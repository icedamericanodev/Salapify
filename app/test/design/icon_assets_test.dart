// The launcher icon exists, at every density, in every layer.
//
// This guard exists because a missing density is INVISIBLE until somebody
// installs the app on a phone with that screen. Android silently falls back to
// the nearest density and upscales it, so the only symptom is a slightly soft
// icon on one class of device, which nobody reports and nobody notices in a
// review. A test is the only thing that can see it.
//
// It also pins the three things that are easy to get wrong once and never look
// at again: that the adaptive icon declares all three layers, that the
// monochrome layer is one of them, and that the background is the app's own
// hero ramp rather than a colour somebody typed.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The five density buckets Android ships, and the pixel size each one wants
/// for a 48dp launcher icon.
const _legacy = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// The adaptive layers are 108dp, so 108/48 of the legacy size.
int _adaptiveFor(int legacy) => legacy * 108 ~/ 48;

String get _res => 'android/app/src/main/res';

/// The width of a PNG, read from its IHDR chunk.
///
/// Deliberately NOT decoded with an image package: the point is to check the
/// file on disk is a real PNG of the right size, and a 12 byte header read
/// cannot be fooled by a resize happening somewhere in a decode path.
int _pngWidth(File f) {
  final b = f.readAsBytesSync();
  expect(b.sublist(0, 8), [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
  ], reason: '${f.path} is not a PNG');
  return (b[16] << 24) | (b[17] << 16) | (b[18] << 8) | b[19];
}

void main() {
  test('every density carries every launcher layer, at the right size', () {
    for (final entry in _legacy.entries) {
      final dir = '$_res/mipmap-${entry.key}';
      final adaptive = _adaptiveFor(entry.value);

      final checks = <String, int>{
        'ic_launcher.png': entry.value,
        'ic_launcher_foreground.png': adaptive,
        'ic_launcher_monochrome.png': adaptive,
      };

      for (final c in checks.entries) {
        final f = File('$dir/${c.key}');
        expect(
          f.existsSync(),
          isTrue,
          reason:
              'Missing $dir/${c.key}. Android would silently upscale a '
              'neighbouring density and only that class of phone would look '
              'wrong. Run: python3 tool/build_icons.py',
        );
        expect(
          _pngWidth(f),
          c.value,
          reason: '$dir/${c.key} should be ${c.value}px wide for ${entry.key}',
        );
      }
    }
  });

  test('the adaptive icon declares all three layers, monochrome included', () {
    for (final name in ['ic_launcher', 'ic_launcher_round']) {
      final xml = File('$_res/mipmap-anydpi-v26/$name.xml');
      expect(xml.existsSync(), isTrue, reason: 'Missing $name.xml');
      final s = xml.readAsStringSync();

      expect(s, contains('<background'), reason: '$name has no background');
      expect(s, contains('<foreground'), reason: '$name has no foreground');

      // The one that is easy to skip and expensive to skip. Android 16 QPR2
      // forces themed icons and apps cannot opt out; without this layer the
      // system invents one from the artwork and nobody chose what it looks
      // like.
      expect(
        s,
        contains('<monochrome'),
        reason:
            '$name has no monochrome layer, so Android will generate a themed '
            'icon from the artwork and the result is not ours to predict',
      );
    }
  });

  test(
    'the icon background is the app hero ramp, not a colour somebody typed',
    () {
      final bg = File('$_res/drawable/ic_launcher_background.xml');
      expect(bg.existsSync(), isTrue);
      final s = bg.readAsStringSync();

      // The exact three stops of heroGradient in lib/design/tokens.dart. If the
      // palette moves and the icon does not, this is what says so.
      for (final stop in ['#FFFFD9B0', '#FFFEC078', '#FFFB9C52']) {
        expect(
          s,
          contains(stop),
          reason:
              'The icon background lost $stop. It must stay byte identical to '
              'heroGradient in lib/design/tokens.dart, or the icon and the app '
              'hero panel drift apart.',
        );
      }
    },
  );

  test('the manifest points at both the square and the round icon', () {
    final m = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(m, contains('android:icon="@mipmap/ic_launcher"'));
    expect(m, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
  });
}
