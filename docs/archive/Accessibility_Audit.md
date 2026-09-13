# Accessibility Audit

Sprint 0 engineering audit, 2026-07-10. Scope: mobile/, Android first
(TalkBack), all 8 themes in light and dark. Review only, no files modified.
Effort scale: S under 1 day, M 1 to 3 days, L 1 to 2 weeks.

## What is already good (acknowledge the existing work)

There is real, deliberate accessibility engineering in this codebase, well
above typical seed stage React Native apps:

- TrendChart TalkBack pattern (mobile/components/TrendChart.js lines 153 to
  169): the chart is one focusable element with a full spoken data summary,
  and the correct Android trick of putting no-hide-descendants on an inner
  wrapper so the outer label survives. The label is built with formatMoney per
  point (insights.js lines 433 to 435 and 685 to 688), so money announces with
  currency.
- Bar component (components/Bar.js lines 96 to 99): decorative bars hidden
  from the reader by design, with the value always in adjacent text.
- AnimatedNumber (components/motion/AnimatedNumber.js lines 96 to 127): the
  rolling number carries an accessibilityLabel of the final formatted value so
  a reader never hears a mid roll number, and it renders plain Text under
  reduce motion.
- Home screen cards (app/(tabs)/index.js lines 450 to 456, 517 to 523, 567 to
  574): pressable money cards are grouped, role button, label includes the
  money and the destination, and inner duplicate numbers are hidden. This is
  the gold standard the rest of the app should copy.
- Insights legends and DO NEXT rows (insights.js lines 314 to 333, 393 to 408,
  464 to 486): grouped accessible rows with full labels including money and
  percent, proportion bars hidden as decorative.
- Salary modal error handling (index.js lines 690 to 698): accessibilityRole
  alert plus assertive live region, with Error prefixed. Correct.
- Motion: a single reduce motion source of truth (context/Motion.js),
  respected by PressableScale, Bar, AnimatedNumber, and Celebration.
  Celebration (components/motion/Celebration.js) even fires the success haptic
  under reduce motion and announces the win with announceForAccessibility
  because confetti is hidden from the reader.
- PeriodSelector (components/PeriodSelector.js lines 59 to 79): uses
  accessibilityState for selected and disabled, plus labeled chevron steppers
  with hitSlop.
- Color as signal: warning hues reserved for debt with documented hue gaps
  (theme.js lines 24 to 29), chart categorical colors CVD validated with
  segment gaps and legends as the required secondary encoding, over budget
  states always come with words, and the WeekChain filled dots carry a check
  glyph, not just color.
- No allowFontScaling false anywhere; the one font scale cap is a bounded,
  commented maxFontSizeMultiplier 1.5 on the net worth hero paired with
  adjustsFontSizeToFit, a defensible tradeoff.

The problem is that this quality is concentrated in Home, Insights, and the
shared chart components. The main logging flow and the Debts flow did not get
the same pass.

## Findings, most blocking first

### A11Y-1: LogSheet is not modal to TalkBack, so the core flow leaks focus into the screen behind it

Severity: Critical | Effort: S
Where: mobile/components/LogSheet.js lines 623 to 633 (SheetOverlay), 640
(overlay style).
What is wrong: the add entry sheet is an in window overlay, not a native
Modal, and there is no accessibilityViewIsModal on the sheet and no
importantForAccessibility no-hide-descendants on the screen behind it. The
comment at line 639 notes the tabs stay live behind it for touch, solved with
elevation, but nothing solves it for TalkBack. Compare with the salary modal
which uses a native Modal plus accessibilityViewIsModal (index.js lines 676
to 678). The backdrop Pressable (line 629) is also an unlabeled clickable
element.
Business impact: logging is the heartbeat of the whole app. If a blind or low
vision user cannot reliably add an entry, the product has zero value to them.
Technical impact: TalkBack linear navigation walks out of the sheet into the
tab bar, the FAB, and the whole screen underneath.
User impact: a TalkBack user opening Add entry gets a mixed stream of sheet
fields and background content, can accidentally activate the screen behind,
and may dismiss the sheet by double tapping an unlabeled element.
Recommendation: either render the sheet in a native Modal (Android Modals are
separate windows, so TalkBack focus is contained for free), or keep the
overlay and add accessibilityViewIsModal on the sheet View plus
no-hide-descendants on the tab content while visible. Give the backdrop a
role and label (Close add entry). Announce the sheet title on open.

