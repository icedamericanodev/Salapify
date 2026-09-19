# Storage: one file on the device

Founder approval, 2026-09-19: "go with will the recommendations", answering
three questions put to them the same day. This covers the first, storage and
its shape. The other two, archiving an account instead of deleting it and
leaving Safe to Spend as it is, are approved and NOT in this change.

## Scope

`app/` persists nothing. Everything lives in `FinancialState`, seeded on every
launch, so closing the app loses every account, entry, payment, budget and
goal. This is the step that makes the rest of the migration mean anything: up
to now every screen built was a screen the founder could tap and then lose.

Approved shape: one file on the device, in the prototype's own backup format,
so export and moving to a new phone work later without a rewrite.

## What changed

| File | What it is |
|---|---|
| `app/lib/data/json_codec.dart` | Every model to and from JSON, in the prototype's own spelling |
| `app/lib/data/snapshot.dart` | The whole document, plus the keys this build does not model |
| `app/lib/data/store.dart` | Where the file lives, how it is written, and what happens when it cannot be read |
| `app/lib/state/financial_state.dart` | `restore()`, and a save on every change |
| `app/lib/main.dart` | Reads the file before the first frame |
| `app/lib/screens/reports/reconciliation_view.dart` | Survives a ledger with no accounts in it |
| `app/pubspec.yaml` | `path_provider`, to find the documents directory |

Copy on three screens changed because it became false. See "Honesty" below.

## The format

Top level keys are the prototype's own, from `handleExportData` in
`src/components/SettingsModal.tsx`. A file written here opens in the prototype
and a prototype backup opens here.

It is a SUPERSET of that export, deliberately. See "The prototype defect not
ported".

Two spellings differ from the Dart field names, and getting either wrong is
silent corruption rather than a crash:

- Multi word enum values are snake_case on the wire: `side_hustle`, `i_owe`,
  `owed_to_me`, `weekly_income`, `semimonthly_salary`, `thirteenth_month`. The
  obvious `.name` would have written `sideHustle`, which the prototype does not
  recognise, and a side hustle read back as personal is money filed in the
  wrong books with nothing on screen to show it.
- A debt's schedule is stored under `scheduleType`, not `schedule`.
- A reconciliation's outcome is `status: "balanced" | "discrepancy"`, not a
  `balanced` boolean. Writing both would have left two fields meaning the same
  thing, and the moment they disagreed the prototype would read the stale one.

Every enum has an explicit two way map and a test that walks all fifteen of
them, asserting both directions and that no two values share a spelling.

## What it refuses to do

The decoder THROWS rather than guessing. A required field of the wrong type, an
enum value this build has never heard of, or a `schemaVersion` from the future
all refuse the whole file.

That is the point, not a rough edge. The caller's answer to a refusal is to
leave the file exactly as it was, and a file left alone can still be recovered.
Guessing a default would load a quietly wrong ledger and then save that over
the original.

Absent optionals stay tolerant: a missing field is an absence, a field holding
something unreadable is a contradiction.

## Recovery

The `recovery-designer` agent reviewed the design before it was built and
returned SAFE WITH CONDITIONS over seven must-fixes. Its findings, and what
happened to each:

| Finding | Outcome |
|---|---|
| No previous generation on disk | **Built.** Every save keeps the copy it replaced as `.prev`, tried first on a parse failure |
| `writeAsString` does not fsync by default | **Already right.** The implementation opens the file and calls `flush()` explicitly. Comment added on why, and that Dart still cannot fsync the directory |
| Unknown keys preserved only per record, not at the root | **Already right.** `Extras.top` holds root keys, so a prototype export's `payday`, `categories`, `spaces` and the rest survive |
| Enum wire values are not the Dart names | **Already right**, and the agent found one this build had wrong: `ReconciliationRecord.balanced` vs `status`. Fixed |
| Two saves can race and publish a halfway state | **Already right.** A serialized write chain plus coalescing, so a mutation that notifies twice writes once. Per save temp filename added as a belt |
| Seed data becomes the user's data permanently | **NOT fixed. To the founder.** See below |
| `accounts.first` crashes Reports on an empty ledger | **Fixed**, plus an empty state, plus a render |

Also fixed from its SHOULD list: a reconciliation history row printed a
different real account's name when the id no longer resolved, on the one screen
whose whole job is to be trustworthy about whether the app and the bank agree.

Its claims were checked against the code rather than taken on confidence. Three
were already handled; the brief it worked from described a proposal, not the
implementation.

## The prototype defect not ported

The prototype's export covers nine of the thirty four keys it stores. It omits
instalment plans, reconciliation history, bills, income streams, investments
and all the collaboration data.

It is worse than dropping them. `handleImportData` writes back only seven keys
and does not clear the rest, so on a wiped phone `salapify_installments_v3` and
`salapify_reconciliations_v3` stay unset and `FinancialContext` falls back to
`INITIAL_INSTALLMENTS` and `INITIAL_RECONCILIATION_HISTORY`. The user does not
get "no instalment plans". They get the DEMO instalment plans and a DEMO
reconciliation history, mixed with their real restored transactions, with no
notice. A reconciliation record is a written claim that somebody checked an
account on a date.

This file carries everything `app/` holds, and a test asserts the three the
prototype leaves out are present.

## Honesty

Three on-screen lines said entries were not saved to the phone. They were true
and right up until this change, and saying them now would be the same lie in
the other direction:

