# 05. Roadmap

Phases in order. Each has an exit test the founder can check by looking or
tapping, not by trusting. No dates; the founder is not in a hurry, and a
phase is done when its exit test passes, not when a week ends.

## Phase 0. Documentation (this folder)

Do: write the governing set; inventory every existing doc; point CLAUDE.md
at the new set; get founder decisions in 07-decisions.md answered.

Exit: the founder has read this folder, answered the decisions, and said
"go". The old docs are moved to docs/archive on a branch and merged.

## Phase 1. Design

Do: turn 03 and 04 into pictures before any code. Three deliverables:
1. A component sheet (every kit component, dark and light) as a design
   canvas or Stitch export.
2. The five core screens (Home, Log, Activity, Plan > Budget, Accounts) as
   high-fidelity mockups in dark, then light.
3. One prototype flow the founder can tap through: open app, tap Log, type
   "jollibee 250", save, see Home update.

Tools: Google Stitch for fast exploration of layouts, Figma (connected to
Claude Code) as the file of record, Claude's design canvas for quick
in-conversation revisions. See 06-tooling.md.

Exit: the founder looks at the five screens beside Tarsi's and says v3
looks like the one they want to open. Any screen that does not pass gets
redesigned before Phase 2 starts.

## Phase 2. Foundation code

Do, in app/:
1. New Flutter project, same applicationId, version 1.0.0+21 (one above the
   current versionCode so it installs over the old app).
2. Design tokens and the component kit, with the contrast test, the type
   discipline test, and kit_shot.dart rendering every component.
3. Copy core/money and core/data from flutter/ with their tests. Trim to
   what v3 uses. The golden vectors must pass unchanged.
4. Typed models with a round-trip test against a real v12 backup file.
5. Router and shell: four tabs and the Log button, empty screens.
6. The branch check workflow for app/ (analyze, test, shots).

Exit: app/ boots on an emulator, restores the founder's backup, shows the
right net worth on an otherwise empty Accounts tab, and the component sheet
PNGs match the Phase 1 mockups.

## Phase 3. Core screens

One PR per screen, in this order, each with dark and light PNGs in the
conversation and a journey test that taps through it:

1. Log sheet with the fast-log field (the heartbeat; everything else is
   read-only without it).
2. Activity.
3. Accounts and account detail.
4. Home.
5. Plan > Budget.
6. Plan > Upcoming.
7. Utang and debt detail.
8. Plan > Goals.
9. Insights.
10. Settings, backup and restore, app lock, onboarding.

Exit: the founder side-loads app/ on their phone next to the old app and
uses only v3 for one week without needing the old one. Anything they reach
for that is missing goes on the Phase 5 list, not into Phase 3.

## Phase 4. Cutover

Do:
1. Publisher workflow for app/ (build, Shorebird release, delivery log).
2. Base APK installed by the founder over the old app; data found in place;
   backup restore tested as the fallback.
3. Home screen widget re-pointed at v3's data.
4. flutter/ and mobile/ deleted from the working tree (founder decision),
   old workflows removed, CLAUDE.md rewritten for the single app.

Exit: docs/delivery-log.md has a row for s3.xx and the founder confirms the
stamp on the phone. The old app is uninstalled.

## Phase 5. Features, one at a time

Only now. The list is whatever the founder missed in Phase 3's week plus
whatever they want next, ranked by "would I use it tomorrow". Candidates
from the cut list that are most likely to return: a Tools sheet (13th
month, loan, tax), receipts as photo attachments, CSV import, themes for
other users. Each is its own brainstorm, design, PR, render, review.

## What does not move between phases

- The privacy promise.
- The stored data shape (schema v12) unless a phase explicitly bumps it
  with a founder decision.
- Peso-exact money math and its golden vectors.
