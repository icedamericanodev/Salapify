# Pan returns as a character: handoff brief

Founder direction, 2026-10-08: bring Pan back into Salapify 3 as a CHARACTER,
using the new art in `app/assets/pan/`. Record this as **D30** in
`docs/revamp/07-decisions.md` before writing code.

## D30, what it changes and what it does not

1. **D2 is amended for one item.** Pan the CHARACTER moves from "cut" to
   "kept". Everything else on the D2 cut list stays cut.
2. **The Pan chat stays cut.** No chat screen, no "Ask Pan", no AI. That is
   still the founder-gated fork in `12-financial-os-audit.md` section 3.5.
3. **Gamification stays cut.** No streaks, week chains, wins or milestones
   in this work. Pan reacts to what is on screen; he does not keep score.
4. **D17 still holds.** The icon stays Buto. The old Pan was a panda; the new
   Pan is not an animal, which answers the Tarsi comparison D17 worried about.
5. `06-tooling.md` says "no illustrations, no mascot" in the Stitch prompt.
   Update that line so future mockups match D30.

## Two phases

1. **Phase 1, this file:** static Pan on the empty states.
2. **Phase 2, [pan-motion.md](pan-motion.md):** Pan animated. Starts only
   after Phase 1's real renders are shown to the founder. D30 covers both.

## Phase 1 scope: empty states only

Small on purpose. No money, no stored data, no new screens, no network.

1. Add the 19 images to `app/assets/pan/` and list `assets/pan/` in
   `app/pubspec.yaml`.
2. Add a `PanMood` enum and ONE widget, `PanArt(mood, size)`, in
   `app/lib/design/`. Every screen goes through it, so swapping art later is
   one folder, not twenty edits.
3. Give `EmptyState` in `app/lib/design/kit.dart` an optional `pan` mood.
   When set, Pan replaces the icon disc. When not set, nothing changes.
4. Set a mood on the empty states that greet a person, using the map below.
   Leave error and "not found" states on their icons for now.

## Target look

`docs/revamp/mockups/pan/README.md` shows every Phase 1 screen before and
after, dark and light. Match those pictures: a 96 x 96 Pan in place of the
52 icon disc, a 10 gap under him instead of 16, nothing else on the card
changes. They are HTML reference renders, so where they and the real widgets
disagree on a pixel, the widgets win; where they disagree on WHICH Pan or
WHERE, ask the founder.

## Which Pan, when

| Mood | File | Use it for |
|---|---|---|
| wave | pan_wave.png | Home first run. A hello. |
| calm | pan_calm.png | Nothing due, nothing owed. "All clear" states. |
| sleep | pan_sleep.png | An empty ledger or list with nothing logged yet. |
| idea | pan_idea.png | Plan empty states that suggest a first step. |
| thinking | pan_thinking.png | Insights before there is enough data. |
| coin | pan_coin.png | Accounts empty state, money coming in. |
| shy | pan_shy.png | Asking permission (later phases). |
| wink | pan_wink.png | A quick confirmation (later phases). |
| celebrate, stars, savings, love | | Big moments: payday, debt paid off, goal reached. Later phases, after hi-res art. |
| surprised, nervous, confused, sad | | Heads-ups and failures. Later phases. |
| annoyed, tear, crying | | **Do not use.** Pan never judges spending. Tear may return only for the wipe-all-data confirmation, by founder decision. |

Pick the mood by what the screen says, not by what looks cute. If none fits,
leave the icon.

## Rules

- **Size: 96 logical pixels at most** until hi-res art arrives. The files are
  256 x 256, which looks sharp up to about 96 on a 3x phone and blurry above
  it. When bigger files arrive they replace these with the SAME names, and no
  code changes.
- **One Pan per screen.**
- **Decorative to screen readers.** The empty state's title already says what
  matters, so `PanArt` uses `excludeFromSemantics: true`.
- **Do not edit the PNGs.** Each has a light grey ground shadow baked in. If
  it reads as a smudge on Gabi, report it in the review; the art gets fixed,
  not the code.
- Writing style rules in CLAUDE.md apply: no em or en dashes anywhere.

## Done means

1. A guard test iterates `PanMood` and fails if any value has no asset file,
   the same pattern as `info_sheet_test.dart`. Prove it can fail once, per
   CLAUDE.md.
2. `flutter analyze` is clean and the full suite is green, including the
   readability and palette sweeps.
3. Every screen that changed is rendered, **dark first**, then light, and the
   PNGs are shown to the founder in the chat and committed with a README that
   embeds them, per "Look at the screen before shipping a screen".
4. A review note in `docs/reviews/` says what changed and confirms that no
   money, data or behaviour changed.
