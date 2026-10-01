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
import 'package:salapify/main.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

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
///
/// It drives the WHOLE APP rather than a bare Scaffold, and that is the
/// difference between this version and the one it replaced. The first version
/// pumped `DebtScreen` on its own and asserted a card inside it opened the
/// sheet. Every word of that was true, and the feature was still effectively
/// unreachable: the founder went looking for it, did not find it, and the
/// test had nothing to say because it had been handed the destination as its
/// starting point. A reachability test that begins where the feature lives
/// cannot fail the way reachability actually fails.
void _reachable() {
  testWidgets('the split sheet opens from the Home shortcut row', (
    WidgetTester tester,
  ) async {
    // The real fonts, because this pumps the whole of Home and Home MEASURES.
    // Without them the first run of this test reported a 45 pixel overflow in
    // debt_beam_card.dart that does not exist on a phone: Flutter's default
    // test font is wider than Plus Jakarta Sans, so a layout judged in it is
    // a layout nobody will ever see.
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Pinned, for the same reason plan_test.dart and log_journey_test.dart
    // are: the seed ledger is dated September and the real clock has moved
    // past it.
    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    addTearDown(state.dispose);

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    // Home opens on the first tab, so nothing is tapped to get here. That is
    // the point of the move: the door is on the screen the app opens on.
    final Finder door = find.descendant(
      of: find.byType(QuickActions),
      matching: find.text('Split'),
    );
    expect(
      door,
      findsOneWidget,
      reason: 'the Split shortcut is not on Home at all',
    );

    await tester.ensureVisible(door);
    await tester.pumpAndSettle();
    await tester.tap(door);
    await tester.pumpAndSettle();

    expect(find.text('Split a bill'), findsWidgets);
    expect(find.text('Total bill'), findsOneWidget);
  });

  testWidgets('the Home shortcut row still fits on a 320dp phone', (
    WidgetTester tester,
  ) async {
    // The fifth shortcut is why this exists, and what it guards is NOT an
    // overflow. The first version of this test was written believing a fixed
    // 52 tile would overflow by 2.4 pixels at five across; it does not,
    // because Flutter enforces a tight width against the parent's constraint
    // and silently clamps it to 49.6. The deliberate break proved that by
    // passing when it should have failed.
    //
    // What is really at risk when shortcuts are added is the TOUCH TARGET.
    // Each tile gets whatever a fifth of the row is, and that number falls
    // every time somebody adds a shortcut. At six it is 40, under the 44
    // floor, and nothing anywhere else in the app would say so. That is the
    // assertion with teeth here.
    //
    // 320dp is the narrowest phone worth supporting, and the row is checked
    // at large text too, because the LABEL under each tile is what runs out
    // of room second.
    //
    // Real fonts, because this measures. The default test font is wider than
    // the shipped one, so a row that fits in it is not evidence about a
    // phone, and a row that fails in it is not necessarily a defect.
    await tester.runAsync(loadRealFonts);

    for (final double scale in <double>[1.0, 1.5]) {
      tester.view.physicalSize = const Size(320 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
      final Palette p = Palette.of(state.theme);
      addTearDown(state.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(p, state.theme),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: QuickActions(
                    palette: p,
                    onLog: () {},
                    onDebt: () {},
                    onBills: () {},
                    onMove: () {},
                    onSplit: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the shortcut row overflowed at 320dp and ${scale}x text',
      );

      // All five are really drawn, not just not-overflowing. A row that
      // dropped a shortcut would pass an overflow check perfectly.
      for (final String label in <String>[
        'Log',
        'Debt',
        'Bills',
        'Move',
        'Split',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '$label is missing from the shortcut row',
        );
      }

      // And every tile still clears the 44dp touch floor.
      for (final Element e in find.byType(InkWell).evaluate()) {
        final Size size = e.size!;
        expect(
          size.width,
          greaterThanOrEqualTo(44.0),
          reason: 'a shortcut tile is only ${size.width}dp wide',
        );
      }
    }
  });
}
