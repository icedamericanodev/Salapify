# UX Audit

Sprint 0 engineering audit, 2026-07-10. Reviewed as a product designer against
the actual screen code, not the pitch. No redesign performed; review only.

Baseline: 6 tabs (home, budget, debts, insights, tools, more), a global FAB
opening a shared LogSheet, and 29 non tab stack screens (9 of them
calculators). Effort scale: S under 1 day, M 1 to 3 days, L 1 to 2 weeks,
XL more than 2 weeks.

## Ranked findings

### UX-1: The heartbeat flow, logging a custom expense, does not meet the under 5 second bar

Severity: Critical | Effort: M
Where: mobile/components/LogSheet.js (lines 317 to 591)
What the code shows: the sheet stacks, in order: type toggle, When chips,
Quick add, category chips (full tree), free label input, Amount, a full
horizontal currency chip row rendered for every expense every time (lines 448
to 469), account chips, receipt button, then Cancel and Add. The Amount field
is the sixth block, has no autoFocus, and the Add button lives inside the
ScrollView, so with the keyboard up on a 6.1 inch phone the user must scroll
to reach Add. Quick adds are one tap and excellent, but any non preset amount
is realistically 4 to 6 taps plus a scroll.
Business impact: retention lives or dies on daily logging; every second here
compounds across the only habit the app monetizes.
Technical impact: reordering and pinning a footer bar is contained to one
component; the store API is untouched.
User impact: the most frequent action feels like filling a form, not flicking
a note.
Recommendation: Amount first with autofocus, category chips second, everything
else (currency, account, receipt, date) collapsed behind More options, and pin
Cancel and Add outside the ScrollView above the keyboard. Keep quick adds at
the top.

### UX-2: Home buries the daily answer under conditional cards, and always shows two utang cards even at zero

Severity: High | Effort: M
Where: mobile/app/(tabs)/index.js (render, lines 278 to 673)
What the code shows: up to 13 stacked cards: sweldo plan, coach card, Safe to
spend, Net worth, Cash flow, WeekChain, TreatCard, WeekRecap, People who owe
me, People I owe, Bills before sweldo, Days to payday, Quick links. Safe to
spend, explicitly the daily open number per the comment at line 410, can sit
below two full cards for 48 hours after every payday. The two utang cards
render even when the copy is "No one owes you right now" (lines 566 to 608),
which is pure noise for non utang users.
Business impact: the first screen is the brand; a long scroll of near equal
cards reads busy, not calm and trustworthy.
Technical impact: reordering and conditional rendering only.
User impact: the daily question, how much can I spend today, is not guaranteed
above the fold on a 6.1 inch phone.
Recommendation: Safe to spend always first. Collapse the sweldo plan to a slim
banner once step 1 is done. Hide the two utang cards when both are zero, or
merge them into one two column card. Cut the Quick links grid (see UX-9).

### UX-3: The utang model is split across three surfaces while the Debts tab shows only formal debts

Severity: High | Effort: L
Where: mobile/app/(tabs)/debts.js, mobile/app/receivables.js,
mobile/app/payables.js, mobile/app/person.js, mobile/app/split.js
What the code shows: the Debts tab has no link to receivables or payables.
Utang, the identity feature in the app's own description, is reached via home
cards, the More grid, or search. Split a bill is reachable only from inside
receivables (receivables.js line 462), three levels deep for the most share
worthy Gen Z flow in the app. Person ledgers are four taps from open.
Business impact: the differentiator (utang plus barkada splitting) is the
least discoverable core feature; the commodity feature (formal debt payoff)
owns the tab.
Technical impact: a segmented Debts tab (Loans and cards / People owe me /
I owe) is mostly composition of existing screens.
User impact: users hold two mental models, Debts and people utang, that the
product treats as one concept everywhere else (net worth, Pan, search).
Recommendation: make the Debts tab the single money owed home with three
segments, promote Split to a visible action there, and let the home cards deep
link into it.

### UX-4: The debt add and edit modal is a mega form; paying a debt is buried inside editing one

Severity: High | Effort: M
Where: mobile/app/(tabs)/debts.js (modal, lines 417 to 650)
What the code shows: one sheet holds 9 input fields (4 card only), the payment
logger, Paid from chips, Mark paid off, the SOA forecast, and pending
payments. The frequent monthly action, logging a payment, requires opening the
full edit form and scrolling past Name, Type, Balance, Rate, and Min payment
first. The money math underneath (splitDebtPayment, pending card posts,
double tap guards) is genuinely excellent; the container is the problem.
Business impact: monthly payment logging is the retention loop for the debt
persona; friction here erodes it.
User impact: editing the Remaining field while the Log payment box sits below
it invites which number is real confusion, even though the code defends
against it (line 249 comment).
Recommendation: split into a debt detail screen (balance, SOA forecast, Log
payment as the primary bottom action) with Edit details behind a secondary
tap. Keep the math exactly as is.
Technical impact: new route plus moving existing JSX; the store calls are
already isolated.

