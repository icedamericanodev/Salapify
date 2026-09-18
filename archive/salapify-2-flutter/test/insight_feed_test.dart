// Unit coverage for the Phase 5 interpretation layer (money/insight_feed.dart).
//
// These are net-new presentation reads with no RN golden, so every honesty
// gate is pinned here directly: the silent branches (early month, no income,
// no history) matter as much as the speaking ones, because a fabricated
// conclusion on sparse data is the failure mode this engine exists to avoid.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/insight_feed.dart';

Map<String, dynamic> _data(List<Map<String, dynamic>> txs) => {
  'transactions': txs,
  'payments': const [],
};

Map<String, dynamic> _tx(
  String type,
  num amount,
  String date, {
  String? label,
  String? note,
}) => {
  'type': type,
  'amount': amount,
  'date': date,
  'label': ?label,
  'note': ?note,
};

void main() {
  // July 2026 has 31 days; day 20 is past both gates (0.34 and 0.5).
  final mid = DateTime(2026, 7, 20);
  final early = DateTime(2026, 7, 3);

  group('monthPulse', () {
    test('empty data says nothing at all', () {
      expect(monthPulse(_data([]), mid), isNull);
    });

    test('stays silent early in a month with spending but no income', () {
      final d = _data([_tx('expense', 900, '2026-07-02', label: 'Food')]);
      expect(monthPulse(d, early), isNull);
    });

    test('past mid-month, spending with no income is named plainly', () {
      final d = _data([_tx('expense', 900, '2026-07-02', label: 'Food')]);
      final p = monthPulse(d, mid)!;
      expect(p.tone, 'attention');
      expect(p.headline, contains('No income logged'));
      expect(p.detail, contains('₱900'));
    });

    test('spending past income is the attention read', () {
      final d = _data([
        _tx('income', 10000, '2026-07-01'),
        _tx('expense', 12000, '2026-07-05', label: 'Food'),
      ]);
      final p = monthPulse(d, mid)!;
      expect(p.tone, 'attention');
      expect(p.headline, contains('more than you earned'));
      expect(p.ratePctNow, lessThan(0));
    });

    test('best month needs three prior income months and wins them all', () {
      final d = _data([
        for (final m in ['04', '05', '06']) ...[
          _tx('income', 20000, '2026-$m-01'),
          _tx('expense', 17000, '2026-$m-10', label: 'Food'),
        ],
        _tx('income', 20000, '2026-07-01'),
        _tx('expense', 8000, '2026-07-10', label: 'Food'),
      ]);
      final p = monthPulse(d, mid)!;
      expect(p.tone, 'good');
      expect(p.confidence, 'trend');
      expect(p.headline, contains('strongest savings month'));
    });

    test('two prior months is not enough history for a best-month claim', () {
      final d = _data([
        for (final m in ['05', '06']) ...[
          _tx('income', 20000, '2026-$m-01'),
          _tx('expense', 17000, '2026-$m-10', label: 'Food'),
        ],
        _tx('income', 20000, '2026-07-01'),
        _tx('expense', 8000, '2026-07-10', label: 'Food'),
      ]);
      final p = monthPulse(d, mid)!;
      expect(p.headline, isNot(contains('strongest')));
      // It still speaks, via the vs-last-month comparison.
      expect(p.headline, contains('keeping more'));
    });

    test('keeping more vs less vs same follows the 3-point threshold', () {
      Map<String, dynamic> months(num prevSpend, num nowSpend) => _data([
        _tx('income', 10000, '2026-06-01'),
        _tx('expense', prevSpend, '2026-06-10', label: 'Food'),
        _tx('income', 10000, '2026-07-01'),
        _tx('expense', nowSpend, '2026-07-10', label: 'Food'),
      ]);
      expect(
        monthPulse(months(8000, 7000), mid)!.headline,
        contains('keeping more'),
      );
      expect(
        monthPulse(months(7000, 8000), mid)!.headline,
        contains('keeping less'),
      );
      expect(
        monthPulse(months(8000, 8100), mid)!.headline,
        contains('about the same'),
      );
    });

    test('first income month states the share without a comparison', () {
      final d = _data([
        _tx('income', 10000, '2026-07-01'),
        _tx('expense', 7600, '2026-07-05', label: 'Food'),
      ]);
      final p = monthPulse(d, mid)!;
      expect(p.headline, contains('24%'));
      expect(p.ratePctPrev, isNull);
    });

    test('junk amounts never crash and never fabricate a claim', () {
      final d = _data([
        _tx('income', double.infinity, '2026-07-01'),
        _tx('expense', 500, '2026-07-05', label: 'Food'),
      ]);
      // Non-finite savings rate reads as "no income", and at day 20 the
      // spending line speaks instead of a garbage percent.
      final p = monthPulse(d, mid);
      expect(p?.ratePctNow, isNull);
    });
  });

  group('whatChanged', () {
    test('no prior month spending refuses to compare', () {
      final w = whatChanged(
        _data([_tx('expense', 2000, '2026-07-02', label: 'Food')]),
        mid,
      );
      expect(w.comparable, isFalse);
      expect(w.shifts, isEmpty);
      expect(w.note, contains('another logged month'));
    });

    test('early month refuses to compare even with history', () {
      final w = whatChanged(
        _data([
          _tx('expense', 2000, '2026-06-10', label: 'Food'),
          _tx('expense', 2500, '2026-07-01', label: 'Food'),
        ]),
        early,
      );
      expect(w.comparable, isFalse);
      expect(w.note, contains('early in the month'));
    });

    test('paces last month to the day, so mid-month reads are fair', () {
      // Day 20 of 31: frac 20/31. Food last month 3100 paces to 2000, so
      // 3700 now is a +1700 shift, not the raw +600 a full-month diff says.
      final w = whatChanged(
        _data([
          _tx('expense', 3100, '2026-06-10', label: 'Food'),
          _tx('expense', 3700, '2026-07-05', label: 'Food'),
        ]),
        mid,
      );
      expect(w.comparable, isTrue);
      expect(w.shifts, hasLength(1));
      expect(w.shifts.first.label, 'Food');
      expect(w.shifts.first.change, closeTo(3700 - 3100 * 20 / 31, 0.01));
    });

    test('sub-floor moves and unmoved categories stay out', () {
      final w = whatChanged(
        _data([
          _tx('expense', 1000, '2026-06-10', label: 'Transport'),
          _tx('expense', 800, '2026-07-05', label: 'Transport'),
        ]),
        mid,
      );
      expect(w.shifts, isEmpty);
      expect(w.comparable, isTrue);
    });

    test('caps at three shifts, biggest first, stable on ties', () {
      final w = whatChanged(
        _data([
          for (final l in ['A', 'B', 'C', 'D']) ...[
            _tx('expense', 100, '2026-06-10', label: l),
          ],
          _tx('expense', 5000, '2026-07-05', label: 'A'),
          _tx('expense', 4000, '2026-07-05', label: 'B'),
          _tx('expense', 3000, '2026-07-05', label: 'C'),
          _tx('expense', 2000, '2026-07-05', label: 'D'),
        ]),
        mid,
      );
      expect(w.shifts, hasLength(3));
      expect(w.shifts.map((s) => s.label), ['A', 'B', 'C']);
    });

    test('a drop is reported without a driver sentence', () {
      final w = whatChanged(
        _data([
          _tx('expense', 4000, '2026-06-10', label: 'Shopping'),
          // Nothing this month: paced 4000 * 20/31 is a real drop.
        ]),
        mid,
      );
      expect(w.shifts, hasLength(1));
      expect(w.shifts.first.change, lessThan(0));
      expect(w.shifts.first.driver, isNull);
    });
  });

  group('changeDriver', () {
    test('names the dominant note group', () {
      final d = [
        _tx('expense', 900, '2026-07-02', label: 'Food', note: 'Grab food'),
        _tx('expense', 800, '2026-07-09', label: 'Food', note: 'grab food'),
        _tx('expense', 400, '2026-07-11', label: 'Food', note: 'groceries'),
      ];
      expect(changeDriver(d, 'Food', mid), 'Mostly from Grab food.');
    });

    test('names a dominant single entry when notes do not dominate', () {
      final d = [
        _tx('expense', 5000, '2026-07-02', label: 'Food'),
        _tx('expense', 700, '2026-07-09', label: 'Food'),
      ];
      expect(changeDriver(d, 'Food', mid), 'Mostly one ₱5,000 entry.');
    });

    test('a single entry alone gets no driver; the shift already says it', () {
      final d = [_tx('expense', 5000, '2026-07-02', label: 'Food')];
      expect(changeDriver(d, 'Food', mid), isNull);
    });

    test('spread spending with no pattern gets no driver', () {
      final d = [
        for (var i = 1; i <= 4; i++)
          _tx('expense', 500, '2026-07-0$i', label: 'Food'),
      ];
      expect(changeDriver(d, 'Food', mid), isNull);
    });
  });

  group('trendConclusion', () {
    test('null with no activity', () {
      expect(
        trendConclusion([
          {'income': 0.0, 'expenses': 0.0, 'net': 0.0},
        ]),
        isNull,
      );
    });

    test('counts ahead months over active months', () {
      final s = [
        {'income': 100.0, 'expenses': 50.0, 'net': 50.0},
        {'income': 100.0, 'expenses': 150.0, 'net': -50.0},
        {'income': 0.0, 'expenses': 0.0, 'net': 0.0},
        {'income': 100.0, 'expenses': 40.0, 'net': 60.0},
      ];
      expect(
        trendConclusion(s),
        'You kept more than you spent in 2 of the last 3 active months.',
      );
    });
  });

  group('weekdayLine', () {
    test('null when the week is near-flat', () {
      final d = _data([
        _tx('expense', 500, '2026-07-06', label: 'Food'), // Monday
        _tx('expense', 500, '2026-07-07', label: 'Food'),
        _tx('expense', 450, '2026-07-08', label: 'Food'),
      ]);
      expect(weekdayLine(d, mid), isNull);
    });

    test('speaks only on a real gap, as a tendency', () {
      final d = _data([
        // Fridays heavy across weeks; two light days for contrast.
        _tx('expense', 3000, '2026-07-03', label: 'Food'),
        _tx('expense', 3000, '2026-07-10', label: 'Food'),
        _tx('expense', 3000, '2026-07-17', label: 'Food'),
        _tx('expense', 200, '2026-07-06', label: 'Food'),
        _tx('expense', 200, '2026-07-07', label: 'Food'),
      ]);
      final line = weekdayLine(d, mid)!;
      expect(line, contains('Fridays'));
      expect(line, contains('tend to be'));
    });
  });
}
