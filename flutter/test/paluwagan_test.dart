// Unit suite for money/paluwagan.dart: the rotating savings (paluwagan) engine.
// Net-new math with no RN counterpart, so it is covered by these Dart tests
// instead of a golden replay. The invariants that must never break: a full
// round is zero sum, the payout lands on your turn's date, "behind" means a due
// contribution is unpaid, the timing read (early loan vs late savings) is
// stable, the contribution feeds safe-to-spend while the round runs and is
// capped at what you still owe, and junk never throws.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/paluwagan.dart';

void main() {
  final ref = DateTime(2026, 7, 15); // 15 July 2026.

  // A clean monthly paluwagan: 5 members, PHP 1000 each, started 10 May 2026,
  // you are turn 3, you have paid 2 of the cycles due so far.
  const monthly = {
    'id': 'p1',
    'name': 'Office paluwagan',
    'amount': 1000,
    'members': 5,
    'cadence': 'monthly',
    'startDate': '2026-05-10',
    'myTurn': 3,
    'paidCycles': 2,
  };

  group('newPaluwagan normalizes a raw form to safe defaults', () {
    final p = newPaluwagan({'name': '  ', 'amount': '2500'}, ref);
    test('defaults to 5 members', () => expect(p['members'], 5));
    test('defaults to a monthly cadence', () => expect(p['cadence'], 'monthly'));
    test('reads a string amount the JS way', () => expect(p['amount'], 2500));
    test('blank name falls back to Paluwagan', () => expect(p['name'], 'Paluwagan'));
    test('startDate defaults to the reference day',
        () => expect(p['startDate'], '2026-07-15'));
    test('your turn defaults to 1', () => expect(p['myTurn'], 1));

    test('members and turn are clamped to a sane range', () {
      final big = newPaluwagan({'members': 500, 'myTurn': 999}, ref);
      expect(big['members'], 60);
      expect(big['myTurn'], 60);
      final tiny = newPaluwagan({'members': 1}, ref);
      expect(tiny['members'], 2); // a paluwagan needs at least two people
    });
  });

  group('paluwaganStatus computes the decision figures', () {
    final s = paluwaganStatus(monthly, ref);

    test('payout is the full pot on your turn date', () {
      expect(s['payoutAmount'], 5000); // 1000 * 5
      expect(s['payoutDate'], '2026-07-10'); // cycle 3 from a 10 May start
    });
    test('three cycles have come due by 15 July',
        () => expect(s['currentCycle'], 3));
    test('your payout has landed by schedule', () {
      expect(s['received'], true);
      expect(s['cyclesToPayout'], 0);
    });
    test('behind flags an unpaid contribution that is already due', () {
      expect(s['behind'], true);
      expect(s['behindBy'], 1000);
    });
    test('net position reflects money held vs put in', () {
      expect(s['contributedSoFar'], 2000);
      expect(s['remainingContribution'], 3000);
      expect(s['netNow'], 3000); // received 5000, put in 2000
    });
    test('a full round is zero sum: total in equals payout',
        () => expect(s['totalContribution'], s['payoutAmount']));
    test('the round is not finished', () => expect(s['done'], false));
  });

  group('the timing read (dealType) is based on position, not pesos', () {
    String at(int turn) =>
        paluwaganStatus({...monthly, 'members': 6, 'myTurn': turn}, ref)['dealType']
            as String;
    test('an early turn reads as a loan', () => expect(at(1), 'early'));
    test('a middle turn reads as even', () => expect(at(3), 'middle'));
    test('a late turn reads as forced savings', () => expect(at(6), 'late'));
  });

  group('weekly and kinsenas schedules land on the right dates', () {
    test('weekly steps seven days per cycle', () {
      final s = paluwaganStatus({
        ...monthly,
        'cadence': 'weekly',
        'startDate': '2026-07-01',
        'members': 4,
        'myTurn': 2,
      }, ref);
      expect(s['payoutDate'], '2026-07-08'); // second weekly cycle
      expect(s['currentCycle'], 3); // 01, 08, 15 have come due by the 15th
    });
    test('kinsenas lands on the 15th and end of month', () {
      final s = paluwaganStatus({
        ...monthly,
        'cadence': 'kinsenas',
        'startDate': '2026-06-15',
        'members': 4,
        'myTurn': 3,
      }, ref);
      // cycles: 06-15, 06-30, 07-15, 07-31; turn 3 is 07-15.
      expect(s['payoutDate'], '2026-07-15');
      expect(s['currentCycle'], 3);
    });
  });

  group('the monthly commitment feeds safe-to-spend', () {
    test('a monthly cadence commits the amount',
        () => expect(paluwaganMonthlyCommitment(monthly, ref), 1000));
    test('weekly and kinsenas normalize to per-month', () {
      final base = {...monthly, 'members': 6, 'paidCycles': 0, 'startDate': '2026-07-01'};
      final wk = paluwaganMonthlyCommitment({...base, 'cadence': 'weekly', 'amount': 500}, ref);
      expect(wk, closeTo(500 * (52 / 12), 1e-6));
      final kn = paluwaganMonthlyCommitment({...base, 'cadence': 'kinsenas', 'amount': 500}, ref);
      expect(kn, 1000);
    });
    test('the reserve never exceeds what you still owe', () {
      // Run-rate 2166.67/mo but only 1500 left to pay in.
      final shortRound = {
        ...monthly, 'cadence': 'weekly', 'amount': 500, 'members': 5,
        'paidCycles': 2, 'startDate': '2026-07-01',
      };
      final s = paluwaganStatus(shortRound, ref);
      expect(s['remainingContribution'], 1500);
      expect(paluwaganMonthlyCommitment(shortRound, ref), 1500);
    });
    test('a fully-prepaid member reserves nothing, even mid-round', () {
      final prepaid = {...monthly, 'paidCycles': 5}; // all 5 paid, round not done
      final s = paluwaganStatus(prepaid, ref);
      expect(s['done'], false);
      expect(s['remainingContribution'], 0);
      expect(paluwaganMonthlyCommitment(prepaid, ref), 0);
    });
    test('a finished round commits nothing more', () {
      final doneRound = {
        ...monthly, 'members': 3, 'startDate': '2026-01-10', 'myTurn': 1, 'paidCycles': 3,
      };
      final s = paluwaganStatus(doneRound, ref);
      expect(s['done'], true);
      expect(paluwaganMonthlyCommitment(doneRound, ref), 0);
    });
    test('total commitment sums the active groups only', () {
      final doneRound = {
        ...monthly, 'members': 3, 'startDate': '2026-01-10', 'myTurn': 1, 'paidCycles': 3,
      };
      expect(paluwaganTotalCommitment([monthly, doneRound], ref), 1000);
    });
  });

  group('early-recipient net must be paired with the remaining owed', () {
    final early = {...monthly, 'myTurn': 1, 'paidCycles': 1};
    final s = paluwaganStatus(early, ref);
    test('received early, holding the pot', () {
      expect(s['received'], true);
      expect(s['netNow'] as double, greaterThan(0));
    });
    test('the remaining obligation is real and non-zero',
        () => expect(s['remainingContribution'] as double, greaterThan(0)));
  });

  group('a degenerate one-person group is refused', () {
    test('paluwaganStatus floors members at two',
        () => expect(paluwaganStatus({...monthly, 'members': 1}, ref)['members'], 2));
  });

  group('junk never throws', () {
    test('non-finite amount and bad date are safe', () {
      final s = paluwaganStatus({
        'amount': 'abc', 'members': 4, 'cadence': 'monthly',
        'startDate': '2026-02-30', 'myTurn': 2,
      }, ref);
      expect(s['amount'], 0);
      expect(s['payoutAmount'], 0);
      expect(s['dealType'], isA<String>());
    });
    test('a junk list totals to zero, not a crash', () {
      expect(paluwaganTotalCommitment(null, ref), 0);
      expect(paluwaganTotalCommitment([null, 42, 'x'], ref), 0);
    });
    test('the cadence list is well formed', () {
      expect(paluwaganCadences.map((c) => c['key']).toList(),
          ['weekly', 'kinsenas', 'monthly']);
    });
  });
}
