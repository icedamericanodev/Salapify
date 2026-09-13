# Salapify full app review, 2026-08-07

A brutally honest, evidence-based review of the Salapify Flutter app
(`flutter/lib`), run as a multi-agent product review. Every finding below
references a real file. This document is review only. No app code was changed
to produce it.

## Who reviewed what

Step 0 asked for six reviewer personas. Four were expected to already exist
under the names Morgan, Sam, Nova, and Quinn. They do NOT exist under those
names in this repo, but functional equivalents do, so each step was run by the
closest existing agent, and the three genuinely missing personas were created
as new agent files before the review started.

| Persona (as named in the brief) | Role | Ran by | New file created? |
|---|---|---|---|
| Morgan | Feature and product review | `product-manager` | No, equivalent existed |
| Sam | UX and flow review | `flutter-ux-craftsman` | No, equivalent existed |
| Quinn | Money math integrity and QA | `qa-tester` | No, equivalent existed |
| Nova | Architecture and code review | folded into Quinn and Morgan | No, equivalent existed |
| Riley | Competitor UX benchmarker | new `riley-competitor-ux` | Yes, created |
| Isla | Financial literacy content strategist | new `isla-literacy-content` | Yes, created |
| Kai | Motion and interaction designer | new `kai-motion-interaction` | Yes, created |

The three created files live in `.claude/agents/riley-competitor-ux.md`,
`.claude/agents/isla-literacy-content.md`, and
`.claude/agents/kai-motion-interaction.md`.

---

## 1. Executive summary

**Overall app score: 7.5 / 10.**

Salapify is not a skeleton. It is a mature, genuinely built finance app whose
foundations are stronger than most of its named competitors. The money engines
in `flutter/lib/money` are ported 1:1 from the React Native app and pinned to
the centavo by a large golden-vector suite (260 test files in `flutter/test`).
The design system is disciplined and, in dark mode, best in class. The coaching
and lessons layer is more actionable than Spendee, Monefy, or Money Manager and
closer in spirit to YNAB. The core log loop is fast (2 taps plus typing to log
an expense, under the 3-tap bar).

What holds it back from an 8 or 9 is a small number of real defects and one
systemic capture gap, not a shortage of features. The single most important
structural problem is that the app never captures a structured category at log
time, which quietly starves its own excellent analytics. There is one genuine
Critical money bug (foreign-currency balances summed as base currency in two
engines). Three core journeys have a break that a user would feel: recurring
bills never notify, transfers confirm nothing, and there is no shared month, so
different screens silently disagree about which month they are showing.

### The 5 most important findings

1. **CRITICAL money bug: two engines mix currencies.**
   `emergencyRunway` and `healthScore` in
   `flutter/lib/money/analytics.dart` sum every account balance as if it were
   base currency, ignoring `currencyCode`. The correctly scoped
   `commitments.safeToSpend` excludes foreign accounts, so the same data blob
   produces two disagreeing cash figures. This poisons the runway, health
   score, afford check, windfall split, and "where your next peso goes". (Q1)

2. **Category is never captured at log time, so the app starves its own
   analytics.** The Log sheet writes no `categoryId`
   (`flutter/lib/screens/log_sheet.dart`), so an expense typed "Jollibee"
   never moves a "Food" category cap, and category grouping depends on the
   user retyping the same word every time. Three reviewers hit this
   independently, from flow, from competitors, and from content quality. (S1,
   R1, R2)

3. **Recurring bills never notify.** `plannedReminders`
   (`flutter/lib/money/reminders.dart`) reads `data['debts']` only and never
   `data['recurring']`, so a recurring rent or Netflix bill produces zero
   reminders even though the screen promises "Salapify logs it every month on
   its day". (S4)

4. **Transfers confirm nothing.** A successful account-to-account transfer
   just pops the sheet with no receipt
   (`flutter/lib/screens/accounts.dart`), while every other money write shows
   a receipt with Undo. Moving ten thousand pesos, the largest single-tap
   money move in the app, gives no feedback, breaking the house rule against
   silent success. (S5)

5. **No shared selected month.** Home, Budget, and Insights are hardwired to
   today, while History and Reports each own a separate, differently capped
   month state. Stepping one back a month changes nothing on the others, so
   the surfaces silently disagree. (S3)

### What is genuinely excellent (specific and earned)

- The dark palette system (`flutter/lib/theme.dart`, 8 themes times light and
  dark, every text-on-surface pair machine-checked to WCAG AA in
  `test/palette_contrast_test.dart`) beats every named built-in tracker and is
  competitive with Revolut and Copilot.
