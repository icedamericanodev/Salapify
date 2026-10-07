// Renders the Decision Score gauge at three bands so it can be looked at.
// Not *_test.dart, so `flutter test` never collects it.
//   flutter test test/mindset_gauge_shot.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';
import 'package:salapify/widgets/mindset_score_gauge.dart';

import 'screens_shot.dart' show loadRealFonts;

void main() {
  testWidgets('score gauge, three bands, dark', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1860, 760);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    Widget cell(int score, int band, String label) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MindsetScoreGauge(score: score, band: band, animate: false),
        const SizedBox(height: 10),
        Text(label, style: AppText.small.tint(Barako.textSecondary)),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                cell(89, 1, 'Fits comfortably'),
                cell(72, 2, 'Worth a pause'),
                cell(34, 3, 'Big impact'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-gauge-dark.png'),
    );
  });
}
