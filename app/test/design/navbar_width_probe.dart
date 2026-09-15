// A measurement, not a test. Verifies two claims made by a UX review before
// either is acted on:
//
//   1. "Accounts" already wraps to two lines at 320dp with FOUR tabs, today.
//   2. A FIFTH tab breaks three of five labels at 320dp.
//
// No `_test` suffix, so `flutter test` never collects it. It is run by hand:
//   flutter test test/design/navbar_width_probe.dart --plain-name probe
// and the numbers go in the decision, not in a guard.
//
// REAL FONTS ARE NOT OPTIONAL HERE. Flutter's default test font is wider than
// Plus Jakarta Sans, the face the app ships, so a width measured without them
// answers a question about a font nobody sees. CLAUDE.md records a layout test
// that got exactly this wrong.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/design/type.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The tab bar's own geometry, read from kit.dart rather than assumed.
///
/// Each tab is an `Expanded` inside a Row that also holds a 10dp gap and the
/// Log pill, inside padding of `gutter` on each side.
double _tabColumnWidth(double screen, int tabs, double pillWidth) {
  final usable = screen - gutter * 2 - 10 - pillWidth;
  return usable / tabs;
}

void main() {
  // What the wrap actually COSTS, rendered rather than reasoned about. The
  // label is inside a Column with mainAxisSize.min, so a second line may
  // simply make the bar taller rather than clip anything, and "it wraps" is
  // not the same finding as "it is broken".
  testWidgets('shot', (tester) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(hapon),
        home: Scaffold(
          backgroundColor: hapon.bg,
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NavBar(active: 0, onTab: (_) {}, onLog: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../shots/out/probe-navbar-320.png'),
    );
  });

  testWidgets('probe', (tester) async {
    await tester.runAsync(loadRealFonts);

    // Measure the Log pill once, from the real widget.
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(hapon),
        home: Scaffold(body: NavBar(active: 0, onTab: (_) {}, onLog: () {})),
      ),
    );
    await tester.pumpAndSettle();

    final pill = tester.getSize(
      find
          .ancestor(of: find.text('Log'), matching: find.byType(Container))
          .first,
    );

    for (final scale in [1.0, 1.3]) {
      for (final screen in [320.0, 360.0, 412.0]) {
        for (final labels in [
          ['Home', 'Ledger', 'Plan', 'Accounts'],
          ['Home', 'Ledger', 'Plan', 'Accounts', 'Insights'],
        ]) {
          final column = _tabColumnWidth(screen, labels.length, pill.width);
          final broken = <String>[];
          for (final label in labels) {
            final tp = TextPainter(
              text: TextSpan(
                text: label,
                style: TypeScale.tab(const Color(0xFF000000)),
              ),
              textDirection: TextDirection.ltr,
              textScaler: TextScaler.linear(scale),
            )..layout(maxWidth: column);
            // One line at 1.0x is about 15dp. Anything taller wrapped.
            if (tp.height > 15 * scale + 2) {
              broken.add('$label(${tp.width.toStringAsFixed(1)}w '
                  '${tp.height.toStringAsFixed(0)}h)');
            }
          }
          debugPrint(
            'screen=${screen.toInt()} scale=$scale tabs=${labels.length} '
            'column=${column.toStringAsFixed(1)} '
            'pill=${pill.width.toStringAsFixed(1)} '
            'WRAPPED=${broken.isEmpty ? "none" : broken.join(", ")}',
          );
        }
      }
    }
  });
}
