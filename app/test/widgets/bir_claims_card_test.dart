import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/reports/bir_claims_card.dart';

import '../shots/screens_shot.dart' show loadRealFonts;
import 'package:salapify/core/money/money.dart';

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
        amount: Money.fromDouble(amount),
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

  /// The band chips are COLLAPSED by default since 2026-10-07, on founder
  /// direction ("too wordy and the users may feel flooded"). Six chips and
  /// two lines of prompt were the bulk of the card's words and showed on
  /// every visit to anyone with something marked. They are now one tap away.
  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.textContaining('could save on income tax'));
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
    // ONE CONTROL, NOT SIX CHIPS. The picker is collapsed until asked for.
    expect(find.textContaining('could save on income tax'), findsOneWidget);
    expect(
      find.textContaining('₱400,000 to ₱800,000'),
      findsNothing,
      reason: 'the six band chips are showing before anybody asked for them',
    );
  });

  testWidgets('one tap opens the band picker', (WidgetTester tester) async {
    // THE DIRECTIONAL HALF of the collapse. A control that opened nothing
    // would pass the test above and would have dropped the whole feature.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await openPicker(tester);

    expect(find.textContaining('₱400,000 to ₱800,000'), findsOneWidget);
    // The band is YEARLY TAXABLE income. The card is usually filtered to a
    // month, so without this somebody earning 40,000 a month reads "up to
    // 250,000" as their month and picks the 0% band.
    expect(find.textContaining('yearly taxable income'), findsOneWidget);
  });

  testWidgets('choosing a band shows the saving, with its assumptions', (
    WidgetTester tester,
  ) async {
    // The other half. A card that never showed a saving would pass the test
    // above and would have dropped the feature.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await openPicker(tester);
    await tester.tap(find.textContaining('₱400,000 to ₱800,000'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2,000'), findsWidgets, reason: '20% of 10,000');
    expect(
      find.textContaining('8% election'),
      findsOneWidget,
      reason: 'the figure appeared without saying what it assumes',
    );
  });

  testWidgets('the saving says "up to", because it is a ceiling', (
    WidgetTester tester,
  ) async {
    // A TAX PROFESSIONAL REVIEW, 2026-10-07, found this overstating. The
    // engine multiplies the receipts by ONE marginal rate, which is exact
    // only while taxable income stays inside the chosen band after the
    // deduction. Worked on the 2023 table and re-checked by hand:
    //
    //   taxable 420,000, receipts 50,000
    //     before 22,500 + 20% x 20,000   = 26,500
    //     after  15% x 120,000 (370,000) = 18,000
    //     true saving 8,500, the card at 20% showed 10,000
    //
    // So the figure is a ceiling. "This could take off" read as a point
    // estimate; "up to" says what it actually is. The arithmetic is not
    // changed: it is right inside a band, and that is the only claim now.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await openPicker(tester);
    await tester.tap(find.textContaining('₱400,000 to ₱800,000'));
    await tester.pumpAndSettle();

    expect(find.textContaining('At 20%, up to'), findsOneWidget);
    expect(
      find.textContaining('this could take off'),
      findsNothing,
      reason: 'the old wording read as an exact figure',
    );
  });

  testWidgets('the saving names who it applies to', (
    WidgetTester tester,
  ) async {
    // THE OTHER MUST-FIX from the tax review, and the more serious one.
    //
    // TRAIN removed the personal exemptions, and a pure compensation earner
    // has no itemised deductions at all: Sec 34 deductions are for expenses
    // of a trade, business or profession, and personal expenses are
    // expressly non-deductible (Sec 36(A)(1)). An employee also files on the
    // graduated rates, so the old condition "only if you file on the
    // graduated rates with itemised deductions" did not exclude them, and
    // anyone could tick a receipt. They were shown a peso saving they can
    // never claim.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await openPicker(tester);
    await tester.tap(find.textContaining('₱400,000 to ₱800,000'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('business or professional income'),
      findsOneWidget,
      reason: 'an employee is shown a saving that cannot apply to them',
    );
    // And it is INCOME tax. A non-VAT filer on graduated rates still owes 3%
    // percentage tax on gross, which receipts do not touch.
    expect(find.textContaining('income tax'), findsWidgets);
  });

  testWidgets('the zero band says the receipts save nothing', (
    WidgetTester tester,
  ) async {
    // Somebody under the 250,000 exemption. The spec would quote them a
    // quarter of their receipts, which is money that is not coming.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await openPicker(tester);
    await tester.tap(find.textContaining('no income tax'));
    await tester.pumpAndSettle();

    expect(find.textContaining('take nothing off'), findsOneWidget);
    expect(find.text('₱0.00'), findsOneWidget);
    // The explanation of WHY moved behind the dot. The tax review ruled it
    // safe to move: "take nothing off" beside a 0.00 cannot mislead anybody,
    // so the sentence teaches rather than prevents a wrong belief.
    expect(find.textContaining('still worth keeping'), findsNothing);
  });

  testWidgets('Change goes straight to the open picker', (
    WidgetTester tester,
  ) async {
    // With the picker collapsed by default, a plain reset would drop the
    // person back on the collapsed control and make Change cost two taps.
    // Somebody who taps Change has already said they want to pick again.
    await pump(tester, <Transaction>[tx(amount: 10000, ref: 'OR-1')]);
    await openPicker(tester);
    await tester.tap(find.textContaining('₱400,000 to ₱800,000'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('₱400,000 to ₱800,000'),
      findsOneWidget,
      reason: 'Change landed on the collapsed control, not the picker',
    );
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
    await openPicker(tester);
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

    // THE INSTRUCTION WAS FALSE. It said "Tick a business expense when you
    // log it", and the Log sheet has no such control: isTaxDeductible is set
    // only by the scan receipt sheet's switch and by OCR. Somebody following
    // it would look for a tick that does not exist. Filing under the
    // business category is a route that genuinely works, because isClaimable
    // in bir_claims.dart accepts that category on its own.
    expect(find.textContaining('when you log it'), findsNothing);
    expect(find.textContaining('Business & Freelance Ops'), findsOneWidget);
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
    // shape that overflows on the narrowest phone. They are collapsed by
    // default now, so this OPENS the picker first: measuring the collapsed
    // card would pass while never laying the chips out at all, which is the
    // one shape this test exists for.
    await pump(tester, <Transaction>[
      tx(amount: 1234567, ref: 'OR-1'),
    ], textScale: 1.5);
    expect(tester.takeException(), isNull);
    await openPicker(tester);
    expect(find.textContaining('₱400,000 to ₱800,000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
