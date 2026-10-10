// Golden vectors for the instalment plan port.
//
// Run with: bun app/tool/gen_installment_vectors.ts
//
// Same shape as gen_debt_vectors.ts and for the same reason: the prototype's
// recordInstallmentPayment and recordInstallmentExtraPayment live inside a
// React closure and cannot be imported, so both reducers are TRANSCRIBED here
// line for line from src/context/FinancialContext.tsx and run over the
// prototype's own seeded plans.
//
// The transcription is the weak link. It is kept deliberately literal, with no
// tidying and no renamed variables, so it can be diffed against the source.

import { INITIAL_INSTALLMENTS } from '../../src/data/initialData';
import type { InstallmentPlan } from '../../src/types';

const TODAY = '2026-09-18';

// --- transcribed from FinancialContext.tsx, recordInstallmentPayment -------
function recordInstallmentPayment(
  installments: InstallmentPlan[],
  id: string
): InstallmentPlan[] {
  const inst = installments.find((i) => i.id === id);
  if (!inst) return installments;

  const nextPaid = inst.paidInstallments + 1;
  const isNowSettled = nextPaid >= inst.totalInstallments;
  const nextBalance = isNowSettled
    ? 0
    : Math.max(0, inst.runningBalance - inst.installmentAmount);
  const nextPrincipal = isNowSettled
    ? 0
    : Math.max(
        0,
        inst.principalRemaining - inst.principal / inst.totalInstallments
      );

  return installments.map((item) =>
    item.id === id
      ? {
          ...item,
          paidInstallments: nextPaid,
          runningBalance: nextBalance,
          principalRemaining: nextPrincipal,
          isSettled: isNowSettled,
        }
      : item
  );
}

// --- transcribed from FinancialContext.tsx, recordInstallmentExtraPayment --
function recordInstallmentExtraPayment(
  installments: InstallmentPlan[],
  id: string,
  amount: number,
  note?: string
): InstallmentPlan[] {
  const inst = installments.find((i) => i.id === id);
  if (!inst) return installments;

  const newExtra = {
    id: 'ext_fixed',
    date: TODAY,
    amount,
    note: note || 'Principal prepayment',
  };

  const newRunning = Math.max(0, inst.runningBalance - amount);
  const newPrincipal = Math.max(0, inst.principalRemaining - amount);
  const isNowSettled = newRunning <= 0;

  return installments.map((item) =>
    item.id === id
      ? {
          ...item,
          runningBalance: newRunning,
          principalRemaining: newPrincipal,
          isSettled: isNowSettled,
          extraPayments: [...(item.extraPayments || []), newExtra],
        }
      : item
  );
}

const pick = (list: InstallmentPlan[], id: string) =>
  list.find((i) => i.id === id)!;

const shape = (p: InstallmentPlan) => ({
  id: p.id,
  paidInstallments: p.paidInstallments,
  runningBalance: p.runningBalance,
  principalRemaining: p.principalRemaining,
  isSettled: p.isSettled,
  extraCount: (p.extraPayments || []).length,
});

const out: Record<string, unknown> = {};
out.seed = INITIAL_INSTALLMENTS.map(shape);

// One scheduled payment on each of the three, which differ in shape: a
// monthly add-on plan, a genuine 0 percent promo, and an e-commerce plan.
out.payments = ['inst_home_credit', 'inst_bpi_sip', 'inst_spaylater'].map(
  (id) => ({
    id,
    after: shape(pick(recordInstallmentPayment(INITIAL_INSTALLMENTS, id), id)),
  })
);

// Paying the SPayLater plan all the way out, to pin what the last instalment
// does. It is 2 of 6, so four more payments settle it.
out.paidToTheEnd = (() => {
  let list = INITIAL_INSTALLMENTS;
  const steps: unknown[] = [];
  for (let n = 0; n < 4; n++) {
    list = recordInstallmentPayment(list, 'inst_spaylater');
    steps.push(shape(pick(list, 'inst_spaylater')));
  }
  return steps;
})();

// A payment on an ALREADY settled plan. The prototype does not guard this.
out.paymentPastTheEnd = (() => {
  let list = INITIAL_INSTALLMENTS;
  for (let n = 0; n < 5; n++) {
    list = recordInstallmentPayment(list, 'inst_spaylater');
  }
  return shape(pick(list, 'inst_spaylater'));
})();

out.extras = [
  { id: 'inst_home_credit', amount: 5000 },
  { id: 'inst_spaylater', amount: 6591.2 },
  { id: 'inst_spaylater', amount: 99999 },
].map((c) => ({
  ...c,
  after: shape(
    pick(
      recordInstallmentExtraPayment(INITIAL_INSTALLMENTS, c.id, c.amount),
      c.id
    )
  ),
}));

console.log(JSON.stringify(out, null, 2));
