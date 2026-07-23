// Quick-add helpers: the recent-label chips and the remembered account that
// take typing out of the highest-frequency action. Newest-first ordering,
// distinct labels, the generic fallbacks filtered out, and a remembered account
// that must still exist. Junk never throws.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/quickadd.dart';

void main() {
  group('recentLabels', () {
    final txs = [
      {'type': 'expense', 'label': 'Groceries', 'date': '2026-07-01', 'accountId': 'a'},
      {'type': 'expense', 'label': 'Load', 'date': '2026-07-05', 'accountId': 'a'},
      {'type': 'income', 'label': 'Sweldo', 'date': '2026-07-04'},
      {'type': 'expense', 'label': 'groceries', 'date': '2026-07-06'}, // dup, newer
      {'type': 'expense', 'label': '', 'date': '2026-07-07'}, // blank, skipped
      {'type': 'expense', 'label': 'Expense', 'date': '2026-07-08'}, // fallback, skipped
    ];

    test('newest first, distinct, filters blanks and fallbacks', () {
      final r = recentLabels(txs, 'expense');
      // groceries (07-06) newest, then Load (07-05). "Groceries" and "groceries"
      // collapse to one, keeping the first-seen spelling at that newest slot.
      expect(r, ['groceries', 'Load']);
    });

    test('filters by type', () {
      expect(recentLabels(txs, 'income'), ['Sweldo']);
    });

    test('honors the limit', () {
      final many = [
        for (var i = 0; i < 10; i++)
          {'type': 'expense', 'label': 'L$i', 'date': '2026-07-${(i + 1).toString().padLeft(2, '0')}'},
      ];
      expect(recentLabels(many, 'expense', limit: 3).length, 3);
    });

    test('junk never throws', () {
      expect(recentLabels(null, 'expense'), isEmpty);
      expect(recentLabels([42, 'x', {}], 'expense'), isEmpty);
    });
  });

  group('lastUsedAccountId', () {
    test('returns the newest account that still exists', () {
      final txs = [
        {'accountId': 'a', 'date': '2026-07-01'},
        {'accountId': 'b', 'date': '2026-07-05'},
        {'accountId': 'a', 'date': '2026-07-03'},
      ];
      expect(lastUsedAccountId(txs, {'a', 'b'}), 'b');
    });

    test('skips a remembered account that was deleted', () {
      final txs = [
        {'accountId': 'gone', 'date': '2026-07-09'},
        {'accountId': 'a', 'date': '2026-07-02'},
      ];
      expect(lastUsedAccountId(txs, {'a'}), 'a');
    });

    test('null when nothing was logged from an account', () {
      final txs = [
        {'label': 'Cash spend', 'date': '2026-07-01'},
      ];
      expect(lastUsedAccountId(txs, {'a'}), isNull);
    });

    test('junk never throws', () {
      expect(lastUsedAccountId(null, {'a'}), isNull);
      expect(lastUsedAccountId([42, 'x', {}], {'a'}), isNull);
    });
  });
}
