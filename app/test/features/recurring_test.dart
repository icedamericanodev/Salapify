// Telling Salapify about your rent.
//
// THE DEFECT THIS FEATURE EXISTS TO FIX, and it is a money one rather than a
// convenience one. `upcomingCommitments` reads `data['recurring']` and safe to
// spend is liquid MINUS what it finds there. With no way to add a recurring
// bill, every bill had to arrive from a restored backup, so a new user's rent
// counted as spendable. The figure was not slightly wrong, it was FLATTERING,
// and safe to spend is the one number in this app somebody spends against.
//
// So the assertion that carries this file is not "a row was written". It is
// that the number on Home goes DOWN by the bill, which is the only thing the
// feature is actually for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/core/money/recurring.dart'
    show recurringSaveLastPosted;
import 'package:salapify/core/state/financial_state.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart' show sampleAnchor;
import 'package:salapify/features/plan/recurring_rows.dart';

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

/// Walk to Plan > Upcoming by tapping.
Future<void> _openUpcoming(WidgetTester tester, LedgerStore store) async {
  await tester.pumpWidget(_app(store));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(NavBar), matching: find.text('Plan')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Upcoming'));
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder what) async {
  await tester.scrollUntilVisible(
    what,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Fill the sheet and save. [day] is a day-of-month chip.
Future<void> _fill(
  WidgetTester tester, {
  required String label,
  required String amount,
  required int day,
}) async {
  await tester.enterText(find.byType(TextField).first, label);
  await tester.enterText(find.byType(TextField).at(1), amount);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(PickChip, '$day'));
  await tester.pumpAndSettle();
  await _scrollTo(tester, find.widgetWithText(PillButton, 'Save'));
  await tester.tap(find.widgetWithText(PillButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  group('the rows, and the sentences under them', () {
    test('income first, then largest, and stable on a tie', () {
      final rows = recurringRows({
        'recurring': [
          {
            'id': 'a',
            'type': 'expense',
            'label': 'Small',
            'amount': 100.0,
            'dayOfMonth': 5,
          },
          {
            'id': 'b',
            'type': 'income',
            'label': 'Sweldo',
            'amount': 18500.0,
            'dayOfMonth': 15,
          },
          {
            'id': 'c',
            'type': 'expense',
            'label': 'Rent',
            'amount': 10000.0,
            'dayOfMonth': 1,
          },
        ],
      });

      expect(rows.map((r) => r.label), ['Sweldo', 'Rent', 'Small']);

      // Two equal bills must come back in the same order every time, or the
      // list swaps places on every rebuild and looks like it is twitching.
      final tie = {
        'recurring': [
          {
            'id': 'z',
            'type': 'expense',
            'label': 'Z',
            'amount': 500.0,
            'dayOfMonth': 1,
          },
          {
            'id': 'a',
            'type': 'expense',
            'label': 'A',
            'amount': 500.0,
            'dayOfMonth': 1,
          },
        ],
      };
      expect(
        recurringRows(tie).map((r) => r.id),
        recurringRows(tie).map((r) => r.id),
      );
    });

    test('a day of the month is never printed as a date', () {
      // screen_readability's rule, seen from the other side. The stored value
      // repeats every month, so printing it as a full date would invent a
      // month the data never said.
      expect(ordinalDay(1), 'the 1st');
      expect(ordinalDay(2), 'the 2nd');
      expect(ordinalDay(3), 'the 3rd');
      expect(ordinalDay(11), 'the 11th');
      expect(ordinalDay(21), 'the 21st');
      expect(ordinalDay(31), 'the 31st');
    });

    test('the caption says whether this month is already dealt with', () {
      // The only thing about the row a person cannot work out by looking at
      // it, and the thing that decides whether the amount still stands between
      // them and their safe to spend.
      const unposted = RecurringRow(
        id: 'r',
        label: 'Rent',
        amount: 10000,
        dayOfMonth: 1,
        income: false,
        accountId: 'a',
        lastPosted: '',
      );
      expect(
        recurringCaption(unposted, sampleAnchor),
        'Every month on the 1st',
      );

      const posted = RecurringRow(
        id: 'r',
        label: 'Rent',
        amount: 10000,
        dayOfMonth: 1,
        income: false,
        accountId: 'a',
        lastPosted: '2026-09',
      );
      expect(posted.postedIn(sampleAnchor), isTrue);
      expect(
        recurringCaption(posted, sampleAnchor),
        contains('already counted this month'),
      );
    });

    test('a stale marker from an older month does NOT read as posted', () {
      const old = RecurringRow(
        id: 'r',
        label: 'Rent',
        amount: 10000,
        dayOfMonth: 1,
        income: false,
        accountId: 'a',
        lastPosted: '2026-08',
      );
      expect(
        old.postedIn(sampleAnchor),
        isFalse,
        reason:
            'last month\'s marker counts as this month, so a bill that is '
            'genuinely still due is treated as handled',
      );
    });

    test('the summary shows both directions, never a net', () {
      // "You are 15,000 ahead each month" hides the size of the commitment,
      // which is the thing somebody is deciding about.
      final rows = recurringRows({
        'recurring': [
          {
            'id': 'a',
            'type': 'income',
            'label': 'Sweldo',
            'amount': 18500.0,
            'dayOfMonth': 15,
          },
          {
            'id': 'b',
            'type': 'expense',
            'label': 'Rent',
            'amount': 10000.0,
            'dayOfMonth': 1,
          },
        ],
      });
      final s = recurringSummary(rows);
      expect(s, contains('18,500'));
      expect(s, contains('10,000'));
      expect(recurringSummary(const []), '');
    });
  });

  group('adding a bill, by hand, and what it does to the money', () {
    testWidgets('SAFE TO SPEND GOES DOWN by the bill', (tester) async {
      // The whole feature, in one assertion. Everything else here is detail.
      final store = await memoryStore(livedIn());
      final before = FinancialState.of(store.data, sampleAnchor);

      await _openUpcoming(tester, store);
      await _scrollTo(tester, find.widgetWithText(PillButton, 'Add another'));
      await tester.tap(find.widgetWithText(PillButton, 'Add another'));
      await tester.pumpAndSettle();

      // Day 14, which is BEFORE the 15th payday and AFTER the anchor's 11th,
      // so it genuinely falls inside the days this cycle still has to cover.
      await _fill(tester, label: 'Rent', amount: '9000', day: 14);

      final after = FinancialState.of(store.data, sampleAnchor);

      expect(
        after.committed,
        before.committed + 9000,
        reason:
            'the bill was saved and nothing set it aside, so safe to spend '
            'still counts the rent as money the user can spend',
      );
      expect(after.available, before.available - 9000);

      // Did anything happen. The two above would also hold if the sheet had
      // written nothing AND the figures were already zero.
      //
      // RELATIVE TO THE FIXTURE, which already ships Meralco, Spotify and the
      // sweldo. The first version asserted the list had exactly one row and
      // failed on the fixture rather than on the feature.
      expect(
        (store.data['recurring'] as List).where((r) => r['label'] == 'Rent'),
        hasLength(1),
        reason: 'the sheet saved nothing',
      );
    });

    testWidgets('a bill whose day has PASSED is not charged again', (
      tester,
    ) async {
      // Add a bill on the 20th whose day is the 3rd. That money already went
      // out. Counting it against what is left before payday would make safe to
      // spend too low for the rest of the month, which is the opposite error
      // and just as wrong.
      final store = await memoryStore(livedIn());
      final before = FinancialState.of(store.data, sampleAnchor);

      await _openUpcoming(tester, store);
      await _scrollTo(tester, find.widgetWithText(PillButton, 'Add another'));
      await tester.tap(find.widgetWithText(PillButton, 'Add another'));
      await tester.pumpAndSettle();
      await _fill(tester, label: 'Rent', amount: '9000', day: 3);

      final saved = (store.data['recurring'] as List).firstWhere(
        (r) => r['label'] == 'Rent',
      );
      expect(
        saved['lastPosted'],
        '2026-09',
        reason:
            'a bill whose day already passed was left unstamped, so it is '
            'about to be counted against a month it has already left',
      );
      expect(
        FinancialState.of(store.data, sampleAnchor).committed,
        before.committed,
      );
    });

    testWidgets('and it is on the screen afterwards, editable', (tester) async {
      // A write path is not tested until somebody can follow it. The row is
      // the only way to correct a bill whose amount went up.
      final store = await memoryStore(livedIn());
      await _openUpcoming(tester, store);
      await _scrollTo(tester, find.widgetWithText(PillButton, 'Add another'));
      await tester.tap(find.widgetWithText(PillButton, 'Add another'));
      await tester.pumpAndSettle();
      // A LABEL THE FIXTURE DOES NOT ALREADY USE. The lived-in ledger ships
      // with Meralco and Spotify, and that name appears on the day rows above
      // as well as in this list, so reusing it made the finder match three
      // widgets and fail with "Bad state: Too many elements" rather than with
      // anything about the feature.
      await _fill(tester, label: 'Internet', amount: '1699', day: 14);

      // SCOPED TO THE REPEATING LIST. A bill due on the 14th also appears in
      // the day rows above, so a bare `find.text` matches twice and fails with
      // "Bad state: Too many elements" rather than with anything about the
      // feature. Those day rows are `_UpcomingDayRow`; only this list uses
      // `ItemRow`.
      final row = find.widgetWithText(ItemRow, 'Internet');
      await _scrollTo(tester, row);
      expect(row, findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Edit this'), findsOneWidget);
      expect(find.text('Delete this'), findsOneWidget);
    });

    testWidgets('editing changes the amount without losing the marker', (
      tester,
    ) async {
      final d = livedIn();
      d['recurring'] = [
        {
          'id': 'r1',
          'type': 'expense',
          'label': 'Meralco',
          'amount': 3200.0,
          'dayOfMonth': 14,
          'accountId': 'a_bpi',
          'lastPosted': '',
        },
      ];
      final store = await memoryStore(d);

      await _openUpcoming(tester, store);
      // Scoped to the repeating list, for the reason above: this bill is due
      // inside the window so it is drawn twice on this screen.
      final row = find.widgetWithText(ItemRow, 'Meralco');
      await _scrollTo(tester, row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '4100');
      await tester.pumpAndSettle();
      await _scrollTo(tester, find.widgetWithText(PillButton, 'Save'));
      await tester.tap(find.widgetWithText(PillButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = (store.data['recurring'] as List).first;
      expect(amountOf(saved['amount']), 4100);
      expect(
        saved['accountId'],
        'a_bpi',
        reason:
            'the edit rebuilt the row from the form and dropped a field the '
            'sheet does not show',
      );
    });
  });

  group('the empty state can be acted on', () {
    testWidgets('a brand new ledger has a way in, and says why it matters', (
      tester,
    ) async {
      // THE TEST WAS WRONG ABOUT THE APP, not the other way round, and the
      // correction is worth keeping. It asserted the "Nothing scheduled yet"
      // empty state, which a fresh ledger does NOT reach: `sweldoTimeline`
      // still emits today's row carrying the opening balance, so `up.isEmpty`
      // is false the moment there is an account with any money in it. Dumping
      // every Text on the screen is what settled it rather than more guessing.
      //
      // What a new user actually gets is better than what I had asserted: the
      // What repeats section, the sentence naming the gap, and the button.
      final store = await memoryStore({
        'accounts': [
          {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 500.0},
        ],
      });
      await _openUpcoming(tester, store);

      await _scrollTo(tester, find.text('What repeats'));
      expect(
        find.textContaining('still counts your bills as available'),
        findsOneWidget,
        reason:
            'nothing tells a new user their safe to spend is flattering until '
            'they record a bill',
      );
      expect(
        find.widgetWithText(PillButton, 'Add the first one'),
        findsOneWidget,
        reason:
            'the screen names a gap and gives no way to close it, which is the '
            'instruction-nobody-can-follow defect Accounts and Budget shipped',
      );
    });

    testWidgets('and a ledger with no bills SAYS the figure is flattering', (
      tester,
    ) async {
      // Not a quiet empty list. Safe to spend counts the rent as spendable
      // until something is here, and saying so is the difference between an
      // empty section and a reason to fill it.
      final d = livedIn();
      d.remove('recurring');
      await _openUpcoming(tester, await memoryStore(d));

      await _scrollTo(tester, find.text('What repeats'));
      expect(
        find.textContaining('still counts your bills as available'),
        findsOneWidget,
      );
    });
  });

  group('the engine owns the posting rule, not the sheet', () {
    test('recurringSaveLastPosted is what decides, and it is golden locked', () {
      // Pinned here so a future change to the sheet cannot quietly reimplement
      // this. A day still to come leaves the marker empty; a day already past
      // stamps this month.
      expect(
        recurringSaveLastPosted(
          dayOfMonth: 14,
          existingLastPosted: '',
          now: sampleAnchor,
          isEdit: false,
        ),
        '',
      );
      expect(
        recurringSaveLastPosted(
          dayOfMonth: 3,
          existingLastPosted: '',
          now: sampleAnchor,
          isEdit: false,
        ),
        '2026-09',
      );

      // An edit never stamps BACKWARDS past a marker already further ahead.
      expect(
        recurringSaveLastPosted(
          dayOfMonth: 3,
          existingLastPosted: '2026-10',
          now: sampleAnchor,
          isEdit: true,
        ),
        '2026-10',
      );
    });
  });
}
