package dev.icedamericano.salapify

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth on
// Android: the biometric prompt is a fragment and needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {
    // Screen security. This class sets or clears FLAG_SECURE when Dart asks, and
    // decides nothing: whether the flag should be on is decided in
    // lib/services/secure_window.dart, which is tested. FLAG_SECURE blanks both
    // manual screenshots and the recents thumbnail at the OS level, which a
    // Flutter overlay alone cannot do.
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
