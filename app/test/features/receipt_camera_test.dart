import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:salapify/features/log/receipt_camera.dart';

/// The real `DeviceReceiptTextSource`, with a picker that misbehaves.
///
/// THE JOURNEY TESTS CANNOT REACH THIS. They hand the sheet a fake
/// `ReceiptTextSource` that returns a `ReceiptReadFailure` directly, so they
/// prove the right sentence is shown for each failure and prove nothing at
/// all about which failure a real exception BECOMES. That translation lives
/// here, and it was wrong in a way that cost an hour: a
/// `MissingPluginException` was being reported as "the camera could not be
/// opened", which sent the founder to check an emulator whose camera was
/// perfectly fine.
///
/// Only `pickImage` is exercised. The ML Kit half needs a native reader that
/// no test can construct, and pretending otherwise would be a test that
/// passes because it never ran the code.
class _ThrowingPicker extends ImagePicker {
  _ThrowingPicker(this._error);

  final Object _error;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    throw _error;
  }
}

/// A picker that politely returns nothing, the way a cancel does.
class _CancellingPicker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    return null;
  }
}

void main() {
  test('a missing plugin is not reported as a broken camera', () async {
    // The exact exception Flutter raises when Dart code calls a method
    // channel whose native side is not in the installed binary. A hot
    // restart puts new Dart on an older build and produces precisely this,
    // which is why the buttons appeared and nothing behind them worked.
    final DeviceReceiptTextSource source = DeviceReceiptTextSource(
      picker: _ThrowingPicker(
        MissingPluginException(
          'No implementation found for method pickImage on channel '
          'plugins.flutter.io/image_picker',
        ),
      ),
    );

    final ReceiptRead? read = await source.read(ReceiptImageSource.library);

    expect(read, isNotNull);
    expect(
      read!.failure,
      ReceiptReadFailure.notInThisBuild,
      reason:
          'a plugin missing from the build is being reported as a device '
          'problem, which sends the person to check hardware that works',
    );
  });

  test('a real platform refusal is still reported as unavailable', () async {
    // The other half, and the reason the catch has to be ordered rather than
    // broadened. A phone that genuinely has no camera app throws a
    // PlatformException, and answering that with "reinstall the app" would
    // be as wrong in the other direction.
    final DeviceReceiptTextSource source = DeviceReceiptTextSource(
      picker: _ThrowingPicker(
        PlatformException(code: 'no_available_camera', message: 'no camera'),
      ),
    );

    final ReceiptRead? read = await source.read(ReceiptImageSource.camera);

    expect(read, isNotNull);
    expect(read!.failure, ReceiptReadFailure.unavailable);
  });

  test('backing out is null, which is not a failure', () async {
    final DeviceReceiptTextSource source = DeviceReceiptTextSource(
      picker: _CancellingPicker(),
    );

    expect(
      await source.read(ReceiptImageSource.camera),
      isNull,
      reason:
          'a cancel is being turned into a failure, so somebody who changed '
          'their mind is shown a warning about nothing',
    );
  });
}
