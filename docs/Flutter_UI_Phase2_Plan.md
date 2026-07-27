# Flutter UI Phase 2: the write path and the habit layer

Written before any Phase 2 code, the same discipline as Phase 1. Phase 1
(f2.53 and f2.57, confirmed on the phone) restructured navigation: five tabs,
Menu as a header action, one Log button, Home leading with Your Number, the
merged Utang tab, and the first accessibility guideline suite.

Phase 2 was scoped from two independent surveys run after Phase 1 shipped:

1. A full inventory of user-facing patterns the React Native app has that the
   Flutter app lacks. Its verdict: the analysis gap is closed (Insights is at
   or ahead of RN), and what remains is concentrated in the WRITE PATH and the
   HABIT LAYER, the things a daily user touches every day rather than reads
   once a week.
2. A ranked craftsman critique of the Flutter app as it stands. Its top
   finding was behavioral, not visual: the main Log sheet saves silently, no
   receipt, no Undo, while the Budget quick add already does both. The most
   used write path in the app is the one that breaks the house rule that
   monetary writes show what happened.

## Founder decisions (2026-07-27)

- **Pin the header on every tab.** Activity and Utang already pin; Home,
  Budget, and Insights let Menu scroll away, so the app was split down the
  middle. On Home only the 48dp key row pins and the greeting scrolls with
  content, which softens the height cost that kept this open during Phase 1.
- **Habit layer is in.** The 7-day logging chain, a real celebration when a
  debt or utang clears, and the treat card surfacing on Home.
- **The big builds are parked for Phase 3**: first-run onboarding, category
  management with per-category caps, and transfers between accounts. Each is
  phase-sized, and transfers add new money math that needs golden vectors.
  Phase 2 stays small, reviewable, and entirely over the air.
- Utang depth (person detail, one-tap Remind) and small settings (quick-add
  editor, currency) were offered and not selected; they stay on the backlog.

## What Phase 2 will NOT touch

No money calculation changes, no schema or migration changes, no new
packages, no new assets, no version bump. Every batch ships as a Shorebird
patch. Two batches (3 and 4) change what gets WRITTEN to the store through
existing store operations; both get flagged loudly in their pull requests and
batch 4 goes past the founder before merging, per the merge rules.

## The batches, in order

Each batch is its own branch push, pull request, merge, and delivery row.
Every batch: analyze zero issues, full test suite, new guards proven to fail
first, screens rendered and looked at dark first, stamp bumped.

### Batch 1: every log gets a receipt, and debts get one home (small)

- `log_sheet.dart` `_save()` shows the same snackbar the Budget quick add
  shows: "Label ₱X logged." with a 4 second Undo that removes the entry.
  Capture the messenger before the await, exactly like `budget.dart`.
- The Debts tile leaves Menu. Phase 1 made the Utang tab's "I owe" segment
  the canonical home of that content; two doors to two shapes of the same
  data is confusion. Bonus: the MONEY grid becomes 8 tiles, four clean rows.
- `onOpenPayables` callback added beside `onOpenReceivables`, wired through
  the shell; the Home check-in route `/debts` uses it instead of pushing a
  standalone DebtsScreen that strands the user with no bottom bar.
- Guards: a log save shows the receipt and Undo works; the `/debts` check-in
  lands on the Utang tab with TOTAL DEBT visible; Menu no longer lists Debts
  but DebtsScreen stays reachable nowhere (test asserts the tile count).

### Batch 2: pin the header on Home, Budget, and Insights (medium)

- Adopt the `money.dart` shape on the three scrolling tabs: header in a fixed
  Column, body in an Expanded ListView with its own controller. On Home the
  pinned band is the wordmark row (Search and Menu keys) only.
- No animation, so reduce motion is trivially respected. Tap targets are
  untouched.
- Guards: extend `header_action_test.dart` with a scrolled variant: after a
  deep scroll on each tab, the Menu key is still on screen at the same rect.
  The existing flush-edge test keeps holding.
- Risk to check by measuring, not assuming: the per-tab scroll position
  preservation from Phase 1 works through PrimaryScrollController on the
  shell; moving Home, Budget, and Insights to explicit controllers must keep
  scroll state surviving tab flips. The tab_state tests are the net here.

### Batch 3: log any day, and pick dates without typing ISO (medium)

- Log sheet gains a date chip row under the label field: Today (default),
  Yesterday, and Pick a date opening the themed `showDatePicker`. The chosen
  day flows into the existing `date` field; nothing about the transaction
  shape changes.
- The receipt from batch 1 then reports what really happened: "Groceries
  ₱250 logged for Jul 26." when backdated.
- The utang due date stops being a free-text ISO field: the three chips stay,
  the text field becomes read-only and opens the date picker on tap, writing
  the same YYYY-MM-DD string the store already expects, with a clear
  affordance for no due date.
