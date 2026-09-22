// The breakdown behind the donut must reconcile with netWorthParts, or the
// donut screen would show a Total that disagrees with the hero. Every literal
// below is a balance we put in; the ASSERTIONS compare the slice sums to
// netWorthParts, the golden-locked source, never to a number this file
// computes on its own.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/account_taxonomy.dart' show AccountClass;
import 'package:salapify/money/accounts_breakdown.dart';
import 'package:salapify/money/fx_totals.dart' show FxTable;
import 'package:salapify/money/statements.dart' show netWorthParts;

void main() {
  // A lived-in book: base-currency cash and savings, an investment holding, a
  // credit card and a loan, one person who owes the user (receivable) and one
  // the user owes (payable), plus a foreign account to exercise conversion.
  final data = {
    'accounts': [
      {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 2000},
      {
        'id': 'b', 'name': 'BPI', 'kind': 'savings', 'balance': 48000,
        'subtype': 'savings_account',
      },
      {
        'id': 'usd', 'name': 'US bank', 'kind': 'savings', 'balance': 100,
        'subtype': 'savings_account', 'currencyCode': 'USD',
      },
    ],
    'assets': [
      {'id': 's', 'name': 'Stocks', 'kind': 'stocks', 'value': 30000},
    ],
    'debts': [
      {'id': 'cc', 'name': 'Card', 'type': 'credit card', 'remaining': 5000},
      {'id': 'ln', 'name': 'Loan', 'type': 'personal loan', 'remaining': 20000},
    ],
    // cashLeg marks a tracked money debt (not a favor), which is what
    // trackedRemaining counts; remaining is amount minus any payments.
    'receivables': [
      {'id': 'r1', 'name': 'Migs', 'amount': 1500, 'cashLeg': true},
    ],
    'payables': [
      {'id': 'p1', 'name': 'Store', 'amount': 800, 'cashLeg': true},
    ],
    'settings': {'baseCurrency': 'PHP'},
  };
  // A manual rate so the foreign account is priced (manual is base-per-unit,
  // so 56 PHP per 1 USD), exercising the converted path.
  final fx = FxTable(base: 'PHP', manual: const {'USD': 56.0}, nowMs: 0);

  test('asset slices sum to netWorthParts assets, to the centavo', () {
    final parts = netWorthParts(data, fx: fx);
    final slices = assetLiabilityBreakdown(data, fx: fx);
    final assetSum = slices
        .where((s) => s.cls == AccountClass.asset)
        .fold(0.0, (t, s) => t + s.total);
    expect(assetSum, closeTo(parts['assets'] as double, 0.005));
  });

  test('liability slices sum to netWorthParts liabilities, to the centavo', () {
    final parts = netWorthParts(data, fx: fx);
    final slices = assetLiabilityBreakdown(data, fx: fx);
    final liaSum = slices
        .where((s) => s.cls == AccountClass.liability)
        .fold(0.0, (t, s) => t + s.total);
    expect(liaSum, closeTo(parts['liabilities'] as double, 0.005));
  });

  test('receivables and payables come through as their own slices', () {
    final slices = assetLiabilityBreakdown(data, fx: fx);
    final recv = slices.firstWhere((s) => s.id == 'receivables');
    final pay = slices.firstWhere((s) => s.id == 'payables');
    expect(recv.total, closeTo(1500, 0.005));
    expect(recv.cls, AccountClass.asset);
    expect(pay.total, closeTo(800, 0.005));
    expect(pay.cls, AccountClass.liability);
  });

  test('the foreign account is counted at its converted value', () {
    // 100 USD at 56 is 5600 PHP, which must land inside the cash_equivalents
    // asset slice, not be dropped and not be added raw as 100.
    final slices = assetLiabilityBreakdown(data, fx: fx);
    final cash = slices.firstWhere((s) => s.id == 'cash_equivalents');
    // 2000 + 48000 + 5600
    expect(cash.total, closeTo(55600, 0.005));
    expect(cash.count, 3);
  });

  test('an unpriceable foreign row counts as zero, matching the total', () {
    // No fx table: the USD account cannot be priced, so it is excluded from
    // both the slice and netWorthParts, and the two still agree.
    final parts = netWorthParts(data);
    final slices = assetLiabilityBreakdown(data);
    final assetSum = slices
        .where((s) => s.cls == AccountClass.asset)
        .fold(0.0, (t, s) => t + s.total);
    expect(assetSum, closeTo(parts['assets'] as double, 0.005));
    final cash = slices.firstWhere((s) => s.id == 'cash_equivalents');
    expect(cash.total, closeTo(50000, 0.005)); // 2000 + 48000, USD dropped
  });

  test('empty categories never produce a slice', () {
    final slices = assetLiabilityBreakdown({
      'accounts': [
        {'id': 'c', 'name': 'Cash', 'kind': 'cash', 'balance': 500},
      ],
      'settings': {'baseCurrency': 'PHP'},
    });
    expect(slices.map((s) => s.id), ['cash_equivalents']);
  });
}
