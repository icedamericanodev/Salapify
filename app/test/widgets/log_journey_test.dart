import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/format.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/home_screen.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

/// The Log write path, tested the way CLAUDE.md requires a write path to be
/// tested: in BOTH halves.
///
/// Half one asks whether the money moved correctly. Half two asks whether a
/// person can FOLLOW it afterwards, by walking to every screen that should
/// now mention it and asserting it is actually on the screen.
///
/// Half two is the half that gets forgotten, and it is the half that matters:
/// a payment was once written perfectly and was invisible on the screen an
/// auditor would look at, and every money test was green the whole time.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

  FinancialState storeOf(WidgetTester tester) =>
      tester.widget<HomeScreen>(find.byType(HomeScreen)).state;

  /// The Log button exists TWICE by design, once in the tab bar and once as a
  /// Home quick action, so a bare find.text('Log') matches both and throws
  /// "Bad state: Too many elements". The journey goes through Home's.
  final Finder logButton = find.descendant(
    of: find.byType(QuickActions),
    matching: find.text('Log'),
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  double balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  double netWorthOf(FinancialState s) =>
      s.accounts.fold<double>(0, (double sum, Account a) => sum + a.balance);

  testWidgets('logging a spend moves the money AND shows up where a person '
      'would look for it', (WidgetTester tester) async {
    await pumpApp(tester);
    final FinancialState state = storeOf(tester);

    final double cashBefore = balanceOf(state, 'acc_cash');
    final int countBefore = state.transactions.length;

    await tapAndSettle(tester, logButton);
    expect(find.byType(LogSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '250');
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'Mang Tonio Carinderia',
    );
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.text('Save entry'));

    // ---------------------------------------------------------------- half one
    // The money moved, by exactly the amount typed, out of exactly the account
    // chosen. Directional, so a save that silently did nothing fails here.
    expect(balanceOf(state, 'acc_cash'), cashBefore - 250);
    expect(state.transactions.length, countBefore + 1);
    expect(
      state.transactions.first.merchant,
      'Mang Tonio Carinderia',
      reason: 'the newest entry should be the one just logged',
    );

    // ---------------------------------------------------------------- half two
    // Saving lands on Activity, because being left on a screen that does not
    // show the entry is how somebody concludes it did not save.
    expect(
      find.text('Mang Tonio Carinderia'),
      findsWidgets,
      reason: 'the logged entry is not on the screen the app landed on',
    );

    // And it is under Today, not filed under some other day.
    expect(find.text('Today'), findsOneWidget);

    // Now walk BACK to Home and check the screen that lists recent entries.
    await tapAndSettle(tester, find.byIcon(Icons.home_outlined));
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mang Tonio Carinderia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('Mang Tonio Carinderia'),
      findsWidgets,
      reason: 'Home does not mention an entry logged seconds ago',
    );
  });

  testWidgets(
    'a transfer changes net worth by nothing, and both accounts move',
    (WidgetTester tester) async {
      await pumpApp(tester);
      final FinancialState state = storeOf(tester);

      final double netBefore = netWorthOf(state);
      final double bpiBefore = balanceOf(state, 'acc_bpi');
      final double gcashBefore = balanceOf(state, 'acc_gcash');

      await tapAndSettle(tester, logButton);
      await tapAndSettle(tester, find.text('Moved'));
      await tester.enterText(find.byType(TextField).first, '1500');
      await tester.pumpAndSettle();

      // Scoped to each picker by key. Both pickers list account names, so a
      // bare find.text names two controls and the tap is a coin toss.
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byKey(const Key('log-source-picker')),
          matching: find.text('BPI Preferred Payroll'),
        ),
      );
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byKey(const Key('log-destination-picker')),
          matching: find.text('GCash Wallet'),
        ),
      );
      await tapAndSettle(tester, find.text('Save entry'));

      // The invariant.
      expect(netWorthOf(state), netBefore);
      // The directional companion, without which a transfer that transferred
      // nothing would satisfy the invariant perfectly.
      expect(balanceOf(state, 'acc_bpi'), bpiBefore - 1500);
      expect(balanceOf(state, 'acc_gcash'), gcashBefore + 1500);
    },
  );

  testWidgets('Save is refused until there is an amount', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final FinancialState state = storeOf(tester);
    final int countBefore = state.transactions.length;

    await tapAndSettle(tester, logButton);
    await tester.tap(find.text('Save entry'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Still open, nothing written. An entry with no amount is a row that can
    // never be reconciled against anything.
    expect(find.byType(LogSheet), findsOneWidget);
    expect(state.transactions.length, countBefore);
  });

  testWidgets(
    'the sheet says out loud that nothing is saved to the phone yet',
    (WidgetTester tester) async {
      await pumpApp(tester);

      await tapAndSettle(tester, logButton);
      await tester.enterText(find.byType(TextField).first, '100');
      await tester.pumpAndSettle();
      await tapAndSettle(tester, find.text('Save entry'));

      // There is no storage layer in app/ yet. Somebody who logs a real expense
      // deserves to know it will not survive a restart, at the moment they save
      // it, rather than discovering it tomorrow.
      expect(
        find.textContaining('not saved to the phone yet'),
        findsOneWidget,
        reason: 'the app must not imply a durability it does not have',
      );
    },
  );

  testWidgets('a spend tells you what it is about to do before you save it', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapAndSettle(tester, logButton);
    await tester.enterText(find.byType(TextField).first, '250');
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
    );

    expect(
      find.textContaining('${formatPeso(250)} leaves Cash on Hand (Pitaka)'),
      findsOneWidget,
    );
  });

  testWidgets('a transfer cannot be sent to the account it came from', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tapAndSettle(tester, logButton);
    await tapAndSettle(tester, find.text('Moved'));
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
    );

    // The source is now Cash, so the destination list must not offer it. This
    // is the guard against the engine's preserved quirk, where a transfer
    // with a destination that is not a real other account debits the source
    // and credits nobody.
    expect(
      find.descendant(
        of: find.byKey(const Key('log-destination-picker')),
        matching: find.text('Cash on Hand (Pitaka)'),
      ),
      findsNothing,
      reason: 'a transfer to itself moves nothing and reads as a bug',
    );
  });

  testWidgets('Transfer is not offered as a category for a spend', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await tapAndSettle(tester, logButton);

    // Found by looking at the render. A transfer is a TYPE, and offering it as
    // a spending category produces rows tagged Transfer that are not
    // transfers, which is exactly the entry nobody can reconcile later.
    expect(
      find.text('Transfer'),
      findsNothing,
      reason: 'Transfer is a type, not a category to pick for a spend',
    );
    // The categories that DO belong are still there, so this is not passing
    // because the picker rendered nothing at all.
    expect(find.text('Food & Dining'), findsOneWidget);
  });
}
