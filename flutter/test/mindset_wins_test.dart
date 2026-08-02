// Money Mindset Phase 4's pure logic: the 30-day snapshot (mindsetSnapshot)
// and the single rule-based insight (mindsetInsight). No widgets here; the
// screen-level behavior (Small Wins entry, editing, prefill) is covered in
// mindset_screen_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_wins.dart';

void main() {
  final now = DateTime(2026, 8, 2, 10, 30);
  String isoDaysAgo(int days) =>
      now.subtract(Duration(days: days)).toIso8601String();

  group('within30Days', () {
    test('today counts', () {
      expect(within30Days(isoDaysAgo(0), now), isTrue);
    });

    test('exactly 30 days ago counts (inclusive boundary)', () {
      expect(within30Days(isoDaysAgo(30), now), isTrue);
    });

    test('31 days ago does not count', () {
      expect(within30Days(isoDaysAgo(31), now), isFalse);
    });

    test('a future date does not count', () {
      final tomorrow = now.add(const Duration(days: 1)).toIso8601String();
      expect(within30Days(tomorrow, now), isFalse);
    });

    test('junk or missing values do not count', () {
      expect(within30Days(null, now), isFalse);
      expect(within30Days('not a date', now), isFalse);
      expect(within30Days(12345, now), isFalse);
    });
  });

  group('validWinAmount', () {
    test('a positive amount is usable', () {
      expect(validWinAmount(150), 150.0);
      expect(validWinAmount(150.5), 150.5);
    });

    test('zero is not spending avoided, it is a blank field', () {
      expect(validWinAmount(0), isNull);
    });

    test('a negative amount is rejected', () {
      expect(validWinAmount(-50), isNull);
    });

    test('non-numeric or non-finite values are rejected', () {
      expect(validWinAmount('150'), isNull);
      expect(validWinAmount(null), isNull);
      expect(validWinAmount(double.nan), isNull);
      expect(validWinAmount(double.infinity), isNull);
    });
  });

  group('mindsetSnapshot', () {
    test('everything empty reads as all zero', () {
      final snap = mindsetSnapshot(
        wins: const [],
        mindsetChecks: const [],
        mindsetWaiting: const [],
        now: now,
      );
      expect(snap.decisionChecksCompleted, 0);
      expect(snap.purchasesPaused, 0);
      expect(snap.purchasesSkipped, 0);
      expect(snap.confirmedSpendingAvoided, 0);
      expect(snap.spendingAvoidedRecordCount, 0);
    });

    test('counts decision checks within 30 days, excludes older ones', () {
      final snap = mindsetSnapshot(
        wins: const [],
        mindsetChecks: [
          {'id': 'a', 'verdict': 'fitsPlan', 'date': isoDaysAgo(1)},
          {'id': 'b', 'verdict': 'pause24h', 'date': isoDaysAgo(29)},
          {'id': 'c', 'verdict': 'notInPlan', 'date': isoDaysAgo(31)},
        ],
        mindsetWaiting: const [],
        now: now,
      );
      expect(snap.decisionChecksCompleted, 2);
    });

    test('purchases paused counts every waiting item in the window, any '
        'status; purchases skipped is the "skipped" subset', () {
      final snap = mindsetSnapshot(
        wins: const [],
        mindsetChecks: const [],
        mindsetWaiting: [
          {'id': 'w1', 'status': 'waiting', 'createdAt': isoDaysAgo(2)},
          {'id': 'w2', 'status': 'skipped', 'createdAt': isoDaysAgo(3)},
          {'id': 'w3', 'status': 'dismissed', 'createdAt': isoDaysAgo(5)},
          // Outside the window: paused long enough ago not to count.
          {'id': 'w4', 'status': 'skipped', 'createdAt': isoDaysAgo(40)},
        ],
        now: now,
      );
      expect(snap.purchasesPaused, 3);
      expect(snap.purchasesSkipped, 1);
    });

    test('confirmed spending avoided sums only wins with a valid amount, '
        'in the 30-day window; ignores missing, zero, or invalid amounts '
        'and wins outside the window', () {
      final snap = mindsetSnapshot(
        wins: [
          {
            'id': '1',
            'text': 'Skipped shoes',
            'amount': 1500,
            'date': isoDaysAgo(1),
          },
          {'id': '2', 'text': 'No amount noted', 'date': isoDaysAgo(1)},
          {
            'id': '3',
            'text': 'Zero is blank, not free',
            'amount': 0,
            'date': isoDaysAgo(1),
          },
          {
            'id': '4',
            'text': 'Too old to count',
            'amount': 500,
            'date': isoDaysAgo(45),
          },
          {
            'id': '5',
            'text': 'Packed lunch',
            'amount': 200,
            'date': isoDaysAgo(10),
          },
        ],
        mindsetChecks: const [],
        mindsetWaiting: const [],
        now: now,
      );
      expect(snap.confirmedSpendingAvoided, 1700.0);
      expect(snap.spendingAvoidedRecordCount, 2);
    });
  });

  group('mindsetInsight', () {
    String? noNames(String id) => null;

    test('fewer than 3 relevant records yields no insight', () {
      final insight = mindsetInsight(
        mindsetWaiting: [
          {'id': 'w1', 'status': 'skipped', 'createdAt': isoDaysAgo(1)},
          {'id': 'w2', 'status': 'skipped', 'createdAt': isoDaysAgo(2)},
        ],
        now: now,
        categoryName: noNames,
      );
      expect(insight, isNull);
    });

    test('3 skipped purchases in the window names the count', () {
      final insight = mindsetInsight(
        mindsetWaiting: [
          {'id': 'w1', 'status': 'skipped', 'createdAt': isoDaysAgo(1)},
          {'id': 'w2', 'status': 'skipped', 'createdAt': isoDaysAgo(2)},
          {'id': 'w3', 'status': 'skipped', 'createdAt': isoDaysAgo(3)},
          // Outside the window: does not add to the count.
          {'id': 'w4', 'status': 'skipped', 'createdAt': isoDaysAgo(31)},
        ],
        now: now,
        categoryName: noNames,
      );
      expect(
        insight,
        'Waiting 24 hours helped you skip 3 purchases this month.',
      );
    });

    test('a clear category cluster is named when skips are below the '
        'minimum', () {
      final insight = mindsetInsight(
        mindsetWaiting: [
          {
            'id': 'w1',
            'status': 'waiting',
            'categoryId': 'dining',
            'createdAt': isoDaysAgo(1),
          },
          {
            'id': 'w2',
            'status': 'dismissed',
            'categoryId': 'dining',
            'createdAt': isoDaysAgo(2),
          },
          {
            'id': 'w3',
            'status': 'reviewed',
            'categoryId': 'dining',
            'createdAt': isoDaysAgo(3),
          },
        ],
        now: now,
        categoryName: (id) => id == 'dining' ? 'Dining' : null,
      );
      expect(insight, 'Most of your pauses happened in Dining.');
    });

    test('an even split across categories names no pattern', () {
      final insight = mindsetInsight(
        mindsetWaiting: [
          {'id': 'w1', 'categoryId': 'dining', 'createdAt': isoDaysAgo(1)},
          {'id': 'w2', 'categoryId': 'dining', 'createdAt': isoDaysAgo(2)},
          {'id': 'w3', 'categoryId': 'shopping', 'createdAt': isoDaysAgo(3)},
          {'id': 'w4', 'categoryId': 'shopping', 'createdAt': isoDaysAgo(4)},
        ],
        now: now,
        categoryName: (id) => id == 'dining' ? 'Dining' : 'Shopping',
      );
      expect(insight, isNull);
    });

    test('a category that no longer resolves to a name yields no insight '
        'rather than a blank one', () {
      final insight = mindsetInsight(
        mindsetWaiting: [
          {'id': 'w1', 'categoryId': 'deleted', 'createdAt': isoDaysAgo(1)},
          {'id': 'w2', 'categoryId': 'deleted', 'createdAt': isoDaysAgo(2)},
          {'id': 'w3', 'categoryId': 'deleted', 'createdAt': isoDaysAgo(3)},
        ],
        now: now,
        categoryName: noNames,
      );
      expect(insight, isNull);
    });
  });
}
