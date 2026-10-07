# Archive

Finished apps, kept whole and kept out of the way.

Nothing in this folder is built, tested, published or checked by CI. Nothing
here can turn a pull request red. It is here so the work is not lost and so a
file can be pulled back when one is genuinely needed, which is exactly what the
founder asked for on 2026-09-18.

Three generations live here now, in the order they were built:

| Folder | What it is | Status |
|---|---|---|
| `prototype-google-ai-studio/` | The React and TypeScript prototype from Google AI Studio, which every Salapify 3 money engine was ported FROM | Archived 2026-10-05 |
| `salapify-1-react-native/` | The original React Native and Expo app, the first thing the founder used daily | Archived 2026-10-05 |
| `salapify-2-flutter/` | Salapify 2, the Flutter app that was on the founder's phone | Archived 2026-09-18 |

The live app is `app/`, Salapify 3. It is the ONLY thing at the repository root
that is built, tested or published.

## Why the root was cleared, 2026-10-05

Founder direction: "since my instruction we build from the scratch i want to
remove confusion in the repository retain only our current salapify current
build", then, a moment later, "instead of delete archive to one folder".

The second half is the important one and it matches decision D5. NOTHING WAS
DELETED. Every file that was at the root is still in the tree, at a new
address, and `git log --follow` reaches its whole history. The repository root
went from nine folders and nineteen loose files to five folders and six files,
and the five that remain are the live app, the documentation, the two helper
scripts, and the public landing page.

What moved, and from where:

- `mobile/` became `salapify-1-react-native/`.
- `src/`, `public/` and `google-ai-studio/` became
  `prototype-google-ai-studio/src/`, `/public` and `/notes`.
- The prototype's build tooling came with it: `package.json`, `bun.lock`,
  `vite.config.ts`, `tsconfig.json`, `server.ts`, `metadata.json` and the six
  one-off `patch_*` and `fix_*` scripts.
- `index.html` came with it too, because it was never a landing page: it is the
  prototype's Vite shell, a `<div id="root">` and a module script pointing at
  `src/main.tsx`. A real landing page was written to replace it at the root,
  because `pages.yml` copies that file with no `|| true` and a missing one
  fails the whole deploy.

WHAT STAYED AT THE ROOT AND WHY. `privacy.html` is load bearing: Google Play
requires that URL to keep resolving, and `pages.yml` says so in its own
comment. `404.html` and `robots.txt` serve the same site. `tools/dev-sync.sh`
is how the founder's emulator gets a new build. `scripts/self-check.sh` and the
two markdown files govern the work.

FOUR WORKFLOWS WERE REPOINTED, not disabled, so the Pages site keeps building
from the archived sources exactly as it did: `pages.yml`, `eas-update.yml` and
`build-apk.yml` now name the new paths, and all four still parse. `app-check.yml`
never referenced any of this.

SIXTY SIX FILES IN `app/` CITED THE OLD ADDRESSES in their provenance comments
("ported from `src/components/X.tsx`"). Every one was rewritten to the new
address rather than left dangling, and `test/docs/claude_md_paths_test.dart`
caught the two that had reached CLAUDE.md itself. That guard is the reason this
move is verifiable rather than hopeful: it fails the build when a document
points at a file that is not there.

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