### UX-5: Dates are typed as YYYY-MM-DD text in every flow

Severity: Medium | Effort: M
Where: mobile/components/LogSheet.js (line 366, Another day),
mobile/app/receivables.js (due date, validated at line 146),
mobile/app/goals.js (targetDate, not validated at all in save(), lines 47 to
57)
What the code shows: validation and error copy are good in LogSheet and
receivables (real calendar check, future check). Goals accepts any string
silently; a typo just silently kills the Save X a month line (line 95).
Receivables mitigates with quick date chips, LogSheet and goals do not.
Business impact: backdating is the fix for the number one honesty problem (I
forgot to log for two days); a typed ISO date is a power user pattern, not a
Gen Z one.
User impact: ten plus keystrokes with format anxiety, on a numeric task.
Recommendation: a simple chip calendar (last 14 days) covers 95 percent of
backdating; a month and year wheel for goal dates. Validate goal targetDate on
save.

### UX-6: The Debts tab reads as an alarm: warning red on every number, and it skipped the Card and SectionHeader migration

Severity: Medium | Effort: S
Where: mobile/app/(tabs)/debts.js styles: totalDebt (line 703),
sectionSubtotal (line 727), rowAmount (line 733) all use colors.warning; the
screen builds its own card, cardPad, and Group header instead of the shared
Card and SectionHeader used by home, budget, and receivables.
What the code shows: theme.js states the rule itself, warning is reserved for
debt and over limit states, but painting the headline, every subtotal, and
every row amount crimson means red is the default state of an entire tab, so
it stops meaning anything, and it shames the exact user the app exists for.
Business impact: a finance app that makes its core persona feel judged loses
them; calm is the brand promise.
Technical impact: color swaps plus adopting the shared components; zero logic
change.
User impact: no visual difference between a healthy on schedule loan and a
blown due date.
Recommendation: balances in colors.text, warning only for overdue, over limit,
or interest not covered states. Migrate the screen to Card and SectionHeader
to close the style drift.

### UX-7: Selection chips across the app are about 32 to 34 points tall, under the 44 point target

Severity: Medium | Effort: S
Where: chip styles with paddingVertical spacing.sm (8) plus 13 point text:
mobile/components/LogSheet.js line 664, mobile/app/(tabs)/debts.js line 743,
mobile/app/(tabs)/index.js line 911, receivables and preferences equivalents.
No hitSlop on these (hitSlop is used well elsewhere, for example the budget
trash icons).
Business impact: mis taps in the money entry path on mid range Androids
translate directly into wrong data and lost trust.
User impact: category, account, and currency picking, the highest frequency
taps after the FAB, are the smallest targets in the app.
Recommendation: minHeight 44 on the shared chip pattern, and ideally extract
one Chip component; the style is copy pasted in at least six files.

### UX-8: Sample data mode has no persistent indicator after Explore the sample data first

Severity: Medium | Effort: S
Where: mobile/components/Onboarding.js (lines 193 to 199), sample seeds in
mobile/context/AppData.js (line 46 onward); SAMPLE_TX_IDS already exists in
mobile/lib/sampleData.js and is used by budget.js line 78.
What the code shows: onboarding warns once (clear it before you add real
entries), then nothing on any screen says fake numbers are still mixed in. The
machinery to detect sample rows exists.
Business impact: a user whose net worth headline is part fiction on day three
deletes the app for wrong math, not for the real reason.
Recommendation: a dismissible home banner while sample IDs remain: Sample data
is still in your totals, Clear it, linking to /data. One tap clear that
removes only sample IDs.
User impact: protects the single most important trust moment, the first real
net worth number.

### UX-9: Home Quick links duplicate the tab bar; More grid duplicates home

Severity: Low | Effort: S
Where: mobile/app/(tabs)/index.js lines 271 to 276 (Debts, Budget, Insights
tiles link to tabs one tap away in the bar); mobile/app/(tabs)/more.js
MONEY_LINKS includes Search (already in the home header) and receivables and
payables (already home cards).
Impact: every duplicate is a decision the user must re make; it pads scroll
length. Business: perceived bloat. User: thinking count. Technical: trivial
removal.
Recommendation: on home keep only Accounts (the one link with no tab). In
More, drop the Search tile.

### UX-10: Two different income logging UIs exist: the sweldo modal and LogSheet

Severity: Low | Effort: S
Where: mobile/app/(tabs)/index.js salary modal (lines 676 to 729) versus
mobile/components/LogSheet.js income mode.
Impact: two forms to maintain and two behaviors to learn; the salary modal
lacks the date row and the celebration toast, so payday logging feels flatter
than a coffee log. User: inconsistent reward. Technical: duplicated chips and
validation code.
Recommendation: open LogSheet preset to income with label Salary from the
sweldo plan, delete the bespoke modal.

### UX-11: Categories management and Earn your treats are buried under Preferences

