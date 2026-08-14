// Hand-computed vectors for the Money Mindset Decision Score. Every axis is
// pinned to the three worked examples the methodology was signed off against, so
// a change to the curve, a weight, or a threshold moves a number here and fails
// loudly. The axes are pure functions precisely so each branch can be checked in
// isolation and broken to prove the test fails (the repo rule for money logic).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/mindset_decision.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A ledger with several completed months of income and spending and a real
/// cushion, so the multi-month engines have a base and the comfort spectrum has
/// interior boundaries to find.
Map<String, dynamic> _spectrumBlob() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String iso(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
  DateTime back(int m, int day) => DateTime(today.year, today.month - m, day);
  final txns = <Map<String, dynamic>>[];
  for (var m = 0; m <= 5; m++) {
    txns.add({
      'id': 'in$m',
      'type': 'income',
      'label': 'Salary',
      'amount': 32000,
      'date': iso(back(m, 5)),
      'accountId': 'pay',
    });
    txns.add({
      'id': 'ex$m',
      'type': 'expense',
      'label': 'Living',
      'amount': 17000,
      'date': iso(back(m, 12)),
      'accountId': 'gcash',
    });
  }
  return <String, dynamic>{
    'schemaVersion': 12,
    'settings': {
      'onboarded': true,
      'paydaySchedule': {'mode': 'monthly', 'day': 30},
    },
    'accounts': [
      {'id': 'gcash', 'name': 'GCash', 'kind': 'ewallet', 'balance': 6000},
      {'id': 'bpi', 'name': 'BPI', 'kind': 'savings', 'balance': 54000},
      {'id': 'pay', 'name': 'Payroll', 'kind': 'checking', 'balance': 10000},
    ],
    'transactions': txns,
  };
}

