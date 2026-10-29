package cl.nuestrorincon.nuestro_rincon

import android.os.Bundle
import android.os.SystemClock
import android.view.KeyEvent
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import android.view.View
import android.widget.FrameLayout
import org.godotengine.godot.GodotActivity
import org.godotengine.godot.Godot

/** Runs the original Godot scenes in their own process; no Flutter redrawing. */
class UncannyGolfActivity : GodotActivity() {
    override fun getGodotAppLayout() = R.layout.uncanny_golf
    override fun getCommandLine() = mutableListOf(
        "--main-pack", "res://uncanny/uncanny-mobile.pck", "--rendering-method", "gl_compatibility"
    )

    private lateinit var game: FrameLayout
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        game = findViewById(org.godotengine.godot.R.id.godot_fragment_container)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        enterFullscreen()
        // Godot handles direct aiming; only translucent buttons intercept touches.
        bindKey(R.id.ucg_overlay_pause, KeyEvent.KEYCODE_ESCAPE)
        bindKey(R.id.ucg_overlay_retry, KeyEvent.KEYCODE_R)
        bindKey(R.id.ucg_overlay_parry, KeyEvent.KEYCODE_SHIFT_LEFT)
        bindKey(R.id.ucg_overlay_exit, KeyEvent.KEYCODE_F10)
    }

    override fun onGodotForceQuit(instance: Godot) {
        // Godot cannot initialize twice in one process. Finish only this screen,
        // then terminate its dedicated process, preserving the Flutter task.
        runOnUiThread {
            finish()
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }

    override fun onGodotMainLoopStarted() {
        runOnUiThread { enterFullscreen() }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) window.decorView.postDelayed({ enterFullscreen() }, 300)
    }

    private fun enterFullscreen() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    private fun bindKey(id: Int, code: Int) {
        findViewById<View>(id).setOnClickListener {
            val now = SystemClock.uptimeMillis()
            godot?.renderView?.inputHandler?.onKeyDown(code,
                KeyEvent(now, now, KeyEvent.ACTION_DOWN, code, 0))
            // Keep the key pressed for physics frames, rather than losing both
            // transitions between consecutive Godot input polls.
            game.postDelayed({
                godot?.renderView?.inputHandler?.onKeyUp(code,
                    KeyEvent(now, SystemClock.uptimeMillis(), KeyEvent.ACTION_UP, code, 0))
            }, 60)
        }
    }
}
