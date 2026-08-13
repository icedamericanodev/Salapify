// Phase 0 constitution follow-up, Block 1: a machine-enforced guard that the
// two independent "money kept this month" code paths can never silently
// disagree.
//
// The gap this closes (docs/reviews/phase0-constitution-audit.md, section D):
// Insights, coach, recap and Pan read analytics.savingsRate / monthlySeries,
// while Reports reads statements.incomeStatement (then reports_calc). Both
// classify a month's income and expenses with the SAME rule, copied into two
// golden-locked 1:1 RN ports:
//   income  = type == 'income' AND source != 'receivable'
//   expense = type == 'expense'
// over the ref month. Because the rule lives in two files, a future edit to
// one and not the other would make two screens show different savings rates
// on the same data. Nothing caught that before; this does.
//
// This test changes NO money code. It asserts an invariant across the existing
// engines, so it is behaviour-preserving by construction. It deliberately does
// NOT assert the ROUNDED percentage (Reports rounds with Dart's .round(),
// Insights rounds with the engine's JS-parity _jsRound); that difference at a
// negative half-boundary is a real but separate money-methodology decision
// flagged for the founder in the audit, not something this guard should freeze
// in place.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/analytics.dart' show savingsRate, monthlySeries;
import 'package:salapify/money/statements.dart' show incomeStatement;

void main() {
  final ref = DateTime(2026, 7, 15);

  // A helper that builds one transaction. Defaults make the common case terse.
  Map<String, dynamic> tx(
    String date,
    num amount, {
    String type = 'expense',
    String? source,
  }) => {'date': date, 'amount': amount, 'type': type, 'source': ?source};

  // Every scenario is a named data blob plus what we expect the ONE shared
  // classification to produce for the ref month, so a broken rule fails with a
  // readable number, not just a mismatch.
  final scenarios = <String, Map<String, dynamic>>{
    'plain income and expense': {
      'data': {
        'transactions': [
          tx('2026-07-01', 20000, type: 'income'),
          tx('2026-07-03', 8000),
        ],
      },
      'income': 20000.0,
      'expenses': 8000.0,
    },
    'receivable-source income is NOT income (utang collected)': {
      'data': {
        'transactions': [
          tx('2026-07-01', 20000, type: 'income'),
          tx('2026-07-02', 5000, type: 'income', source: 'receivable'),
          tx('2026-07-03', 8000),
        ],
      },
      'income': 20000.0,
      'expenses': 8000.0,
    },
    'interest-source expense still counts as an expense': {
      'data': {
        'transactions': [
          tx('2026-07-01', 20000, type: 'income'),
          tx('2026-07-03', 8000),
          tx('2026-07-04', 500, source: 'interest'),
        ],
      },
      'income': 20000.0,
      'expenses': 8500.0,
    },
    'other months are excluded by both paths': {
      'data': {
        'transactions': [
          tx('2026-07-01', 20000, type: 'income'),
          tx('2026-06-30', 9999, type: 'income'), // prior month
          tx('2026-08-01', 7777), // next month
          tx('2026-07-03', 8000),
        ],
      },
      'income': 20000.0,
      'expenses': 8000.0,
    },
    'junk and dateless rows never move a total': {
      'data': {
        'transactions': [
          tx('2026-07-01', 20000, type: 'income'),
          tx('2026-07-03', 8000),
          {'amount': 1234, 'type': 'income'}, // no date
          {'date': '2026-07-05', 'type': 'expense'}, // no amount
          null,
          42,
          'not a row',
        ],
      },
      'income': 20000.0,
      'expenses': 8000.0,
    },
    'no income this month: rate is null, statement income is zero': {
      'data': {
        'transactions': [tx('2026-07-03', 8000)],
      },
      'income': 0.0,
      'expenses': 8000.0,
    },
    'overspent month reads as a negative net on both paths': {
      'data': {
        'transactions': [
          tx('2026-07-01', 5000, type: 'income'),
          tx('2026-07-03', 8000),
        ],
      },
      'income': 5000.0,
      'expenses': 8000.0,
    },
  };

  group('savings-rate paths agree (analytics vs statements)', () {
    scenarios.forEach((name, s) {
      final data = s['data'] as Map<String, dynamic>;
      final expectIncome = s['income'] as double;
      final expectExpenses = s['expenses'] as double;
      final txs = data['transactions'];

      test(name, () {
        final stmt = incomeStatement(data, ref);
        final series = monthlySeries(txs, 1, ref); // last = ref month
        final month = series.last;

        // 1. The statement path and the analytics monthlySeries path must
        //    agree, to the centavo, on income and expenses. This is the core
        //    guard: it catches a divergence in the classification rule OR in
        //    the month filter, in either file.
        expect(
          stmt['income'],
          month['income'],
          reason: 'income disagrees between statements and analytics',
        );
        expect(
          stmt['expenses'],
          month['expenses'],
          reason: 'expenses disagree between statements and analytics',
        );

        // 2. Did anything happen? Pin the actual figures so the guard cannot
        //    pass by both paths quietly computing nothing.
        expect(stmt['income'], expectIncome);
        expect(stmt['expenses'], expectExpenses);

        // 3. The savings rate the Insights side shows must equal the fraction
        //    the Reports side would divide out of the same statement, or both
        //    must agree there is no rate (no income to divide by).
        final rate = savingsRate(txs, const [], ref);
        final income = stmt['income'] as double;
        final net = stmt['netIncome'] as double;
        if (income > 0) {
          expect(
            rate,
            net / income,
            reason: 'savingsRate fraction disagrees with netIncome / income',
          );
        } else {
          expect(rate, isNull, reason: 'no income should yield a null rate');
        }
      });
    });
  });
}
