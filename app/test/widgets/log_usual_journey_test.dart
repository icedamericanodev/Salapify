import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/home_screen.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

/// The Log sheet learning from the ledger (D31, 2026-10-09): last used
/// account, "usual" chips, and a confirmation that says what changed.
///
/// Every check here is DIRECTIONAL. A default that silently fell back to the
/// first account would still save, so the test names the account the money
/// must leave.
void main() {
  Future<FinancialState> pumpApp(WidgetTester tester) async {
    // Taller than the 800 by 600 default, for the reason log_journey_test
    // gives: Home is a lazy list and the shortcut row must be built.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final FinancialState state = await pumpSalapify(tester);
    // The one-time reminder offer is already answered, as in log_journey.
    state.updateReminderSettings(
      state.reminderSettings.copyWith(phoneEnabled: true),
    );
    return state;
  }

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

  Future<void> openLog(WidgetTester tester) async {
    if (find.byType(HomeScreen).evaluate().isEmpty) {
      await tapAndSettle(tester, find.byIcon(Icons.home_outlined));
    }
    await tapAndSettle(tester, logButton);
    expect(find.byType(LogSheet), findsOneWidget);
  }

  Finder field(String key) => find.descendant(
    of: find.byKey(Key(key)),
    matching: find.byType(TextField),
  );

  Money balanceOf(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  Future<void> logKape(WidgetTester tester, {String? pick}) async {
    await openLog(tester);
    await tester.enterText(field('log-amount'), '150');
    await tester.enterText(field('log-merchant'), 'Kape');
    await tester.pumpAndSettle();
    if (pick != null) {
      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byKey(const Key('log-source-picker')),
          matching: find.text(pick),
        ),
      );
    }
    await tapAndSettle(tester, find.text('Save entry'));
  }

  testWidgets('the account last spent from is the one picked next time', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await pumpApp(tester);
    // GCash, deliberately NOT the first account in the list. The first draft
    // of this test used Cash, which IS first, so it passed with the feature
    // deleted: the old default and the new one picked the same account.
    await logKape(tester, pick: 'GCash Wallet');

    // Second entry: the account is NOT touched. The money must still leave
    // GCash, because that is what was used last.
    final Money gcashBefore = balanceOf(state, 'acc_gcash');
    await openLog(tester);
    await tester.enterText(field('log-amount'), '60');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Save entry'));
    expect(
      balanceOf(state, 'acc_gcash'),
      gcashBefore - const Money.pesos(60),
      reason: 'the default fell back to the first account, not the last used',
    );
  });

  testWidgets('a repeated spend becomes a chip that FILLS the form, and Save '
      'is still a separate tap', (WidgetTester tester) async {
    final FinancialState state = await pumpApp(tester);
    await logKape(tester, pick: 'Cash on Hand (Pitaka)');
    await logKape(tester);

    await openLog(tester);
    final Finder chip = find.byKey(const ValueKey<String>('usual-Kape-15000'));
    expect(chip, findsOneWidget, reason: 'two Kape 150 entries made no chip');

    final int countBefore = state.transactions.length;
    final Money cashBefore = balanceOf(state, 'acc_cash');
    await tapAndSettle(tester, chip);

    // Filled, not saved.
    expect(state.transactions.length, countBefore, reason: 'the chip saved');
    expect(
      tester.widget<TextField>(field('log-amount')).controller!.text,
      '150',
    );
    expect(
      tester.widget<TextField>(field('log-merchant')).controller!.text,
      'Kape',
    );

    await tapAndSettle(tester, find.text('Save entry'));
    expect(state.transactions.length, countBefore + 1);
    expect(balanceOf(state, 'acc_cash'), cashBefore - const Money.pesos(150));
  });

  testWidgets('the confirmation says what the spend did to the day', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await pumpApp(tester);
    expect(state.payday.isSet, isTrue, reason: 'the fixture has no payday');
    await logKape(tester, pick: 'Cash on Hand (Pitaka)');
    expect(find.textContaining('a day until payday now'), findsOneWidget);
    expect(
      find.textContaining('Saved to this phone'),
      findsOneWidget,
      reason: 'the reassurance must stay beside the new figure',
    );
  });
}
