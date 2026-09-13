# Design System Foundation

Sprint 1, 2026-07-10. Recommendations only; nothing here is implemented in
this sprint. The goal: one polished product, not seven screens that happen
to share a color. The foundation is already unusually strong for an indie
app: real tokens in mobile/theme.js, a theme context, a motion context, and
a handful of shared components. The gap is enforcement: about half the app
uses the shared pieces (Overview) and half still hand rolls them (Debts,
the LogSheet chips, TreatCard). The first job is closing that gap before
adding anything new.

## Benchmarks: what premium means for Salapify

What to steal:
- Apple Wallet: one hero surface per screen that owns the money number,
  big soft corners, and tabular numerals so digits never jiggle. The Card
  hero variant is already this shape; the job is making every screen use
  it.
- Monzo: feedback first. Every commit gets an instant honest response
  (toast plus Undo, a haptic) and destructive actions prefer Undo over
  scary dialogs. LogSheet's toast with Undo is already the Monzo pattern;
  make it the app wide standard.
- Revolut: motion quality. Numbers roll up, sheets glide, nothing
  stutters. AnimatedNumber and the duration and spring tokens already
  encode this; adopt Revolut's ceiling as law: nothing over about 260ms,
  ever.
- Copilot Money: category color discipline. Fixed color slots per
  category, never generated hues. CHART_CATEGORICAL with its CVD ordered
  slots is already better engineered than most fintechs. Keep it sacred.
- Linear: typography does the hierarchy, not decoration. Very few sizes;
  weight and color carry meaning; speed treated as a feature. The biggest
  lesson: the premium ceiling comes from deleting ad hoc font sizes, not
  adding fonts.

What NOT to copy:
- Revolut and Linear's cold, gray, corporate minimalism. Salapify is
  barako espresso, oat milk cream, Taglish praise lines, and Pan the
  mascot. Warmth is the identity: keep the cream backgrounds, the warm
  shadows, the human copy.
- Monzo's confetti everywhere gamification. The existing rule is right:
  celebrate only earned moments. Rare is what keeps it meaningful.
- Material Design defaults: no ripples, no FAB with label, no Material
  elevation ramps. The app has its own press language (the PressableScale
  spring dip) and its own elevation system. The one Material shaped thing
  kept is the FAB itself, because logging is the heartbeat action.

## 1. Typography

Exists: an 8 step fontSize scale and 4 named weights (theme.js lines 426
to 444), system font only. Line heights are ad hoc per screen (19, 16, 18
retyped across index.js, debts.js, TreatCard.js). tabular-nums is hand
applied in only 5 files and missing where it matters most: debts.js
totalDebt and AnimatedNumber itself.

Keep: the 8 step scale and exact sizes; the named weights and the written
rule that heavy is reserved for money numbers and page titles; the system
font (a custom font is a taste risk and load cost with no proven payoff;
revisit only if the brand demands it).

Change:
1. Promote fontSize to a full type token with paired line heights so no
   screen ever types lineHeight again: caption 12/16, small 13/18, body
   15/21, subtitle 17/23, title 22/28, big 28/34, huge 34/40 with letter
   spacing minus 0.5, display 42/48 with letter spacing minus 0.5. Keep
   fontSize exported for backward compatibility during migration.
2. Add a moneyText token (fontVariant tabular-nums, heavy weight, letter
   spacing minus 0.5) applied everywhere a peso figure renders. Tabular
   numerals are the single cheapest premium upgrade: digits stop shifting
   during AnimatedNumber roll ups and columns of amounts align. First
   fixes: AnimatedNumber (bake into its default style), debts.js
   totalDebt, rowAmount, sectionSubtotal.
3. Kill the two stray hardcoded sizes: fontSize 10 in the TreatCard earned
   tag and fontSize 11 in the tab bar label. Both become tokens chosen
   deliberately, not per file.
4. The kicker style (uppercase, letter spacing 1.2) exists in at least
   four files; export one kicker text token and reuse it.

## 2. Spacing

Exists: a clean 7 step scale, xxs 2 to xxl 32. Mostly respected, with
magic numbers leaking (marginTop 2, paddingVertical 4, FAB offsets).

Keep the scale. Change:
1. Add xxxl 48 for empty state breathing room and onboarding; nothing
   exists between 32 and screen level padding today.
