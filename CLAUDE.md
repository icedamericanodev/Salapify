# Salapify working rules

Salapify is an offline first budget, debt, and utang tracker for Filipino
Gen Z, millennials, and working corporate adults. React Native with Expo
SDK 54 lives in mobile/. There is no backend; all data stays on the device
in AsyncStorage under the key salapify_data_v2.

## Writing style

Never use em dashes or en dashes anywhere: code comments, commit messages,
PR text, UI copy, ads. Use commas or periods instead. Plain English
explanations for the founder, who is a beginner. Small tested steps.

## Development workflow

1. Develop on the branch claude/salapify-v2 and open PRs to main.
2. Compile check every changed file with the Expo Babel preset before
   committing (run node with babel.transformFileSync from mobile/).
3. Commit per milestone with a clear message explaining the why.
4. JS only changes ship over the air: every push to the branch triggers
   the EAS workflow that publishes to the preview update channel. Bump the
   Update stamp row in mobile/app/(tabs)/more.js on every push so the
   founder can verify on the phone which bundle arrived.
5. Native changes (new native modules, app.json plugin or version changes)
   need a full APK rebuild on EAS and a version bump to isolate runtimes.
   Flag these loudly, they are not over the air.

## Merge rules (separation of duties)

Claude may review and merge its own PRs when ALL of these hold:
- The change is routine: UI, copy, new screens, refactors, additive
  features that do not touch the items on the significant list below.
- A QA pass ran on the changed code (the qa-tester agent or equivalent)
  and found no must fix issues.
- The Expo publish status check on the PR head commit is green.
- The merge uses "Create a merge commit". Never squash, squash rewrites
  history and causes merge conflicts on the next PR every single time.

The founder reviews and merges when the change is significant, meaning any
of: the stored data shape or migration logic, money math (balances, debt
payoff, forecasts, analytics), backup and restore, security or app lock,
notifications scheduling, monetization or pricing, deleting or replacing
user data, or anything requiring an APK rebuild. When in doubt, treat it
as significant and notify the founder instead of merging.

After any merge, confirm the branch still merges cleanly into main; if the
founder squash merged by accident, merge origin/main back into the branch
keeping the branch side on conflicts (the branch is always strictly newer).
