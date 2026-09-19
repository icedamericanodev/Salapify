// Golden vectors for consolidatedDebtStatement, the f4.66 consolidated debt
// statement. The totals are hand-summed from the fixture; the composed figures
// (monthly interest, utilization, payoff) are asserted to equal the golden-
// locked engines they come from, so the statement can never disagree with the
// Debts screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/credit_utilization.dart';
import 'package:salapify/money/debt_statement.dart';
import 'package:salapify/money/debtmath.dart'
    show debtFreeProjection, monthlyInterest;

void main() {
  final ref = DateTime(2026, 8, 20, 12);

  // Four debts whose balances sum to 139,950 and minimums to 10,442.50, the
  // same shape as a real multi-card book.
  Map<String, dynamic> blob() => {
    'debts': [
      {
        'id': 'a',
        'name': 'UnionBank Platinum',
        'type': 'credit card',
        'remaining': 38450,
        'minPayment': 1922.50,
        'monthlyRate': 3.0,
        'creditLimit': 60000,
        'dueDay': 8,
      },
      {
        'id': 'b',
        'name': 'BDO Titanium',
        'type': 'credit card',
        'remaining': 64200,
        'minPayment': 3210,
        'monthlyRate': 3.0,
        'creditLimit': 120000,
        'dueDay': 25,
      },
      {
        'id': 'c',
        'name': 'Shopee PayLater',
        'type': 'bnpl',
        'remaining': 12800,
        'minPayment': 2560,
        'monthlyRate': 3.5,
        'dueDay': 15,
      },
      {
        'id': 'd',
        'name': 'Home Credit Loan',
        'type': 'personal loan',
        'remaining': 24500,
        'minPayment': 2750,
        'monthlyRate': 2.375, // 28.5% p.a.
        'dueDay': 28,
      },
    ],
  };

  test('the totals are the hand-summed vector', () {
    final s = consolidatedDebtStatement(blob(), ref)!;
    expect(s['totalDebt'], 38450 + 64200 + 12800 + 24500); // 139950
    expect(s['totalMinDue'], 1922.50 + 3210 + 2560 + 2750); // 10442.50
    expect(s['debtCount'], 4);
    // Average nominal APR: (36 + 36 + 42 + 28.5) / 4 = 35.625.
    expect(s['avgApr'] as double, closeTo(35.625, 1e-9));
  });

  test('the composed figures equal the golden-locked engines', () {
    final b = blob();
    final s = consolidatedDebtStatement(b, ref)!;
    // Estimated monthly interest is exactly the sum of monthlyInterest.
    final expectedInterest = (b['debts'] as List)
        .cast<Map<String, dynamic>>()
        .fold(0.0, (t, d) => t + monthlyInterest(d));
    expect(s['estMonthlyInterest'] as double, closeTo(expectedInterest, 1e-9));
    // Overall utilization is exactly creditUtilization's overall ratio.
    final radar = creditUtilization(b['debts'])!;
    expect(s['utilization'], radar['overall']);
    // The payoff line is the golden-locked projection at extra 0.
    expect(
      s['payoff'],
      debtFreeProjection(
        (b['debts'] as List).cast<Map<String, dynamic>>(),
        'avalanche',
        0,
        ref,
      ),
    );
  });

  test('rows are worst balance first, each read straight from the blob', () {
    final s = consolidatedDebtStatement(blob(), ref)!;
    final rows = s['rows'] as List<DebtStatementRow>;
    expect(rows.map((r) => r.name).toList(), [
      'BDO Titanium', // 64200
      'UnionBank Platinum', // 38450
      'Home Credit Loan', // 24500
      'Shopee PayLater', // 12800
    ]);
    // A card's nominal APR is monthlyRate x 12.
    expect(rows.first.aprAnnual, closeTo(36.0, 1e-9));
    // The personal loan carries its own 28.5% and a real due date.
    final loan = rows.firstWhere((r) => r.name == 'Home Credit Loan');
    expect(loan.aprAnnual, closeTo(28.5, 1e-9));
    expect(loan.dueISO, isNotNull);
  });

  test('nominal and compounded rates: a 3%/month card reads 36% and ~42.6%', () {
    final s = consolidatedDebtStatement(blob(), ref)!;
    final card = (s['rows'] as List<DebtStatementRow>)
        .firstWhere((r) => r.name == 'BDO Titanium');
    expect(card.aprAnnual, closeTo(36.0, 1e-9));
    // (1.03)^12 - 1 = 0.42576...
    expect(card.aprEffective, closeTo(42.576, 1e-2));
  });

  test('a card-number debt name is masked to its last four', () {
    // The stored name is left alone; only the display is masked.
    expect(maskDebtName('BDO Titanium'), 'BDO Titanium');
    expect(maskDebtName('1234 5678 9012 4291'), contains('4291'));
    expect(maskDebtName('1234 5678 9012 4291'), isNot(contains('1234')));
    expect(maskDebtName('4291'), '4291'); // too short to be a PAN, left alone
  });

  test('minsUnset counts debts with no minimum saved', () {
    final b = {
      'debts': [
        {'id': 'a', 'type': 'credit card', 'remaining': 5000, 'minPayment': 500},
        {'id': 'b', 'type': 'mortgage', 'remaining': 900000}, // no minimum
        {'id': 'c', 'type': 'auto', 'remaining': 40000}, // no minimum
      ],
    };
    final s = consolidatedDebtStatement(b, ref)!;
    expect(s['minsUnset'], 2);
    expect(s['totalMinDue'], 500.0);
  });

  test('a debt with no minimum is a dash, never a fake zero', () {
    final b = {
      'debts': [
        {
          'id': 'x',
          'name': 'Mortgage',
          'type': 'mortgage',
          'remaining': 2000000,
          'monthlyRate': 0.5,
          'dueDay': 5,
        },
      ],
    };
    final s = consolidatedDebtStatement(b, ref)!;
    final row = (s['rows'] as List<DebtStatementRow>).single;
    expect(row.minDue, isNull);
    expect(s['totalMinDue'], 0.0);
  });

  test('a paid-off book has no statement', () {
    expect(
      consolidatedDebtStatement({
        'debts': [
          {'id': 'p', 'type': 'credit card', 'remaining': 0},
        ],
      }, ref),
      isNull,
    );
    expect(consolidatedDebtStatement({'debts': <dynamic>[]}, ref), isNull);
    expect(consolidatedDebtStatement({}, ref), isNull);
  });

  test('the minimum is capped at what is owed, never more', () {
    final b = {
      'debts': [
        {
          'id': 'y',
          'name': 'Almost paid card',
          'type': 'credit card',
          'remaining': 300,
          'minPayment': 500, // more than owed
          'monthlyRate': 3.0,
          'dueDay': 10,
        },
      ],
    };
    final s = consolidatedDebtStatement(b, ref)!;
    expect((s['rows'] as List<DebtStatementRow>).single.minDue, 300.0);
    expect(s['totalMinDue'], 300.0);
  });
}
