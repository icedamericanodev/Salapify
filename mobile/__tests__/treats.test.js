// Regression suite for lib/treats.js: the earn-your-treats check-in logic.
// The invariants that must never break: adding then undoing a check-in nets
// to zero, lifetime only grows, check-ins age out of the rolling window, and
// junk never throws. Ported from the scratchpad harness with a fixed ref date.

import { treatStatus, toggleCheckIn, newTreat, pruneCheckIns, TREAT_TEMPLATES } from '../lib/treats';

const REF = new Date(2026, 6, 15); // Wednesday, 15 July 2026, local time.

// 'YYYY-MM-DD' for n days before REF, matching the module's own local-time math.
const iso = (n) => {
  const d = new Date(2026, 6, 15 - n);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

describe('newTreat normalizes form fields to safe defaults', () => {
  const t = newTreat({ treat: 'Kape', action: 'Lakad' }, REF);
  test('the target defaults to 3', () => expect(t.target).toBe(3));
  test('the window defaults to 7 days', () => expect(t.windowDays).toBe(7));
  test('a new treat starts with no check-ins', () => expect(t.checkIns).toHaveLength(0));
  test('a new treat starts at zero lifetime', () => expect(t.lifetime).toBe(0));
  test('createdAt is stamped with the reference date', () => expect(t.createdAt).toBe(iso(0)));
});

describe('a single check-in today', () => {
  let t = newTreat({ treat: 'Kape', action: 'Lakad' }, REF);
  t = toggleCheckIn(t, REF);
  const s = treatStatus(t, REF);
  test('recent count rises to 1', () => expect(s.recent).toBe(1));
  test('lifetime rises to 1', () => expect(s.lifetime).toBe(1));
  test('it is marked done today', () => expect(s.doneToday).toBe(true));
  test('it is not earned yet at 1 of 3', () => expect(s.earned).toBe(false));
  test('remaining shows 2 more to go', () => expect(s.remaining).toBe(2));
});

describe('undoing the same day nets back to zero', () => {
  let t = newTreat({ treat: 'Kape', action: 'Lakad' }, REF);
  t = toggleCheckIn(t, REF); // add
  t = toggleCheckIn(t, REF); // undo
  const s = treatStatus(t, REF);
  test('recent returns to 0', () => expect(s.recent).toBe(0));
  test('lifetime returns to 0', () => expect(s.lifetime).toBe(0));
  test('it is no longer done today', () => expect(s.doneToday).toBe(false));
  test('the stored check-ins are empty', () => expect(t.checkIns).toHaveLength(0));
});

describe('a treat is earned once the target is reached in the window', () => {
  const t = { treat: 'Kape', action: 'Lakad', target: 3, windowDays: 7, checkIns: [iso(0), iso(1), iso(2)], lifetime: 3 };
  const s = treatStatus(t, REF);
  test('recent equals the three in-window days', () => expect(s.recent).toBe(3));
  test('it is earned', () => expect(s.earned).toBe(true));
  test('nothing remains', () => expect(s.remaining).toBe(0));
});

describe('a check-in aging past the window drops recent but never lifetime', () => {
  const t = { treat: 'Kape', action: 'Lakad', emoji: '☕', target: 3, windowDays: 7, checkIns: [iso(0), iso(1), iso(10)], lifetime: 3 };
  const s = treatStatus(t, REF);
  test('the day 10 check-in falls outside the 7-day window', () => expect(s.recent).toBe(2));
  test('lifetime is untouched by the window slide', () => expect(s.lifetime).toBe(3));
  test('it is no longer earned once a day ages out', () => expect(s.earned).toBe(false));
});

describe('pruneCheckIns keeps only in-window days and drops junk', () => {
  const pruned = pruneCheckIns([iso(0), iso(0), iso(3), iso(30), 'junk', iso(-1)], 7, REF);
  test('duplicates and out-of-window and junk are all removed', () => expect(pruned).toHaveLength(2));
  test('today survives', () => expect(pruned).toContain(iso(0)));
  test('a day inside the window survives', () => expect(pruned).toContain(iso(3)));
  test('a future-dated check-in is dropped', () => expect(pruned).not.toContain(iso(-1)));
});

describe('toggling prunes stored check-ins to the window', () => {
  let t = { treat: 'x', action: 'y', target: 3, windowDays: 7, checkIns: [iso(20)], lifetime: 5 };
  t = toggleCheckIn(t, REF); // add today; the day-20 entry should prune out of storage
  test('an old stored check-in is pruned away', () => expect(t.checkIns).not.toContain(iso(20)));
  test('today is kept in storage', () => expect(t.checkIns).toContain(iso(0)));
  test('lifetime still only grows', () => expect(t.lifetime).toBe(6));
});

describe('robustness', () => {
  test('the starter templates are all well formed', () => {
    expect(TREAT_TEMPLATES).toHaveLength(4);
    expect(TREAT_TEMPLATES.every((x) => x.treat && x.action && x.target >= 1)).toBe(true);
  });

  test('junk input never throws', () => {
    expect(() => {
      treatStatus(null, REF);
      toggleCheckIn(undefined, REF);
      newTreat(null, REF);
      pruneCheckIns(null, 0, REF);
    }).not.toThrow();
  });
});
