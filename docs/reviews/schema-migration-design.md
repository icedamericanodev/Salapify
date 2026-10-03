# P2.2, schema version and migration on load: the design

2026-10-03. Written before any code, per the brainstorming gate. Two
specialist passes were run, a recovery lens and an architecture lens, and
every load-bearing claim in both was verified by reading the code.

## What this is, in one paragraph

Your data file carries `schemaVersion: 1`, and that is the only version there
has ever been. The app already refuses a file written by a NEWER build, which
is correct and working. There is no path at all for a file from an OLDER
build, because no older build exists. P2.2 builds the machinery to carry a
file forward from one shape to the next, so that the first time a shape really
has to change, it is not an emergency performed on live data.

## Why it is founder gated

A migration rewrites the only copy of somebody's ledger, on launch, before
they have touched anything. There is no server, no account and no support
channel. If it is wrong, nothing throws and nothing looks broken; every figure
is simply different.

---

## Two defects that exist TODAY

Both are harmless while only one version exists, and both become unfindable
bugs the day a second one ships. Neither changes the stored shape, so they can
land independently of everything else here.

**An absent version reads as current.** `snapshot.dart:415` is
`if (version is num && version > currentSchemaVersion)`. A file with no
`schemaVersion` at all passes with no objection, and `looksLikeSalapify`
(`snapshot.dart:614`) deliberately admits such a file on one collection key.
So the moment version 2 exists, an unversioned prototype backup is treated as
already current and is never migrated. **Absent must mean the oldest version,
never the current one.**

**A version that is not a number is waved through.** The same line tests
`version is num`, so `"schemaVersion": "2"` is a string, fails the test, and is
read as if it were current. It must be a refusal.

---

## The design

### 1. A migration is a chain of pure functions over the raw map

```dart
typedef SchemaStep = Map<String, dynamic> Function(Map<String, dynamic> doc);
```

Operating on the decoded map rather than on built models, and this is not a
close call. The codec is STRICT BY DESIGN: it throws on a field it cannot
read, because a file left untouched can still be recovered. A model-based
migration would have to decode a v1 file with a v2 reader in order to fix it,
which is exactly the thing that throws. It would force a frozen copy of every
version's model tree and codec to be kept forever. **The codec can only ever
be the last step.**

The cost, stated rather than discovered later: the map is stringly typed, a
typo in a key name is silent, and nothing type checks it. That is paid for by
the fixture discipline below, not by cleverness.

Two rules on a step:

- **Total.** It never throws and never refuses. A throw during load is the
  whole ledger unreadable over one bad record. Refusal stays in the codec,
  which already writes sentences for humans.
- Where it cannot convert a record, it leaves it in a state the codec will
  **refuse**, never one the codec will **misread**.

### 2. The list is the version

```dart
// Index 0 is version 1 to 2. Position IS the version.
const List<SchemaStep> schemaSteps = <SchemaStep>[];
```

and `currentSchemaVersion` is derived as `1 + schemaSteps.length` rather than
written down separately. A second number is a second thing that can be wrong,
and a `from`/`to` pair on each step is exactly that. Deriving it makes a
disagreement impossible rather than unlikely.

Lives in a new `lib/data/migrations.dart`. Not inside `snapshot.dart`, which
is already 620 lines and whose job is the CURRENT shape; migrations only ever
grow.

### 3. Migration runs FIRST, before extras are extracted

Three arguments, all pointing the same way, and the second one is the one that
would have bitten us.

**It has to, or a rename produces both keys forever.** If extras were
extracted first, every key a migration deletes has already been captured as a
stranger's key, and `toJson` writes it straight back (`snapshot.dart:229`,
`:234`). Migration first makes a leftover key the migration's own bug, which a
test can catch.

**Extras are keyed by record id** (`snapshot.dart:447`). Any migration that
changes a record's id, moves a record between collections, or splits one
record in two would ORPHAN that record's extras: stashed under the old key,
looked up under the new, and silently dropped on the next save. That is
permanent loss of precisely the data the sidecar exists to protect. Running
the migration first makes it a non problem for free, because the unknown keys
are still physically on the record's map and travel with it.

