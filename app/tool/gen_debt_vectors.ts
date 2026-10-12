// Golden vectors for the debt payment port.
//
// Run with: bun app/tool/gen_debt_vectors.ts
//
// The prototype's recordDebtPayment and toggleDebtSettled live inside a React
// component's closure and cannot be imported, so the two reducers are
// TRANSCRIBED here, line for line, from src/context/FinancialContext.tsx and
// then run over the prototype's OWN seeded debts. That transcription is the
// weak link, so it is kept deliberately literal: no tidying, no early return,
// no renamed variable. Compare it against the source before trusting a
// regenerated file.
//
// The alternative, deriving the expected figures by hand, is what this whole
// procedure exists to avoid: a number I work out myself can agree with my own
// misreading of the source.

import { INITIAL_DEBTS } from '../../src/data/initialData';
import type { Debt } from '../../src/types';

const TODAY = '2026-09-18';

// --- transcribed from FinancialContext.tsx, recordDebtPayment ---------------
function recordDebtPayment(prev: Debt[], debtId: string, amount: number): Debt[] {
  return prev.map((d) => {
    if (d.id === debtId) {
      const newPaid = d.paidAmount + amount;
      const isSettled = newPaid >= d.totalAmount;
      return {
        ...d,
        paidAmount: newPaid,
        isSettled,
        settledDate: isSettled ? TODAY : d.settledDate,
        installmentCurrent: d.installmentCurrent
          ? Math.min(d.installmentTotal || 12, d.installmentCurrent + 1)
          : undefined,
      };
    }
    return d;
  });
}

// --- transcribed from FinancialContext.tsx, toggleDebtSettled --------------
function toggleDebtSettled(prev: Debt[], debtId: string): Debt[] {
  return prev.map((d) => {
    if (d.id === debtId) {
      const newSettled = !d.isSettled;
      return {
        ...d,
        isSettled: newSettled,
        settledDate: newSettled ? TODAY : undefined,
        paidAmount: newSettled ? d.totalAmount : d.paidAmount,
      };
    }
    return d;
  });
}

// --- the beam, transcribed from DebtScreen.tsx -----------------------------
function beam(debts: Debt[]) {
  const iOwe = debts
    .filter((d) => !d.isSettled && d.direction === 'i_owe')
    .reduce((s, d) => s + Math.max(0, d.totalAmount - d.paidAmount), 0);
  const owedToMe = debts
    .filter((d) => !d.isSettled && d.direction === 'owed_to_me')
    .reduce((s, d) => s + Math.max(0, d.totalAmount - d.paidAmount), 0);
  const totalCombined = owedToMe + iOwe;
  const owedToMePercent =
    totalCombined > 0
      ? Math.max(10, Math.min(90, (owedToMe / totalCombined) * 100))
      : 50;
  return { iOwe, owedToMe, owedToMePercent, youOwePercent: 100 - owedToMePercent };
}

const pick = (list: Debt[], id: string) => list.find((d) => d.id === id)!;

const shape = (d: Debt) => ({
  id: d.id,
  paidAmount: d.paidAmount,
  isSettled: d.isSettled,
  settledDate: d.settledDate ?? null,
  installmentCurrent: d.installmentCurrent ?? null,
});

const cases: Array<{ name: string; debtId: string; amount: number }> = [
  // A part payment on a scheduled instalment debt: the counter should advance.
  { name: 'partial on an instalment debt', debtId: 'debt_homecredit', amount: 2450 },
  // Exactly enough to clear it.
  { name: 'exact payoff', debtId: 'debt_homecredit', amount: 7350 },
  // More than enough. The prototype does NOT cap paidAmount.
  { name: 'overpayment', debtId: 'debt_homecredit', amount: 10000 },
  // A flexible receivable with no instalment counter at all.
  { name: 'partial on a flexible receivable', debtId: 'debt_kuya_mark', amount: 1500 },
  { name: 'receivable paid in full', debtId: 'debt_sarah', amount: 1250 },
  // Paying an already settled debt: settledDate must NOT be restamped.
  { name: 'payment on an already settled debt', debtId: 'debt_mom_settled', amount: 500 },
  // The last instalment, where the counter is already at its cap minus one.
  { name: 'instalment counter near its cap', debtId: 'debt_bpi_loan', amount: 10000 },
];

const out: Record<string, unknown> = {};
out.seed = INITIAL_DEBTS.map(shape);
out.beamAtSeed = beam(INITIAL_DEBTS);

out.payments = cases.map((c) => {
  const next = recordDebtPayment(INITIAL_DEBTS, c.debtId, c.amount);
  return {
    ...c,
    after: shape(pick(next, c.debtId)),
    beam: beam(next),
  };
});

out.toggles = ['debt_homecredit', 'debt_mom_settled', 'debt_kuya_mark'].map(
  (id) => ({
    debtId: id,
    after: shape(pick(toggleDebtSettled(INITIAL_DEBTS, id), id)),
  })
);

// Settling then un-settling, to pin what the round trip leaves behind.
out.toggleRoundTrip = (() => {
  const once = toggleDebtSettled(INITIAL_DEBTS, 'debt_homecredit');
  const twice = toggleDebtSettled(once, 'debt_homecredit');
  return shape(pick(twice, 'debt_homecredit'));
})();

console.log(JSON.stringify(out, null, 2));
