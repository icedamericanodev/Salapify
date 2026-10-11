// A message with an Undo button goes away on its own (founder report,
// 2026-10-11).
//
// Flutter 3.47 changed SnackBar's default: one with an action now stays on
// screen until it is tapped. Nothing in Salapify changed, and the "Logged.
// ... Undo" message after every entry started sitting over the tab bar for
// good. Every snackbar with an action here sets `persist: false`.
//
// Two halves. The journey proves the behaviour on the commonest path, the
// one the founder hit. The scan proves every OTHER snackbar with an action
// says the same, because a new one added next month would otherwise inherit
// the sticky default silently.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  testWidgets('the Logged message with Undo is gone a few seconds later', (
    WidgetTester tester,
  ) async {
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    state.startWithExampleData();
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    final Finder log = find.descendant(
      of: find.byType(QuickActions),
      matching: find.text('Log'),
    );
    await tester.tap(log);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '150',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();

    // It showed, so the absence below means something.
    expect(find.textContaining('Logged.'), findsOneWidget);

    // Five seconds is its duration; give it room to animate out.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Logged.'),
      findsNothing,
      reason: 'the Undo message stayed on screen after its time was up',
    );
  });

  testWidgets('every message has a close button that hides it at once', (
    WidgetTester tester,
  ) async {
    // Founder direction, 2026-10-11: five seconds is long for a message
    // already read, so it can be closed. Set once in the theme.
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final FinancialState state = FinancialState(clock: DateTime(2026, 9, 18));
    await state.restore();
    state.startWithExampleData();
    // Not the first real entry: that one also opens the one-time reminder
    // offer, whose dimmed barrier sits over the message and would make this
    // a test of the offer instead.
    state.logTransaction(
      const Transaction(
        id: 'tx_earlier',
        type: TransactionType.expense,
        amount: Money.pesos(90),
        category: 'Food & Dining',
        accountId: 'acc_cash',
        date: '2026-09-17',
        createdAt: 1,
      ),
    );
    addTearDown(state.dispose);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(QuickActions),
        matching: find.text('Log'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '150',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save entry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Logged.'), findsOneWidget);

    final Finder close = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byIcon(Icons.close),
    );
    expect(close, findsOneWidget, reason: 'the message has no close button');
    // Well inside its five seconds.
    await tester.tap(close);
    // Lets the closing animation finish. It does NOT run out the five second
    // timer: that is a timer, not a frame, so a message the close button
    // failed to hide would still be here afterwards.
    await tester.pumpAndSettle();
    expect(find.textContaining('Logged.'), findsNothing);
    // Closing is not undoing: the entry is still there.
    expect(state.transactions.where((t) => t.amount.pesos == 150), isNotEmpty);
  });

  test('every snackbar with an action says persist: false', () {
    final List<String> offenders = <String>[];
    for (final FileSystemEntity f in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final String src = f.readAsStringSync();
      // Each action built, whether handed straight to a SnackBar or through
      // a helper that builds one, needs its own persist: false.
      final int actions = 'SnackBarAction('.allMatches(src).length;
      final int persists = 'persist: false'.allMatches(src).length;
      if (actions > persists) {
        offenders.add('${f.path} ($actions vs $persists)');
      }
    }
    expect(offenders, isEmpty);
  });
}
