package cl.nuestrorincon.nuestro_rincon

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import android.opengl.Matrix
import android.os.Bundle
import android.view.Gravity
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.google.ar.core.*
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/** Local, plane-anchored AR. No Cloud Anchors, camera uploads or gallery writes. */
class CardArActivity : Activity(), GLSurfaceView.Renderer {
    private lateinit var surface: GLSurfaceView
    private lateinit var instructions: TextView
    private lateinit var shutter: Button
    @Volatile private var session: Session? = null
    private var anchor: Anchor? = null
    private var installRequested = false
    @Volatile private var failed = false
    private var resumed = false
    private var captureRequested = false // Only touched on the GL thread.
    private var tap: Pair<Float, Float>? = null
    @Volatile private var cardScale = 1f
    private var screenWidth = 1
    private var screenHeight = 1
    private var cameraTexture = 0
    private var cardTexture = 0
    private var cameraProgram = 0
    private var cardProgram = 0
    private val quad = floats(floatArrayOf(-1f,-1f, 1f,-1f, -1f,1f, 1f,1f))
    private val cameraUv = floats(FloatArray(8))
    private val cardUv = floats(floatArrayOf(0f,1f, 1f,1f, 0f,0f, 1f,0f))
    private var lastMessage = ""

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        surface = GLSurfaceView(this).apply {
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            preserveEGLContextOnPause = true
            setRenderer(this@CardArActivity)
        }
        val root = FrameLayout(this)
        root.addView(surface)
        instructions = TextView(this).apply {
            text = "Mueve despacio el teléfono y toca una mesa o el suelo para colocar tu carta."
            setTextColor(0xffffffff.toInt())
            setBackgroundColor(0xb0293f39.toInt())
            setPadding(22, 20, 22, 20)
            textSize = 16f
            gravity = Gravity.CENTER
        }
        root.addView(instructions, FrameLayout.LayoutParams(-1, -2, Gravity.TOP))
        val controls = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(8, 8, 8, 24)
            setBackgroundColor(0xb0293f39.toInt())
        }
        fun button(label: String, action: () -> Unit): Button = Button(this).apply {
            text = label
            setOnClickListener { action() }
            controls.addView(this, LinearLayout.LayoutParams(0, -2, 1f))
        }
        button("Volver") { finish() }
        button("−") { cardScale = (cardScale / 1.2f).coerceIn(.2f, 4f) }
        button("+") { cardScale = (cardScale * 1.2f).coerceIn(.2f, 4f) }
        shutter = button("Foto") {
            shutter.isEnabled = false
            surface.queueEvent { captureRequested = true }
        }.apply { isEnabled = false }
        root.addView(controls, FrameLayout.LayoutParams(-1, -2, Gravity.BOTTOM))
        setContentView(root)
        val pinch = ScaleGestureDetector(this, object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                cardScale = (cardScale * detector.scaleFactor).coerceIn(.2f, 4f)
                return true
            }
        })
        val touch = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onDown(e: MotionEvent) = true
            override fun onSingleTapUp(e: MotionEvent): Boolean {
                val point = Pair(e.x, e.y)
                surface.queueEvent { tap = point }
                return true
            }
        })
        var suppressTap = false
        surface.setOnTouchListener { view, event ->
            if (event.actionMasked == MotionEvent.ACTION_DOWN) suppressTap = false
            if (event.pointerCount > 1) suppressTap = true
            pinch.onTouchEvent(event)
            if (!suppressTap && !pinch.isInProgress) touch.onTouchEvent(event)
            if (event.action == MotionEvent.ACTION_UP) view.performClick()
            true
        }
    }

    override fun onResume() {
        super.onResume()
        resumed = true
        if (failed) return
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), 74)
            return
        }
        ensureSession()
    }

    private fun ensureSession() {
        ArCoreApk.getInstance().checkAvailabilityAsync(this) { availability ->
            if (isFinishing || isDestroyed || !resumed) return@checkAvailabilityAsync
            if (!availability.isSupported) {
                fail("Este teléfono no es compatible con ARCore. Puedes seguir usando el visor de cartas.")
            } else startSession()
        }
    }

    private fun startSession() {
        try {
            if (session == null) {
                if (ArCoreApk.getInstance().requestInstall(this, !installRequested) == ArCoreApk.InstallStatus.INSTALL_REQUESTED) {
                    installRequested = true
                    return
                }
                session = Session(this).apply {
                    configure(Config(this).apply { planeFindingMode = Config.PlaneFindingMode.HORIZONTAL })
                }
            }
            session!!.resume()
            surface.onResume()
        } catch (_: Exception) {
            fail("No se pudo iniciar AR. Revisa Google Play Services para AR y el permiso de cámara.")
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 74) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) ensureSession()
            else fail("Necesitamos permiso de cámara para ver tu carta en realidad aumentada.")
        }
    }

    override fun onPause() {
        resumed = false
        surface.onPause()
        session?.pause()
        super.onPause()
    }

    override fun onDestroy() {
        anchor?.detach()
        session?.close()
        super.onDestroy()
    }

    private fun fail(message: String) {
        runOnUiThread {
            if (failed || isFinishing) return@runOnUiThread
            failed = true
            setResult(RESULT_CANCELED, Intent().putExtra("error", message))
            finish()
        }
    }

    private fun message(text: String, ready: Boolean) {
        if (text == lastMessage) return
        lastMessage = text
        runOnUiThread {
            instructions.text = text
            shutter.isEnabled = ready
        }
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        try {
            cameraProgram = program(
                "attribute vec2 pos; attribute vec2 uv; varying vec2 tex; void main(){tex=uv;gl_Position=vec4(pos,0.,1.);}",
                "#extension GL_OES_EGL_image_external : require\nprecision mediump float; uniform samplerExternalOES image; varying vec2 tex; void main(){gl_FragColor=texture2D(image,tex);}")
            cardProgram = program(
                "attribute vec2 pos; attribute vec2 uv; uniform mat4 mvp; varying vec2 tex; void main(){tex=uv;gl_Position=mvp*vec4(pos,0.,1.);}",
                "precision mediump float; uniform sampler2D image; varying vec2 tex; void main(){gl_FragColor=texture2D(image,tex);}")
            val textures = IntArray(2)
            GLES20.glGenTextures(2, textures, 0)
            cameraTexture = textures[0]
            cardTexture = textures[1]
            bindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTexture)
            bindTexture(GLES20.GL_TEXTURE_2D, cardTexture)
            val path = intent.getStringExtra("texturePath") ?: throw IllegalArgumentException()
            val bitmap = BitmapFactory.decodeFile(path) ?: throw IllegalArgumentException()
            GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
            bitmap.recycle()
        } catch (_: Exception) { fail("No pudimos preparar la carta para AR.") }
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        screenWidth = width
        screenHeight = height
        GLES20.glViewport(0, 0, width, height)
    }

    override fun onDrawFrame(gl: GL10?) {
        val ar = session ?: return
        if (failed) return
        try {
            ar.setCameraTextureName(cameraTexture)
            @Suppress("DEPRECATION")
            ar.setDisplayGeometry(windowManager.defaultDisplay.rotation, screenWidth, screenHeight)
            val frame = ar.update()
            GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
            if (frame.timestamp == 0L) return
            quad.position(0)
            cameraUv.position(0)
            frame.transformCoordinates2d(Coordinates2d.OPENGL_NORMALIZED_DEVICE_COORDINATES, quad, Coordinates2d.TEXTURE_NORMALIZED, cameraUv)
            draw(cameraProgram, GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTexture, cameraUv, null)
            if (frame.camera.trackingState != TrackingState.TRACKING) {
                message("Seguimiento pausado. Mueve despacio el teléfono hacia una zona iluminada.", false)
                captureRequested = false
                return
            }
            tap?.let { point ->
                tap = null
                val hit = frame.hitTest(point.first, point.second).firstOrNull {
                    val plane = it.trackable as? Plane
                    plane != null && plane.type == Plane.Type.HORIZONTAL_UPWARD_FACING && plane.isPoseInPolygon(it.hitPose)
                }
                if (hit != null) {
                    anchor?.detach()
                    val t = hit.hitPose.translation
                    val camera = frame.camera.pose.translation
                    val yaw = atan2(camera[0] - t[0], camera[2] - t[2])
                    anchor = ar.createAnchor(Pose(t, floatArrayOf(0f, sin(yaw / 2), 0f, cos(yaw / 2))))
                }
            }
            val placed = anchor
            if (placed != null && placed.trackingState == TrackingState.TRACKING) {
                val model = FloatArray(16)
                val view = FloatArray(16)
                val projection = FloatArray(16)
                val mv = FloatArray(16)
                val mvp = FloatArray(16)
                placed.pose.toMatrix(model, 0)
                Matrix.translateM(model, 0, 0f, .1775f * cardScale, 0f)
                Matrix.scaleM(model, 0, .135f * cardScale, .1775f * cardScale, 1f)
                frame.camera.getViewMatrix(view, 0)
                frame.camera.getProjectionMatrix(projection, 0, .01f, 100f)
                Matrix.multiplyMM(mv, 0, view, 0, model, 0)
                Matrix.multiplyMM(mvp, 0, projection, 0, mv, 0)
                GLES20.glEnable(GLES20.GL_BLEND)
                // Android Bitmap uploads use premultiplied alpha.
                GLES20.glBlendFunc(GLES20.GL_ONE, GLES20.GL_ONE_MINUS_SRC_ALPHA)
                draw(cardProgram, GLES20.GL_TEXTURE_2D, cardTexture, cardUv, mvp)
                GLES20.glDisable(GLES20.GL_BLEND)
                message("Pellizca para cambiar el tamaño · toca otra superficie para moverla · Foto para capturar.", true)
                if (captureRequested) {
                    captureRequested = false
                    capture()
                }
            } else {
                message("Mueve despacio el teléfono y toca una mesa o el suelo para colocar tu carta.", false)
                captureRequested = false
            }
        } catch (_: Exception) { fail("La sesión AR se interrumpió. Cierra otras apps que usen la cámara y vuelve a intentar.") }
    }

    private fun capture() {
        val buffer = ByteBuffer.allocateDirect(screenWidth * screenHeight * 4)
        GLES20.glReadPixels(0, 0, screenWidth, screenHeight, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, buffer)
        val pixels = IntArray(screenWidth * screenHeight)
        for (row in 0 until screenHeight) for (col in 0 until screenWidth) {
            val index = (row * screenWidth + col) * 4
            val r = buffer.get(index).toInt() and 255
            val g = buffer.get(index + 1).toInt() and 255
            val b = buffer.get(index + 2).toInt() and 255
            pixels[(screenHeight - 1 - row) * screenWidth + col] = (255 shl 24) or (r shl 16) or (g shl 8) or b
        }
        val bitmap = Bitmap.createBitmap(pixels, screenWidth, screenHeight, Bitmap.Config.ARGB_8888)
        val ratio = minOf(1f, 1200f / maxOf(screenWidth, screenHeight))
        val small = Bitmap.createScaledBitmap(bitmap, (screenWidth * ratio).toInt(), (screenHeight * ratio).toInt(), true)
        val bytes = ByteArrayOutputStream()
        small.compress(Bitmap.CompressFormat.JPEG, 85, bytes)
        if (small !== bitmap) small.recycle()
        bitmap.recycle()
        val photo = File.createTempFile("ar-photo-", ".jpg", cacheDir).apply { writeBytes(bytes.toByteArray()) }
        runOnUiThread {
            setResult(RESULT_OK, Intent().putExtra("photoPath", photo.absolutePath))
            finish()
        }
    }

    private fun draw(program: Int, target: Int, texture: Int, uv: FloatBuffer, mvp: FloatArray?) {
        GLES20.glUseProgram(program)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(target, texture)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "image"), 0)
        val pos = GLES20.glGetAttribLocation(program, "pos")
        val tex = GLES20.glGetAttribLocation(program, "uv")
        quad.position(0)
        uv.position(0)
        GLES20.glEnableVertexAttribArray(pos)
        GLES20.glEnableVertexAttribArray(tex)
        GLES20.glVertexAttribPointer(pos, 2, GLES20.GL_FLOAT, false, 0, quad)
        GLES20.glVertexAttribPointer(tex, 2, GLES20.GL_FLOAT, false, 0, uv)
        if (mvp != null) GLES20.glUniformMatrix4fv(GLES20.glGetUniformLocation(program, "mvp"), 1, false, mvp, 0)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(pos)
        GLES20.glDisableVertexAttribArray(tex)
    }

    private fun bindTexture(target: Int, texture: Int) {
        GLES20.glBindTexture(target, texture)
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(target, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
    }

    private fun program(vertex: String, fragment: String): Int {
        fun shader(type: Int, source: String): Int {
            val shader = GLES20.glCreateShader(type)
            GLES20.glShaderSource(shader, source)
            GLES20.glCompileShader(shader)
            val status = IntArray(1)
            GLES20.glGetShaderiv(shader, GLES20.GL_COMPILE_STATUS, status, 0)
            check(status[0] != 0) { "AR shader compilation failed" }
            return shader
        }
        val v = shader(GLES20.GL_VERTEX_SHADER, vertex)
        val f = shader(GLES20.GL_FRAGMENT_SHADER, fragment)
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, v)
        GLES20.glAttachShader(program, f)
        GLES20.glLinkProgram(program)
        val status = IntArray(1)
        GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, status, 0)
        check(status[0] != 0) { "AR shader linking failed" }
        GLES20.glDeleteShader(v)
        GLES20.glDeleteShader(f)
        return program
    }

    private fun floats(values: FloatArray): FloatBuffer =
        ByteBuffer.allocateDirect(values.size * 4).order(ByteOrder.nativeOrder()).asFloatBuffer().apply { put(values); position(0) }
}
