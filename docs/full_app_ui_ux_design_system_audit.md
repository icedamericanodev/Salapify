# Salapify Flutter, full app UI/UX and design system audit

Date: 2026-08-07. Audit only, nothing in this document is implemented yet.
Successor to the RN era docs/Design_System.md and docs/UX_Audit.md (both
Sprint 0/1, 2026-07-10, written against mobile/); this one is written against
the Flutter app in flutter/lib, which is now the product.

How this audit was produced, so its claims can be checked:

- The whole app was RENDERED and looked at, not only read. The screens_shot
  harness produced 120+ PNGs (93 render tests, dark first, both brightnesses,
  the lived-in fixture), and the core surfaces were reviewed as images:
  Overview, Shell, Accounts, Activity, Insights, Budget, Utang, Log sheet,
  Cash flow, Learn, Menu, Goal detail, Appearance at large font, and light
  mode. Shot filenames are cited below; regenerate them any time with
  `cd flutter && flutter test test/screens_shot.dart --update-goldens`.
- Five specialist passes ran independently before consolidation: a Flutter
  UX screen-by-screen audit, a competitor benchmark (Tarsi, researched from
  live sources), a brand identity review, a motion and interaction audit,
  and a mechanical typography/spacing/radius/color inventory (grep counts,
  not impressions).
- Every count in this document is a measurement against the tree at the time
  of writing. Counts rot; re-run the greps before trusting them in a future
  session (the inventory section includes the commands).

## 1. Executive summary

Salapify's Flutter app has a genuinely strong design system SKELETON and a
weak design system PRACTICE. One color namespace with sixteen AA-swept
palettes, one type ladder with four real font weights and tabular money
figures, a spacing ladder, a radius ladder, reduce-motion aware primitives,
and honest error copy: that infrastructure is better than most shipped
fintech apps, and it is enforced by tests in a way even big teams rarely do.

But the screens only half-obey it. About a third of all text bypasses the
type system (416 raw TextStyle literals in screens against 821 AppText
uses). The app's most used corner radius (12, at 107 sites) is not on its
own radius ladder. The declared standard card gap is 16 while the home
screen ships 12 in twenty places. The two forms that write the same
transaction object (log sheet and edit sheet) disagree on surface, radius,
input fill, chip style, and amount size. Every screen speaks a dialect, and
that is precisely the "developer-designed, assembled features" feeling the
founder named.

So the diagnosis is specific and fixable: this is not a redesign problem,
it is a consolidation problem. The system exists; reality drifted from it;
nothing enforces the boundary. The cure is (a) adjust the tokens to match a
decision where reality won the argument (radius 12, gutter 20), (b) convert
the screens where the system should have won (spacing, type, inputs), and
(c) add the same kind of machine enforcement that already guards palettes
and stamps, so drift cannot silently return.

### Scores, out of 10

| Area | Score | One-line evidence |
|---|---|---|
| Typography | 6 | Excellent ladder and weights, but 41 off-ladder size sites, a 17x shadow rung at 12.5, and 241 raw weight literals |
| Visual hierarchy | 6 | Overview's ordering is genuinely well reasoned; Insights is a ~20 card equal-weight wall, Activity is a card per row |
| Spacing | 5 | 7 of 643 EdgeInsets literals use Gap tokens; two card rhythms (12 and 16) ship side by side |
| Color system | 8 | 16 palettes AA-swept in CI with self-verifying math; minus 23 ad-hoc alpha levels and caramel/celebrate untested |
| Component consistency | 5 | Inputs hand-rolled in 15+ files, chips copy-pasted 5x, AppBar boilerplate 30x, four progress bar heights |
| Navigation | 7 | Shell, tabs, FAB and header language are coherent; Menu is a wall of 16 identical tiles, two header systems |
| Forms | 5 | Log and edit sheet are two different apps ten seconds apart; error states are the consistent bright spot |
| Charts | 5 | Cash flow projection is good; the 6-month trend has no numbers, Home's Road Ahead renders as a flat block |
| Accessibility | 8 | No text-scale disables anywhere, 37 screens machine-checked at 1.5x, 18/18 icon buttons labeled; minus unswept sheets and the Syste/m wrap |
| Brand identity | 7 | Ownable palette, Pan's fixed color, earned gold discipline; underexpressed at wins, stock Material glyphs |
| Overall UX | 6 | Substance (utang, courses, PH tax) ahead of most competitors; density and front-door speed behind |
| Perceived polish | 6 | Press feel and card flip are premium; ripple corners mismatch cards, progress bars teleport, saves are silent |

### If Salapify and Tarsi were side by side today, which feels more polished?

Tarsi, and it is worth being precise about why, because it is not craft
depth. Tarsi's polish is perceived at the front door: one utterance logs a
transaction ("Starbucks 250", typed or spoken), the net worth story fits one
screen, and a single design hand kept every list obeying the same physics.
Salapify's craft is deeper where a first-run user never looks: sixteen
AA-verified palettes against Tarsi's two brightnesses, a tested type system,
trademark-safe bank cards, reduce-motion contracts, screen-reader labels
reasoned line by line. An independent review of Tarsi even says its flows
are "surprisingly confusing and overwhelming" under the clean surface, which
is the inverse of Salapify's problem. Salapify loses the first five minutes
and wins the fifth week. The overhaul's job is to stop losing the first five
minutes without spending the depth: uniform list physics, one form language,
a calmer first viewport, and a faster path from thumb to saved entry.

## 2. Top 20 UI/UX problems, ranked

P0 critical, P1 high, P2 medium, P3 polish. Every item names evidence you
can open today.

### P0-1. The main write path never captures a category, but Insights is built on categories
- Evidence: grep of `flutter/lib/screens/log_sheet.dart` shows zero
  categoryId references; `insights.dart` "WHERE YOUR MONEY WENT THIS MONTH"
  (line ~1309) and Budget's Where it went aggregate by category.