Future<SalapifyStore> _loadStore(Map<String, dynamic> blob) async {
  SharedPreferences.setMockInitialValues({
    'salapify_data_v2': jsonEncode(blob),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bufferAxis (weight 40): months of cushion after the buy', () {
    test('3+ months is full marks', () {
      // Example A: buffer 90000 - 1500 = 88500, avg 20000 -> 4.425 months.
      expect(bufferAxis(88500, 20000), 100);
    });
    test('1..3 months ramps 60..100', () {
      // Example B: 40000 - 10000 = 30000, avg 18000 -> 1.667 months.
      expect(bufferAxis(30000, 18000), closeTo(73.333, 0.01));
      // Example C: 60000 - 549 = 59451, avg 24000 -> 2.477 months.
      expect(bufferAxis(59451, 24000), closeTo(89.542, 0.01));
    });
    test('under 1 month ramps 0..60, empty is zero', () {
      expect(bufferAxis(9000, 18000), closeTo(30, 0.01)); // 0.5 mo -> 30
      expect(bufferAxis(0, 18000), 0);
      expect(bufferAxis(-5000, 18000), 0); // went negative -> clamped 0
    });
    test('thin history falls back to the 10000 starter floor', () {
      expect(bufferAxis(30000, 0), 100); // 30000/10000 = 3 months proxy
    });
  });

  group('incomeAxis (weight 25)', () {
    test('one-time: <=5% full, >=50% zero', () {
      expect(incomeAxisOneTime(1500, 30000), 100); // 5%
      expect(incomeAxisOneTime(10000, 25000), closeTo(22.222, 0.01)); // 40%
      expect(incomeAxisOneTime(15000, 25000), 0); // 60% -> clamped 0
    });
    test('recurring: <=35% full, >=65% zero (new total share)', () {
      // Example C: existing 16000 + 549 on 40000 -> 41.4% share.
      expect(incomeAxisRecurring(16000, 549, 40000), closeTo(78.758, 0.01));
      expect(incomeAxisRecurring(10000, 4000, 40000), 100); // 35%
      expect(incomeAxisRecurring(26000, 0, 40000), 0); // 65% -> 0
    });
    test('no income base returns NaN so the caller drops the axis', () {
      expect(incomeAxisOneTime(1000, 0).isNaN, isTrue);
      expect(incomeAxisRecurring(0, 500, 0).isNaN, isTrue);
    });
  });

  group('reservedAxis (weight 20): dipping into bills/debt money', () {
    test('no dip is full marks', () {
      expect(reservedAxis(6500, 12000, 15), 100); // Example A
      expect(reservedAxis(0, 10000, 15), 100); // exactly break-even
    });
    test('any dip caps the axis under 50', () {
      // Example B: availableAfter -4000, committed 10000, mid-cycle.
      expect(reservedAxis(-4000, 10000, 15), closeTo(30, 0.01));
      expect(reservedAxis(-10000, 10000, 15), 0); // wipes all reserved
    });
    test('sweldo relief within 3 days halves the penalty', () {
      // Same dip as Example B but payday lands in 2 days.
      expect(reservedAxis(-4000, 10000, 2), closeTo(65, 0.01)); // 50 + 30/2
    });
  });

  group('goalAxis (weight 15)', () {
    test('with a deadline, 0 days full, 90+ days zero', () {
      // Example B: 5 monthly periods -> 150 days -> 0.
      expect(
        goalAxis({
          'delay': {'periods': 5, 'frequency': 'monthly'},
        }),
        0,
      );
      expect(
        goalAxis({
          'delay': {'periods': 1, 'frequency': 'monthly'},
        }),
        closeTo(66.667, 0.01), // 30 days -> (90-30)/90
      );
    });
    test('no deadline grades on share of remaining eaten', () {
      expect(goalAxis({'delay': null, 'percentOfRemaining': 50}), 50);
      expect(goalAxis({'delay': null, 'percentOfRemaining': 100}), 0);
    });
    test('no goal returns NaN so the caller drops the axis', () {
      expect(goalAxis(null).isNaN, isTrue);
    });
  });

  group('combineAxes: weighted average, skipped axes leave the sum', () {
    test('Example A: no goal axis -> 100', () {
      final s = combineAxes([
        (weight: wBuffer, score: 100),
        (weight: wIncome, score: 100),
        (weight: wReserved, score: 100),
        (weight: wGoal, score: double.nan), // no goal linked
      ]);
      expect(s, 100);
    });
    test('Example B: all four present -> ~40.9', () {
      final s = combineAxes([
        (weight: wBuffer, score: 73.333),
        (weight: wIncome, score: 22.222),
        (weight: wReserved, score: 30),
        (weight: wGoal, score: 0),
      ]);
      expect(mindsetRound(s), 41);
      expect(mindsetBand(s), 3);
    });
    test('Example C: no goal axis -> ~89', () {
      final s = combineAxes([
        (weight: wBuffer, score: 89.542),
        (weight: wIncome, score: 78.758),
        (weight: wReserved, score: 100),
        (weight: wGoal, score: double.nan),
      ]);
      expect(mindsetRound(s), 89);
      expect(mindsetBand(s), 1);
    });
    test('nothing to judge yet returns NaN', () {
      expect(combineAxes([(weight: 40, score: double.nan)]).isNaN, isTrue);
    });
  });

  group('bands and labels', () {
    test('thresholds 70 and 45', () {
      expect(mindsetBand(70), 1);
      expect(mindsetBand(69), 2);
      expect(mindsetBand(45), 2);
      expect(mindsetBand(44), 3);
    });
    test('impact words, never commands', () {
      expect(mindsetBandLabel(1), 'Fits comfortably');
      expect(mindsetBandLabel(2), 'Worth a pause');
      expect(mindsetBandLabel(3), 'Big impact');
    });
    test('buffer comfort labels', () {
      expect(mindsetBufferLabel(3.0), 'Comfortable');
      expect(mindsetBufferLabel(1.5), 'Okay');
      expect(mindsetBufferLabel(0.5), 'Thin');
      expect(mindsetBufferLabel(0), 'Empties your cushion');
      expect(mindsetBufferLabel(null), 'Okay');
    });
  });

  group('applyReflection: penalties only, never raises', () {
    test('Example A: two mild No answers keep Band 1', () {
      final r = applyReflection(
        100,
        essential: false,
        affordWithoutReserved: true,
        wanted24h: false,
      );
      expect(r['adjustedScore'], 82); // -8 -10
      expect(r['finalBand'], 1);
    });
    test('Example B: cannot-afford No drops it and holds Band 3', () {
      final r = applyReflection(
        41,
        essential: true,
        affordWithoutReserved: false,
        wanted24h: true,
      );
      expect(r['adjustedScore'], 16); // -25
      expect(r['finalBand'], 3);
    });
    test('all Yes changes nothing', () {
      final r = applyReflection(
        88,
        essential: true,
        affordWithoutReserved: true,
        wanted24h: true,
      );
      expect(r['adjustedScore'], 88);
      expect(r['finalBand'], 1);
    });
    test('Q2 No hard-caps the band at 2 even off a high score', () {
      // 100 - 25 = 75, which is Band 1, but "cannot afford without reserved"
      // must never show green.
      final r = applyReflection(
        100,
        essential: true,
        affordWithoutReserved: false,
        wanted24h: true,
      );
      expect(r['adjustedScore'], 75);
      expect(r['finalBand'], 2);
    });
  });

  group('creditPenalty and cool-off', () {
    test('markup costs points, capped at 30% = full 15', () {
      expect(creditPenalty(0), 0);
      expect(creditPenalty(0.15), closeTo(7.5, 1e-9));
      expect(creditPenalty(0.30), 15);
      expect(creditPenalty(0.50), 15);
    });
    test('cool-off lengthens with impact; tiny buys stay short', () {
      expect(mindsetCoolOff(1), isNull);
      expect(mindsetCoolOff(2), const Duration(days: 3));
      expect(mindsetCoolOff(3), const Duration(days: 7));
      // A ₱80 item under a day of typical spend gets the short pause.
      expect(
        mindsetCoolOff(3, cashNow: 80, avgDaily: 600),
        const Duration(days: 3),
      );
    });
  });

  group('mindsetComfortRange: the personal spending spectrum', () {
    test('ceilings are ordered and each boundary really flips the band', () async {
      final store = await _loadStore(_spectrumBlob());
      final now = DateTime.now();
      final r = mindsetComfortRange(store.data, now, maxAmount: 300000);
      final comfort = r['comfortCeiling']!;
      final caution = r['cautionCeiling']!;

      // A real interior spectrum: 0 < comfort <= caution < max.
      expect(comfort, greaterThan(0));
      expect(comfort, lessThanOrEqualTo(caution));
      expect(caution, lessThan(300000));

      // The binary search lands exactly on each boundary: at the ceiling the buy
      // is still in the band, a nudge past it is not. The 200-peso nudge clears
      // the search's sub-peso convergence.
      expect(mindsetOneTimeBand(store.data, now, comfort), 1);
      expect(
        mindsetOneTimeBand(store.data, now, comfort + 200),
        greaterThanOrEqualTo(2),
      );
      expect(
        mindsetOneTimeBand(store.data, now, caution),
        lessThanOrEqualTo(2),
      );
      expect(mindsetOneTimeBand(store.data, now, caution + 200), 3);
    });

    test(
      'band never drops as the amount rises (the search relies on this)',
      () async {
        final store = await _loadStore(_spectrumBlob());
        final now = DateTime.now();
        var prev = 0;
        for (var a = 0.0; a <= 250000; a += 5000) {
          final b = mindsetOneTimeBand(store.data, now, a);
          expect(b, greaterThanOrEqualTo(prev), reason: 'band fell at $a');
          prev = b;
        }
        // And it genuinely spans all three bands over the range.
        expect(mindsetOneTimeBand(store.data, now, 0), 1);
        expect(mindsetOneTimeBand(store.data, now, 250000), 3);
      },
    );
  });
}
