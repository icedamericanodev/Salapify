# Pan returns as a character: review note

Date: 2026-10-08. Decision: D30 in `docs/revamp/07-decisions.md`.
Briefs: `docs/revamp/pan-handoff.md` (phase 1) and `docs/revamp/pan-motion.md`
(phase 2). Renders: [pan/README.md](pan/README.md).

## Scope

Pan, drawn from the founder's 19 images, on the empty states that greet a
person, animated, and interactive. Founder direction on the day added "build
freely, explore maximum capability of flutter ... make it more interactive",
which this note treats as the answer to the one open question below.

## What changed

1. **Files.** The founder's art, briefs and mockups, copied unedited to the
   paths named in the package (commit `0d6b9ab`). `assets/pan/` is listed in
   `app/pubspec.yaml`.
2. **D30 recorded**, D2 amended for the one item, and the Stitch prompt line in
   `06-tooling.md` updated.
3. **`app/lib/design/pan_art.dart`**, one file holding all of it:
   - `PanMood` (all 19 images) and `panAsset(mood)`.
   - `PanArt(mood, size)`, capped at 96 and silent to screen readers.
   - Four nested layers pivoting at his feet: entrance pop, travel (float or
     hop), body (rock, breathe or tilt), and tap squash.
   - Per-mood effects, painted rather than built from widgets: sparkles, z
     letters, glows, glints and thinking dots. Their positions and timings
     were read from `motion-preview.html`.
   - The drawn shadow replaces the one baked into the PNGs. The bottom 7.5% of
     each image is clipped off, and the drawn shadow shrinks and fades when he
     floats or hops.
   - `panIdleCycles = 3`. Each idle layer plays three cycles and then rests.
   - `PanEmptyContent`, which runs the title, body and button rise-in at 560,
     630 and 720 ms, and Home's two rings at 1500 ms.
   - Built only on Flutter's `AnimationController`, `Transform`,
     `CustomPaint` and `SpringSimulation`. No new packages.
4. **Interactivity beyond the brief**, at the founder's request:
   - A tap squashes him with a light buzz and throws a small burst of
     sparkles.
   - Three quick taps and he winks (`pan_wink`) for 1.4 seconds.
   - Drag him SIDEWAYS and he leans after the finger on a rubber band, then
     springs home with a wobble. It is sideways only so a scroll that starts
     on him still scrolls.
5. **`app/lib/features/shared/pan_empty_card.dart`**, the card for the five
   screens that had no empty state before.
6. **Where Pan appears.** Each shows only when that thing is truly empty.

   | Screen | Mood | When | Button |
   |---|---|---|---|
   | Home | wave | the book has no entries; replaces the Today row | Log your first entry, with rings |
   | Activity | sleep | no entries and no filter | none (unchanged) |
   | Plan, Budgets | idea | no budgets | none, see finding 1 |
   | Plan, Goals | idea | no goals | the existing Add a goal above it |
   | Accounts | coin | no accounts in the book; replaces the zero net worth card | Add your first account |
   | Reports, Performance and Cash flow | thinking | no entries in the book; replaces "No entries in this period" | none |
   | Debts, You owe | calm | nothing owed | none (unchanged) |

   "Nothing matches these filters" and "Nobody owes you anything" keep their
   icons: a not-found and a neutral fact, not a greeting.
7. **Plan, Budgets with no budgets** no longer shows "₱0.00, Every budget on
   track" above the empty card. That line was true of an empty list and read
   as a verdict on budgets that do not exist.

## What did NOT change

- **Money:** no calculation, figure, sign or rounding.
- **Stored data:** no field, key, backup or migration. Pan stores nothing.
- **Navigation:** no tab, route or sheet added, moved or removed. Every
  button opens a sheet that already existed.
- **Copy on existing screens:** unchanged. New text exists only on the five
  new empty states. It follows the mockups, rewritten where the mockup's
  sentence was not true of this app (Home already leads with Safe to spend,
  and Budgets cannot be set from the app).
- **D30 limits:** no chat added, no streaks or scores, and no annoyed, tear or
  crying mood. A test enforces the last.

## Validation

- `flutter analyze`: no issues, on the 3.47.4 pin.
- Full suite: 2,203 pass, 0 fail, with the new tests below.
- Readability and palette sweeps: pass.
- Renders: all seven screens, dark then light, plus the frame strip; see
  [pan/README.md](pan/README.md).

Each new guard was broken once and seen to fail, then restored after the run
reported:

| Test | Break | Failure line |
|---|---|---|
| `pan_art_test` every mood has art | `pan_sleep.png` moved aside | `Actual: ['assets/pan/pan_sleep.png']` |
| `pan_motion_test` reduce motion | PanArt ignores reduce motion | `Expected: false Actual: <true>` |
| `pan_motion_test` idle stops | clock `repeat()` instead of `forward()` | `pumpAndSettle timed out` |
| `pan_motion_test` tap restarts | `forward()` instead of `forward(from: 0)` | `the second tap did not restart the squash` |
| `pan_screens_test` Home door | button does nothing | `the first-entry button did not open Log` |
| `pan_screens_test` no Pan over real money | Pan always shown | `Found 1 widget with type "PanArt"` |

## Deviations from the briefs

1. **The briefs were drawn from main's older `app/`**, the c1 design with
   `kit.dart`, "Ledger" and "Insights". The live `app/` restarted under D24
   and has none of them, so:
   - The moods were mapped by meaning: Ledger is Activity, Insights is
     Reports.
   - The `EmptyState` the brief extends does not exist. Activity and Debt
     swapped their own icon, and the other five use the new `PanEmptyCard`.
2. **Five of the seven screens had no empty state at all** and got a new one.
   The founder's "build freely" settled that.
3. **Home's button is inside the card**, not under it as in the mockup, so
   the card is one unit.
4. **Effect timing** follows `motion-preview.html` where it and the brief
   differ in detail. The coin's two "glints" twinkle as the preview does,
   rather than flashing at 62 to 100%. The thinking and coin tilts rest at
   minus 4 degrees, which is their first keyframe, as in the preview.

## Findings for the founder

1. **A budget cannot be created anywhere in this app.** Budgets arrive with
   the example data, and once that is cleared there is no way to add one,
   though D19 calls budgets core. The Budgets empty state therefore carries
   no "Set your budget" button: a button that goes nowhere is worse than
   none. Adding budgets writes new records, so it waits for your go-ahead.
2. **Ask Pan already exists on Home** in this app: a rule-based card and a
   floating button from the prototype rebuild, with no AI and no network.
   D30 says the chat stays cut and adds nothing to it; whether the existing
   one stays is your call. On an empty Home, its floating button also covers
   part of the quick-action row (unchanged by this work, visible in the
   renders).

## Deferred

- Hi-res art. The same file names replace the PNGs and no code changes.
- Pan's later moods (celebrate, stars, savings, love, shy, surprised and the
  rest) for big moments and heads-ups.
