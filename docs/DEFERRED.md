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

### Nothing was lost with Pan's second health engine (P1.7, F9), and one thing was fixed

**This section replaces an earlier version of itself that was wrong twice, and
the way it was wrong is the point.** It claimed card utilisation left the app
and asked the founder whether to add a sixth health question to bring it back.
Three independent expert passes, asked to decide that question, each began by
correcting the premise instead. Both corrections were then checked against the
code rather than taken on their word.

**Correction 1. Card utilisation never left.** `lib/core/money/accounts.dart`
computes `creditUtilization` and `isHighUtilization`, and
`lib/screens/accounts/bank_card.dart` renders it per card: the percentage, a
progress bar, the limit underneath, the threshold spelled out in words and not
colour alone, and an honest empty state for a card with no limit entered. It
sits on the object it describes, which is where a reference figure belongs.

**Correction 2. The retired reading was broken, so deleting it was a fix.**
Salapify stores a credit balance POSITIVE when money is owed.
`test/core/money/accounts_test.dart` pins it: 12,000 against a 40,000 limit is
30 percent, and the sample BPI card carries `balance: 4200.00` against a 40,000
limit. The retired `_cardUse` counted only the negative side:

    (double s, Account c) => s + (c.balance < 0 ? -c.balance : 0),

so on that sample card it computed 0 percent and awarded a perfect 25 of 25
with the reading "0% of the limits you have entered". It reported zero
utilisation on every card actually carrying debt, and could only ever fire on a
card in credit, which by definition owes nothing.

Its own doc comment asserted the opposite convention with full confidence, and
its test used `balance: -18000` and expected 45 percent, so the test agreed with
the bug. That is the failure this repository already has a rule about: a test
written from the same wrong mental model as the code passes for the wrong reason
and then reads as proof.

**So the three retired readings are:**

| Retired reading | Verdict |
|---|---|
| Cover, months of spending held in cash | Still answerable. Safe to Spend owns the runway figure and Pan still answers "what is safe to spend". |
| What you owe, pesos owed per 100 held | Still answerable. Pan's own "what do I owe" answer and the Reports net worth card. |
| Card use, balance against the limits entered | Already shipped and correct on the Accounts screen. The retired copy was wrong by sign and is not coming back. |

**DECIDED, no founder action needed: the Health Check stays at five
questions.** Nothing was lost that needs replacing, and three separate reviews
converged on the same reasons for not adding a sixth even if something had
been: credit card ownership is a minority of the audience and a typed-in credit
limit a minority of that, so a sixth card would be grey on most installs, which
is the exact outcome the five-not-twelve decision of 2026-09-20 was made to
prevent; the five are ordered by time horizon and a ratio has no horizon;
and a sixth candidate that is never measured dilutes the one "worth doing
something about" banner without ever competing for it.

### Two Health Check and Accounts findings, verified, not yet fixed

Both came out of the expert pass on the sixth-question decision, and both were
checked against the code and the rendered screen rather than taken on the
report's word. Neither is in P1.7's scope, so neither was folded into it.

**1. The banner repeats a card the user can already see.** The Health Check
sheet opens with one "WORTH DOING SOMETHING ABOUT" box carrying the tightest
reading, and on the lived-in ledger that reading is the SAME SENTENCE as the
one on card five, both on screen at rest: "Debt & Loan Servicing is over by
₱450.00". The sheet's own comment records that an earlier version printed the
question there and that this was fixed by printing the reading instead; it
swapped one duplication for another. The fix is to let the card that is already
in the banner render without restating it, or to give the banner the one tap
and leave the detail to the card, so they are not the same object.

**2. The one place that asks for a credit limit cannot accept the answer.**
`_Utilisation` in `screens/accounts/bank_card.dart` prints "Add this card's
limit to see how much of it you are using." as a bare `Text` with no tap of its
own, and the card's only `InkWell` calls `_turn`, which flips it over. So the
sentence is a request with a four-step scavenger hunt behind it: Accounts, find
the card, tap to flip, tap Edit, scroll to the field. That is the same shape as
the Home dead ends P1.1 removed. Making it a real control is the smallest
change that would get more people measured on a figure the app already
computes correctly.

### The real card gap, which is NOT utilisation


Two of the three reviews independently landed on the same genuine hole, and it
survived checking. `_promised`, question 2, counts only `InstallmentPlan`
records. A revolving credit card balance with no plan behind it contributes
nothing to "how much of my pay is already promised", while costing the person
real money every month. Utilisation cannot see this either: somebody who runs
30,000 a month through a 50,000 card and clears it in full pays nothing and
reads as stretched, while somebody carrying 6,000 on the same card at the
minimum reads as comfortable. The ratio ranks them backwards, and the second
person is who the Health Check exists for.

**This is a founder decision and it is money meaning, so it is not being built
on anyone's initiative.** The clean version is an optional minimum-payment
field on a credit account, counted into `monthlyInstalments` when the person
entered one and absent when they did not. Never an assumed percentage:
`health_check.dart` already names that sin, because the prototype assumes eight
percent of every outstanding debt is a monthly minimum and so charges somebody
for family utang that has no minimum and never did.

Deferred pending the founder.

### The instalment screen reprints the lender's marketing rate as the true cost

Found by the bank-officer review during P2.1's instalment conversion, and the
largest single finding in it. NOT fixed, because fixing it is new feature work
and it changes what Salapify tells somebody about the cost of credit.

`annualisedRate` multiplies a monthly ADD-ON rate by twelve, and the screen
prints "That 1.5% a month is 18.0% a year." The arithmetic is right and the
framing is wrong: 18% a year IS what the poster says, because the poster quotes
the add-on rate. An add-on rate charges interest on the ORIGINAL principal for
the whole term, so the true cost on the balance you still owe is roughly double.

Solved from each plan's own cash flows:

| Plan | Quoted | Shown today | True effective a year |
|---|---|---|---|
| Home Credit, 24,500 over 12 months | 1.5% a month | 18.0% | about 36.8% |
| SPayLater, 8,400 over 6 months | 2.95% a month | 35.4% | about 76.8% |
| BPI SIP, 54,990 over 24 months | 0% | n/a | 0% |

The app is currently on the lender's side of the add-on trap, which is the
single thing `bank-officer` exists to prevent.

**Why it is not fixed here.** The honest figure is an internal rate of return
solved from the payment schedule, and nothing in the codebase computes one. It
is new math with its own vectors, not a type conversion, and the correct screen
copy is a founder call: the quoted rate must stay visible, with the real one
beside it, and the wording decides whether this reads as help or as an accusation
against a lender.

**The adjacent half, already fixed**, because leaving it was worse: the summary
card claimed "Paying early is what takes it off" about unearned interest. On a
fixed add-on plan it does not. That line now says so.

**One discipline note.** The review's statements about Philippine lending
practice, the Consumer Act, the Truth in Lending Act and BSP circulars were all
marked UNVERIFIED MEMORY by the reviewer, who could not reach gov.ph from the
sandbox. None of it has reached a screen and none should until independently
searched, which is this repository's existing rule after a fabricated
government URL survived a confident review.

### A plan cannot be created in the app yet

`InstallmentPlan` is constructed in exactly three places: the model, the JSON
codec and the sample data. There is no "add a plan" sheet. That is the cheap
moment to settle something the model cannot currently express: `InterestRateType`
says "per what period" and never says add-on or diminishing, and those cost
roughly double one another. `loan.dart` already has the right enum. When the
sheet is built, make it a required choice.

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
