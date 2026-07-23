// Unit suite for money/windfall.dart, the Windfall Split Planner. New
// composition (not a port), so it is asserted against a controlled fixture whose
// engine reads are hand computed:
//
//   accounts:   one cash account of 5,000   -> buffer 5,000
//   expenses:   10,000 in two completed months -> typical/avg 10,000,
//               monthsCovered not null (hasHistory true, usedFloor false)
//   so starterTarget = 10,000, starterGap = 5,000; fullTarget = 30,000
//   debts:      credit card 20,000 @ 3%/mo, personal loan 50,000 @ 1%/mo
//               (both high-rate), an SSS short-term 10,000 @ 0.5%/mo (below the
//               line, ignored), and a BNPL 3,000 with NO rate (flags rateUnfilled)
//   goal:       target 20,000 saved 15,000 -> remaining 5,000

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/windfall.dart';

Map<String, dynamic> _exp(String date, num amt) =>
    {'id': 'e$date', 'date': date, 'type': 'expense', 'label': 'x', 'amount': amt};

Map<String, dynamic> baseData() => {
      'accounts': [
        {'id': 'a1', 'kind': 'cash', 'balance': 5000},
      ],
      'debts': [
        {'id': 'cc', 'name': 'Credit card', 'type': 'credit card', 'remaining': 20000, 'monthlyRate': 3},
        {'id': 'pl', 'name': 'Personal loan', 'type': 'personal loan', 'remaining': 50000, 'monthlyRate': 1},
        {'id': 'sss', 'name': 'SSS loan', 'type': 'short term', 'remaining': 10000, 'monthlyRate': 0.5},
        {'id': 'bnpl', 'name': 'Gadget hulog', 'type': 'bnpl', 'remaining': 3000, 'monthlyRate': 0},
      ],
      'goals': [
        {'id': 'g1', 'name': 'Laptop', 'target': 20000, 'saved': 15000},
      ],
      'transactions': [
        _exp('2026-05-20', 10000),
        _exp('2026-06-20', 10000),
      ],
    };

final DateTime ref = DateTime(2026, 7, 15);

void main() {
  group('splitWindfall waterfall', () {
    test('carves the set-aside first, then fills cushion and costliest debt', () {
      final r = splitWindfall(baseData(), ref, amount: 40000, setAside: 5000);
      expect(r['applicable'], true);
      expect(r['setAside'], 5000);
      final slices = (r['slices'] as List).cast<Map<String, dynamic>>();
      // pool = 35,000: starter 5,000 -> CC 20,000 -> personal loan 10,000.
      expect(slices.length, 3);
      expect(slices[0]['key'], 'starter');
      expect(slices[0]['amount'], 5000);
      expect(slices[1]['key'], 'debt');
      expect(slices[1]['label'], 'Pay down Credit card'); // 3%/mo, costliest first
      expect(slices[1]['amount'], 20000);
      expect(slices[2]['label'], 'Pay down Personal loan');
      expect(slices[2]['amount'], 10000); // capped by the remaining pool
      expect(r['leftover'], 0);
      expect(r['allocated'], 35000);
      // The 0% BNPL is a real 0% installment, not a forgotten rate, so it is not
      // flagged; the pool is exhausted before its clear-it tier here.
      expect(r['rateUnfilled'], false);
    });

    test('a big windfall clears BNPL, fills the fuller fund, the goal, leftover',
        () {
      final r = splitWindfall(baseData(), ref, amount: 200000);
      final slices = (r['slices'] as List).cast<Map<String, dynamic>>();
      // starter 5k, CC 20k, personal 50k, BNPL 3k, fuller 20k, goal 5k.
      expect(slices.map((s) => s['key']).toList(),
          ['starter', 'debt', 'debt', 'bnpl', 'fuller', 'goal']);
      expect(slices.firstWhere((s) => s['key'] == 'bnpl')['amount'], 3000);
      expect(slices.firstWhere((s) => s['key'] == 'fuller')['amount'], 20000);
      expect(slices.firstWhere((s) => s['key'] == 'goal')['amount'], 5000);
      expect(r['leftover'], 97000);
      expect(r['allocated'], 103000);
    });

    test('a 0% BNPL is offered as a clear-it slice, not flagged as rate-less',
        () {
      final data = baseData();
      data['debts'] = [
        {'id': 'b', 'name': 'Shopee hulog', 'type': 'bnpl', 'remaining': 4000, 'monthlyRate': 0},
      ];
      data['goals'] = [];
      final r = splitWindfall(data, ref, amount: 100000);
      final slices = (r['slices'] as List).cast<Map<String, dynamic>>();
      final bnpl = slices.firstWhere((s) => s['key'] == 'bnpl');
      expect(bnpl['label'], 'Clear Shopee hulog');
      expect(bnpl['amount'], 4000);
      expect(r['rateUnfilled'], false);
    });

    test('a rate-less card or loan IS flagged, since it should have interest',
        () {
      final data = baseData();
      data['debts'] = [
        {'id': 'c', 'name': 'Card', 'type': 'credit card', 'remaining': 8000, 'monthlyRate': 0},
      ];
      data['goals'] = [];
      final r = splitWindfall(data, ref, amount: 100000);
      expect(r['rateUnfilled'], true);
      expect((r['slices'] as List).any((s) => s['key'] == 'bnpl'), false);
    });

    test('the 0.5%/mo SSS loan is below the line and never allocated', () {
      final r = splitWindfall(baseData(), ref, amount: 200000);
      final labels =
          (r['slices'] as List).map((s) => s['label'] as String).toList();
      expect(labels.any((l) => l.contains('SSS')), false);
    });
  });

  group('honest degradation and guards', () {
    test('with no spending history, a 10k floor cushion is used and flagged', () {
      final data = baseData();
      data['accounts'] = [
        {'id': 'a1', 'kind': 'cash', 'balance': 2000},
      ];
      data['transactions'] = []; // no completed expense months
      data['debts'] = [];
      data['goals'] = [];
      final r = splitWindfall(data, ref, amount: 5000);
      expect(r['usedFloor'], true);
      expect(r['hasHistory'], false);
      final slices = (r['slices'] as List).cast<Map<String, dynamic>>();
      expect(slices.length, 1);
      expect(slices[0]['key'], 'starter');
      expect(slices[0]['amount'], 5000); // capped by the pool, gap was 8,000
      expect(slices[0]['detail'], contains('10,000'));
      // No fuller-fund tier without a known typical month.
      expect(slices.any((s) => s['key'] == 'fuller'), false);
    });

    test('a set-aside larger than the windfall is clamped, nothing to split', () {
      final r = splitWindfall(baseData(), ref, amount: 1000, setAside: 5000);
      expect(r['applicable'], true);
      expect(r['setAside'], 1000);
      expect((r['slices'] as List).isEmpty, true);
      expect(r['leftover'], 0);
    });

    test('zero and junk amounts are not applicable', () {
      expect(splitWindfall(baseData(), ref, amount: 0)['applicable'], false);
      expect(splitWindfall(baseData(), ref, amount: 'wala')['applicable'], false);
    });

    test('an all-goals-done, no-debt, funded user gets it all as leftover', () {
      final data = baseData();
      data['debts'] = [];
      data['goals'] = [];
      // Cushion already past three months so no starter/fuller gap.
      data['accounts'] = [
        {'id': 'a1', 'kind': 'cash', 'balance': 500000},
      ];
      final r = splitWindfall(data, ref, amount: 10000);
      expect((r['slices'] as List).isEmpty, true);
      expect(r['leftover'], 10000);
    });
  });
}
