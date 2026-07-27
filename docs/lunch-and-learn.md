# Lunch and learn

A short, blameless retrospective after every patch check, so the same mistake
never ships twice. Newest session first. Facilitated by the lunch-and-learn
agent (.claude/agents/lunch-and-learn.md).

The one rule: ground truth is the Update stamp ON THE PHONE. Everything else
(a green local test run, a merged pull request, a passing action) is a belief
about delivery, and beliefs are what these sessions audit.

---

## 2026-07-27, session 6: the bug only light mode could see

### What we believed / What was true

Six beliefs this round. Two were true, and the delivery pipeline was one of
them, twice.

**Believed: both batches reached the phone. TRUE, and confirmed in person.**
Read from `git show origin/main:docs/delivery-log.md`, then confirmed by the
founder on the phone, which is the only proof that counts: f2.53 patch 5 at
12:06 UTC (run 30263887813, merge 8e9fba0c) and f2.57 patch 6 at 13:38 UTC
(run 30270358216, merge 81a32e04). Both mode `patch` on 0.6.2+11,
flutter/pubspec.yaml still 0.6.2+11, so no base APK was stranded. Merge to
delivery row: 10 minutes and 11 minutes, inside the 9 to 11 minute norm
measured in session 4. The founder read f2.57 patch 6 off the Update stamp
row and it matched the last delivery row exactly. This entry is not about a
delivery failure. There were two deliveries today and both were boring, which
is what a delivery should be.

The gap in the log is benign by session 5's reading rule: f2.54, f2.55 and
f2.56 have no rows because they only ever existed on the working branch,
superseded inside pull request #209. None of them reached main. A missing
stamp is an incident only when it reached main, and none of these did.

**Believed: batch 1 was visually checked before merging, so what shipped
looked right. FALSE for light mode, and a real bug reached the phone.** When
Menu moved off the bottom bar it became a pushed route, and its Scaffold was
stripped along with the other destinations' Scaffolds during the shell
refactor. The five destinations render inside the SHELL's Scaffold. A pushed
route does not, so Menu rendered with no background surface at all. In dark
mode that happened to look almost right, and dark is what the founder uses
and what gets looked at first, per the standing rule. In light mode the Menu
title rendered at a contrast of 1.21 to 1, where 4.5 to 1 is the floor. It
was live from f2.53 until f2.57, about 92 minutes by the log. No eye caught
it. The new textContrastGuideline test caught it, by number, in batch 2
(commit 6b35e90; the fix and the measurement are quoted in
flutter/lib/screens/menu.dart:61).

**Believed, three separate times: the new accessibility suite's first green
was proof. FALSE all three times, and each false green looked identical to a
true one.** (a) The shared segmented control wrapped each segment in
`Semantics(button: true)` around `ExcludeSemantics`, which strips the
InkWell's tap ACTION along with its label, and Flutter's tap target guideline
skips any node with neither a tap nor a longPress action. So the control was
invisible to the exact test meant to measure it, and, worse, genuinely
unreachable by screen readers, a real bug that had already shipped inside
Appearance. (b) The guideline skips nodes touching the view edge, so a
full-bleed test harness exempted the whole control. (c) Guidelines measure
only BUILT widgets, a lazy ListView builds only the viewport, and certifying
the top and bottom of Menu skipped the entire middle band, where a control
deliberately shrunk to 40 pixels still passed. All three were found by the
prove-it-fails discipline, not by luck, and the failure lines are quoted in
commits 84e3f46 and 6b35e90.

**Believed: the committed-amount duplication test guarded its fix. TRUE only
on some calendar dates, which is FALSE.** Its widget half ran through the
live clock and excused itself with markTestSkipped whenever the fixture
produced no committed money, which was most days of the month, because
store.load() posts due recurring bills and stamps lastPosted, so the test and
the widget were examining different data. Three fixture rewrites failed
instructively before the real fix, a clock seam (commit 17532be, the three
failures written out in its message).

**Believed, in the plan: IndexedStack would make finders ambiguous across the
mounted tabs. FALSE, disproven with a test rather than argued away.** The
SDK's `_IndexedStackElement` overrides the onstage walk and visits only the
selected child, so inactive destinations never reach a default finder. The
proof test found 1, not 2. The plan doc was corrected and the behaviour is
now pinned in flutter/test/nav_ambiguity_test.dart, including a third test
that flips the index so the first two cannot pass by accident.

**Believed, briefly: a silent CI watcher meant a build still running. FALSE.**
The first watcher this session queried the GitHub API, got 403s (documented
as unreadable from this sandbox in sessions 4 and 5), and reported nothing,
and that silence read as progress. It was replaced with a watcher that reads
docs/delivery-log.md over git and explicitly reports BOTH outcomes, a
new-row line and a loud no-row-after-35-minutes line. This is session 5's
Lesson 8 recurring once and then being followed.

### Timeline (with evidence)

All times UTC, from `git show -s --format=%cI` and from the publisher's own
timestamps in docs/delivery-log.md.

| Time | Event | Evidence |
|------|-------|----------|
| 03:05 | 75eaf19, one navigation seam for the widget suite (test/support/app_harness.dart), and the IndexedStack assumption corrected with a proof test | git log; nav_ambiguity_test.dart |
| 06:13 | 84e3f46, the shared segmented control, and the first accessibility test found measuring nothing three ways, one of them a shipped screen reader bug | commit message, guideline source quoted |
| 06:44 | 8208cc8, one shell owns the navigation, tabs stop forgetting | git log |
| 11:50 | **Divergence.** 6432323, Menu moves to the top and becomes a pushed route with no Scaffold. From here the light mode Menu has no background surface, and nothing knows | git show 6432323; menu.dart:61 comment |
| 11:56 | Merge #208 (8e9fba0c), stamp f2.53 | git log |
| 12:06 | f2.53 patch 5 delivered, 10 minutes | delivery row |
| 12:06 to 13:38 | The contrast bug is live on the phone. Invisible in dark mode, which is what the founder uses | menu.dart:61 |
| 12:01 to 12:41 | 9766af7 one committed figure not two, a209653 Home leads with the number, 17532be the clock seam after three failed fixtures, a700de2 three presentation levels | git log |
| 12:54 | 6b35e90, the accessibility suite. textContrastGuideline samples the pushed Menu title at 1.21 to 1 and fails. Fixed in the same commit, with three more real findings | commit message, failure lines quoted |
| 13:20 | 23a405d, Utang and Debts merge into one tab, two segments, stamp f2.57 | git log |
| 13:27 | Merge #209 (81a32e04) | git log |
| 13:38 | f2.57 patch 6 delivered, 11 minutes | delivery row |
| after | **Founder confirms f2.57 patch 6 on the phone, in person** | founder |

Verified on the checkout at the time of writing: `flutter analyze` reports
"No issues found", `flutter test` reports **814 tests passing** (up from 775),
run in this session, not quoted from memory.

### Divergence point

**11:50 UTC, commit 6432323.** That is where "the screens were rendered and
looked at" stopped being the same fact as "the screens are right". The
render discipline was followed as written: every changed screen, both
brightnesses, dark first. The bug sat precisely in the discipline's stated
blind spot, because dark first is a priority order for HUMAN attention, and
the one brightness a human deprioritises is exactly where a surface bug can
live alone. The divergence closed at 12:54 when a numeric check that has no
brightness preference measured the title and said 1.21.

Worth stating the shape: this is the first session where the founder found
zero bugs and the tests found several, including one that was already on the
phone. The direction of detection reversed. That is what every guard in this
log has been trying to buy.

### Root cause

**The shipped contrast bug.** The shell refactor changed two things in one
move: the five destinations gave up their Scaffolds to the shell, and Menu
changed CATEGORY, from destination to pushed route, in the same batch. A
pushed route needs what the destinations no longer do, and nothing in the
type system or the suite distinguished "renders inside the shell's Scaffold"
from "renders alone". The human check then missed it for a structural reason,
not an attention reason: the rule says dark first because dark is what the
founder uses, and a missing Material surface in dark happened to sit on a
dark window anyway. A review order optimised for the common case is blind in
the uncommon one, by construction. The fix for that is not "look harder at
light mode", it is a check that does not have a favourite brightness.

**The three silent greens.** A new test's first green is a recording of its
author's mental model, not evidence, which is session 3's Lesson 3 wearing
accessibility clothes. What is new this round is HOW MANY silent-pass modes
one honest suite turned out to contain: skipped actionless nodes, skipped
edge-touching nodes, unmeasured unbuilt widgets. All three are documented
behaviours of the guideline machinery, none is a bug in Flutter, and every
one of them converts "passed" into "did not look". The only thing that
distinguished measuring from not measuring was breaking the app on purpose
and demanding the failure.

**The self-skipping test.** A test that conditions its own execution on the
live clock is an alarm that removes its own battery on most days, and it had
been proven-to-fail on one date, which hid that it checked nothing on the
others. Proving a test can fail on one input does not prove it RUNS on all of
them. The structural fix was a seam, not a cleverer fixture, because some
real dates genuinely have no committed money and the app is right about that.

**The silent watcher.** Same class as session 5's Lesson 8, an uncommitted
monitor whose failure mode is indistinguishable from good news. The standing
answer, read the delivery log instead of asking the API, already existed and
was applied on the second attempt. The cost of the rule not being in
CLAUDE.md was measured this round: one silent watcher, replaced within the
session.

### Lessons and guards

**Lesson 1. A dark-first eye has a light-mode blind spot, and the contrast
guideline does not care which brightness anyone prefers.**

The render discipline stays, and stays dark first, because it catches what
only eyes can catch, prose walls, missing ticks, a mascot dissolving into his
background. What it structurally cannot promise is the brightness the human
deprioritised, and this round produced the proof: a 1.21 to 1 title, live on
the phone, invisible to a dark-first review, caught by a number.

**Guard, SHIPPED, strongest tier.** flutter/test/a11y_test.dart runs
textContrastGuideline (plus both tap target guidelines and the label
guideline) over all five destinations, the Utang second segment, Menu
screenful by screenful, the log sheet, the Activity filter state, and the
welcome state, at test/a11y_test.dart:96. It runs in the Flutter check on
every branch push and in the preview publisher before anything ships. It
caught this exact bug before batch 2 merged, which is the guard demonstrating
its value in the same session it was written.

**Lesson 2. An accessibility suite can pass while measuring nothing, in at
least three distinct ways, and only a deliberate failure tells them apart.**

The three silent-pass modes, named so the next suite author can check them by
name: a node with no tap action is SKIPPED by the tap target guideline, so a
widget made semantically inert passes precisely because it is broken; a node
touching the view edge is skipped, so a full-bleed harness certifies nothing;
and guidelines measure only built widgets, so a lazy list is only certified
for the screenfuls actually scrolled through. Mode (a) was not just a test
gap, it was a shipped bug: the segmented control advertised "button,
selected" to screen readers with no way to activate it.

**Guards, SHIPPED, layered.** The widget fix gives the Semantics its own
onTap, with the reason written at flutter/lib/widgets/segmented.dart:80 so it
cannot be tidied away. The Menu sweep walks every screenful and then asserts
it covered at least three of them (test/a11y_test.dart:161), so the sweep
itself cannot silently shrink back into a top-and-bottom pair, a guard on the
guard, automated. And the proof-of-failure lines are quoted in the commits
that landed the suite, per the standing CLAUDE.md rule:

    expected tap target size of at least Size(48.0, 48.0), but found Size(318.0, 40.0)
    androidTapTargetGuideline on Menu, screenful 4

The standing rule needs no strengthening, it needs exactly what happened
here: application. Three silent-pass modes found in one suite in one day is
the strongest evidence yet that the rule is load bearing.

**Lesson 3. A test that can skip itself on most calendar dates is an alarm
with its battery out, and proving it fails on one date does not prove it runs
on the others.**

**Guard, SHIPPED, strongest tier.** OverviewScreen takes an injectable clock
defaulting to DateTime.now (flutter/lib/screens/overview.dart:116, with the
three failed fixture attempts recorded in the doc comment), the test pins
DateTime(2026, 7, 26) and drives its precondition through the store, and the
markTestSkipped escape hatch is gone, so the test now hard-fails instead of
abstaining.

**Guard for the class, MEDIUM, stated plainly.** The rule worth carrying: a
widget test may not gate its own execution on the live clock. If the scenario
depends on the date, the screen takes a clock and the test picks the date.
This is a rule, not a check, and it is recorded here rather than promoted to
CLAUDE.md because one instance is not yet a pattern; if a second self-skipping
test ever appears, promote it.

**Lesson 4. Per session 5's Lesson 10 convention, the tests that changed this
round are reported, and none was defending a bug.** The duplication test's
markTestSkipped was removed so it fails instead of abstaining, an assertion
was added, none inverted. The first a11y versions were replaced by versions
that measure MORE, with the old blind spots quoted in the commits. No
assertion changed sides. Nothing to quote as a defended defect, and saying so
plainly is the convention.

**Lesson 5. A disproven plan assumption should end as a pinning test, not as
a corrected sentence.** The IndexedStack ambiguity worry was reasonable,
predicted in the plan, and wrong. The correction is now held by
flutter/test/nav_ambiguity_test.dart, which quotes the SDK element it depends
on, explains that the assumption is imported from the SDK rather than owned
by this app, and fails first if a future Flutter release changes the onstage
walk, at which point dozens of tests would otherwise silently target the
wrong screen.

**Guard, SHIPPED, strong.** The pinning test, including the index-flip test
that keeps the other two honest. Related and worth recording as a pattern
that paid for itself: the single navigation seam
(flutter/test/support/app_harness.dart) meant moving Menu off the bottom bar
cost a 2 line change in one file instead of edits across 24 test files, and
its openMenu finder is byTooltip, so the finder breaking would itself signal
a real accessibility regression.

