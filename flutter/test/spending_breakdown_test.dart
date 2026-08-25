// Net-new math (no RN counterpart), so these are unit tests, not a golden
// replay. The load-bearing one is the INVARIANT: committed + everyday must
// equal the golden-locked budgetSummary's spent for the same month, because
// the split only re-buckets the exact same expense universe the budget counts.
// If that ever drifts, the split is lying about the budget.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/budget.dart' show budgetSummary;
import 'package:salapify/money/spending_breakdown.dart';

void main() {
  final ref = DateTime(2026, 8, 20);

  Map<String, dynamic> fixture() => {
    'settings': {'monthlyLimit': 20000},
    'transactions': [
      // Committed: a posted recurring bill, a debt payment, and card interest.
      {'id': 't1', 'type': 'expense', 'amount': 5000, 'date': '2026-08-02', 'recurringId': 'r1'},
      {'id': 't2', 'type': 'expense', 'amount': 2000, 'date': '2026-08-10', 'debtId': 'd1'},
      {'id': 't3', 'type': 'expense', 'amount': 300, 'date': '2026-08-11', 'source': 'interest'},
      // Everyday: plain logged spending, no committing tag.
      {'id': 't4', 'type': 'expense', 'amount': 1200, 'date': '2026-08-12', 'label': 'Groceries'},
      {'id': 't5', 'type': 'expense', 'amount': 800, 'date': '2026-08-18', 'label': 'Coffee'},
      // Ignored: income, a transfer, and a last-month expense.
      {'id': 't6', 'type': 'income', 'amount': 40000, 'date': '2026-08-05'},
      {'id': 't7', 'type': 'transfer', 'amount': 3000, 'date': '2026-08-06', 'flow': 'out'},
      {'id': 't8', 'type': 'expense', 'amount': 999, 'date': '2026-07-30', 'label': 'Last month'},
    ],
    'recurring': [
      {'id': 'r1', 'type': 'expense', 'amount': 1500, 'dayOfMonth': 2, 'label': 'Rent'},
      {'id': 'r2', 'type': 'expense', 'amount': 2500, 'dayOfMonth': 15, 'label': 'Meralco'},
      {'id': 'r3', 'type': 'income', 'amount': 40000, 'dayOfMonth': 15, 'label': 'Salary'},
    ],
  };

  test('spendingSplit buckets committed vs everyday', () {
    final s = spendingSplit(fixture(), ref);
    expect(s['committed'], 7300.0); // 5000 + 2000 + 300
    expect(s['everyday'], 2000.0); // 1200 + 800
    expect(s['total'], 9300.0);
    expect(s['committedPct'] as double, closeTo(78.4946, 0.001));
  });

  test('INVARIANT: committed + everyday equals budgetSummary spent', () {
    final data = fixture();
    final s = spendingSplit(data, ref);
    final b = budgetSummary(data, ref);
    expect(
      (s['committed'] as double) + (s['everyday'] as double),
      b['spent'],
      reason: 'the split must re-bucket exactly the budget expense universe',
    );
  });

  test('an empty book splits to zero, not a divide-by-zero', () {
    final s = spendingSplit({'transactions': const []}, ref);
    expect(s['committed'], 0.0);
    expect(s['everyday'], 0.0);
    expect(s['total'], 0.0);
    expect(s['committedPct'], 0.0);
  });

  test('a summation overflow does not crash committedPct', () {
    // amountOf floors a lone Infinity to 0, so the real non-finite vector is a
    // SUM of two near-max finite doubles overflowing to Infinity (a junk backup
    // could carry these). committedPct must fall back to a real 0, not a NaN
    // from Infinity / Infinity that the screen's later round() would throw on.
    const huge = 1.7976931348623157e308; // finite, close to the max double
    final s = spendingSplit({
      'transactions': [
        {'id': 'x', 'type': 'expense', 'amount': huge, 'date': '2026-08-01', 'recurringId': 'r'},
        {'id': 'y', 'type': 'expense', 'amount': huge, 'date': '2026-08-02', 'recurringId': 'r'},
      ],
    }, ref);
    expect((s['committed'] as double).isInfinite, isTrue);
    expect((s['committedPct'] as double).isFinite, isTrue);
    expect(s['committedPct'], 0.0);

    // The mirror case: the overflow lands on the everyday side.
    final m = spendingSplit({
      'transactions': [
        {'id': 'x', 'type': 'expense', 'amount': huge, 'date': '2026-08-01', 'label': 'Junk'},
        {'id': 'y', 'type': 'expense', 'amount': huge, 'date': '2026-08-02', 'label': 'More'},
      ],
    }, ref);
    expect((m['everyday'] as double).isInfinite, isTrue);
    expect((m['committedPct'] as double).isFinite, isTrue);
    expect(m['committedPct'], 0.0);
  });

  test('recurringBillsMonthly sums expense recurring only', () {
    expect(recurringBillsMonthly(fixture()), 4000.0); // 1500 + 2500, salary out
    expect(recurringBillsCount(fixture()), 2);
  });

  test('billsForPeriod projects a monthly figure onto week and year', () {
    expect(billsForPeriod(4000, BillPeriod.monthly), 4000.0);
    expect(billsForPeriod(4000, BillPeriod.annual), 48000.0);
    expect(billsForPeriod(4000, BillPeriod.weekly), closeTo(923.0769, 0.001));
  });
}
