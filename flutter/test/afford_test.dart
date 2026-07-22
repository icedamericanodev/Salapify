// Unit suite for money/afford.dart, the "Kaya mo ba ito?" Afford-This test.
// This is NEW composition (not a port), so it is asserted against a controlled
// fixture whose every engine output is hand computed:
//
//   accounts:   one cash account of 20,000  -> liquid 20,000, buffer 20,000
//   recurring:  one 3,000 expense, already posted this month
//               -> counted by commitmentLoad, ignored by safeToSpend
//   debts:      one credit card, remaining 10,000, minPayment 1,000, no due
//               schedule -> minimum counted by commitmentLoad, no due before
//               payday so safeToSpend stays clean
//   income:     30,000 in Apr, May, Jun 2026 (three completed months)
//               -> typicalIncome 30,000, leanIncome 30,000
//   expenses:   10,000 in May and Jun 2026 -> runway typical 10,000
//
// So with ref = 2026-07-15:
//   available (safeToSpend)      = 20,000  (no bills due before payday)
//   typicalIncome (commitmentLoad) = 30,000
//   monthlyCommitted             = 3,000 + 1,000 = 4,000
//   buffer / avgMonthlyExpense (runway) = 20,000 / 10,000

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/afford.dart';

Map<String, dynamic> _tx(String date, String type, num amount,
        {String? source}) =>
    {
      'id': 'tx-$date-$type-$amount',
      'date': date,
      'type': type,
      'amount': amount,
      'source': ?source,
    };

Map<String, dynamic> baseData() => {
      'accounts': [
        {'id': 'a1', 'kind': 'cash', 'balance': 20000},
      ],
      'assets': [],
      'debts': [
        {
          'id': 'd1',
          'name': 'Credit card',
          'type': 'credit card',
          'remaining': 10000,
          'minPayment': 1000,
        },
      ],
      'recurring': [
        {
          'id': 'r1',
          'type': 'expense',
          'label': 'Netflix',
          'amount': 3000,
          'dayOfMonth': 5,
          'lastPosted': '2026-07',
        },
      ],
      'goals': [],
      'settings': {},
      'transactions': [
        _tx('2026-04-15', 'income', 30000),
        _tx('2026-05-15', 'income', 30000),
        _tx('2026-06-15', 'income', 30000),
        _tx('2026-05-20', 'expense', 10000),
        _tx('2026-06-20', 'expense', 10000),
      ],
    };

final DateTime ref = DateTime(2026, 7, 15);

