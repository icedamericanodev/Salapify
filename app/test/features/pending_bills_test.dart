// Confirming a bill: did the money move, and can a person FIND it afterwards.
//
// Both halves, because the second one is the one that gets forgotten. Every
// money test on the Debt batch asked only the first question, all of them
// passed, and the founder then paid 1,500 off a loan, opened the account it
// came from, and found nothing in its history. The balance had moved and no
// entry explained why.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/core/money/statements.dart' show netWorthParts;
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/plan/pending_bills.dart';

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

double _balance(Map<String, dynamic> data, String id) {
  for (final a in (data['accounts'] as List)) {
    if (a is Map && a['id'] == id) return amountOf(a['balance']);
  }
  return double.nan;
}

/// The fixture's bills carry no account, so every money assertion below would
/// be about a transaction that moves nothing. This links one and gives it a
/// day that has already passed, which is the shape a real user has.
Map<String, dynamic> _withLinkedBill() {
  final data = livedIn();
  data['recurring'] = [
    {
      'id': 'rc_rent',
      'type': 'expense',
      'label': 'Rent',
      'amount': 9000.00,
      'dayOfMonth': 3,
      'accountId': 'a_bpi',
    },
    {
      'id': 'rc_netflix',
      'type': 'expense',
      'label': 'Netflix',
      'amount': 549.00,
      'dayOfMonth': 5,
      'accountId': 'a_bpi',
    },
  ];
  return data;
}

String _id() => 'tx_test';

