// Golden vectors for the Split Bill port.
//
// Run with: bun app/tool/gen_split_vectors.ts
//
// Unlike gen_debt_vectors.ts, nothing here is transcribed. calculateSplitShares
// is a plain exported function in src/utils/collaborationEngine.ts, so it is
// IMPORTED and EXECUTED, and the numbers it prints become the expectations in
// app/test/core/money/split_bill_test.dart. Deriving them by hand is exactly
// what this procedure exists to avoid: a figure I work out myself can agree
// with my own misreading of the source.
//
// The fixture set is chosen to reach the edges rather than the happy path:
// an amount that does not divide evenly, percentages that do not total 100,
// fixed amounts that under and over shoot the bill, a single participant, and
// a zero bill.

import { calculateSplitShares } from '../../src/utils/collaborationEngine';
import type { SplitMethod } from '../../src/types';

interface Case {
  readonly label: string;
  readonly total: number;
  readonly method: SplitMethod;
  readonly names: string[];
  readonly inputs?: Record<string, number>;
}

const cases: Case[] = [
  // EQUAL. 1000 over 3 is the classic: 333.33 each leaves a centavo over.
  { label: 'equal_even', total: 1200, method: 'equal', names: ['You', 'Carla'] },
  { label: 'equal_thirds', total: 1000, method: 'equal', names: ['You', 'A', 'B'] },
  { label: 'equal_seven', total: 100, method: 'equal', names: ['You', 'A', 'B', 'C', 'D', 'E', 'F'] },
  { label: 'equal_one', total: 500, method: 'equal', names: ['You'] },
  { label: 'equal_centavos', total: 33.33, method: 'equal', names: ['You', 'A', 'B'] },

  // PERCENTAGE. The last participant absorbs the rounding, by design.
  { label: 'pct_half', total: 1000, method: 'percentage', names: ['You', 'Carla'], inputs: { You: 50, Carla: 50 } },
  { label: 'pct_uneven', total: 1000, method: 'percentage', names: ['You', 'A', 'B'], inputs: { You: 33.3, A: 33.3, B: 33.4 } },
  { label: 'pct_over_100', total: 1000, method: 'percentage', names: ['You', 'A'], inputs: { You: 80, A: 80 } },
  { label: 'pct_under_100', total: 1000, method: 'percentage', names: ['You', 'A'], inputs: { You: 20, A: 20 } },
  { label: 'pct_missing_input', total: 900, method: 'percentage', names: ['You', 'A', 'B'] },

  // FIXED. Nothing forces these to add up to the bill.
  { label: 'fixed_exact', total: 1000, method: 'fixed', names: ['You', 'A'], inputs: { You: 400, A: 600 } },
  { label: 'fixed_short', total: 1000, method: 'fixed', names: ['You', 'A'], inputs: { You: 100, A: 200 } },
  { label: 'fixed_over', total: 1000, method: 'fixed', names: ['You', 'A'], inputs: { You: 900, A: 900 } },
  { label: 'fixed_missing_input', total: 1000, method: 'fixed', names: ['You', 'A', 'B'] },

  // SHARES. A ratio rather than a percentage.
  { label: 'shares_2_1', total: 900, method: 'shares', names: ['You', 'A'], inputs: { You: 2, A: 1 } },
  { label: 'shares_default_1', total: 900, method: 'shares', names: ['You', 'A', 'B'] },
  { label: 'shares_uneven', total: 1000, method: 'shares', names: ['You', 'A', 'B'], inputs: { You: 1, A: 1, B: 1 } },

  // A NEGATIVE HALF, which is the only input where JavaScript's Math.round
  // and Dart's round() disagree: JS rounds toward positive infinity and gives
  // -0, Dart rounds away from zero and gives -1.
  //
  // Added only AFTER the fixture audit. Swapping the port's _jsRound for
  // Dart's round() passed all twenty original cases, which said the fixture
  // set was incomplete rather than the port correct. Nothing stops somebody
  // typing a negative fixed amount: the prototype runs parseFloat over a text
  // field and does not check the sign.
  { label: 'fixed_negative_half', total: 1000, method: 'fixed', names: ['You', 'A'], inputs: { You: -0.5, A: 1000.5 } },
  { label: 'pct_negative', total: 1000, method: 'percentage', names: ['You', 'A'], inputs: { You: -0.05, A: 100 } },

  // DEGENERATE. Both return an empty list, and that is worth locking.
  { label: 'zero_total', total: 0, method: 'equal', names: ['You', 'A'] },
  { label: 'negative_total', total: -100, method: 'equal', names: ['You', 'A'] },
  { label: 'no_names', total: 1000, method: 'equal', names: [] },
];

const out = cases.map((c) => ({
  label: c.label,
  total: c.total,
  method: c.method,
  names: c.names,
  inputs: c.inputs ?? null,
  shares: calculateSplitShares(c.total, c.method, c.names, c.inputs),
  // The sum matters as much as the parts: several methods do NOT guarantee
  // the shares add back up to the bill, and the UI has to say so.
  sum: Number(
    calculateSplitShares(c.total, c.method, c.names, c.inputs)
      .reduce((s, p) => s + p.shareAmount, 0)
      .toFixed(4),
  ),
}));

console.log(JSON.stringify(out, null, 2));
