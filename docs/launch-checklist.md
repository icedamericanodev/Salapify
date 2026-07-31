# Launch checklist: what must be decided or done at submission

Not a duplicate of the play-launch-auditor agent, which covers the mechanical
bars (signing, target SDK, versionCode, Data safety, staged rollout). This file
holds the things that are DECISIONS rather than checks, and that were
deliberately deferred rather than forgotten.

A decision cannot have a test written for it. What it can have is a home that
somebody is guaranteed to open at the right moment, which is why each entry says
where it is enforced or where the reader will already be standing.

## Open decisions

### 1. Does the onboarding sample data stay?

**Deferred by the founder on 2026-07-30**, who chose "both, but decide later"
when asked whether removing the testing scaffolding also covers the first-run
offer.

**What exists today.** Two separate things share the words "sample data":

- The **Menu card** (`_sampleDataCard`, gated behind `kTestingAids`). Testing
  scaffolding, added because the founder could not test by hand from work. This
  one is settled: the store build does not contain it.
- The **onboarding offer**, "explore the sample data first", inside
  `completeOnboarding`. A shipped first-run feature. Untouched, and the open
  question.
- The **Home banner's** "Remove sample data", which is the way OUT whenever
  sample rows exist. This must survive into a store build regardless of the
  decision below: somebody who loaded sample data needs the exit, and a build
  that strips the exit while leaving the entrance is the worst of the options.

**The case for keeping it.** Letting somebody see a finance app with money in it
before typing their own is ordinary and useful, and Salapify's version is
unusually safe: every seeded row carries the `sample_` prefix and one tap removes
exactly that set. A brand new user otherwise meets an app where every screen is
an empty state, which is the hardest possible first impression for a product
whose value is in what it shows you.

**The case for removing it.** The founder's instinct, which is that pretend money
in a shipped money app is a trust problem, and that a reviewer or a new user
seeing Jollibee transactions they did not enter may read it as the app inventing
data. That is a real risk and it is not answered by the technical safety above.

**How to act on either.** Keeping it needs nothing. Removing it means wrapping
the onboarding branch in `kTestingAids` the same way the Menu card is, and
updating `test/preview_only_test.dart`'s label list so the scan covers it.

**Where the reader will be standing.** `flutter/lib/build_flags.dart` points
here, and that file is what somebody opens to set
`--dart-define=SALAPIFY_PREVIEW=false`. The question therefore surfaces at the
exact moment it has to be answered, rather than in a document somebody has to
remember exists.

### 2. Production upload key

**Deferred until the first Play submission, on purpose.** Production signing
needs an upload key that must NEVER enter the repo (unlike the committed preview
key, which exists only so preview builds install over each other on the founder's
phone). Until the founder is actually submitting to Play there is nothing to do
here, and the production AAB workflow refuses to run without it, so the gap
cannot ship anything wrong. It fails at its first step with these same
instructions.

**What the production build uses.** The `prod` flavor in
`flutter/android/app/build.gradle.kts` reads its keystore only from the
environment (`SALAPIFY_UPLOAD_STORE_FILE` and friends), with no fallback to the
preview credentials. `.github/workflows/flutter-prod-aab.yml` is the only place
that sets those, and it is manual (`workflow_dispatch`) only. So a normal push
never touches the upload key, and a prod build with no key configured fails
loudly at signing rather than borrowing the preview one.

**How to create the upload key** (one time, when submitting to Play):

    keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 \
      -validity 10000 -alias upload

Keep `upload.jks` and the passwords in a safe place OUTSIDE the repo (a password
manager). Losing it means you can no longer update the app on Play without a key
reset, so back it up.

**How to wire it into CI.** Add these four repository secrets (Settings,
Secrets and variables, Actions):

- `SALAPIFY_UPLOAD_KEYSTORE_BASE64`: the keystore file base64 encoded, from
  `base64 -w0 upload.jks` (macOS: `base64 -i upload.jks`).
- `SALAPIFY_UPLOAD_STORE_PASSWORD`: the keystore password.
- `SALAPIFY_UPLOAD_KEY_ALIAS`: the key alias (`upload` above).
- `SALAPIFY_UPLOAD_KEY_PASSWORD`: the key password (often the same as the store
  password).

**How to produce the bundle.** Run the "Production AAB (Play)" workflow by hand
from the Actions tab. It builds the `prod` flavor with testing aids off, then
`.github/scripts/verify-prod-aab.sh` refuses to hand over anything that borrows
the preview identity: the preview certificate, the "Salapify Preview" label, or
the sample-data scaffolding. A green run uploads `salapify-production-aab` as a
build artifact, which is what you submit to Play.

**Play App Signing.** Google re-signs the app with a key it holds; the upload key
above only proves the upload came from you. Enrol in Play App Signing at first
submission (the default for new apps) so a lost upload key can be reset.

**Where the reader will be standing.** The prod AAB workflow points here in its
failure message, so this surfaces at the exact moment production signing is first
attempted.

## Done, recorded so it is not re-litigated

- **Testing scaffolding is flagged, not remembered** (f2.94). `kTestingAids` in
  `flutter/lib/build_flags.dart`, set by `--dart-define=SALAPIFY_PREVIEW=false`.
  Guarded by `test/preview_only_test.dart`, which fails when a testing aid has no
  gate around it, when the flag stops being readable from the environment, and
  when the gate hides the feature from the preview too.