### A11Y-2: No selected state on any chip or toggle in the logging and debt flows

Severity: Critical | Effort: S (M if extracting a shared Chip component,
which is recommended)
Where: LogSheet.js lines 328 to 346 (Expense/Income toggle), 359 to 363 (date
chips), 401 to 421 (category chips), 455 to 468 (currency chips), 523 to 537
(account chips); debts.js lines 385 to 389 (Snowball/Avalanche), 437 to 441
(debt type chips), 541 to 548 (Paid from chips); index.js lines 703 to 715
(salary account chips).
What is wrong: selection is shown only by fill color. No accessibilityRole
button, no accessibilityState selected. PeriodSelector.js already does this
correctly; nothing else does.
Business impact: money correctness. Which account the salary lands in, which
currency an expense is in, and whether an entry is an Expense or an Income are
all invisible states to a screen reader.
Technical impact: TalkBack reads each chip as plain text with no role and no
selected, so the user cannot tell Expense from Income mode before saving.
User impact: a blind user can log an expense as income, or against the wrong
account or date, and never know. In a finance app this is the getting a
balance wrong has real cost scenario.
Recommendation: on every chip Pressable add accessibilityRole button and
accessibilityState selected. One shared Chip component would fix all nine
sites at once and prevent regressions.

### A11Y-3: Errors and confirmations in LogSheet and Debts are silent to the screen reader

Severity: High | Effort: S
Where: LogSheet.js line 581 (error text shown in warning color only, no alert
role, no live region, no Error prefix; the identical error in the salary modal
does this correctly). LogSheet.js lines 594 to 614: the success toast with
Undo has no live region, while the Budget copy of the same toast has one
(budget.js line 338). debts.js lines 550 to 556 and 632 to 634: Mark paid off
and Delete are two tap confirms whose only feedback is the button text
changing; nothing is announced. debts.js lines 557 and 629: the payment result
message and the form error render without live regions.
Business impact: failed saves that feel like successes, and destructive
actions armed without the user knowing.
Technical impact: color plus silent re-render is the only signal. The error is
red text with no icon or prefix in LogSheet, which also fails the not color
alone rule.
User impact: a TalkBack user taps Add, validation fails, and they hear
nothing. They tap Delete once, hear nothing, tap again later and delete a debt
they meant to keep. The 4 second Undo window is unusable if you never hear the
toast.
Recommendation: copy the salary modal pattern everywhere: alert role plus
assertive live region plus an Error text prefix on every error or message
Text. Add an assertive live region to the LogSheet toast container. For two
tap confirms, call announceForAccessibility when arming.

### A11Y-4: faint text fails WCAG AA on raised surfaces in dark themes and on cream backgrounds in warm light themes

Severity: High | Effort: M
Where: mobile/theme.js palette definitions, used across all screens.
Measured pairs (normal size text, needs 4.5 to 1):
- Barako dark faint #97806F on surfaceRaised #2E211A: about 4.2 to 1, fail.
- Ultraviolet dark faint #897FB2 on surfaceRaised #28214F: about 4.0 to 1, fail.
- Voltage dark faint #768093 on surfaceRaised #1C1F2B: about 4.1 to 1, fail.
- Barako light faint #867162 on background #F7F1E7: about 4.1 to 1, fail.
- Ember light faint #877262 on background #FBF4EE: about 4.1 to 1, fail.
- Borderline passes with zero headroom: barako dark faint on card 4.6, barako
  light faint on card 4.5, mint light faint on white 4.6.