- Affected: Log sheet, Insights, Budget, Reports.
- User impact: the fastest, most-used way to log produces entries invisible
  to every category insight; the analytics screens quietly under-report.
- Root cause: category attach was built into edit_sheet and Budget quick add
  only.
- Fix: optional one-row category chip strip in the log sheet, defaulting to
  none, remembering last pick per label. This is a UX architecture fix, not
  visual polish, which is why it outranks everything below.

### P0-2. Home's "The Road Ahead" chart renders as a flat orange block
- Evidence: shots overview-dark.png and overview-light.png; the sparkline
  hugs the top edge and the fill below is one solid rectangle with no axis,
  no scale, no readable shape.
- Affected: Overview, the default screen of the app.
- User impact: the most prominent visual on the home screen reads as a
  rendering bug, which taxes trust in everything else.
- Root cause: timeline_sparkline scales to the data's min/max; a low
  variance week degenerates into a flat line with a giant fill, and nothing
  clamps or annotates the degenerate case.
- Fix: give the sparkline a sensible y-domain floor (for example, zero to a
  rounded ceiling), a dashed zero/today reference, and let the existing
  caption carry the numbers. The correct pattern (chart states its own
  conclusion) already exists in this exact card's caption.

### P0-3. Log sheet and edit sheet are two different apps for the same object
- Evidence: amount 28/w700 (log_sheet.dart:261) vs 24/w700
  (edit_sheet.dart:340); sheet surface background+radius 24 (log_sheet:57)
  vs card+default 28 (edit_sheet:37); input fill card vs background; input
  radius 12 vs Radii.md; chips card-filled vs background-filled; drag
  handle vs none.
- Affected: the two most used forms in the app.
- User impact: log then edit within ten seconds and the app visibly changes
  dialect on its highest-frequency path.
- Root cause: two files evolved separately with private `_decor` helpers.
- Fix: one shared EntryFormBody (or at minimum one shared decoration, chip
  builder and sheet chrome) consumed by both. Amount input at
  AppText.amount, tabular, in both.

### P1-4. Two card rhythms ship side by side, and the front page is on the old one
- Evidence: theme.dart Gap.lg is documented as "the standard gap between
  cards. Was 12 in 95 places"; overview.dart still separates cards with
  SizedBox(height: 12) twenty times; budget, insights, reports, menu
  likewise; goal_detail and onboarding use Gap.lg.
- Impact: the single largest contributor to "screens feel disconnected";
  vertical rhythm changes per screen.
- Fix: mechanical pass, between-card 12 becomes Gap.lg. Cheapest single
  change that makes the app feel like one product.

### P1-5. The app's most used radius is not a token, and ripples clip at the wrong corner
- Evidence: BorderRadius.circular(12) at 107 sites vs Radii.* used 64
  times; ~15 distinct radii ship (2,3,4,5,6,8,10,12,14,16,18,20,24,28,999).
  InkWell(borderRadius: 12) inside Cards whose theme shape is 20
  (overview.dart:385,459; section.dart:215) squares every tap ripple 8dp
  short of the card corner.
- Impact: subtle "developer-designed" tell on the most touched surfaces.
- Fix: promote 12 to a token (controls/chips), snap the rest, and give
  every card-filling InkWell the card's own radius.

### P1-6. Cash flow runs a private half-point type scale
- Evidence: cashflow.dart:696,768,817,838,846,1012,1187,1193 use 13.5,
  12.5, 14.5, 11.5, 10.5 via copyWith on AppText styles.
- Impact: an entire feature renders in a different type system than its
  neighbors.
- Fix: snap to the ladder (12.5 to caption or small, 14.5 to label, 11.5 to
  micro, 10.5 to nav/micro), delete the copyWiths.

### P1-7. Text below the app's own readable floor
- Evidence: reports.dart:1412,1622 at fontSize 8.5; insights.dart:1798 at
  9; the ladder's own doc calls micro (11) "the smallest a phone should
  show".
- Impact: unreadable for exactly the users who raise system font size.
- Fix: AppText.micro and let the layout widen, or move the label into
  Semantics.

### P1-8. Insights is a wall of ~20 equal-weight cards
- Evidence: insights.dart:287-425 stacks decision cards, steady pay, safe
  to spend, next peso, four collapsibles (each a header card plus child
  card), then five "bigger picture" cards, all with the same border,
  radius, and kicker. Shot insights-full-dark.png.
- Impact: the app's most tiring screen; the one number the coach orbits
  (Safe to spend) is a visual peer of everything else.
- Fix: Safe to Spend becomes the one raised hero (the Overview pattern);
  the bigger-picture band becomes rows in one card; keep collapsibles.

### P1-9. Three list physics for "a list of money things"
- Evidence: History is a card per transaction (history.dart:499, ~6 rows
  visible per screen, shot history-dark.png); Overview's MY MONEY is rows
  in one card with hairline dividers and documents that rule in a comment
  (overview.dart:487-492); Utang is a card per person (utang.dart:972).
- Impact: density collapses on the transaction list (hundreds of entries),
  and the same content type gets three treatments.
- Fix: adopt the Overview rule app-wide; History becomes grouped day cards
  with divider rows, which roughly doubles rows per screen and removes two
  borders per row.

### P1-10. A row amount reads five different ways in five screens
- Evidence: AppText.amountRow.w6 (history.dart:485), plain w700
  (accounts.dart:880, account_detail.dart:440), .w8 at 14.5
  (cashflow.dart:846), resized to 17 (utang.dart:986) and 16
  (accounts.dart:508, overview.dart:517).
- Fix: one rule, AppText.amountRow untouched everywhere, .tint() the only
  permitted modifier.

### P1-11. Input decoration is hand-rolled in 15+ files against a theme that already defines it
- Evidence: `_decor` in log_sheet.dart:332 (radius 12, fill card),
  edit_sheet.dart:468 (radius 14, fill background), quick_add_editor:257,
  two different ones inside utang.dart (1019, 1388), split_expense,
  recurring, every calculator; theme.dart:846-862 defines
  inputDecorationTheme.
