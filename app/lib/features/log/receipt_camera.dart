import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Getting the words off a receipt the person photographed.
///
/// An interface with one method, because everything interesting about this
/// feature is on the far side of two plugins that cannot run in a test. The
/// PARSING is already covered by `receipt_ocr.dart` and its vectors, so what
/// is left here is the handover, the failures and the cleanup, and those are
/// only testable if something can stand in for the camera.
///
/// Nothing in this file interprets the text. It hands whatever the reader saw
/// to `parseReceiptText`, which is the same function the paste box and the
/// samples already go through, so a photographed receipt and a pasted one
/// cannot disagree about what a receipt means.
abstract class ReceiptTextSource {
  /// Opens the camera or the photo library and returns what it could read.
  ///
  /// Null means the person backed out, which is not an error and must not
  /// produce a message.
  Future<ReceiptRead?> read(ReceiptImageSource from);
}

/// Where the picture comes from.
///
/// BOTH, and the second one is not a convenience. An Android emulator's back
/// camera renders a synthetic room, so a photo taken on the founder's
/// emulator can never contain a receipt: choosing an image is the only way
/// this feature can be tried anywhere except a real phone. It is also the
/// better path for a receipt already saved as a screenshot, which is how
/// most GCash and Maya receipts arrive in the first place.
enum ReceiptImageSource { camera, library }

/// What the reader got, successfully or not.
class ReceiptRead {
  const ReceiptRead.text(this.text) : failure = null;
  const ReceiptRead.failed(this.failure) : text = '';

  /// Everything the reader saw, newline separated, in reading order.
  final String text;

  /// Why there is nothing to work with, in words a person can act on.
  final ReceiptReadFailure? failure;

  bool get ok => failure == null && text.trim().isNotEmpty;
}

/// The ways this can come back with nothing.
///
/// An enum rather than a message, so the sentence a person reads lives on the
/// screen with the rest of the copy instead of down here.
enum ReceiptReadFailure {
  /// The image opened and held no readable text. The usual cause is a blurry
  /// or badly lit photo, and it is the one the person can do something about.
  noText,

  /// The camera, the photo library or the reader would not start. A phone
  /// with no camera app, a revoked gallery permission, a reader that failed
  /// to initialise.
  unavailable,
}

/// The real one: the phone's camera app, then ML Kit, then delete the file.
///
/// DELETING THE FILE IS PART OF THE JOB, not tidying up afterwards. The
/// picker writes the photo into Salapify's own cache directory, where it
/// would otherwise sit indefinitely. That file is a picture of somebody's
/// shopping, with their card's last four digits on it often enough, kept by
/// an app whose whole promise is that their money stays on their phone and
/// under their control. Salapify needs the words for a few milliseconds and
/// has no use for the image ever again.
class DeviceReceiptTextSource implements ReceiptTextSource {
  DeviceReceiptTextSource({ImagePicker? picker, TextRecognizer? recognizer})
    : _picker = picker ?? ImagePicker(),
      _recognizer =
          recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final ImagePicker _picker;

  /// Latin only, which is what the bundled model covers and what a Philippine
  /// receipt is printed in. The other scripts are separate downloads and
  /// Salapify does not download models.
  final TextRecognizer _recognizer;

  @override
  Future<ReceiptRead?> read(ReceiptImageSource from) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: from == ReceiptImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        // Enough for a receipt's small print and well under what the reader
        // wants to chew on. A modern phone camera hands back 12 megapixels
        // of a piece of paper, which is slower to read and no more accurate.
        maxWidth: 2000,
        imageQuality: 88,
      );
    } on Object {
      // Deliberately broad. Every failure here is somebody else's plugin
      // saying no on a device Salapify cannot inspect, and the answer to all
      // of them is the same sentence on screen. A crash instead would take
      // down the sheet somebody had just started filling in.
      return const ReceiptRead.failed(ReceiptReadFailure.unavailable);
    }

    // Backed out of the camera. Not a failure, and must not say anything.
    if (file == null) return null;

    try {
      final RecognizedText result = await _recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final String text = result.text.trim();
      return text.isEmpty
          ? const ReceiptRead.failed(ReceiptReadFailure.noText)
          : ReceiptRead.text(text);
    } on Object {
      return const ReceiptRead.failed(ReceiptReadFailure.unavailable);
    } finally {
      // In a `finally`, so the picture goes whether the read worked, found
      // nothing, or threw. A failed read is exactly when a stray photo of
      // somebody's receipt is most likely to be left behind.
      await _deleteQuietly(file.path);
    }
  }

  /// Best effort, and silent when it cannot.
  ///
  /// There is nothing useful to tell somebody who has just logged a purchase
  /// about a cache file that would not delete, and the OS clears that
  /// directory on its own schedule anyway. Never let this take down a read
  /// that otherwise succeeded.
  static Future<void> _deleteQuietly(String path) async {
    try {
      final File f = File(path);
      if (f.existsSync()) await f.delete();
    } on Object {
      // Nothing to do and nothing worth saying.
    }
  }

  /// Frees the native reader. The sheet closes far more often than the app
  /// does, and a recogniser per opening would leak one each time.
  Future<void> dispose() => _recognizer.close();
}