The theme comment saying every text pairing passes WCAG AA (theme.js line 20)
was true for text on card and background at the time, but surfaceRaised was
added later and faint was never rechecked against it.
Business impact: the faint tier carries real information: rate hints, carry
over notes, bill due hints, footnotes. Low vision users and anyone on a cheap
low brightness AMOLED panel in sunlight, which is the target hardware, lose
it.
Technical impact: WCAG 1.4.3 failure on specific token and surface
combinations, not a general palette failure.
User impact: working parents with aging eyes squint at exactly the explanatory
text meant to make money less scary.
Recommendation: for each dark palette, lighten faint until it clears 4.5 to 1
against surfaceRaised (the worst surface). For barako and ember light, darken
faint to clear 4.5 to 1 against background. Add a test in __tests__ that
computes contrast for every text token and surface token pair per palette so
this can never regress silently.

### A11Y-5: Quick add, check in, and list row pressables miss roles and grouped labels

Severity: High | Effort: S to M (mechanical, roughly 25 sites)
Where: LogSheet.js lines 381 to 390 and budget.js lines 269 to 278 (quick add
buttons, no role, no hint that one tap immediately logs money);
TreatCard.js lines 98 to 110 (check in button, no role) and lines 71 to 94
(two adjacent Pressables both open /treats, tiny header target, no roles);
debts.js lines 672 to 687 (debt row Pressable with no role, decorative card
emoji not hidden so TalkBack reads it first); more.js navigation rows (lines
77, 110, 126, 130, 142, 202) without button roles; assorted text buttons
(budget.js line 203, debts.js line 372, LogSheet.js lines 583 to 588,
index.js lines 353, 402, 703 to 725).
Business impact: the habit loop (quick add, treat check in) is the retention
engine; it should be first class for every user.
Technical impact: missing roles mean TalkBack does not say button or double
tap to activate, and missing hints on quick adds mean no warning that money is
written immediately.
User impact: hesitation and accidental logs. A quick add that instantly writes
150 pesos should say Food, 150 pesos, button, double tap to log this expense.
Recommendation: add accessibilityRole button everywhere a Pressable acts as
one. For quick adds, add a money label and a Logs this expense now hint. Hide
decorative emoji with importantForAccessibility no, as WeekChain.js line 103
and TreatCard.js line 77 already do.

### A11Y-6: Dynamic type hazards, mainly the fixed height tab bar and single line truncations

Severity: Medium | Effort: S
Where: app/(tabs)/_layout.js lines 26 and 66 to 70: tab bar height fixed at 78
plus insets with an 11 point label; Android font scale goes to 2.0, so the
label scales to 22 points inside a fixed height bar and clips.
LogSheet.js line 607: numberOfLines 1 on the toast text; at large font sizes
the amount can be the truncated part (the Budget copy correctly allows
wrapping). insights.js lines 856 to 862: hbarValue fixed width 72 with
adjustsFontSizeToFit quietly defeats the user's font setting.
TreatCard.js line 138: EARNED tag at font size 10 with 1 pixel vertical
padding, below the sensible floor.
Positives: no allowFontScaling false anywhere, rows use minHeight not height,
sheets scroll, lineHeights scale with the font.
Business impact: older working parents are precisely the users who set font
size to Large on day one.
User impact: tab labels clipped at the bottom of every screen; the log
confirmation toast truncates the amount.
Recommendation: let the tab bar grow (compute height from fontScale or use
padding instead of fixed height, or a bounded maxFontSizeMultiplier of about
1.3 on the tab label). Remove numberOfLines 1 from the LogSheet toast. Replace
the fixed width on hbarValue with minWidth and flex.

### A11Y-7: Tap targets under 44 points on chips and small controls

