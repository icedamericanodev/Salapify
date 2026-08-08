# Salapify UI/UX Overhaul, Phase 4: Implementation Report

Money management. Date: 2026-08-08. Status: implemented, tested, visually
validated, documented. Per the stop condition, no Phase 5 work (Insights,
Reports, Pan, Money Courses, Tools redesign) was started.

Phase 4 shipped as five over-the-air patches, each with QA row, green Flutter
check, merge commit, and a delivery row (the log is the authority; the last
two rows land when their publisher runs finish):

| Stamp | Patch | Batch |
|---|---|---|
| f3.85 | 78 | The Activity ledger |
| f3.86 | 79 | The receipt, and money writes felt in the hand |
| f3.87 | 80 | Budget answers "am I safe" |
| f3.88 | (publisher) | Accounts says own vs owe |
| f3.89 | (publisher) | Honest debt words |

## Screens Redesigned

history.dart (Activity), edit_sheet.dart (the receipt, new), budget.dart,
accounts.dart, account_detail.dart, debts.dart, goals.dart, goal_detail.dart
(haptic), utang.dart (copy), and the shared widgets bank_card.dart,
flip_bank_card.dart, period_selector.dart, plus one additive engine function
in money/budget.dart.

## Before vs After

Activity was a card per transaction (six rows and twelve borders per screen)
whose tap dropped a reader into an edit form; it is now a ledger (one card
per day, hairline dividers, roughly twice the rows) whose tap opens a
receipt, with Edit one tap deeper and Delete reachable without a swipe.
Budget headlined what you spent; it now headlines what is LEFT, warns in
words at 85 percent, and names the biggest category when over. Accounts
showed a savings account's stored digits unmasked on the card front while
auth-gating the same digits everywhere else, drew fake card numbers on
wallets, and painted every debt red; the front now shows dots only, wallets
wear no card furniture, and WHAT YOU OWN / WHAT YOU OWE structure replaced
tint. The loan rate field never said which convention it charged; it now
names diminishing-balance and warns about quoted add-on rates, the costliest
ambiguity the review found.

## Accounts System

Cash: the content-height accent tile with a wallet emblem, deliberately not a
payment card (the banking specialist confirmed the existing treatment and it
was kept), now a named semantics button. Banks: brand-color card in the deck
(dots only on the front), compact monogram rows in the sections. E-wallets:
brand color and corner label only, no chip, no contactless, no fabricated
PAN. Credit cards: YOU OWE kicker (was OUTSTANDING), utilization bar with a
semantics name and a "Getting full" warning in words at 70 percent, proven
quiet below it. Investments and property: monogram rows under their own
sections. Liabilities: neutral ink rows under WHAT YOU OWE; red stays on the
Total owed summary. Foreign accounts keep their own symbol with the converted
equivalent beside them.

## Activity System

Row structure: label + context line ("GCash · Food") left, AmountText row
face right with real sign grammar (minus for out, explicit plus for in,
unsigned muted for a move). Grouping: day headers outside one card per day.
A money move names its ends ("From GCash to BPI Savings") from its own
account ids and titles itself with its capitalized type instead of sanitize's
"Entry" filler. Search and filters kept the shared chips from Phase 3;
period-step arrows now click. The row's semantics speak the whole row.
Transfer treatment in the receipt: From and To fact rows, and the read-only
explanation preserved for every locked class. Swipe-delete lands with the
money-written buzz; the receipt's Delete goes through the same engine path
with the same Undo.

## Budgets

Hierarchy: remaining is the hero ("₱11,623.75 left this month"), spent-of-
limit is the caption, and a daily pace sentence closes it ("About ₱484 a day
until the end of the month", computed by the new engine function dailyRoom,
rounded because it hedges). States: healthy / "Getting close." at 85 percent
/ "₱850 over your limit" with the biggest category named as the next cut.
No shaming language anywhere ("No shame" itself was removed for naming the
emotion; "keep you honest" became "show what is left"). Quick-add receipts
state the new remaining after every tap, and the chips warn screen readers
that activating them writes money.

## Goals / Savings

The overlap was resolved with vocabulary, not model changes: the Goals
summary now says "This money stays in your accounts; goals just earmark it."
Goal progress grammar (X of Y, left line, pace, target) was already the
shared system and was left intact; contributions now land with the
money-written buzz except when the milestone celebration carries its own.
The completed-goals section, milestone dots, and celebration were reviewed
and found already deliberate.

## Card Reduction

Activity: from a card per transaction to a card per day (the largest single
container reduction in the app). The receipt replaced a full form for the
reading intent. No new cards were introduced anywhere in the phase.

