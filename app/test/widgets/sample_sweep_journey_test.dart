import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Clearing the sample data, by tapping, and then walking to every screen that
/// should now show the difference.
///
/// A write path is not tested until somebody can SEE what it did. This one
/// DELETES, which makes the second half the whole point: the money being right
/// in the store means nothing if a screen still shows eleven demo accounts.
void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the demo rows are marked where the figure is read', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
    );
    await pump(tester, state);

    // Home carries the notice, because that is where the hero figure and the
    // way out both are.
    expect(find.textContaining('here is sample money'), findsOneWidget);

    // Accounts and Activity carry the marking on the ROWS instead. A banner
    // is read once and scrolled past; the row is what somebody is looking at
    // when they read a balance they think is theirs.
    await tester.tap(find.text('Accounts').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sample ·'),
      findsWidgets,
      reason: 'a demo account is indistinguishable from a real one',
    );

    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Sample ·'),
      findsWidgets,
      reason: 'a demo entry is indistinguishable from a real one',
    );
  });

  testWidgets('clearing it empties every screen that showed it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime.utc(2026, 9, 19),
    );

    // The user's own entry, made BEFORE the sweep, against a demo account.
    // This is the record the sweep must not touch, and the account it points
    // at is the one that must survive.
    final String sampleAccountId = state.accounts.first.id;
    state.logTransaction(
      Transaction(
        id: 'tx_mine',
        type: TransactionType.expense,
        amount: 250,
        category: 'Food & Dining',
        merchant: 'Tindahan ni Aling Nena',
        accountId: sampleAccountId,
        date: '2026-09-19',
        createdAt: DateTime.utc(2026, 9, 19).millisecondsSinceEpoch,
      ),
    );

    await pump(tester, state);
    expect(find.textContaining('here is sample money'), findsOneWidget);

    // Tap the banner, then Remove, then confirm.
    await tester.tap(find.textContaining('here is sample money'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove the sample data'));
    await tester.pumpAndSettle();

    // The confirmation names what leaves AND what stays.
    expect(find.textContaining('Out:'), findsOneWidget);
    expect(find.textContaining('Stays: everything you typed'), findsOneWidget);

    await tester.tap(find.text('Remove it'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pumpAndSettle();

    // NOW WALK TO EVERY SCREEN. The banner is gone.
    expect(find.textContaining('here is sample money'), findsNothing);

    // Activity still holds the user's own entry, and only it.
    await tester.tap(find.text('Activity').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tindahan ni Aling Nena'),
      findsOneWidget,
      reason:
          'the sweep deleted an entry the person typed, which is the one '
          'thing it must never do',
    );

    // And the store agrees with the screens.
    expect(state.hasSampleData, isFalse);
    expect(state.transactions.map((Transaction t) => t.id), <String>[
      'tx_mine',
    ]);
    expect(
      state.accounts.any((Account a) => a.id == sampleAccountId),
      isTrue,
      reason:
          'the account their entry points at was deleted, so the balance it '
          'moved is now unexplainable',
    );
  });
}
