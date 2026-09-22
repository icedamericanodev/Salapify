// The one choke point for saving bytes straight to the device through the
// system save dialog. On Android this is the storage access framework: the
// plugin itself writes the bytes to the location the user picked (no storage
// permission, matching the privacy policy's "system file picker" wording), and
// the string it returns is NOT the real destination, it is a fabricated
// Downloads path. Writing to that returned path on Android would silently drop
// a second plaintext copy of the finances into local Downloads that the user
// never chose, so the write-fallback below runs ONLY on desktop platforms,
// where the dialog genuinely returns a real path without writing. There the
// write always runs (an explicit save must never silently keep stale content)
// and a failure propagates to the caller instead of reporting success.
//
// A module-level busy flag makes concurrent saves impossible across every
// caller (backup, CSV, Excel, PDF), the same job _guard does for the share
// paths. No temp file is ever written on this path.

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

bool _saving = false;

/// Returns true when the file was saved, false when the user cancelled or a
/// save is already in flight. Throws on a desktop write failure so the caller
/// can tell the user instead of claiming success.
Future<bool> saveBytesToDevice(List<int> bytes, String filename) async {
  if (_saving) return false;
  _saving = true;
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $filename',
      fileName: filename,
      bytes: Uint8List.fromList(bytes),
    );
    if (path == null) return false;
    final desktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);
    if (desktop) {
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  } finally {
    _saving = false;
  }
}