- The golden-vector money suite genuinely contains the double-vs-decimal risk:
  Flutter is byte-locked to the RN app so a rounding case like 2.675 cannot
  drift between the two. Quinn found only three exceptions in the whole
  `money/` folder.
- The coaching logic (`flutter/lib/money/coach.dart`, the next-peso order rail
  in `flutter/lib/screens/insights.dart`, `flutter/lib/money/lesson_insight.dart`)
  is real, peso-specific coaching that gets debt-before-goal order of
  operations correct in plain words.
- The interaction layer is more alive than expected: a real swipe-to-delete
  with Undo (`flutter/lib/screens/history.dart`), a wallet-style card carousel
  with a true 3D flip and haptics
  (`flutter/lib/widgets/flip_bank_card.dart`), a confetti celebration wired to
  real wins (`flutter/lib/widgets/celebration.dart`), and a mascot whose mood
  is genuinely event-driven, not random (`flutter/lib/money/pan_mood.dart`).

---

## 2. Findings table

Severity key: Critical, High, Medium, Low. Per the review convention, money
math correctness defects are treated as Critical. Display-only divergences on
money are graded on their real user impact.

| ID | Agent | Severity | Feature / screen | Finding | Recommendation |
|---|---|---|---|---|---|
| Q1 | Quinn | Critical | Insights runway, health score | `emergencyRunway` (`analytics.dart:392-398`) and `healthScore` (`analytics.dart:467-475`) sum `accounts[].balance` with no currency check, so a foreign account is counted at face value in a base-currency total. `safeToSpend` excludes it, so two screens disagree. Poisons afford, windfall, surplus, runway, health. | Gate both loops through `inBaseCurrency(a, baseCurrencyOf(data))` exactly as `statements.netWorthParts` does. Add foreign-exclusion golden vectors for both. |
| Q2 | Quinn | High | Money formatter | `formatMoney` (`format.dart:118`) takes the sign from the raw input but rounds the magnitude, so any value in (-0.005, 0) prints "-₱0". `formatMoneyText` derives the sign from the rounded value and does not, so the two formatters disagree on the same number. | Compute the sign from the rounded value, or drop the sign when `whole == 0 && cents == 0`. Add a sub-centavo-negative vector to `about_money_rounding_test.dart`. |
| Q3 | Quinn | Low | Budget card | `budgetSummary` (`budget.dart:33-63`) accepts a negative stored `monthlyLimit`, making remaining, pct, and over all nonsense. Reachable only via a hand-edited backup. | Floor `baseLimit` at 0 in `budgetSummary`, and clamp `monthlyLimit` on import in the store. |
| S1 | Sam | High | Log sheet, categories | Log sheet writes no `categoryId` (`log_sheet.dart:149-156`), so `spentByCategory` (`categories.dart:143`) only counts an entry when the label exactly equals the category name. User-named category caps read 0 for everything logged through the main button while Budget shows the spend. | Add an optional category chip row to the Log sheet (reuse the account-chip `Wrap` at `log_sheet.dart:290-301`), writing `categoryId` into the tx map. Do not touch the golden-locked label-fallback math. |
| S2 | Sam | Medium | Edit sheet, categories | Edit cannot set a category either (`edit_sheet.dart` patch handles amount, type, account, date only), so nothing in normal use ever tags a category. The only tagging surface is bulk recategorize in `categories.dart:81`. | Add the same category chip to the edit sheet once S1 lands, so per-entry tagging exists on both write paths. |
| S3 | Sam | High | Home, Budget, Insights, History, Reports | No global selected month. History (`history.dart:132`) and Reports (`reports.dart:64-79`) own separate, differently capped month states; Home, Budget (`budget.dart:33`), and Insights (`insights.dart:239`) are hardwired to today. The surfaces silently disagree. | Short term: unify Reports and History arrow-stepping on `money/period.dart` `shiftPeriod` with one cap. Then lift a shared `Period` to the shell and give Budget and Insights a `PeriodSelector`. |
| S4 | Sam | High | Recurring bills, notifications | `plannedReminders` (`reminders.dart:198-231`) reads `data['debts']` only, never `data['recurring']`, so recurring bills never notify despite the screen promising they will. | Add a recurring branch that emits "due in 3 days" and "due today" reminders per item from `dayOfMonth`, mirroring the debt branch, keeping names and amounts out of the title per the privacy contract. |
| S5 | Sam | High | Account transfer | A successful transfer calls `Navigator.pop()` with no snackbar (`accounts.dart:1869`), unlike every other money write. The largest single-tap money move confirms nothing. | Show a receipt snackbar ("Moved ₱X from A to B") before the pop. Undo is not available here (transfer delete does not reverse balances, by design), so the receipt is the minimum honest feedback. |
| S6 | Sam | Medium | Recurring reschedule | Adding, editing, or deleting a recurring item does not reschedule notifications (`store.dart:2005/2038`, `recurring.dart:406-445`); new reminders stay dark until the next app resume. | Call `Reminders.reschedule(store.data, DateTime.now())` after a successful add, edit, or delete, the pattern `notifications_security.dart:78` already uses. |
| S7 | Sam | Low | Log income, payday | No "allocate income to budget" surface exists; the Payday distribution ritual (`payday.dart`) is unreachable from the Log income flow, so a user who logs salary via Log never discovers it. | Add a one-line "Just got paid? Plan it" link on the income variant of the Log sheet, routing to Payday. |
| R1 | Riley | High | Add transaction | No category grid and no in-app keypad (`log_sheet.dart:227-329`). Logging relies on the OS decimal keyboard and a free-text label. Monefy logs in about 3 taps with a category tile plus a custom keypad. | Add a category chip row (pairs with S1) and a code-drawn 12-key `GridView` keypad of `PressableScale` keys writing into `amountController`. Pure Dart, ships over the air. |
| R2 | Riley | High | Insights composition | Spending categories are derived from a free-text label, not captured (`insights.dart:1298`), so analytics quality is downstream of a field the log sheet never collects. | Same fix as S1 and R1. Once a category id is captured, point `categoryVsAverage` at it instead of the label string. If the schema needs a new field, flag it to the founder as a significant change before merging. |
| R3 | Riley | Medium | Charts | The 6-month trend (`insights.dart:1770`) is two static lines with no way to read a month's value, and category bars are scaled to the largest category so they show rank, not share. Copilot lets you scrub the chart; Spendee shows a composition donut. | Make `_TrendPainter` scrubbable with a `GestureDetector` and a value readout, and append "NN% of spending" to each category bar using its share of the forecast total. Pure Dart. |
| R4 | Riley | Medium | Bank and e-wallet cards | A GCash wallet and a BPI account differ only by gradient hue and a nearly invisible monogram (`bank_card.dart:176`, alpha 0.08), so a card does not read as "my GCash". | Without adding a logo (legally correct), raise the monogram presence and add a code-drawn e-wallet vs bank distinction (wallets get a corner pill, banks keep the EMV chip). |
| R5 | Riley | Low | Loading states | Empty and error states are strong, but there is no loading or skeleton state, so a cheap phone can show empty cards mid-load. | Add a `LoadingState` sibling to `empty_state.dart` drawing a few shimmer placeholder bars, used while the store resolves on heavy tabs like Insights. |
| K1 | Kai | High | Log sheet feedback | The most frequent action has no haptic. After `addEntry` succeeds (`log_sheet.dart:162-163`) the sheet pops with no `HapticFeedback`, while debt payoff, utang settle, and card flip all buzz. | Add `HapticFeedback.mediumImpact()` immediately after `addEntry` returns. One line, ships over the air. |
| K2 | Kai | High | History performance | History is a plain `ListView(children: items)` (`history.dart:345`), so every row and every `Dismissible` builds on the first frame. This is the one clear performance defect and it janks on long histories. | Convert to `ListView.builder` or `SliverList.builder` so rows build lazily. |
| K3 | Kai | Medium | Pan visibility | Because the Log FAB is global but Pan lives only on Overview and Ask Pan, a log from another tab turns Pan happy for 6 seconds on a screen where Pan is not shown, so the warmest feedback is usually invisible. | Surface a tiny Pan face or micro-bob in the log-confirmation snackbar, so the success state travels with the action. |
| K4 | Kai | Medium | Screen transitions | Every screen push is a hard platform cut. The carousel card and `account_detail.dart` share a visual but the transition is a stock slide. | Wrap the carousel card and the detail header in a `Hero` with a matching tag. Low risk because the flip card is already a clean widget. |
| K5 | Kai | Medium | Month navigation | No swipe to change month anywhere; only arrow buttons (`period_selector.dart`). Copilot, Mint, and Monarch all swipe a month view. | Put the month body in a `PageView`, or add `onHorizontalDragEnd` stepping the period, keeping the selector as the visible affordance. Pairs with S3. |
| K6 | Kai | Low | Balance display | Balances snap to a new value (`overview.dart:1206`) rather than counting. Copilot rolls the balance so it reads as "your money moved". | Wrap the amount in a `TweenAnimationBuilder<double>` easing between the two already-correct totals. Animate presented digits only, never recompute money. |
| K7 | Kai | Low | List gestures | No leading swipe (edit or duplicate) on rows and no `onLongPress` anywhere in `lib`. | Widen the history `Dismissible` to a secondary background for Edit or Duplicate, and add `onLongPress` quick actions. |
| I1 | Isla | High | Insights | `categoryMovers` (`analytics.dart:259-282`), the sharpest "you spent 40% more on food delivery this cycle" insight, is fully computed but never rendered. Insights only calls `categoryVsAverage`. | Render a "Biggest changes since last month" strip from `categoryMovers`. One wiring change on an already-golden engine. |
| I2 | Isla | High | Recap | The recap (`recap.dart`) is monthly only, but this audience lives on the 15th and 30th sweldo cycle, so a monthly recap arrives too late to change behavior mid-cycle. | Add a `cycleRecap` keyed to the payday schedule (`cycle.dart`, `phcalendar` exist) that fires the day before each payday with cycle-over-cycle category deltas. |
| I3 | Isla | Medium | Money health card | `_healthCard` (`insights.dart:1158-1236`) shows a 0-100 score and four bars but never names the one lever to pull. Pan already computes the weakest lever in `pan/respond.dart`. | Add a "Your weakest lever is X, doing Y would move it most" line, converting the most dashboard-like surface into coaching. |
| I4 | Isla | Medium | Pan copy correctness | The `savings_rate` reply in `pan/respond.dart` says "Debt payments count as money out here", but `savingsRate` (`analytics.dart:349-363`) counts interest as spending and principal not, so the stated mechanism is wrong. | Reword to match the engine: interest paid counts as money out, principal paid down moves from debt to net worth and does not lower this number. |
| I5 | Isla | Medium | All-clear check-in | The calm-week fallback in `coach.dart` and the Insights "on track" card say "enjoy the calm" and teach nothing, wasting the most teachable moment. | When nothing is urgent, surface the next forward step from `surplus.nextPesoPlan` or the day's targeted lesson. |
| I6 | Isla | Medium | Emergency fund lesson | The `emergency-fund` lesson (`content/lessons.dart`) never teaches that the account choice changes the return by roughly 10x (passbook vs online savings, both PDIC insured). | Add a product-neutral "Your cushion should still earn" concept, linked from the runway card with an illustrative figure. |
| I7 | Isla | Low | Share cards | Authored share copy ends with a coffee emoji (`recap.dart`, `milestones.dart`), contradicting the repo's own "no emoji in authored copy" rule. | Replace the emoji with a word, or document the share-card exception in the house rules. |
| M1 | Morgan | Medium | Learn / Money Courses | The lessons track (`learn.dart` plus 19 content files including full BIR business-registration and permits courses) is the largest surface by content volume and the furthest from the core log loop, serving a tiny freelancer sub-segment. | REDESIGN: keep 4 to 6 core money-habit lessons on the Home "next lesson" hook, archive the business and BIR tracks behind a clearly optional door, stop expanding them. |
| M2 | Morgan | Medium | Reports | Three formal financial statements (`reports.dart`) use an accounting mental model that is wrong for Gen Z and largely restate Home and Insights. Low glance value, high reading cost. | REDESIGN into one plain "your month" view, or merge into Insights. |
| M3 | Morgan | Low | Tax cluster | Three separate tools (`tax_calculator.dart`, `tax_deadlines.dart`, `year_end_tax.dart`) for a narrow seasonal need over-build the Tools list. | Collapse into one "Tax" tool with tabs. |
| M4 | Morgan | Low | Treats, Notes | "Earn your treats" (`treats.dart`) and Notes (`notes.dart`) are clever but invisible to the money loop and carry no retention pull. | Fold the treats check-in into Mindset, and either tie Notes to logging (a note line becomes an entry) or cut it. |
| M5 | Morgan | Low | Dead / orphaned code | `UtangScreen` (`utang.dart:135`) is not reached in production (its own comment admits it is for tests and a transition), and `learning_path.dart:50` is a hidden, content-incomplete path. | Remove `UtangScreen` after confirming tests use `UtangBody`, and either finish or delete the hidden learning path. |
| M6 | Morgan | Note | Pro gating | Pro is a local `settings['pro']` flag with "Unlock free" buttons (`cashflow.dart:135`, `recurring.dart:300`, `store.dart:2354`) and no purchase flow. Every Pro gate is bypassable today. | Expected pre-monetization. When monetization lands, do not wall off anything users already had open; build the paid tier from new weekly-felt value. |
| K8 | Kai | Note | Tab transitions | The `IndexedStack` tab swap (`shell.dart:303`) is instant. This is the right call for state preservation and lazy build; do not trade it away. | Optional: a light `AnimatedSwitcher` fade around the stack output, only if it does not risk the lazy-build behavior. |

