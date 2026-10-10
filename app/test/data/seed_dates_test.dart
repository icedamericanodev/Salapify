import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/test_clock.dart';

/// The sample ledger dates itself from TODAY, and this proves it.
///
/// ## What changed, and why
///
/// Every date in `seed_data.dart` used to be a fixed calendar string written
/// against 18 September 2026, while the `createdAt` timestamp beside it was
/// anchored to `DateTime.now()`. The two fields described different days about
/// the same transaction, and on 1 October a brand new install showed a Log
/// full of entries from "yesterday" sitting above a Budgets screen reporting
/// that nothing at all had been spent this month. Both were reading the sample
/// data correctly.
///
/// ## The property that made the change safe
///
/// Those fixed strings were ALWAYS the anchor minus the offset already written
/// beside them: `'2026-09-17'` sat with `_daysAgo(1)`, `'2026-09-01'` with
/// `_daysAgo(17)`, with no exceptions. So replacing each string with its own
/// offset leaves the ledger unchanged when the clock is at the anchor, which
/// is why hundreds of expected figures across this suite did not move.
///
/// That is a claim, and a claim about a hundred dates is exactly the sort that
/// is true in the places somebody checked. The fixture below was captured from
/// the OLD code before any of it was touched, so this is a comparison rather
/// than a restatement.
void main() {
  Map<String, dynamic> datesOf(FinancialState s) => <String, dynamic>{
    'transactions': <Map<String, String>>[
      for (final Transaction t in s.transactions)
        <String, String>{'id': t.id, 'date': t.date},
    ],
    'bills': <Map<String, String>>[
      for (final BillItem b in s.bills)
        <String, String>{'id': b.id, 'dueDate': b.dueDate},
    ],
    'debts': <Map<String, String?>>[
      for (final Debt d in s.debts)
        <String, String?>{
          'id': d.id,
          'dueDate': d.dueDate,
          'settled': d.settledDate,
        },
    ],
    'accounts': <Map<String, String?>>[
      for (final Account a in s.accounts)
        <String, String?>{'id': a.id, 'dueDate': a.dueDate},
    ],
    'installments': <Map<String, String>>[
      for (final InstallmentPlan i in s.installments)
        <String, String>{'id': i.id, 'start': i.startDate},
    ],
  };

  test('at the anchor, every money date is what the fixed strings gave', () {
    final Map<String, dynamic> fixture =
        jsonDecode(File('test/data/seed_dates_anchor.json').readAsStringSync())
            as Map<String, dynamic>;

    final Map<String, dynamic> now = datesOf(FinancialState(clock: testToday));

    // Everything except the Coming Up labels, which changed deliberately and
    // are asserted separately below.
    for (final String key in <String>[
      'transactions',
      'bills',
      'debts',
      'accounts',
      'installments',
    ]) {
      expect(
        jsonEncode(now[key]),
        jsonEncode(fixture[key]),
        reason:
            'the $key dates moved at the anchor, which means the offsets '
            'do not reproduce the strings they replaced',
      );
    }
  });

  test('the Coming Up labels changed, on purpose, and are now derived', () {
    // The ONE place the old strings were not reproduced, because two of them
    // were wrong. 'Sep 18' was the label on a bill due the very day it was
    // shown, where a person says "Today". 'Monday, Sep 15' named a weekday
    // that 15 September 2026 is not; it was a Tuesday. A weekday worked out
    // from the date cannot be wrong.
    final FinancialState s = FinancialState(clock: testToday);
    final Map<String, String> byId = <String, String>{
      for (final UpcomingItem u in s.upcoming) u.id: u.dueDate,
    };

    expect(byId['up_meralco'], 'Today');
    expect(byId['up_homecredit'], 'Today');
    expect(byId['up_spotify'], 'Sunday');
    // '15', not a date offset, since the founder decision of 2026-10-04.
    // Dated three days in the past it sat in the overdue-income bucket, which
    // the projection excludes from the grid, so the "counted once" notice
    // could never fire on the sample ledger at any clock. A day of the month
    // is readable by `daysUntil`, matches the stored payday rule exactly, and
    // is what a person actually types. An offset of two to six would have
    // produced a WEEKDAY NAME, which `daysUntil` cannot read, so the obvious
    // fix would have moved the item from one invisible bucket to another.
    expect(byId['up_payday'], '15');
    expect(
      byId.values,
      isNot(contains('Monday, Sep 15')),
      reason: 'the wrong weekday came back',
    );
  });

  group('and it genuinely moves with the clock', () {
    test('a new install in March is dated March, not September', () {
      // The half that would be missed by only checking the anchor: the
      // anchor test passes perfectly if the dates are still hardcoded.
      final FinancialState s = FinancialState(clock: DateTime(2027, 3, 20));

      expect(
        s.transactions.map((Transaction t) => t.date),
        everyElement(startsWith('2027-03')),
        reason: 'the ledger is still dated September',
      );
      expect(
        s.transactions.map((Transaction t) => t.date),
        contains('2027-03-20'),
        reason: 'nothing happened today',
      );
    });

    test('money really is counted as spent THIS month', () {
      // The defect in one assertion. This is what read zero on 1 October.
      final FinancialState s = FinancialState(clock: DateTime(2027, 3, 20));
      expect(
        s.panFacts.monthOut,
        greaterThan(0),
        reason: 'a brand new install reports nothing spent this month',
      );
      expect(s.panFacts.monthIn, greaterThan(0));
    });

    test('a due date in the future stays in the future', () {
      // Offsets carry a sign, and getting one backwards would turn every
      // upcoming bill into an overdue one on a screen full of red.
      final FinancialState s = FinancialState(clock: DateTime(2027, 3, 20));
      final BillItem rent = s.bills.firstWhere(
        (BillItem b) => b.id == 'bill_rent',
      );
      expect(
        DateTime.parse(rent.dueDate).isAfter(DateTime(2027, 3, 20)),
        isTrue,
      );
    });

    test('an instalment that started months ago still did', () {
      final FinancialState s = FinancialState(clock: DateTime(2027, 3, 20));
      for (final InstallmentPlan p in s.installments) {
        expect(
          DateTime.parse(p.startDate).isBefore(DateTime(2027, 3, 20)),
          isTrue,
          reason: '${p.id} starts in the future',
        );
      }
    });
  });
}
