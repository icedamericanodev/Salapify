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

## Done, recorded so it is not re-litigated

- **Testing scaffolding is flagged, not remembered** (f2.94). `kTestingAids` in
  `flutter/lib/build_flags.dart`, set by `--dart-define=SALAPIFY_PREVIEW=false`.
  Guarded by `test/preview_only_test.dart`, which fails when a testing aid has no
  gate around it, when the flag stops being readable from the environment, and
  when the gate hides the feature from the preview too.
