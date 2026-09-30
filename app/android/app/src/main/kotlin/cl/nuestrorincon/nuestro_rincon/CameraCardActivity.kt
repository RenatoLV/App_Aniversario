package cl.nuestrorincon.nuestro_rincon

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.*
import android.hardware.camera2.*
import android.os.*
import android.view.*
import android.widget.*
import java.io.File
import kotlin.math.*

/** An interactive collectible over the camera; never waits for AR tracking. */
class CameraCardActivity : Activity(), TextureView.SurfaceTextureListener {
    private lateinit var preview: TextureView
    private lateinit var card: CardView
    private lateinit var shutter: Button
    private lateinit var instructions: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var device: CameraDevice? = null
    private var session: CameraCaptureSession? = null
    private var target: Surface? = null
    private var active = false
    private var opening = false
    private var ready = false
    private var generation = 0
    private var sensorRotation = 90
    private var bufferWidth = 1280
    private var bufferHeight = 720

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val front = BitmapFactory.decodeFile(intent.getStringExtra("texturePath"))
        if (front == null) { fail("No pudimos preparar la carta."); return }
        val back = intent.getStringExtra("backTexturePath")?.let { BitmapFactory.decodeFile(it) } ?: front
        val root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        preview = TextureView(this).apply { surfaceTextureListener = this@CameraCardActivity }
        root.addView(preview, FrameLayout.LayoutParams(-1, -1))
        card = CardView(this, front, back)
        root.addView(card, FrameLayout.LayoutParams(-1, -1))
        instructions = TextView(this).apply {
            text = "Desliza para girar 360° · pellizca para acercar o alejar"
            textSize = 15f; gravity = Gravity.CENTER
            setTextColor(Color.WHITE); setBackgroundColor(0xc021183e.toInt())
            setPadding(dp(12), dp(12), dp(12), dp(12))
        }
        root.addView(instructions, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(6), dp(4), dp(6), dp(6)); setBackgroundColor(0xdc21183e.toInt())
        }
        fun row() = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; panel.addView(this) }
        fun button(row: LinearLayout, label: String, action: () -> Unit): Button = Button(this).apply {
            text = label; textSize = 13f; isAllCaps = false; minWidth = 0
            setOnClickListener { action() }
            row.addView(this, LinearLayout.LayoutParams(0, dp(48), 1f))
        }
        val first = row()
        button(first, "Volver") { finish() }
        button(first, "−") { card.zoom = (card.zoom / 1.2f).coerceIn(.25f, 3f) }
        button(first, "+") { card.zoom = (card.zoom * 1.2f).coerceIn(.25f, 3f) }
        shutter = button(first, "Foto") { capture() }.apply { isEnabled = false }
        val second = row()
        button(second, "Mover") {
            card.moveMode = !card.moveMode
            instructions.text = if (card.moveMode) "Arrastra para mover · pellizca para cambiar el tamaño"
                else "Desliza para girar 360° · pellizca para acercar o alejar"
            (second.getChildAt(0) as Button).text = if (card.moveMode) "Girar" else "Mover"
        }
        button(second, "Pausar giro") {
            card.autoSpin = !card.autoSpin
            (second.getChildAt(1) as Button).text = if (card.autoSpin) "Pausar giro" else "Auto 360°"
        }
        button(second, "Centrar") { card.reset() }
        root.addView(panel, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
        root.setOnApplyWindowInsetsListener { _, insets ->
            val bars = if (Build.VERSION.SDK_INT >= 30)
                insets.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout()) else null
            @Suppress("DEPRECATION") val top = bars?.top ?: insets.systemWindowInsetTop
            @Suppress("DEPRECATION") val bottom = bars?.bottom ?: insets.systemWindowInsetBottom
            (instructions.layoutParams as FrameLayout.LayoutParams).apply { topMargin = top; instructions.layoutParams = this }
            (panel.layoutParams as FrameLayout.LayoutParams).apply { bottomMargin = bottom; panel.layoutParams = this }
            insets
        }
        setContentView(root); root.requestApplyInsets()
    }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    override fun onResume() {
        super.onResume(); active = true
        if (!::preview.isInitialized) return
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED)
            requestPermissions(arrayOf(Manifest.permission.CAMERA), 74)
        else if (preview.isAvailable) openCamera()
    }
    override fun onRequestPermissionsResult(code: Int, permissions: Array<out String>, results: IntArray) {
        super.onRequestPermissionsResult(code, permissions, results)
        if (code == 74) {
            if (results.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                if (preview.isAvailable && active) openCamera()
            } else fail("Necesitamos permiso de cámara para este visor.")
        }
    }

    @Suppress("MissingPermission", "DEPRECATION")
    private fun openCamera() {
        if (!active || opening || device != null || !preview.isAvailable ||
            checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) return
        try {
            val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = manager.cameraIdList.firstOrNull {
                manager.getCameraCharacteristics(it).get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: manager.cameraIdList.first()
            val info = manager.getCameraCharacteristics(id)
            sensorRotation = info.get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            val sizes = info.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)!!
                .getOutputSizes(SurfaceTexture::class.java)
            val size = sizes.filter { it.width <= 1920 && it.height <= 1080 }
                .minByOrNull { abs(it.width.toFloat() / it.height - 16f / 9) * 10000 + abs(it.width - 1280) }
                ?: sizes.minBy { it.width * it.height }
            bufferWidth = size.width; bufferHeight = size.height
            preview.surfaceTexture!!.setDefaultBufferSize(bufferWidth, bufferHeight)
            configurePreview(); opening = true
            val token = generation
            manager.openCamera(id, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    if (!active || token != generation || !preview.isAvailable) { camera.close(); return }
                    opening = false; device = camera
                    val output = Surface(preview.surfaceTexture!!); target = output
                    camera.createCaptureSession(listOf(output), object : CameraCaptureSession.StateCallback() {
                        override fun onConfigured(configured: CameraCaptureSession) {
                            if (!active || device !== camera || token != generation) { configured.close(); return }
                            session = configured
                            try {
                                val request = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW).apply {
                                    addTarget(output); set(CaptureRequest.CONTROL_MODE, CaptureRequest.CONTROL_MODE_AUTO)
                                }
                                configured.setRepeatingRequest(request.build(), object : CameraCaptureSession.CaptureCallback() {
                                    override fun onCaptureCompleted(s: CameraCaptureSession, r: CaptureRequest, result: TotalCaptureResult) {
                                        if (active && device === camera) { ready = true; shutter.isEnabled = true }
                                    }
                                }, handler)
                            } catch (_: Exception) { fail("No se pudo iniciar la cámara. Cierra otras apps que la usen.") }
                        }
                        override fun onConfigureFailed(s: CameraCaptureSession) { if (token == generation) fail("No se pudo preparar la cámara.") }
                    }, handler)
                }
                override fun onDisconnected(camera: CameraDevice) { camera.close(); if (active && token == generation) fail("La cámara se desconectó.") }
                override fun onError(camera: CameraDevice, error: Int) { camera.close(); if (active && token == generation) fail("No se pudo abrir la cámara.") }
            }, handler)
        } catch (_: Exception) { opening = false; fail("No se pudo abrir la cámara.") }
    }

    @Suppress("DEPRECATION")
    private fun configurePreview() {
        if (preview.width == 0 || preview.height == 0) return
        val rotation = (sensorRotation - windowManager.defaultDisplay.rotation * 90 + 360) % 360
        val view = RectF(0f, 0f, preview.width.toFloat(), preview.height.toFloat())
        val swapped = rotation == 90 || rotation == 270
        val buffer = RectF(0f, 0f, (if (swapped) bufferHeight else bufferWidth).toFloat(),
            (if (swapped) bufferWidth else bufferHeight).toFloat())
        val matrix = Matrix()
        // Undo TextureView's stretch of the raw sensor buffer before rotating and center-cropping.
        matrix.setScale(bufferWidth / view.width(), bufferHeight / view.height())
        matrix.postTranslate(-bufferWidth / 2f, -bufferHeight / 2f)
        matrix.postRotate(rotation.toFloat())
        val scale = maxOf(view.width() / buffer.width(), view.height() / buffer.height())
        matrix.postScale(scale, scale)
        matrix.postTranslate(view.centerX(), view.centerY())
        preview.setTransform(matrix)
    }
    override fun onSurfaceTextureAvailable(t: SurfaceTexture, w: Int, h: Int) { openCamera() }
    override fun onSurfaceTextureSizeChanged(t: SurfaceTexture, w: Int, h: Int) { configurePreview() }
    override fun onSurfaceTextureUpdated(t: SurfaceTexture) {}
    override fun onSurfaceTextureDestroyed(t: SurfaceTexture): Boolean { closeCamera(); return true }
    private fun closeCamera() {
        generation++; opening = false; ready = false
        if (::shutter.isInitialized) shutter.isEnabled = false
        session?.close(); session = null; device?.close(); device = null; target?.release(); target = null
    }
    override fun onPause() { active = false; closeCamera(); super.onPause() }
    override fun onDestroy() { if (::card.isInitialized) card.release(); super.onDestroy() }
    private fun fail(message: String) {
        if (isFinishing || isDestroyed) return
        setResult(RESULT_CANCELED, Intent().putExtra("error", message)); finish()
    }
    private fun capture() {
        if (!ready) return
        shutter.isEnabled = false
        try {
            val image = preview.bitmap ?: throw IllegalStateException()
            card.draw(Canvas(image))
            val ratio = min(1f, 1600f / maxOf(image.width, image.height))
            val small = Bitmap.createScaledBitmap(image, (image.width * ratio).toInt(), (image.height * ratio).toInt(), true)
            val photo = File.createTempFile("ar-photo-", ".jpg", cacheDir)
            photo.outputStream().use { small.compress(Bitmap.CompressFormat.JPEG, 90, it) }
            if (small !== image) small.recycle()
            image.recycle()
            setResult(RESULT_OK, Intent().putExtra("photoPath", photo.absolutePath)); finish()
        } catch (_: Exception) { shutter.isEnabled = true; Toast.makeText(this, "No pudimos tomar la foto. Intenta otra vez.", Toast.LENGTH_SHORT).show() }
    }

    private class CardView(context: Context, private val front: Bitmap, private val back: Bitmap) : View(context) {
        var zoom = 1f
        var moveMode = false
        var autoSpin = true
        private var turn = 0f
        private var tilt = -5f
        private var offsetX = 0f
        private var offsetY = 0f
        private var lastX = 0f
        private var lastY = 0f
        private var lastTime = SystemClock.uptimeMillis()
        private var interacting = false
        private var lastTouch = SystemClock.uptimeMillis()
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
        private val perspective = android.graphics.Camera()
        private val transform = Matrix()
        private val pinch = ScaleGestureDetector(context, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(d: ScaleGestureDetector): Boolean { zoom = (zoom * d.scaleFactor).coerceIn(.25f, 3f); return true }
        })
        fun reset() { zoom = 1f; turn = 0f; tilt = -5f; offsetX = 0f; offsetY = 0f }
        fun release() { front.recycle(); if (back !== front) back.recycle() }
        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val now = SystemClock.uptimeMillis()
            if (autoSpin && !interacting && now - lastTouch > 2500) turn += min(now - lastTime, 50L) * .018f
            lastTime = now
            val w = min(width * .65f, height * .43f) * zoom
            val h = w * front.height / front.width
            val isFront = cos(Math.toRadians(turn.toDouble())) >= 0
            perspective.save(); perspective.setLocation(0f, 0f, -12f * resources.displayMetrics.density)
            perspective.rotateX(tilt); perspective.rotateY(if (isFront) turn else turn + 180f)
            perspective.getMatrix(transform); perspective.restore()
            transform.preTranslate(-w / 2, -h / 2)
            transform.postTranslate(width / 2f + offsetX, height * .46f + offsetY)
            canvas.save(); canvas.concat(transform)
            val rect = RectF(0f, 0f, w, h); val radius = w * .08f
            paint.shader = null; paint.color = 0x554fdfff; paint.style = Paint.Style.STROKE
            for (i in 4 downTo 1) {
                paint.strokeWidth = i * 3f * resources.displayMetrics.density; paint.alpha = 15 + (4 - i) * 8
                canvas.drawRoundRect(rect, radius, radius, paint)
            }
            paint.style = Paint.Style.FILL; paint.alpha = 255
            canvas.drawBitmap(if (isFront) front else back, null, rect, paint)
            canvas.save(); canvas.clipPath(Path().apply { addRoundRect(rect, radius, radius, Path.Direction.CW) })
            val sweep = ((now % 6500L) / 6500f * 2.4f - .7f) * w
            paint.shader = LinearGradient(sweep - w * .2f, 0f, sweep + w * .2f, h,
                intArrayOf(Color.TRANSPARENT, 0x60ffffff, 0x3079efff, Color.TRANSPARENT),
                floatArrayOf(0f, .45f, .65f, 1f), Shader.TileMode.CLAMP)
            canvas.drawRect(rect, paint); paint.shader = null; paint.color = Color.WHITE
            paint.alpha = ((.4 + .4 * sin(now / 600.0)) * 255).toInt()
            paint.strokeWidth = 2f * resources.displayMetrics.density
            for ((x, y) in listOf(Pair(w * .08f, h * .08f), Pair(w * .92f, h * .92f))) {
                val r = w * .025f
                canvas.drawLine(x-r, y, x+r, y, paint); canvas.drawLine(x, y-r, x, y+r, paint)
            }
            canvas.restore(); canvas.restore(); paint.alpha = 255
            postInvalidateOnAnimation()
        }
        override fun onTouchEvent(event: MotionEvent): Boolean {
            pinch.onTouchEvent(event)
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> { interacting = true; lastX = event.x; lastY = event.y }
                MotionEvent.ACTION_MOVE -> {
                    if (event.pointerCount == 1 && !pinch.isInProgress) {
                        if (moveMode) {
                            offsetX = (offsetX + event.x - lastX).coerceIn(-width * .4f, width * .4f)
                            offsetY = (offsetY + event.y - lastY).coerceIn(-height * .3f, height * .3f)
                        } else { turn += (event.x - lastX) * .6f; tilt = (tilt - (event.y - lastY) * .25f).coerceIn(-35f, 35f) }
                    }
                    lastX = event.x; lastY = event.y
                }
                MotionEvent.ACTION_POINTER_UP -> { val other = if (event.actionIndex == 0) 1 else 0; lastX = event.getX(other); lastY = event.getY(other) }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> { interacting = false; lastTouch = SystemClock.uptimeMillis(); performClick() }
            }
            return true
        }
        override fun performClick(): Boolean { super.performClick(); return true }
    }
}
