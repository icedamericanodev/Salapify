import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Erasing everything, by tapping, and then checking every screen agrees.
///
/// This is the only irreversible control in Salapify, so it gets the strictest
/// version of the write-path rule: prove the money went, prove a person can
/// SEE it went, and prove the guards around it hold. A wipe that half works is
/// worse than one that does not work at all, because the person believes it.
void main() {
  emptyAppTests();

  /// SalapifyApp, not a bare AppShell inside a MaterialApp.
  ///
  /// This is not a style choice and it cost a round to find. The listener that
  /// rebuilds the screens when the ledger changes lives in SalapifyApp
  /// (main.dart, `_state.addListener`). A test that pumps AppShell directly
  /// has NOTHING listening, so the tree never rebuilds and every screen keeps
  /// showing the data that was there when it was first built.
  ///
  /// That made the assertion "a person can see the wipe happened" fail against
  /// a harness that could not have shown it either way, which is the hollow
  /// test this repository keeps relearning: a screen that cannot update is not
  /// evidence about a screen that can.
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
  }

  void bigPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> openWipe(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();
    // ensureVisible, not scrollUntilVisible: the sheet and the screen behind
    // it are both scrollable, so scrollUntilVisible cannot tell which one it
    // was asked about and throws "Too many elements". The sheet's body is a
    // SingleChildScrollView, so every row is already built and only needs
    // bringing into view.
    final Finder row = find.text('Delete everything on this phone');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('it asks twice, and the first tap changes nothing', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: store,
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded. This
    // fixture is the seeded ledger, which is what the "look around with
    // example data" path leaves behind, so it says so.
    state.startWithExampleData();
    await state.flushWrites();
    final int accounts = state.accounts.length;
    expect(accounts, greaterThan(0));

    await pump(tester, state);
    await openWipe(tester);

    // The screen names what goes, in figures, before anything happens.
    expect(find.text('There is no undo'), findsOneWidget);
    expect(find.text('$accounts'), findsWidgets);

    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();

    expect(
      state.accounts.length,
      accounts,
      reason:
          'the first tap erased the ledger, so a mis-tap on the row destroys '
          'everything with no second chance',
    );
    expect(find.text('Yes, erase it'), findsOneWidget);
    expect(find.text('Keep my records'), findsOneWidget);
  });

  testWidgets('backing out leaves every figure exactly where it was', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded. This
    // fixture is the seeded ledger, which is what the "look around with
    // example data" path leaves behind, so it says so.
    state.startWithExampleData();
    await state.flushWrites();
    final int accounts = state.accounts.length;
    final int entries = state.transactions.length;

    await pump(tester, state);
    await openWipe(tester);
    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep my records'));
    await tester.pumpAndSettle();

    expect(state.accounts.length, accounts);
    expect(state.transactions.length, entries);
  });

  testWidgets('confirming empties the app, the files and the screens', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: store,
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded. This
    // fixture is the seeded ledger, which is what the "look around with
    // example data" path leaves behind, so it says so.
    state.startWithExampleData();
    await state.flushWrites();

    // Give the store a previous generation AND a pre-import copy, because
    // those are the two the wipe exists to reach and the two nothing else in
    // the app mentions.
    state.toggleTheme();
    await state.flushWrites();
    await store.writePreImport('{"accounts": []}');
    expect(store.previous, isNotNull);
    expect(store.preImport, isNotNull);

    await pump(tester, state);
    await openWipe(tester);
    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, erase it'));
    await tester.pumpAndSettle();

    // Half one: the money is gone from the store.
    expect(state.accounts, isEmpty);
    expect(state.transactions, isEmpty);
    expect(state.debts, isEmpty);
    expect(state.bills, isEmpty);
    expect(state.notifications, isEmpty);
    expect(
      store.preImport,
      isNull,
      reason:
          'the copy taken before the last restore survived, so a full second '
          'ledger with other people\'s names is still on the phone after '
          'somebody asked for everything to be deleted',
    );
    expect(store.previous, isNull);

    // Half two: a person can SEE it. Walk out of the sheet to Home.
    expect(find.text('Gone'), findsOneWidget);

    // And the receipt NAMES the Pan conversation, which it did not until
    // 2026-10-03 although the wipe genuinely deleted it. This is the
    // rendered half of the guard in truthful_claims_test: that one reads
    // the source, this one reads the screen, because a string can be
    // present in the file and never reach a person.
    expect(
      find.textContaining('conversation with Pan'),
      findsOneWidget,
      reason:
          'the done screen lists what was removed and leaves out the file '
          'holding sentences somebody typed in their own words, which is '
          'what they are wiping before they hand the phone over',
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Meralco'),
      findsNothing,
      reason: 'a seeded bill is still on a screen after the wipe',
    );
  });

  testWidgets('the sample data does not quietly come back', (
    WidgetTester tester,
  ) async {
    // The prototype's own control is "Reset to Sample Data", which puts eleven
    // demo accounts and a salary back. Somebody who just erased everything and
    // is then shown money they never earned has been handed the exact thing
    // they were trying to avoid.
    bigPhone(tester);
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded. This
    // fixture is the seeded ledger, which is what the "look around with
    // example data" path leaves behind, so it says so.
    state.startWithExampleData();
    await state.flushWrites();

    await pump(tester, state);
    await openWipe(tester);
    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, erase it'));
    await tester.pumpAndSettle();

    expect(state.accounts, isEmpty);
    expect(state.hasSampleData, isFalse);
  });

  testWidgets('a wiped phone starts over, welcome and all', (
    WidgetTester tester,
  ) async {
    // THE WIPE HAS TO FORGET THE INTRODUCTION TOO, and until 2026-10-03 it
    // did not, which left the whole thing in a dead end.
    //
    // Everything else was cleared and `onboardedAt` survived, so the app came
    // back empty with `needsWelcome` false: no welcome, and no example data
    // either, because `_sampleRemovedAt` is correctly null after a wipe and
    // that is what gates the put-it-back control. Settings read "There is no
    // sample data on this phone" with no control beside it, and neither the
    // first run nor the examples could be reached again by any route.
    //
    // It also made the wipe screen's own promise false. A phone that still
    // remembers being introduced to somebody is not empty and new, and the
    // person this matters most to is the one the wipe exists for: somebody
    // handing the phone on, whose recipient would meet a blank app that had
    // already decided it knew them.
    bigPhone(tester);
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    state.startWithExampleData();
    await state.flushWrites();

    await pump(tester, state);
    expect(
      state.needsWelcome,
      isFalse,
      reason:
          'the fixture starts at the welcome, so the wipe below proves '
          'nothing about having come back to it',
    );

    await openWipe(tester);
    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, erase it'));
    await tester.pumpAndSettle();

    expect(state.needsWelcome, isTrue);
    expect(
      find.text('Start with my own money'),
      findsOneWidget,
      reason:
          'a wiped phone did not come back to the welcome, so there is '
          'no route to the example data or to a first run',
    );
    expect(find.text('Look around with example data first'), findsOneWidget);
  });

  testWidgets('the app is still saving afterwards', (
    WidgetTester tester,
  ) async {
    // An app that erased itself and then stopped writing would be the same
    // defect twice over, and silently.
    bigPhone(tester);
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: store,
    );
    await state.restore();
    // The app opens on the welcome when nothing has been onboarded. This
    // fixture is the seeded ledger, which is what the "look around with
    // example data" path leaves behind, so it says so.
    state.startWithExampleData();
    await state.flushWrites();

    await pump(tester, state);
    await openWipe(tester);
    await tester.tap(find.text('Delete everything').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, erase it'));
    await tester.pumpAndSettle();

    expect(state.isSaving, isTrue);

    final int writes = store.writes;
    state.toggleTheme();
    await state.flushWrites();
    expect(
      store.writes,
      greaterThan(writes),
      reason:
          'nothing typed after the wipe would ever be kept, and no screen '
          'would say so',
    );
    expect(store.contents, isNotNull);
  });
}

