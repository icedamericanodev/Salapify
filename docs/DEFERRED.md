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

### Three readings retired with Pan's second health engine (P1.7, F9)

F9 retired `pan_health.dart`, so the whole app now runs one health check, the
five-question engine the Health Check sheet already used. Pan's old engine
scored four parts, and three of them have no equivalent among the five, so
three readings left the app with it:

| Retired reading | Still reachable? |
|---|---|
| Cover, months of spending held in cash | Yes. Safe to Spend owns the runway figure, and Pan still answers "what is safe to spend". |
| What you owe, pesos owed per 100 held | Yes. Pan's own "what do I owe" answer and the Reports net worth card. |
| Card use, balance against the limits entered | NO. Nothing else in the app computes a card utilisation percentage. The Accounts screen shows the limit and the balance side by side and leaves the division to the reader. |

Card use is the real loss and it is deliberately not replaced here. Adding a
sixth question is a product decision, not an engineering one: the founder
settled on five on 2026-09-20 precisely because twelve destroyed the signal,
and quietly making it six inside a consolidation task would undo that decision
without anybody deciding anything.

**For the founder:** should "Am I leaning on my cards?" become a sixth health
question? It is the one reading that went nowhere else, it only works for
people who entered a credit limit, and the old engine handled that honestly by
excluding anybody who had not. Say the word and it is a small, contained
addition to `health_check.dart`.

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