/// Scroll the tab screen until [what] is on screen AND tappable.
///
/// `Screen` is a lazy ListView that leaves 130 of bottom padding for the nav
/// bar, and the test viewport is 600 tall. A control past that is FOUND by the
/// finder and then tapped at a point outside the viewport, so the tap lands on
/// nothing and the test reports that the button did not work. The same helper
/// goals_test.dart carries, for the same reason.
Future<void> _scrollTo(WidgetTester tester, Finder what) async {
  await tester.scrollUntilVisible(
    what,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the engine decides what is due, this file never restates it', () {
    test('a bill whose day has passed is pending, one still ahead is not', () {
      final data = _withLinkedBill();
      (data['recurring'] as List).add({
        'id': 'rc_later',
        'type': 'expense',
        'label': 'Later',
        'amount': 100.00,
        // sampleAnchor is the 11th, so the 28th has not arrived.
        'dayOfMonth': 28,
        'accountId': 'a_bpi',
      });

      final due = pendingBills(
        data,
        sampleAnchor,
      ).map((b) => b.row['id']).toList();
      expect(due, contains('rc_rent'));
      expect(due, contains('rc_netflix'));
      expect(
        due,
        isNot(contains('rc_later')),
        reason:
            'a bill whose day is still ahead was offered for confirmation, so '
            'the app is asking the user to pay something early',
      );
    });

    test('and it reports the date the entry will really carry', () {
      // The card promises "Will be dated Sep 3", and a person goes looking
      // there. The date comes back from the engine's own probe post rather than
      // from a day number the screen formats, so the short-month clamp cannot
      // be restated wrongly here.
      final data = _withLinkedBill();
      final rent = pendingBills(
        data,
        sampleAnchor,
      ).firstWhere((b) => b.row['id'] == 'rc_rent');
      expect(rent.date, '2026-09-03');

      // And the promise matches what confirming actually writes. Two
      // derivations of one date is one more than this feature is allowed.
      final after = postOneBill(data, 'rc_rent', sampleAnchor, _id);
      final made = (after['transactions'] as List).firstWhere(
        (t) => t is Map && t['recurringId'] == 'rc_rent',
      );
      expect(
        (made as Map)['date'],
        rent.date,
        reason:
            'the card told the person one date and the entry landed on '
            'another, so they will look in the wrong place for it',
      );
    });

    test('a 31st bill in a short month is clamped, and says so', () {
      // February is the case a screen file would get wrong. The engine clamps
      // a 31st bill onto the last day of the month; nothing here repeats that
      // rule, so this pins that the probe carries it through.
      final data = _withLinkedBill();
      data['recurring'] = [
        {
          'id': 'rc_31',
          'type': 'expense',
          'label': 'Card',
          'amount': 500.00,
          'dayOfMonth': 31,
          'accountId': 'a_bpi',
        },
      ];
      final due = pendingBills(data, DateTime(2026, 2, 28));
      expect(due, hasLength(1));
      expect(
        due.first.date,
        '2026-02-28',
        reason:
            'a 31st bill was dated into a day February does not have, or was '
            'not offered at all',
      );
    });

    test('a bill already stamped this month is not offered again', () {
      final data = _withLinkedBill();
      (data['recurring'] as List)[0]['lastPosted'] = '2026-09';
      final due = pendingBills(
        data,
        sampleAnchor,
      ).map((b) => b.row['id']).toList();
      expect(due, isNot(contains('rc_rent')));
      expect(
        due,
        contains('rc_netflix'),
        reason:
            'stamping one bill silenced the others, so the probe is asking '
            'about the whole list instead of one row',
      );
    });
  });

  group('confirming one bill', () {
    test('takes exactly the amount out of exactly that account', () {
      final before = _withLinkedBill();
      final bank = _balance(before, 'a_bpi');
      final worth = netWorthParts(before)['netWorth'] as double;

      final after = postOneBill(before, 'rc_rent', sampleAnchor, _id);

      // DIRECTIONAL, and about the named account. "Net worth fell by 9,000" is
      // also true of nine other things happening; this says which account.
      expect(
        _balance(after, 'a_bpi'),
        closeTo(bank - 9000, 0.005),
        reason: 'the bill was confirmed and the account it names did not move',
      );
      expect(
        netWorthParts(after)['netWorth'] as double,
        closeTo(worth - 9000, 0.005),
        reason: 'spending reduces net worth by exactly what was spent',
      );
    });

    test('and leaves the OTHER pending bill completely alone', () {
      // The whole reason this file hands the engine a one-row ledger. Calling
      // postDueRecurring directly would post BOTH bills, which is the automatic
      // behaviour the founder deliberately did not choose.
      final before = _withLinkedBill();
      final bank = _balance(before, 'a_bpi');

      final after = postOneBill(before, 'rc_rent', sampleAnchor, _id);

      expect(
        _balance(after, 'a_bpi'),
        closeTo(bank - 9000, 0.005),
        reason:
            'confirming rent also posted Netflix, so one tap paid two bills',
      );
      final still = pendingBills(after, sampleAnchor).map((b) => b.row['id']);
      expect(
        still,
        contains('rc_netflix'),
        reason: 'the bill nobody confirmed vanished from the list',
      );
      expect(still, isNot(contains('rc_rent')));
    });

    test('twice does not pay twice', () {
      final before = _withLinkedBill();
      final once = postOneBill(before, 'rc_rent', sampleAnchor, _id);
      final twice = postOneBill(once, 'rc_rent', sampleAnchor, _id);

      expect(
        identical(twice, once),
        isTrue,
        reason:
            'the second confirmation was not refused, so a double tap can pay '
            'the rent twice',
      );
      expect(
        (twice['transactions'] as List).length,
        (once['transactions'] as List).length,
      );
    });

    test('an unknown id changes nothing at all', () {
      final before = _withLinkedBill();
      expect(
        identical(postOneBill(before, 'rc_nope', sampleAnchor, _id), before),
        isTrue,
      );
    });

    test('a bill with no account records the entry and moves no balance', () {
      // Not a corner case: the editor allows an empty account and an old backup
      // can carry rows from before the field existed. The card says so on the
      // row, and this pins the behaviour it is describing.
      final before = _withLinkedBill();
      (before['recurring'] as List)[0].remove('accountId');
      final bank = _balance(before, 'a_bpi');
      final worth = netWorthParts(before)['netWorth'] as double;

      final after = postOneBill(before, 'rc_rent', sampleAnchor, _id);

      expect(
        (after['transactions'] as List).length,
        (before['transactions'] as List).length + 1,
        reason: 'the entry was not recorded at all',
      );
      expect(_balance(after, 'a_bpi'), closeTo(bank, 0.005));
      expect(netWorthParts(after)['netWorth'] as double, closeTo(worth, 0.005));
    });
  });

  group('and a person can SEE what it did', () {
    testWidgets('confirm on Home, then find the entry in the Ledger', (
      tester,
    ) async {
      final store = await memoryStore(_withLinkedBill());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      // The card is on Home, unprompted, because a confirmation nobody sees is
      // a confirmation nobody gives.
      expect(
        find.text('Rent'),
        findsWidgets,
        reason: 'the due bill never appeared on Home',
      );

      final bank = _balance(store.data, 'a_bpi');
      await _scrollTo(tester, find.text('I paid it').first);
      await tester.tap(find.text('I paid it').first);
      await tester.pumpAndSettle();

      expect(
        _balance(store.data, 'a_bpi'),
        closeTo(bank - 9000, 0.005),
        reason: 'the tap did not reach the store',
      );

      // HALF TWO. Walk where an auditor walks: the money moved, so something
      // has to explain why. A balance that changes with no entry behind it is
      // the defect, not a polish item.
      await tester.tap(
        find.descendant(of: find.byType(NavBar), matching: find.text('Ledger')),
      );
      await tester.pumpAndSettle();

      // SCROLLED, because the entry is dated the bill's DAY and not today.
      // Confirm a bill on the 11th that fell on the 3rd and the entry lands
      // eight days back, behind everything logged since. That is correct, the
      // engine dates it when it was due, and it is also the reason somebody can
      // tap "I paid it" and not see it where they expect. The card says so.
      await _scrollTo(tester, find.text('Rent'));
      expect(
        find.text('Rent'),
        findsWidgets,
        reason:
            'the account went down by 9,000 and the Ledger has nothing named '
            'Rent in it, so nothing on screen explains where the money went',
      );
    });

    testWidgets('and the row stops asking once it is confirmed', (
      tester,
    ) async {
      final store = await memoryStore(_withLinkedBill());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      // Counted from the derivation rather than from a literal, because a
      // lazy list only builds what is near the viewport and a bare count of
      // what is on screen is a statement about the scroll position.
      final pending = pendingBills(store.data, sampleAnchor).length;
      expect(pending, 2, reason: 'the fixture no longer has two bills due');

      await _scrollTo(tester, find.text('I paid it').first);
      await tester.tap(find.text('I paid it').first);
      await tester.pumpAndSettle();

      expect(
        pendingBills(store.data, sampleAnchor).length,
        pending - 1,
        reason:
            'the confirmed bill is still pending, so the person has no way to '
            'tell which ones they have dealt with',
      );
      await _scrollTo(tester, find.text('I paid it').first);
      expect(
        find.text('I paid it'),
        findsOneWidget,
        reason:
            'the confirmed bill is still asking to be confirmed, so the person '
            'has no way to tell which ones they have dealt with',
      );
    });
  });
}