**Lesson 6. Existing tests caught a real navigation bug mid-refactor, and a
guard firing is the process working.** Three screens used a single pop()
before switching tabs, which stranded the user on the now-pushed Menu with
the tab changed silently behind it. Fixed with popUntil isFirst, reasons
written at the call sites (flutter/lib/screens/pan.dart:120,
search.dart:81, reports.dart:1348). No new guard, the suite already held.

**Lesson 7. CLAUDE.md fact check, run as a step of the session, not as a
favour.** What still matches, checked against the repository: every path the
file names exists where it says (flutter/shorebird.yaml,
flutter/test/update_stamp_test.dart, flutter/test/screens_shot.dart,
flutter/lib/widgets/salapify_icon.dart, docs/delivery-log.md); /opt/flutter
reports Flutter 3.44.6 stable; all five skills exist in .claude/skills; the
120 character stamp cap is enforced at update_stamp_test.dart:20;
flutter-check.yml triggers on `claude/**` at line 20; mobile/lib/storage.js
still holds salapify_data_v2; the three delivery commands ran as written and
returned f2.57 patch 6; and the screenshot harness still covers Menu and the
tabs after the restructure.

**No NEW false claim was found this session, which breaks a three session
streak. The OLD one is still there.** CLAUDE.md:17 and CLAUDE.md:157 still
name the branch claude/salapify-v2, which does not exist, and
flutter-preview.yml:13 still lists it as a publish trigger. That is session
5's Open 12, found, written down, and not yet fixed, now surviving its second
session as a known false sentence read with authority. It is a five minute
edit. It should not survive a third session, and if anyone ever recreates a
branch by that name, pushes to it begin publishing to the founder's phone
from a working branch. Still open, and now overdue rather than merely open.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design, and this
round it cost zero.** The founder confirmed f2.57 patch 6 in person and it
matched the last delivery row exactly. The phone half of the comparison is
still a human, and this session that human had nothing to report, which is
the cheap case.

**Open 6, the watchdog has never been OBSERVED running a scheduled pass:
STILL OPEN.** The GitHub API still returns 403 from this sandbox, so run
history is unreadable, same limit as sessions 4 and 5. What the log shows is
that it did not fire spuriously today, and both merge-to-row gaps (10 and 11
minutes) were far inside its 2700 second grace. Closes on one observed run.

**Open 7, the watchdog is a stall detector, not an audit trail: STILL OPEN.**
Nothing changed. Open 9 remains the fix for the audit half.

**Open 8, split the publish step from the log scraping step: STILL OPEN,
verified.** The grep still runs inside the same step as the shorebird
commands (flutter-preview.yml, the ship step around line 100 to 125), so a
future failure in the reading half would again suppress the APK upload and
the delivery row. The `|| true` protects the one known shape only.

**Open 9, record failed publishes as FAILED rows in docs/delivery-log.md:
STILL OPEN, verified.** No FAILED mode exists in the workflow and no such row
exists in the log.

**Open 10, nothing holds Pan's rendered size: STILL OPEN, verified.** No ink
fraction test and no named margin constant exist; the three tuned numbers
from 830b021 are still unguarded.

**Open 11, nothing stops a sixth private kicker: STILL OPEN, with a note in
its favour.** No lib scanning test exists yet. This session did make the same
class of move again in the right direction, two hand-rolled segment controls
became one shared widget (flutter/lib/widgets/segmented.dart) for exactly the
five-kickers reason, so the pattern is being resisted by habit. Habit is the
weakest tier, which is why this stays open.

**Open 12, CLAUDE.md names a branch that does not exist: STILL OPEN and now
OVERDUE.** See Lesson 7. Two sentences in CLAUDE.md plus one dead trigger
entry in flutter-preview.yml:13. Second session in a row as a known false
claim.

### Guard status re-check

Read, not assumed. Nothing has been quietly deleted, disabled, or routed
around.

- The `|| true` on the ship log scrape: PRESENT with its sixteen line
  comment, flutter-preview.yml:124.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:221.
- The release install shout: PRESENT, flutter-preview.yml:246, and correctly
  silent today, both rows were patches.
- The auto-close on recovery: PRESENT, flutter-preview.yml:263.
- The duplicate stamp refusal: PRESENT, flutter-preview.yml:176.
- The publisher watching its own path, and concurrency with
  `cancel-in-progress: false`: PRESENT, flutter-preview.yml:15 and :33.
- The delivery watchdog with `--first-parent` and the 2700 second grace:
  PRESENT, delivery-watchdog.yml:43 and :99.
- flutter-check.yml on `claude/**`, the screenshot harness step with
  `--update-goldens`, and the branch-stamp-versus-delivered step: PRESENT,
  lines 20, 80, 91.
- The stamp cap: PRESENT and passing, update_stamp_test.dart:20.
- The Pan folder sum and the nothing-but-Pan test: PRESENT,
  pan_asset_test.dart:94 and :120.
- pan_signature_test.dart: PRESENT.
- The shared Kicker widget: PRESENT, flutter/lib/widgets/section.dart:28.
- The whole suite: 814 tests green and analyze clean, run in this session.

New guards added this round, for the next session to re-check:
flutter/test/a11y_test.dart (four guidelines, the Menu sweep with its
three-screenful floor), flutter/test/nav_ambiguity_test.dart, the clock seam
at overview.dart:116, and test/support/app_harness.dart as the suite's single
navigation seam.

### What it cost, and what it did not

Cost: one light-mode-only contrast bug live on the phone for about 92
minutes, almost certainly never seen because the founder uses dark mode.
Three rounds of rewriting an accessibility suite before it measured anything,
which is labour that a naive first green would have skipped and regretted.
Three failed fixture rewrites before the clock seam. One silent throwaway
watcher, replaced within the hour.

Did not cost: any delivery failure, any wrong number, any manual install, any
founder-reported bug, any founder round spent as the detector. Both merges
delivered on the normal schedule, the founder's phone matched the log on the
first read, and every real bug found this round, the contrast surface, the
unreachable segmented control, the unlabeled switches, the stranded-on-Menu
pop, the duplicated committed figure, was found by a test or by the
prove-it-fails discipline before the founder could meet it.

### For the founder, in plain English

A few words first. **Contrast** is how strongly text stands out from what is
behind it, written as a ratio; 4.5 to 1 is the accepted floor for body text,
and 1.21 to 1 is barely darker than the background. A **screen reader** is
the phone feature that reads the screen aloud for people who cannot see it
well, and an **accessibility test** checks, with numbers, that buttons are
big enough to tap, labelled, and readable.

**What happened.** Both updates reached your phone and you confirmed the
second one yourself, f2.57, patch 6. The pipeline was boring twice, ten and
eleven minutes each, which is exactly what we want from it.

One real bug did ship in between, and I want to tell you about it even
though you almost certainly never saw it. When we moved Menu from the bottom
bar to the top right corner, Menu lost its background layer. In dark mode,
the mode you use, that accident happened to look nearly right. In light mode
the Menu title was almost the same shade as the empty space behind it, 1.21
to 1 where 4.5 to 1 is the floor. My habit is to look at the dark
screenshots first because dark is what you use, and that habit is exactly
why no eye caught this: the one mode a person deprioritises is the one mode
a bug like this can live in alone. It was live for about an hour and a half
and was fixed in the second batch.

What caught it was not a person. The second batch added a set of automated
accessibility checks that measure every screen with numbers: is every button
at least 48 pixels tall, does every control have a name a screen reader can
speak, does every piece of text clear the contrast floor. Numbers do not
have a favourite brightness. The contrast check measured the Menu title,
said 1.21, and failed, and that failure is the whole reason you never saw
this bug get worse.

**The part I most want you to understand.** When I first wrote those
accessibility checks, they all passed immediately, and that is exactly when
I trusted them least. We have a standing rule: before trusting a new test,
break the app on purpose and watch the test notice. Doing that revealed,
three separate times, that the checks were passing while measuring nothing.
The most serious case was also a real bug: the little two-way switch we use
on some screens had been built in a way that made it completely invisible to
screen readers, no name, no way to press it, and invisible to the checker
for the very same reason. A blind user could not have used it at all. It is
fixed, and the checker now genuinely measures it. A test that passes on its
first try has proven nothing yet. Breaking things on purpose is how a green
light earns the right to be believed.

Two smaller things from the round. Home briefly showed the same committed
amount twice, in two cards, because two correct changes met each other; that
is fixed, and the test that guards it now picks its own date on the
calendar, because it used to quietly excuse itself from running on most days
of the month, and a smoke alarm that takes its own battery out is not an
alarm. And an early version of my build-watching script failed silently, so
silence looked like a build still running; it now reads the delivery log
directly and says something loud in both directions, update arrived or
nothing after 35 minutes.

**What it costs if a guard is removed.** Delete the accessibility test file
and the next missing-background bug ships in whichever mode you do not use,
silently, and the next unlabelled control ships unusable to screen reader
users, which will matter at launch far beyond you and me. Shrink the Menu
part of that test and the middle of the Menu screen goes unmeasured; there is
an assertion that fails if the sweep ever covers less than three screenfuls,
specifically so that cannot happen quietly.

**One thing I owe you straight.** Last session I found that our own rules
file names a work branch that no longer exists, in two places. It is still
not fixed. It has caused no harm, and it is a five minute edit, but a rules
file that states something false gets read with authority, so I am flagging
that it is now overdue rather than letting it fade. Beyond that, this was
the round we have been building toward since session 1: two clean
deliveries, and every bug found by a test before it could reach you, instead
of by you after it did.

---

## 2026-07-26, session 5: the release that published and then threw its own APK away

### What we believed / What was true

Five beliefs. Two were true, three were not, and the most expensive one is the
one that looked most obviously true.

**Believed: every stamp shipped today reached the phone. TRUE.** Read from
`git show origin/main:docs/delivery-log.md`, not assumed: f2.40 patch 34 at
01:53 UTC, f2.41 patch 35 at 03:11, f2.44 release 0.6.1+10 at 04:42, f2.47
release 0.6.2+11 at 07:00, f2.49 patch 1 on 0.6.2+11 at 09:51.
`flutter/pubspec.yaml` is 0.6.2+11, which matches the last release, and f2.49
patched onto it cleanly. The founder installed both base APKs and confirmed on
the phone. The installed base is not stranded.

**Believed: the five missing stamps are all the same benign thing. FALSE for
one of them, and that one is this session.** f2.42, f2.43, f2.45, f2.46 and
f2.48 have no delivery row. Four are benign: 1a5a097 (f2.42) was superseded by
0bc35a4 (f2.43) inside pull request #199, 989e667 (f2.45) and d76080b (f2.46)
were superseded by 3a2a91c (f2.47) inside #203, and 830b021 (f2.48) was
superseded by 75c1b37 (f2.49) inside #204. None of those stamps ever existed on
main. f2.43 did. It was the stamp on merge commit 4697ef2, which landed on main
at 04:00 UTC and delivered nothing at all.

That gives a clean reading rule for the next person looking at a gap in the
log: **a missing stamp is benign when it only ever existed on a working branch,
and it is an incident when it reached main.** Establishing which of the two it
was today took reading four commits, and that is a finding in itself (Lesson 2).

**Believed: a successful Shorebird publish means the founder has something to
install. FALSE.** Release 0.6.0+9 published fine and the step then failed
anyway. From the log, quoted in 4d2fbba:

    Published Release 0.6.0+9!
    ##[error]Process completed with exit code 1.

**Believed: the Pan asset size guard measured what ships. FALSE.** It summed
four named files. `flutter/pubspec.yaml` declares `- assets/pan/`, a whole
directory, so the bundle is whatever sits in that folder.

**Believed: the typography refresh changed the kicker everywhere. FALSE.**
`_kicker` existed as five private copies. theme.dart and debts.dart moved to
12/w600/1.2. menu, overview, insights and privacy_receipt kept a hand rolled
11/w700/2. The same label rendered two different ways for an unknown length of
time with the whole suite green.

### Timeline (with evidence)

All times UTC. Merge commits carry +0800 committer times in git, converted
here. Delivery times are the publisher's own timestamps in docs/delivery-log.md.

