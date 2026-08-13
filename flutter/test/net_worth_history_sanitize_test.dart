// The other half of the net worth history feature: it must survive the one
// gate every load, save and backup passes through. sanitizeData is where a key
// the RN code never set gets dropped, so this proves netWorthHistory is carried
// (not dropped), cleaned (malformed rows removed, capped), and CONDITIONAL (an
// RN-shaped blob without it never gains the key, keeping the golden key-set
// contract intact).
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';

void main() {
  group('sanitizeData carries netWorthHistory', () {
    test('a valid history round-trips under settings', () {
      final clean = sanitizeData({
        'accounts': [],
        'settings': {
          'netWorthHistory': [
            {'month': '2026-07', 'value': 1000.0},
            {'month': '2026-08', 'value': 1250.5},
          ],
        },
      });
      final history = (clean['settings'] as Map)['netWorthHistory'] as List;
      expect(history.length, 2);
      expect(history.first['month'], '2026-07');
      expect(history.last['value'], closeTo(1250.5, 1e-9));
    });

    test('malformed rows are dropped and months de-duplicated (last wins)', () {
      final clean = sanitizeData({
        'settings': {
          'netWorthHistory': [
            {'month': '2026-07', 'value': 100.0},
            {'month': '2026-07', 'value': 200.0}, // duplicate month
            {'month': 'nope', 'value': 5.0}, // bad month shape
            {'month': '2026-08', 'value': 'x'}, // non-numeric -> _num -> 0
            'garbage',
          ],
        },
      });
      final history = (clean['settings'] as Map)['netWorthHistory'] as List;
      // 2026-07 kept once (last value), 2026-08 kept with value coerced to 0.
      expect(history.map((r) => r['month']).toList(), ['2026-07', '2026-08']);
      expect(history.first['value'], 200.0);
    });

    test('caps to 24 months, keeping the most recent', () {
      // 30 distinct consecutive months, past the 24 cap.
      final distinct = [
        for (var i = 0; i < 30; i++)
          {
            'month':
                '${2020 + (i ~/ 12)}-${(i % 12 + 1).toString().padLeft(2, '0')}',
            'value': i.toDouble(),
          },
      ];
      final clean = sanitizeData({
        'settings': {'netWorthHistory': distinct},
      });
      final history = (clean['settings'] as Map)['netWorthHistory'] as List;
      expect(history.length, 24);
      expect(history.last['value'], 29.0);
    });

    test(
      'the key is ABSENT when the blob never carried it (key-set contract)',
      () {
        final clean = sanitizeData({
          'accounts': [],
          'settings': {'currency': 'PHP'},
        });
        expect(
          (clean['settings'] as Map).containsKey('netWorthHistory'),
          isFalse,
          reason:
              'an RN-shaped blob must not gain a Flutter-era key, or the '
              'golden key-set contract breaks',
        );
      },
    );

    test('an empty history is dropped, not stored as []', () {
      final clean = sanitizeData({
        'settings': {'netWorthHistory': []},
      });
      expect(
        (clean['settings'] as Map).containsKey('netWorthHistory'),
        isFalse,
      );
    });
  });
}
