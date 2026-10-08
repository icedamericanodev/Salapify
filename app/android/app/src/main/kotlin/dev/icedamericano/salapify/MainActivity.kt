package dev.icedamericano.salapify

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity, not FlutterActivity: local_auth shows the phone's
// own lock prompt as a fragment, and a fragment needs a FragmentActivity to
// live in. Added with app lock, 2026-10-08.
class MainActivity : FlutterFragmentActivity() {
    // App lock's two native helpers. This class does what Dart asks and
    // decides nothing itself: every rule is in AppLockController
    // (lib/features/lock/app_lock.dart), which is tested.
    private val secureChannel = "salapify/secure_window"
    private val credentialRequest = 4207
    private var pendingCredential: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // The screenshot and recent-apps shield, on exactly while
                    // app lock is on. FLAG_SECURE blanks both at the system
                    // level, which an overlay drawn by Flutter cannot do.
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
                    // The phone's own PIN, pattern or password screen, for
                    // when the biometric prompt keeps failing on a phone.
                    // Still the phone's lock, never a way past it. Answers
                    // true or false, or null when the phone has no screen
                    // lock at all.
                    "confirmDeviceCredential" -> {
                        val keyguard =
                            getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        @Suppress("DEPRECATION")
                        val intent: Intent? = if (keyguard.isDeviceSecure) {
                            keyguard.createConfirmDeviceCredentialIntent(
                                call.argument<String>("title"),
                                call.argument<String>("description"),
                            )
                        } else {
                            null
                        }
                        if (intent == null) {
                            result.success(null)
                        } else {
                            pendingCredential?.success(false)
                            pendingCredential = result
                            @Suppress("DEPRECATION")
                            startActivityForResult(intent, credentialRequest)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android, still the way to hear back here")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == credentialRequest) {
            pendingCredential?.success(resultCode == Activity.RESULT_OK)
            pendingCredential = null
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }
}
