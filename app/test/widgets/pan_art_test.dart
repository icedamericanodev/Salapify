// Pan's art is wired up: every mood has a file, the app bundles the folder,
// and the moods Pan must never wear are never reached.
//
// The same pattern as info_sheet_test.dart. PanArt builds its path from the
// mood's name, so a mood added to the enum without its PNG would draw
// Flutter's broken-image box on an empty state somebody is looking at for the
// first time. A typed list would be a promise; iterating the enum is a rule.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/pan_art.dart';

void main() {
  test('every PanMood has its image in assets/pan', () {
    final List<String> missing = <String>[
      for (final PanMood m in PanMood.values)
        if (!File(panAsset(m)).existsSync()) panAsset(m),
    ];
    expect(missing, isEmpty, reason: 'moods with no art: $missing');
  });

  test('the app bundles assets/pan/', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      RegExp(r'^\s+- assets/pan/\s*$', multiLine: true).hasMatch(pubspec),
      isTrue,
      reason: 'pubspec.yaml does not list assets/pan/, so no Pan would load',
    );
  });

  test('nothing in lib/ uses the moods Pan never wears', () {
    // Pan never judges spending (D30). The art exists, so the enum names it;
    // reaching it from a screen is the defect.
    final List<String> hits = <String>[];
    for (final FileSystemEntity f in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final String src = f.readAsStringSync();
      for (final String banned in <String>['annoyed', 'tear', 'crying']) {
        if (src.contains('PanMood.$banned')) hits.add('${f.path}: $banned');
      }
    }
    expect(hits, isEmpty);
  });

  testWidgets('Pan is silent to a screen reader and never above 96', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: PanArt(mood: PanMood.wave, size: 200)),
      ),
    );
    final Image img = tester.widget<Image>(find.byType(Image));
    expect(img.excludeFromSemantics, isTrue);
    expect(img.width, panMaxSize);
  });
}
