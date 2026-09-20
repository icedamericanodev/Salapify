import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/screens/plan/bonus_allocator_card.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The 13th month allocator on Plan.
void main() {
  setUpAll(() async => loadRealFonts());

  const Palette p = Palette.gabi;

  Future<void> pump(
    WidgetTester tester, {
    double width = 320,
    double textScale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            backgroundColor: p.background,
            body: Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: const BonusAllocatorCard(palette: p),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it shows nothing computed until an amount is entered', (
    WidgetTester tester,
  ) async {
    // A card that showed a split of zero on first sight would be three
    // empty rows and a bar at nought, which reads as something already
    // going wrong rather than as a starting line.
    await pump(tester);
    expect(find.textContaining('WHAT LANDS'), findsNothing);
    expect(find.textContaining('Cushion'), findsNothing);
  });

  testWidgets('a quick chip fills it in and the split appears', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('₱50,000.00'));
    await tester.pumpAndSettle();

    expect(find.textContaining('WHAT LANDS'), findsOneWidget);
    // Under the ceiling, so nothing is taxed and the whole 50,000 lands.
    expect(find.textContaining('₱50,000.00'), findsWidgets);
    expect(find.textContaining('₱25,000.00'), findsWidgets, reason: '50%');
    expect(find.textContaining('₱15,000.00'), findsWidgets, reason: '30%');
    expect(find.textContaining('₱10,000.00'), findsWidgets, reason: '20%');
  });

  testWidgets('a bonus over the ceiling shows the tax and says it is rough', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('₱120,000.00'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Taxed, above the allowance'), findsOneWidget);
    expect(
      find.textContaining('₱6,000.00'),
      findsWidgets,
      reason: '20% of 30k',
    );
    expect(
      find.textContaining('rough 20%'),
      findsOneWidget,
      reason: 'a tax estimate was shown as though it were exact',
    );
  });

  testWidgets('an exempt bonus shows no tax rows at all', (
    WidgetTester tester,
  ) async {
    // The other half. Printing "taxed: ₱0.00" on an exempt bonus invites
    // somebody to think tax was taken when none was.
    await pump(tester);
    await tester.tap(find.text('₱25,000.00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Taxed, above the allowance'), findsNothing);
    expect(find.textContaining('rough 20%'), findsNothing);
  });

  testWidgets('the allowance bar carries its figures, not only a colour', (
    WidgetTester tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('₱90,000.00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('of ₱90,000'), findsOneWidget);
    expect(
      find.textContaining('whole year together'),
      findsOneWidget,
      reason:
          'the bar implied a fresh allowance for this payment, when it '
          'covers the whole year',
    );
  });

  testWidgets('no bucket names a bank, a fund or a rate', (
    WidgetTester tester,
  ) async {
    // The spec routes the first bucket to "SeaBank, Maya, Pag-IBIG MP2".
    await pump(tester);
    await tester.tap(find.text('₱50,000.00'));
    await tester.pumpAndSettle();

    for (final String banned in <String>[
      'SeaBank',
      'GoTyme',
      'Maya',
      'MP2',
      'Pag-IBIG',
      'high-yield',
      'per annum',
    ]) {
      expect(
        find.textContaining(banned),
        findsNothing,
        reason: 'the card recommended "$banned"',
      );
    }
    expect(
      find.textContaining('yours to decide'),
      findsOneWidget,
      reason: 'it stayed silent about where the money goes without saying why',
    );
  });

  testWidgets('it logs nothing, and says so', (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(find.text('₱50,000.00'));
    await tester.pumpAndSettle();
    expect(find.textContaining('has not logged anything'), findsOneWidget);
  });

  testWidgets('the dot opens the explanation', (WidgetTester tester) async {
    await pump(tester);
    await tester.tap(
      find.bySemanticsLabel('How a 13th month is taxed and split'),
    );
    await tester.pumpAndSettle();
    expect(find.text(infoContent[InfoTopic.bonusSplit]!.title), findsOneWidget);
  });

  testWidgets('nothing overflows at 320dp, nor at 1.5x text', (
    WidgetTester tester,
  ) async {
    await pump(tester, textScale: 1.5);
    await tester.tap(find.text('₱120,000.00'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