---

## 3. Competitor gap analysis

Salapify versus the best-in-class competitor per UI area. "Gap" is the honest
distance, not a putdown.

| UI area | Salapify today | Best competitor at this | The gap |
|---|---|---|---|
| Home hierarchy | One hero number and one action on the only raised card, supporting cards below (`overview.dart`) | Copilot Money | Small. Structure is already right; the gap is hero polish, not layout. |
| Add transaction | Bottom sheet, OS keyboard, free-text label, no category, no keypad (`log_sheet.dart`) | Monefy, Money Manager | High. No category grid, no in-app keypad. |
| Category capture | Label is the category; grouping depends on exact retyping | Money Manager, Monefy | High. Analytics quality is downstream of a field never collected. |
| Charts and insights | Strong text insight, static 2-line trend and rank bars (`insights.dart`) | Copilot (scrubbable), Spendee (donut) | Medium. Logic beats rivals; the visualization is static. |
| Dark mode | 16 AA-checked palettes, warm coffee darks (`theme.dart`) | Revolut, Copilot | None to slight. Best in class; do not chase anyone. |
| Bank and e-wallet cards | Brand-color gradient, drawn chip, faint monogram (`bank_card.dart`) | GCash and Maya own apps, Revolut card art | Medium. Premium and legally clean, but a GCash card reads generic. |
| Typography and spacing | One type system, tabular figures, Jakarta, Gap and Radii ladders | YNAB, Copilot | None. More disciplined than most rivals. |
| Empty and error states | Unified, reassuring, action-led (`empty_state.dart`, `error_state.dart`) | Cash App | None for empty and error. Missing a loading skeleton. |
| Motion and feedback | Real swipe-delete, card flip, celebration, event-driven mascot | Copilot, Cash App, Revolut | Medium. Strong pieces, but logging is silent and screen pushes are hard cuts. |
| Content and coaching | Peso-specific coach, order-of-operations, PH-grounded lessons | YNAB (philosophy) | Salapify leads on logic; the gap is that smart conclusions render as static widgets. |

