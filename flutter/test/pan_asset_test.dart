// Pan's four faces must actually exist, be declared, and be small.
//
// This is the one guard that matters most on an asset build, because a
// missing asset fails QUIETLY. Image.asset falls back to the code-drawn cup
// (deliberately, so a hole never appears where the character should be), and
// that graceful fallback is exactly what would hide a typo'd path or a file
// left out of pubspec. The app would look almost right, the artwork the
// founder installed a whole new APK for would simply never appear, and
// nothing would say a word.
//
// It costs the founder a manual install to ship these. Shipping that install
// and silently getting the old drawn cup would be the worst outcome available.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/widgets/pan_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every mood maps to a distinct asset path', () {
    final paths = PanMood.values.map(panAssetFor).toList();
    expect(
      paths.toSet().length,
      PanMood.values.length,
      reason: 'two moods sharing one face means one of them is wrong',
    );
    for (final p in paths) {
      expect(p.startsWith('assets/pan/'), isTrue, reason: p);
      expect(p.endsWith('.png'), isTrue, reason: p);
    }
  });

  test('every face exists on disk', () {
    for (final mood in PanMood.values) {
      final path = panAssetFor(mood);
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            'Missing $path. Image.asset would fall back to the drawn cup and '
            'say nothing, so the founder would install a new APK and get the '
            'old Pan.',
      );
    }
  });

  test('every face is declared in pubspec, or it ships in nothing', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // The directory form covers every file inside it.
    final declared =
        pubspec.contains('- assets/pan/') ||
        PanMood.values.every((m) => pubspec.contains(panAssetFor(m)));
    expect(
      declared,
      isTrue,
      reason:
          'The files exist but are not in the bundle. A file on disk that is '
          'not declared is a file the app cannot see.',
    );
  });

  testWidgets('every face actually loads through the asset bundle', (
    tester,
  ) async {
    // Existing on disk is not the same as loading. This is what catches a
    // truncated or corrupt PNG, which the disk check above would happily pass.
    for (final mood in PanMood.values) {
      final path = panAssetFor(mood);
      final data = await rootBundle.load(path);
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '$path loaded but is suspiciously small',
      );
      final header = data.buffer.asUint8List(0, 8);
      expect(
        const ListEquality().equals(header, pngMagic),
        isTrue,
        reason: '$path is not a PNG',
      );
    }
  });

  test('the set stays small enough to be worth an install', () {
    // Sums the DIRECTORY, not the four known paths. pubspec declares
    // `- assets/pan/` as a whole directory, so the bundle is whatever is in
    // that folder, and a guard that only measures the files it already knows
    // about cannot see the thing most likely to go wrong.
    var total = 0;
    for (final f in Directory('assets/pan').listSync().whereType<File>()) {
      total += f.lengthSync();
    }
    expect(
      total,
      lessThan(300 * 1024),
      reason:
          'Pan is ${(total / 1024).round()}KB. The 1024px sources are several '
          'megabytes and are cut to roughly 145KB for the four of them; a '
          'jump back means someone dropped a full-resolution render in '
          'without processing it.',
    );
  });

  test('nothing but Pan lives in the Pan folder', () {
    // The near miss that earned this test: working out the theme tint meant
    // writing eight intermediate PNGs, and the obvious place to put them was
    // next to the art they came from. They were cleaned up by memory alone.
    //
    // Had they survived, every one would have shipped, because pubspec
    // declares the DIRECTORY. Worse, the size guard above would still have
    // passed, and the first symptom would have arrived days later as a
    // Shorebird patch refusing to build against a changed asset bundle. That
    // is a long way from the mistake, in a message that says nothing about
    // stray files.
    final declared = PanMood.values.map(panAssetFor).toSet();
    final found = Directory('assets/pan')
        .listSync()
        .whereType<File>()
        // Normalise separators so this reads the same on a Windows checkout.
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    final strays = found.difference(declared);
    expect(
      strays,
      isEmpty,
      reason:
          'Unexpected file(s) in assets/pan: ${strays.join(', ')}.\n'
          'pubspec declares the whole directory, so these WILL ship. Either '
          'delete them, or if one is a real new asset (pan.riv, say), add it '
          'to the declared set here on purpose. Note a genuinely new asset '
          'also means a new base APK and a manual install, so this failing is '
          'the cheap moment to find that out.',
    );
  });
}

/// The eight bytes every PNG starts with.
final pngMagic = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

class ListEquality {
  const ListEquality();
  bool equals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
