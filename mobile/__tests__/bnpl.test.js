// Regression suite for lib/bnpl.js: the installment true-cost engine.
import { bnplCost } from '../lib/bnpl';

describe('bnplCost', () => {
  test('a genuinely free 0% plan reads as free, no extra cost', () => {
    // 12,000 over 6 months at exactly 2,000/month, no fee, no downpayment.
    const r = bnplCost({ cashPrice: 12000, months: 6, monthlyPayment: 2000 });
    expect(r.totalPaid).toBe(12000);
    expect(r.extraCost).toBe(0);
    expect(r.trulyFree).toBe(true);
    expect(r.annualRate).toBeCloseTo(0, 5);
  });

  test('a "0%" plan with an upfront fee is unmasked as costing more', () => {
    // Same plan but a 600 processing fee. It is no longer free.
    const r = bnplCost({ cashPrice: 12000, months: 6, monthlyPayment: 2000, upfrontFee: 600 });
    expect(r.totalPaid).toBe(12600);
    expect(r.extraCost).toBe(600);
    expect(r.trulyFree).toBe(false);
    expect(r.annualRate).toBeGreaterThan(0);
  });

  test('a marked-up installment shows the extra over cash and a real rate', () => {
    // 12,000 cash, but the plan is 2,200/month for 6 = 13,200.
    const r = bnplCost({ cashPrice: 12000, months: 6, monthlyPayment: 2200 });
    expect(r.totalPaid).toBe(13200);
    expect(r.extraCost).toBe(1200);
    expect(r.trulyFree).toBe(false);
    // A 1,200 markup on 12,000 over 6 months is a punishing annual rate.
    expect(r.annualRate).toBeGreaterThan(0.3);
  });

  test('a downpayment reduces what is financed', () => {
    const r = bnplCost({ cashPrice: 12000, downpayment: 3000, months: 6, monthlyPayment: 1500 });
    expect(r.financed).toBe(9000);
    expect(r.totalPaid).toBe(3000 + 1500 * 6); // 12,000
    expect(r.extraCost).toBe(0);
    expect(r.trulyFree).toBe(true);
  });

  test('an underpaying plan (payments below cash price) is flagged, never called free', () => {
    // 1,500 x 6 = 9,000 does not even cover a 12,000 item: a typo, not a deal.
    const r = bnplCost({ cashPrice: 12000, months: 6, monthlyPayment: 1500 });
    expect(r.underpays).toBe(true);
    expect(r.trulyFree).toBe(false);
  });

  test('a fee at or above the financed amount gives no misleading 0% rate', () => {
    // 20,000 fee on a 12,000 item: net credit is zero, so the rate is not
    // meaningful and must not print as 0%, the extra cost carries the message.
    const r = bnplCost({ cashPrice: 12000, months: 6, monthlyPayment: 2000, upfrontFee: 20000 });
    expect(r.netCredit).toBe(0);
    expect(r.rateReliable).toBe(false);
    expect(r.extraCost).toBe(20000);
    expect(r.trulyFree).toBe(false);
  });

  test('junk and negatives never throw and never go negative', () => {
    expect(() => bnplCost(null)).not.toThrow();
    expect(() => bnplCost({ cashPrice: 'bad', months: -3, monthlyPayment: null })).not.toThrow();
    const r = bnplCost({ cashPrice: -100, months: 0, monthlyPayment: -50 });
    expect(r.extraCost).toBeGreaterThanOrEqual(0);
    expect(r.months).toBeGreaterThanOrEqual(1);
  });
});
