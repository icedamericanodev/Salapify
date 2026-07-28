# Flutter Phase 3: the first run, and the last big gaps

Written before any Phase 3 code, the discipline Phases 1 and 2 kept. Phase 2
closed with f2.66 patch 16 confirmed on the phone; this phase turns to what
decides whether a stranger who installs from Play becomes a user, and to the
few remaining structural gaps against the RN app.

The sequence came from the roadmap arbiter reading the actual code, and the
reading changed the picture from the earlier survey:

- Transfers are much smaller than billed. The RN math is two centavo-rounded
  balance writes plus one type transfer record, and everything downstream in
  Flutter (backup normalization, the chain, commitments, search, history,
  the edit gate) already handles or skips transfers. Only the write op and
  the modal are new.
- Category caps need no schema work: backup.dart already carries monthlyCap,
  parentId and icon per category, and Budget's cap meter already renders.
  The management screen is the only missing piece, and today the cap code is
  dead for Flutter-only users.
- The year-end tax and BIR deadline math is already golden locked (phtax,
  phcalendar); those are screens and Tools tiles only.
- The currency setting is not a standalone small: formatMoney and
  formatMoneyText hardcode the peso, so the onboarding currency pick cannot
  exist until they read a stored currency. It is batch 1 of onboarding.

## Founder decisions (2026-07-28)

- **Onboarding first.** Every pre-onboarding install is a first impression
  never recovered; everything else on the board improves an app a new user
  has already decided to keep.
- **Category delete moves entries to a chosen category.** Never silently
  dropped. This decision was taken here, before the batch, because deletion
  reassigns user data and that call is never delegated.
- **Sample-or-empty stays in onboarding.** Sample rows are tagged so they
  never count in the logging chain and are removable in one tap.
- **Cut from Phase 3 entirely** (stay on the backlog): net worth trend, bank
  brand badges (image assets cannot ship over the air, so they would spend a
  base APK install on decoration), the weekly recap variant, count-up
  animations and the haptic vocabulary.

## What Phase 3 will NOT touch

No pubspec bump anywhere in the sequence: every batch is pure Dart and ships
as a Shorebird patch. No existing money math changes; transfers ADD an
operation under the golden-vector contract. The three native-level parked
items (receipt OCR, home-screen widgets, automatic backups) stay parked.

## The batches, in order

Same rhythm as Phase 2: one batch, one PR, one patch, analyze clean, full
suite green, new guards proven failing first, changed screens rendered and
looked at dark first, stamp bumped with an asserted script, delivery
confirmed by the row.

### Batch 1: the currency setting (small)

- formatMoney and debtmath's formatMoneyText read a stored currency symbol,
  resolved once from settings on load and change, the Barako.current
  pattern. Default stays the peso, so every existing test and every existing
  user sees zero change.
- A currency row in Menu (the RN list: PHP, USD, EUR, SGD and the rest),
  writing settings.currency and settings.currencyCode, the RN keys, so
  backups round-trip with the RN app.
- Guards: a non-peso setting reflows a rendered amount; a backup written
  with a currency set re-imports to the same symbol; the default-peso path
  is bit-identical to today.

### Batch 2: the onboarding flow (large, SIGNIFICANT)

- First run only: what Salapify is (offline, free, no ads), the currency
  pick (batch 1's setting), an optional monthly budget, then the
  sample-or-empty choice, then straight into the log sheet so the first
  session produces a real entry. Skippable at every step.
- First-run state is a stored flag, which is schema-adjacent, and the sample
  seed CREATES user data: this batch is presented to the founder before
  merging, per the merge rules.
- Sample rows carry a marker id prefix; the chain already counts only real
  entries by the RN rule, and a one-tap "remove sample data" undoes the
  seed exactly.
- Existing users must never see the flow: the flag derives as already-set
  when any real data exists.

### Batch 3: the notification opt-in step (small, SIGNIFICANT)

- The nightly log nudge ask joins onboarding, last, because the flow works
  without it. Notifications scheduling is a significant category; the
  founder is told what changed at merge.

### Batch 4: transfers between accounts (small, SIGNIFICANT)

- Golden vectors FIRST, translated from the RN saveTransfer semantics: two
  centavo-rounded balance writes, one type transfer record with flow legs,
  overdraft blocked, budget and cash flow untouched.
- Then store.transfer and the modal on Accounts, replacing the fake
  expense-income pair workaround that pollutes Budget and cash flow today.

### Batch 5: category management with caps (medium, FOUNDER GATED)

- Add, rename, re-icon categories; set or clear a monthly cap feeding the
  meter Budget already renders; delete asks where the entries go and moves
  them, the founder's decision above.
- Deletion reassigns user data, so this batch goes to the founder before
  merging, never delegated.

### Batch 6: the tax check and BIR dates screens (small)

- Year-end refund-or-owe over phtax's already-locked withheld vs annual
  figures, and the filing calendar over phcalendar. Two screens, two Tools
  tiles, no new math.

### The tail, in order

- Utang person depth: payment history with a running total, a contact note,
  a plain-text statement of account via the share sheet, and a one-tap
  polite Remind in English or Tagalog.
- The period selector on Activity and Insights: month, year, custom range,
  all time.
- The quick-add editor: settings.quickAdds already round-trips; only the
  editor is missing.

## Test and verification plan

Everything Phase 2 proved out carries forward: the clock seam for any
date-sensitive fixture, seeded shots for any change the empty-seed renders
cannot see, both halves proven for anything that fires conditionally, and
the three-command delivery check after every merge. Batch 4 adds a golden
vector file for transfers before the store op exists, the porting rule.
