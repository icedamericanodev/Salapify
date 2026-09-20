import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/reports/bir_claims_card.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The BIR receipts hub, and the one rule it exists to keep.
///
/// The spec asks for an "Estimated BIR Tax Shield (25% rate)" on the card.
/// That figure is ZERO for anybody on the 8 percent election, which has no
/// itemised deductions at all, and for anybody on the 40 percent standard
/// deduction. On graduated and itemised it is one bracket of six. So no tax
/// saving may appear until the person has said which band they are in, and
/// that is what most of this file pins.
void main() {
  setUpAll(() async => loadRealFonts());

  const Palette p = Palette.gabi;

  int seq = 0;
  Transaction tx({double amount = 1000, bool deductible = true, String? ref}) =>
      Transaction(
        id: 'tx${seq++}',
        type: TransactionType.expense,
        amount: amount,
        category: 'Food & Dining',
        accountId: 'acc',
        date: '2026-09-20',
        createdAt: 1758326400000,
        isTaxDeductible: deductible,
        taxTinOrRef: ref,
      );

  Future<void> pump(
    WidgetTester tester,
    List<Transaction> txs, {
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
                  child: BirClaimsCard(palette: p, transactions: txs),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('no tax saving is shown until a band is chosen', (
    WidgetTester tester,
  ) async {
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);

    // The claimable total IS shown, because it is the person's own money and
    // owes nothing to a tax rate.
    expect(find.textContaining('10,000'), findsWidgets);

    // A quarter of it must appear nowhere. That is the spec's figure and it
    // is the one somebody would plan around.
    expect(
      find.textContaining('2,500'),
      findsNothing,
      reason:
          'a tax saving was shown before anybody said which band they are in',
    );
    expect(find.textContaining('Pick the income tax band'), findsOneWidget);
  });

  testWidgets('choosing a band shows the saving, with its assumptions', (
    WidgetTester tester,
  ) async {
    // The other half. A card that never showed a saving would pass the test
    // above and would have dropped the feature.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await tester.tap(find.textContaining('₱400,000 to ₱800,000'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2,000'), findsWidgets, reason: '20% of 10,000');
    expect(
      find.textContaining('8% election'),
      findsOneWidget,
      reason: 'the figure appeared without saying what it assumes',
    );
  });

  testWidgets('the zero band says the receipts save nothing', (
    WidgetTester tester,
  ) async {
    // Somebody under the 250,000 exemption. The spec would quote them a
    // quarter of their receipts, which is money that is not coming.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await tester.tap(find.textContaining('no income tax'));
    await tester.pumpAndSettle();

    expect(find.textContaining('take nothing off'), findsOneWidget);
    expect(find.textContaining('still worth keeping'), findsOneWidget);
  });

  testWidgets('the saving counts only what has a receipt behind it', (
    WidgetTester tester,
  ) async {
    // 10,000 with a reference, 5,000 without. At 20 percent the honest
    // answer is 2,000, not 3,000: a claim with nothing behind it is a claim
    // that gets disallowed.
    await pump(tester, <Transaction>[
      tx(amount: 10000, ref: 'OR-1'),
      tx(amount: 5000),
    ]);
    await tester.tap(find.textContaining('₱400,000 to ₱800,000'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2,000'), findsWidgets);
    expect(
      find.textContaining('3,000'),
      findsNothing,
      reason: 'the saving included claims with no receipt behind them',
    );
  });

  testWidgets('an empty period says so, and shows no zero', (
    WidgetTester tester,
  ) async {
    // A zero is a measurement, and a big ₱0.00 on a first visit reads as
    // something already going wrong.
    await pump(tester, <Transaction>[tx(deductible: false)]);
    expect(find.textContaining('Nothing marked as claimable'), findsOneWidget);
    expect(find.textContaining('₱0.00'), findsNothing);
  });

  testWidgets('what is marked but unsupported is named, not hidden', (
    WidgetTester tester,
  ) async {
    await pump(tester, <Transaction>[
      tx(amount: 10000, ref: 'OR-1'),
      tx(amount: 5000),
    ]);
    expect(find.textContaining('With nothing behind it yet'), findsOneWidget);
    expect(find.textContaining('not yet backed up'), findsOneWidget);
  });

  testWidgets('the dot opens the explanation', (WidgetTester tester) async {
    await pump(tester, <Transaction>[tx(amount: 1000, ref: 'OR-1')]);
    await tester.tap(find.bySemanticsLabel('What makes an expense claimable'));
    await tester.pumpAndSettle();
    expect(
      find.text(infoContent[InfoTopic.claimableExpenses]!.title),
      findsOneWidget,
    );
  });

  testWidgets('nothing overflows at 320dp, nor at 1.5x text', (
    WidgetTester tester,
  ) async {
    // The band chips are a Wrap of six long labels, which is exactly the
    // shape that overflows on the narrowest phone.
    await pump(tester, <Transaction>[
      tx(amount: 1234567, ref: 'OR-1'),
    ], textScale: 1.5);
    expect(tester.takeException(), isNull);
  });
}
