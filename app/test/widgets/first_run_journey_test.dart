// The first launch, both ways through it.
//
// Until 2026-10-03 a fresh install went straight to Home on SAMPLE data: a
// 48,500 payroll, a housing loan, a debt to a person called Sarah, and
// nothing anywhere saying any of it was fake. A user panel of three Filipino
// archetypes produced three different wrong theories about what they were
// seeing, and agreed the worst moment was the first REAL entry landing beside
// the fake ones.
//
// So the app asks once. These journeys walk both answers and then check what
// the ledger actually holds, because the whole defect class here is a figure
// that belongs to nobody surviving into somebody's real book.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/home/quick_actions.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

void main() {
  /// The store the last [freshInstall] wrote to, so a test can reopen it.
  ///
  /// Returned through a variable rather than from the helper, the way
  /// `debt_removal_test` does it, because almost every caller wants the state
  /// and only two want the file.
  late MemorySnapshotStore lastStore;

  /// A brand new phone: nothing saved, nothing onboarded.
  Future<FinancialState> freshInstall(WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);

    tester.view.physicalSize = const Size(1170, 3400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    lastStore = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18),
      store: lastStore,
    );
    await state.restore();
    addTearDown(state.dispose);

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  testWidgets('a fresh install meets the welcome, not somebody money', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await freshInstall(tester);

    expect(state.needsWelcome, isTrue);
    expect(find.text('Start with my own money'), findsOneWidget);
    expect(find.text('Look around with example data first'), findsOneWidget);

    // THE DIRECTIONAL HALF. The seeded figures are what the welcome exists to
    // stand in front of, so the test has to prove they are not on screen
    // rather than merely that a button is.
    expect(
      find.textContaining('38,414'),
      findsNothing,
      reason: 'a stranger payroll reached the first screen anyway',
    );
    expect(find.byType(QuickActions), findsNothing);
  });

  testWidgets('starting with your own money leaves NO demo figure behind', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await freshInstall(tester);

    // The seed is in memory before the choice, which is what makes the sweep
    // on this path meaningful rather than a no-op.
    expect(state.hasSampleData, isTrue);

    await tapIt(tester, find.text('Start with my own money'));
    expect(find.text('Where is your money?'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '5140');
    await tester.pumpAndSettle();
    await tapIt(tester, find.text('Done'));

    // THE APP, not the welcome. needsWelcome flipped and main.dart rebuilt.
    expect(find.byType(QuickActions), findsOneWidget);
    expect(state.needsWelcome, isFalse);

    // NOT ONE DEMO RECORD SURVIVES, in any collection.
    expect(state.hasSampleData, isFalse);
    expect(state.accounts, hasLength(1));
    expect(state.accounts.single.name, 'GCash');
    expect(state.accounts.single.balance, Money.pesos(5140));
    expect(state.transactions, isEmpty);
    expect(state.debts, isEmpty);

    // AND THE FABRICATED PAYDAY IS GONE, which is the one most likely to be
    // forgotten. SeedData.payday carries a 15th and 30th cycle, a next payday
    // and 32,500 of expected income, and the hero draws a countdown off it.
    // An install that kept it would count down to a stranger's sweldo.
    expect(
      state.payday.cycleType,
      PaydayCycle.unset.cycleType,
      reason: 'the demo payday survived a real-money start',
    );
    expect(find.textContaining('32,500'), findsNothing);

    // The way out of the examples is not offered, because there are none.
    expect(find.text('These figures are examples, not yours'), findsNothing);
  });

  testWidgets('looking around keeps the demo AND says so on Home', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await freshInstall(tester);

    await tapIt(tester, find.text('Look around with example data first'));

    expect(find.byType(QuickActions), findsOneWidget);
    expect(state.needsWelcome, isFalse);
    expect(state.hasSampleData, isTrue);

    // THE PANEL'S ONE ASK. The honest sentence used to live two taps and a
    // scroll behind a gear icon. It is on Home now, with the way out on it.
    await tester.scrollUntilVisible(
      find.text('These figures are examples, not yours'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('These figures are examples, not yours'), findsOneWidget);

    await tapIt(tester, find.text('These figures are examples, not yours'));
    expect(
      find.text('Sample data'),
      findsWidgets,
      reason: 'the banner on Home led nowhere',
    );
  });

  testWidgets('the welcome never returns once it has been answered', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await freshInstall(tester);
    await tapIt(tester, find.text('Look around with example data first'));

    // A SECOND LAUNCH, reading the file the first one wrote. A second state
    // rather than the same object, because the question is whether
    // `onboardedAt` actually PERSISTED, and asserting on the in-memory
    // instance would pass with the field never written at all.
    await state.flushWrites();
    final FinancialState reopened = FinancialState(
      clock: DateTime(2026, 9, 19),
      store: lastStore,
    );
    await reopened.restore();
    addTearDown(reopened.dispose);

    expect(
      reopened.needsWelcome,
      isFalse,
      reason: 'the welcome came back on the second launch',
    );
  });

  testWidgets('a restored backup written before onboarding existed is left '
      'alone', (WidgetTester tester) async {
    // The honest case for a nullable field. A file exported before
    // `onboardedAt` existed says null, and null means "never onboarded",
    // which is TRUE and would still be the wrong thing to act on: somebody
    // restoring a full ledger has plainly met this app before. The second
    // question, whether real records exist, is what saves them.
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState seeded = FinancialState(
      clock: DateTime(2026, 9, 18),
      store: store,
    );
    await seeded.restore();
    seeded.startWithOwnMoney(
      accountName: 'BPI Savings',
      opening: Money.pesos(20000),
    );
    await seeded.flushWrites();
    addTearDown(seeded.dispose);

    // Strip the flag the way an older export simply would not have carried
    // it, so this is a file from before the field existed rather than one
    // with the field set to something.
    //
    // DECODED AND RE-ENCODED, not edited with a regex. The first version of
    // this deleted the line with a pattern whose trailing comma was optional,
    // which is correct for a key in the middle of an object and leaves a
    // dangling comma when the key is last. The file then failed to parse, the
    // store fell back to the seed, and the test reported eleven accounts: a
    // failure that looks exactly like the feature being broken and was
    // entirely the fixture's doing.
    final Map<String, dynamic> raw =
        jsonDecode(store.contents!) as Map<String, dynamic>;
    raw.remove('onboardedAt');
    final String older = jsonEncode(raw);

    expect(
      older.contains('onboardedAt'),
      isFalse,
      reason: 'the flag was not actually stripped, so this proves nothing',
    );

    final FinancialState restored = FinancialState(
      clock: DateTime(2026, 9, 19),
      store: MemorySnapshotStore(older),
    );
    await restored.restore();
    addTearDown(restored.dispose);

    expect(
      restored.accounts,
      hasLength(1),
      reason: 'the fixture did not load, so the assertion below is hollow',
    );
    expect(
      restored.needsWelcome,
      isFalse,
      reason:
          'a restored ledger with real accounts was marched through a first '
          'run it had already finished',
    );
  });
}
