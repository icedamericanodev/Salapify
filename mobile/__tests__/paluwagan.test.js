// Regression suite for lib/paluwagan.js: the rotating savings (paluwagan)
// engine. The invariants that must never break: a full round is zero sum, the
// payout lands on your turn's date, "behind" means a due contribution is
// unpaid, the timing read (early loan vs late savings) is stable, the
// contribution feeds safe-to-spend while the round runs and stops when it ends,
// and junk never throws. Fixed ref date so the schedule math is deterministic.

import {
  newPaluwagan,
  paluwaganStatus,
  paluwaganMonthlyCommitment,
  paluwaganTotalCommitment,
  PALUWAGAN_CADENCES,
} from '../lib/paluwagan';

const REF = new Date(2026, 6, 15); // 15 July 2026, local.

// A clean monthly paluwagan: 5 members, PHP 1000 each, started 10 May 2026,
// you are turn 3, you have paid 2 of the cycles due so far.
const monthly = {
  id: 'p1',
  name: 'Office paluwagan',
  amount: 1000,
  members: 5,
  cadence: 'monthly',
  startDate: '2026-05-10',
  myTurn: 3,
  paidCycles: 2,
};

describe('newPaluwagan normalizes a raw form to safe defaults', () => {
  const p = newPaluwagan({ name: '  ', amount: '2500' }, REF);
  test('defaults to 5 members', () => expect(p.members).toBe(5));
  test('defaults to a monthly cadence', () => expect(p.cadence).toBe('monthly'));
  test('reads a string amount the JS way', () => expect(p.amount).toBe(2500));
  test('blank name falls back to Paluwagan', () => expect(p.name).toBe('Paluwagan'));
  test('startDate defaults to the reference day', () =>
    expect(p.startDate).toBe('2026-07-15'));
  test('your turn defaults to 1', () => expect(p.myTurn).toBe(1));

  test('members and turn are clamped to a sane range', () => {
    const big = newPaluwagan({ members: 500, myTurn: 999 }, REF);
    expect(big.members).toBe(60);
    expect(big.myTurn).toBe(60);
    const tiny = newPaluwagan({ members: 1 }, REF);
    expect(tiny.members).toBe(2); // a paluwagan needs at least two people
  });
});

describe('paluwaganStatus computes the decision figures', () => {
  const s = paluwaganStatus(monthly, REF);

  test('payout is the full pot on your turn date', () => {
    expect(s.payoutAmount).toBe(5000); // 1000 * 5
    expect(s.payoutDate).toBe('2026-07-10'); // cycle 3 from a 10 May start
  });
  test('three cycles have come due by 15 July', () => {
    expect(s.currentCycle).toBe(3);
  });
  test('your payout has landed by schedule', () => {
    expect(s.received).toBe(true);
    expect(s.cyclesToPayout).toBe(0);
  });
  test('behind flags an unpaid contribution that is already due', () => {
    // 3 cycles due, only 2 paid, so one PHP 1000 ambag is behind.
    expect(s.behind).toBe(true);
    expect(s.behindBy).toBe(1000);
  });
  test('net position reflects money held vs put in', () => {
    expect(s.contributedSoFar).toBe(2000);
    expect(s.remainingContribution).toBe(3000);
    expect(s.netNow).toBe(3000); // received 5000, put in 2000
  });
  test('a full round is zero sum: total in equals payout', () => {
    expect(s.totalContribution).toBe(s.payoutAmount);
  });
  test('the round is not finished', () => expect(s.done).toBe(false));
});

describe('the timing read (dealType) is based on position, not pesos', () => {
  const at = (turn) =>
    paluwaganStatus({ ...monthly, members: 6, myTurn: turn }, REF).dealType;
  test('an early turn reads as a loan', () => expect(at(1)).toBe('early'));
  test('a middle turn reads as even', () => expect(at(3)).toBe('middle'));
  test('a late turn reads as forced savings', () => expect(at(6)).toBe('late'));
});

describe('weekly and kinsenas schedules land on the right dates', () => {
  test('weekly steps seven days per cycle', () => {
    const s = paluwaganStatus(
      { ...monthly, cadence: 'weekly', startDate: '2026-07-01', members: 4, myTurn: 2 },
      REF);
    expect(s.payoutDate).toBe('2026-07-08'); // second weekly cycle
    expect(s.currentCycle).toBe(3); // 01, 08, 15 have come due by the 15th
  });
  test('kinsenas lands on the 15th and end of month', () => {
    const s = paluwaganStatus(
      { ...monthly, cadence: 'kinsenas', startDate: '2026-06-15', members: 4, myTurn: 3 },
      REF);
    // cycles: 06-15, 06-30, 07-15, 07-31; turn 3 is 07-15.
    expect(s.payoutDate).toBe('2026-07-15');
    expect(s.currentCycle).toBe(3);
  });
});

