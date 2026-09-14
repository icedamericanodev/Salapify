// What Home SAYS, with the screen actually built.
//
// The helper tests next door check the pure functions and every one of them
// passed while the assembled screen was telling the user four wrong things: a
// weekday name for a payday a month away, a payday nobody had set, "₱3,394 of
// that" against a figure the ₱3,394 had already been taken out of, and a peso
// sign on the wrong side of a minus. None of those live in a helper. They live
// in how the helpers are arranged, which only pumping the widget can see.
//
// Every case fixes "now", because this screen's content depends on the date and
// a test that passes only on the days somebody happened to run it is not a
// test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/home/home_screen.dart';

import '../support/memory_store.dart';

/// Four days before payday, with both recurring bills inside the cycle.
final _now = DateTime(2026, 9, 11, 9, 30);

Widget _app(LedgerStore store, DateTime now) => LedgerScope(
  store: store,
  child: AppClock(
    now: now,
    child: MaterialApp(
      theme: salapifyTheme(gabi),
      home: const Scaffold(body: HomeScreen()),
    ),
  ),
);

/// Every piece of text on the screen, joined, so a case can ask what it says
/// without knowing which widget happens to hold the words.
String _spoken(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? '')
    .join(' | ');

/// The screen scrolls and builds its rows lazily, so anything below the fold
/// is not in the tree until it is scrolled to. A test that forgets this reads
/// an empty answer as a passing one.
Future<void> _toBottom(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the hero figure and the sentence under it agree', (
    tester,
  ) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store, _now));
    await tester.pumpAndSettle();

    final said = _spoken(tester);

    // liquid 9,660.50 minus committed 3,394 is the hero.
    expect(said, contains('6,266'));
    expect(said, contains('.50'));

    // NOT "of that". The committed money has already been removed from the
    // hero, so "₱3,394 of that" invited the reader to subtract it twice and
    // conclude they had half the runway they really had.
    await _toBottom(tester);
    final ending = _spoken(tester);
    expect(ending, contains('₱3,394 is already set aside for 2 bills'));

    // While we are at the bottom: Latest is newest first ACROSS and WITHIN
    // days. Sep 13 holds two entries and the later one has to lead.
    expect(ending.indexOf('To GCash'), lessThan(ending.indexOf('Load')));
    expect(ending.indexOf('Groceries'), lessThan(ending.indexOf('Jollibee')));
    expect(ending, isNot(contains('of that')));
  });

  testWidgets('a payday inside the week is named, and the rail agrees with it', (
    tester,
  ) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store, _now));
    await tester.pumpAndSettle();

    final said = _spoken(tester);
    expect(said, contains('a day until payday on Tuesday.'));
    expect(said, contains('4 days to payday'));
    expect(said, contains('Aug 30 to Sep 15'));
  });

  testWidgets('a payday a month out is a date, not a weekday', (tester) async {
    // Monthly on the 30th, read on 1 October. Oct 2 is a Friday, so naming a
    // weekday said "payday on Friday" over a rail saying 29 days, and a daily
    // pace the reader would believe was wrong by a factor of 29.
    final data = livedIn();
    data['settings'] = {
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
    };
    final store = await memoryStore(data);
    await tester.pumpWidget(_app(store, DateTime(2026, 10, 1, 9)));
    await tester.pumpAndSettle();

    final said = _spoken(tester);
    expect(said, contains('until payday on Oct 30.'));
    expect(said, isNot(contains('until payday on Friday')));
  });

  testWidgets('on payday itself the rail is empty, not full', (tester) async {
    // The cycle BEGINS today. Filling the bar told somebody they had used up a
    // cycle that had not started, and the panel named two different paydays at
    // once: "payday on Tuesday" over "15 days to payday".
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store, DateTime(2026, 9, 15, 9)));
    await tester.pumpAndSettle();

    final said = _spoken(tester);
    expect(said, contains('Sep 15 to Sep 30'));
    expect(said, isNot(contains('Sep 15 to Sep 15')));
    expect(said, contains('until payday on Sep 30.'));
  });

  testWidgets('with no payday set, the screen claims no payday at all', (
    tester,
  ) async {
    // schedule.dart is explicit: guessing 15/31 for a forecast is harmless,
    // guessing it for a CLAIM is not. A fresh install was being told its
    // payday, its weekday, its day count and its cycle dates, all four
    // invented out of a fallback.
    final data = livedIn();
    data.remove('settings');
    final store = await memoryStore(data);
    await tester.pumpWidget(_app(store, _now));
    await tester.pumpAndSettle();

    final said = _spoken(tester);
    expect(said, contains('Set your payday in Plan'));
    expect(said, isNot(contains('days to payday')));
    expect(said, isNot(contains('until payday')));
  });

  testWidgets('a negative figure reads -₱, never ₱-', (tester) async {
    // Being overcommitted before payday is a normal month for this app's
    // users, not an edge case.
    final data = livedIn();
    data['accounts'] = [
      {'id': 'a_cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000.00},
    ];
    final store = await memoryStore(data);
    await tester.pumpWidget(_app(store, _now));
    await tester.pumpAndSettle();

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();

    // The sign and the digits are drawn as separate Text widgets so they can
    // take different sizes, so the assertion is that the MINUS travels with
    // the sign and never with the number.
    expect(texts, contains('-₱'));
    expect(texts.any((t) => t.startsWith('₱-')), isFalse);
    expect(texts, contains('2,394'));

    // And the pace goes silent rather than stating "₱0 a day" as a fact, which
    // is what the engine's own forecast does in the crunch case.
    expect(_spoken(tester), contains('come to more than this'));
    expect(_spoken(tester), isNot(contains('₱0.00 a day')));
  });

  testWidgets('a settled debt leaves no debt card behind', (tester) async {
    // "Owed to you ₱0, You owe ₱0" claims you are square with the world, which
    // is a different statement from having never recorded a debt. Clearing
    // your last utang was being rewarded with exactly that card.
    final data = livedIn();
    data['debts'] = [];
    data['receivables'] = [
      {'id': 'r_marco', 'name': 'Marco', 'amount': 1800.00, 'cashLeg': true, 'paid': true},
    ];
    final store = await memoryStore(data);
    await tester.pumpWidget(_app(store, _now));
    await tester.pumpAndSettle();

    expect(find.text('Debt, both ways'), findsNothing);
  });

  testWidgets('an action word that does nothing is not on the screen', (
    tester,
  ) async {
    // Three "See all" links were accent coloured text with no tap target, and
    // they were the only route to the rows the sections cap off. Debt, Bills
    // and Move announced themselves to TalkBack as buttons and did nothing.
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store, _now));
    await tester.pumpAndSettle();

    final handle = tester.ensureSemantics();

    for (final label in ['Debt', 'Bills', 'Move']) {
      final node = tester.getSemantics(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.text(label),
        ).first,
      );
      // isSemantics rather than reading a flag off the node: it checks only
      // what is named here, and the flag accessors plus containsSemantics are
      // both deprecated on the pinned SDK, where analyze is zero tolerance and
      // an info counts as a failure.
      expect(
        node,
        isSemantics(isButton: false),
        reason: '$label has no destination yet, so it must not claim to be a '
            'button. Wire it before advertising it.',
      );
    }

    handle.dispose();
  });
}
