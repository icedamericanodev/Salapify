// Font-gate specimen for the f4.61 pairing. NOT a `_test` file, so `flutter
// test` never collects it; run with --update-goldens and LOOK at the PNG.
//
// The whole point is the peso and the minus. Fraunces was rejected here once
// because a negative peso figure read as a struck-through number; this sheet
// puts the three faces the pairing proposes side by side, on real peso amounts
// with negatives and a masked PAN, so that failure (or its absence) is visible
// at a glance before any call site is rewired.
//
//   Jakarta (heavy, tabular)      -> the display hero, unchanged
//   IBM Plex Sans (400/600/700)   -> ledger rows and the PDF statement
//   IBM Plex Mono (400/600)       -> masked PANs and reference ids

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts;

const _tnum = [FontFeature.tabularFigures()];

Widget _swatch(String title, String sub, List<Widget> rows) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Jakarta',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: Barako.celebrate,
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            fontFamily: 'Jakarta',
            fontSize: 11,
            color: Barako.muted,
          ),
        ),
        const SizedBox(height: 10),
        ...rows,
      ],
    ),
  );
}

// A right-aligned amount column: the tabular test. Every figure must land on
// the same decimal column, and the negative must not read as struck through.
Widget _ledgerRow(String label, String amount, String family, Color color) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: family,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Barako.text,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontFamily: family,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: _tnum,
          ),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('font pairing specimen, dark', (tester) async {
    await loadRealFonts(tester);
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
    tester.view.physicalSize = const Size(1080, 1720);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Barako.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The display hero stays Jakarta. Shown for the comparison the
                // real screen makes: this big number sits above a ledger.
                _swatch(
                  'DISPLAY HERO  ·  Plus Jakarta Sans',
                  'Net worth, heavy, tabular',
                  [
                    Text(
                      '₱128,450.00',
                      style: TextStyle(
                        fontFamily: 'Jakarta',
                        fontSize: 42,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        color: Barako.text,
                        fontFeatures: _tnum,
                      ),
                    ),
                  ],
                ),
                _swatch(
                  'LEDGER TABLE  ·  IBM Plex Sans',
                  'A column of peso figures, positives and a negative',
                  [
                    _ledgerRow(
                      'Sweldo',
                      '₱35,000.00',
                      'IBMPlexSans',
                      Barako.celebrate,
                    ),
                    _ledgerRow(
                      'Groceries',
                      '-₱1,234.56',
                      'IBMPlexSans',
                      Barako.warningStrong,
                    ),
                    _ledgerRow(
                      'Load',
                      '-₱299.00',
                      'IBMPlexSans',
                      Barako.warningStrong,
                    ),
                    _ledgerRow(
                      'Refund',
                      '₱120.50',
                      'IBMPlexSans',
                      Barako.celebrate,
                    ),
                    _ledgerRow(
                      'Utang paid',
                      '-₱12,000.00',
                      'IBMPlexSans',
                      Barako.warningStrong,
                    ),
                  ],
                ),
                _swatch(
                  'MASKED PAN & REFERENCE ID  ·  IBM Plex Mono',
                  'Fixed-width, tabular, so digits never jitter',
                  [
                    Text(
                      '••••  ••••  ••••  4291',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: Barako.text,
                        fontFeatures: _tnum,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'REF 8F2A-19K0-7C4D',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Barako.textSecondary,
                        fontFeatures: _tnum,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '0 1 2 3 4 5 6 7 8 9   O I l 1',
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        color: Barako.muted,
                        fontFeatures: _tnum,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/font-pairing-dark.png'),
    );
    Barako.currentTheme = themeForKey('palawan');
    Barako.current = themeForKey('palawan').resolve(Brightness.dark);
  });
}