| Time | Event | Evidence |
|------|-------|----------|
| 01:43 | Merge #197 (3ac59da), stamp f2.40 | git log |
| 01:53 | f2.40 patch 34 delivered, 10 minutes | delivery row |
| 03:01 | Merge #198 (a11ab83), stamp f2.41 | git log |
| 03:07 | 1a5a097 stamp f2.42, pubspec 0.5.0+8 to **0.6.0+9**. First native bump since 07-22 | git show 1a5a097:flutter/pubspec.yaml |
| 03:11 | f2.41 patch 35 delivered, 10 minutes. The last patch on 0.5.0+8 | delivery row |
| 03:18 | 0e66c38, "The screenshot harness was showing Pan by luck, not by loading" | git log |
| 03:39 | 0bc35a4 stamp f2.43, the per theme cup tint | git log |
| ~03:54 | **Asset near miss.** Eight intermediate PNGs written into assets/pan while working out the tint, then removed by memory alone | dbbae7e commit message; assets/pan directory mtime 03:54 |
| 03:56 | dbbae7e, the folder guard, proven to fail first | git show dbbae7e |
| **04:00** | **Merge #199 (4697ef2), stamp f2.43, release 0.6.0+9. DIVERGENCE.** Shorebird published, the step then exited 1, no APK was uploaded to the flutter-preview tag and no delivery row was written | no row between f2.41 and f2.44; failure quoted in 4d2fbba |
| ~04:0x | Claude tells the founder the APK is building. It had already failed. The founder asks for the link twice | session record |
| 04:24 | 4d2fbba, `\|\| true` on the grep, reproduced on both log shapes, pubspec 0.6.0+9 to **0.6.1+10** on purpose | git show 4d2fbba |
| 04:31 | Merge #201 (5e73391), stamp f2.44 | git log |
| 04:42 | f2.44 release 0.6.1+10 delivered, 11 minutes. **Manual install one** | delivery row |
| 05:14 | assets/pan/*.png replaced with the founder's Nano Banana renders | file mtimes |
| 05:20 | 989e667 stamp f2.45, pubspec 0.6.1+10 to **0.6.2+11** | git show 989e667:flutter/pubspec.yaml |
| 05:42 | d76080b stamp f2.46. pan_tint_test.dart deleted, pan_signature_test.dart added, guarding the opposite property | git show d76080b --stat |
| 06:09 | 3a2a91c stamp f2.47, Pan speaks in a bubble | git log |
| 06:49 | Merge #203 (c858b12) | git log |
| 07:00 | f2.47 release 0.6.2+11 delivered, 11 minutes. **Manual install two** | delivery row |
| after 07:00 | **Founder installs and reports Pan looks "super small"** | founder message |
| 07:36 | 830b021 stamp f2.48. Sizes 56 to 80, 56 to 76, 36 to 48. Fixed in Dart, not by re-cropping, so it patches | git show 830b021 |
| 09:34 | 75c1b37 stamp f2.49. Menu becomes a grid, five kickers become one | git show 75c1b37 --stat |
| 09:40 | Merge #204 (d0f3688) | git log |
| 09:51 | f2.49 patch 1 on 0.6.2+11 delivered, 11 minutes | delivery row |

Merge to delivery row, measured across five merges: 10, 10, **never**, 11, 11,
11. The pipeline is boringly consistent. The one that broke did not break
slowly, it broke completely, and it looked identical to the others for the
first ten minutes.

### Divergence points

**One, 04:00 UTC, merge 4697ef2.** The delivered stamp stopped matching the
built stamp. It was closed at 04:42, not by re-running the build but by bumping
to a fresh version, and that choice was correct: 0.6.0+9 already existed
server side, so a re-run would have taken the PATCH branch and patched a
release that was on nobody's phone. It cost the founder no extra install
because they had never received the first one.

**Two, invisible and much older.** The line
`PATCH=$(grep -oE 'Published Patch [0-9]+' ship.log | ...)` was correct for
every patch run and had succeeded 35 times. Its divergence point is not a date,
it is a SHAPE: the first release build after the line was added. Today was that
build. This is the classic form of a latent fault, a thing that is not wrong
until an input arrives that nobody thought about, and the input in this case
was the project's own most important event.

**Three, the typography refresh.** Whenever the kicker moved to 12/w600/1.2 in
theme.dart, four screens stopped agreeing with it and nothing said so. The
refresh believed it had changed "the kicker". It had changed one of five
definitions of the kicker.

### Root cause

Four of today's five technical faults are one fault wearing four costumes.
Each is a guard or a calculation that measured a STAND-IN for the thing that
matters, where the stand-in was simply the thing easiest to reach from where
the author was standing, and the stand-in agreed with reality right up until it
did not:

- `grep 'Published Patch'` measured the shape of a PATCH log as a stand-in for
  any ship log. Agreed 35 times.
- The size test summed four named files as a stand-in for the asset bundle.
  Agreed until a stray file existed.
- The typography refresh edited theme.dart as a stand-in for "the kicker".
  Agreed until the copies drifted.
- The widget size was used as a stand-in for how big Pan looks. Agreed while
  the artwork had no transparent margin, and the artwork has 22%.

The general counter move, and the thing to carry forward: **make the guard
measure the artifact that ships, not the declaration of it.** The folder sum
beats the file list. The bundle beats pubspec. The rendered ink beats the
widget box. One shared widget beats five agreeing copies.

There is a second, separate root cause, and it is session 4's returning
unchanged: **a channel that goes silent when it fails, where silence reads as
progress.** That covers the monitor with `except: pass` and it covers Claude
reporting "building" for a build that had already failed. Session 4 named this
exact shape after the 91 minute queue stall. It came back in a different place
within a day, which tells us the guard written for it (the delivery watchdog)
addressed the instance, not the class.

### Lessons and guards

**Lesson 1. A post publish step can undo a publish, and the publish step is the
one place where "the step failed" does not mean "nothing happened".**

The damage was not a red tick. The grep runs inside the same step as the
`shorebird release` command, after it, under `bash -e` with `pipefail`. grep
exits 1 when it matches nothing, and a failing command substitution kills the
step. So the step reported failure AFTER Shorebird had already published, and
both `if: success()` steps that matter were skipped: the APK upload to the
flutter-preview tag, and the delivery log row.

**Guard, SHIPPED, workflow change, strong for the instance.**
.github/workflows/flutter-preview.yml:124 now ends `... | tail -1 || true`,
with a sixteen line comment above it explaining what the two words cost.
Reproduced on both log shapes before fixing, quoted in 4d2fbba:

    release log -> exit=1     patch log -> PATCH=[35], exit=0

**Honest ranking: this fixes the instance, not the class.** The class is that
publishing and reading the log live in ONE step, so any future failure in the
reading half will again be reported as a failure of the publishing half and
will again suppress the APK upload and the row. See Open 8.

**Lesson 2. A run that publishes nothing leaves no trace in the repository, and
once the next merge lands the gap becomes unreadable.**

Anyone reading docs/delivery-log.md today sees f2.41 then f2.44 and cannot tell
whether f2.42 and f2.43 were branch only stamps or a failed delivery. It took
reading four commits and three pull requests to establish which. The delivery
log is explicitly the file the "three commands" check tells us to trust, and it
records only successes.

**Existing partial guard:** the `if: failure()` step at flutter-preview.yml:220
opens an issue titled "Preview build failed, nothing shipped to the phone". It
is loud at the moment of failure and it leaves nothing behind in the
repository, which is where the next session looks.

**Guard, OPEN, proposed, automated tier.** Have the failure step also append a
row to docs/delivery-log.md with mode `FAILED` and no patch number. The
publisher already has `contents: write` and already has a rebase and push loop
at flutter-preview.yml:206. See Open 9.

**Lesson 3. A guard that counts the files it already knows about cannot see the
file it does not.**

The near miss: working out the theme tint meant writing eight intermediate PNGs
into assets/pan, and they were cleaned up from memory alone. Had they survived,
all eight would have shipped (pubspec declares the directory), the size guard
would still have PASSED, and the first symptom would have arrived days later as
Shorebird refusing to patch against a changed asset bundle, in an error message
that says nothing about stray files.

**Guard, SHIPPED, test, strongest tier, and re-proven in this session.**
flutter/test/pan_asset_test.dart:88 now sums `Directory('assets/pan')`, and
flutter/test/pan_asset_test.dart:108 adds "nothing but Pan lives in the Pan
folder". Proven to fail before it was trusted, message quoted in dbbae7e. I did
not take that on trust: I copied one extra PNG into assets/pan and ran the
suite, which gave

    Unexpected file(s) in assets/pan: assets/pan/zz-stray-probe.png.
    00:00 +5 -1: Some tests failed.

then removed it and confirmed the folder is back to four faces. **Sufficient.**

**Lesson 4. A private copy of a style is invisible to every test.**

Five `_kicker` definitions, two of them updated by the typography refresh and
four not, 750 plus tests green throughout. Nothing failed because nothing could:
a private const inside a screen file is not reachable by any assertion.

**Guard, SHIPPED, partial.** One shared `Kicker` widget at
flutter/lib/widgets/section.dart, and all five call sites moved onto it. It is
deliberately NOT const, with a comment explaining that a const call site would
let `Element.updateChild` skip build and freeze the label in the previous
theme's colour. That removes today's divergence. **It does not stop the sixth
copy.**

**Guard, OPEN, proposed, automated tier.** A source scanning test that reads
`Directory('lib')` and fails on any `TextStyle` with `letterSpacing` at or
above 1.5 outside theme.dart, which is the signature of a hand rolled kicker.
Note there is no precedent for a lib scanning test in this suite yet, so it
needs proving by breaking it, like any other. See Open 11.

This lesson and Lesson 3 are the same lesson. Both measured the declaration
instead of the thing that ships.

**Lesson 5. Rendering the screen caught two real bugs, and it caught them
because it looks at the artifact rather than at a description of it.**

Two defects, neither of which any test would have found:

- A disposed `TextEditingController`. Disposing it as soon as `showDialog`
  returns looks right and throws "A TextEditingController was used after being
  disposed" every single time, because the exit animation still rebuilds the
  field. That is a crash, caught before the merge.
- Pan dissolving into his own background on the new Ask Pan banner. Pan is a
  fixed orange, the banner is filled with the accent, and on Barako those are
  the same orange. Invisible in the code, obvious in the shot. He now sits on a
  darker disc.

What made it work is specific and worth naming: it was run BEFORE the merge, on
the screens that changed, at both brightnesses, and someone actually looked at
the dark ones. The CLAUDE.md rule names that moment precisely, which is why it
fired.

**Guard: already in place and sufficient for what it can cover.**
.github/workflows/flutter-check.yml runs screens_shot.dart with
`--update-goldens`, which proves the harness still renders. It cannot prove
somebody looked, and no guard can.

**Lesson 6. A render shows you what is WRONG. It does not show you what is the
wrong SIZE, because a render has no reference beside it.**

Pan shipped at 56 logical pixels on Home. The artwork carries 22% transparent
margin inside its own canvas, so the cup actually drew 43 pixels there and 28
in the Ask Pan header. Every one of those renders was looked at and passed,
because 28 pixels of cup looks like a small character rather than like a bug.
The founder installed 0.6.2+11 and said Pan looks super small.

Root cause: the margin was inherited from matching the previous drawn cup's
framing exactly, which was the right call for visual consistency and quietly
capped how large Pan could ever appear. After that, nothing ever compared the
drawn cup against the box it sits in. **Widget size was a stand-in for cup
size, and it was wrong by 22% forever.**

The fix at 830b021 deserves credit for the part it got right: it changed the
SIZES rather than re-cropping the PNGs, specifically because assets cannot be
patched and re-cropping would have cost the founder a third manual install in
one day. Pure Dart ships over the air.

**Guard, OPEN, proposed, automated tier.** The fix is three numbers with no
test behind it, so the next person tuning a size can undo it silently. Either
a test that loads each face, finds the opaque bounding box, and asserts the ink
covers a minimum fraction of the canvas; or, cheaper and more honest, name the
margin as a constant in pan_mascot.dart so every call site is written in CUP
size and the widget box is computed from it. The second is a code change with
no test, so it is medium. See Open 10.

**Lesson 7. The rule "finished means delivered" existed, was correct, and did
not fire, because it forbids a narrower sentence than the one that was said.**

CLAUDE.md says: "Never tell the founder a stamp is live until a row for it
exists." Claude did not say live. Claude said the APK was building, which the
founder heard as "it is on its way", and it was not, it had already failed. The
founder then had to ask for the link twice.

Why no automated guard covered it, precisely:

- The `if: failure()` issue step at flutter-preview.yml:220 is designed to fire
  here. I cannot confirm from this sandbox that it did: the GitHub API returns
  403 through the proxy and there is no `gh` CLI, so I am stating what the
  workflow does, not what I observed. That limit is itself worth recording.
- The delivery watchdog did NOT fire, and that was CORRECT. f2.43 sat
  undelivered on main from 04:00 to 04:31, which is 31 minutes, inside the 45
  minute grace window set by `GRACE_SECONDS: '2700'`. So the watchdog stayed
  silent when it should stay silent, which is the exact half that was broken on
  its first version. Good news about the watchdog, and no help whatsoever here.
- Both of those report asynchronously, into GitHub Issues. The wrong sentence
  was said within minutes of the merge, in chat.

**Root cause, structural: nothing forces the delivery log to be READ in the
same turn as the sentence that describes a build.** Every automated signal is a
backstop measured in tens of minutes. The report to the founder happens in
seconds.

**Guard, MEDIUM, and I will not dress it up.** Broaden the CLAUDE.md ban from
"live" to any statement about a build's FATE, including "building", "on its
way", and "should land shortly", unless
`git show origin/main:docs/delivery-log.md | tail -1` was run in that same turn
and the result quoted. Medium because it depends on being read at the right
moment. The evidence that this tier is genuinely weaker is sitting in this very
lesson: a correct rule was present and did not bite, because it named a
narrower thing than the failure. **No test can stop a sentence, so this lesson
does not get a strong guard, and it should be re-checked every session until
it survives a real temptation.**

**Lesson 8. A monitor that swallows its errors is a monitor that reports
success.**

A monitoring loop written during this session used a bare `except: pass`, so a
total failure of the thing it watched would have looked exactly like "still
running". It was rewritten to report failure. It was never committed, and there
is no Python anywhere in the repository, which is itself the finding: **the
tool that was meant to detect the outage was throwaway, so its bug got no
review and its lesson has nowhere to live.**

**Guard: the standing rule already covers this exactly.** CLAUDE.md's alarm
rule says to prove both halves, that it fires when it should and stays silent
when it should, and that an alarm which cries wolf gets its battery taken out.
It was written for committed alarms and was simply not applied to a five line
script.

**Guard, MEDIUM to WEAK, proposed.** State in CLAUDE.md that the alarm rule
applies to throwaway tooling too, since throwaway tooling is the one kind that
gets no review. The genuinely strong version of this lesson is not a new guard
at all: **do not write ad hoc monitors, read docs/delivery-log.md**, which the
three commands already say and which needs no code.

**Lesson 9. Two manual installs in one day, both for the same feature, plus one
release nobody could install.**

pubspec went 0.5.0+8, then 0.6.0+9 at 03:07 (published to Shorebird, never
installable), then 0.6.1+10 at 04:24 (installed), then 0.6.2+11 at 05:20
(installed). Two hand installs five hours apart, both for Pan's face. Assets
cannot be patched, so the four PNGs forced a release; then the artwork was
replaced with a better set three hours later, which forced a second one.

**Guard for the DANGER, existing, sufficient, and it worked.** The
`mode == 'release'` step at flutter-preview.yml:245 opens an issue titled
"Install the new APK by hand, or the phone stops receiving updates". The
founder installed both, and f2.49 landed as patch 1 on 0.6.2+11, which proves
the phone is on the current release. Nobody was stranded.

**Guard for the COST, OPEN and honestly WEAK.** Nothing stops a second release
on the same day. The rule would be: settle the artwork before the release that
carries it, because every asset change costs the founder a manual install. That
is a habit, the weakest tier, and I am saying so out loud rather than promoting
it. It is worth writing down anyway because the counter example is already in
the log: at 07:36 the size fix was deliberately made in Dart rather than by
re-cropping, precisely to avoid a third install. The judgement is present. It
just is not enforceable.

**Lesson 10. A test was deleted and replaced by one asserting the opposite, and
this is NOT the usual case. Naming the difference is the point.**

flutter/test/pan_tint_test.dart was deleted at d76080b. It had asserted, among
eleven tests, that Pan MUST recolour per theme:

    test('a different theme really does recolour the cup', () {
      final m = panTintMatrix(...);
      expect(m, isNotNull, reason: 'Mint is nowhere near orange');
      ...
      reason: 'the matrix exists but leaves the cup orange');

Session 3's standing rule is that a test which had to change for a fix to pass
was asserting the bug. **That rule does not apply here, and saying so plainly
matters more than applying it reflexively.** This test was not defending a
defect. It correctly guarded a design decision that the founder reversed the
same day: Pan keeps one signature colour rather than following the wallpaper
(founder, 2026-07-26). The machinery was built, measured across all eight
palettes, rendered, and then removed on purpose.

The distinction to keep: **a test that changes because the CODE was wrong is
evidence of a defended bug. A test that changes because the DECISION changed is
evidence of a decision that is now held by something.** Both get quoted in the
entry. Only the first is a finding.

**Guard, SHIPPED, strong.** flutter/test/pan_signature_test.dart replaces it
and names the three realistic ways the old behaviour returns: wrapping the
artwork in a `ColorFiltered` again, giving `PanCupPainter`'s palette a live
Barako default again, or reading a Barako getter inside `PanMascot.build`. I
ran it in this session, four tests, all pass.

**Lesson 11. CLAUDE.md fact check: one false claim, third session in a row.**

Checked as a step of the session, not as a favour. What still matches:

- flutter/shorebird.yaml, flutter/test/update_stamp_test.dart,
  flutter/test/screens_shot.dart, flutter/lib/widgets/salapify_icon.dart and
  docs/delivery-log.md all exist exactly where they are named.
- /opt/flutter exists and reports "Flutter 3.44.6 stable", matching the version
  the rules name.
- All five skills named in the Skills section exist in .claude/skills.
- The 120 character stamp cap is real and enforced,
  flutter/test/update_stamp_test.dart:20, `lessThanOrEqualTo(120)`. Four tests,
  all pass.
- flutter-check.yml triggers on `'claude/**'`, exactly as rule 1 says.
- The three delivery commands run as written and returned f2.49 patch 1.
- mobile/ still holds salapify_data_v2 (mobile/lib/storage.js).
- The screenshot harness output goes to test/shots/ as documented, and the
  directory listing is the count, as the rule insists.

**FALSE: "Develop on the branch claude/salapify-v2 and open PRs to main"**
(Development workflow, item 1). That branch does not exist. `git branch -a`
returns only `main` and `claude/salapify-continuation-3i8jup`, and
`git ls-remote --heads origin` returns `main` alone. All of today's work
happened on claude/salapify-continuation-3i8jup.

**Stale in the same way:** Flutter rule 1 says pushes to "main or
claude/salapify-v2" that touch flutter/ run the preview publisher, and
.github/workflows/flutter-preview.yml:13 still lists `claude/salapify-v2` in
its branch trigger.

How bad is it today: **harmless, in the safe direction.** The working branch
does not match the publisher's trigger, so branch pushes published nothing,
which is exactly what rule 1 wants. The Flutter check did run on every branch
push, because `claude/**` matches. No delivery was affected.

Why it still matters: it is precisely the trap this session is instructed to
hunt. Both sentences name a real thing that has MOVED, so no checker can catch
them, and a beginner founder reading item 1 would push to a branch that is not
there. It is also a live trap in one direction: if anyone ever recreates a
branch called claude/salapify-v2, pushes to it would begin publishing to the
founder's phone from a working branch, which is the thing rule 1 exists to
prevent.

**Guard, MEDIUM.** Fix the two CLAUDE.md sentences to name the working branch
PATTERN (`claude/**`) rather than one branch name, and decide deliberately
whether flutter-preview.yml:13 keeps a dead branch in its trigger. See Open 12.

**The pattern, stated honestly: three consecutive sessions, three false factual
claims in CLAUDE.md, all the same kind, a name that was true when written. The
rate is not falling.** The only thing catching them is this fact check, which
means the fact check is now load bearing and must not be skipped when a session
is short.

### Open lessons carried forward

**Open 3, nothing compares the phone to main: STILL OPEN, by design.** The
repository half is watched every 30 minutes. The phone half was closed twice
today, once by the founder installing an APK and once by the founder reporting
Pan was small, and both times the founder was the detector. That is the
architecture, not a defect. It cost one round.

**Open 6, the watchdog is written but not yet OBSERVED running: STILL OPEN, and
I cannot close it from here.** The GitHub API returns 403 through this
sandbox's proxy and there is no `gh` CLI, so run history is unreadable. What I
can say from the delivery log is that it did not fire spuriously, and that its
grace window correctly covered the one 31 minute gap today. Closing this needs
one observed scheduled run.

**Open 7, a merge that touches flutter/ without bumping the stamp is invisible
to the watchdog: STILL OPEN, and today adds a second blind spot to it.** The
watchdog compares main's CURRENT stamp against the last delivered one. When
f2.43 failed and f2.44 replaced it 31 minutes later, the watchdog's answer
became "ok" and the failed delivery became invisible to it forever. **It is a
stall detector, not an audit trail.** Open 9 is the fix for that half.

**NEW Open 8: split the publish step from the log scraping step in
flutter-preview.yml,** so a failure while READING the log can never suppress
the APK upload or the delivery row. Automated tier. Not done.

**NEW Open 9: record failed publishes in docs/delivery-log.md** with mode
`FAILED`, so a gap in the log is self explaining instead of needing four
commits of archaeology. Automated tier. Not done.

**NEW Open 10: nothing holds Pan's rendered size.** Three tuned numbers, no
test. Automated tier available. Not done.

**NEW Open 11: nothing stops a sixth private kicker.** The five were merged
into one widget; the pattern that created them is untouched. Automated tier
available, with no precedent in this suite for scanning lib/. Not done.

**NEW Open 12: CLAUDE.md names a branch that does not exist,** in two places,
plus one dead entry in flutter-preview.yml's trigger. Medium tier. Not done.

### Guard status re-check

Read, not assumed. Nothing has been quietly deleted or routed around.

- flutter-check.yml on `'claude/**'`: PRESENT, and it covered today's branch
  even though that branch is not the one CLAUDE.md names.
  .github/workflows/flutter-check.yml:20.
- The nothing-shipped failure issue: PRESENT, flutter-preview.yml:220.
- The release install shout: PRESENT and it fired twice today by design,
  flutter-preview.yml:245.
- The auto-close on recovery: PRESENT, flutter-preview.yml:262.
- The duplicate stamp refusal: PRESENT, flutter-preview.yml:173.
- The publisher watching its own definition (session 2's finding): PRESENT,
  flutter-preview.yml:23. It earned its keep today: 4d2fbba edited only the
  workflow and a Dart file, and the workflow being in its own paths filter is
  what guarantees a publisher edit exercises the publisher.
- The concurrency group with `cancel-in-progress: false`: PRESENT,
  flutter-preview.yml:31.
- The delivery watchdog: PRESENT, .github/workflows/delivery-watchdog.yml,
  including the `--first-parent` fix and the 2700 second grace.
- The stamp cap: PRESENT and passing, four tests.
- The screenshot harness in CI with `--update-goldens`: PRESENT.
- pan_tint_test.dart: DELETED on purpose, replaced by pan_signature_test.dart
  guarding the opposite property. Lesson 10.

### What it cost, and what it did not

Cost: one merge that delivered nothing and had to be re-shipped under a new
version number, roughly 40 minutes plus one round of the founder asking twice
for a link that did not exist. Two manual APK installs in one day for one
feature. One round where the founder was the detector for a size problem. And
about three hours of build, measure and render work on Pan's per theme colour
that was deliberately deleted the same day, which is not waste, that is a
decision being made properly with the evidence in front of it.

Did not cost: any wrong number, any lost data, any stranded install, any real
stray asset shipped. Every stamp that reached the phone was the right one,
patch 1 landed cleanly on 0.6.2+11, and the near miss with the eight PNGs was
caught by the person who made it and turned into a test the same hour.

### For the founder, in plain English

Some words first, so the rest reads straight.

A **patch** is a small update the app downloads by itself when you reopen it.
A **release** is a whole new app file, an APK, that you have to install by
hand. Patches can only be applied on top of the exact release they were built
for, and anything involving pictures has to be a release, because patches
cannot carry pictures.

**What happened.** Five updates reached your phone today and all five were
correct. One did not, and you noticed before we told you, which is the part
worth fixing.

At 04:00 in the morning we merged the batch with Pan's real face. That one
needed a new app file, because it contains pictures. The publishing robot did
its job, made the release, and then tripped over its own shoelace on the very
last instruction. Here is the shoelace, and it is almost funny. After
publishing, the robot reads its own log to find out which patch number it just
shipped, so it can write that number down for you. On a normal update the log
says "Published Patch 35" and the robot finds it. On a NEW APP FILE the log
never says that, because there is no patch number, there is a version number.
The robot searched, found nothing, and the tool it searches with treats
"found nothing" as an error. So the robot declared failure, and everything
after that point was skipped: it never uploaded the app file for you to
download, and it never wrote the row that tells us something shipped.

The cruel part is the order. It failed AFTER succeeding. The release existed on
the server, so from every angle except your phone it looked done. And I told
you the APK was building. It was not building. It was already dead. You asked
for the link twice, and both times there was no link to give, because the file
had never been uploaded.

**Why it happened.** That one line had worked 35 times in a row. It only ever
sees normal updates, and normal updates always have the word it is looking for.
The first time it met a new app file, it broke. Nothing was rushed and nobody
was careless. A thing that had never been tested against a rare input met that
input for the first time, and the rare input happened to be the most important
event we have.

The same shape caused three other things today. A test that checked the size of
Pan's picture folder was actually only adding up four files by name, while the
app ships the whole folder, so eight leftover files I made while experimenting
would have shipped invisibly and broken future updates days later. A style used
across the app turned out to be written out five separate times, and two of
them had been updated and three had not, so the same little heading looked
different depending on the screen. And Pan looked tiny to you because his
picture has empty space built into its edges, 22% of it, so asking for 56
pixels of Pan gave you 43 pixels of actual cup.

All four are the same mistake: we measured something CLOSE to the real thing
instead of the real thing itself, and the close thing agreed with reality until
the day it did not.

**What now makes it impossible.**

The publishing robot no longer treats "found nothing" as an error, and there is
a long comment above that line explaining what it cost, so nobody tidies it
away.

The picture folder test now weighs the actual folder, and a second test fails
if there is anything in there that is not one of Pan's four faces. I did not
take that on trust: I put a fake stray file in the folder during this session
and watched the test go red with the file's name in the message, then removed
it.

The five copies of that heading style are now one.

**What it costs if a guard is removed.** Take the two words `|| true` out of
the publishing robot and the next new app file publishes to the server and
never reaches you, silently, exactly as it did this morning. Take the stray
file test out and the next stray picture ships, and the symptom arrives days
later as updates mysteriously refusing to install, in an error message that
mentions nothing about stray files.

**Three things I want to be straight with you about.**

First, the guard that failed today was not a piece of code, it was me. The rule
"never say it shipped until the log says it shipped" was already written down
and it was right. It says do not say "live". I said "building", which is not
the banned word but meant the same thing to you. I am tightening the rule to
cover any sentence about a build at all, and I want to be honest that a written
rule is a weaker guard than a test. A test works when nobody is watching. A
rule only works when it is read at the right moment, and this one was not.

Second, you had to install the app by hand twice in one day, five hours apart,
for the same feature. That is more than it should have been. The first install
was needed because pictures cannot be patched. The second was needed because we
replaced the pictures with better ones afterwards. Settling the artwork first
would have cost you one install instead of two. When you said Pan looked too
small, we deliberately fixed it by changing numbers in the code rather than
re-cropping the pictures, specifically so it could reach you over the air with
no third install. That part went right.

Third, and this is a small thing that will otherwise confuse you: your Update
stamp row now shows **patch 1**, after showing patch 35 this morning. That is
not a step backwards. The patch counter starts again at 1 for every new app
file, and you installed two new app files today. Patch 1 on version 0.6.2+11 is
newer than patch 35 on version 0.5.0+8.

One last note, since it is the sort of thing you should be told rather than
left to find. Our own rules file tells us to work on a branch called
`claude/salapify-v2`. That branch does not exist any more. It has not caused
any harm, and today's work still got checked properly, but it is the third time
in three of these sessions that our rules file has confidently stated something
that is no longer true. A wrong rule is worse than no rule, because it gets
read with authority. It is on the list to fix.

---

## 2026-07-25, session 4: the wall, the boxes, and ninety one minutes of nothing

### What we believed / What was true

Four beliefs this round. One of them was true, and it is the one that matters
most.

**Believed: all four stamps reached the phone. TRUE.** Read from
`git show origin/main:docs/delivery-log.md`, not assumed: f2.36 patch 30 at
07:21 UTC, f2.37 patch 31 at 08:01, f2.38 patch 32 at 10:36, f2.39 patch 33 at
11:57. All mode `patch`, all app version 0.5.0+8, `flutter/pubspec.yaml` still
`0.5.0+8` so no base APK was stranded. The founder confirmed on the phone that
the lesson ticks are back, which closes the f2.34 fix from session 3 with the
only evidence that counts. Delivery worked. This entry is not about a delivery
failure.

**Believed: the Update stamp was a row.** True: it was roughly forty lines. The
founder sent a screenshot of it filling the whole screen. Measured from git
rather than described: the stamp text was 424 characters at f2.34, 765 at
f2.35, 896 at f2.36, and 1264 at f2.37, which is what the founder photographed.
The number of version names inside it went 1, 2, 3, 4. Each build appended the
previous build's notes instead of replacing them, and the row it lived in was a
right-aligned `Text` with no line limit, so nothing pushed back. This was
self-inflicted, by Claude, over six consecutive builds, and the founder had to
be the one to notice.

**Believed: boxes in the screenshot render are a harmless sandbox artifact, and
CLAUDE.md said so in writing.** True: twice in one day the boxes were the
defect. First when icons became the thing being reviewed, second when the
diagnostics report used a monospace font the harness does not have, so the one
screen in the app that shows data leaving the phone rendered as solid boxes.
The note that excused boxes was accurate when it was written. That is what made
it dangerous.

**Believed: a merge to main publishes in about eleven minutes.** True, usually.
Measured across this round: 11 minutes, 11 minutes, 9 minutes, and once 102
minutes, because the run sat in GitHub's queue for 91 minutes waiting for a
free runner. Nothing in the repository was wrong. Nothing in the repository
said a word either.

### Timeline (with evidence)

All times UTC, from the commit dates and from the timestamps the publisher
wrote into docs/delivery-log.md. Stamp lengths measured by extracting the
`updateStamp` constant from each commit.

| Time | Event | Evidence |
|------|-------|----------|
| 06:24 (prev round) | **Wall divergence.** c68f750 writes f2.35 and, for the first time, appends the previous build's notes. 765 characters, two version names | git show c68f750:flutter/lib/main.dart |
| 07:04 | 8fa04b7, stamp f2.36, 896 characters, three version names | git log |
| 07:10 | Merge #192 (624af1b) | delivery row f2.36 patch 30 at 07:21 |
| 07:44 | 35024fc, one orange icon family. Stamp f2.37, 1264 characters, four version names | git log |
| 07:44 | The renderer is taught to load MaterialIcons from the running SDK, and to print a loud WARNING if it cannot find it | flutter/test/screens_shot.dart |
| 07:50 | Merge #193 (3f9c23f) | delivery row f2.37 patch 31 at 08:01 |
| after 08:01 | **Founder screenshot: the stamp row fills the screen** | founder message |
| 08:20 | 44f0237, the renderer draws dark as well as light | git log |
| 08:49 | 3de299e, stamp f2.38 cut to 82 characters. test/update_stamp_test.dart added. update_card.dart gains maxLines 4. Two false lines in CLAUDE.md corrected | git show 3de299e --stat |
| 08:54 | Merge #194 (8d71c91) | git log |
| 08:54 to 10:25 | **Queue divergence.** The publish run never starts. No runner. Zero runs in progress, all four workflows from the merge stuck identically. Not cancelled and not re-pushed, on purpose, because both add jobs to a queue that is not moving | session record |
| 10:25 | c55367f, the Copy diagnostics button. The render shows the report as solid boxes, monospace removed, three stacked button labels shortened. Stamp f2.39, 76 characters | commit message of c55367f |
| 10:36 | f2.38 finally publishes, 102 minutes after its merge | delivery row f2.38 patch 32 |
| 11:48 | Merge #195 (3a8b46a) | git log |
| 11:57 | f2.39 delivered, 9 minutes after merge | delivery row f2.39 patch 33 |
| 13:16 | 4fde57a, .github/workflows/delivery-watchdog.yml | git log |

Merge to delivery row, measured: 11, 11, 102, 9 minutes. The normal case is 9
to 11 minutes. That measurement is what justifies the watchdog's 45 minute
grace window, which is four times normal.

Verified on the checkout at the time of writing: `flutter analyze` reports "No
issues found", `flutter test` reports **693 tests passing**, and the screenshot
harness writes its shots in about eleven seconds.

Limitation, stated rather than hidden: the claim that zero runs were in
progress during the queue comes from the session record, not from a fresh
query. What does not need any API is the timing, and the timing alone proves
the anomaly: three merges in this round went from merge to delivery row in 9 to
11 minutes, and one took 102. That comparison comes entirely from git and from
docs/delivery-log.md.

### Divergence points

Three, because there were three separate splits between belief and reality, at
three different moments.

**The wall: 06:24 UTC on commit c68f750**, in the round session 3 wrote up. That
is the first push where the stamp stopped naming only itself. It was already
too long before that (326 to 496 characters at f2.30 through f2.34, four to
eight lines on a phone), but the appending is what turned "too long" into
"forty lines". Session 3 did not catch it. Worse, and this is the sharpest
single fact in this entry, session 3's own Lesson 6 **endorsed** it: "when
several stamps merge together, the delivered stamp's text must cover everything
since the last delivery row." That guard, written to stop a stamp's notes being
lost, is the mechanism that grew the wall. A guard aimed at one failure created
another.

**The monospace boxes: the moment the note became true.** There is no commit
for this one. The divergence is that a sentence in CLAUDE.md went from
describing an irrelevant artifact to excusing a real defect, without changing a
single character. Nothing can detect that transition, which is exactly why it
deserves the most attention here.

**The queue: 08:54 UTC**, the merge of #194. From that second until the founder
asked "what happened to f2.38", every signal in the system was consistent with
success, because a run that has not started looks precisely like a run about to
finish. The founder asked twice, once about f2.38 and once for "status now", so
the reporting failed even though no code did.

### Root cause

**The stamp wall.** The stamp had two jobs, and they fight. Job one, answer
"which build am I running", needs one short line. Job two, added by session 3,
carry forward everything since the last delivery row so no notes are lost,
grows without limit. Nothing arbitrated between them, and nothing measured the
result. The root cause is not carelessness in writing long stamps; it is that
one field was assigned two purposes with no bound, and the only place the
outcome was visible was the founder's screen. Note the shape: a rule with no
number in it drifts, and a rule with a number that nothing checks drifts just
as fast.

**The monospace boxes.** A documented known-artifact is a standing invitation to
dismiss a real defect, and the invitation is strongest exactly when the
artifact overlaps what is being reviewed. The note said boxes are a sandbox
artifact, never fix one of those. It was true for emoji. It was false for icons
the moment icons were the subject, and false again for monospace text a few
hours later. The root cause is not the note being wrong, because it was right.
The root cause is that the artifact was documented instead of eliminated, and a
documented exception trains the reviewer to filter out the exact pixels a
defect would hide in. Boxes were caught this time only because someone looked
at the harness output and refused to apply their own rule.

**The 91 minute queue.** Every alarm in this repository fires when something
FAILS. Nothing fires when something never runs. The publisher has an
`if: failure()` step that opens an issue, and it is a good guard, but a job
sitting in a queue has not failed, so nothing was there to speak. The root
cause is that the monitoring watched causes rather than the outcome, and the
outcome is the only thing the founder experiences.

**The bug in the watchdog.** The first version used
`git log -1 -- flutter/lib/main.dart`, which returns the BRANCH commit that
wrote the stamp, not the merge that put it on main. Verified by running both
forms against origin/main: without `--first-parent`, 10:25; with it, 11:48.
Eighty three minutes apart, on the very stamp in front of us. Any batch that
took longer than the 45 minute grace window would have fired a false alarm the
instant it merged, every single time. The root cause is that a new guard is
itself untested code, and it was written from a mental model of git rather than
from a measurement of git.

**CLAUDE.md going stale, third consecutive session.** Two lines had gone false:
that the render uses the light palette only, and that icons draw as boxes. Both
were corrected. The root cause is structural and worth naming precisely:
CLAUDE.md stores facts that live somewhere else. A sentence about what the
renderer draws is a copy of a fact owned by flutter/test/screens_shot.dart, and
a copy has no way to know when the original changes.

### Lessons and guards

**Lesson 1. A field with no limit and two jobs will grow until a human
complains.**
Guard, part one: `flutter/test/update_stamp_test.dart`, which caps the stamp at
120 characters and fails if it names more than one version, that second
assertion aimed at the precise mechanism that grew the wall.
Guard, part two: `maxLines: 4` with ellipsis overflow on the row itself, so
even a stamp that gets past the test cannot take the screen.
Strength: **strong**. Automated, fails loudly, two independent layers where
either alone would have failed here.
Verified with teeth rather than trusted. A deliberate 247 character wall naming
five versions was written in, and both assertions fired, each naming the
mechanism rather than just the number. Reverted immediately.

**Lesson 2. A documented known-artifact is a licence to dismiss a real defect,
and it is most dangerous when the artifact overlaps what is under review.**
This is the most important lesson in this session.
Guard, part one, and the only strong kind: **remove the artifact instead of
documenting it.** The harness now loads MaterialIcons from the running Flutter
SDK, so Salapify's own icons render for real, and it prints a loud warning
rather than quietly drawing boxes again. The monospace family in the
diagnostics report was deleted outright, since the report is lines and not
aligned columns, so monospace bought nothing and cost the reviewability of the
one screen that moves data off the phone.
Guard, part two: the CLAUDE.md note now states what it does NOT excuse, in the
same breath as the artifact.
Strength: **strong** for the part that removed the artifact, because a font
that loads cannot be misread. **Medium** for the residual, which is emoji, all
of it user data now, and genuinely cannot render in this sandbox.
The general rule: any note that tells a reviewer to ignore something must be
written as a fence around a narrow case, never as a class of pixels. "Emoji in
user data draw as boxes" is a fence. "Boxes are fine" is a blindfold.

**Lesson 3. Every alarm we had fired on failure. Nothing fired on absence.**
Guard: `.github/workflows/delivery-watchdog.yml`, on a 30 minute cron, which
reads the stamp main is built at, reads the last delivered stamp out of
docs/delivery-log.md, and if they disagree for more than 45 minutes opens ONE
issue, comments rather than duplicating, and closes it when they agree again.
Strength: **strong in design, and inert until merged.** GitHub only runs
scheduled workflows from the default branch. "The guard is written" and "the
guard is running" is the same one word gap as "merged" and "delivered".
**Is watching the symptom rather than the cause the right call? Yes, and it is
the whole reason this guard is worth having.** Causes multiply: a queued
runner, a cancelled run, a run that died before its own failure notice, a paths
filter that never triggered, a publish step that failed silently. Five causes
have already happened, and a watchdog written against any one of them would
have missed the next. There is exactly one symptom, nothing new reached the
phone, and it is the only thing the founder ever experiences. A symptom
watchdog also cannot rot the way a cause watchdog can, because it encodes no
assumption about how delivery works. The cost is that it cannot say why, which
is handled by the issue body listing the causes in the order they have actually
happened.
One hole, named rather than glossed: it reads main only, so work that is
finished but never merged is invisible to it. That was session 3's failure and
it stays covered by a rule plus the informational branch step.

**Lesson 4. A new guard is untested code, and a guard that cries wolf is worse
than no guard, because it teaches people to ignore alarms.**
The `--first-parent` bug would have made the watchdog fire falsely on every
batch longer than 45 minutes, which is most real batches. It was found by
measuring git, not by reading the watchdog again.
Guard: the reasoning is written into the workflow itself, naming the two real
timestamps so the next person to touch that line knows what removing it costs.
Strength: **medium**. A comment is a rule, not a check.
The transferable practice, now written into CLAUDE.md: **before trusting a new
alarm, prove both halves.** Prove it fires when it should, and prove it stays
SILENT when it should. Only the second half was ever in doubt here, and only
the second half was broken.

**Lesson 5. CLAUDE.md stores facts that live somewhere else, so it goes stale
by construction. Third consecutive session.**
Session 3 made re-reading CLAUDE.md's factual claims a step of every
retrospective, and that step caught both false lines this round, so **the guard
is working**. It is also working at the wrong end: it catches false claims
after they have already been read with authority for hours.
Two claims that went false are now self-maintaining: the harness names its own
output `-light` and `-dark`, so the dark mode claim is visible in a directory
listing, and it prints a warning if the icon font is missing, so the icon claim
announces its own falsity.
Drift found this session, and both fixed in this commit:
- CLAUDE.md said the renderer produces "fifteen shots in about eight seconds".
  It was stale within HOURS of being written, because two shots were added the
  same day. The numbers are now gone rather than corrected: numbers in prose
  rot, and the directory listing is the count.
- The new stamp rule said the detail belongs in the pull request and
  docs/delivery-log.md. That file has no notes column and is not meant to gain
  one; it records what shipped, not what changed. Half of the destination the
  rule named did not exist. Now it names the pull request only.

**Lesson 6. Session 3's Lesson 6 is superseded, and it caused this round's most
visible defect.**
Session 3 wrote that when several stamps merge together, the delivered stamp's
text must cover everything since the last delivery row. That rule is now void.
The stamp answers one question, which build am I running, and the founder said
so directly: high level only. This is recorded because a retrospective log that
silently keeps a superseded guard is a trap of exactly the kind Lesson 2 is
about. It will be read later, with authority, and it is wrong.
Guard: the 120 character test enforces the new rule mechanically, so the old
rule cannot be followed even by someone who reads it.
Strength: **strong**, and note what happened. A rule was replaced by a check,
which is the upgrade every entry in this log keeps asking for.

**Lesson 7. Proving a new test can fail is now a standing rule.**
Three guards were proven this way in one day, each in about three minutes: the
stamp cap rejected a deliberate wall, the icon test caught a renamed icon name
reaching the silent fallback, and the diagnostics privacy test caught a
plausible leak by name. So "no time" is not an objection.
Guard: written into CLAUDE.md, tied to a moment. When adding a test that guards
a lesson, break the code once, watch it fail, and paste the failure line into
the commit message.
Strength: **medium**, and that will not be dressed up. It is a rule and depends
on being followed. Two things make it more than an intention: the cost is
measured, and the artifact is visible, because a commit message either quotes a
real failure line or it does not.

**Lesson 8. Two tests changed this round, and both deserve naming even though
neither was defending a bug.**
This log treats a test that had to change for a fix to pass as the strongest
evidence that the suite was defending the defect, so honesty requires reporting
the changes and also reporting when they are innocent.
Four assertions in flutter/test/mindset_screen_test.dart lost an emoji prefix.
Honest read: not a bug being defended. It was decoration pinned into a data
assertion, so a purely visual change broke four tests that were never about
visuals. The smaller real lesson: an assertion should name the thing it is
about, because one that also captures styling will block a legitimate change
and be edited under pressure, which is the state in which a genuinely wrong
edit gets made.
The second change is the more dangerous kind. `test/goldens/lessons_goldens.json`
was regenerated, 44 lines, and a golden regeneration is precisely where an
unnoticed content change hides. The commit claimed the diff touches the icon
field and nothing else. That was verified independently rather than believed:
the number of changed lines in that file that are not an icon or emoji field is
**zero**.

### Open lessons carried forward

**Open 1, a Shorebird step failure is silent: CLOSED, re-verified.** The
`if: failure()` notice, the release warning, the auto-close, the delivery row
writer, and the self-watching path are all still present in
.github/workflows/flutter-preview.yml. Nothing has been quietly deleted or
routed around.

**Open 2, a pubspec version bump strands the installed app: CLOSED, still
verified.** pubspec is still 0.5.0+8, all four rows this round say `patch`, and
the `mode == 'release'` issue step is still present and still gated correctly.

**Open 3, nothing compares the phone to main: STILL OPEN, and the repository
half is now genuinely closed rather than half closed.** Read the halves
precisely. The repository half, does what main is built at match what the
publisher says it shipped, was answerable before but only by a human choosing
to read the log. With the watchdog merged, something reads it every 30 minutes
and speaks without being asked. The phone half is not closed and cannot be
closed by this watchdog, because a patch published is not a patch installed:
Shorebird delivers on reopen, so a green row proves what left the building,
never what arrived. The founder tapping check-for-update is still the only
proof.
What changed this round is that the phone half became cheap to report. The new
Copy diagnostics button prints the build and patch as TEXT, so a paste beats a
photograph and can be compared mechanically against the last delivery row.

**Open 4, the screenshot harness can rot: CLOSED, re-verified and now proven
useful.** The harness step is still in flutter-check.yml with
`--update-goldens`, and it is no longer theoretical: it caught two real defects
this round, the monospace boxes and three long button labels stacked into a
vertical column taking a third of a dialog.

**Open 5, there is nowhere to read what a build changed: CLOSED as not a
problem.** Capping the stamp was right, and the founder asked for high level
only. The pull request is the place for detail. The false half of the rule, the
sentence pointing at a delivery log with no notes column, is fixed in this
commit.

**New Open 6, the watchdog is written but not yet observed running.** It is
merged in this batch, but no scheduled run has been seen yet. This is the same
shape as session 3's unmerged pull request applied to a guard, which makes it
the more expensive version: an unmerged feature delivers nothing, an unmerged
guard delivers a false sense that a gap is covered. Closes when one scheduled
run has been observed doing its comparison.

**New Open 7, a merge that touches flutter/ without bumping the stamp is
invisible to the watchdog.** In that case main's stamp already equals the
delivered stamp, so the watchdog reports `ok` while a patch is genuinely
pending. Partially covered, and worth being precise about how: the publisher
refuses to record a stamp identical to the last delivered one and exits 1 after
publishing, which trips the failure notice. So the situation gets reported, by
a different guard, with a message about a duplicate stamp rather than about a
pending build.

### What it cost, and what it did not

Cost: one founder screenshot spent on a wall of text that Claude created over
six builds, 91 minutes of a delivered build sitting in a queue while the
founder asked twice for status, and one round where the founder had to be the
detector for a cosmetic defect a render would have shown at a glance.

Did not cost: any user data, any wrong number, any undelivered build, any
stranded APK. All four stamps reached the phone, and the founder confirmed the
ticks are back, which closes the one real data-shaped scare from session 3 with
evidence from the only source that counts.

Nearly cost, and worth recording: the diagnostics report is the one feature in
Salapify designed to move data off the phone. It shipped with a test that fails
by name on an amount, a merchant, an account, a person, a note, or a category,
and that test was proven to fail before it was trusted. That is the correct
order of operations for a privacy promise.

---

### For the founder, in plain English

**What happened.** All four builds reached your phone, and your ticks are back.
That part worked. Three things went wrong around it.

First, the Update stamp row, the line in Menu that tells you which build you
are running. It grew into about forty lines and filled your screen, and you
sent me the screenshot. This one was entirely my doing, over six builds: each
time I wrote a new stamp I pasted the previous build's notes in front of it, so
it got longer every time. I measured it, and it went from 424 characters to
1264. The row also had no limit on how many lines it could draw, so nothing
stopped it. Two things now stop it. A test refuses any stamp longer than 120
characters or that mentions more than one build, and the row itself refuses to
draw more than four lines even if something gets past the test. I proved both
work by deliberately writing a wall and watching them reject it.

Second, and this is the one I would most like you to take away, because it is
the subtlest mistake in this whole log. When I take a picture of a screen to
check it, some characters cannot draw in my sandbox and come out as empty
boxes. I had written that down as a known quirk to ignore. That note was
completely true. Then twice in one day the boxes WERE the problem. Once when
the icons were the exact thing I was reviewing, so a screenshot full of boxes
proved nothing at all. And once when the new diagnostics screen used a
typewriter style font my sandbox does not have, so the one screen in the app
that shows data leaving your phone came out as solid blocks. If I had followed
my own note, I would have shipped a screen I had never actually seen. The fix
was not a better note. It was to make the boxes go away: I load the real icon
font now, and the typewriter font is gone because it bought nothing. A written
excuse to ignore something is dangerous in a specific way. It is most tempting
exactly when the thing you are ignoring is the thing that is broken.

Third, f2.38 took 102 minutes to reach you instead of the usual 9 to 11.
Nothing was broken. GitHub, the company that runs the machines that build
Salapify, had no free machine, so the job waited in line for 91 minutes. Here
is the uncomfortable part: I had alarms for a build that FAILS and no alarm at
all for a build that never STARTS, and those look identical from outside. You
noticed before I did, and you asked twice. Even though no code was at fault,
the reporting was.

**Why it happened.** All three come from the same habit. Something was true,
nobody measured whether it was still true, and the only place the answer showed
up was your screen. The stamp had no number attached to "keep it short". The
box note had no expiry. And the delivery pipeline was watched for the ways it
had already broken rather than for the one thing you actually care about,
whether something new arrived.

**What now makes it impossible.**
- The stamp physically cannot be long again. That is a test, not a promise.
- The icons draw for real in my screenshots, and if the font is ever missing
  the run prints a loud warning instead of quietly drawing boxes.
- A new watchdog wakes up every 30 minutes, compares the build main is carrying
  against the last build the log says reached your phone, and if they disagree
  for 45 minutes it opens an issue. It does not care WHY nothing shipped, which
  is deliberate: five different causes have already happened, and a guard aimed
  at one would miss the next.
- The Copy diagnostics button closes the one gap I cannot close myself. When
  something looks wrong, tap it, read what it says, and paste it to me. It has
  counts and error messages only, never your amounts, names, notes, or the
  people you owe. There is a test that puts fake incriminating data in and
  fails by name if any of it escapes, and I broke the code on purpose to watch
  that test catch it before trusting it.

**One thing I found by testing my own new alarm.** The watchdog was wrong the
first time I wrote it. It looked up the wrong date, so any batch of work that
took more than 45 minutes would have set off a false alarm the moment it
merged. That matters because a smoke alarm that goes off while you cook gets
the battery taken out, and then it is not there during a fire. It is fixed, and
the reason is written into the file so nobody undoes it later.

**What it costs if a guard is ever removed.**
- Remove the stamp test, and the row goes back to eating your screen, one build
  at a time, and you will be the one who has to say so again.
- Remove the icon font from my screenshot harness, and every screenshot I show
  you becomes a picture I cannot actually read, while I tell you I checked it.
- Remove the watchdog, and a build that never starts goes back to looking
  exactly like a build about to finish, and you find out by asking.
- Remove the privacy test on diagnostics, and one harmless looking edit puts
  your amounts and the names of people you owe into text you paste into a chat.
  That is the guard whose removal I would consider most serious, because unlike
  a missed build it cannot be undone.

**Still true and still not fixed:** nothing on my side can see your phone. The
log tells me what left the building, never what arrived, because Salapify
downloads its update when you reopen it. You are still the last check in the
system, and your one tap is still the only real proof. That is acceptable while
you are the only user. It stops being acceptable at launch, because a stranger
will not tell us, they will just stop opening the app.

---

## 2026-07-25, session 3: the eyes we already had

### What we believed / What was true

Three beliefs this round, at three different moments.

Believed: f2.31 was on its way to the phone.
True: it was sitting in an open pull request (#188) for 41 minutes while the
founder tapped "check for update" and read f2.30 back. The founder reported it,
in those words: "theres no update when I clicked..It is still f2.30".

Believed: the lesson redesign that shipped in f2.30 and f2.31 read well,
because 673 tests were green.
True: two lessons were visibly broken on the phone. The Philippine tax lessons
rendered five paragraphs of reference prose as one wall of text, with three
sentences printed twice, and lessons the founder had already finished went back
to unfinished when reopened. Both were found in founder screenshots. Neither
was catchable by any test in the suite.

Believed: Claude had no way to look at a Flutter screen, so the founder was the
only pair of eyes.
True: the capability existed all along. It had been attempted, it appeared to
hang, and it was abandoned without the reason ever being written down.

Believed and TRUE, for once: the delivery pipeline itself. Every merge this
round produced exactly one row in docs/delivery-log.md, and the phone ended on
f2.35, patch 29, which is what the log says. Rows for f2.30 patch 25, f2.31
patch 26, f2.32 patch 27, f2.34 patch 28, f2.35 patch 29. All mode `patch`, all
app version 0.5.0+8. The stamp f2.33 has no row and never reached a phone,
which is correct and explained below.

### Timeline (with evidence)

All times UTC, from `git show -s --format=%ad` on each commit and from the
timestamps written by the publisher into docs/delivery-log.md.

| Time | Event | Evidence |
|------|-------|----------|
| 01:31 | Merge #187 (2ec1b5d) | delivery row f2.30, patch 25, run 30138654637 |
| 01:43 | f2.30 lands on the phone | docs/delivery-log.md |
| 02:08 | Commit 5f599dc pushed to the branch, stamp f2.31 | git log |
| 02:08 to 02:49 | **Divergence.** Built stamp f2.31, delivered stamp f2.30. Founder taps check for update, sees f2.30, reports it | founder message |
| 02:49 | Merge #188 (3d8d9b1) | delivery row f2.31, patch 26, 03:00 |
| 02:50 | "Finished means delivered" written into CLAUDE.md (ba889ac) | git log |
| 03:14 | Commit 197fe3a, stamp f2.32 | git log |
| 03:26 | Merge #189 (9043b3e) | delivery row f2.32, patch 27, 03:37 |
| 03:46 | Commit 282023e, stamp f2.33, the tax lesson fix | git log |
| 05:44 | Commit ac1a36e, stamp rewritten to f2.34, the disappearing ticks fix | git log |
| 05:51 | Merge #190 (b6b64ca), both stamps in one merge | delivery row f2.34, patch 28, 06:02 |
| 06:17 | Commit ea37949 puts the screenshot harness in flutter/tool/ | git log |
| 06:17 to 06:22 | **The branch check goes red.** flutter analyze fails: tool/ is production code to the analyzer, and SharedPreferences.setMockInitialValues is test only | commit message of 4875f41 |
| 06:22 | Commit 4875f41 moves it to flutter/test/screens_shot.dart, check green | git log |
| 06:24 | Commit c68f750, stamp f2.35 | git log |
| 06:30 | Merge #191 (26ff2cf) | delivery row f2.35, patch 29, 06:42 |

Verified on the checkout at the time of writing: `flutter analyze` reports "No
issues found", and `flutter test` reports 677 tests passing. The count being
677 and not higher independently confirms that flutter/test/screens_shot.dart
is not collected by the runner, because it does not end in `_test.dart`.

### Divergence point

02:08 UTC, commit 5f599dc. That is the first push in this round where the built
stamp stopped matching the delivered stamp, and the gap closed only when a
human merged the pull request 41 minutes later. Nothing in the system was
watching that gap. Every guard written in sessions 1 and 2 answers the question
"did the thing we merged reach the phone". None of them answers "did we merge",
and none of them answers "is what reached the phone any good". Those are exactly
the two gaps the founder's eyes filled this round.

### Root cause

One root cause per finding, and one shape they share.

**Finding 1, the unmerged pull request.** "Finished" was defined as "the code is
written, the tests pass, the pull request is open". Under that definition the
work genuinely was finished, and there was nothing left to prompt a merge. The
root cause is a definition, not an oversight. A definition that ends before the
merge produces work that ends before the merge, and it does so reliably, for
anyone, on a busy day.

**Finding 2, the wall of text.** flutter/lib/content/lessons.dart expanded the
`reference` field of the Philippine tax lessons into a single ProseBlock
carrying five long paragraphs. The suite has 90 test files and not one of them
asserts anything about how a block looks on screen, because no test can. The
root cause is that no step in the process ever put a rendered screen in front of
anything with eyes. Related: three coaching lines repeated sentences that the
prose said again a paragraph later, which is the same root cause seen from the
other side, nothing compared the text of one block against another.

**Finding 3, the disappearing ticks.** flutter/lib/money/lesson_progress.dart
holds two records of "done": the legacy `settings.lessonsRead` list and the
newer `settings.lessonProgress` map. `parseLessonProgress` wrote the legacy
entries first and then let any newer entry overwrite them. A lesson finished
under the old build lives ONLY in the legacy list, so reopening it recorded
`viewed`, which shadowed `completed`, and the tick vanished.

The sharp part is why 673 tests were green. Eight lines above the offending
line, the source comment said, in the file itself, that "taking away a completed
tick is a worse wrong than leaving one that was generously granted". And a test
asserted the opposite behaviour on purpose, the one removed in ac1a36e:

    test('a new entry wins over the legacy list for the same lesson', () {
      ...
      expect(p['see-it-first'], LessonState.viewed,
        reason: 'the finer-grained record is the truthful one');

The file argued with itself, the test took the wrong side, and from then on the
suite was actively defending the bug. The root cause is not the overwrite, it is
that a test was treated as evidence for a belief when it was only a recording of
that belief.

**Finding 4, the abandoned capability.** A screenshot harness was attempted
earlier, appeared to hang with no output, and was written off. The real cause of
the hang is that `testWidgets` installs a fake async zone, so awaiting real file
I/O to load the shipped fonts never completes. The root cause of the two rounds
without eyes is not the hang, it is that the write-off was never recorded
anywhere. An undocumented conclusion cannot be challenged, corrected, or
inherited, so it stands until someone happens to ask, which is what the founder
did: "is there a way that you can see the screen of the app? is there something
i need to install or implement?" The answer was that nothing needed installing.

**The shape they share.** Every one of these was a belief held with confidence
and never checked against something outside itself. That is the same shape as
sessions 1 and 2, applied to new subjects.

### The guard that fired, and what it saved

Commit ea37949 at 06:17 put the screenshot harness at
flutter/tool/screens_shot.dart. The Dart analyzer treats tool/ as production
code, so `SharedPreferences.setMockInitialValues`, a test only API, became a
hard `flutter analyze` failure. The "Flutter check" action went red on the
branch, before any merge, and it was fixed five minutes later.

This matters more than it looks. The preview publisher runs the same
`flutter analyze` with zero tolerance, with no `continue-on-error` and no
`if: always()`. If that commit had been merged as it was, the publish would have
died at the analyze step and shipped NOTHING, while pull request #191 sat there
looking clean and merged. That is the exact shape of session 1, thirteen stamps
and 21 hours of it.

It cost five minutes instead, because of the branch check written in session 1
specifically so that a runner failure shows up before the merge rather than
after. A guard firing is not a failure of the process, it is the process
working. This is the first time a lunch and learn has been able to record one of
its own guards paying for itself.

### Lessons and guards

**Lesson 1. Work that is finished but not merged is not finished.**
The founder should never be the one to discover that something is waiting.
Guard: the "Finished means delivered" section now in CLAUDE.md (commit ba889ac),
which redefines finished as merged plus a delivery row, and requires saying out
loud why any open pull request is waiting before starting anything new.
Strength: **medium**. It is a rule, so it depends on being read at the right
moment. It is written at the strongest available point, the top of the workflow
rather than the end.
Applied this session: a step in .github/workflows/flutter-check.yml prints the
branch stamp next to the last DELIVERED stamp from docs/delivery-log.md on every
branch run. Informational, never a gate, because unmerged work in progress is
normal and failing there would cry wolf on every push. It puts the true delivery
state in the same output at the exact moment someone is deciding whether a batch
is done. Call it what it is: a louder rule, not a gate.

**Lesson 2. Tests confirm behaviour. They say nothing about whether a screen is
worth reading.**
Guard: flutter/test/screens_shot.dart renders real screens to PNG in about a
second, plus the "Look at the screen before shipping a screen" section of
CLAUDE.md which ties it to a specific moment, every UI change, before the merge.
Strength: **medium**. It is a tool plus a rule, and a tool only helps when
someone runs it.
The harness was already protected against one kind of rot, because
`flutter analyze` covers test/, so a renamed screen constructor breaks the
branch check. What was NOT protected is that it still RUNS: it is deliberately
excluded from `flutter test`, so it could rot silently and be abandoned a second
time, which is precisely how the first two rounds without eyes happened.
Applied this session: a "The screenshot harness still renders" step in
flutter-check.yml, running it with `--update-goldens`. That flag is load-bearing
rather than a shortcut, because test/shots/ is gitignored, so without it a fresh
checkout compares against a file that does not exist and fails for a reason that
says nothing about the app. With it, the only way the step can fail is if the
harness genuinely stopped working. Closes new Open 4 the same day it opened.

**Lesson 3. A test that asserts a belief is not evidence for the belief.**
The removed test did not merely fail to catch the bug, it defended it, with a
reason string that sounded like a principle. Meanwhile the comment eight lines
above the code said the opposite in plain words.
Guard: four regression tests in flutter/test/lesson_progress_test.dart,
including 'opening a legacy-completed lesson does not demote it' and an end to
end store test that reproduces the founder's phone exactly by importing an old
backup and reopening the lesson.
Strength: **strong**. Automated, fails loudly, and written from the observed
symptom rather than from the model.
Confirmed by reading rather than assumed: the fix repairs already-damaged phones
on its own. flutter/lib/money/lesson_progress.dart takes the higher rank of the
legacy and new entries, and the legacy entry was only ever shadowed, never
deleted, so it reappears the moment the new code runs. The test 'an
already-stored lower state is repaired by the legacy entry' asserts exactly that
recovery. The founder does not need to re-read anything and nothing was lost.
What is NOT guarded: nothing mechanically detects a test that contradicts the
comment above the code it tests. That cannot be automated with anything we have.
The nearest real practice is to treat any test CHANGED by a bug fix as suspect,
because a test that had to change to let a fix through was asserting the bug.
Say that out loud rather than pretend it is covered.

**Lesson 4. A capability written off after one failed attempt stays written off,
because nothing records the write-off.**
Guard: the CLAUDE.md section records not just that the harness exists, but the
three things that make it fail, and specifically that real file I/O must run
inside `tester.runAsync` because testWidgets uses a fake clock. The next hang is
now diagnosed in seconds rather than abandoned.
Strength: **medium**, and this is the strongest form available. "Do not give up
too early" is a habit and would be worthless. Writing down the diagnosis is
structural, because it survives the person who worked it out.

**Lesson 5. The branch check earned its keep. No new guard.**
See the section above. The honest finding is that the existing guard worked as
designed, and the correct action is to change nothing.
Strength of existing guard: **strong**, and now proven twice, once on the fix
that ended session 1 and once here.

**Lesson 6. One stamp per push, one patch per merge. That is fine, and it needs
saying.**
f2.33 was built, checked on a runner, and never delivered, because it was merged
together with f2.34 and Shorebird publishes one patch per successful run on
main. There is no f2.33 row and there should not be one. docs/delivery-log.md
already answers the only question that matters, which stamps exist on a phone,
and it answers it correctly by the absence of a row.
The real risk is that a skipped stamp's notes get lost, so the founder never
learns what changed. That did not happen: flutter/lib/main.dart carries the
f2.33 tax lesson notes forward inside the f2.34 and f2.35 stamp text, by hand.
Guard: when several stamps merge together, the delivered stamp's text must cover
everything since the last delivery row. Strength: **medium**, a rule, and it is
honest to add that this half cannot be automated. No machine can verify that a
paragraph of prose describes a change.
The adjacent failure mode CAN be machine-checked, and now is. Applied this
session: the publisher refuses to record a stamp identical to the last delivered
one. Two different builds under one name would silently break the single
comparison the founder can make that nobody here can fake.

**Lesson 7. Our own rules file contradicted itself about where the harness
lives.**
CLAUDE.md gave the command as `flutter test test/screens_shot.dart` and, 17
lines later, said "The file lives in tool/, not test/, on purpose". The file is
at flutter/test/screens_shot.dart. That sentence was the reasoning from before
the move, left behind after the move made it false. Session 2 found the same
class of thing, a false trigger rule. Twice in a row is a pattern, not an
accident.
Guard: the sentence is fixed, and "re-read CLAUDE.md's factual claims against
the repository" is now an explicit step of every lunch and learn.
Strength: **medium**. Stated plainly: this one cannot be automated. The false
sentence named two directories that both exist, so no path checker would flag
it. A rule that is wrong is worse than no rule, because it is read with
authority.

### Open lessons carried forward

**Open 1 from sessions 1 and 2, a Shorebird step failure is silent: CLOSED.**
Verified by reading .github/workflows/flutter-preview.yml rather than by
trusting the write-up. A step runs `if: failure()` and opens, or comments on, a
single issue titled "Preview build failed, nothing shipped to the phone", and a
later step closes that issue on the next green run so it cannot rot into noise.
The workflow now also watches its own path, which was session 2's unapplied
recommendation, so editing the publisher exercises the publisher. And the
publisher writes docs/delivery-log.md itself, so the ABSENCE of a row is
positive evidence of non-delivery, readable with plain git and no API access.
Three guards where one was requested. Closed.

**Open 2, a pubspec version bump strands the installed app: CLOSED this
session.** flutter/pubspec.yaml is still 0.5.0+8 and all five rows this round
say mode `patch`, so the situation has not yet arisen. Until now the only
warning was a word in a table that a human had to notice and pass on, and if
that human did not, the founder would receive nothing forever while every build
stayed green. Applied this session: a step gated on
`steps.ship.outputs.mode == 'release'` opens a GitHub issue saying a new base
APK exists and must be installed by hand, with the link. Same proven pattern as
the failure notice, different condition. Strength: **strong**.

**Open 3, nothing compares the phone to main: STILL OPEN, now half closed.** The
repository-to-shipped half is automated, docs/delivery-log.md answers it without
guessing. The shipped-to-phone half is still a human looking at a screen, and
this round that human found both bugs that reached the phone and the pull
request that never merged. That is not a criticism of the setup, it is a
measurement of how much load is resting on one pair of eyes. It is acceptable
while the founder is the only user. It stops being acceptable at launch.

**New Open 4, the screenshot harness can rot without anyone noticing: CLOSED the
same session it opened.** See Lesson 2. CI now runs it with `--update-goldens`
on every branch push.

### What it cost, and what it did not

Cost: 41 minutes of a stamp sitting unmerged while the founder checked the
phone, two rounds where the founder was the only way to see a screen, one wall
of text and one set of vanished ticks that reached a real phone, and one round
of founder screenshots spent on a problem that a one second render would have
shown.

Did not cost: any user data, any wrong number, and any undelivered build. Every
merge this round delivered. The disappearing ticks looked like data loss and
were not; the legacy record was hidden, never deleted, and it comes back by
itself.

---

### For the founder, in plain English

**What happened.** Three things, and only one of them was a real bug in the way
you would think of it.

First, a batch of work was ready and I did not press the merge button. You
tapped "check for update", saw the old build, and told me. You were right. The
work was sitting in a pull request, which is a proposal to add code to the main
copy of the app. A proposal is not a delivery. Nothing on my side was watching
for proposals that never got accepted, so it just sat there.

Second, two things that reached your phone looked wrong on screen, and you found
both by sending me screenshots. The Philippine tax lesson dumped five long
paragraphs as one block of text, in the middle of a redesign whose whole point
was to stop doing that. And lessons you had already finished lost their tick
when you opened them again. That second one is fixed, and here is the part that
matters: nothing was deleted. The old record of "you finished this" was still
there the whole time, it was just being hidden by a newer, lower record. The fix
takes whichever record says you did more, so your ticks come back on their own
the moment the app opens. You do not have to re-read anything.

Third, and this is the one I would most like you to remember: you asked whether
there was a way for me to see the app's screen, and whether you needed to
install something. Nothing needed installing. I could always do it. I had tried
once, it seemed to freeze, and I gave up without writing down why. The reason it
froze is technical and boring, the testing tool uses a fake clock, and reading
real files under a fake clock never finishes. Two rounds went by with you as the
only pair of eyes on this app, because I never wrote down a dead end. It now
takes about one second to render a screen and look at it, and there is a rule in
my instructions file saying to do that before shipping any screen change.

**Why it happened.** A "test" is a small piece of code that checks another piece
of code still does what it should. There were 673 of them passing while both of
those bugs were live. That is not surprising once you see what a test really is:
it checks what somebody thought to check. Nobody thought to check whether a
paragraph looked like a wall. Worse, for the vanishing ticks, there was a test
that specifically insisted on the wrong behaviour, written earlier with a
confident sounding explanation. So the tests were not silent about that bug,
they were defending it. That is the most useful thing in this whole session: a
passing test is a record of what someone believed, not proof that the belief is
right.

**What now makes it impossible.**
- Work that is written but not merged now counts as unfinished, in writing, at
  the top of my instructions. If a pull request is open, I either merge it or
  tell you why it is waiting, before I do anything else. And every branch build
  now prints the stamp on your phone next to the stamp being built, so the gap
  is visible instead of assumed.
- I can render any screen to an image and look at it, in about a second, my
  instructions say to do that before every screen change ships, and the build
  now runs the renderer on every push so it cannot quietly stop working and be
  abandoned a second time.
- The vanishing ticks now have four tests, one of which recreates your exact
  phone, old backup and all. That one is genuinely automatic.
- Repeated sentences are now caught by a test, which names the lesson and quotes
  the sentence. That is half of the tax lesson bug. The other half, whether a
  block reads as a wall, needs eyes, which is what the renderer is for.
- If a build ever needs you to install a new APK by hand, it now opens an issue
  saying so. That was the most dangerous state this pipeline had, because it
  looks exactly like success from every angle except your phone.

**One piece of good news you paid for earlier.** Partway through this round I
made a mistake that would have quietly shipped nothing to your phone, the exact
failure that cost thirteen builds a few days ago. The automatic check we added
after that outage caught it before the merge and turned red. It cost five
minutes instead of a day. That check is not decorative. If it is ever removed or
skipped "just this once", the cost is not five minutes, it is you tapping "check
for update" for hours while everything on my side looks green.

**What it costs if a guard is removed.**
- Remove the branch check, and a broken build merges, the publish dies, nothing
  reaches your phone, and every pull request still looks perfect. That is the
  thirteen stamp outage, again.
- Remove the delivery log, and "did it ship" goes back to being a guess. The
  answer to a guess is usually yes, and usually wrong.
- Remove the "finished means delivered" rule, and finished work sits in a
  proposal nobody accepted, and you find out by tapping a button.
- Remove the screenshot step, and you go back to being the only pair of eyes on
  every screen in the app.

**Still true and still not fixed:** nothing automatically compares the build on
your phone against the build we think is out there. You are still the last check
in the system. That is fine while you are the only user. It will not be fine
when there are strangers using this app, because a stranger will not tell us,
they will just stop opening it.

---

## 2026-07-24, session 2: a clean patch, and an audit of session 1's guards

### What we believed / What was true

Believed: the fix would deliver every stranded stamp in one patch.

True: it did. The phone shows **f2.26, patch 22**, "You are on the newest build
already", and the Menu now has the "New phone day" row that shipped in f2.24
and had never been on a phone before. Repo and phone agree: `updateStamp` in
flutter/lib/main.dart line 22 is f2.26. Nothing to investigate. This entry is
therefore step 6 only: an independent re-check of the guards written in
session 1, done by reading the repo rather than trusting the write-up.

### Guard status

**Lesson 1 guard (forced-offline FX test): VERIFIED, still strong.**
flutter/test/fx_log_test.dart lines 111 to 126 wrap the call in
`HttpOverrides.runZoned`, throw `SocketException` from `createHttpClient`, and
assert `askedForAClient` is true. flutter/lib/data/fx_service.dart line 134
uses the bare `HttpClient()` constructor, which routes through
`HttpOverrides.current`, so the override intercepts the real code path and the
test never reaches the network on a runner. The self-check is not decorative:
`askedForAClient` would be false, and the test would fail, if a refactor ever
moved the fetch off `HttpClient()`. It passes here, which proves the zone
really applies.

**Whole-suite sweep for machine dependence (the session 1 bug class): clean.**
All 90 test files, 614 tests, checked for network, clock, time zone, locale,
and filesystem coupling.
- Network: exactly one call site in the suite, the forced one above.
- Image goldens: none. No `matchesGoldenFile` anywhere, so the classic
  renders-differently-on-another-machine failure cannot occur. The `goldens/`
  directory is JSON number vectors, read repo-relative, deterministic.
- Locale: no `DateFormat`, `NumberFormat`, or `intl` formatting in lib/.
- Platform channels and temp files: no `path_provider`, no `MethodChannel`
  mocks in tests.
- Clock: `DateTime.now()` appears in about 15 tests, always to anchor seed data
  to the run day rather than to assert a fixed answer. Weekday-anchored payday
  seeds, `_monthsAgo` built with `DateTime(y, m - n, d)` which rolls over the
  year correctly, and every literal day argument is 15 or lower, so no test can
  ask for February 30.
- One narrow residual: fx_log_test.dart lines 137 to 147 assert local
  wall-clock strings. In a time zone whose daylight-saving gap starts at
  midnight on 2 January 2026, `DateTime(2026, 1, 2, 0, 30)` normalizes forward
  and the assertion fails. Sandbox and runner are both UTC, so this is
  theoretical. Logged, not fixed.

**Lesson 2 guard (.github/workflows/flutter-check.yml): VERIFIED, strong, with
a named blind spot.** The branch filter `claude/**` does match the working
branch `claude/salapify-continuation-3i8jup`. The paths filter is where it
misses. It does not run on: a push touching no file under flutter/ (proven on
this branch, commit fcf6433 touched only .claude/, CLAUDE.md and docs/, so the
current HEAD has no Flutter check); a branch not prefixed `claude/`; or main.
A workflow skipped by a paths filter shows as no check at all, not a red X, so
absence can read as approval. Practical consequence: if a pull request's last
commit is docs-only, its head commit carries no Flutter check.

**Lesson 3 and 4 guards (CLAUDE.md): VERIFIED, present and actionable.**
CLAUDE.md lines 104 to 111 name the "Flutter check" action as the pre-merge
equivalent, forbid treating a green local `flutter test` as a substitute, and
state that after EVERY merge to main we confirm the "Flutter preview APK" run
went green and actually published a patch. That names the action, the moment,
and both things to confirm, which is specific enough to act on. Residual: the
generic waiver at lines 96 to 100 ("blocked by billing or infrastructure ...
that condition is waived") still sits above and is never explicitly scoped away
from the Flutter checks. The post-merge sentence is unconditional, so there is
little for the waiver to attach to, but the words are still generic.

Separately, CLAUDE.md line 14 says "Every push touching flutter/ triggers the
'Flutter preview APK' action". That is not true as written: the publisher's
branch filter is main and claude/salapify-v2 only, so a push touching flutter/
on the current working branch triggers nothing. This sentence describes the
belief that made the session 1 failure invisible, and it is still in the file.
Guard: correct the sentence to say the publisher runs on main, and the branch
check runs on claude/** before the merge. Strength: **medium** (a rule, but an
accurate one beats an inaccurate one).

### New finding: the publisher does not watch its own definition

.github/workflows/flutter-preview.yml has `paths: 'flutter/**'` and does not
list itself. flutter-check.yml does list itself. So a push that edits ONLY the
publisher workflow triggers neither workflow: no check, and no publish. The
publisher can be broken, or believed fixed, with zero signal until the next
push that happens to touch flutter/, at which point it fails and ships nothing
while the pull request looks clean. That is the exact shape of session 1.
Guard: add `.github/workflows/flutter-preview.yml` to that workflow's own
paths filter, one line, so editing the publisher exercises the publisher.
Strength: **strong** once applied. Not applied in this session; it changes
delivery infrastructure and belongs in a normal reviewed change.

### Confirmed: the twelve failed builds consumed no patch numbers

Checked in .github/workflows/flutter-preview.yml. Step order is Analyze (line
52), Test (line 55), setup-shorebird (line 58), Release or patch (line 65).
No `continue-on-error`, no `if: always()`. A failed Test step ends the job, so
Shorebird was never installed and no patch command ever ran. The counter
genuinely sat at 21 and patch 22 is the next one. That reasoning is sound.
Limitation, stated rather than hidden: GitHub API access is not enabled for
this session and there is no `gh` CLI, so run ids 200 to 213 come from session
1's record, not from a fresh query. The step-order argument stands on the
workflow file alone.

### Open lessons carried forward

**Open 1. A Shorebird step failure is still silent.** Still open, and now
slightly wider: the new finding above means the publisher can also fail to
trigger at all. Candidate guard unchanged, an `if: failure()` step that files
an issue saying plainly that nothing shipped, plus the one-line paths fix.

**Open 2. A pubspec version bump strands the installed app.** Still open.
flutter/pubspec.yaml is still `0.5.0+8` and the run took the patch path, which
is why one patch could carry thirteen stamps. Coverage remains a habit, weak.

**Open 3. Nothing compares the phone to main.** Still open. The prediction
matched reality this time, but it was still a human reading a screen that
closed the loop.

---

## 2026-07-24, session 1: thirteen stamps that never left the building

### What we believed / What was true

Believed: the app on the founder's phone was at f2.25. Twelve pull requests
had been built, QA reviewed, merged, and reported to the founder as shipped.

True: the phone was at **f2.12, patch 21**, and had been for about 21 hours.
The app even said "You are on the newest build already", which was correct:
patch 21 genuinely was the newest patch ever published. Thirteen stamps of
work (f2.13 through f2.25) existed only in the repository.

The founder found this, not Claude. That is the most important sentence in
this entry.

### Timeline

| Run | Result | Pull request | Note |
|-----|--------|--------------|------|
| 200 | success | #171 | Last patch that actually reached the phone (f2.12, patch 21) |
| 201 | failure | #172 | Privacy receipt. First silent failure. `527 tests passed, 1 failed` |
| 202 to 212 | failure | #173 to #183 | Eleven more, same single cause every time |
| 212 | failure | #183 | `613 tests passed, 1 failed`. Founder checks phone, still f2.12 |
| 213 | success | #184 | Fix merged. Patch path taken (base APK step skipped) |

Every failure was the same one test, from the first (527 tests) to the last
(613 tests):

    ❌ flutter/test/fx_log_test.dart: a real refresh records its attempt
       an offline failure lands in the log as ok=false (failed)
       Expected: null
         Actual: <Instance of 'FxRates'>

### Divergence point

Pull request #172, the Privacy receipt, added `flutter/test/fx_log_test.dart`.
One test there called the real `FxService.refresh` (flutter/lib/data/fx_service.dart,
`_attempt`, which uses a `dart:io` HttpClient) and asserted it returned null,
on the assumption that the machine running the test had no internet.

That assumption holds in the development sandbox, whose proxy blocks the rates
endpoint, so the suite was green locally on every single run. A GitHub runner
has real internet, so the fetch genuinely succeeded and returned rates. The
test was wrong, the app was correct, and the build died before the publish
step. A build that fails publishes nothing at all.

### Why it survived twelve merges

1. Why did nobody notice? Because every visible signal was green: local
   `flutter test` passed, the pull request looked clean, and the "CI" check on
   the pull request was green.
2. Why was CI green on a broken Flutter build? Because `.github/workflows/ci.yml`
   is the React Native app (`npm ci`, `npm run lint`, `npm test`). It says
   nothing whatsoever about the Flutter app, but its green check appears on
   Flutter pull requests and reads as approval.
3. Why did no Flutter check run before the merge? Because the only job that
   ever ran `flutter test` on a real machine was the publisher, and the
   publisher triggers only on `main` and `claude/salapify-v2`, never on the
   working branch. So the first real test run happened after the merge.
4. Why was the post-merge result never checked? Because CLAUDE.md's merge
   rules waive the publish check when it is "blocked by billing or
   infrastructure rather than by the code", and that waiver had been invoked
   for the whole Flutter track on the grounds that the publisher never runs on
   the working branch. The waiver was written for a mechanism that is broken;
   it got applied to a mechanism that was working fine and reporting real
   failures. That turned the one true delivery signal into noise to be
   ignored.
5. Why did a wrong test get written in the first place? Because the sandbox's
   lack of network was treated as a property of "the test environment" rather
   than as an accident of one machine.

### Root cause

Nothing ran the Flutter tests on an internet-connected machine before a merge,
and the one signal that did (the publisher, after the merge) had been formally
declared ignorable. Delivery was therefore verified by inference rather than
by observation, and the only real detector left in the system was the founder
looking at the phone.

Note what is NOT the root cause: "Claude did not check carefully enough". That
framing produces the fix "check harder", which fails the moment anyone is
busy. The useful framing is that a missing check was missing.

### Lessons and guards

**Lesson 1. A green local test run is not evidence about delivery.**
The sandbox has no outbound network; the runner does. Any test that reaches
the network passes locally for the wrong reason.
Guard: `flutter/test/fx_log_test.dart` now forces the offline condition with
`HttpOverrides` and asserts the forced client was actually the one used, so
it can never quietly go back to depending on the machine.
Strength: **strong** (automated, fails loudly, and self-checking).

**Lesson 2. The Flutter tests must run on a real machine before the merge.**
Guard: `.github/workflows/flutter-check.yml` runs analyze and test on
`claude/**` branches. No Shorebird, no secrets, nothing published.
Strength: **strong** (automated). Already proven: it ran and passed on the fix
commit.

**Lesson 3. A green pull request does not mean delivered. A red publisher
ships nothing while everything upstream still looks clean.**
Guard: CLAUDE.md merge rules now require confirming, after every merge to
main, that the "Flutter preview APK" run went green and actually published.
Strength: **medium** (a rule, so it depends on being read at the right
moment). This is the weakest link in the current setup and should be upgraded
to something automated when a cheap option exists.

**Lesson 4. A waiver written for a broken mechanism must not be applied to a
working one.**
The infrastructure waiver silenced a check that was correctly reporting twelve
real failures.
Guard: the Flutter paragraph in CLAUDE.md now names the specific check for
Flutter work, so the waiver has nothing to attach to.
Strength: **medium** (a rule).

### Open lessons carried forward

These are real gaps that the fixes above do NOT close. Carry them into the
next session and check whether they are still open.

**Open 1. A Shorebird step failure is still silent.** The new branch check
runs analyze and test but deliberately does not run Shorebird (that would need
secrets and would publish). So a failure in the publish step itself, after the
tests pass, still results in nothing reaching the phone while every branch
signal is green. Covered today only by the medium strength rule in Lesson 3.
Candidate guard: a step in the publisher that runs `if: failure()` and files
or updates a GitHub issue saying plainly that nothing shipped. Needs founder
approval, since it writes to the repository.

**Open 2. A pubspec version bump strands the installed app.** Shorebird keeps
one release per pubspec version. Bumping the version makes the workflow build
a NEW base APK, which the founder must install by hand. Until they do, every
build is green and the phone receives nothing, which looks exactly like the
failure in this entry from the founder's side. Covered today only by the
CLAUDE.md instruction to flag version bumps loudly.
Strength of that coverage: **weak** (a habit).

**Open 3. Nothing compares the phone to main.** There is no automated
comparison between the stamp the founder has and the stamp on main. The
founder remains the detector of last resort. That is acceptable only while
they are the only user; it stops being acceptable at launch, when silent
non-delivery would hit real users with no one to notice.

### What it cost

About 21 hours between the first silent failure and discovery. Twelve pull
requests reported as shipped that were not. No user data was at risk and no
app code was wrong, but every "this is live now" statement made during that
window was false, and the founder had to be the one to catch it.
