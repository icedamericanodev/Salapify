// Split a bill, and can anybody FOLLOW what it did?
//
// `test/core/money/split_bill_test.dart` is the first half: twenty six golden
// vectors prove the arithmetic matches the prototype to the centavo. This is
// the second half, and it is the one this repository keeps losing: a write is
// not tested until somebody can walk to every screen that should now mention
// it and find it there.
//
// The rule came from a real failure. A founder paid 1,500 off a loan, opened
// the account it came from, and found nothing in its history. The money had
// moved and no entry explained why. A split is the same shape, only worse: it
// writes SEVERAL debts and optionally a transaction in one tap, so the gap
// between "the engine is right" and "the ledger shows it" is several records
// wide.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/debt/split_bill_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/state/financial_state.dart';

void main() {
  _reachable();

  /// Opens the sheet directly rather than through the Debt screen.
  ///
  /// The reachability of the door is asserted separately below; driving three
  /// taps before every assertion would make each of these fail for whichever
  /// of the three moved last.
  Future<FinancialState> openSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 10, 1),
    );
    final Palette p = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          body: SafeArea(
            child: SplitBillSheet(palette: p, state: state),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> type(WidgetTester tester, String label, String value) async {
    await tester.enterText(
      find
              .ancestor(of: find.text(label), matching: find.byType(Column))
              .first
              .evaluate()
              .isEmpty
          ? find.byType(TextField).first
          : find
                .descendant(
                  of: find
                      .ancestor(
                        of: find.text(label),
                        matching: find.byType(Column),
                      )
                      .first,
                  matching: find.byType(TextField),
                )
                .first,
      value,
    );
    await tester.pumpAndSettle();
  }

  /// Scroll to it, then tap it.
  ///
  /// The sheet is taller than the phone once a second person is added, so
  /// "Record it" sits below the fold. Tapping a finder whose centre is off
  /// screen does NOT fail in Flutter: it warns and lands nowhere. The first
  /// version of these journeys asserted straight after and every write test
  /// reported zero debts, which reads exactly like a save path that does not
  /// save.
  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  List<Debt> splitDebts(FinancialState s) => s.debts
      .where((Debt d) => (d.notes ?? '').startsWith('Split:'))
      .toList(growable: false);

  group('the share a person is shown is the share they get', () {
    testWidgets('an even split between two shows both halves', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);
      await type(tester, 'Total bill', '1200');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      // Both rows show the amount, which is the engine's number and not a
      // percentage. See the odd thing 2 note in split_bill.dart.
      expect(find.textContaining('Their share: '), findsNWidgets(2));
      expect(find.textContaining('600.00'), findsWidgets);
    });
  });

  group('recording it writes debts somebody can find', () {
    testWidgets('paying for two friends creates two debts owed to you', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await openSheet(tester);
      final int before = state.debts.length;

      await type(tester, 'Total bill', '1200');
      await type(tester, 'What was it', 'Lunch');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );
      await type(tester, 'Add somebody', 'Ben');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      await tapIt(tester, find.text('Record it'));

      final List<Debt> made = splitDebts(state);
      expect(made.length, 2, reason: 'one per other person, never for you');
      expect(state.debts.length, before + 2);

      // DIRECTIONAL: you paid, so they owe you, and for 400 each on a 1200
      // bill split three ways.
      for (final Debt d in made) {
        expect(d.direction, DebtDirection.owedToMe);
        expect(d.totalAmount, 400);
        expect(d.notes, 'Split: Lunch');
        expect(d.isSettled, isFalse);
      }
      expect(made.map((Debt d) => d.person).toSet(), <String>{'Carla', 'Ben'});
    });

    testWidgets('when somebody else paid, you owe THEM, once', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await openSheet(tester);

      await type(tester, 'Total bill', '1000');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      // Tap the "Paid the bill" radio on Carla's row, which is the second.
      await tapIt(tester, find.text('Paid the bill').last);

      await tapIt(tester, find.text('Record it'));

      final List<Debt> made = splitDebts(state);
      expect(
        made.length,
        1,
        reason:
            'one debt, not one per person: you owe the payer your share '
            'and nobody owes you anything',
      );
      expect(made.single.direction, DebtDirection.iOwe);
      expect(made.single.person, 'Carla');
      expect(made.single.totalAmount, 500);
    });

    testWidgets('the EXACT centavos are written, not whole pesos', (
      WidgetTester tester,
    ) async {
      // Founder decision, 2026-10-01, and a deliberate divergence from the
      // prototype, which wraps every share in Math.round before creating the
      // debt. On this bill that would write 333 against a share of 333.33 and
      // 67 centavos would leave the ledger with nothing said.
      final FinancialState state = await openSheet(tester);

      await type(tester, 'Total bill', '1000');
      await type(tester, 'Add somebody', 'A');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );
      await type(tester, 'Add somebody', 'B');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      await tapIt(tester, find.text('Record it'));

      final List<Debt> made = splitDebts(state);
      expect(made.length, 2);
      for (final Debt d in made) {
        expect(
          d.totalAmount,
          333.33,
          reason: 'the prototype would have written 333 here',
        );
      }
    });

    testWidgets('a split with nobody else recorded writes nothing', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await openSheet(tester);
      final int before = state.debts.length;

      await type(tester, 'Total bill', '1000');
      // No second person, so the button must not be live.
      await tapIt(tester, find.text('Record it'));

      expect(state.debts.length, before);
      expect(splitDebts(state), isEmpty);
    });
  });

  group('the expense half', () {
    testWidgets('the whole bill is logged when you paid', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await openSheet(tester);
      final int before = state.transactions.length;

      await type(tester, 'Total bill', '1200');
      await type(tester, 'What was it', 'Lunch');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      await tapIt(tester, find.text('Record it'));

      expect(state.transactions.length, before + 1);
      final Transaction tx = state.transactions.firstWhere(
        (Transaction t) => t.id.startsWith('tx_split_'),
      );
      expect(
        tx.amount,
        1200,
        reason:
            'the whole bill left your account, and the debt is what '
            'brings half of it back',
      );
      expect(tx.type, TransactionType.expense);
      expect(tx.merchant, 'Lunch');
    });

    testWidgets('only your share is logged when somebody else paid', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await openSheet(tester);

      await type(tester, 'Total bill', '1200');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );
      await tapIt(tester, find.text('Paid the bill').last);

      await tapIt(tester, find.text('Record it'));

      final Transaction tx = state.transactions.firstWhere(
        (Transaction t) => t.id.startsWith('tx_split_'),
      );
      expect(tx.amount, 600);
    });

    testWidgets('unticking it writes the debts and no transaction', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await openSheet(tester);
      final int txBefore = state.transactions.length;

      await type(tester, 'Total bill', '1200');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      await tapIt(tester, find.textContaining('Also log the whole bill'));

      await tapIt(tester, find.text('Record it'));

      // DIRECTIONAL both ways: the debt still landed, the transaction did not.
      expect(splitDebts(state).length, 1);
      expect(state.transactions.length, txBefore);
    });
  });

  group('when the shares do not add up, the screen says so', () {
    testWidgets('fixed amounts short of the bill warn before recording', (
      WidgetTester tester,
    ) async {
      // The engine never reconciles fixed amounts, by design and by vector.
      // Silence here would let somebody record debts that are 700 short of
      // what they actually paid.
      await openSheet(tester);

      await type(tester, 'Total bill', '1000');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      await tapIt(tester, find.text('Amounts'));

      final Finder boxes = find.byType(TextField);
      await tester.enterText(boxes.at(boxes.evaluate().length - 2), '100');
      await tester.pumpAndSettle();
      await tester.enterText(boxes.last, '200');
      await tester.pumpAndSettle();

      expect(find.textContaining('LESS than the bill'), findsOneWidget);
      expect(find.textContaining('not assigned to anybody'), findsOneWidget);
    });

    testWidgets('an even split says nothing, so the warning means something', (
      WidgetTester tester,
    ) async {
      // The silent half of the alarm. A warning that is always on screen is
      // one nobody reads, and then it is not there for the real mismatch.
      await openSheet(tester);

      await type(tester, 'Total bill', '1000');
      await type(tester, 'Add somebody', 'Carla');
      await tapIt(
        tester,
        find.bySemanticsLabel('Add this person to the split'),
      );

      expect(find.textContaining('LESS than the bill'), findsNothing);
      expect(find.textContaining('MORE than the bill'), findsNothing);
      expect(find.textContaining('The shares come to'), findsOneWidget);
    });
  });

  group('nothing from the prototype that should not be here', () {
    testWidgets('no stranger is pre-filled into the split', (
      WidgetTester tester,
    ) async {
      // The prototype ships with a second participant named Carla and a
      // description reading "Barkada Lunch". Placeholder data pre-filled into
      // a form that creates debts is somebody else's name on your money.
      await openSheet(tester);

      expect(find.text('Carla'), findsNothing);
      expect(find.text('Barkada Lunch'), findsNothing);
      expect(find.text('You'), findsOneWidget);
    });
  });
}

/// A screen somebody cannot REACH is not shipped.
///
/// The journeys above open the sheet directly, deliberately, so that each one
/// fails for its own reason rather than for whichever of three taps moved
/// last. This is the one that drives the real route.
void _reachable() {
  testWidgets('the split sheet opens from the Debt screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 10, 1),
    );
    final Palette p = Palette.of(state.theme);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: Scaffold(
          body: SafeArea(child: DebtScreen(state: state)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Found by its TEXT rather than its semantics label. The card wraps an
    // InkWell whose children carry their own text, and those merge upward, so
    // the explicit label is not separately findable. The label still does its
    // job for a screen reader; it is simply not the handle a test can grab.
    final Finder door = find.text(
      'Work out everyone\'s share and record who owes what',
    );
    await tester.ensureVisible(door);
    await tester.pumpAndSettle();
    await tester.tap(door);
    await tester.pumpAndSettle();

    expect(find.text('Split a bill'), findsWidgets);
    expect(find.text('Total bill'), findsOneWidget);
  });
}
