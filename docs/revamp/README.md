# Salapify 3: the ground-up revamp

Founder direction, 2026-09-11: rebuild Salapify from the ground up. Get the
documentation right first, then the architecture, then the UI and UX design,
then add features. No launch deadline. The founder is building it for
themself first, and for other people only after it earns a place on their own
phone.

This folder is the governing document set for that rebuild. It replaces
docs/Salapify_Master_Constitution.md as the top authority below direct
founder direction. The constitution file stays in the repository, unedited,
as history (and because one test still reads it), but nothing in it binds
the revamp any more. Where the two disagree, this folder wins.

## The one-paragraph version

The current app is not bad, it is too much. Sixty-six screens, six
destinations, four colour themes, three font families, a mascot, a chatbot,
a course library, nine calculators. Each was a good idea on its own day and
together they read as assembled, not designed. That is the "boring and
weird" the founder named. Tarsi, the app it is being compared to, wins by
doing less with one design hand: log in seconds, see your money on one
screen, nothing you did not ask for. Salapify 3 keeps the one thing that
is genuinely hard to rebuild (a tested peso-exact money engine and an
encrypted store that already holds the founder's data) and rebuilds
everything a person sees and touches: navigation, screens, design system,
and the feature list itself, which gets cut to what the founder will use
every day.

## How to read this folder

Read in order. Each file is short on purpose.

| File | What it settles |
|---|---|
| 01-vision.md | Who the app is for now, the principles, and what is cut |
| 02-architecture.md | Where the new app lives, how it is structured, what is kept from today |
| 03-design-system.md | The new look: colour, type, spacing, shape, motion, components |
| 04-screens.md | The information architecture and every core screen, one by one |
| 05-roadmap.md | The phases, in order, each with an exit test |
| 06-tooling.md | How Claude Code, Google AI Studio, Stitch and Figma fit together |
| 07-decisions.md | The founder decisions this plan needs, each with a recommendation |
| 08-docs-inventory.md | Every existing doc, and whether it is kept, archived, or superseded |
| 09-working-rules.md | The short rulebook that replaces the constitution's autonomy model |

## Status

Phase 0 (this document set) is written and waiting for founder review.
Nothing in the app has changed. No code has been written for Salapify 3.
The current Flutter app keeps working and keeps shipping until Salapify 3
replaces it on the founder's phone.

## What is NOT changing

- The privacy promise. No account, no cloud, no telemetry. Data stays on the
  phone. This is the reason the founder trusts the app with real money and
  it is not up for debate in the rebuild.
- The founder's data. Salapify 3 reads the same encrypted store and the same
  backup file format (schema v12), so the day it installs, every account,
  transaction and debt is already there.
- Peso-exact money math. The engine and its golden test vectors carry over
  as a library. A number that matched to the centavo yesterday matches
  tomorrow.

## The pictures

docs/revamp/mockups/ holds the rendered mockups of the chosen theme, Papel
(Home, Log sheet, Accounts, Plan, then Home in Tinta, the dark option),
the three direction sketches the theme was chosen from, and the artboard
sources. The same set is an editable canvas the founder can tweak by hand:
https://claude.ai/code/artifact/3e662418-389c-4486-a0ff-2e9a1e60e656
(private to the founder). All figures in them are sample values.

The first draft (dark, cards, one orange accent) was rejected on
2026-09-12 as a Tarsi copy and is kept on the canvas only for comparison.
