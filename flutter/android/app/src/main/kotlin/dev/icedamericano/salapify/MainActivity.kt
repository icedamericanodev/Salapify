package dev.icedamericano.salapify

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth on
// Android: the biometric prompt is a fragment and needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity()