## Typography Drift

The type ratchet tightened again (accounts.dart 8 to 6). amountRow forks
killed this phase: history's w6, accounts' 16pt mini stats and 13pt
subtotals; history.dart joined amount_face_test's cleaned list. Remaining
Phase 4-surface forks are in debts.dart, cashflow.dart, recurring.dart, and
notes.dart (deferred with the screens that own them, listed below); the
roughly fifteen others live on Phase 5+ screens.

## Currency Validation

Tested: PHP base throughout; the USD foreign account on the lived-in fixture
renders "$1,200.00" with "~ ₱67,800" beside it in the sections, ranks by its
converted value in Home's preview (the Phase 3 fix, still guarded), and the
Accounts summary carries the manual-rate provenance sentence. Conversion
stays entirely in the engines; no FX logic was touched.

## Fable Review

Before shots: the harness's 93-shot set from earlier the same day (accounts
carousel with digits showing, card-per-transaction Activity, spent-first
Budget). After shots, all dark on the lived-in fixture and sent to the
founder in the conversation as each batch shipped: the Activity ledger, the
receipt, Budget safe-first (re-rendered after the rounding guard caught
centavos under "about"), the masked deck, and the own/owe sections. Real
defects the review or its guards caught in session: the credit face's 9px
overflow inside its fixed design box, the "about + centavos" contradiction,
and sanitize's "Entry" filler surfacing as a title.

## Accessibility

Machine matrix: every main tab at 1.2x and 2.0x text on 390dp and at 1.0x
and 1.3x on a 320dp compact phone, zero layout exceptions, on the final
tree (validation_sweep.dart), plus the permanent 1.0x/1.5x sweep every push.
Semantics landed: whole-sentence Activity rows (label, direction, amount,
destination), the receipt's reachable Delete (the swipe-only P0), liveRegion
on debt payment results, the cash tile as a named button, "Card number
hidden here" instead of digits spoken aloud, utilization named with words
beside it, quick-add chips warning they write money. Amounts scale down
instead of truncating on the two summary surfaces. Card small labels went
opaque for AA.

## Performance

The Activity ledger REDUCED per-row cost (one Card and one border set per
day instead of per row). No new images; card gradients remain computed.
Budget rows keep their identity keys from Phase 3, so re-sorts move rows
instead of re-animating bars. No animation was added beyond the existing
token set. The 2800-test suite runtime was unchanged (about 5 minutes).

## Test Results

Full suite on the final tree: 2819 tests green (from 2801 pre-phase), zero
analyzer issues, warnings fatal on the runner. New guard suites:
activity_ledger_test (4), receipt_test (3), accounts_own_owe_test (4),
debt_words_test (1), three budget state guards plus five dailyRoom vectors.
Every guard was broken and watched fail with the failure line recorded,
restored only after the run reported. The panel: six specialist reviews
(product design, banking, personal finance product, accessibility, motion,
UX writing) drove the batch plan; their reports are summarized in the
conversation and their P0s are all closed except those listed below.

## Deferred Issues (for Phases 5-8)

1. Log-sheet category capture (the audit's P0-1): an additive optional
   categoryId write on the fastest path. Deliberately NOT slipped into a
   design phase; it touches the write path and belongs in its own batch
   through the data-migration review lane.
2. Transfer sheet dialect: theme chrome, shared chips, a direction glyph
   between From and To (motion finding 8; the haptic half landed).
3. Debt rows' next-due date and the card detail's minimum payment (the
   engine already computes both; presentation wiring remains).
4. Over-limit credit relabel ("Over limit by ₱X" instead of a clamped ₱0
   available), and an availableCredit engine function to end the duplicated
   widget subtraction.
5. Goals FOCUS card visible treatment plus its engine-derived reason
   sentence; "Overdue" to "Past its date" (an engine label string).
6. Carousel dot semantics and animation, detail-panel crossfade, search
   reveal fade, card flip onto Motion tokens (motion findings 5-7).
7. Budget limit dialog income-anchored helper; goal contribution note field
   (needs a one-parameter store extension); sweldo-cycle pace phrasing.
8. Remaining amountRow forks: debts, cashflow, recurring, notes, search,
   utang, tax and salary calculators, section.dart, bank_card.dart.
9. Loan progress bars stay impossible honestly (no principal or term is
   stored); do not synthesize one.
10. Form labelText adoption on the account form; USD-rate button tap
    target; period selector two-line wrap at 390dp (accepted for now).
11. Golden coverage additions for accounts-mixed, budget-exceeded, and
    goal-completed states as permanent harness entries.

Phase 4 ends here.
