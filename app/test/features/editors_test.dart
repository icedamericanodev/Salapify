// Creating the things the app could only ever READ before.
//
// Until now an account could arrive only through a restored backup or the debug
// sample data, and a budget limit could not be set at all. Both screens carried
// instructions nobody could follow: "Add where your money actually sits", with
// no control that did it, and a Budget screen whose every row said "No limit
// set". The founder hit the second one on a real phone.
//
// These write to STORAGE, so what is tested is what lands on disk, not what the
// sheet looked like. A field that reads back wrong is worse than a field that
// refuses to save.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/commitments.dart' show safeToSpend;
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

Future<void> _tab(WidgetTester tester, String name) async {
  await tester.tap(
    find.descendant(of: find.byType(NavBar), matching: find.text(name)),
  );
  await tester.pumpAndSettle();
}

/// Tap something that may be BELOW the fold.
///
/// A modal sheet with the keyboard open is taller than the phone, so the save
/// button starts off screen and a bare `tester.tap` silently misses it: the
/// test then reports "nothing was saved" when the truth is "nothing was
/// pressed". A person scrolls to it. So does this.
///
/// The unfocus is NOT decoration. A focused TextField keeps pulling its own
/// caret back on screen every frame, so `ensureVisible` scrolls to the button
/// and the field immediately scrolls most of the way back: measured at 315
/// pixels down, then 65, with the button still 200 below the fold. Letting go
/// of the field first is what a person does before reaching for a button, and
/// it is what makes the scroll stick.
Future<void> _press(WidgetTester tester, String label) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

List<Map<String, dynamic>> _accounts(LedgerStore s) => [
  for (final a in (s.data['accounts'] as List)) (a as Map).cast<String, dynamic>(),
];