Severity: Low | Effort: S
Where: mobile/app/preferences.js lines 150 to 157.
Impact: users who want to edit categories will look where they use them
(LogSheet, Budget), not under More then Preferences. User: dead end searching.
Business: caps are a Pro feature, hiding their editor hides the upsell.
Recommendation: an Edit categories link at the end of the category chip row in
LogSheet and in Budget's Where it went card.

### UX-12: Long money strings and toasts truncate rather than wrap

Severity: Low | Effort: S
Where: mobile/components/LogSheet.js line 607, toast text is numberOfLines 1,
so a long label plus amount clips exactly where the amount is. Home net worth
is handled well (manual font stepping plus maxFontSizeMultiplier, index.js
line 471), but that careful pattern exists only there; totalDebt in debts.js
and payday amounts on home have no adjustsFontSizeToFit.
Recommendation: two line toasts; add numberOfLines 1 with adjustsFontSizeToFit
to the remaining hero amounts.

### UX-13: Scope: 6 tabs plus 29 stack screens is at the edge of coherent, and the Tools tab is the stretch

Severity: Medium (strategic) | Effort: XL to fix wrongly, S to fix cheaply
Where: mobile/app/(tabs)/tools.js (9 calculators), plus learn, mindset, notes,
treats, reports, recurring, pan.
What holds it together: everything is genuinely PH money themed, well written,
and offline. The calculators (13th month, SSS, PhilHealth, Pag-IBIG, BIR
dates) are strong acquisition hooks with seasonal spikes.
What does not: tools are occasional use (yearly or one time) yet own a
permanent top level tab, while the daily and weekly utang ledger does not (see
UX-3). Learn, mindset, notes, and treats have no shared home, so the More grid
absorbs everything, which is where features go to be forgotten.
Business impact: for due diligence, the risk is not the code (each screen is
self contained), it is positioning: the app currently presents as budget
tracker plus debt payoff plus utang ledger plus tax suite plus lessons plus a
chatbot, which muddies the store listing and the first session.
Recommendation: do not delete anything in Sprint 0. Instrument screen opens
first (no analytics exist, consistent with the privacy stance, so even a local
counter surfaced in feedback would help), then decide whether Tools trades its
tab slot with a unified Debts and Utang tab.

### UX-14: ErrorBoundary and load failure screens are hardcoded to the dark palette

Severity: Low | Effort: S
Where: mobile/components/ErrorBoundary.js lines 58 to 73.
Impact: a light mode user who hits a crash gets a sudden orange on espresso
screen. Defensible (the theme context may be the thing that crashed) but a
static light and dark pair keyed off the OS scheme would look intentional.
Everything else passes the theme discipline check: the only hardcoded colors
in mobile/app are the receipt viewer's near black overlay and white text
(correct for photo viewing) and the save failure banner text.

## UX strengths (genuinely above average for this stage)

1. Theme system discipline. Eight palettes, light and dark each, WCAG AA
   documented per pairing, a written red is reserved rule, CVD validated chart
   colors with fixed slot order (mobile/theme.js). Near zero color drift in
   screens.
2. Undo everywhere money moves. Log toast with Undo, delete with Undo restore,
   double tap guards on every mutating path (LogSheet, budget.js, debts.js
   payBusy, receivables saveBusy). Calm and trustworthy in the mechanical
   sense.
3. Money math integrity comments. The code explains why each financial edge
   case is handled (overpay never debits cash, interest split, sample utang
   never seeded as overdue, stale FX table guard in LogSheet lines 78 to 84).
4. Quick adds plus remembered defaults. One tap logging of the top four PH
   spends (Food 150, Transport 50, Coffee 120, Load 100) seeded by default,
   with account and category auto attached; the true fast path is 2 taps from
   any tab.
5. First run habit engineering. firstLogPrompt opens the add sheet once after
   onboarding (tabs _layout.js lines 34 to 40), the day one recap fires at the
   third log, the WeekChain rewards streaks. The habit loop is designed, not
   accidental.
6. Honest, local microcopy. "Bukas na.", "A plan, not a transfer. Nothing
   moves out of your accounts.", equal weight No thanks on the notification
   ask. Playful without lying about money.
7. Empty states are consistently intentional, with a shared component and
   actionable templates (Goals offers Emergency, Pasko, Travel funds
   prefilled).
8. Failure states exist: an unreadable data screen that deletes nothing, a
   save failure banner that only appears when silence would cost data,
   ErrorBoundary, a dead receipt explanation in the viewer.
9. Share worthy moments are built: WeekRecap, RecapShare card, debt payoff
   Celebration, SOA share, polite utang reminder share.
10. One handed use is mostly respected: FAB bottom right, sheets bottom
    anchored, keyboard lift handled correctly on Android edge to edge
    (SheetOverlay, pan.js).

## Fix order

LogSheet speed (UX-1), home hierarchy (UX-2), utang navigation (UX-3), debt
payment flow (UX-4). Those four changes touch four files, none touch the data
schema, and together they move the product from impressively engineered to
fast where it counts. Everything else on the list is polish that can ride
along in normal batches.
