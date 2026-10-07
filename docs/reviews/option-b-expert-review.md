# The Option B review, and the framing error it was built on

2026-10-05. Three independent reviews of the publisher and cutover design.

## WITHDRAWN IN PART, SAME DAY

The CUTOVER half of this review is withdrawn. The founder stopped it: "we are
building the Salapify from scratch right using the google ai studio prototype
why you mix it up to Salapify 2". There is no cutover. Salapify 3 is a NEW
APP, it inherits nothing, and no data has to move for it to be finished.

The error was inherited, not invented. `docs/revamp/05-roadmap.md` Phase 4 was
titled "Cutover" and promised "data found in place". It was adopted
2026-09-11, a week before D24 made app/ a rebuild from the prototype, and was
never updated. That roadmap line is now rewritten, which is the real fix.

SO THE HEADLINE BELOW, "Salapify 3 cannot read a Salapify 2 backup", IS NOT A
DEFECT. It is correct and expected behaviour for an app that was rebuilt from
scratch. It is kept below because the investigation was real and because the
refusal MESSAGE was a genuine problem worth fixing on its own terms.

WHAT SURVIVES UNCHANGED: the signing key finding, which has nothing to do with
Salapify 2 and is the most urgent item in the whole review; and the four fixes
that were built, every one of which stands on its own.

---


## THE HEADLINE, and it invalidates the plan I wrote

**Salapify 3 cannot read a Salapify 2 backup.** Option B's whole premise is
that data moves by export and import, and my design said "Both halves of that
already exist and are already tested". That sentence is false. Two reviewers
found it independently, and I then verified it three ways rather than taking
either of them at their word.

**1. The file is refused at the door.** Salapify 2 writes an ENVELOPE
(`archive/salapify-2-flutter/lib/data/backup.dart:818`) and puts the ledger
one level down:

    {"app": "salapify", "version": 2, "exportedAt": ..., "data": {...}}

Salapify 3's gate, `looksLikeSalapify` in `app/lib/data/snapshot.dart:744`,
accepts a top level `schemaVersion` or a top level collection LIST. The
envelope has neither. Run against Salapify 2's own committed export golden,
the top level keys are exactly `app, data, exportedAt, version`, no
`schemaVersion`, and no value at that level is a list. The gate returns false.

**2. Unwrapped, every account still throws.** `accountFromJson`
(`app/lib/data/json_codec.dart:374`) demands `institution` and `monogram`
through `_reqStr`, which throws on anything that is not a String. A real
Salapify 2 account carries `balance, brand, icon, id, kind, name, target`.
Neither field exists, on any account, ever.

**3. The vocabularies barely overlap.** Salapify 3 knows cash, bank, gcash,
maya, debit, credit, loan, mortgage, investment, receivable, property.
Salapify 2 knows cash, savings, checking, ewallet. Only `cash` is shared, and
`decodeRequired` refuses the rest by design.

The shapes do not correspond either: Salapify 2 keeps `people`,
`receivables`, `payables`, `categories`, `wins`, `notes`, `recurring` and
`payments` as separate collections, and Salapify 3 has none of them, because
it deliberately holds both directions of debt in one list.

**This is founder-gated** under STOP conditions 1 and 2, money meaning and
stored data. The two honest answers are a tested one-way converter built
against the founder's REAL export, or Salapify 3 starting empty with
Salapify 2 kept installed as read-only history. Neither is a decision to take
inside a session, and a converter written in a hurry against the only copy of
somebody's financial history is precisely the thing to refuse to do.

## THE SECOND FINDING, which all three reviewers named first

**`app/android/app/build.gradle.kts:42` signs release builds with the DEBUG
key**, with a `TODO` beside it. There is no keystore anywhere under
`app/android`. Salapify 2 has one, committed, at
`archive/salapify-2-flutter/android/app/preview-keystore.jks`, and CLAUDE.md
says why in as many words: "The committed preview keystore signs every build
so updates install in place."

Why it bites, and why it is worse than it looks: the Android debug keystore is
generated per machine. A CI runner is a fresh machine, so two base APKs built
on two runs carry two different signatures. Android then refuses the second
install in place, and the only route Android offers is uninstall, which
deletes the app's whole data directory.

So the failure is scheduled rather than immediate. Publisher ships, founder
installs, uses Salapify 3 for a week, a native change forces a new base APK,
and the only way to accept it is to wipe the week. **The first install looks
perfect, which is exactly when everyone concludes the pipeline works.**

Not built in this batch: generating and committing a keystore is a credential
entering the repository, and although CLAUDE.md blesses that exact pattern for
a preview key, it is a security surface and it is reported rather than done.

## WHAT DID NOT SURVIVE VERIFICATION

Recorded because the standing rule is that a finding is a lead, not a fact.

