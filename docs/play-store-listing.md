# Salapify - Google Play Console listing (draft for submission)

Rewritten to match the shipped Flutter app. The previous draft described the older React
Native build (home screen widgets, Peso Smart import, only Forest and Mint themes, a logging
chain streak) and was stale, the same way privacy.html was. Every claim below is true of the
current Flutter app, stays clear of lending and investment language (Play finance policy),
and never promises "free forever". Have legal-compliance-counsel do a final pass before you
submit, and keep the Data safety answers identical to privacy.html.

Character limits are Google's: title 30, short description 80, full description 4000.

---

## App title (30 max)

```
Salapify: Budget, Utang, Ipon
```
(29 characters. Leads with three of the highest-intent Philippine finance search words:
budget, utang, ipon. "Salapify" first keeps the brand as the anchor.)

Alternatives:
```
Salapify: Budget & Utang        (24)
Salapify Utang & Budget App     (26)
```

---

## Short description (80 max)

```
Track gastos, utang, at ipon offline. No account, no ads. It stays on your phone.
```
(80 characters. "gastos", "utang", "ipon" are search terms; the offline and no-account
lines are the trust hook that differentiates from cloud apps.)

---

## Full description (4000 max)

```
Salapify is the money app built for how Filipinos actually earn, spend, and lend. Budget around your sweldo, track every utang, plan your debts, and see where your gastos really go. All offline, all on your phone, no account and no ads.

Your money life is private. Salapify has no sign up, no cloud, and no trackers. Nothing you enter ever leaves your phone unless you make a backup yourself. Walang lider ng data.

WHAT YOU CAN DO

Track utang, both ways
Log who owes you and who you owe, per person, with due dates. See your total inutang sa akin in one number, know who to follow up first, oldest first, and get a ready reminder you can copy and send, so it never gets awkward.

Split a bill (Hatian)
Someone fronted the group dinner or the Grab? Split it in seconds and each person's share becomes utang you can actually collect. Your own share stays your expense, so only your real cost hits your money.

Budget around your sweldo
Plan by your real 15th and end of month cutoffs, not a foreign calendar month. See what is safe to spend until your next sweldo, with card and bill due dates already adjusted for weekends and Philippine holidays.

Get out of debt
Track credit cards, BNPL, and loans with honest interest and amortization. See what each payment really costs in interest and principal, and where to attack first.

Save with a goal (Ipon)
Set an ipon goal, watch the progress, and get an honest monthly pace so you know if you are on track.

Paluwagan tracker
Follow your barkada or office paluwagan: who has paid, whose turn is next, your payout date, and an honest read on whether your turn is an early advantage or forced savings.

See where it went
Clear reports: net worth, cash flow, and your spending trend, with graphs that answer real questions, like which weekday you overspend and whether you saved or spent this month.

Handy calculators
Loan, tax, and take home pay calculators, plus a currency converter with 20 currencies, all in one place.

Ask Pan
Ask your money questions in plain words and get answers from your own data. Walang halong AI sa cloud.

WHY SALAPIFY

Offline first. Works with or without load or signal.
No account. Start logging in seconds, nothing to sign up for.
No ads, ever.
Your data stays on your phone. Back it up yourself, any time, to a place you choose.
App lock with your fingerprint or face.
Eight color themes, light and dark.

Core features are free forever. Salapify Pro is free during early access, and early users keep Pro free.

Salapify is a personal finance manager. It does not lend money, offer credit, or handle investments. It helps you track and plan the money that is already yours.
```

(Under 4000. Keyword coverage: budget, utang, gastos, ipon, sweldo, paluwagan, hatian, debt,
loan, tax, take home, currency converter. The closing sentence states plainly that the app is
not a lender, which reinforces the Play finance classification.)

---

## What's new (release notes, 500 max)

```
Faster logging: tap a recent name instead of typing, and your last used account is already picked. New Reports graphs show your net cash flow month by month and your busiest spending weekday. Split a bill with Hatian and track your paluwagan. Thanks for trying Salapify during early access.
```

---

## Data safety form (must match privacy.html exactly)

- Does your app collect or share any of the required user data types? **No.**
- Data collected: **None.** No personal info, no financial info sent to us, no location, no
  contacts, no identifiers, no analytics.
- Data shared: **None.**
- Is all user data encrypted in transit? Not applicable (no user data is transmitted).
  If the reviewer asks: the app makes two network calls, neither carrying user or financial
  data. It fetches exchange rates from a public service (sending only a currency code, for
  example PHP), and it checks for app code updates through Shorebird.
- Does your app provide a way to request data deletion? **Data is stored only on the device;
  deleting an item removes it and uninstalling the app removes all of it. No account, so no
  server side data to delete.**
- Families policy: not a child directed app; target audience is adults.

## Financial features declaration

- Does the app provide loans, or facilitate personal loans? **No.**
- Investments, or manage investments? **No.**
- The app is a personal finance manager only. Declare accordingly. (This declaration is
  mandatory even on testing tracks.)

## Content rating (IARC questionnaire)

- Category: Utility / Finance (general audience).
- Violence, sexual content, profanity, controlled substances: **None.**
- Gambling: **None.** (Paluwagan is a savings group tracker, not a game of chance.)
- User generated content shared publicly: **None.** ("Share your month" produces a card the
  user chooses to export; nothing is posted to a public feed.)
- Purchases / in app purchases: none yet (Pro is currently a free early access flag). Update
  this if paid Pro ships, and use Google Play Billing when it does.
- Expected result: **Everyone.**

## Store settings

- App category: **Finance.**
- Tags: budget, expense tracker, debt tracker, money manager. (Play picks from a fixed list;
  choose the closest.)
- Contact email: a real, monitored address (required; also referenced by privacy.html).
- Privacy policy URL: https://icedamericanodev.github.io/Salapify/privacy.html
  (verify it loads and matches the app before submitting).
- Contains ads: **No.**

---

## Screenshot captions (conversion ordered, 8 frames)

Sell the wedge first, then the differentiators. Short captions, English with the Filipino
identity word as flavor.

1. Utang list. "Know exactly who owes you, and follow up without the awkward."
2. Bill split (Hatian). "Split the bill. Each share becomes utang you can collect."
3. Safe to spend. "See what is safe to spend until your next sweldo."
4. Debt plan. "Track cards, BNPL, and loans with honest interest."
5. Reports graphs. "See if you saved or spent, month by month."
6. Paluwagan. "Track your paluwagan: whose turn, your payout, your standing."
7. Ipon goal. "Set an ipon goal and keep an honest monthly pace."
8. Privacy. "No account. No ads. Your data stays on your phone."

Feature graphic line (1024x500): "Budget, utang, and ipon. Offline and private."

---

## Pre submission gates (handled outside this document)

These block submission and are not copy:

1. Production AAB signed with a real upload key or Play App Signing, not the committed
   preview keystore. (Needs the founder's production key.)
2. App label changed from "Salapify Preview" to "Salapify" in the production build.
3. `android:allowBackup="false"` set in the production manifest, so the OS never copies data
   to the user's own Google account and the privacy policy's "stays on your phone" claim is
   literally true. Native change, base rebuild, not over the air.
4. Staged rollout for production (start around 10 percent).
5. Financial features declaration, Data safety form, and IARC rating completed as above.
6. A final legal-compliance-counsel pass on this listing copy before it goes live.