describe('the monthly commitment feeds safe-to-spend', () => {
  test('a monthly cadence commits the amount', () => {
    expect(paluwaganMonthlyCommitment(monthly, REF)).toBe(1000);
  });
  test('weekly and kinsenas normalize to per-month', () => {
    // A wide-open round (nothing paid, plenty owed) so the pure run-rate shows.
    const base = { ...monthly, members: 6, paidCycles: 0, startDate: '2026-07-01' };
    const wk = paluwaganMonthlyCommitment({ ...base, cadence: 'weekly', amount: 500 }, REF);
    expect(wk).toBeCloseTo(500 * (52 / 12), 6);
    const kn = paluwaganMonthlyCommitment({ ...base, cadence: 'kinsenas', amount: 500 }, REF);
    expect(kn).toBe(1000);
  });
  test('the reserve never exceeds what you still owe', () => {
    // A short weekly round: run-rate 2166.67/mo but only 1500 left to pay in,
    // so safe-to-spend reserves the 1500, not the higher run-rate.
    const shortRound = {
      ...monthly, cadence: 'weekly', amount: 500, members: 5, paidCycles: 2,
      startDate: '2026-07-01',
    };
    const s = paluwaganStatus(shortRound, REF);
    expect(s.remainingContribution).toBe(1500);
    expect(paluwaganMonthlyCommitment(shortRound, REF)).toBe(1500);
  });
  test('a fully-prepaid member reserves nothing, even mid-round', () => {
    const prepaid = { ...monthly, paidCycles: 5 }; // all 5 cycles paid, round not done
    const s = paluwaganStatus(prepaid, REF);
    expect(s.done).toBe(false);
    expect(s.remainingContribution).toBe(0);
    expect(paluwaganMonthlyCommitment(prepaid, REF)).toBe(0);
  });
  test('a finished round commits nothing more', () => {
    const doneRound = {
      ...monthly, members: 3, startDate: '2026-01-10', myTurn: 1, paidCycles: 3,
    };
    const s = paluwaganStatus(doneRound, REF);
    expect(s.done).toBe(true);
    expect(paluwaganMonthlyCommitment(doneRound, REF)).toBe(0);
  });
  test('total commitment sums the active groups only', () => {
    const doneRound = {
      ...monthly, members: 3, startDate: '2026-01-10', myTurn: 1, paidCycles: 3,
    };
    expect(paluwaganTotalCommitment([monthly, doneRound], REF)).toBe(1000);
  });
});

describe('early-recipient net must be paired with the remaining owed', () => {
  // An early turn shows a positive net now, but it is a 0% loan: the member
  // still owes the rest. The engine exposes both so the screen never renders
  // "you are up PHP X" without "you still owe PHP Y".
  const early = { ...monthly, myTurn: 1, paidCycles: 1 };
  const s = paluwaganStatus(early, REF);
  test('received early, holding the pot', () => {
    expect(s.received).toBe(true);
    expect(s.netNow).toBeGreaterThan(0);
  });
  test('the remaining obligation is real and non-zero', () => {
    expect(s.remainingContribution).toBeGreaterThan(0);
  });
});

describe('a degenerate one-person group is refused at both entry points', () => {
  test('paluwaganStatus floors members at two', () => {
    const s = paluwaganStatus({ ...monthly, members: 1 }, REF);
    expect(s.members).toBe(2);
  });
});

describe('junk never throws', () => {
  test('non-finite amount and bad date are safe', () => {
    const s = paluwaganStatus(
      { amount: 'abc', members: 4, cadence: 'monthly', startDate: '2026-02-30', myTurn: 2 },
      REF);
    expect(s.amount).toBe(0);
    expect(s.payoutAmount).toBe(0);
    expect(typeof s.dealType).toBe('string');
  });
  test('a junk list totals to zero, not a crash', () => {
    expect(paluwaganTotalCommitment(null, REF)).toBe(0);
    expect(paluwaganTotalCommitment([null, 42, undefined], REF)).toBe(0);
  });
  test('the cadence list is well formed', () => {
    expect(PALUWAGAN_CADENCES.map((c) => c.key)).toEqual(['weekly', 'kinsenas', 'monthly']);
  });
});