void main() {
  group('adding an account', () {
    testWidgets('the empty state now has a button that works', (tester) async {
      // An empty state whose instruction cannot be followed is the same defect
      // as a sentence pointing at a screen that cannot do the thing.
      final store = await memoryStore();
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Accounts');

      expect(find.text('Add your first account'), findsOneWidget);

      await tester.tap(find.text('Add your first account'));
      await tester.pumpAndSettle();
      expect(find.text('Add an account'), findsOneWidget);
    });

    testWidgets('it lands in storage with the balance typed', (tester) async {
      final store = await memoryStore();
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Accounts');
      await tester.tap(find.text('Add your first account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'GCash');
      await tester.enterText(find.byType(TextField).at(1), '1500.50');
      await _press(tester, 'Add account');

      final saved = _accounts(store).single;
      expect(saved['name'], 'GCash');
      expect(amountOf(saved['balance']), 1500.50);
      expect(saved['kind'], 'ewallet');
    });

    testWidgets('savings is kept OUT of safe to spend, e-wallet is not', (
      tester,
    ) async {
      // This is the whole reason the kind picker exists and why it names the
      // consequence in words. `liquidKinds` counts cash, ewallet and checking
      // and leaves savings out, because the point of safe to spend is to
      // protect savings. Picking the wrong chip is therefore a money decision,
      // not a labelling one.
      final store = await memoryStore();
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Accounts');
      await tester.tap(find.text('Add your first account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Emergency fund');
      await tester.enterText(find.byType(TextField).at(1), '50000');
      await _press(tester, 'Savings');
      await _press(tester, 'Add account');

      expect(_accounts(store).single['kind'], 'savings');
      expect(
        amountOf(safeToSpend(store.data, sampleAnchor)['liquid']),
        0.0,
        reason:
            'a savings account was counted as spendable, which is the exact '
            'failure the exclusion exists to prevent',
      );
    });

    testWidgets('a nameless account is refused, not saved blank', (
      tester,
    ) async {
      final store = await memoryStore();
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Accounts');
      await tester.tap(find.text('Add your first account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '100');
      await _press(tester, 'Add account');

      expect(find.textContaining('Give it a name'), findsOneWidget);
      expect(_accounts(store), isEmpty);
    });

    testWidgets('an unreadable balance is refused rather than taken as zero', (
      tester,
    ) async {
      final store = await memoryStore();
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Accounts');
      await tester.tap(find.text('Add your first account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'GCash');
      await tester.enterText(find.byType(TextField).at(1), '2o,000');
      await _press(tester, 'Add account');

      expect(find.textContaining('cannot be read'), findsOneWidget);
      expect(_accounts(store), isEmpty);
    });
  });

  group('setting a budget', () {
    testWidgets('the wall the founder hit now has a way through it', (
      tester,
    ) async {
      // Four rows all saying "No limit set", and nothing anywhere that could
      // set one. Worse than the empty state, because empty explains itself.
      final data = livedIn();
      data['settings'] = {'paydaySchedule': (data['settings'] as Map)['paydaySchedule']};
      data['categories'] = [
        for (final c in (data['categories'] as List))
          {...(c as Map), 'monthlyCap': 0.0},
      ];
      final store = await memoryStore(data);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');

      expect(find.text('Set limits'), findsOneWidget);
    });

    testWidgets('the monthly limit and the caps both reach storage', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '25000');
      await _press(tester, 'Save budget');

      expect(amountOf((store.data['settings'] as Map)['monthlyLimit']), 25000.0);
      // And the caps that were already set survived, rather than being wiped
      // by an editor that only meant to change the monthly figure.
      final food = (store.data['categories'] as List).firstWhere(
        (c) => (c as Map)['id'] == 'cat_food',
      );
      expect(amountOf((food as Map)['monthlyCap']), 200.0);
    });

    testWidgets('a cap bigger than the whole month still SAVES', (
      tester,
    ) async {
      // This test records a DECISION, not just a behaviour. The founder set a
      // 20,000 month, typed 50,000 against Load, and the app took it. The
      // right answer is not to block them: a refusal is the app claiming it
      // knows their money better than they do, and it traps somebody who
      // raises a cap before raising the limit. So the editor explains and
      // saves, and this test is what stops a later session reading the new
      // warning as permission to start blocking.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '20000');
      await tester.enterText(find.byType(TextField).at(1), '50000');
      await _press(tester, 'Save budget');

      final food = (store.data['categories'] as List).firstWhere(
        (c) => (c as Map)['id'] == 'cat_food',
      );
      expect(
        amountOf((food as Map)['monthlyCap']),
        50000.0,
        reason:
            'the editor silently refused or clamped a figure the user typed, '
            'which is indistinguishable from a bug',
      );
      expect(amountOf((store.data['settings'] as Map)['monthlyLimit']), 20000.0);
    });

    testWidgets('it says so, as you type, before you ever press save', (
      tester,
    ) async {
      // The old warning was set with setState and then the sheet saved and
      // popped in the same frame, so it existed in the source and nowhere a
      // human could read it. The founder hit exactly that: the app took
      // 50,000 against a 20,000 month and said nothing at all.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '20000');
      await tester.enterText(find.byType(TextField).at(1), '50000');
      // Focus leaves the monthly field the moment the cap is typed into, which
      // is the condition the note waits for.
      await tester.pumpAndSettle();

      expect(
        find.textContaining('this cap can never warn you'),
        findsOneWidget,
        reason:
            'a cap that can never fire inside the month it guards was accepted '
            'with no word to the user, which is the defect being fixed',
      );
      // And the running total, which is on whether or not anything is wrong.
      expect(find.textContaining('add up to'), findsOneWidget);
    });

    testWidgets('it stays QUIET while the monthly figure is being typed', (
      tester,
    ) async {
      // The other half of the alarm, and the half that gets alarms ignored.
      // Typing "20000" passes through 2, 20, 200 and 2000, and at 2 every cap
      // on the screen is above the limit. A sheet that lights up on every row
      // while somebody enters their headline number is an alarm crying wolf.
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('this cap can never warn you'),
        findsNothing,
        reason:
            'every row shouted while the user was halfway through typing the '
            'monthly limit, which is how a warning gets tuned out',
      );
    });

    testWidgets('an unreadable figure refuses and saves nothing', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      final before = amountOf((store.data['settings'] as Map)['monthlyLimit']);

      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'twenty thousand');
      await _press(tester, 'Save budget');

      expect(find.textContaining('cannot be read'), findsOneWidget);
      expect(
        amountOf((store.data['settings'] as Map)['monthlyLimit']),
        before,
        reason: 'an unreadable entry overwrote a limit that was already set',
      );
    });
  });
}
