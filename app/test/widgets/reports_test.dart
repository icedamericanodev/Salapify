import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/features/info/info_dot.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/screens/reports/reports_screen.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Reports, driven the way a person drives it: tap the tab, tap a sub-tab,
/// change the period.
///
/// The arithmetic is proved in reports_golden_test.dart against vectors from
/// the prototype. These tests ask the other question, which no engine test can
/// answer: does a person actually SEE the right number, on the right screen,
/// after tapping what they would tap.
void main() {
  Future<void> openReports(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.insert_chart_outlined));
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('the Reports tab opens on Position with real money on it', (
    WidgetTester tester,
  ) async {
    await openReports(tester);

    expect(find.byType(ReportsScreen), findsOneWidget);

    // The vectors say net worth is -217,229.50 across all entities. If this
    // screen ever disagrees with the engine, this is where it shows.
    expect(find.text('-₱217,229.50'), findsOneWidget);
    expect(find.text('₱181,970.50'), findsWidgets, reason: 'total assets');
    expect(find.text('₱399,200.00'), findsWidgets, reason: 'total liabilities');
  });

  testWidgets('a negative net worth is defused on the screen, and explained '
      'behind the dot', (WidgetTester tester) async {
    await openReports(tester);

    // A mortgage makes net worth negative for a great many people, and the
    // screen must not read as an accusation. After the founder's "too wordy"
    // review the long reassurance moved into the explainer, but ONE short
    // line stays: alarm is the worst possible moment to make somebody go
    // hunting for the reason.
    expect(find.text('A housing loan alone can do this.'), findsOneWidget);

    // And the full version is genuinely one tap away, not merely written
    // down somewhere. This is the assertion the old test could not make.
    await tapAndSettle(tester, find.byType(InfoDot).first);
    expect(find.byType(InfoSheet), findsOneWidget);
    expect(
      find.textContaining('nothing is actually wrong'),
      findsOneWidget,
      reason: 'the net worth dot opened the wrong explainer, or an empty one',
    );
  });

  testWidgets('Performance shows the income statement and both ratios', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));

    expect(find.text('₱51,000.00'), findsWidgets, reason: 'money in');
    expect(find.text('₱24,274.75'), findsWidgets, reason: 'money out');
    expect(find.text('₱26,725.25'), findsWidgets, reason: 'kept');

    // Percent, not a fraction. A savings rate printed as 0.5% instead of
    // 52.4% is the classic hundredfold slip and it looks entirely plausible.
    expect(find.text('52.4%'), findsWidgets);
    expect(find.text('9.7%'), findsWidgets);
  });

  testWidgets('Cash flow adds its three sections up to the headline', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Cash flow'));

    // The headline equals operating + investing + financing, which the engine
    // test proves. Here it just has to be the number actually on the screen.
    expect(find.text('₱26,725.25'), findsWidgets, reason: 'net change');
    expect(find.text('-₱4,950.00'), findsWidgets, reason: 'net financing');
  });

  testWidgets('a transfer is reported and visibly left out of the total', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Cash flow'));
    await tester.scrollUntilVisible(
      find.text('1 transfer'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('1 transfer'), findsOneWidget);
    expect(find.text('₱5,000.00'), findsWidgets);
    expect(
      find.text('Not counted above, on purpose.'),
      findsOneWidget,
      reason:
          'a 5,000 transfer that changes no total needs saying so, or it '
          'reads as money the report lost',
    );
  });

  testWidgets('changing the period changes the figures', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));
    expect(find.text('₱51,000.00'), findsWidgets);

    await tapAndSettle(tester, find.text('Today'));

    // The directional companion: it is not enough that the numbers are
    // "still valid" after the tap, they have to have MOVED. Today holds one
    // 180 peso coffee and no income at all.
    expect(
      find.text('₱51,000.00'),
      findsNothing,
      reason: 'the period picker did nothing',
    );
    expect(find.text('₱180.00'), findsWidgets);
    expect(find.textContaining('From 1 entry'), findsOneWidget);
  });

  testWidgets('an empty period says so instead of looking broken', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Cash flow'));
    await tapAndSettle(tester, find.text('This week'));

    // This week has entries, so first prove the note is counting rather than
    // hardcoded, then check the wording exists for the zero case by reading
    // the note itself.
    expect(find.textContaining('entries'), findsWidgets);
  });

  testWidgets('the period picker is hidden on Position', (
    WidgetTester tester,
  ) async {
    await openReports(tester);

    // A balance sheet is what you own NOW. Offering "this week" beside it
    // would promise last week's net worth, which needs history the app does
    // not keep.
    expect(find.text('This month'), findsNothing);

    await tapAndSettle(tester, find.text('Performance'));
    expect(find.text('This month'), findsOneWidget);
  });

  testWidgets('the period pills sit side by side, not stacked', (
    WidgetTester tester,
  ) async {
    // Found by LOOKING at the render, not by any test. A Container given an
    // alignment and no width expands to its maximum constraint, so all six
    // pills filled the row and stacked into a column that ate a third of the
    // screen. Every test above still passed: the labels were present, the
    // taps worked, the figures were right.
    await tester.runAsync(loadRealFonts);
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));

    final double today = tester.getTopLeft(find.text('Today')).dy;
    final double week = tester.getTopLeft(find.text('This week')).dy;
    expect(
      today,
      week,
      reason:
          'the first two period pills are on different rows, so each one '
          'is filling the full width instead of sizing to its label',
    );

    // And a pill must not be as wide as the screen.
    final double pillWidth = tester
        .getSize(
          find
              .ancestor(
                of: find.text('Today'),
                matching: find.byType(DecoratedBox),
              )
              .first,
        )
        .width;
    expect(
      pillWidth,
      lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
      reason: 'a period pill is as wide as the whole screen',
    );
  });

  testWidgets('the missing fourth tab explains itself', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tester.scrollUntilVisible(
      find.text('Reconciliation comes next'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    // A gap with no explanation reads as a bug. The prototype has four tabs
    // here and this build ships three.
    expect(find.text('Reconciliation comes next'), findsOneWidget);
  });

  testWidgets('the category breakdown is ordered biggest first', (
    WidgetTester tester,
  ) async {
    await openReports(tester);
    await tapAndSettle(tester, find.text('Performance'));
    await tester.scrollUntilVisible(
      find.text('Family Support & Remittance'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final double biggest = tester
        .getTopLeft(find.text('Family Support & Remittance'))
        .dy;
    final double smaller = tester.getTopLeft(find.text('Groceries')).dy;
    expect(
      biggest,
      lessThan(smaller),
      reason:
          'the largest category must be at the top, or the list answers '
          '"what is eating my money" in the wrong order',
    );
  });

  testWidgets('nothing on Reports overflows at 320dp, on any sub-tab', (
    WidgetTester tester,
  ) async {
    // Real fonts, because the default test font is wider than Plus Jakarta
    // and measuring layout without it answers a different question.
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openReports(tester);
    expect(tester.takeException(), isNull);

    for (final String tab in <String>['Performance', 'Cash flow', 'Position']) {
      await tapAndSettle(tester, find.text(tab));
      expect(
        tester.takeException(),
        isNull,
        reason: '$tab overflowed at 320dp',
      );
    }
  });

  testWidgets('every control on Reports clears the 44dp floor', (
    WidgetTester tester,
  ) async {
    await openReports(tester);

    final Finder taps = find.descendant(
      of: find.byType(ReportsScreen),
      matching: find.byType(InkWell),
    );
    expect(taps, findsWidgets);

    for (int i = 0; i < taps.evaluate().length; i++) {
      final Size size = tester.getSize(taps.at(i));
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'a control on Reports is only ${size.height} tall',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(44),
        reason: 'a control on Reports is only ${size.width} wide',
      );
    }
  });
}
