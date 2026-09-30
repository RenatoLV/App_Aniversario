package cl.nuestrorincon.nuestro_rincon

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingAr: MethodChannel.Result? = null
    private var textureFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                if (bytes == null || bytes.size > 6_000_000) {
                    result.error("texture", "No pudimos preparar la carta.", null)
                    return@setMethodCallHandler
                }
                try {
                    textureFile = File.createTempFile("ar-card-", ".png", cacheDir).apply { writeBytes(bytes) }
                    pendingAr = result
                    startActivityForResult(Intent(this, CardArActivity::class.java)
                        .putExtra("texturePath", textureFile!!.absolutePath), 8421)
                } catch (e: Exception) {
                    pendingAr = null
                    textureFile?.delete()
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
}