- Fix: make the theme decoration correct once (fill surfaceRaised or card,
  radius Radii.md), delete every private helper.

### P1-12. The most frequent action in the app saves in tactile silence
- Evidence: log_sheet.dart:162-200 addEntry succeeds with no haptic; zero
  HapticFeedback calls in the file; same on Budget quick add and edit
  sheet.
- Impact: the save moment, felt dozens of times a day, has no physical
  confirmation; benchmark apps thump on every money write.
- Fix: HapticFeedback.lightImpact() after each successful money write.
  Light, not medium, so medium stays reserved for celebrations.

### P1-13. Large-text defect on a control the readability sweep does not cover
- Evidence: shot appearance-large-font-dark.png shows the Mode segmented
  control wrapping mid-word ("Syste / m") at 1.3x; the readability test
  covers 37 screens at 1.5x but exempts the modal sheets
  (log/edit/split/quick-add), onboarding, and the share screens, and
  fixed-height controls live in the unswept set (tax_deadlines.dart:240,
  milestone_share.dart:581, recap_share.dart:436).
- Fix: let segment labels wrap to two lines or scale down gracefully;
  extend the sweep to sheets (the harness itself calls this "the biggest
  remaining hole").

### P2-14. The kicker forked about 26 times
- Evidence: letterSpacing 2 (16x) and 1 (10x) hand-rolled against the one
  canonical kicker (1.2); Kicker widget exists but 20+ files use raw
  Text(style: Barako.kickerStyle); log_sheet uses cardKickerStyle while
  section.dart documents that style as "used by nothing in the app".
- Fix: route everything through Kicker; write the inside/outside card rule
  or delete cardKickerStyle.

### P2-15. 23 distinct alpha levels, no opacity ladder
- Evidence: 44 withValues calls across 23 alpha values (0.05 to 0.92);
  nearly every use invents its own.
- Fix: four named levels (wash 0.06, tint 0.12, hint 0.24, scrim per
  palette overlay), token'd next to the palette.

### P2-16. Reduce-motion support is a coin flip per file
- Evidence: honored in pressable_scale, flip_bank_card, celebration,
  segmented, mindset, shell; ignored in paged_lesson_reader (220ms slide
  always animates), treats, lesson_block_views, learn, pan chat scroll,
  pan_mascot bob, accounts ensureVisible.
- Fix: a Motion.of(context, d) helper returning Duration.zero under
  disableAnimations, then retrofit the seven files.

### P2-17. Progress never moves, and 17 bars ship at four heights
- Evidence: all 17 LinearProgressIndicator sites take a static value
  (goal_detail:207, goals:580, budget:300/374, learn:455); heights 5, 6, 8,
  10 across files.
- Impact: adding money to a goal teleports the bar while the milestone
  confetti fires next to it.
- Fix: one SalapifyProgressBar (two sizes) with a TweenAnimationBuilder
  fill, snap under reduced motion.

### P2-18. Charts are paintings, not instruments, and the trend chart has no numbers
- Evidence: zero onHorizontalDrag/onPanUpdate across lib; cashflow's
  _BalancePainter and insights' _TrendPainter are static CustomPaints; the
  6-month trend shows shape but no figure, so "was July worse than June"
  cannot be answered on it.
- Fix: print the latest month's figures beside the legend; add scrub with
  per-day selectionClick to the cash flow chart (the Semantics summary
  already computes the values).

### P2-19. Hand-rolled empty states re-drifted despite EmptyState existing
- Evidence: empty_state.dart exists because empty states "read as three
  different apps"; only budget, history, insights, utang use it; goals
  (19pt off-ladder title), accounts, treats, paluwagan hand-roll.
- Fix: adopt EmptyState in the four drifted screens.

### P2-20. AppBar boilerplate copy-pasted ~30 times, one copy already diverged
- Evidence: backgroundColor/foregroundColor/title w800 repeated in ~30
  files; search.dart:167 uses AppText.title instead.
- Fix: one appBarTheme entry in salapifyTheme, delete all copies.

Held at P3, tracked but below the fold of this list: Fraunces font assets
still shipped in pubspec but referenced by nothing (base APK weight, its
removal must be flagged loudly as a native-level change), divider heights
20/24/18 within one file, month stepping tap-only and silent, no
Hero/shared-element continuity from card to detail, Reports' hand-rolled
segmented control that regressed the shared one (height 44 vs the enforced
48), menu's 16-tile wall scrolling two screens deep, w800 leaking onto
ordinary labels (mindset.dart:1226), the stale "net worth is the headline"
comment above code that demotes it (overview.dart:1186), and the "tap the
card to flip it over" hint sitting in its own odd card on Accounts (shot
accounts-grouped-dark.png).

## 3. Typography inventory

Font sizes in flutter/lib (raw fontSize literals; 211 total, plus 933
AppText.* consumptions which resolve to ladder rungs). Re-derive with:
`cd flutter && grep -rhoE 'fontSize: [0-9.]+' lib | sort | uniq -c | sort -rn`

