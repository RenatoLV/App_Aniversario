package cl.nuestrorincon.nuestro_rincon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.media.AudioManager
import android.media.ToneGenerator
import java.io.File
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.plugin.common.EventChannel
import android.view.Surface

class MainActivity : FlutterActivity() {
    private var tiltSink: EventChannel.EventSink? = null
    private val sensors by lazy { getSystemService(SENSOR_SERVICE) as SensorManager }
    private val tiltListener = object : SensorEventListener {
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        override fun onSensorChanged(event: SensorEvent) {
            @Suppress("DEPRECATION")
            val rotation = windowManager.defaultDisplay.rotation
            val x = when (rotation) {
                Surface.ROTATION_90 -> -event.values[1]
                Surface.ROTATION_180 -> -event.values[0]
                Surface.ROTATION_270 -> event.values[1]
                else -> event.values[0]
            }
            tiltSink?.success(x.toDouble())
        }
    }
    private fun startTilt() {
        val sensor = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
            ?: sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (sensor == null || !sensors.registerListener(tiltListener, sensor, SensorManager.SENSOR_DELAY_GAME)) {
            tiltSink?.error("unavailable", "Sensor no disponible", null)
        }
    }
    override fun onPause() {
        sensors.unregisterListener(tiltListener)
        super.onPause()
    }
    override fun onResume() {
        super.onResume()
        if (tiltSink != null) startTilt()
    }
    private var tones: ToneGenerator? = null
    private var pendingAr: MethodChannel.Result? = null
    private var textureFile: File? = null
    private var backTextureFile: File? = null
    private var animatedTextureFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anivermaru/updates")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "version" -> {
                        @Suppress("DEPRECATION")
                        val info = packageManager.getPackageInfo(packageName, 0)
                        @Suppress("DEPRECATION")
                        val code = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                        result.success(mapOf("name" to info.versionName, "code" to code))
                    }
                    "openDownload" -> {
                        val url = call.argument<String>("url") ?: ""
                        if (!url.startsWith("https://github.com/RenatoLV/App_Aniversario/releases/download/")) {
                            result.error("url", "Descarga no válida", null)
                        } else try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(null)
                        } catch (_: Exception) { result.error("browser", "No se pudo abrir la descarga", null) }
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "anivermaru/tilt")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    tiltSink = events
                    startTilt()
                }
                override fun onCancel(arguments: Any?) {
                    sensors.unregisterListener(tiltListener)
                    tiltSink = null
                }
            })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "anivermaru/sfx")
            .setMethodCallHandler { call, result ->
                if (call.method != "play") { result.notImplemented(); return@setMethodCallHandler }
                try {
                    val player = tones ?: ToneGenerator(AudioManager.STREAM_MUSIC, 55).also { tones = it }
                    val clear = call.argument<Boolean>("clear") == true
                    player.startTone(if (clear) ToneGenerator.TONE_PROP_ACK else ToneGenerator.TONE_PROP_BEEP,
                        if (clear) 220 else 65)
                    result.success(null)
                } catch (_: Exception) { result.success(null) }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rincon/card_ar")
            .setMethodCallHandler { call, result ->
                if (call.method == "privacy") {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://policies.google.com/privacy")))
                        result.success(null)
                    } catch (_: Exception) { result.error("privacy", "No se pudo abrir la política de privacidad.", null) }
                    return@setMethodCallHandler
                }
                if (call.method != "open") { result.notImplemented(); return@setMethodCallHandler }
                if (pendingAr != null) { result.error("busy", "Ya hay una sesión AR abierta.", null); return@setMethodCallHandler }
                val bytes = call.argument<ByteArray>("texture")
                val backBytes = call.argument<ByteArray>("backTexture")
                val animation = call.argument<ByteArray>("animatedTexture")
                val bounds = call.argument<List<Number>>("animatedRect")?.map { it.toFloat() }?.toFloatArray()
                if ((animation == null) != (bounds == null) ||
                    (animation?.size ?: 0) > 20_000_000 ||
                    (bounds != null && !ArtworkGeometry.validBounds(bounds))) {
                    result.error("animation", "No pudimos preparar la animación de la carta.", null)
                    return@setMethodCallHandler
                }
                if (bytes == null || bytes.size > 6_000_000 || (backBytes?.size ?: 0) > 6_000_000) {
                    result.error("texture", "No pudimos preparar la carta.", null)
                    return@setMethodCallHandler
                }
                try {
                    textureFile = File.createTempFile("ar-card-", ".png", cacheDir).apply { writeBytes(bytes) }
                    backTextureFile = backBytes?.let { content ->
                        File.createTempFile("ar-back-", ".png", cacheDir).apply { writeBytes(content) }
                    }
                    animatedTextureFile = animation?.let { content ->
                        File.createTempFile("ar-animation-", ".gif", cacheDir).apply { writeBytes(content) }
                    }
                    pendingAr = result
                    startActivityForResult(Intent(this, CameraCardActivity::class.java)
                        .putExtra("texturePath", textureFile!!.absolutePath)
                        .putExtra("backTexturePath", backTextureFile?.absolutePath)
                        .putExtra("animationPath", animatedTextureFile?.absolutePath)
                        .putExtra("animationBounds", bounds), 8421)
                } catch (e: Exception) {
                    pendingAr = null
                    textureFile?.delete()
                    backTextureFile?.delete()
                    animatedTextureFile?.delete()
                    result.error("ar", "No se pudo abrir la cámara AR.", null)
                }
            }
    }

    @Deprecated("Platform result bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 8421) return
        val result = pendingAr
        pendingAr = null
        textureFile?.delete()
        textureFile = null
        backTextureFile?.delete()
        backTextureFile = null
        animatedTextureFile?.delete()
        animatedTextureFile = null
        val error = data?.getStringExtra("error")
        val path = data?.getStringExtra("photoPath")
        if (error != null) result?.error("ar", error, null)
        else if (path != null) {
            val photo = File(path)
            try { result?.success(photo.readBytes()) }
            catch (_: Exception) { result?.error("capture", "No pudimos leer la foto.", null) }
            finally { photo.delete() }
        } else result?.success(null)
    }

    override fun onDestroy() {
        tones?.release()
        tones = null
        super.onDestroy()
    }
}
