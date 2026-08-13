// Pan's twelve expressions must exist, load, be declared, and stay lean.
//
// Same reasoning as pan_asset_test for the four mood faces: a missing or
// mis-declared asset fails QUIETLY, because Image.asset falls back to the
// code-drawn cup. On an asset build that means the founder installs a whole new
// APK (new art is not Shorebird-patchable) and silently gets the old drawn Pan,
// the worst outcome available. These guards make that impossible to ship.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/pan_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every expression maps to a distinct asset path', () {
    final paths = PanExpression.values.map(panExpressionAsset).toList();
    expect(
      paths.toSet().length,
      PanExpression.values.length,
      reason: 'two expressions sharing one file means one of them is wrong',
    );
    for (final p in paths) {
      expect(p.startsWith('assets/pan/expressions/'), isTrue, reason: p);
      expect(p.endsWith('.png'), isTrue, reason: p);
    }
  });

  test('every expression exists on disk', () {
    for (final e in PanExpression.values) {
      final path = panExpressionAsset(e);
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            'Missing $path. Image.asset would fall back to the drawn cup and '
            'say nothing, so the founder installs a new APK and gets the old Pan.',
      );
    }
  });

  test('the expressions directory is declared in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('- assets/pan/expressions/'),
      isTrue,
      reason:
          'The files exist but the directory is not in the bundle. A file on '
          'disk that is not declared is a file the app cannot see.',
    );
  });

  testWidgets('every expression actually loads through the asset bundle', (
    tester,
  ) async {
    for (final e in PanExpression.values) {
      final path = panExpressionAsset(e);
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

  test('the expressions folder holds exactly the twelve declared poses', () {
    // pubspec declares the whole directory, so anything in it ships. A stray
    // (an intermediate crop, a full-resolution render dropped in unprocessed)
    // would ship silently and, worse, could break the next Shorebird build.
    final declared = PanExpression.values
        .map(panExpressionAsset)
        .map((p) => p.replaceAll(r'\', '/'))
        .toSet();
    final found = Directory('assets/pan/expressions')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .toSet();
    expect(
      found.difference(declared),
      isEmpty,
      reason: 'Unexpected file(s) in assets/pan/expressions.',
    );
    expect(
      declared.difference(found),
      isEmpty,
      reason: 'A declared expression has no file.',
    );
  });

  test('the twelve stay lean enough to bundle', () {
    var total = 0;
    for (final f in Directory(
      'assets/pan/expressions',
    ).listSync().whereType<File>()) {
      total += f.lengthSync();
    }
    expect(
      total,
      lessThan(2 * 1024 * 1024),
      reason:
          'Pan expressions are ${(total / 1024).round()}KB. The 1254px source '
          'sheet is several MB; the twelve are cut and downscaled to ~1.3MB. A '
          'jump back means someone dropped full-resolution renders in without '
          'processing them.',
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
