// Golden vectors for safeToSpendBuffer, the f4.62 Safe-to-Spend buffer.
//
// Founder rule (2026-08-22), chosen from a menu: "minimum due only,
// conservative-safe". The buffer is the liquid pesos you can reach now, minus
// every payment landing in the next 14 days, where a credit card counts ONLY
// for its minimum payment (a bill, not a payoff). These vectors are computed by
// hand from a fixture whose due dates all fall on plain banking days, so the
// arithmetic is checkable without trusting the very function under test.
//
// The reference day is 2026-07-16 (a Thursday). The due days used, 17, 24 and
// 28, are all weekdays in July 2026 with no PH holiday, so upcomingDues does
// not bank-adjust any of them: the adjusted date equals the raw date, and the
// hand figures below are exact. A "did anything happen" companion sits beside
// the conservation checks, because a buffer that silently counts nothing also
// "protects savings" perfectly.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/commitments.dart';

void main() {
  final ref = DateTime(2026, 7, 16, 12);

  // Liquid: cash 5000 + ewallet 3000 + checking 30000 = 38000. Savings and a
  // USD checking account are present but MUST NOT count.
  List<Map<String, dynamic>> accounts() => [
    {'id': 'c', 'kind': 'cash', 'balance': 5000},
    {'id': 'w', 'kind': 'ewallet', 'balance': 3000},
    {'id': 'k', 'kind': 'checking', 'balance': 30000},
    {'id': 's', 'kind': 'savings', 'balance': 50000}, // protected, excluded
    {
      'id': 'usd',
      'kind': 'checking',
      'balance': 1000,
      'currencyCode': 'USD', // foreign, excluded
    },
  ];

  // Three debts due inside the window and one outside it.
  List<Map<String, dynamic>> debts() => [
    // Due 07-17 (in 1 day). Minimum 1500 < remaining, so 1500 counts.
    {'id': 'A', 'remaining': 20000, 'minPayment': 1500, 'dueDay': 17},
    // Due 07-24 (in 8 days). Minimum 800 counts.
    {'id': 'B', 'remaining': 8000, 'minPayment': 800, 'dueDay': 24},
    // Due 07-28 (in 12 days). Minimum 6000 > remaining 5000, so 5000 counts:
    // never charge a person more than the debt is worth.
    {'id': 'C', 'remaining': 5000, 'minPayment': 6000, 'dueDay': 28},
    // Due day 15: next occurrence is 08-15, 30 days out, OUTSIDE the window.
    {'id': 'D', 'remaining': 10000, 'minPayment': 500, 'dueDay': 15},
    // Paid off: remaining 0, never a due.
    {'id': 'E', 'remaining': 0, 'minPayment': 900, 'dueDay': 20},
  ];

  // Recurring: rent lands in the window, Netflix is already posted, the day-31
  // bill lands 07-31 which is one day past the 14-day horizon.
  List<Map<String, dynamic>> recurring() => [
    {'id': 'rent', 'type': 'expense', 'amount': 12000, 'dayOfMonth': 25},
    {
      'id': 'nf',
      'type': 'expense',
      'amount': 500,
      'dayOfMonth': 10,
      'lastPosted': '2026-07', // posted this month, excluded
    },
    {'id': 'late', 'type': 'expense', 'amount': 300, 'dayOfMonth': 31},
    {'id': 'pay', 'type': 'income', 'amount': 40000, 'dayOfMonth': 15},
  ];

  Map<String, dynamic> blob() => {
    'accounts': accounts(),
    'debts': debts(),
    'recurring': recurring(),
    'settings': <String, dynamic>{},
  };

  test('the buffer matches the hand-computed vector to the centavo', () {
    final b = safeToSpendBuffer(blob(), ref);
    // Liquid = 5000 + 3000 + 30000 (savings and USD excluded).
    expect(b['liquid'], 38000.0);
    // Card/loan minimums in window = 1500 + 800 + 5000.
    expect(b['cardDue'], 7300.0);
    // Recurring bills in window = rent 12000 only.
    expect(b['billsDue'], 12000.0);
    expect(b['committed'], 19300.0);
    // Buffer = 38000 - 19300.
    expect(b['buffer'], 18700.0);
    // Three debt dues + one recurring bill.
    expect(b['dueCount'], 4);
    // Every debt in the fixture has a real minimum, so none are flagged.
    expect(b['minsUnset'], 0);
    expect(b['windowDays'], 14);
  });

  test('a debt with no minimum set is flagged, not reserved at full balance', () {
    // Bank-officer finding (2026-08-22): upcomingDues falls back to the whole
    // remaining balance when minPayment is unset, which would drop a mortgage
    // into a fortnight buffer. The buffer must exclude it and flag it instead.
    final blobNoMin = {
      'accounts': [
        {'id': 'c', 'kind': 'cash', 'balance': 10000},
      ],
      'debts': [
        // A 300k loan due in 4 days with NO minimum saved. If it leaked in at
        // full balance the buffer would read about minus 290000.
        {'id': 'M', 'remaining': 300000, 'dueDay': 20},
      ],
      'recurring': <Map<String, dynamic>>[],
      'settings': <String, dynamic>{},
    };
    final b = safeToSpendBuffer(blobNoMin, ref);
    expect(b['cardDue'], 0.0, reason: 'a blank minimum must not be reserved');
    expect(b['buffer'], 10000.0, reason: 'the buffer is just the liquid cash');
    expect(b['dueCount'], 0);
    expect(b['minsUnset'], 1);
  });

  test('savings is protected: dropping it changes nothing', () {
    final withSavings = safeToSpendBuffer(blob(), ref);
    final noSavings = {
      ...blob(),
      'accounts': accounts().where((a) => a['kind'] != 'savings').toList(),
    };
    final without = safeToSpendBuffer(noSavings, ref);
    expect(without['liquid'], withSavings['liquid']);
    expect(without['buffer'], withSavings['buffer']);
    // Directional companion: the savings balance is real and large, so a
    // computation that DID count it would move liquid by exactly 50000. This
    // asserts the gap, not just equality, so a future change that starts
    // counting savings reddens here instead of passing quietly.
    expect(withSavings['liquid'], lessThan(50000.0));
  });

  test('a foreign balance is not counted as pesos', () {
    final b = safeToSpendBuffer(blob(), ref);
    // The USD checking account holds 1000 units. If it leaked in as pesos the
    // liquid figure would be 39000, not 38000.
    expect(b['liquid'], 38000.0);
  });

  test('the window cutoff excludes dues past 14 days', () {
    // Debt D (08-15) and the day-31 bill (07-31) are both outside the window.
    // Move the reference back so BOTH fall inside a wider window and confirm
    // they then count: this proves the cutoff is a real boundary, not a
    // permanent exclusion.
    final wide = safeToSpendBuffer(blob(), ref, windowDays: 40);
    // Now debt D's 08-15 due (in 30 days) adds its 500 minimum, and the day-31
    // bill (07-31, in 15 days) adds 300.
    expect(wide['cardDue'], 7300.0 + 500.0);
    expect(wide['billsDue'], 12000.0 + 300.0);
    expect(wide['dueCount'], 6);
  });

  test('a negative buffer is reported, not floored to zero', () {
    // Overcommitted: only 2000 liquid against the same 19300 of dues.
    final broke = {
      ...blob(),
      'accounts': [
        {'id': 'c', 'kind': 'cash', 'balance': 2000},
      ],
    };
    final b = safeToSpendBuffer(broke, ref);
    expect(b['liquid'], 2000.0);
    expect(b['committed'], 19300.0);
    expect(b['buffer'], 2000.0 - 19300.0);
    expect(b['buffer'] as double, lessThan(0));
  });

  test('with no dues at all, the buffer is exactly the liquid', () {
    final calm = {
      'accounts': accounts(),
      'debts': <Map<String, dynamic>>[],
      'recurring': <Map<String, dynamic>>[],
      'settings': <String, dynamic>{},
    };
    final b = safeToSpendBuffer(calm, ref);
    expect(b['committed'], 0.0);
    expect(b['buffer'], b['liquid']);
    expect(b['buffer'], 38000.0);
    expect(b['dueCount'], 0);
  });

  test('an empty blob is all zeros, never a crash', () {
    final b = safeToSpendBuffer({
      'accounts': <dynamic>[],
      'debts': <dynamic>[],
      'recurring': <dynamic>[],
      'settings': <String, dynamic>{},
    }, ref);
    expect(b['liquid'], 0.0);
    expect(b['committed'], 0.0);
    expect(b['buffer'], 0.0);
    expect(b['dueCount'], 0);
  });
}
