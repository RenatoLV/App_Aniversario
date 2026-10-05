package cl.nuestrorincon.nuestro_rincon

import android.graphics.*
import android.view.View
import java.util.concurrent.Executors

/** Streaming fallback for Android 7/8: two canvases, no full-animation bitmap cache. */
class LegacyWebpArtwork(private val timeline: WebpTimeline, private val owner: View) {
    val width get() = timeline.width
    val height get() = timeline.height
    private val working = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    private val shown = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    private val workingCanvas = Canvas(working)
    private val shownCanvas = Canvas(shown)
    private val replace = Paint().apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC) }
    private val clear = Paint().apply { color = timeline.background; xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC) }
    private val worker = Executors.newSingleThreadExecutor()
    private val lock = Any()
    private var decoded = -1
    private var displayed = -1
    private var wanted = 0
    private var pending = false
    private var released = false
    init {
        working.eraseColor(timeline.background)
        advance(0)
        shownCanvas.drawBitmap(working, 0f, 0f, replace)
        displayed = 0
    }
    private fun advance(target: Int) {
        if (target < decoded) {
            decoded = -1
            working.eraseColor(timeline.background)
        }
        while (decoded < target) {
            if (decoded >= 0) {
                val previous = timeline.frames[decoded]
                if (previous.dispose) {
                    workingCanvas.drawRect(previous.x.toFloat(), previous.y.toFloat(),
                        (previous.x + previous.width).toFloat(), (previous.y + previous.height).toFloat(), clear)
                }
            }
            val next = timeline.frames[++decoded]
            val bytes = timeline.stillFrame(decoded)
            val image = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
            try {
                require(image.width == next.width && image.height == next.height)
                workingCanvas.drawBitmap(image, next.x.toFloat(), next.y.toFloat(), if (next.blend) null else replace)
            } finally { image.recycle() }
        }
    }
    fun draw(canvas: Canvas, elapsed: Long) {
        val target = timeline.frameAt(elapsed)
        synchronized(lock) {
            if (released) return
            canvas.drawBitmap(shown, 0f, 0f, null)
            wanted = target
            if (pending || displayed == target) return
            pending = true
            worker.execute {
                try {
                    while (true) {
                        val next = synchronized(lock) { if (released) return@execute else wanted }
                        advance(next)
                        synchronized(lock) {
                            if (released) return@execute
                            shownCanvas.drawBitmap(working, 0f, 0f, replace)
                            displayed = next
                            owner.postInvalidate()
                            if (wanted == next) { pending = false; return@execute }
                        }
                    }
                } catch (_: Exception) {
                    synchronized(lock) { pending = false }
                }
            }
        }
    }
    fun release() {
        synchronized(lock) { if (released) return; released = true }
        // Recycle on the same queue after any decoder using the working canvas.
        worker.execute { synchronized(lock) { working.recycle(); shown.recycle() } }
        worker.shutdown()
    }
}