- Flag in the PR: this changes what gets written (the date), through the
  existing field, with no computation change.
- Guards: a backdated log lands on the picked date in the store and the
  receipt names the day; the due date field cannot produce an invalid string.

### Batch 4: edit a logged entry without deleting it (medium to large)

- The RN app lets a user tap any history row and fix amount, label, date, or
  account, reversing the old ledger effect and applying the new one. Flutter
  is swipe-to-delete only, so a typo means delete and re-log, and for
  non-deletable rows means nothing at all.
- Port the behavior, not the code: read the RN EditSheet semantics first,
  design the store operation against them, and translate the relevant RN test
  vectors so the balance effects match to the centavo.
- This is the significant batch: it is a money-adjacent store operation.
  It goes past the founder before merging, with the design written out.
- Guards: editing an amount adjusts the account balance by exactly the
  difference; editing the account moves the effect between accounts; edits to
  non-deletable rows are either safely supported or clearly refused, matching
  RN.

### Batch 5: Insights reads in three bands (medium)

- After DO NEXT the screen is roughly ten equal-weight cards; the two
  always-on tools occupy two screenfuls whether or not the user came for
  them.
- Three labeled bands using the existing Kicker: DO NEXT (decisions, win,
  safe to spend), TOOLS (Afford, Windfall, and both what-ifs as collapsed
  one-line launcher rows expanding in place on tap, plain setState), THE
  BIGGER PICTURE (Spoken for, Health, Trend, Categories, Runway).
- No number moves, no computation changes, purely which pixels are open by
  default.
- Guards: every card still reachable; collapsed tools expand and their
  content matches the pre-band values; the a11y sweep covers the collapsed
  and expanded states.

### Batch 6: list polish sweep (small pieces, one batch)

- Activity date headers become human: extend `prettyDay` with a weekday so
  `2026-07-12` reads "Sat, Jul 12". Rows gain a muted context line from the
  already-computed `transactionNameMaps` ("GCash · Food").
- Kicker sweep: replace every hand-rolled uppercase label in budget.dart,
  utang.dart, log_sheet.dart, and history.dart with the shared Kicker or
  cardKickerStyle. One typographic voice; zero behavior change;
  golden-diff before merge.
- Budget's empty month stops being a void: an EmptyState when there are no
  category rows, and a small TODAY card listing today's entries (a filter,
  never a sum; arithmetic does not start living in screens).
- Home's THIS MONTH and MY MONEY cards become tappable: accounts open the
  Accounts screen, THIS MONTH switches to Activity. PressableScale, chevron,
  Semantics button, same as their siblings.

### Batch 7: the habit layer, a chain that never resets (medium)

- Port the RN WeekChain: seven dots for the last 7 days on Home, filled on
  days with a log, gold at 7 of 7, and the comeback line when yesterday was
  missed. Deliberately a chain, not a streak: nothing resets, which is the
  behavioral design the RN app already settled ("Walang reset dito" becomes
  an English-first line with the identity flavor kept only if it reads on its
  own).
- The celebration a cleared debt deserves: a small confetti overlay plus
  success haptic plus centred message, on both the debt and utang sides,
  reduce-motion aware exactly like RN (message and haptic survive, motion
  does not).
- The treat card surfaces on Home: the active treat with progress and a
  one-tap check-in, celebrate-colored when earned.
- Guards: the chain marks days from transactions correctly across month
  boundaries (pinned clock, the Phase 1 clock seam pattern); reduce motion
  suppresses the confetti but not the message; the treat card appears only
  when a treat is active.

## Test and verification plan

- Every new guard is broken once first, and the failure line goes in the
  commit message. Phase 1 proved this is not ceremony three times in one
  suite.
- The a11y guideline suite runs on every changed screen state, including
  Insights' new collapsed and expanded tool rows and the log sheet's date
  chips.
- Screens rendered and looked at before every merge, dark first, and the
  harness now wires the header chrome on every mount (the session 7 lesson).
  Batch 2 adds scrolled-state shots for the pinned headers.
- Delivery per batch: merge, watch docs/delivery-log.md, report the patch
  number, and no batch is called finished before its row exists.

## Phase 3 parking lot (founder-approved deferrals)

First-run onboarding, category management with per-category caps, transfers
between accounts (golden vectors required), person detail with statements and
one-tap Remind, quick-add editor, currency setting, net worth trend, year-end
tax screen and BIR filing dates (math already ported, screens missing), bank
brand badges, weekly recap share card, animated count-up numbers, a shared
haptic vocabulary with reduce-motion respect, and the three native-level
items that need a new APK: receipt photo with OCR, Android home-screen
widgets, and automatic backups to a synced folder.