This bites `Budget` hardest, because a budget has no id: its identity IS its
category, which the code says in its own comment at `snapshot.dart:252`. So
any category normalisation is an id change in disguise.

**A naming rule that cannot be a code rule.** The chain can never see a newer
VERSION, because the version check refuses it first. It can see a same-version
file carrying newer-build additive keys, which is the whole point of the
sidecar. So: **a migration never writes a key name that could already exist at
its source version.** Never recycle a name. Defensively, if the target key is
already present, leave it alone; the build that wrote it knew more than the
migration does.

### 4. Both doors share one chain

A file arrives two ways: the app's own storage on launch, and a backup
restored from Settings, which can be months old. Both already funnel through
`Snapshot.fromJson`, so putting the chain at the front of that function means
both inherit it. A separate `migrate()` called from two places is a rule
somebody has to remember.

Three things must differ on the restore door, and all three are real:

- **No second copy.** `importSnapshot` already takes a pre-import copy of the
  outgoing ledger. A migration copy there would copy a file that is already
  copied.
- **The preview is computed AFTER migration.** The import sheet shows counts
  and figures before you confirm. Computed from the unmigrated map, it would
  promise a restore the app does not deliver.
- **The missing-collections warning too.** It is built from the raw map, so
  the first migration that renames a collection key would warn about data the
  file actually has.

### 5. The copy: a fourth file, kept forever

A migration is structurally the same act as a destructive import, and the
store already protects that with a durable pre-import copy. A migration needs
its own.

**Not `.prev`.** Every `notifyListeners` is a write, so the one-generation
backup survives a single tap. The code already argues this at
`store.dart:33`.

**Not the pre-import copy either**, and this is the one that looks free and is
not. `writePreImport` replaces any earlier copy, and `previousLedger()` reads
that file with no flag. A migration writing there silently destroys the way
back from a restore somebody did yesterday, AND the Settings row offering to
put that ledger back then describes something else entirely. A control whose
label stops being true, with nothing on screen saying so.

So: a fourth file, written once immediately before the first write of a
migrated ledger, **kept forever**, replaced only by the next migration that
actually runs. It cannot expire, because a wrong-but-silent migration is found
when somebody reconciles at month end, not inside a session, and a timer that
deletes the only copy before they had reason to look is a clock deciding when
they were allowed to notice.

Two things ship with it or it is a liability: it goes into the wipe's delete
list **before** the live file, because a wipe leaving a complete plaintext
ledger behind breaks the promise the privacy policy rests on; and it is
exportable.

### 6. If a migration throws halfway

**Nothing is written.** Not the partial result, not a best effort, not a
repaired one. The migrated document may be written only after the whole chain
returns AND the result re-decodes successfully in memory.

The shape enforces this rather than relying on memory: a step is a pure map to
map function with no store reference in scope, so it physically cannot write.
Half written is not expressible.

Order at the boundary: migrate in memory, re-decode, copy the ORIGINAL bytes,
then write. If the copy fails, **refuse**: run the session read-only with
saving off. A read-only hour is a bad hour. A migrated file with no copy of
what it replaced is permanent.

**A trap the current code sets.** A migration failure must NOT route through
the existing fall-back-to-previous path. `.prev` is the same version, so it
fails the same migration and the fallback merely costs a read. The dangerous
case is the other one: if `.prev` happens to hold a differently shaped
document that DOES migrate, the load reports `recovered`, saving turns back
ON, and the app silently adopts an older ledger as the good one. A migration
failure needs its own outcome that skips the previous generation entirely.

The message must also not reuse the existing "could not make sense of its data
file" wording, which is false here and frightening:

> **We stopped before changing anything**
> Salapify could not finish upgrading the way it stores your records, so it
> has not changed them. Your file is exactly as it was, and nothing has been
> written over it. Send yourself a copy now, then try updating the app again.

### 7. If a migration succeeds and is WRONG

The honest answer is that almost nothing can be offered afterwards, and the
defence is upstream. Saying so plainly rather than inventing a remedy:

The one real remedy is the pre-migration copy, exported, and it is only a
remedy because it never expires.

Upstream means four things:

1. **A migration may not change money. Ever.** A shape change that moves a
   figure is a money change and stops for the founder.
