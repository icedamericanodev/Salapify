---
name: porting-money-logic
description: Use when porting any money calculation from the React Native app (mobile/) to the Flutter app (flutter/), or adding new money math to flutter/. Triggers on balances, debt payoff, interest, amortization, tax, salary, contributions, 13th month, analytics, forecasts, budgets, utang, or any function that returns pesos or a financial date.
---

# Porting money logic behind the golden lock

Salapify's rule: port the brain exactly, improve the body. A money number in
the Flutter app must match the live RN app to the centavo. This is enforced
by golden vectors generated from the REAL RN code, never hand-written.

## The contract

1. Generate goldens by EXECUTING the real RN module, not by reading it. Use a
   node harness in the scratchpad: createRequire from mobile/package.json,
   babel transformFileSync over mobile/lib, call the real function across a
   fixture set, write JSON to flutter/test/goldens/<name>_goldens.json. Copy
   existing gen-*-goldens.js in the scratchpad as the template.
2. Port the function to flutter/lib/money/ preserving JS semantics exactly:
   _jsRound(x) = (x + 0.5).floorToDouble() for Math.round; amountOf = Number(x)
   || 0; reject out-of-range months and days the way the JS Date grammar does
   (DateTime.tryParse would wrongly normalize them); add an index tiebreak to
   every sort because Dart's sort is not stable and JS's is.
3. Replay in a Dart test with normalize(): num to double, non-finite to null.
   Compare exactly, except rate fields from bisection which drift a few ulps,
   compare those at ~1e-9 relative tolerance.
4. Net-new math with no RN counterpart gets its own Dart unit tests instead of
   a golden replay, and say so in the test (e.g. goalForecast, whatIfLadder's
   derived savings).

## Non-negotiables

- Money math does not merge without matching test vectors. No exceptions:
  "it's a tiny change" and "it obviously matches" are exactly when a centavo
  drifts. Generate the vectors.
- The engine lives in flutter/lib/money/, never inline in a screen. A screen
  that computes a peso is a bug; move it behind the lock (this is how
  monthlyInterest and whatIfLadder came to live in debtmath.dart).
- Guard non-finite before round(): a backup can smuggle Infinity or a value
  whose *100 overflows, and round() throws on non-finite. Render the raw value
  and stay alive, the way formatMoney and _wholePeso do.

## Quick reference

- Harness pattern: scratchpad gen-*-goldens.js (RN require + babel + fixtures)
- Goldens: flutter/test/goldens/<name>_goldens.json
- Replay: flutter/test/<name>_golden_test.dart with normalize()
- Semantics helpers already in the codebase: _jsRound, amountOf, _jsDate,
  stable-sort-with-index, _jsStr / _jsFalsy

## Then

Run flutter analyze (zero issues) and flutter test from flutter/, bump the
updateStamp in flutter/lib/main.dart, then gate and merge per CLAUDE.md
(qa-tester plus the fitting money specialist: bank-officer for loans and BNPL,
tax-professional for tax, compensation-benefits for salary and contributions,
plus CI green on head). Money math is a significant change, announce it to the
founder right after merging.

## Common mistakes

- Reading the RN code and re-implementing from understanding. Execute it and
  diff the numbers instead; understanding misses rounding and coercion edges.
- Using DateTime.tryParse for a user date string, which normalizes 2026-02-30
  to March. Match JS: reject what the JS Date grammar rejects.
- Forgetting the sort tiebreak, so a tie orders differently than RN and one
  golden row flaps.