---

## 4. Flow break map

Every point where a user journey breaks or dead-ends, from the six traced
journeys.

- **Log to category totals.** Log writes no `categoryId`, so user-named
  category caps read 0 while Budget shows the spend for the same money.
  `log_sheet.dart:149-156`, `money/categories.dart:143`. FIX NOW. (S1, R1, R2)
- **No per-entry tagging on Edit either**, so nothing in normal use ever tags
  a category. `edit_sheet.dart`. POLISH SOON. (S2)
- **No shared selected month.** History and Reports own independent,
  differently capped month states; Home, Budget, and Insights are fixed to
  today. Stepping one back changes nothing on the others.
  `history.dart:132`, `reports.dart:64-79`, `budget.dart:33`,
  `insights.dart:239`. BREAK. (S3)
- **No swipe between months anywhere**, only arrow buttons.
  `period_selector.dart`, `reports.dart:254-270`. NOTE. (K5, S3)
- **Recurring bills never notify.** `plannedReminders` reads debts only.
  `reminders.dart:198-231`. FIX NOW. (S4)
- **Recurring add/edit/delete does not reschedule notifications**, so new
  reminders stay dark until the next resume. `store.dart:2005/2038`,
  `recurring.dart:406-445`. POLISH SOON. (S6)
- **Transfer success is silent.** `Navigator.pop()` with no receipt, unlike
  every other money write. `accounts.dart:1869`. FIX NOW. (S5)
