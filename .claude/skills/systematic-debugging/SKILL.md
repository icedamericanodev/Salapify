---
name: systematic-debugging
description: Use when a Salapify test fails, a golden vector mismatches, a number is wrong on screen, the app crashes, a Flutter layout throws, or a fix did not work. Triggers on "still failing", "not sure why", a red test, a stack trace, "the number is off", unbounded constraints, or the urge to try another quick patch.
---

# Systematic debugging: find the root cause first

Adapted for Salapify from obra/superpowers (MIT). Always find the root cause
before attempting a fix. Guess-and-check thrashing is slower than this, not
faster, and on money math a wrong patch can ship a wrong number to real
people.

## Four phases, in order

1. Investigate the root cause. Read the FULL error, not the first line.
   Reproduce it reliably (a single failing test, an exact input). Check what
   changed recently. Trace the data backward through the call stack to where
   it first goes wrong, do not fix at the symptom.
2. Analyze the pattern. Find a working example (the RN original in mobile/,
   the golden generator, a sibling function). Read it completely and name the
   exact difference between working and broken.
3. Hypothesis and test. State a specific theory of the cause. Test it with the
   SMALLEST possible change. Do not stack fixes on top of fixes.
4. Fix. Write a failing test that captures the bug, then make the single
   change that addresses the underlying cause, then confirm the test and the
   full suite pass.

## The three-fix rule (hard stop)

If three fixes in a row fail, STOP patching. The design or an assumption is
wrong, not just a line. Step back and question the shape. In this session's
history that is exactly how the loan-screen infinity crash and the safe-to
spend contradictions got truly fixed, by clamping in the right space instead
of adding another guard.

## Salapify-specific first suspects

When a golden vector or an on-screen number mismatches, check these before
anything else:
- normalize(): num to double, non-finite to null. A NaN or Infinity slipping
  through is the usual culprit.
- JS semantics helpers: _jsRound is Math.round = floor(x + 0.5); amountOf is
  Number(x) || 0; the JS Date grammar rejects out-of-range months and days
  where DateTime.tryParse would normalize them; stable sort needs an index
  tiebreak because Dart's sort is not stable.
- ulp drift: rate fields from bisection can differ from V8 by a few ulps.
  Compare those at a small relative tolerance, everything else exactly.
- The store coerces missing numeric fields (e.g. a blank monthlyRate) to 0
  on load, so a "missing" field never arrives as null in real data.

When a Flutter layout throws or overflows, first suspect an unbounded width:
a hero Text in a Row without Expanded or Flexible, or a FittedBox with no
bounded parent.

## Red flags (restart the process if you catch yourself)

- Proposing a fix before reproducing the failure.
- "I'll just add another guard" for the third time.
- Assuming what the value is instead of printing or testing it.
- "No time to be systematic." Systematic IS the fast path here.
