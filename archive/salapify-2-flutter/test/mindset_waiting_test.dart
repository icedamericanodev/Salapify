// Unit suite for money/mindset_waiting.dart: the pure helpers behind Money
// Mindset Phase 3's Waiting list. Which items are still waiting, sorted
// soonest first, whether one is due, and the compact revisit label. No RN
// counterpart and nothing golden-locked; junk in, junk out like the rest of
// the money layer.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_waiting.dart';

void main() {
  final now = DateTime(2026, 7, 15, 12); // noon, 15 July 2026.

  Map<String, dynamic> item({
    String id = 'w1',
    String status = 'waiting',
    DateTime? revisitAt,
  }) => {
    'id': id,
    'status': status,
    if (revisitAt != null) 'revisitAt': revisitAt.toIso8601String(),
  };

  group('waitingItems', () {
    test('keeps only status waiting, drops reviewed/dismissed/skipped', () {
      final list = [
        item(id: 'a', status: 'waiting', revisitAt: now),
        item(id: 'b', status: 'reviewed', revisitAt: now),
        item(id: 'c', status: 'dismissed', revisitAt: now),
        item(id: 'd', status: 'skipped', revisitAt: now),
      ];
      final out = waitingItems(list);
      expect(out.map((e) => e['id']), ['a']);
    });

    test('sorts soonest revisit first', () {
      final list = [
        item(id: 'late', revisitAt: now.add(const Duration(hours: 20))),
        item(id: 'soon', revisitAt: now.add(const Duration(hours: 1))),
        item(id: 'mid', revisitAt: now.add(const Duration(hours: 10))),
      ];
      final out = waitingItems(list);
      expect(out.map((e) => e['id']), ['soon', 'mid', 'late']);
    });

    test('an item with no readable revisitAt sorts last, never throws', () {
      final list = [
        item(id: 'good', revisitAt: now),
        {'id': 'bad', 'status': 'waiting', 'revisitAt': 'not-a-date'},
        {'id': 'missing', 'status': 'waiting'},
      ];
      expect(() => waitingItems(list), returnsNormally);
      expect(waitingItems(list).first['id'], 'good');
    });

    test('junk entries (null, a number, a bare string) are skipped', () {
      final list = [null, 42, 'x', item(id: 'real', revisitAt: now)];
      expect(waitingItems(list).map((e) => e['id']), ['real']);
    });

    test('a non-list input reads as empty', () {
      expect(waitingItems(null), isEmpty);
      expect(waitingItems('not a list'), isEmpty);
    });
  });

  group('isDue', () {
    test('false with time left', () {
      expect(
        isDue(item(revisitAt: now.add(const Duration(hours: 1))), now),
        isFalse,
      );
    });

    test('true exactly at the revisit moment and after', () {
      expect(isDue(item(revisitAt: now), now), isTrue);
      expect(
        isDue(item(revisitAt: now.subtract(const Duration(minutes: 1))), now),
        isTrue,
      );
    });

    test('true (fails toward asking) when revisitAt is missing or junk', () {
      expect(isDue({'id': 'x', 'status': 'waiting'}, now), isTrue);
      expect(
        isDue({'id': 'x', 'status': 'waiting', 'revisitAt': 'nope'}, now),
        isTrue,
      );
    });
  });

  group('timeUntilDue', () {
    test('the exact remaining duration when not yet due', () {
      final d = timeUntilDue(
        item(revisitAt: now.add(const Duration(hours: 5))),
        now,
      );
      expect(d, const Duration(hours: 5));
    });

    test('null once due, never negative', () {
      expect(timeUntilDue(item(revisitAt: now), now), isNull);
      expect(
        timeUntilDue(
          item(revisitAt: now.subtract(const Duration(hours: 3))),
          now,
        ),
        isNull,
      );
    });
  });

  group('revisitLabel', () {
    test('"Ready to revisit" once due', () {
      expect(revisitLabel(item(revisitAt: now), now), 'Ready to revisit');
    });

    test('rounds down to whole hours with an hour or more left', () {
      expect(
        revisitLabel(item(revisitAt: now.add(const Duration(hours: 18))), now),
        'Revisit in 18h',
      );
      expect(
        revisitLabel(
          item(revisitAt: now.add(const Duration(hours: 1, minutes: 59))),
          now,
        ),
        'Revisit in 1h',
      );
    });

    test('minutes under an hour', () {
      expect(
        revisitLabel(
          item(revisitAt: now.add(const Duration(minutes: 45))),
          now,
        ),
        'Revisit in 45m',
      );
    });

    test('"a moment" for under a minute', () {
      expect(
        revisitLabel(
          item(revisitAt: now.add(const Duration(seconds: 30))),
          now,
        ),
        'Revisit in a moment',
      );
    });
  });
}
