# Archive

Finished apps, kept whole and kept out of the way.

Nothing in this folder is built, tested, published or checked by CI. Nothing
here can turn a pull request red. It is here so the work is not lost and so a
file can be pulled back when one is genuinely needed, which is exactly what the
founder asked for on 2026-09-18.

| Folder | What it is | Status |
|---|---|---|
| `salapify-2-flutter/` | Salapify 2, the Flutter app that was on the founder's phone | Archived 2026-09-18 |

The live app is `app/`, Salapify 3, rebuilt from the Google AI Studio prototype
in `src/` under decision D24. `mobile/`, the original React Native app, is still
at the repository root and is frozen but not archived; its only workflow
(`eas-update.yml`) triggers on a retired branch, so it publishes nothing.

## salapify-2-flutter

It used to be `flutter/`. The rename is the point: two folders that both held a
Flutter app called Salapify, one live and one frozen, is a trap, and the name
now says which is which without anybody having to remember.

### What was switched off, and what that costs

Four workflows and four scripts moved into `ci-disabled/`. GitHub only runs
workflows from `.github/workflows`, so moving them is what actually stops them,
and keeping them means they can be moved back rather than rewritten.

| Moved out of CI | What it did |
|---|---|
| `flutter-check.yml` | Analyze and test on every branch. This is the check that was red on every pull request. |
| `flutter-preview.yml` | **The publisher.** Shipped a Shorebird patch to the founder's phone on every merge to main that touched `flutter/`. |
| `flutter-prod-aab.yml` | Built the Play Store AAB. |
| `delivery-watchdog.yml` | Alarmed when a stamp went undelivered. |
| `scripts/check-stamp-unique.sh` | Refused a merge whose stamp matched an already delivered one. |
| `scripts/check-engine-identical.sh` | Byte-for-byte money engine comparison. Already retired under D24. |
| `scripts/check-merged-manifest.sh`, `scripts/verify-prod-aab.sh` | Release verification. |

**The cost, stated plainly: the phone running Salapify 2 will not receive
another update.** No patch can reach it while `flutter-preview.yml` sits in this
folder, because its trigger is the path `flutter/**` and nothing is at that path
any more. That is the intended effect of archiving a finished app, not an
oversight, and it is reversible in minutes (see below). The app already on the
phone keeps working exactly as it is; it simply stops changing.

The last stamp actually delivered is `f4.72`. The tree here says `f4.73`, which
was bumped when this archive was still a live app and will now never ship. Do
not read that constant as something the founder is running.

### The guards are here too, deliberately

Founder direction, 2026-09-18: the guards that came back with the restoration
must not gate the current build. They are Salapify 2's rules, written for an app
with a publisher and a phone at the end of it, and Salapify 3 has neither yet.

They live in `salapify-2-flutter/test/` and cannot run, because the workflow
that ran them is in `ci-disabled/`. Named so nobody goes looking:

- `qa_record_test.dart`, which required a `docs/qa-log.md` row per stamp
- `update_stamp_test.dart`, the 120 character cap on the phone's stamp row
- `toolchain_pin_test.dart`, which required every workflow to agree on a
  Flutter version
- `constitution_citation_test.dart`

When `app/` earns a publisher and a phone at the end of it, these are the right
guards to copy forward and the wrong ones to inherit by accident. Copy them
deliberately then, rewritten for `app/`.

### Pulling a file back

Everything is ordinary tracked content, so nothing special is needed:

    cp archive/salapify-2-flutter/lib/<file> app/lib/<somewhere>

The money engines are the likeliest thing to want, and there is a caveat worth
knowing before copying one. Under D24 `app/` is rebuilt from the prototype in
`src/`, which is the source of truth for every calculation, so an engine here
is not automatically the right answer for `app/`. It is a second opinion, and a
useful one, but the vectors in `app/test/core/money/` come from running the
prototype's own TypeScript and those win.

### Un-archiving it

If Salapify 2 ever needs a real fix on the phone:

1. `git mv archive/salapify-2-flutter flutter`
2. Move the four workflows in `ci-disabled/workflows/` back to
   `.github/workflows/`, and the four scripts back to `.github/scripts/`.
3. Restore `.githooks/pre-push` from this commit's parent, because the stamp
   collision guard and the publisher belong together. Three real collisions
   were caught by that pair (`docs/lunch-and-learn.md`, sessions 32 and 33).
4. Point `pages.yml`'s `working-directory` back at `flutter`.
5. Re-read the delivery rules in `CLAUDE.md` before merging anything, because
   from that moment a merge to main ships to a real phone again.