- **Transfer delete does not reverse balances** (intended, golden-locked) and
  has no Undo, so the receipt fix is the only honest feedback.
  `ledger.dart:111-131`, `transfers.dart:7-10`. NOTE. (S5)
- **Allocate income to budget has no surface**; the Payday ritual exists but
  is unreachable from the Log income flow. `payday.dart`, `log_sheet.dart`.
  NOTE. (S7)

Journeys that PASS cleanly: expense logging tap count (2 taps, under the bar),
income raising the linked account and net worth, transfer money correctness
(both balances move, one inert record row, no double count), and edit or delete
recalculation (reverse-then-apply means no edit can drift a balance).

---

## 5. Innovation and enhancement roadmap

### Fix first (this week): Critical and High, money and broken flows

1. **Q1, currency mixing.** Gate `emergencyRunway` and `healthScore` through
   `inBaseCurrency`, add foreign-exclusion vectors. This is the one Critical
   correctness bug. (Significant: touches money math, tell the founder.)
2. **S1 plus R1 plus R2, capture a category at log time.** One change fixes a
   flow break, a competitor gap, and the app's own analytics quality at once.
   If it needs a schema field, flag it to the founder first.
3. **S4, recurring bills notify.** Add the recurring branch to
   `plannedReminders`.
4. **S5, transfer receipt.** Add the confirming snackbar.
5. **K1, log haptic.** One line, immediate tactile payoff on the most frequent
   action.
