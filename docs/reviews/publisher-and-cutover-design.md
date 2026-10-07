# The publisher, and getting Salapify 3 onto the phone

Design, 2026-10-05.

## WITHDRAWN IN PART, SAME DAY. Read this before anything below it.

**Part 3, THE CUTOVER, is withdrawn in full. Part 1's fork was a false
choice.** The founder stopped it on sight: "we are building the Salapify from
scratch right using the google ai studio prototype why you mix it up to
Salapify 2". They were right, and the error is traceable rather than random.

`docs/revamp/05-roadmap.md` Phase 4 was titled "Cutover" and said "Base APK
installed by the founder over the old app; data found in place". That document
was adopted 2026-09-11. D24, which made `app/` a rebuild from the AI Studio
prototype, is 2026-09-18, and Salapify 2 was archived the same day. Phase 4 was
never rewritten to match, and this design read it as current.

THERE IS NO CUTOVER. Salapify 3 is a NEW APP. It does not replace Salapify 2,
it does not inherit from it, and no data has to move for it to be finished.
Salapify 2 is archived history, not a predecessor waiting to be migrated. The
roadmap's Phase 4 has been rewritten accordingly.

What that makes of part 1: the "fork" between taking over the old app and
shipping beside it was never a real decision, because taking over a rebuilt
app's predecessor was never the plan after D24. The applicationId stays
`dev.icedamericano.salapify3` because that is what a new app has, not because
it won a trade-off. D29 is amended to say so.

WHAT SURVIVES, and is still worth building: PART 2, THE PUBLISHER. Salapify 3
needs a way to reach a phone whatever else is true, and every mechanism in
part 2 was audited line by line and stands on its own. The signing key finding
is the urgent one and has nothing to do with Salapify 2: `app/` signs release
builds with the debug key today, which is generated per machine, so a second
base APK cannot install over the first.

Part 3 below is kept unedited as the record of what was designed and
withdrawn. Do not execute any of it.

---

## 1. THE FINDING THAT CHANGES THE PLAN

The roadmap's Phase 2, item 1, says:

> New Flutter project, same applicationId, version 1.0.0+21 (one above the
> current versionCode so it installs over the old app).

Neither half happened. Measured from the files:

| | applicationId | version |
|---|---|---|
| Salapify 1, `mobile/` | `com.icedamericanodev.salapify` | React Native |
| Salapify 2, `archive/` | `dev.icedamericano.salapify` | 0.9.5+20 |
| **Salapify 3, `app/`** | **`dev.icedamericano.salapify3`** | **1.0.0+1** |

Android isolates stored data BY applicationId. There is no way around that and
no permission that grants it. So with the ids as they stand today:

- Salapify 3 installs ALONGSIDE Salapify 2, not over it.
- Salapify 3 cannot read a single byte of Salapify 2's data.
- "Data found in place", the roadmap's Phase 4 exit, is not achievable.

This is not damage. It may well be the better answer. But it is not what the
plan says, and the plan's cutover step was written assuming the opposite, so
it cannot be followed as written.

### The fork, and it is the founder's

**Option A. Take over the old app.** Change `app/` to
`dev.icedamericano.salapify` and set the version to `1.0.0+21`, one above
Salapify 2's `+20`.

- The founder installs one APK. It replaces Salapify 2 in place.
- Salapify 3 then finds Salapify 2's stored data in its own sandbox. Whether
  it can READ it is a separate question, answered below, and the honest
  answer today is that nobody has tried.
- The old app is gone the moment the new one lands. There is no going back
  without a reinstall from a file.
- Matches the roadmap.

**Option B. Ship beside it.** Keep `dev.icedamericano.salapify3`.

- Both apps sit on the phone at once, with different icons.
- Data moves by EXPORT from Salapify 2 and IMPORT into Salapify 3. Both
  halves of that already exist and are already tested (`settings_sheet.dart`
  exports, `import.dart` reads, `import_refusal_test.dart` guards the
  refusals).
- Salapify 2 stays untouched and usable for as long as the founder wants it,
  which makes the whole cutover reversible by closing one app and opening the
  other.
- The home screen widget has to be re-pointed deliberately rather than
  inheriting.
- Does not match the roadmap.

**The recommendation is B,** and the reason is narrow rather than general:
Option A's safety rests on Salapify 3 being able to read Salapify 2's stored
file in place, and NOTHING HAS EVER TESTED THAT. Salapify 3 stores under the
key `salapify_data_v2` through its own `store.dart`; whether that is
byte-compatible with what Salapify 2 left behind is unverified, and the day to
discover it is not the day the old app is replaced. Option B reaches the same
destination with a file the founder can see, keep, and re-import.

Option A is still available later. Going from B to A is a reinstall; going
from A back to B after a bad migration is a restore from a backup that may not
exist.

**Nothing below is built until this is answered.**

## 2. THE PUBLISHER

`app/` has no publisher, no stamp, no Shorebird app id, and no delivery row.
`app-check.yml` analyzes and tests on every `claude/**` branch and on `main`,
and says in its own comments that it deliberately publishes nothing.