- `app_shell.dart`, the log confirmation, now "Saved to this phone."
- `home_screen.dart`, the debt confirmation, now "Added and saved to this phone."
- `budget_sheets.dart`, the caption, removed rather than reversed. Silence used
  to mislead; now that saving is what happens, silence is correct.

`academy_segment.dart` still says lesson progress is not saved, because it is
not: `_done` is local widget state, outside `FinancialState`. Left true rather
than made consistent.

`log_journey_test.dart` asserted the old warning. It now asserts the
confirmation and the absence of the warning, because the question it asks is
the same either way: does the screen tell the person what really happened.

## Validation

- `flutter analyze`, on the 3.47.4 pin: no issues
- `flutter test`: 510 pass, 0 fail. 466 before this batch, plus 44 new across
  snapshot_test, store_test and main_wiring_test
- Every screen rendered, 59 shots, the new empty state looked at and committed
  to `docs/migration/screens/reports-check-empty.png`

### Guards proved able to fail

Per the working rules, each new guard was broken once and the failure read.

**The central rule, an unreadable file is never written over.** Set
`_saveEnabled = true` on the unreadable branch:

    Expected: false
      Actual: <true>
    Expected: '{"schemaVersion":2,"accounts":[],"transactions":[]}'
      Actual: '{\n'

Four tests red, and the third shows the catastrophe directly: the file that
could not be read, replaced with fresh JSON.

**The enum wire spelling.** Changed `side_hustle` to `sideHustle`:

    Expected: 'side_hustle'
      Actual: 'sideHustle'

**The main wiring guard**, which no runtime test can replace because every
widget test deliberately runs on the memory store. Pointed `main` at
`MemorySnapshotStore`:

    Expected: contains 'FileSnapshotStore()'
      Actual: 'import \'package:flutter/material.dart\';\n'

## A test that rotted, and was fixed rather than patched

`reports_test.dart`, "changing the period changes the figures", went red on its
own at midnight UTC on 2026-09-19. It asserted that the Today period shows one
180 peso coffee, and the seed's dates are the prototype's, fixed in September
2026. The entry it meant was dated 2026-09-18, which stopped being today.

Nothing to do with this change. Fixed by pinning the clock to the day the
fixture is written for, so the whole file is now deterministic instead of
passing for eleven days and then not.

## Not changed

No money behaviour. No engine was touched. Every figure on screen still comes
from a ported prototype engine locked to vectors generated by running the
prototype itself. The reconciliation `status` change is a WIRE spelling, not a
computation: `isBalanced` and its 0.01 tolerance are untouched.

Nothing was deleted. No migration runs, because there is no existing file
anywhere to migrate.

## Open, and needing the founder

### 1. Seed data becomes the user's data, permanently

This is the one real fork in this batch and it is not mine to call.

`app/` seeds eleven demo accounts holding 110,720.50 of liquid cash, a 385,000
Pag-IBIG housing loan, sixteen transactions, five debts, three goals and three
instalment plans. Somebody installs, taps the theme toggle, and that entire
fake ledger is now their saved file. They log real spending on top of it. Six
weeks later their net worth includes a mortgage they do not have, and nothing
on any screen says which rows are theirs.

Three ways out, in my order of preference:

1. **Never serialize the seed.** The seed ids are compile time constants, so a
   `Set<String>` of them can be excluded from every save, plus any sample row a
   real row references so nothing dangles. The fake data becomes structurally
   unable to reach the file. Roughly a day, and the question then disappears
   rather than being managed.
2. **Label it and offer one tap to clear it.** `"sample": true` on every seed
   row, one line on Home, a Settings control. Cheap. Because the seed is a
   compile time constant, clearing it is genuinely reversible, so it needs no
   scary confirmation.
3. **Ask once, at the first save.** Keep them or clear them.

Not urgent for the founder's own emulator testing, where the seed is what makes
the screens worth looking at. It is urgent before anybody else installs it.

### 2. `android:allowBackup` is unset, so it defaults to true

`app/android/app/src/main/AndroidManifest.xml` says nothing about it, which
means Android Auto Backup and device to device transfer are ON. The moment
`salapify_data.json` exists, a user's whole financial file is eligible for
upload to Google's servers.

Both directions need a decision:

- **For recovery** this may be the only second copy a real user ever has, since
  there is no export or restore UI yet, and Android deletes the file on
  uninstall.
- **For privacy**, `main.dart` currently states "Everything stays on the
  device. There is no account, no server and no network call anywhere in this
  app." That sentence becomes false, and Play's data safety form would have to
  declare it.

This is a security and privacy call, so it stops here by the working rules.
Nobody will notice it on their own, because the manifest says nothing at all.

### 3. Backup, export and restore UI do not exist

This change does not add them and did not claim to. Until they do, the only
copy of a user's financial life is one file in a private directory. Worth
saying plainly as the standing risk this batch does not close.

## Deferred, written down rather than done

- Academy lesson progress and the Accounts screen's collapsed state are widget
  state, outside `FinancialState`, so they are still not saved. The Academy
  screen says so.
- `payday` and `categories` still come from the seed rather than being stored.
  A file that carries them keeps them through the extras, so nothing is lost,
  but the app cannot yet change them.
- No lifecycle flush on `AppLifecycleState.paused`. The save is scheduled on a
  microtask rather than a timer, so the window is very small, but it is not
  zero.
