// Specimen sheets for the f4.59 looks, so a theme decision is made by LOOKING.
// Not a `_test` file; run with --update-goldens to write test/shots, then look.
// Dark first, the mode the founder uses.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';
import 'package:salapify/widgets/salapify_icon.dart';

import 'screens_shot.dart' show loadRealFonts;

// A compact "one card" specimen that exercises the palette the way a real screen
// does: page, card, kicker, a hero amount, secondary and muted text, a primary
// action, a warning, and the win gold. Every colour is a Barako getter, so it
// paints whatever palette is active.
Widget _specimen(String title, String hint) {
  return Container(
    color: Barako.background,
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.title),
        const SizedBox(height: 2),
        Text(hint, style: AppText.small),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Barako.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NET WORTH', style: Barako.kickerStyle),
              const SizedBox(height: 4),
              Text('₱128,450.00', style: AppText.amountLg),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('You own ₱150,000', style: AppText.small),
                  const SizedBox(width: 10),
                  Text(
                    'You owe ₱21,550',
                    style: AppText.small.tint(Barako.warningStrong),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Barako.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Log',
                      style: AppText.label.tint(Barako.onPrimary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SalapifyGlyph('celebrate', size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Streak kept',
                    style: AppText.small.tint(Barako.celebrate),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Secondary text, muted text, and a faint line.',
          style: AppText.small.tint(Barako.muted),
        ),
      ],
    ),
  );
}

Future<void> _shot(
  WidgetTester tester,
  String key,
  String label,
  String hint,
) async {
  await loadRealFonts(tester);
  final theme = themeForKey(key);
  tester.view.physicalSize = const Size(1080, 1400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.currentTheme = theme;
  Barako.current = theme.dark;
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Barako.background,
        body: Center(child: _specimen(label, hint)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/theme-$key-dark.png'),
  );
}

void main() {
  testWidgets(
    'Palawan Lagoon',
    (t) => _shot(
      t,
      'palawan',
      'Palawan Lagoon',
      'Emerald and cyan on lagoon navy.',
    ),
  );
  testWidgets(
    'Mayon Sunset',
    (t) => _shot(t, 'mayon', 'Mayon Sunset', 'Warm coral over a dusk plum.'),
  );
  testWidgets(
    'BGC Obsidian',
    (t) => _shot(
      t,
      'obsidian',
      'BGC Obsidian',
      'Neon cyan on near-black titanium.',
    ),
  );
  testWidgets(
    'Pearl',
    (t) => _shot(t, 'pearl', 'Pearl', 'Clean blue on a soft pearl white.'),
  );
}