/// The emptiest the app can ever be.
///
/// A wiped ledger is a state every screen has to survive, and it is the one
/// least likely to be looked at: the founder's own phone always has data on
/// it, and the render harness fixture is deliberately lived-in. Nothing else
/// in the suite walks every tab with absolutely nothing in the store.
void emptyAppTests() {
  testWidgets('every tab survives a completely empty ledger', (
    WidgetTester tester,
  ) async {
    // A REAL phone size, not a tall test surface. An overflow is a function of
    // height, so a 3200px window would hide the very thing this looks for.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    state.startWithExampleData();
    await state.deleteEverything();

    // PAST THE WELCOME AGAIN, and the order of these two lines is the whole
    // point of the fixture.
    //
    // A wipe now clears `onboardedAt` as well, so a wiped phone genuinely
    // starts over and meets the welcome. That is correct, and it is not what
    // this test is about: the subject here is every TAB surviving an empty
    // ledger, which is a state somebody reaches by being introduced and
    // simply not having typed anything yet. Marking it after the wipe says
    // that, where marking it before said something the app no longer does.
    state.startWithExampleData();

    await tester.runAsync(loadRealFonts);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();

    for (final IconData tab in <IconData>[
      Icons.menu_book_outlined,
      Icons.insert_chart_outlined,
      Icons.track_changes_outlined,
      Icons.account_balance_wallet_outlined,
    ]) {
      await tester.tap(find.byIcon(tab));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'a tab threw or overflowed on an empty ledger',
      );
    }
  });
}
