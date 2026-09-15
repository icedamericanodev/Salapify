// Saving a file straight to the phone, with no share sheet in the way.
//
// The founder asked for exactly this: "what if i do not like to share it but
// just want to save in my device?". Sharing and saving are different acts.
// Sharing sends your finances somewhere; saving puts them down where you
// choose. A backup tool that only offers the first is asking you to send your
// whole ledger through Gmail to keep a copy.
//
// Ported from flutter/lib/data/save_to_device.dart, including the Android trap
// below, which is the kind of thing only a shipped app finds.
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

bool _saving = false;

/// Write bytes to wherever the person picks. True when saved, false when they
/// cancelled or a save is already running.
///
/// THE ANDROID TRAP, and why the write below is desktop only. On Android this
/// is the Storage Access Framework: the PLUGIN writes the bytes to the location
/// the person chose, and the string it hands back is NOT that location, it is a
/// fabricated Downloads path. Writing to that returned path would drop a SECOND
/// plaintext copy of the finances into local Downloads that nobody asked for.
/// So the fallback write runs only on desktop, where the dialog genuinely
/// returns a real path and writes nothing itself.
///
/// It also means no storage permission is ever requested, because the system
/// picker grants access to the one file the person chose and nothing else.
///
/// A module level flag makes two concurrent saves impossible. A file dialog is
/// slow and a second tap is easy.
///
/// Throws on a desktop write failure rather than returning false, so a caller
/// can say what went wrong instead of quietly reporting "cancelled".
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
      // Always, never conditionally: an explicit save must not silently keep
      // whatever was in the file before.
      await File(path).writeAsBytes(bytes, flush: true);
    }
    return true;
  } finally {
    _saving = false;
  }
}