2. Replace every marginTop 2 with spacing.xxs.
3. Write the rhythm rules down so they are checkable: screen gutter lg
   (16), gap between cards lg (the existing heroGap convention), inside a
   card md between related rows and sm between a label and its value,
   section header to its card sm.

## 3. Colors

Exists: 8 palettes, light and dark each, with genuinely semantic tokens
(background, card, surfaceRaised, border, primary, text, textSecondary,
muted, faint, warning, warningStrong, onPrimary, celebrate,
positiveSurface, positiveBorder, overlay) and documented rules: warning
reserved for debt and over limit, celebrate only for earned moments.

Keep the whole system; eight palettes with per palette AA tuning is a
feature, not debt. Do not add a ninth this horizon. The warning reserved
rule is hard law. The four step text ramp maps cleanly to hierarchy.

Change:
1. Rename softGreen (admitted legacy; it is caramel in barako, peach in
   forest, violet in ultraviolet). Add kicker or accent as an alias in
   every palette; migrate call sites over time; keep softGreen pointing at
   the same value so nothing breaks OTA.
2. Two missing semantic tokens get faked today:
   - inputSurface: inputs reuse colors.card and disappear against card
     colored sheets, invisible on dark themes. Give inputs their own token
     (dark: one step darker than card; light: background or a subtle
     fill).
   - warningSurface and warningBorder: the positive pair exists but over
     limit states have no tinted surface, so screens improvise. Add the
     pair per palette, AA checked.
3. Bake in the audit rule: every text token must pass 4.5 to 1 on card AND
   surfaceRaised, not just background (surfaceRaised is lighter than card
   on dark themes, which is exactly where faint fails today). Enforced by
   a small jest test over the palette object, cheap and OTA free.
4. Document that colors.primary is dual duty (interactive AND positive
   money). It works because warning is hue separated; every future palette
   must preserve that gap (barako documents 32 degrees).

## 4. Elevation

Exists: three named levels (flat, raised, overlay) with the smart insight
already encoded: on dark themes depth comes from surfaceRaised, not
shadow, and Card pairs them. The warm shadow color is a nice identity
detail.

Keep all of it. Change:
1. The FAB hand rolls a primary colored glow shadow. It is a deliberate,
   good choice, so name it: add elevation.glow (overlay geometry, color
   supplied by caller) so the FAB and any future celebratory surface share
   it.
2. LogSheet's overlay uses elevation 32 and zIndex 100 as a stacking hack.
   That is z order, not depth. The shared Sheet (section 12) uses
   elevation.overlay for the visual shadow and gets stacking from render
   order, killing the magic 32.
3. Rule: never a raw elevation or shadow property outside theme.js.
   Grep checkable.

## 5. Corner radius

Exists: sm 10, md 14, lg 20, xl 26, pill. Usage mostly coherent.

Keep the scale. Change:
1. Sheets are inconsistent with the documented intent: theme.js says xl is
   for hero cards and sheets, but every sheet uses lg top corners.
   Standardize sheets on radius.xl top corners; it reads noticeably more
   premium (the Apple Wallet and Monzo sheet look) and costs one line per
   sheet, then zero once the shared Sheet exists.
2. Write the mapping table into the doc: pill for chips, avatars, progress
   caps, FAB; sm for tiny tags and inline inputs; md for buttons, inputs,
   list tiles; lg for cards; xl for hero cards and sheets. No other
   values.

## 6. Icons

Exists: Ionicons outline variants for chrome, and emoji doing double duty
as UI icons (card emoji on debt rows, receipt emoji on the receipt button,
sparkle as the EmptyState default).

Keep: Ionicons as the one icon set, never a second. Emoji where the USER
chose them (account icons, category icons, treat emoji): that user
generated warmth is identity. The party emoji in Celebration stays; an
earned moment can be playful.

Change:
1. Emoji in chrome (buttons, empty state defaults) reads as unfinished,
   not warm, because emoji render differently per Android vendor and
   cannot be tinted. Replace the receipt button glyph with Ionicons
   receipt-outline, and the EmptyState default with either an icon prop
   or, better, small Pan mascot poses (the mascot components already
   exist). Pan in empty states is the single best place to spend identity
   budget; it is what Monzo does with its illustrations.
2. Standardize sizes: 16 inline chevrons, 18 row actions, 22 tiles and
   list leads, 24 tab bar and headers, 30 FAB only. All five already
   occur; the rule forbids new ones.
