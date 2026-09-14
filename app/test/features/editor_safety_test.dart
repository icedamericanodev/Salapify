// The four ways an editor sheet can quietly destroy something.
//
// Every test here guards a finding from the QA pass on the first two editor
// sheets this app grew. Three of them were rated must-fix, and all four share
// a shape: the app reports success and the user loses a real number, or loses
// the app itself, with nothing on screen ever saying so.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/shared/editor_safety.dart';

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

double _limit(LedgerStore s) =>
    amountOf((s.data['settings'] as Map)['monthlyLimit']);

void main() {
  group('opening an editor cannot round the money inside it', () {
    // toStringAsFixed(0) rounds half away from zero, and the sheet saves
    // whatever the field holds. So a limit of 20,000.50 came back as 20,001
    // and a cap of 1,234.56 came back as 1,235 by the act of OPENING the
    // editor and pressing save with nothing typed. 999.99 became 1,000.
    test('a whole peso figure still prints without decimals', () {
      expect(moneyField(20000), '20000');
      expect(moneyField(0), '0');
    });

    test('and centavos SURVIVE the trip into the field', () {
      expect(moneyField(20000.5), '20000.50');
      expect(moneyField(1234.56), '1234.56');
      expect(
        moneyField(999.99),
        '999.99',
        reason:
            'a figure one centavo under a thousand was shown as a thousand, '
            'and saving without editing would have made that true',
      );
    });

    testWidgets('proved end to end: open, save nothing, lose nothing', (
      tester,
    ) async {
      final data = livedIn();
      (data['settings'] as Map)['monthlyLimit'] = 20000.50;
      final store = await memoryStore(data);

      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Touch nothing at all.
      await tester.tap(find.text('Save budget'));
      await tester.pumpAndSettle();

      expect(
        _limit(store),
        20000.50,
        reason:
            'opening the editor and saving with no edit changed a stored peso '
            'figure, which is the one thing money meaning forbids',
      );
    });
  });

  group('the app cannot be closed by saving', () {
    // These sheets open on the ROOT navigator, whose only other page is the
    // app shell. A second pop does not close a sheet, it pops the whole app:
    // in debug go_router asserts, in release the history just empties and the
    // user is left on a blank window.
    testWidgets('tapping Save twice leaves the app standing', (tester) async {
      // The write TAKES TIME here, and that is the whole test. With an instant
      // fake the first save finishes before a second tap can land, the race
      // never opens, and a deliberately broken guard passes. That is exactly
      // what happened when this test was first written.
      final store = await memoryStore(livedIn(), const Duration(seconds: 1));
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '25000');
      await tester.tap(find.text('Save budget'));
      // Mid write, which is where a real second tap lands.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Save budget'), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byType(NavBar),
        findsOneWidget,
        reason:
            'the second save popped the app shell, so the tabs, the screen '
            'and every way back are gone',
      );
      expect(_limit(store), 25000.0);
    });

    testWidgets('and the second save is never even STARTED', (tester) async {
      // Counting writes, not accounts, and that distinction is the test. The
      // first version asserted "one account exists", which passed with the
      // guard deleted: `mutate` deep-copies the ledger before awaiting, so two
      // overlapping saves branch from the same blob and the later one wins.
      // One account, two writes, and the assertion could not tell the
      // difference. Today both copies hold the same thing. The moment a second
      // write path can overlap, the first one's change is silently lost.
      final repo = MemoryRepo(null, const Duration(seconds: 1));
      final store = LedgerStore(repo);
      await store.load();

      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Accounts');
      await tester.tap(find.text('Add your first account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'GCash');
      await tester.tap(find.text('Add account'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Add account'), warnIfMissed: false);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(NavBar), findsOneWidget);
      expect(
        repo.writes,
        1,
        reason:
            'a second save ran while the first was still in flight, so two '
            'writes both branched from the same ledger and one of them was '
            'going to be thrown away',
      );
      expect((store.data['accounts'] as List).length, 1);
    });

    testWidgets('pressing Back during the save leaves the app standing', (
      tester,
    ) async {
      // The likelier half, and the one no amount of button-disabling fixes.
      // The write is invisible, so "tap Save, nothing happened, press Back" is
      // the natural human sequence. Back pops the sheet; the save then
      // finishes and pops again, and the second pop takes the shell.
      final store = await memoryStore(livedIn(), const Duration(seconds: 1));
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '25000');
      await tester.tap(find.text('Save budget'));
      await tester.pump(const Duration(milliseconds: 100));

      // Android Back, delivered the way the system delivers it.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(
        find.byType(NavBar),
        findsOneWidget,
        reason:
            'the save finished after the sheet was already dismissed and '
            'popped the app shell, leaving a blank window with no way back',
      );
    });
  });

  group('a number that is not a number is refused, not saved as zero', () {
    // double.tryParse returns real values for these, and `n < 0` is false for
    // every one, so an unguarded check passed them through as money. The
    // screen then said "your PHP Infinity monthly limit", the sheet reported a
    // successful save, and sanitizeData coerced the value to 0 on the way to
    // disk. The limit was gone and nothing said so.
    test('Infinity, NaN and 1e400 are all refused', () {
      expect(readMoney('Infinity').value, isNull);
      expect(readMoney('NaN').value, isNull);
      expect(readMoney('1e400').value, isNull);
      expect(readMoney('-Infinity').value, isNull);
    });

    test('and ordinary money still reads', () {
      expect(readMoney('1500').value, 1500);
      expect(readMoney('1,500.50').value, 1500.50);
      expect(readMoney('  ').value, 0, reason: 'blank means no limit');
      expect(readMoney('.').value, isNull);
    });

    test('a negative is told it is negative, not that it is unreadable', () {
      final r = readMoney('-500');
      expect(r.value, isNull);
      expect(
        r.negative,
        isTrue,
        reason:
            'a legible -500 was reported as gibberish, which reads as a broken '
            'app rather than as a rule',
      );
    });

    testWidgets('proved end to end: Infinity never reaches storage', (
      tester,
    ) async {
      final data = livedIn();
      (data['settings'] as Map)['monthlyLimit'] = 20000.0;
      final store = await memoryStore(data);

      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _tab(tester, 'Plan');
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Infinity');
      await tester.tap(find.text('Save budget'));
      await tester.pumpAndSettle();

      expect(find.textContaining('cannot be read'), findsOneWidget);
      expect(
        _limit(store),
        20000.0,
        reason: 'a limit somebody had set was wiped to zero by a word',
      );
    });
  });

  testWidgets('a monthly limit with no caps can still be edited', (
    tester,
  ) async {
    // Four taps from a fresh install to a number nobody can ever change: set a
    // monthly limit, leave every cap blank (which the sheet invites), and both
    // doors into the editor close. The limit killed the empty state and the
    // missing rows killed the heading.
    final store = await memoryStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await _tab(tester, 'Plan');
    await tester.tap(find.text('Set your budget'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '20000');
    await tester.tap(find.text('Save budget'));
    await tester.pumpAndSettle();

    expect(_limit(store), 20000.0);
    expect(
      find.text('Edit'),
      findsOneWidget,
      reason:
          'the budget screen showed a limit with no control anywhere in the '
          'app that could change it',
    );

    // And the door actually opens.
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Set your budget'), findsOneWidget);
  });
}