| Size | Count | On ladder? | Where / replacement |
|---|---|---|---|
| 20 | 21 | yes | AppText has no 20 rung; mostly hero labels, use lg via a new style or heading |
| 12 | 21 | yes | AppText.caption |
| 11 | 20 | yes | AppText.micro |
| 13 | 18 | yes | AppText.small |
| 12.5 | 17 | NO | the shadow rung; goal_detail, cashflow, pan, goals, overview, paluwagan; snap to caption or small |
| 16 | 14 | yes | AppText.bodyLg |
| 15 | 14 | yes | AppText.body |
| 14 | 14 | yes | AppText.label |
| 10 | 14 | yes | TypeScale.nav |
| 24 | 12 | yes | new AppText.titleLg |
| 9 | 5 | NO | 3 legit (PDF export), insights.dart:1798 and flip_bank_card.dart:527 snap to micro |
| 18 | 5 | yes | AppText.heading |
| 17 | 4 | yes | AppText.subtitle |
| 30 | 3 | yes | new AppText.hero (non-money) or amountLg (money) |
| 28 | 3 | yes | AppText.amount |
| 27 | 3 | NO | the lesson-reader title forked 3x (learn:1210, paged:364, expansion:320); snap to big 28 |
| 26 | 3 | NO | treats emoji, overview wordmark, bank card; snap or exempt as art |
| 22 | 3 | yes | AppText.title |
| 14.5 | 3 | NO | goals:256, cashflow:817,846; snap to label |
| 8.5 | 2 | NO | reports:1412,1622; below the floor, use micro |
| 19 | 2 | NO | goals:172, lesson_block_views:460; snap to heading or lg |
| 13.5 | 2 | NO | afford_card:232, cashflow:696; snap to small or label |
| 10.5 | 2 | NO | cashflow:1187,1193; snap to nav or micro |
| 96 | 1 | NO | bank_card watermark glyph, legitimate art |
| 34 | 1 | yes | AppText.amountXl |
| 11.5 | 1 | NO | cashflow:838; snap to micro |

Off-ladder total: 41 occurrences of 11 distinct sizes. The dominant leak
shape is `AppText.X.copyWith(fontSize: offLadder)`: the token system used
as a base and immediately overridden (68 copyWith(fontSize:) sites).

Weights: zero synthetic weights anywhere (the w500 purge held; every value
is 400/600/700/800). But 241 raw FontWeight literals coexist with the
TypeWeight tokens and .w4/.w6/.w7/.w8 modifiers (~372 tokenized uses), and
w800 appears on ordinary labels against the "heavy is money and titles"
rule.