3. Rule: an icon never appears without a text label or an
   accessibilityLabel, and icon only buttons meet 44pt (the 40pt search
   button gets bumped or gains hitSlop).

## 7. Animations

Exists: the strongest area. Central durations (120, 180, 220, 260),
easing beziers, three spring presets, pressScale 0.97, a MotionProvider
that reads reduce motion app wide, and components that respect it with
subtle judgment (opacity dip instead of scale under reduce motion, the
success haptic surviving reduce motion in Celebration).

Keep everything, and write the implicit conventions down as law:
- Durations only from the duration token; the ceiling is 260ms for hero
  count ups and bar fills; everything interactive is 120 to 220ms.
- Springs only from the spring token: press for touch, gentle for
  surfaces, bouncy only for earned celebrations.
- Every timing and spring passes the system reduce motion flag AND the
  component checks useReduceMotion for structural changes like skipping
  confetti. Both, always.
- Motion never gates input: onPress fires immediately, never waits for a
  tween.
- Transforms and opacity only; no animated width, height, or margin
  except the keyboard lift, the one legitimate padding animation.

Change:
1. LogSheet's toast still uses the old Animated API with hand typed
   values; migrate to Reanimated with spring.gentle and duration.fast when
   the shared Toast is extracted, so there is exactly one animation
   system.
2. Standardize screen transitions: pushed screens use the platform default
   slide; sheets animate with spring.gentle translateY plus a
   duration.base backdrop fade. Written down so nobody adds a custom 400ms
   transition.
3. A named entrance convention: a single FadeIn at duration.base on mount,
   no staggered cascades. Cascades read as slow on budget Android and
   violate the never delay a tap rule.

## 8. Buttons

Exists: no Button component. The save and cancel pair is copy pasted in 14
files (69 occurrences), plus ad hoc one offs. Press feedback is
inconsistent (some PressableScale, most a pressed opacity change).

This is the highest leverage component of the plan. Proposed API: a Button
with variant (primary, secondary, ghost, destructive), size (md at 44pt
minimum height, lg at 52pt), label, optional leading Ionicons icon,
loading (spinner replaces label, keeps width, disables), disabled, haptic
kind, onPress.

Mapping: primary is the colors.primary fill with onPrimary bold text
(replaces saveBtn, allocBtn); secondary is card fill with border
(replaces cancelBtn, addBtn); ghost is primary text on no fill (replaces
markPaid, coachBtn); destructive is warning text on transparent or
warningSurface (replaces deleteBtn), paired with the existing tap to
confirm pattern, which is good and becomes the standard for in sheet
deletes.

States: pressed (PressableScale dip plus haptic), disabled (opacity 0.5,
accessibilityState disabled, label stays 4.5 to 1), loading
(accessibilityState busy, input blocked). Radius md, horizontal padding
lg, body type at bold for primary and medium otherwise. Do not build more
than these four variants; Monzo ships with essentially three.

## 9. Cards

Exists: the shared Card is excellent (flat, raised, hero variants;
pressable with spring and haptic; warning border reserved correctly;
surfaceRaised pairing on dark). Overview is fully migrated.

Keep the API exactly as is. Change:
1. Finish the migration: hand rolled card styles still live in debts.js,
   TreatCard.js, and other unmigrated screens. Each replacement deletes 5
   to 7 style lines and gains the press spring for free.
2. focusCard (debts) and planBorder (home) are the same idea, the card
   asking for action. Add a highlight prop on Card (primary border, same
   precedence slot as warning) so it stops being restyled per screen.
3. Add a shared ListRow: icon or emoji lead, name plus sub line, right
   aligned amount in the moneyText token, hairline divider, 44pt minimum
   height, optional chevron. The row pattern is hand built in at least
   three screens; one component fixes alignment and typography for every
   list at once.

## 10. Charts

Exists: TrendChart (Skia lines with a web and error fallback and its own
error boundary), Bar (single fraction, GPU scaleX, decorative by design
for accessibility), and the CHART_CATEGORICAL fixed slot system with CVD
ordering.

Keep all three, and canonize the rules already living in comments: slots
assign in fixed order and never cycle, the 8th plus category folds into a
neutral more; legends and segment gaps are the required secondary
encoding, color alone never carries meaning; every chart is decorative to
screen readers with a spoken summary on the wrapper (TrendChart shows the
correct Android safe nesting, copy that pattern); Skia on native, View
fallback on web and on render failure.