Severity: Medium | Effort: S
Where: PeriodSelector.js lines 122 to 129: mode chips are about 23 points
tall, no hitSlop, the worst offender. LogSheet.js line 664, index.js line 911,
and the debts chips: about 31 points tall. TreatCard.js line 71 header
Pressable: about 24 points effective. Borderline but acceptable: budget
receipt icon about 43 points effective, trash about 48, coach dismiss exactly
44.
Business impact: cheap phones mean imprecise digitizers; missed taps on the
date chip mean wrongly dated money entries.
User impact: users with tremor or big thumbs mis tap Yesterday and log to
Today, or cannot switch Month and Year on Insights.
Recommendation: add minHeight 44 (or hitSlop making up the difference) to the
shared chip style and the PeriodSelector mode chips. Fold the TreatCard header
Pressable into the body Pressable and make the chevron decorative.

### A11Y-8: WeekChain and the weekday chart read as fragment streams

Severity: Medium | Effort: S
Where: WeekChain.js lines 89 to 110: TalkBack walks dot by dot and letter by
letter. The message line does carry the summary, which is why this is Medium
not High, but which specific day is missing is visual only. insights.js lines
758 to 771 (Pro weekday chart): bars plus single letters, no spoken summary of
the bars themselves.
Recommendation: apply the TrendChart pattern already built: make the dots row
one accessible element with a label like Logged Monday, Tuesday, Thursday,
missed Wednesday, and hide the letters and dots behind it. Same for the
weekday bars.

### A11Y-9: Legacy Animated code ignores reduce motion

Severity: Low | Effort: S
Where: index.js lines 134 and 189 to 201 (peak pill, plan pop), WeekChain.js
lines 51 to 69 (dot springs and stagger), budget.js lines 117 to 128 and
LogSheet.js lines 186 to 192 (toast springs) all use the old Animated API with
no useReduceMotion check, while every Reanimated component respects it.
User impact: small springs and pops still play for vestibular sensitive users
who asked for calm. None are large motions, hence Low.
Recommendation: read useReduceMotion and skip the spring when true, matching
the documented convention in theme.js line 479 that currently overpromises.

### A11Y-10: Chart amber below 3 to 1 as a graphical object on white cards

Severity: Low | Effort: S
Where: theme.js line 371: #eda100 (light slot 3) is about 2.2 to 1 against the
white card; #1baf7a is about 2.3 to 1. WCAG 1.4.11 wants 3 to 1 for meaningful
graphics. Mitigation already in place: segment gaps and a text legend carrying
label, amount, and percent, so no information is lost.
Recommendation: nothing urgent. If retuning, darken those two light mode slots
slightly; keep the fixed slot order rule.

### A11Y-11: Emoji noise in spoken strings

Severity: Low | Effort: S
Where: toast strings embed emoji (LogSheet.js lines 40 and 185, budget.js line
40) so once A11Y-3 adds live regions, TalkBack will speak the emoji names
before the money. Celebration's party pill is already hidden and replaced by a
spoken message, which is the right pattern.
Recommendation: keep emoji visually but move them out of the announced string
via a separate accessibilityLabel or a hidden emoji Text.

## Verdict

TalkBack user today: not usable end to end. The read only surfaces are
genuinely good, among the best at this stage: Home announces grouped cards
with currency, Insights charts speak their data, decorative bars are hidden,
celebrations are announced. But the two flows where money is written, the
global add entry sheet and the debt payment modal, fail: the sheet does not
contain focus (A11Y-1), every selection chip is stateless to the reader
(A11Y-2), and errors, confirmations, and the success toast are silent
(A11Y-3). A blind user can browse their money but cannot safely log it, which
in this app means they cannot use it. A11Y-1 to A11Y-3 are all small, pattern
copying fixes; roughly two to three days of work makes the core loop honestly
usable.

Low vision user today: mostly usable, with two real risks: the faint tier
contrast (A11Y-4) and the fixed height tab bar plus truncating toast at large
font sizes (A11Y-6). Fix those and the app is comfortably above the bar for
the audience it serves.

Suggested order: A11Y-1, 2, 3 as one batch (the logging flow), then 4 and 6,
then 5 and 7 as a mechanical sweep, then 8 to 11 as polish.
