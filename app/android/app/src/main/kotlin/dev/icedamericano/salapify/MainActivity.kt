package dev.icedamericano.salapify

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: local_auth shows the phone's
// own lock prompt as a fragment, and a fragment needs a FragmentActivity to
// live in. Added with app lock, 2026-10-08.
class MainActivity : FlutterFragmentActivity() {
    // The screenshot and recent-apps shield. This class sets or clears
    // FLAG_SECURE when Dart asks and decides nothing itself: whether it should
    // be on is AppLockController's call (lib/features/lock/app_lock.dart),
    // which is tested. It is on exactly while app lock is on. FLAG_SECURE
    // blanks both a screenshot and the recent-apps thumbnail at the system
    // level, which an overlay drawn by Flutter cannot do on its own.
    private val secureChannel = "salapify/secure_window"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        val secure = call.argument<Boolean>("secure") ?: false
                        runOnUiThread {
                            if (secure) {
                                window.setFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                )
                            } else {
                                window.clearFlags(
                                    WindowManager.LayoutParams.FLAG_SECURE,
                                )
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