Raw TextStyle( constructions: 465 in lib (11 in typography.dart and 8 in
theme.dart are the system itself). Worst files: goal_detail (32), mindset
(25), debts (24), utang (23), accounts (22), overview and cashflow and
account_detail (15 each). Share screens legitimately self-style but
correctly name families via Barako.bodyFont/displayFont; the only raw
family strings are two 'monospace' debug usages in overview.dart.

letterSpacing: 12 distinct values where the system defines one (kicker
1.2); the 16x "2" and 10x "1" are forked kickers. Text height: 7 distinct
values in screens vs the sanctioned 1.05/1.2/1.25/1.3/1.4.

Hardcoded Color( outside theme.dart: 33, mostly defensible (share images,
bank card art, Pan's fixed palette). withOpacity: zero (fully migrated).
withValues alphas: 44 calls, 23 distinct levels, no ladder.

## 4. Recommended typography scale

Family: keep Plus Jakarta Sans, one family, four real weights. This is a
deliberate reaffirmation, not a default: the display serif was removed for
a real bug (Fraunces' ₱ crossbar reading as a strikethrough on negatives),
the founder preferred the result, Jakarta ships a real tnum table, and the
RN app the founder liked was one family too (the system face). Salapify's
typographic identity is the money-number system (heavy tabular figures,
₱ set in the brand primary on hero figures), not a second font. Keep
displayFont and bodyFont as two constants so the door stays open.

The scale below is the existing ladder plus the two missing rungs the
screens kept inventing (a non-money 24 and 30), minus nothing. Values are
confirmed by the audit rather than imported from Material.

| Token | Size | Weight | Height | Spacing | Use |
|---|---|---|---|---|---|
| amountHero | 42 | 800 | 1.05 | 0 | net worth hero only, tabular |
| amountXl | 34 | 800 | 1.05 | 0 | hero one step down, tabular |
| amountLg | 30 | 800 | 1.05 | 0 | hero on a busier screen, tabular |
| amount | 28 | 800 | 1.05 | 0 | card headline figure, tabular; also the amount INPUT size in both sheets |
| amountRow | 15 | 700 | 1.2 | 0 | row amounts, tabular; never resized, never reweighted, tint only |
| title | 22 | 800 | 1.2 | 0 | page and AppBar titles |
| titleLg (new) | 24 | 800 | 1.2 | 0 | oversized page moments (onboarding, lesson covers); kills the invented 24s |
| hero (new) | 30 | 800 | 1.15 | 0 | the rare non-money statement (onboarding welcome); kills the invented 30s and 27s |
| heading | 18 | 700 | 1.25 | 0 | section headings in a screen |
| subtitle | 17 | 700 | 1.25 | 0 | card titles |
| bodyLg | 16 | 400 | 1.4 | 0 | emphasized body, primary list titles |
| body | 15 | 400 | 1.4 | 0 | the default sentence |
| label | 14 | 600 | 1.3 | 0 | dense labels, list rows |
| small | 13 | 400 | 1.3 | 0 | secondary rows, hints, timestamps |
| caption | 12 | 400 | 1.3 | 0 | muted metadata |
| micro | 11 | 600 | 1.2 | 0 | the floor; nothing user-visible below this |
| kicker | 12 | 600 | 1.2 | 1.2 | uppercase overline; the ONLY letterspaced style |
| nav | 10 | 600/800 | 1.0 | 0.1 | bottom nav labels only |

Rules that make the scale hold:
1. 12.5 is purged, not promoted. It sits between two rungs that both work.
2. `copyWith(fontSize:)` is banned in screens; a new test greps for it and
   for raw `fontSize:` outside typography.dart, theme.dart, and a short
   allowlist (share images, PDF export, bank card art). Same shape as the
   font-family test that already exists, and per house rules the test gets
   broken once on purpose to prove it fails.
3. Raw FontWeight literals convert to .w4/.w6/.w7/.w8 in the same pass.
4. w800 audit: heavy stays money and titles.

## 5. Design token specification

All proposed tokens live in the two files that already own these decisions
(theme.dart, typography.dart), no new parallel system.

Colors: the existing Barako roles are correct and stay. Additions and
rulings:
- Alpha ladder: `BarakoAlpha.wash = 0.06`, `tint = 0.12`, `hint = 0.24`,
  plus the existing per-palette overlay. All 44 withValues calls snap.
- Contrast test grows three pairs it currently misses: caramel on card
  (today guaranteed only by a comment), celebrate on card/background, text
  on positiveSurface. The repo's own lesson applies: a rule in a comment is
  not a machine.
- Money direction is never color alone (existing rule, keep): sign prefix
  plus glyph carries direction; income keeps primaryText, expense keeps
  text ink, warning red is reserved for genuinely risky states (overdue,
  over-limit), never ordinary spending.
- Celebrate gold becomes theme-invariant, the same reasoning as Pan's fixed
  orange: the reward signature should read identically in every screenshot.
  (Today Voltage celebrates in hot pink, Ultraviolet in lime.)
- Barako-only on all external surfaces as written policy: app icon, store
  listing, share images (already true in code), onboarding first-run.

Spacing: keep Gap 2/4/8/12/16/24/32 and add the two de facto values:
- `Gap.gutter = 20` (the screen edge, already consistently 20 horizontally)
- Card interior padding: exactly two values, 16 standard and 20 hero,
  enforced by the shared card body rather than by memory.
- Off-ladder raws (14 at 89 sites, 18, 6, 10, odd 9/11/13) snap in the
  conversion pass: 14 to 12 or 16 by eye per site, 18 to 16 or 20.
- Screen scroll padding: two named constants, screenPadding
  (20, 16, 20, 32) and tabScreenPadding (adds bottom 96 for the FAB).

Radius: the ladder must describe reality, so it is re-cut around what
shipped, keeping card geometry untouched:
- `Radii.control = 12` (chips, inline controls, small tiles; legalizes the
  107 sites)
- `Radii.field = 14` (inputs, buttons; today's md)
- `Radii.card = 20` (cards and dialogs; today's lg and the theme's card
  shape)
- `Radii.hero = 26` (today's xl)
- `Radii.sheet = 24` (bottom sheet top corners, set once in a new
  bottomSheetTheme so log/edit stop disagreeing)
- `Radii.pill = 999`
- sm/md/lg/xl remain as deprecated aliases during migration; the stragglers
  (2,3,4,5,6,8,10,16,18,28,44) snap to the nearest new token.
- Every InkWell that fills a Card takes the card's radius.

Elevation: formalize what the app already believes, borders not shadows:
- level0 = background (the screen)
- level1 = card + border (standard reading surface)
- level2 = surfaceRaised + border (the ONE hero per screen)
- overlay = the scrim
- The FAB keeps its elevation 2; nothing else casts a shadow. "One raised
  surface per screen" becomes a written rule; it is the entire hierarchy
  mechanism of Overview and it generalizes.

Icon sizes: 22 nav (existing), 20 default inline, 16 dense meta, 40 disc
(salapify_icon). Named in one place.

Motion (new, small, grounded in measured current values):
- `Motion.tap = 120ms` (press dip, already the pressable value)
- `Motion.state = 160ms` (fills, crossfades; absorbs 160/180/200)
- `Motion.move = 240ms` (page turns, scrolls; absorbs 220/240/250/260)
- `Motion.reveal = 420ms` (card flip, progress fills; absorbs 300-420)
- `Motion.celebrate = 1400ms` (confetti only, reserved)
- Curve: easeOut, full stop (13 of 14 sites already; convert the one
  easeOutCubic).
- `Motion.of(context, d)` returns Duration.zero under disableAnimations,
  turning the reduce-motion coin flip into a default.
- Haptic vocabulary, three words: selectionClick = a choice or position
  change; lightImpact = money written (new); mediumImpact = a milestone
  (celebration only, as today). Never a haptic on a gated or failed action
  (cashflow.dart already documents this: a buzz says "that worked").

## 6. Component audit

KEEP (working, protect):
- ScreenHeader + MenuAction: the tab chrome language is coherent.
- PressableScale: best primitive in the app, ~40 call sites, reduce-motion
  aware.
- BankCard + CashBalanceTile + FlipBankCard: premium, trademark-safe, AA
  proven; the "cash is not an institution" split is exactly right.
- Celebration: real reduce-motion contract, announced to screen readers.
- EmptyState: right shape, needs ADOPTION not change.
- Segmented: enforces 48dp and reduce-motion; needs adoption (see REPLACE).
- WeekChain, PanMascot, PeriodSelector, TreatCard: sound.
- Kicker/Section/StatPair as concepts (see REFACTOR).

REFACTOR:
- StatPair (section.dart:141-157): hand-rolls the two styles it exists to
  standardize; convert to AppText, zero visual change.
- timeline_sparkline: degenerate-data y-domain (P0-2).
- CollapsibleCard (insights): card-in-card double border; flatten the child.
- log_sheet + edit_sheet internals: extract shared EntryFormBody (P0-3).
- History list: card-per-row to grouped day cards (P1-9).
- Menu: 16 identical tiles two screens deep; group into denser rows per
  band, keep Ask Pan hero.

MERGE:
- The five-plus private `_decor`/`_field`/`_input` helpers into the theme's
  inputDecorationTheme (P1-11).
- utang.dart's two amount-input treatments into the same.
- The three lesson-reader title styles (27pt x3) into titleLg/hero.

REPLACE:
- reports.dart hand-rolled segmented control (height 44, no reduce-motion,
  no semantics) with the shared Segmented.
- Hand-rolled empty states in goals, accounts, treats, paluwagan with
  EmptyState.
- ~30 AppBar copies with one appBarTheme entry.
- Static LinearProgressIndicators with SalapifyProgressBar (animated fill,
  sizes bar 8 and micro 5).

REMOVE:
- Fraunces SemiBold/Bold assets in pubspec (referenced by nothing). BASE
  APK CHANGE: this is a native-level slimming, cannot ship as a patch-only
  win, must be bundled with the next release and flagged loudly to the
  founder.
- cardKickerStyle, or write its inside/outside rule and apply it (today one
  file uses it and the component that should own it documents it as unused).
- The stale "net worth is the headline" comment (overview.dart:1186).
- Eventually the standalone debts.dart fallback route.

NEW (small, only where duplication is proven):
- EntryFormBody (log + edit).
- SalapifyChoiceChip (5 copy-paste sites) or a completed chipTheme.
- PrimaryButton with busy state (4+ re-spellings).
- SalapifyProgressBar.
- AmountText (wraps amountRow/amount + tabular + tint rules so amounts stop
  being restyled per call site).
- ChartFrame (axis text, legend, caption slot) so every chart shares one
  grammar.
- Motion tokens + Motion.of helper.
Not proposed: generic wrappers for things the theme can own (inputs,
app bars, sheets); consolidate at the theme level instead of minting
widgets, per "do not create abstractions merely for abstraction".

## 7. Tarsi competitive review

Tarsi is real and current: an offline-first budget tracker by Filipino
indie developer Bryl Lim, launched around March 2026, #1 Paid and #1
Finance on the PH App Store within 48 hours, later #1 paid in several
countries, 4.7 rating. Feature-level claims below are verified from live
sources; its pixel-level qualities (type, radii, spacing) are NOT
verifiable from this environment, so where pixels matter the operative
benchmark is the polished-finance genre (Copilot Money, Ivy Wallet,
Revolut, Cash App, YNAB), labeled as such.

What Tarsi does better (verified):
- One-utterance logging as the front door: "Starbucks 250" or "Paid credit
  card 5k last week", typed or spoken, recorded instantly. Salapify's log
  sheet is a good form, but it is a form.
- Category at the moment of logging, with subcategories.
- Net worth in a single screen with clean, simple breakdowns.
- Receipt OCR and image attachments (noted as a deliberate Salapify scope
  gap, not urged).
- Perceived simplicity: a single design hand, uniform physics.

What Salapify already does better (verified in code):
- Sixteen AA-swept palettes with self-verifying contrast math in CI; Tarsi
  ships two brightnesses.
- The bank card system: brand gradients darkened until white clears AA,
  drawn chip, trademark-safe monograms, utilization warning.
- An enforced typography system with tabular money and a font-family test.
- Empty states with a way forward, honest error copy, Undo discipline.
- PH substance: utang both directions as a first-class tab, Sweldo
  Timeline, paluwagan, 13th month, verified BIR/tax lessons, offline Money
  Courses. Tarsi is Filipino-made but its feature language is generic.
- Accessibility depth: no text-scale disables, 37 screens machine-swept at
  1.5x, 18/18 icon buttons labeled, reduce-motion contracts.

What Salapify should learn: the fastest possible log as the default path
(the parsing already exists in Pan's matchers; put one free-text field at
the top of the log sheet that prefills type, amount, label); one decision
per first viewport; every chart states its own conclusion with at least one
printed number.

What Salapify must NOT copy: the tarsier name, mascot, or any
tarsier-adjacent character (a second animal reads as a clone of the current
PH #1); "Chat with X" AI framing (Pan's kapwa-coach framing is distinct);
Tarsi's paid-app positioning claims; bank logos as images (the monogram
approach is the right one and is Salapify's).

Where Salapify can differentiate: Pan reacting to the ledger with moods;
Money Courses with verified official sources, offline; utang culture
centered; sixteen palettes as a Gen Z ownership signal; PH institution
brand colors done right.

Scores side by side are in the executive summary table; the two changes
that close most of the perceived gap are the natural-language log field and
the stricter Home first viewport.

## 8. Recommended Salapify design direction

Three directions were developed from the actual product (not templates):

A. "Kapehan" (warm money coach): caramel-dominant, softer and rounder, Pan
on most screens, illustrated. Strong Gen Z warmth, but reads young and
soft for working adults tracking utang and 13th month pay, and an
illustrated coffee world fights the 8-theme system (a coffee-illustrated
Voltage is incoherent).

B. "Sweldo OS" (modern financial OS): dense, sharp, near-black, gridlines,
electric accents, Pan demoted. Premium and competitive with global
fintech aesthetics, but it is exactly the generic-fintech gravity the
founder wants to escape, discards the two most differentiated assets
(Barako warmth, Pan), and hits the wrong emotional register for utang
culture, where money talk carries shame the brand exists to disarm.

C. "Barako Modern" (calm precision, earned warmth): RECOMMENDED.
An OS-grade quiet foundation with a small fixed set of warm signatures
that fire only at human moments and survive every theme. Not a midpoint,
a division of labor: structure is precise and reserved; personality is
concentrated where it is earned.

Why C: it is what the codebase has been converging on by instinct. Every
good recent decision (Pan's fixed color, earned gold, the caramel kicker,
Pan only on first meetings, cash tile vs bank card) is a Barako Modern
decision. The overhaul names the direction and finishes it rather than
pivoting. It serves the audience spread: Gen Z gets Pan, gold moments, and
eight themes; working adults get density, tabular numbers, and a dark
coffee interior. And it is defensible: a palette can be copied, "the orange
coffee app whose cup cheers when you clear a debt" cannot.

Barako Modern, specified:
- Visual personality: a specialty coffee bar at night. Dark, warm, low-lit
  surfaces, one confident orange voice, gold reserved like a good bottle.
  Calm by default, alive at wins.
- Typography: Jakarta everywhere; the identity is the money-number system
  (heavy tabular figures, ₱ set in Barako.primary when it leads a hero
  figure, as the wordmark already does). Kickers stay the quiet connective
  tissue, one letterspaced style in the whole app.
- Density: medium. Heroes breathe, lists are efficient for daily loggers.
  Never Revolut-sparse, never spreadsheet-tight.
- Shapes: the re-cut Radii ladder; heroes get more corner than furniture.
  Exactly one proprietary curve added: the steam wisp (already drawn in
  PanCupPainter), used in exactly three places: pull-in refresh moment,
  100% progress, celebration. One curve in three places is a signature; in
  thirty it is a costume.
- Cards: three castes, made explicit. Bank-owned (brand gradient, white
  text), Salapify-owned money heroes (surfaceRaised, accent wash, caramel
  kicker, big tabular number), neutral reading surfaces (card + border).
  A screen should be readable by caste at arm's length; one raised hero
  per screen.
- Colors: Barako is the brand; the other seven themes are outfits it lets
  you wear (the picker already says "Barako is the Salapify look").
  Celebrate gold becomes theme-invariant. External surfaces are always
  Barako.
- Charts: one grammar via ChartFrame: primary series in theme primary with
  a soft gradient fill, secondary always caramel, gold markers only for
  records and goal hits, neutral ink for ordinary spending, red only for
  genuine risk, tabular axis labels, and every chart carries a caption
  sentence with at least one printed number.
- Motion: three verbs. Settle (press dip, Pan's single bob), count (hero
  numbers roll in tabular columns), celebrate (gold confetti plus Pan,
  under two seconds, full reduce-motion contract). No ambient loops.
- Iconography: keep the meaning-map architecture and the orange disc; a
  single rounded-stroke custom set is a later one-file swap the
  architecture was built for.
- Pan's role: the face of the relationship, not the interface. First
  meetings, the daily check-in, and earned wins (add Pan to celebrations
  and lesson finishes). Never on errors, never near warnings, never
  watching you overspend.

## 9. Screen consistency matrix

Legend: Y follows the system, ~ partial, X off-system. Columns: Type
(AppText discipline), Space (Gap usage), Card (list/card physics per the
Overview rule), Radius, Buttons/inputs, Charts (shared grammar), A11y
(swept at 1.5x).

| Screen | Type | Space | Card | Radius | Controls | Charts | A11y |
|---|---|---|---|---|---|---|---|
| Overview | ~ | X (12s) | Y (its rule) | ~ (ripple 12) | Y | X (flat sparkline) | Y |
| Activity/History | ~ | ~ | X (card/row) | ~ | Y | n/a | Y |
| Accounts | X (22 raw) | X | ~ | X (15 radii) | ~ | n/a | Y |
| Utang | X (23 raw) | ~ | X (card/person) | ~ | X (2 input skins) | n/a | Y |
| Budget | Y | X (12s) | Y | ~ | ~ | ~ | Y |
| Insights | ~ | X | X (20-card wall) | ~ | Y | X (no numbers) | Y |
| Cash flow | X (half-points) | X | Y | ~ | Y | Y (best) | Y |
| Reports | X (8.5px) | X | ~ | ~ | X (own segmented) | ~ | Y |
| Goals | X (19pt, 14.5) | ~ | ~ | ~ | X (own empty) | n/a | Y |
| Goal detail | X (32 raw) | Y | Y | ~ | Y | n/a | Y |
| Learn | ~ (27pt x3) | ~ | X (card+button wall) | ~ | ~ | n/a | Y |
| Log sheet | Y | ~ | Y | X (24 top) | X (own decor) | n/a | X (unswept) |
| Edit sheet | ~ | ~ | Y | X (28 top) | X (own decor) | n/a | X (unswept) |
| Menu | Y | X (13x 12s) | X (tile wall) | Y | Y | n/a | Y |
| Onboarding | X (30/24 invented) | Y | Y | Y | ~ | n/a | X (unswept) |

Outliers to fix first, by column: Space is the weakest column overall
(hence Phase 1); Cash flow and the sheets are the worst rows.

## 10. Before/after wireframes (text)

Only where the structure changes; screens not listed keep their structure
and receive token conversion only.

Overview (structure kept, weight re-cut):
```
BEFORE                          AFTER
[wordmark  search menu]         [wordmark  search menu]
Good evening                    Good evening
[HERO Your Number     ]         [HERO Your Number      ] raised, only hero
[Bills before payday  ]         [ONE contextual card   ] highest-ranked of
[Money check-in (Pan) ]           check-in/bills/payday/timeline
[Road ahead (flat)    ]         [fixed sparkline w/ numbers]
[Logging chain        ]         [chain + treat, one compact row]
[Treat card           ]         ---- borderless tail ----
[2 min lesson         ]         [lesson | this month | my money | net worth]
[This month][My money]            as rows-in-cards, background tint,
[Net worth footer     ]           no competing borders
```

Activity:
```
BEFORE: [card Groceries -2,450]   AFTER: Today            . total
        gap                              Groceries  -2,450.75
        [card Salary +32,000]           Salary    +32,000
        (one card per row,               (one card per DAY, divider rows,
         ~6 rows per screen)              ~12 rows per screen, amounts
                                          in one immutable style)
```

Insights:
```
BEFORE: 20 equal cards           AFTER: [DO NEXT: max 3 rows, one card]
                                        [HERO Safe to spend] raised
                                        [next peso card]
                                        [tools: collapsibles, flattened]
                                        [bigger picture: rows in ONE card]
```

Learn path:
```
BEFORE: every course =           AFTER: one CONTINUE hero card with
[card title/bar/big button]             button; other courses as
repeated 5x                             rows (title, bar, chevron)
```

Log/Edit sheets: same form body, same surface, same 24 top radius, same
amount size (28 tabular), same chips, one category chip row added (P0-1).

Menu: Ask Pan hero kept; each band becomes two-line rows (icon, label,
chevron) instead of 190dp tiles; 16 destinations fit in ~1.5 screens
instead of ~3.

Accounts: structure kept (it is close); flip hint moves into the card
caption line, section kickers align to one edge, radii snap.

Tools/Settings: token conversion only.

## 11. Implementation roadmap

Sequencing rule: tokens before components, components before screens, and
every phase leaves the suite green and ships behind the normal stamp/QA
discipline. All phases except the Fraunces removal are pure Dart,
Shorebird-patchable. Estimated sizes assume the existing test harness
(readability sweep, palette test, goldens) is extended as it goes.

Phase 1, design foundation (S, low risk):
- Scope: Radii re-cut with aliases; Gap.gutter; alpha ladder; Motion tokens
  + Motion.of; appBarTheme + bottomSheetTheme + completed chipTheme +
  corrected inputDecorationTheme in salapifyTheme; AppText.titleLg + hero;
  celebrate made theme-invariant; contrast test grows caramel/celebrate/
  positiveSurface pairs; new type-discipline test (fontSize/copyWith grep
  with allowlist), broken once on purpose to prove it fails.
- Files: theme.dart, typography.dart, palette_contrast_test.dart, one new
  test.
- Agents: design-systems-engineer equivalent for flutter, qa-tester.
- Risk: low; aliases keep visuals stable until conversion.

Phase 2, core components (M, low risk):
- Scope: EntryFormBody; SalapifyChoiceChip or chipTheme adoption;
  PrimaryButton; SalapifyProgressBar (animated); AmountText; ChartFrame;
  StatPair refactor; delete private _decor helpers; EmptyState adoption in
  goals/accounts/treats/paluwagan; Reports adopts shared Segmented.
- Files: widgets/*, log_sheet, edit_sheet, quick_add_editor, utang,
  split_expense, recurring, calculators, reports, goals, accounts, treats,
  paluwagan.
- Depends: Phase 1. Risk: medium on the sheets (highest-traffic path);
  journey tests cover log-then-edit round trip.

Phase 3, navigation and Overview (M, medium risk):
- Scope: Overview tail de-bordered and compacted; Road Ahead sparkline
  domain fix; ripple radii; card gap 12 to Gap.lg app-wide; Menu density;
  AppBar copies deleted.
- Files: overview.dart, timeline_sparkline.dart, menu.dart, ~30 AppBar
  sites.
- Depends: Phases 1-2.

Phase 4, money management (M-L, medium risk):
- Scope: History grouped-day list physics; category chips in log sheet
  (P0-1); amountRow discipline everywhere; Utang list physics and input
  merge; Accounts radii/type conversion; account detail dividers.
- Files: history, log_sheet, utang, accounts, account_detail, debts.
- Depends: Phase 2. The category write touches the data write path: the
  data-migration reviewer passes over it even though it is additive.

Phase 5, intelligence (M, low risk):
- Scope: Insights hero re-cut and card flattening; trend chart numbers;
  cashflow half-point purge; chart scrub with selection haptics; sub-floor
  font fixes in reports/insights.
- Files: insights, cashflow, reports, chart painters.

Phase 6, learning and tools (S-M, low risk):
- Scope: Learn path row conversion; lesson title unification (titleLg);
  calculators input adoption; treats/paluwagan conversion leftovers.

Phase 7, states and accessibility (S-M, low risk):
- Scope: readability sweep extended to the modal sheets and share screens;
  segmented wrap fix at large text; reduce-motion retrofit of the seven
  non-compliant files; save haptics (P1-12); month-step feedback.
- Files: screen_readability_test.dart, segmented.dart, the seven files,
  write paths.

Phase 8, visual regression and QA (S, ongoing):
- Scope: ui_golden baseline refreshed per phase (non-blocking, per the
  standing rule: pixel diffs inform, deterministic layout tests gate);
  journey test additions for log-edit-delete consistency; final
  consistency-matrix re-audit against this document; lunch-and-learn per
  delivery.

Deliberately excluded from this overhaul: the natural-language log field
(product feature, not design system; recommend it as the next feature after
Phase 4 lands, since EntryFormBody makes it cheap), receipt attachments
(scope call), Rive Pan and the custom icon set (art dependencies; the
architecture is ready when the art exists), Hero transitions (P3, needs a
BankCard in account_detail first).

## 12. Migration safety

- Presentation only: no storage shape, no money math, no backup schema, no
  routing changes. The one exception is P0-1 (category at log time), which
  is additive to an existing optional field and goes through the
  data-migration review lane regardless.
- Every phase keeps the full suite green; the tests that guard old behavior
  are not weakened to make a visual change pass.
- Radii/spacing conversions ship with before/after goldens rendered and
  LOOKED AT (and shown to the founder) per the standing screenshot rule;
  the readability sweep runs at 1.5x on everything it covers.
- The Fraunces asset removal is the only base-APK item; it rides the next
  natural release and gets flagged loudly, never patched silently.
- Per CLAUDE.md: every merge touching flutter/ ships and needs a unique
  stamp and a QA row, test-only changes included; nothing in this roadmap
  assumes a non-shipping flutter/ merge.

## 13. Final success criteria

The app should stop feeling like individually built Flutter features and
read as one financial product. Concretely measurable at the end:

1. Zero raw fontSize literals in screens outside the allowlist (test
   enforced), and zero off-ladder sizes.
2. One card gap (Gap.lg), one gutter (20), two card paddings (16/20),
   enforced by the shared card body.
3. At most 6 radii in lib, all tokens; ripples clip at card corners.
4. One input decoration, one chip style, one primary button, one segmented
   control, one empty state, one progress bar.
5. One list physics (rows in cards) on History, Utang, Overview alike;
   Activity shows roughly twice the rows per screen it does today.
6. Log and edit sheet indistinguishable in dialect; category capturable at
   log time.
7. Every chart states a number; the Home sparkline never renders as a flat
   block; the cash flow chart is scrubable.
8. Money writes are felt (lightImpact), milestones stay mediumImpact, and
   all animation respects reduce-motion through Motion.of.
9. The readability sweep covers the modal sheets; the Syste/m wrap is
   fixed.
10. Celebrate gold and Pan orange are theme-invariant; a screenshot of any
    theme is still recognizably Salapify by structure: one raised hero,
    kickers, tabular heavy numbers, the disc icons, the coffee warmth.

The benchmark question closes the loop: put the reworked Overview,
Activity, and log sheet next to Tarsi's. If the eye no longer concedes the
first five minutes, the system did its job, and Salapify keeps the depth
Tarsi does not have.
