package cl.nuestrorincon.nuestro_rincon

import android.graphics.*
import android.graphics.drawable.AnimatedImageDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.SystemClock
import android.view.View
import java.io.File

/** Streams native GIF frames, preserving their delays instead of sending PNG frames. */
class AnimatedCardArtwork(path: String, private val bounds: FloatArray, owner: View) {
    private val drawable: Drawable?
    private val movie: Movie?
    private var running = false
    private var started = 0L
    private var elapsed = 0L
    init {
        require(ArtworkGeometry.validBounds(bounds))
        if (Build.VERSION.SDK_INT >= 28) {
            drawable = ImageDecoder.decodeDrawable(ImageDecoder.createSource(File(path))) { decoder, _, _ ->
                // Also supports rendering the currently visible frame into the saved photo.
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            }
            require(drawable is AnimatedImageDrawable) { "La carta no contiene una animación GIF." }
            drawable.repeatCount = AnimatedImageDrawable.REPEAT_INFINITE
            drawable.callback = owner
            movie = null
        } else {
            drawable = null
            @Suppress("DEPRECATION")
            movie = Movie.decodeFile(path)
            require(movie != null) { "No se pudo leer la animación GIF." }
            owner.setLayerType(View.LAYER_TYPE_SOFTWARE, null)
        }
    }
    fun owns(who: Drawable) = who === drawable
    fun start() {
        if (running) return
        running = true
        started = SystemClock.uptimeMillis()
        if (Build.VERSION.SDK_INT >= 28) (drawable as? AnimatedImageDrawable)?.start()
    }
    fun stop() {
        if (!running) return
        elapsed += SystemClock.uptimeMillis() - started
        running = false
        if (Build.VERSION.SDK_INT >= 28) (drawable as? AnimatedImageDrawable)?.stop()
    }
    fun release() { stop(); drawable?.callback = null }
    fun draw(canvas: Canvas, cardWidth: Float, cardHeight: Float) {
        val region = RectF(bounds[0] * cardWidth, bounds[1] * cardHeight,
            (bounds[0] + bounds[2]) * cardWidth, (bounds[1] + bounds[3]) * cardHeight)
        val sourceWidth = drawable?.intrinsicWidth ?: movie!!.width()
        val sourceHeight = drawable?.intrinsicHeight ?: movie!!.height()
        val fit = ArtworkGeometry.contain(sourceWidth, sourceHeight, region.width(), region.height())
        canvas.save()
        canvas.clipPath(Path().apply { addRoundRect(region, cardWidth * .025f, cardWidth * .025f, Path.Direction.CW) })
        canvas.drawColor(0xff281a43.toInt())
        canvas.translate(region.left + fit[0], region.top + fit[1])
        canvas.scale(fit[2] / sourceWidth, fit[3] / sourceHeight)
        if (drawable != null) {
            drawable.setBounds(0, 0, sourceWidth, sourceHeight)
            drawable.draw(canvas)
        } else {
            val current = elapsed + if (running) SystemClock.uptimeMillis() - started else 0L
            movie!!.setTime((current % movie.duration().coerceAtLeast(100)).toInt())
            movie.draw(canvas, 0f, 0f)
        }
        canvas.restore()
    }
}
