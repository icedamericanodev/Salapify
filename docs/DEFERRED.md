# Deferred

Anything the build sprint skipped, postponed or deliberately did not do, with
the reason. Written as it happens rather than reconstructed at the end.

## Declared out of scope by the sprint prompt

These are not oversights. The founder's prompt names them as out of scope for
this sprint, and they are listed here so the next pass has one place to look.

| Item | Review finding | Why it is out |
|---|---|---|
| Encryption at rest (SQLCipher), app lock (local_auth), and fixing the docs that claim encryption | Fix-before-launch 6 | Named out of scope. It is a real trust gap: the data is plaintext JSON and the docs say otherwise, so the DOCS are currently wrong in the dangerous direction. |
| Release signing, upload key, release AAB in CI, version and description in pubspec | Fix-before-launch 9 | Named out of scope. Blocks a Play submission entirely, so it has to happen before any public tester. |
| Pan and Academy regulatory guardrails (imperatives, named products, quoted rates) | Guardrails, money copy 5 | Named out of scope. Where the sprint touches that copy it leaves it alone and marks it `// TODO(compliance):`. |
| Verifying rules against CMEPA (RA 12214) | Money copy 6 | Named out of scope. The MP2 withholding line and the long-term deposit exemption may be outdated. |
| Privacy policy and store listing copy | Roadmap, later | Named out of scope. |

## Deferred during the sprint

Nothing yet.

## Raised by the sprint, not in the prompt

### The sample payday cycle is still frozen

Carried over from the work just before this branch. A brand new install on any
date outside mid-September shows "4 days to payday" and "Sep 1 to Sep 15" on
the Safe to Spend card, because the seeded `PaydayCycle` carries no
`paydayDays` rule and so cannot recompute itself.

Not fixed because it moves a headline money figure: the frozen cycle is
internally inconsistent (4 days to a payday on 15 September, from an anchor of
18 September, which is three days past it), so giving it the rule changes Safe
to Spend and everything derived from it across about a dozen test files.

Put to the founder on 2026-10-01 and awaiting an answer. It is close to F5 and
the review's Safe to Spend findings, so it may fold into P2.5.