void main() {
  group('fixture sanity (the composed engine reads)', () {
    test('one-time read exposes the composed money picture', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.oneTime, amount: 5000);
      expect(r['availableNow'], 20000);
      expect(r['typicalIncome'], 30000);
      expect(r['monthlyCommitted'], 4000);
      expect(r['buffer'], 20000);
      expect(r['avgMonthlyExpense'], 10000);
      expect(r['leanIncome'], 30000);
      expect(r['hasIncomeBase'], true);
    });
  });

  group('one-time buy verdicts', () {
    test('a small buy that barely dents spendable cash is comfortable', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.oneTime, amount: 5000);
      expect(r['verdict'], 'comfortable');
      expect(r['fitsNow'], true);
      expect(r['eatsCushion'], false);
      expect(r['cushionMonthsLost'], 0.5); // 5,000 / 10,000
    });

    test('a buy eating most of spendable cash is tight, not comfortable', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.oneTime, amount: 15000); // 75% of 20,000
      expect(r['verdict'], 'tight');
      expect(r['fitsNow'], true);
      expect(r['eatsCushion'], false);
    });

    test('a buy that overflows spendable cash into the cushion is heavy', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.oneTime, amount: 25000);
      expect(r['verdict'], 'heavy');
      expect(r['fitsNow'], false);
      expect(r['eatsCushion'], true);
      expect(r['overflow'], 5000);
      expect(r['wipesCushion'], false);
      expect(r['cushionAfter'], 15000);
    });

    test('a buy that wipes the whole cushion does not fit', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.oneTime, amount: 50000);
      expect(r['verdict'], 'no-fit');
      expect(r['wipesCushion'], true);
      expect(r['cushionAfter'], 0);
    });
  });

  group('installment (BNPL / hulugan) verdicts', () {
    test('a small monthly is comfortable and reports the full cost', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.installment, amount: 1000, termMonths: 6);
      expect(r['verdict'], 'comfortable');
      expect(r['termMonths'], 6);
      expect(r['totalCost'], 6000);
      expect(r['newMonthlyCommitted'], 5000);
      // newShare = 5,000 / 30,000
      expect((r['newShare'] as double), closeTo(0.1667, 0.001));
      expect(r['fitsLean'], true);
    });

    test('a monthly that pushes spoken-for past half is tight', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.installment, amount: 12000, termMonths: 6);
      // newShare = 16,000 / 30,000 = 0.533
      expect(r['verdict'], 'tight');
      expect((r['newShare'] as double), closeTo(0.5333, 0.001));
    });

    test('a monthly that pushes spoken-for past ~two thirds is heavy', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.installment, amount: 18000, termMonths: 12);
      // newShare = 22,000 / 30,000 = 0.733
      expect(r['verdict'], 'heavy');
    });

    test('a monthly that alone eats a whole month does not fit', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.installment, amount: 30000, termMonths: 6);
      // newShare = 34,000 / 30,000 > 1
      expect(r['verdict'], 'no-fit');
    });
  });

  group('honest degradation and guards', () {
    test('an empty amount asks for input, it does not judge', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.oneTime, amount: 0);
      expect(r['applicable'], false);
      expect(r['verdict'], 'unknown');
    });

    test('junk amount coerces to nothing, never crashes', () {
      final r = affordCheck(baseData(), ref,
          mode: AffordMode.installment, amount: 'not a number');
      expect(r['applicable'], false);
      expect(r['verdict'], 'unknown');
    });

    test('an installment with no income history is unknown, not flattered', () {
      final data = baseData();
      // Only one income month: below commitmentLoad's three-month floor.
      data['transactions'] = [
        _tx('2026-06-15', 'income', 30000),
        _tx('2026-05-20', 'expense', 10000),
        _tx('2026-06-20', 'expense', 10000),
      ];
      final r = affordCheck(data, ref,
          mode: AffordMode.installment, amount: 5000, termMonths: 6);
      expect(r['hasIncomeBase'], false);
      expect(r['verdict'], 'unknown');
    });

    test('a one-time buy still gets a verdict with thin income history', () {
      final data = baseData();
      data['transactions'] = [
        _tx('2026-05-20', 'expense', 10000),
        _tx('2026-06-20', 'expense', 10000),
      ];
      final r = affordCheck(data, ref,
          mode: AffordMode.oneTime, amount: 5000);
      // No income needed to judge a cash purchase against spendable cash.
      expect(r['verdict'], 'comfortable');
    });

    test('the first payment not fitting spendable cash bumps up the verdict',
        () {
      // High income keeps the share low, but almost no liquid cash, so the
      // first installment cannot come out of pocket without dipping in.
      final data = baseData();
      data['accounts'] = [
        {'id': 'a1', 'kind': 'cash', 'balance': 500},
      ];
      data['transactions'] = [
        _tx('2026-04-15', 'income', 100000),
        _tx('2026-05-15', 'income', 100000),
        _tx('2026-06-15', 'income', 100000),
        _tx('2026-05-20', 'expense', 10000),
        _tx('2026-06-20', 'expense', 10000),
      ];
      final r = affordCheck(data, ref,
          mode: AffordMode.installment, amount: 2000, termMonths: 6);
      // Share is tiny (6,000 / 100,000) so it would read comfortable, but the
      // 2,000 first payment does not fit 500 of spendable cash.
      expect((r['newShare'] as double) < 0.5, true);
      expect(r['shortNow'] as double > 0, true);
      expect(r['verdict'], 'heavy');
    });
  });
}
