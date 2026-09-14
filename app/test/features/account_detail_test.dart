// What the account detail screen decides.
//
// Same split as the Accounts list: the parts with a RULE in them are top level
// functions, so they can be checked without pumping a widget, and the widget
// above them is paint.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/account_taxonomy.dart';
import 'package:salapify/features/accounts/account_detail_screen.dart';

import '../support/memory_store.dart';

void main() {
  group('finding the row', () {
    test('an id is looked for in all three collections', () {
      final data = livedIn();

      // Cash equivalents live in `accounts`.
      final bpi = findAccount(data, 'a_bpi');
      expect(bpi, isNotNull);
      expect(bpi!.$1['name'], 'BPI');
      expect(bpi.$2, AccountStore.accounts);

      // A credit card lives in `debts`, and a lookup that only walked
      // `accounts` would report the founder's own card as missing.
      final card = findAccount(data, 'd_ubp_cc');
      expect(card, isNotNull);
      expect(card!.$1['name'], 'UnionBank Rewards');
      expect(card.$2, AccountStore.debts);
    });

    test('an id that is not there comes back null, never throws', () {
      // Reachable for real. A home screen widget or a notification can deep
      // link to an account that has since been deleted, so this path is "open
      // a notification" rather than a hypothetical.
      expect(findAccount(livedIn(), 'a_deleted'), isNull);
      expect(findAccount(const {}, 'anything'), isNull);
    });
  });

  group('the entries', () {
    test('only this account, and everything of it', () {
      final gcash = entriesFor(livedIn(), 'a_gcash');
      expect(
        gcash.map((t) => t['label']),
        containsAll(['Jollibee', 'Groceries', 'Load']),
      );
      expect(
        gcash.every((t) => t['accountId'] == 'a_gcash'),
        isTrue,
        reason:
            'An entry from another account on this screen is money shown '
            'against a balance it never touched',
      );
    });

    test('a transfer shows on the account it left, and only that one', () {
      // The stored shape: one row, on the account the money moved FROM. The
      // screen does not invent the mirror row, because a row the ledger does
      // not have is money on a screen that cannot be reconciled with it.
      final bpi = entriesFor(livedIn(), 'a_bpi');
      expect(bpi.map((t) => t['label']), contains('To GCash'));

      final gcash = entriesFor(livedIn(), 'a_gcash');
      expect(gcash.map((t) => t['label']), isNot(contains('To GCash')));
    });

    test('an account with nothing logged comes back empty, not null', () {
      expect(entriesFor(livedIn(), 'd_lola'), isEmpty);
      expect(entriesFor(const {}, 'a_bpi'), isEmpty);
    });
  });
}