Change:
1. Write down the line language currently trapped in one file: stroke
   width 3.5, round caps and joins, dots 4.5 with the newest point at 7
   plus a card colored ring; single series charts get the 0.13 opacity
   area wash, two series never do.
2. Add draw in motion: animate the line path from 0 to 1 over
   duration.slow with the decelerate easing on first mount, skipped under
   reduce motion. Skia paths animate cheaply with Reanimated shared
   values; this is the Revolut grade touch Insights is missing, and it is
   OTA safe.
3. Rule: magnitudes clamp at 0, comparable series share a scale, no dual
   axes ever.

## 11. Forms

Exists: the worst duplication in the app. The same input style block is
retyped in five plus files. Chip styling is copy pasted across 12 files
(41 occurrences); targets are about 34pt (26pt in PeriodSelector's mode
chips); only PeriodSelector announces selection state.

Chip (build first; it deletes roughly 150 lines across 12 files and fixes
the accessibility gap everywhere at once): label (emoji plus text or
separate icon), selected, onPress, disabled. Spec: minimum height 44 (or
visual 36 plus hitSlop reaching 44 if grid density demands it; pick one
and write it down), radius.pill, card fill with border when off, primary
fill with onPrimary text when on, accessibilityRole button,
accessibilityState selected, selection haptic, PressableScale press.

Input and Field: a Field wrapper (label, error, hint) around an Input.
Spec: the new inputSurface token, radius.md, body type, a focused border
shifting to colors.primary (no focus state exists anywhere today, a real
polish gap), error border in warning with the error text as an assertive
live region. The label, hint, and error stack is retyped per screen today.

Also fold PeriodSelector into the system: it is the one component taking
colors as a prop instead of useTheme; migrate it and rebuild its mode
chips on the shared Chip.

## 12. Bottom sheets

Exists: LogSheet is the flagship and its overlay logic is genuinely
sophisticated (keyboard lift via useAnimatedKeyboard mounted only while
open, hardware back handling, receipt cleanup on cancel). But the sheet
visual shell is retyped in the salary modal, the debt editor, and
elsewhere, with two different mechanisms (in window overlay versus native
Modal).

Audit findings baked in as spec: the footer (Cancel and the primary
action) is a sibling of the ScrollView, pinned above the keyboard lift
with a top hairline, never inside the scroll; the sheet sets
accessibilityViewIsModal, announces its title as a header, and returns
focus on close.

Proposed Sheet API: visible, onClose, title, footer (buttons), children
(scrollable form content). Spec: overlay color from colors.overlay with a
duration.base fade; the sheet slides up with spring.gentle (appears in
place under reduce motion); radius.xl top corners; a grab handle bar (36
by 4, colors.border, pill) as the modern sheet signifier; max height 90
percent; keyboard lift and back handling moved in from SheetOverlay;
padding xl. LogSheet migrates first as the proof, then the salary modal,
then the debt editor.

## 13. Dialogs

Exists: native Alert.alert for destructive confirms, and an inline tap to
confirm for in sheet deletes.

Keep both, deliberately. Native alerts are free, fully accessible, and
honest; a custom skinned dialog buys beauty and costs accessibility, so
none gets built this horizon. Tap to confirm is fast and undoable by
simply not tapping again (add a timeout reset where missing). Rules:
destructive buttons use the destructive style in alerts and the
destructive Button variant elsewhere; prefer Undo over confirmation
whenever the action is reversible; never stack dialogs (LogSheet already
guards this).

## 14. Navigation

Exists: expo-router tabs, a fixed bar height of 78 plus insets, a
hardcoded 11pt label, a selection haptic on tab press (a great touch), and
the 56pt FAB positioned off the bar height.

Keep: the six tab structure (the tab CONTENT question, Tools versus a
unified Debts and Utang tab, is a product decision tracked in the backlog,
not a design system matter), the selection haptic, the FAB as the
heartbeat action with its glow.

Change:
1. The audit's font scale break: at font scale 2.0 an 11pt label renders
   at 22pt and clips inside the fixed 78pt bar. Derive the height from the
   OS font scale (capped near 1.6) instead of hardcoding, and set the same
   cap as maxFontSizeMultiplier on the label. The FAB and toast offsets
   already derive from bar height, so they follow for free.