**"Land PR #473 first", recommended as build step 1.** Correct as engineering
and refused on standing founder direction: #473 stays open and untouched. It
is also now moot as a blocker: the five file-location conflicts it named were
resolved earlier today in `4ac5989`, and the PR moved from `dirty` to
`unstable`. The reviewer's diagnosis of the conflict was exactly right and
matched my own independent measurement, five file-location conflicts and zero
content conflicts.

**"The pin must come down for Shorebird."** One reviewer asserted the pin can
stay at 3.47.4 on search evidence; another flagged the same question
UNVERIFIED. `app-check.yml:65` instructs that it must come down. Nobody can
settle it here: `shorebird` is not installed and `docs.shorebird.dev` is
egress-blocked. **Left unbuilt rather than guessed**, because getting it wrong
fails at the first `shorebird release`.

**The `s` stamp prefix I proposed.** One reviewer pointed out `docs/qa-log.md`
already keys Salapify 3 rows as `app-c72` through `app-c76`, so there are two
competing id schemes before the first one exists. Verified and real. Deferred
with the rest of the publisher rather than settled half way.

## WHAT WAS BUILT

Four items, all verified first, none founder-gated, every one removing a
specific way to lose data. Analyzer clean, 2,080 tests pass, up from 2,073 by
exactly the seven added here.

**1. A Salapify 2 backup is now named instead of called a stranger.**
`app/lib/data/import.dart` recognises the envelope BEFORE the gate and says:

> This is a backup from an earlier version of Salapify, not from this app.
> Salapify keeps your records in a different shape now, so this file cannot be
> read here yet. Nothing on this phone has changed. Keep this file safe. It
> may be the only copy of those records.

Nothing was ever written on this path, so no tap could lose data. THE DANGER
WAS THE SENTENCE. The old refusal said the file "is not a Salapify backup" to
somebody holding the only export of their entire financial history, and two of
the three reasonable reactions to that end with the file deleted.

The test reads Salapify 2's REAL export, committed byte for byte as
`app/test/data/salapify2_export_envelope.json` from the `rnText` field of
`archive/salapify-2-flutter/test/goldens/backup_export_goldens.json`. This
matters: `snapshot_test.dart:738` already tested the "older Salapify" refusal
with a hand built object shaped like the data INSIDE the envelope, a shape
nothing has ever written to a file, so the guard it proved could never fire on
anything real. A hand built fixture is what let this through.

Proved able to fail. With the branch disabled:

    Expected: contains 'earlier version of Salapify'
      Actual: 'That file is valid, but it is not a Salapify backup. It has
               none of the parts one has: accounts, entries, debts, budgets,
               goals, reminders, income, payment plans, reconciliation checks
               or bills.'

Worth noting what did NOT fail: "it is refused rather than half read" passed
with the guard disabled, because the old gate also refused. That is the point
made precisely. The refusal was never the defect; the sentence was.

**2. The wipe sheet now offers the export it had been promising.** Property 4
of `wipe_sheet.dart`'s own class comment said "It offers the export first,
right there". It did not. The only two matches for "export" in the file were
that comment and one line of prose. The row is now there, above the red
button, and it disappears once the last check begins, because a third control
between two confirm buttons is a place for a thumb to land by accident.

The share logic moved to `app/lib/features/settings/export_backup.dart` rather
than being copied, so the two callers cannot drift apart.

**3. Exported filenames carry the time and say which app.**
`salapify-backup-2026-10-05.json` became
`salapify3-backup-2026-10-05-1430.json`. Two exports on one day used to
collide silently, and somebody exporting twice in a day is usually about to
try something they are unsure of. The `3` matters during the changeover, when
both apps are exporting into one folder and only one of the two files can be
regenerated at will.

**4. The undo row stops describing demo money as the person's records.** A
fresh install seeds 63 sample records, so somebody who installs and
immediately restores leaves a pre-import copy that is entirely invented money,
and that copy never expires. The permanent Settings row offered to put it back
described in pesos. `LedgerSummary.hasSampleData` was already computed and
already read correctly in the forward direction at `import_sheet.dart:198`;
the reverse direction never read it. Both the row and the confirmation now
say "None of it is yours."

## STILL OPEN, and the first is the only one that blocks

1. **Does the data move?** Converter, or fresh start with Salapify 2 kept.
   Founder-gated. Nothing below is worth building until this is answered,
   because it decides whether there is a cutover at all.
2. **The signing key.** Must be done before the FIRST base APK, never
   retrofitted, because retrofitting it is itself an uninstall.
3. **The home screen widget does not exist in `app/`.** Verified: no
   `home_widget` dependency, no `AppWidgetProvider`, nothing. Cutover step 5
   says "re-point the widget", and there is nothing to point. It is a feature
   to build or a loss to state plainly, not a configuration step.
4. **Cutover step 6, uninstalling Salapify 2, is the real point of no return**,
   and my design called step 7 the irreversible one. Step 7 deletes files that
   are in git and recoverable from any clone. Step 6 removes the last running
   copy of the founder's history.
5. **The pin, the stamp scheme, and the publisher itself.** Deferred as a set.
