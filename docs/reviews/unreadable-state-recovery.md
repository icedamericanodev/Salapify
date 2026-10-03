# The unreadable state gets a way out

Branch `claude/review-build`, PR #477, into `claude/flutter-final`.
Written 2026-10-01.

## Scope

One state: Salapify opened, could not make sense of its data file, and
therefore never applied it. Three features that only exist in that state, plus
the three BROKEN findings the `rounding-controller` pass returned on the
instalment and debt payment paths.

Nothing here is a schema change, a migration, or a change to what is written to
disk. The stored shape is byte for byte what it was.

## Why the state needed work at all

It was a dead end, and every individual decision that made it one was defensible
on its own.

Export was disabled, correctly, because `state.snapshot()` in that state encodes
the SEED: eleven demo accounts, under a row promising "everything on this
phone". Restore was disabled, correctly, because the pre-import copy is taken
from the same snapshot, so importing would have thrown the person's records away
while reporting that it had kept them. Saving was off, correctly. The banners had
been removed on 2026-09-19, correctly, because they sat in front of every screen.

The sum of four correct decisions was: eleven sample accounts on screen, no
sentence anywhere saying they are not yours, no way to get your file off the
phone, and no way to put a good backup on it. The data file lives in app-private
storage that a stock Android file manager cannot open, so the only remaining move
is to uninstall, which destroys the very file that might still have been
rescued by hand.

## What changed

### 1. Home says the figures are not yours

`_CannotReadBanner` in `app/lib/screens/home/home_screen.dart`, shown only when
`state.loadStatus == LoadStatus.unreadable`.

It names the two wrong conclusions it exists to prevent, and nothing else:

- that the sample ledger is yours
- that a week of typing is being saved

This is the ONE EXCEPTION in the working rules ("a figure, and the one short line
needed to read it"): silence here misleads, so the sentences stay on the screen
rather than going behind the dot.

Filled with `palette.negativeSoft` rather than given a `negative` border,
because in the dark palette `accent` and `negative` are the same orange
(`0xFFFF9A52`), so a thin orange border reads as brand chrome rather than as a
warning. This is visible in the render and is not visible to any test.

It carries a control, "What I can do about it", not a sentence telling somebody
to go and find one.

### 2. Export sends the raw bytes

`_exportRaw()` in `app/lib/features/settings/settings_sheet.dart`. The row is
re-enabled in the unreadable state and retitled "Export the file Salapify cannot
read", and it sends `state.rawStoredFile()`, which is `_store.read()`, not a
snapshot.

The old refusal was right about the danger and wrong about the remedy. The bytes
are still the person's records, and they are plain text.

### 3. Restore is offered, and keeps the unreadable bytes

`importSnapshot` in `app/lib/state/financial_state.dart` now has a branch for
`!_saveEnabled`. The copy promise is kept LITERALLY instead of being used as a
reason to block: `writePreImport` receives the raw bytes off disk.

The ordering is unchanged and is the safety property: the copy lands first, then
the new ledger is applied and saved. With nothing on disk to copy, it still
refuses, because the promise cannot be kept and this method's whole contract is
that the copy lands first.

## The three BROKEN findings, verified before fixing

### B1, a 991.20 conservation gap. This is the one that must not ship.

`payInstallmentExtra` capped the payment at `principalRemaining` while the
engine credited it against `runningBalance`. Reproduced before anything was
changed:

    handed over by the person : 6591.2
    plan history row says     : 6591.2
    ledger entry says         : 5600.0
    account fell by           : 5600.0
    CONSERVATION GAP          : 991.1999999999998

The person hands over 6,591.20. The plan records 6,591.20. The account falls by
5,600.00. The missing 991.20 is the interest portion, which the plan counted and
the ledger did not.

Fixed with one named policy, `appliedExtraPayment` in
`app/lib/core/money/installments.dart`, so the cap is decided once and both
sides read the same number.

### B2, the preview could promise a different figure than the engine

`installment_sheet.dart` computed its own THIS MONTH amount. It now reads
`nextPaymentFor(plan).pesos`, for both the figure and the confirmation sentence.

### B3, a debt payment could move net worth by half a centavo

`recordDebtPayment` handed a raw double to the debt engine and a rounded figure
to the ledger. Quantised once, at the door, and both sides use that value.

## What did NOT change

- **Money meaning.** No calculation, sign, precision or rounding policy was
  changed except where B1, B2 and B3 made two sides of one transaction
  disagree, which is a defect rather than a policy.
- **Stored data.** No schema change, no migration, no change to what is written
  to disk. `stored_shape_test.dart` is unchanged and green.
- **The golden vectors.** Every ledger vector holds.
- **The banner removal of 2026-09-19.** The standing banners are still gone.
  This one appears in a single state and in no other, which
  `unreadable_recovery_test.dart` asserts directly.

## Visual evidence

Rendered and reviewed, dark:

- `app/test/shots/out/home_unreadable.png`
- `app/test/shots/out/settings_unreadable.png`

Both are new. That state had no picture anywhere before this, so the only review
it had ever had was reading the code. The shots are registered in
`unreadableRecoveryShots()` so the next change to these screens is reviewable
too.

## Validation

- `flutter analyze`: no issues.
- `flutter test`: 1,496 pass, 0 fail.
- `dart format`: clean.
- Flutter 3.47.4 from `/opt/f3474`, which is the CI pin.

### Both rewritten tests were proven able to fail

Two tests asserted the behaviour this work deliberately reverses. They are
rewritten to the new truth rather than deleted, and each was broken on purpose
first.

Export row made dead again:

    Expected: not null
      Actual: <null>
    the export row was offered and then did nothing when tapped

Pre-import copy switched back to a snapshot of the seed:

    Expected: contains 'My real bank'
      Actual: '{\n'
    the pre-import copy held the sample ledger, so the only copy of the
    person's records was thrown away by the thing meant to save it

The second break reddened BOTH files that assert the copy promise, which is the
result worth having: the promise is checked in two places and neither one is
load-bearing alone.

## Deferred, with reasons

- **The storage panel prints the raw exception.** In the render it reads
  "FormatException: Not a usable peso amount: 100000000000000000.0" in front of
  somebody who is already alarmed. This is DELIBERATE: the code comment says it
  is kept because it is what makes a screenshot diagnosable, and the plain
  translated sentence sits above it carrying the reassurance. Reversing a
  considered decision on one reading of one render is a founder call, not mine.
- **"Sample data, remove them here" is offered in the unreadable state.** Saving
  is off, so tapping it writes nothing, but the row is confusing where the
  sample data is the only thing on screen. Not dangerous, so not widened into.
- **U1 to U7 from the controller pass.** Improvements, not blockers. U1 is the
  one worth doing next: the engines accumulate in doubles, so a budget spent
  exactly to its limit can read as over (proven: `5000.000000000001`).

## Risks

The import branch for the unreadable state turns saving ON after a successful
restore. That is correct and is what the person is there for, but it is the one
path in this change set that starts writing to a file that was previously being
left alone. It is gated behind a successful `writePreImport` of the raw bytes,
and it refuses outright when there is nothing on disk to copy.

## Founder decisions genuinely outstanding

- The payday rule (`paydayDays: [15, 30]`).
- A stored amount above roughly 90 trillion pesos will no longer open in the new
  build. It is refused rather than partly loaded, nothing is overwritten, and the
  person is told. This is safer than the old behaviour and it is still a change
  to how restore behaves.