2. The label size becomes a token, not a raw 11.
3. Use filled icon variants for the active tab (home versus home-outline):
   the standard signal, costs nothing, and strengthens the selected state
   beyond color alone, which also helps color blind users.
4. Standardize the screen header recipe (each screen draws its own): the
   Overview pattern (greeting row, 44pt avatar, search) documented, and
   every pushed screen title in title type at heavy weight.

## 15. Dark mode

Exists: 8 palettes by 2 modes, barako default, system following with a
dark fallback before the phone reports (correct for a dark first app),
persisted separately from the main blob.

Keep everything structural. The warm cream light modes instead of pure
white are a distinctive premium choice; never flatten them.

Change: codify the depth rule per mode (dark layers with surfaceRaised
color, light layers with shadow, Card already pairs them; any new surface
goes through Card or copies the pairing); add the surfaceRaised contrast
check to the palette checklist and the jest palette test (8 palettes by 2
modes by 4 text tones is 64 pairings per surface, only safe as a test);
keep the per palette warm black overlays (a generic black overlay would
cool the whole app down).

## 16. Accessibility (laws of the system, not per screen fixes)

1. 44pt minimum targets on everything tappable, enforced once in Chip and
   Button rather than per screen.
2. 4.5 to 1 contrast for all text tokens on ALL surfaces they can sit on
   (background, card, surfaceRaised, positiveSurface, warningSurface),
   enforced by the palette test.
3. Selected states announced: accessibilityState selected on every chip,
   toggle, and segmented control (PeriodSelector is the reference).
4. Live regions for async feedback: errors as assertive alerts with a
   text prefix (the salary modal is the reference), toasts polite,
   celebrations announced with the timing delay Celebration already gets
   right.
5. Decorative elements hidden; the real value always in text nearby.
6. Dynamic type: no fixed heights around text (the tab bar fix is the
   flagship); money heroes may cap near 1.4x so a display size number
   cannot blow the layout, body text scales freely.
7. Reduce motion: same final state, same information, no tween; haptics
   preserved for confirmations by design.
8. Modals trap the screen reader (accessibilityViewIsModal); headings use
   the header role (SectionHeader already does).

## 17. Micro interactions

Exists: useHaptic with 7 kinds, PressableScale, AnimatedNumber,
Celebration, the LogSheet toast with rotating Taglish praise.

The haptic vocabulary, written down so it never inflates: selection for
tabs, chips, toggles; light for a tap landing on a card or row; medium for
the FAB and primary commits; success for money wins only (debt paid, utang
cleared, goal hit), never for an ordinary log; warning and error reserved
for destructive confirms and failures; never buzz for something the user
did not do.

Rules for the delight components: AnimatedNumber on hero figures only, at
most one or two per screen (a screen full of rolling numbers reads as a
slot machine, the opposite of calm); Celebration for earned rare moments
only, and adding a trigger is a design decision, not a code change in
passing (confetti capped at 16 pieces, chart colors, never warning hues);
the toast plus Undo is the standard response to every write, extracted
into a shared component so debt payments and goal deposits get the same
treatment as logs.

One small new build worth it: a subtle settle on the safe to spend hero
when a log lands (a single gentle spring from 1.02 scale to 1), so logging
visibly feeds the number the user cares about. One shot, reduce motion
aware.

## Build order (feeds Sprint_Plan.md)

1. theme.js token additions (type with line heights, moneyText, kicker,
   inputSurface, warningSurface pair, spacing.xxxl, elevation.glow). Pure
   additions, zero risk.
2. Chip component; migrate all 12 files. Biggest accessibility and
   duplication win.
3. Button component; migrate the 14 save and cancel files.
4. Sheet component with pinned footer and modal accessibility; LogSheet
   first, then the salary modal and debt editor.
5. Input and Field, ListRow; migrate debts.js fully onto Card,
   SectionHeader, and ListRow (the most drifted screen).
6. Tab bar font scale fix and label token.
7. Polish passes: tabular numerals sweep, sheet radius, chart draw in,
   hero settle.

Everything above is JavaScript only (Reanimated, Skia, expo-haptics, and
Ionicons are already in the binary), so the entire design system
foundation ships over the air. Each migration step keeps the jest suite
green, passes the Babel compile check, and bumps the update stamp per the
working rules.
