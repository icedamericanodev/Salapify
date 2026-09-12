# 06. Tooling: Claude Code, Google AI Studio, Stitch, Figma

Four tools, four jobs. Using each for its job is what keeps the founder
from fighting the tools.

| Tool | Job in the revamp | Not its job |
|---|---|---|
| Google Stitch (stitch.withgoogle.com) | Fast UI exploration: describe a screen, get five connected mockups in seconds, iterate on layout and mood, export to Figma or HTML | Production code; anything that must match the tokens exactly |
| Google AI Studio (aistudio.google.com) | Prototypes and throwaway experiments: a tappable web or Android prototype of one flow to feel it before building it; image generation for app store art later | The real app. Its Kotlin or web output is not merged into app/ |
| Figma (connected to Claude Code) | The file of record for approved designs. Claude reads frames from it to build screens | Exploration; it is slower than Stitch for the first draft |
| Claude Code | Everything in the repository: docs, architecture, Flutter code, tests, renders, PRs | Being the only eyes; the founder looks at every PNG |

## The loop for one screen

1. Founder writes a Stitch prompt from the template below and picks the
   variant they like. Ten minutes.
2. Export that variant to Figma (Stitch has a one-click export) and name
   the frame after the screen ("Home / dark").
3. Tell Claude Code: "Build Home from the Figma frame Home / dark, using
   the kit in app/lib/design." Claude reads the frame through the Figma
   connection, maps it onto the tokens and components (never copying
   pixels blindly), builds it, renders it, and shows the PNG.
4. Founder compares the PNG to the Figma frame. Differences are either a
   fix (Claude) or a design change (back to Stitch or edited directly in
   Figma).
5. PR, review, merge.

If the founder prefers not to open Stitch, Claude's own design canvas does
step 1 in the conversation, and the founder tweaks the artboards by hand.

## Stitch prompt template

Paste the tokens so every generation stays on-system:

    Mobile app screen, Android, dark mode. Personal finance tracker for the
    Philippines called Salapify. Style: calm, premium, one warm orange
    accent (#FF8A3D) on near-black (#0D0D10) with cards in #16161B, text
    #F5F4F0, secondary text #A6A4AD. Font: Plus Jakarta Sans. Big bold
    tabular numbers for money, peso sign in orange. Corner radius 20 on
    cards, 12 on buttons. No gradients, no illustrations, no mascot.
    Bottom navigation: Home, Activity, a round orange Log button in the
    centre, Plan, Accounts.

    Screen: <name>. Content, top to bottom: <the list from 04-screens.md>.

Then ask for "the same screen in light mode: background #F7F6F3, cards
white, text #17161A, accent #D9540E".

## Rules that keep the tools honest

- Design output is context, never code. Stitch's HTML and AI Studio's
  Kotlin are read for intent, then rebuilt in Flutter on the kit.
- A mockup that uses a colour or size not in 03-design-system.md is
  either a token change (decided, then applied everywhere) or a mockup fix.
  Never a one-off in code.
- Every screen ends as a PNG in the conversation from the real app, dark
  first. The mockup is the target; the render is the proof.
- Package APIs are checked on Context7 against the pinned version before
  Claude uses them, per CLAUDE.md.

## The design director (added 2026-09-12)

The founder is not a designer and should not have to be. The
design-director agent (.claude/agents/design-director.md) owns the visual
direction from here: it finds real reference screenshots, builds the
founder's Figma moodboard, runs a keep-or-kill round, derives one theme from
what the founder kept, builds tokens and screens in Figma, and hands off to
flutter-ux-craftsman. The founder's only job in that loop is to react to
pictures.

The Figma file of record is "Salapify 3 Design"
(https://www.figma.com/design/VuiHCeU3Pz4irpIJBMHJkC): page 1 is the
moodboard, page 2 the tokens, page 3 the screens. Anything on the moodboard
is private inspiration with its source named; nothing on it is copied into
the app.

Why this replaced the earlier loop: eight text-driven variants were drawn and
rejected in one day. Designing from words guesses at taste; designing from
reactions measures it.

First run, 2026-09-12: twelve references on the moodboard, the founder
delegated the keep-or-kill round to the agent, and the agent derived Sinag
(03-design-system.md), built the two token collections and the swatch and
type sheets on page 2, and the six screens now in mockups/ and on page 3.
One practical note for the next run: the Figma starter plan allows one mode
per variable collection, so light and dark are two collections (Sinag Light,
Sinag Dark) rather than two modes of one. And the Figma calls that build a
whole screen as native frames in one go can hang without returning; the
screens were rendered from HTML with the real fonts instead and uploaded as
images, which is what the founder reviews. Native Figma frames are worth
building once a screen is approved, not before.
