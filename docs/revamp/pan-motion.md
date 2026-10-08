# Pan in motion: Phase 2 brief

Founder direction, 2026-10-08: animate Pan, "maximize the animation", using
the 19 images we already have. Build this AFTER Phase 1 in
[pan-handoff.md](pan-handoff.md) is done and its renders are approved. It is
part of D30, so add one line to D30 saying motion is in scope.

The approved look is `docs/revamp/mockups/pan/motion-preview.html`. Open it
in a browser: it plays every motion below with the real images. The frame
strip `docs/revamp/mockups/pan/motion-frames-home.png` shows the Home
entrance frozen at set times.

## Scope

- Motion lives inside `PanArt`. No screen gains animation code of its own.
- Built with Flutter's own `AnimationController`, `Transform` and
  `CustomPaint`. **No new packages.** No Rive, no Lottie, no flutter_animate.
- No money, data, navigation or copy changes.

## The four layers

Each Pan is four nested layers, outer to inner, so the motions add up
instead of fighting. Every scale and rotation pivots at **50% across, 92%
down** (his feet), never his middle.

1. **Entrance.** Plays once each time the empty state appears.
2. **Move.** The mood's idle travel (float or hop).
3. **Body.** The mood's idle shape change (rock, breathe or tilt).
4. **Tap.** Squash and stretch when tapped.

Effects (sparkles, z, glow, dots) sit on layer 2, so they travel with him.

## Entrance, every mood

- Starts 320 ms after the card appears. Lasts 760 ms, ease out.
- Keyframes: 0% opacity 0, y +28, scale 0.35. 55% opacity 1, y -8,
  scale 1.08. 75% y +2, scale 0.96. 100% y 0, scale 1.
- The empty state's title, body and button then rise in: opacity 0 to 1,
  y +14 to 0, 520 ms, `Cubic(0.2, 0.8, 0.2, 1)`, starting at 560, 630 and
  720 ms.
- **Home only:** after it lands, the "Log your first entry" button sends out
  two soft rings in the accent colour, starting at 1500 ms, 1600 ms each,
  spreading 0 to 16 px while fading out.

## Idle, per mood

Idle starts 1000 ms after the card appears. Ease in out unless stated.
"Alternate" means it goes there and back.

| Mood | Move | Body | Shadow | Effects |
|---|---|---|---|---|
| wave | float up 9 px, 2400 ms, alternate | rock 0, -6, 0, +6, 0 degrees, 1600 ms | shrinks with the float | 3 gold sparkles by the raised hand |
| sleep | none | breathe to scale x 1.035, y 0.965, 3200 ms, alternate | widens slightly with each breath | 2 "z" letters drift up 36 px and fade, 2600 ms, 1300 ms apart |
| idea | hop every 2200 ms, linear (see below) | none | squashes on landing, shrinks in the air | glow behind the bulb, pulses 1200 ms, alternate |
| coin | float up 9 px, 2000 ms, alternate | tilt -4 to +4 degrees, 2400 ms | shrinks with the float | glow behind the coin, plus 2 glints |
| calm | float up 9 px, 3600 ms, alternate | breathe, 3600 ms, alternate | shrinks with the float | 3 soft green sparkles |
| thinking | none | tilt -4 to +4 degrees, 3000 ms | none | 3 dots to his left pulse in turn, 200 ms apart |

**Hop** (idea): 0 to 58% rest. 66% squash to scale x 1.1, y 0.88. 80% in
the air, y -22, scale x 0.95, y 1.06. 92% landing squash, scale x 1.06,
y 0.93. 100% rest.

**Effects:** a sparkle twinkles in 1800 ms (opacity 0 to 1 to 0, scale 0.3
to 1, turning 45 degrees). A glow pulses opacity 0.2 to 0.95 and scale 0.75
to 1.3. A glint flashes at 62 to 100% of its cycle. Exact positions are in
the preview file; read them from there.

### How long idle runs

**3 cycles, then he rests.** Founder asked for maximum animation, and every
effect above is in. But a Pan that never stops pulls attention off the money,
and an endless animation makes `pumpAndSettle` in tests hang forever. So keep
one constant, `panIdleCycles = 3`, in `PanArt`. Changing it is a one-line
decision for the founder, not a code change anywhere else.

## Tap

Tapping Pan plays a squash over 560 ms: 22% scale x 1.16, y 0.82. 52% up
14 px, scale x 0.9, y 1.12. 78% scale x 1.05, y 0.96. 100% rest. Fire
`HapticFeedback.lightImpact()` at the start. Tapping again restarts it.

The tap is a bonus, so it stays invisible to screen readers: no button
semantics, no focus. Pan is still `excludeFromSemantics`.

## The shadow

The PNGs carry a faint shadow baked in under the feet (the bottom 7.5% of
each image). `PanArt` clips that strip off and draws its own soft ellipse
instead, 54% of Pan's width and 9% of his height, centred under his feet,
black fading to clear at about 50% opacity. When he floats or hops, the
ellipse narrows to 74% width and fades to about 22%. When he is still, it is
simply drawn still. This replaces the baked shadow everywhere, Phase 1 Pans
included.

## Colours for effects

These are decorative and appear nowhere else, so they live as constants in
`PanArt`, not in `tokens.dart`.

| Effect | Gabi (dark) | Hapon (light) |
|---|---|---|
| sparkle | #FFD36B | #D99A00 |
| calm sparkle | #7FD9B8 | #2F9E72 |
| z | #8FA3D9 | #5B6FB0 |
| glint | #FFFFFF | #D99A00 |
| glow | #FFE08A at 95% to clear | same |

## Reduce motion

When `MediaQuery.disableAnimationsOf(context)` is true, Pan appears still at
full size with his drawn shadow, no entrance, no idle, no effects, and the
text appears without rising. Tap does nothing.

## Done means

1. Everything in Phase 1's "Done means" still holds.
2. A test proves reduce motion: with animations disabled, nothing animates
   and no ticker is left running.
3. A test proves idle stops: after the entrance plus 3 cycles,
   `pumpAndSettle` completes.
4. A test proves the tap restarts the squash.
5. Render a frame strip of the Home empty state at 0, 320, 600, 760, 1080
   and 2200 ms, dark, using `tester.pump` with those durations, and show it
   to the founder beside `motion-frames-home.png`.
6. Prove each new test can fail once, per CLAUDE.md.
