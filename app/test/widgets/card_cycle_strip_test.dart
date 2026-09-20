import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/accounts/bank_card.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The billing cycle strip under a credit card.
///
/// It MEASURES, in places, so the real fonts are loaded first. Flutter's
/// default test font is wider than Plus Jakarta Sans, so a layout decision
/// can come out one way here and the other way on the founder's phone.
void main() {
  setUpAll(() async => loadRealFonts());

  // Long before the end of a 30 day month, so nothing here depends on the
  // clamping rule the core tests already pin.
  final DateTime now = DateTime(2026, 9, 19, 12);
  const Palette p = Palette.gabi;

  Account card({
    String? cutoff,
    String? due,
    double balance = 4200,
    AccountKind kind = AccountKind.credit,
  }) => Account(
    id: 'c1',
    name: 'BPI Rewards',
    kind: kind,
    institution: 'BPI',
    balance: balance,
    monogram: 'BPI',
    creditLimit: 40000,
    dueDate: due,
    statementDate: cutoff,
  );

  Future<void> pump(
    WidgetTester tester,
    Account a, {
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
                  child: BankCard(account: a, palette: p, now: now),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('both dates are counted in days, in plain words', (
    WidgetTester tester,
  ) async {
    await pump(tester, card(cutoff: '23', due: '2026-10-07'));
    expect(find.text('Bill closes'), findsOneWidget);
    expect(find.text('in 4 days'), findsOneWidget);
    expect(find.text('Due'), findsOneWidget);
    expect(find.text('in 18 days'), findsOneWidget);
  });

  testWidgets('a card whose dates cannot be read draws NOTHING', (
    WidgetTester tester,
  ) async {
    // The other half of the alarm, and the one that matters more. A strip
    // that only ever says it does not know is furniture, and furniture is
    // what teaches people to stop reading a screen.
    await pump(tester, card(cutoff: 'last working day', due: 'payday'));
    expect(find.text('Bill closes'), findsNothing);
    expect(find.text('Due'), findsNothing);
    expect(find.text('What these dates mean'), findsNothing);
  });

  testWidgets('one readable date still shows its own row', (
    WidgetTester tester,
  ) async {
    await pump(tester, card(due: '23'));
    expect(find.text('Bill closes'), findsNothing);
    expect(find.text('Due'), findsOneWidget);
  });

  testWidgets('a debit card gets no cycle at all', (WidgetTester tester) async {
    // A debit card is drawn as plastic too and has no statement. Offering it
    // this strip would imply a float that does not exist.
    await pump(tester, card(kind: AccountKind.debit, cutoff: '23', due: '25'));
    expect(find.text('Bill closes'), findsNothing);
  });

  testWidgets('a late payment says so in WORDS, not only in red', (
    WidgetTester tester,
  ) async {
    // Roughly one man in twelve cannot separate this red from the text
    // beside it, so "3 days ago" has to carry the meaning on its own.
    await pump(tester, card(cutoff: '30', due: '2026-09-16'));
    expect(find.text('3 days ago'), findsOneWidget);
  });

  testWidgets('a payment for a closed bill says which month it is for', (
    WidgetTester tester,
  ) async {
    // The exception to "teaching goes behind the dot": without this line,
    // "Due in 2 days" above "Bill closes in 11 days" reads as
    // today's spending being covered by the payment about to be made.
    await pump(tester, card(cutoff: '30', due: '2026-09-21'));
    expect(find.textContaining('last month’s bill'), findsOneWidget);
  });

  testWidgets('and it is ABSENT when the bill is still open', (
    WidgetTester tester,
  ) async {
    await pump(tester, card(cutoff: '23', due: '2026-10-07'));
    expect(
      find.textContaining('last month’s bill'),
      findsNothing,
      reason: 'it claimed a still-open bill was last month',
    );
  });

  testWidgets('the dot opens the explanation', (WidgetTester tester) async {
    await pump(tester, card(cutoff: '23', due: '2026-10-07'));
    await tester.tap(
      find.bySemanticsLabel('What the two dates on a credit card mean'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(infoContent[InfoTopic.cardCycle]!.title),
      findsOneWidget,
      reason: 'the info dot on the card opened nothing',
    );
  });

  testWidgets('nothing overflows at 320dp with the longest phrases', (
    WidgetTester tester,
  ) async {
    // "Payment due" against "3 days ago" on the narrowest phone the app
    // supports. Container plus alignment plus no width has filled a row
    // seven times in this repository, so the row is measured rather than
    // eyeballed.
    await pump(tester, card(cutoff: '2026-09-16', due: '2026-09-16'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nor at 320dp with the system font turned up to 1.5x', (
    WidgetTester tester,
  ) async {
    // The row is label, dot, spacer, value. At 1.5x both ends grow and the
    // spacer is the only thing that can give, so this is where a Row starts
    // throwing rather than wrapping.
    await pump(
      tester,
      card(cutoff: '2026-09-16', due: '2026-09-16'),
      textScale: 1.5,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Bill closes'), findsOneWidget);
  });
}