2. **A run-time self check on the real device**, not only in CI. Compare the
   document before and after the chain, in memory: row count per collection,
   assets, liabilities, owed, owed to you. `summarizeSnapshot` already
   computes all of these. Any difference means a shape-only migration is wrong
   by definition. On a difference, refuse the write. **This is the one thing
   that turns "silently wrong" into "visibly stopped" on a ledger CI has never
   seen, which is every real ledger.**
3. Golden fixtures per version.
4. A migration that renames a key must declare the OLD key in that codec's
   known-key set, or the old key survives in extras and the file carries both
   shapes forever.

### 8. Silent, with a permanent way back

**Silent at the moment it happens. Visible and permanent afterwards. No
choice.**

A launch-time "upgrade your data?" dialog offers a decision a beginner has no
basis for, and the two answers are "yes" and "stop using the app", because the
build cannot read the old shape correctly, which is why the migration exists.
A choice where one branch is not functional is a fake choice, and somebody who
taps "not now" believes they protected something.

But telling somebody without helping them is noise. So the fix is not a
sentence, it is a route, with a sentence pointing at it. A permanent Settings
row, the same pattern as the existing undo-restore row:

> **Your records were upgraded on 3 October 2026**
> Salapify changed the way it stores your records. Nothing was added, removed
> or recalculated. The copy from before the change is still on this phone.
> [ Send me the copy from before the upgrade ]

**The row offers EXPORT only, never "put it back".** A restore there would
write an old-version file into the live slot and the next launch would migrate
it again, so the control either does nothing or loops. A button that appears
to undo and does not is the worst shape in this category, on the one screen
somebody opens when they are already worried.

### 9. Testing, and the one rule that matters most

Seven assertions per step, six applied generically so a new migration
inherits them: a committed fixture pair compared byte for byte; money totals
asserted as hand-written literals; idempotence, because a rescale applied
twice is the worst class there is; the source key is GONE; extras survive a
round trip; and totality, by deleting each key in turn and asserting no throw.

The input fixture is **captured**, the exact bytes the old version really
wrote, never hand-written, because hand-writing it means committing the file
you BELIEVE the old version wrote, which is the same wrong mental model that
wrote the migration.

The expected output is hand-written and reviewed, and **there is no
regenerate-the-goldens path for it, ever.** The instant a fixture can be
regenerated by running the code, it asserts that the code does what the code
does, and the first wrong migration bakes itself in and is then defended by a
green test.

---

## What this costs, and the recommendation that surprised me

The machinery alone, with no migration in it, is roughly five to seven hours.

**Do not build it empty.** An empty framework is untestable in the only way
that matters: the generic assertions have nothing to run against, the
every-step-has-a-fixture guard iterates an empty list and passes vacuously,
and the break-it-and-watch-it-fail rule cannot be satisfied at all. It would
ship a green suite that proves nothing, which is the exact failure this
project has written down three separate times.

Build the machinery WITH its first real migration, in one batch.

**The first real migration is smaller than it looked.** Three of the five
links from a ledger entry back to what created it are ALREADY stored, as of
this morning: debt payments, plan payments and reconciliation adjustments. Only
two are still guesses, bills and splits. So the first migration is narrow and
targeted rather than sweeping.

---

## Decisions that are yours

**1. Does a migration run at all, on the only copy of somebody's ledger?**
This is the whole of P2.2. Everything above is how to do it safely; this is
whether to do it.

**2. A fourth file, kept forever.** It means a second complete plaintext
ledger lives on the phone permanently. That is the price of the only real
remedy for a wrong migration, and it touches the privacy policy and the Play
data-deletion answers. It is covered by the wipe, but it is still a second
copy.

**3. Silent, with a permanent Settings row.** A product call about whether
somebody is told their records changed, and in what form.

**4. The first migration itself**, storing the link from a bill or split entry
back to what created it. That is a stored-data change and comes to you
separately before a line of it is written.

## What I would land now regardless

The two fence holes in the current code, about an hour, no stored-shape
change, each with a test that fails before it passes:

- A non-numeric `schemaVersion` is refused rather than waved through.
- An absent `schemaVersion` means version 1, decided and written down.

Both are one-line reads today and unfindable bugs the day version 2 ships.
They need no approval beyond yours to spend the hour.
