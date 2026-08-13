// Pan's emotion faces must exist, load, be declared, and stay lean.
//
// A missing or mis-declared asset fails QUIETLY: Image.asset falls back to the
// code-drawn cup. On an asset build that means the founder installs a whole new
// APK (new art is not Shorebird-patchable) and silently gets the old drawn Pan,
// the worst outcome available. These guards make that impossible to ship.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/pan_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every emotion maps to a distinct asset path', () {
    final paths = PanEmotion.values.map(panEmotionAsset).toList();
    expect(
      paths.toSet().length,
      PanEmotion.values.length,
      reason: 'two emotions sharing one file means one of them is wrong',
    );
    for (final p in paths) {
      expect(p.startsWith('assets/pan/emotions/'), isTrue, reason: p);
      expect(p.endsWith('.png'), isTrue, reason: p);
    }
  });

  test('every emotion exists on disk', () {
    for (final e in PanEmotion.values) {
      final path = panEmotionAsset(e);
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            'Missing $path. Image.asset would fall back to the drawn cup and '
            'say nothing, so the founder installs a new APK and gets the old Pan.',
      );
    }
  });

  test('the emotions directory is declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('- assets/pan/emotions/'),
      isTrue,
      reason:
          'The files exist but the directory is not in the bundle. A file on '
          'disk that is not declared is a file the app cannot see.',
    );
  });

  testWidgets('every emotion actually loads through the asset bundle', (
    tester,
  ) async {
    for (final e in PanEmotion.values) {
      final path = panEmotionAsset(e);
      final data = await rootBundle.load(path);
      expect(
        data.lengthInBytes,
        greaterThan(1000),
        reason: '$path loaded but is suspiciously small',
      );
      final header = data.buffer.asUint8List(0, 8);
      expect(
        const ListEquality().equals(header, _pngMagic),
        isTrue,
        reason: '$path is not a PNG',
      );
    }
  });

  test('the emotions folder holds exactly the declared feelings', () {
    // pubspec declares the whole directory, so anything in it ships. A stray
    // (an intermediate crop, a full-resolution render dropped in unprocessed)
    // would ship silently and could break the next Shorebird build.
    final declared = PanEmotion.values
        .map(panEmotionAsset)
        .map((p) => p.replaceAll(r'\', '/'))
        .toSet();
    final found = Directory('assets/pan/emotions')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(
      found.difference(declared),
      isEmpty,
      reason: 'Unexpected file(s) in assets/pan/emotions.',
    );
    expect(
      declared.difference(found),
      isEmpty,
      reason: 'A declared emotion has no file.',
    );
  });

  test('the feelings stay lean enough to bundle', () {
    var total = 0;
    for (final f in Directory(
      'assets/pan/emotions',
    ).listSync().whereType<File>()) {
      total += f.lengthSync();
    }
    expect(
      total,
      lessThan(2 * 1024 * 1024),
      reason:
          'Pan emotions are ${(total / 1024).round()}KB. The 1024px sources are '
          'cut and downscaled to a few hundred KB; a jump back means someone '
          'dropped full-resolution renders in without processing them.',
    );
  });
}

final _pngMagic = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

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