Salapify 2's publisher is in `archive/salapify-2-flutter/ci-disabled/`. It
must be COPIED FORWARD DELIBERATELY AND REWRITTEN, never inherited: CLAUDE.md
says so in as many words, and the four guards that came with it
(`qa_record_test`, `update_stamp_test`, `toolchain_pin_test`,
`constitution_citation_test`) were written for an app that had a publisher at
the end of it. `app/` is about to become one.

### What has to exist before the first publish

1. **A stamp.** `app/` has no `updateStamp`. One constant, one short line, and
   a test capping its length, because on Salapify 2 it became a forty line
   wall on the founder's phone when each build appended the last one's notes.
   Prefix `s` rather than `f`, so a stamp can never be mistaken for a
   Salapify 2 one in the delivery log.

2. **The uniqueness guard.** `check-stamp-unique.sh` reddens a PR whose stamp
   still equals the delivered one. It caught three real collisions on
   Salapify 2 and every pre-authored commit that forgot to bump. Copy it,
   point it at `app/`, and enable `.githooks/pre-push` so it fires one push
   earlier than CI.

3. **The delivery log.** One row per publish, written BY THE PUBLISHER, never
   by hand. It is the only thing that makes "merged" and "delivered"
   distinguishable, and the whole reason the rule "never say a version number
   until its row exists" is in CLAUDE.md.

4. **A QA row.** `qa_record_test` fails the runner when the current stamp has
   no row in `docs/qa-log.md`. That rule sat unenforced for weeks on
   Salapify 2 and was then simply skipped, which put a broken monthly cap on
   the founder's phone for two hours.

5. **The toolchain pin, in one place.** Salapify 2 repeated its Flutter
   version in five files including twice inside one Shorebird argument. The
   pin for `app/` is 3.47.4 (`app-check.yml`). The publisher must read the
   same value, and `toolchain_pin_test` is what stops the copies drifting.

6. **A Shorebird app id**, which does not exist yet and is created once,
   against whichever applicationId part 1 settles on. It is public and lives
   in `shorebird.yaml`; the token is a repo secret.

### The shape

Trigger on pushes to `main` that touch `app/`. Analyze, test, then publish.
Two things from Salapify 2 that are not optional and cost nothing to carry:

- **No path filter on the CHECK, only on the publisher.** A workflow skipped
  by a paths filter reports as "no check", and no check reads as green on a
  PR. `app-check.yml` already gets this right.
- **Never cancel a run in flight.** A cancelled first release can exist
  server-side with no base APK ever published, and every later green run then
  patches a release nobody can install.

### Release against patch, which is the part that bites

One RELEASE per `pubspec` version: a base APK the founder installs by hand,
once. Every later push PATCHES it over the air and the app updates itself on
reopen.

Bumping the `pubspec` version forces a NEW base APK and another manual
install. That must be flagged loudly and never buried, because a release the
founder does not install means they receive nothing forever while every build
stays green. Shorebird patches on build BYTES, so a functionally identical
build is still a new patch under a new number, and a docs-only or test-only
merge that touches `app/` still ships.

## 3. THE CUTOVER

Written for Option B. Option A collapses steps 3 and 4 into one install and
adds a step nobody has rehearsed.

1. **Publisher lands and proves itself** on a stamp the founder confirms on
   the phone, with Salapify 2 still installed and untouched. Nothing about
   their data moves. This is the step that de-risks every later one.
2. **Export from Salapify 2.** The founder shares the backup file to
   themselves. It is theirs, it is readable, and it is the fallback for
   everything after this.
3. **Import into Salapify 3**, with the pre-import summary `import.dart`
   already computes: what is in the file, what it will replace, and the
   refusals it will not perform. Nothing is written until they confirm.
4. **A week of real use**, which is the Phase 3 exit the plan asks for and the
   only thing that finds what the screens missed. Salapify 2 stays installed
   and is not opened.
5. **Re-point the home screen widget** at Salapify 3's data.
6. **Uninstall Salapify 2**, founder's call, not before the week is done.
7. **Delete `archive/` and `mobile/` from the working tree**, which is a
   founder decision under D5 and is the only genuinely irreversible step here.

### What stops for the founder, beyond the fork in part 1

- Step 3, before it runs. Import REPLACES the whole ledger; there is no merge,
  and `import.dart` says why in its own header.
- Step 7, which deletes files that exist on `main`.
- Any `pubspec` version bump, every time, because it costs a manual install.

## 4. WHAT I AM NOT DESIGNING HERE

- **App lock.** It is the one Phase 3 item that does not exist, and it is a
  security surface, so it is its own design and its own founder gate.
- **Play Store submission.** Phase 4 is a side-loaded preview. The store is a
  separate track with its own reviewers (`play-launch-auditor`,
  `play-store-reviewer`) and its own checklist.
- **Whether Salapify 3 can read Salapify 2's stored file in place.** That is
  the load-bearing unknown under Option A. If the founder wants A, it is a
  spike before a decision, not a thing to find out during a cutover.