6. **Q2, negative zero.** Fix the sign source in `formatMoney` and add the
   missing vector.

### Enhance (this month): UI, motion, content

- **S3 plus K5, one shared month with swipe.** Lift a `Period` to the shell,
  give Budget and Insights a selector, and add `PageView` month swiping. Beats
  the disagreeing-pickers problem and matches the Copilot and Monarch month
  swipe.
- **R1, in-app keypad on the Log sheet.** A code-drawn 12-key grid, to beat
  Monefy and Money Manager on logging speed.
- **I1, render `categoryMovers`.** Switch on the sharpest insight the engine
  already computes.
- **I3 plus I4 plus I5, teach where the app currently decorates.** Weakest-lever
  line on the health card, fix the savings-rate copy to match the engine, and
  make the calm-week check-in advance the user instead of congratulating them.
- **R3 plus K6, chart polish.** Scrubbable trend, composition percentages,
  count-up balances (presentation only, never recompute money).
- **K2, `ListView.builder` on History.** The one clear perf fix.
- **R4, stronger card identity** without a logo.

### Innovate (differentiators no PH competitor has)

Evaluated for effort versus impact. The top 3 to build first are marked.

1. **[TOP 1] Sweldo-cycle-aware budgeting and recap (I2 plus I1).** The 15th
   and 30th cycle is the real cadence this audience lives on, and no named
   competitor budgets on it. A `cycleRecap` firing the day before payday with
   cycle-over-cycle category deltas ("you spent 40% more on food delivery this
   cycle") is the highest behavior-change-per-pixel idea in the whole review,
   and it reuses `cycle.dart`, `phcalendar`, and the already-golden
   `categoryMovers`. Medium effort, very high impact.
2. **[TOP 2] Pan as a real payday coach (K3 plus I5 plus proactive goal
   coaching).** Pan already has event-driven moods and the coach already
   computes the next peso; the missing piece is surfacing that proactively on
   payday, where the money exists, and making the warmest feedback visible when
   the user logs from any tab. Low to medium effort, high retention impact, and
   it is a differentiator because it is on-device and offline.
3. **[TOP 3] "Your cushion should still earn" literacy layer (I6).** The single
   biggest passive win for a Gen Z user with money sitting in a 0.25% passbook,
   taught as a product-neutral concept and wired to the user's own runway
   figure. Low effort, high real-world impact, and it deepens the education moat
   that already separates Salapify from Monefy-style trackers.

Strong runners-up to sequence after the top 3: a spending-personality read from
the Mindset pause and skip data (I-extension), a paluwagan and utang social
angle for word of mouth (already built, under-promoted), and the 13th month pay
planner as a seasonal year-end virality lever (already built in
`thirteenth_calculator.dart`).

---

## Appendix: how to read the finding IDs

- M = Morgan (features), S = Sam (flows), Q = Quinn (money math),
  R = Riley (competitor UX), K = Kai (motion), I = Isla (content).
- Every ID in the tables above maps to a real file and, where it matters, a
  line. Nothing here is a hallucinated feature; each reviewer was required to
  trace the code, not assume from a filename.

This review changed no app code. Implementation of the roadmap should follow
founder approval, and any item marked significant (money math, schema, backup)
goes to the founder before it merges, per the repo rules.
