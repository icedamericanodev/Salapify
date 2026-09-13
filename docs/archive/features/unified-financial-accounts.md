# Unified financial accounts

Architecture decision document. Phase 1 only: nothing is implemented, and the
last section is the recommended plan for what to build first.

Status: PROPOSED, needs founder sign off on the four decisions marked
**DECISION** below before any code is written.

---

## 1. What exists today, read from the code

Everything in this section was read out of the repository, not remembered. The
file and line are given so the next reader can check rather than trust.

### The three collections

Salapify stores financial position in three separate lists, and they are not
symmetric.

**`accounts`** (`flutter/lib/data/backup.dart:225`)

```
{ id, name, brand, icon, kind, balance, target }
```

`kind` is CLAMPED to exactly four values on every load and every save:

```dart
'kind': const ['cash', 'savings', 'checking', 'ewallet'].contains(a['kind'])
    ? a['kind']
    : 'cash',
```

Anything else silently becomes `cash`. This is the single most important fact
in this document and section 4 is mostly about it.

**`assets`** (`backup.dart:239`)

```
{ ...whatever was stored, value }
```

Almost no normalization. Only `value` is coerced. Everything else survives
untouched.

**`debts`** (`backup.dart:242`)

```
{ ...stored, name, type, remaining, monthlyRate, minPayment,
  dueDay, statementDay, graceDays, creditLimit, interestThroughISO? }
```

`type` is a FREE STRING defaulting to `'other'`. Only one value is ever
branched on: `type == 'credit card'` (`lib/money/debts.dart:132`, `:294`)
decides whether a statement day is required, whether a credit limit applies,
and whether a logged payment posts as `pending` or `posted`.

All three normalizers use `{...a, ...}`, so **unknown keys already survive a
load, a save, and a backup round trip**. New metadata does not need a
migration to persist. It needs a decision about the golden contract, below.

### Net worth

`netWorthParts` (`lib/money/statements.dart`) is the one formula:

```
assets      = sum(accounts.balance) + sum(assets.value) + trackedRemaining(receivables)
liabilities = sum(debts.remaining)  + trackedRemaining(payables)
netWorth    = assets - liabilities
```

Three things follow, and each matters for this feature:

1. Liabilities already subtract. Nothing needs to be modelled as a negative
   balance, which matches the founder's instruction.
2. A credit LIMIT is stored but never enters net worth. Correct today.
3. **There is no currency conversion anywhere in this function.** Every number
   is added as if it were in one currency. Section 5 is about that.

### Balance adjustments

Editing an account's balance does not just overwrite it. `balanceAdjustDelta`
(`lib/money/accounts_calc.dart:16`) produces a signed delta, which becomes a
real ledger entry. That is why the balance history reconciles. Any new edit
path must keep going through it.

### The golden key-set contract

`test/backup_golden_test.dart:4` and `:33` compare the normalized output
against fixtures generated from the React Native app, **strictly on key sets**:

> Comparison is STRICT on key sets: a key the fixture does not have is a
> failure.

So a new field cannot simply be added to the normalizer. The codebase already
has the pattern for this, used three times: `paluwagans`, `steadyPay` and
`quickAddsEdited` are all CONDITIONAL keys, emitted only when the stored blob
actually carries them, removed otherwise (`backup.dart:484` onward). Every new
field in this feature must follow it.

### Currency today

`lib/money/currencies.dart` has a currency list, `resolveBaseCurrency(settings)`
and a mutable global `baseCurrencySymbol`. Currency is **one app-wide setting**
(`settings.currencyCode`). No account, asset or debt has a currency of its own;
`backup.dart:542` strips `currencyCode` from anywhere it is not a string, and
that is in SETTINGS.

`lib/data/fx_service.dart` fetches and caches rates (`FxRates(base, rates,
fetchedAt)`, with `cached`, `refresh`, `load`). It exists and works, and it is
currently used for a converter, not for totals.

### What the RN screen does

From the screenshot: one summary card (net worth, total assets, total owed),
three buttons (`+ Account`, `+ Asset`, `Transfer`), then grouped sections with
a per-section subtotal. Institution logos on bank and wallet rows, a generic
icon on investments. The proposed direction replaces the first two buttons with
one, and keeps everything else.

---

## 2. The risks, ranked

**R1. The `kind` whitelist silently rewrites data.** Adding `payroll`,
`digital bank`, `time deposit` or `foreign currency` as an account `kind` and
shipping it means: the value is written, then the next load rewrites it to
`cash`. The account does not break, but its subtype vanishes, permanently, with
no error. This is the same silent-coercion class that has already shipped three
times in this project.

**R2. Multi-currency without FX in net worth is a wrong number, not a missing
one.** The moment a USD account exists, `netWorthParts` adds its balance to a
peso total. A USD 1,000 account would read as ₱1,000 and understate net worth by
roughly ₱55,000. A missing feature is visible; a wrong total is not.

**R3. The golden key-set contract breaks on any unconditional new field.** Nine
fixture files are generated from the RN app. They will never carry
`accountClass` or `institutionId`.

**R4. Moving an existing item between collections destroys its history.** An
account carries ledger links and transfer references; a debt carries payment
history. A "helpful" reclassification that moves a savings account into `assets`
would orphan every transaction pointing at it. The founder's instruction already
says not to; this records why it would be severe.

**R5. Logos cannot ship over the air.** Image assets are not carried by a
Shorebird patch. Any real logo means a new base APK and a manual install by the
founder. This is the same cost the widget release is paying right now, and it
should not be paid twice in a row for decoration.

**R6. RN parity.** `mobile/` is still the shipping app for testers. A Flutter
backup carrying new fields must still restore in RN, and an RN backup must still
restore in Flutter. Unknown-key preservation gives us the first direction free;
the second is already handled by the conditional-key pattern.

**R7. Scope.** Phases 2 to 4 as written are roughly a dozen batches of work
touching the highest risk files in the codebase. Section 8 proposes cutting it
into deliveries that each stand on their own.

---

## 3. Proposed UX flow

One primary action, `Add account`, replacing `+ Account` and `+ Asset`.
`Transfer` stays as it is.

```
Step 1  What are you adding?
        [ Asset ]      Something you own, or money available to you.
        [ Liability ]  Money you owe or need to pay.

Step 2  Category        (only those valid for step 1)
Step 3  Subtype         (only those valid for step 2)
Step 4  Institution     (only when the subtype has one)
Step 5  Details         (fields determined by subtype)
```

Steps 2 and 3 collapse into one screen when a category has three or fewer
subtypes, because a step that only ever shows one choice is a tap tax.

**Never requested, never stored, in any field, ever:** full account number, full
card number, CVV, PIN, OTP, username, password. Only an optional last four
digits, validated as exactly four digits. This is written here so it is a
constraint rather than a preference.

---

## 4. Data mapping

**DECISION 1: keep three collections, add metadata. Do not unify storage.**

The unification is in the UI. Internally, an item lands in the collection its
behaviour requires:

| The person adds | Stored in | Because |
| --- | --- | --- |
| Cash, savings, checking, payroll, e-wallet, digital bank, foreign-currency cash | `accounts` | Money can be logged from it and transferred |
| Investments, property, vehicles, equipment, jewellery, other fixed | `assets` | A value that is not a transaction source |
| Credit cards, loans, mortgages, installments, payables | `debts` | Has a payment engine, interest, due dates |

**DECISION 2: subtype goes in a NEW field, not in `kind`.**

`kind` stays clamped to its four legacy values and keeps meaning exactly what it
means today. A new `subtype` field carries the real answer. So a payroll account
is `kind: 'checking', subtype: 'payroll'`. Every existing engine keeps working
untouched, and R1 disappears entirely rather than being managed.

The alternative, widening the whitelist, was considered and rejected: it changes
what a restored RN backup produces, which is exactly the class of change that
needs a data-migration review and a founder gate.

**New fields, all optional, all CONDITIONAL keys following the `paluwagans`
pattern:**

```
accountClass     'asset' | 'liability'
category         stable id, e.g. 'cash_equivalents'
subtype          stable id, e.g. 'payroll_account'
institutionId    stable id, e.g. 'bpi'
institutionName  free text, only for a custom institution
currencyCode     ISO 4217, absent means the base currency
last4            exactly four digits
includeInNetWorth  bool, absent means true
isArchived       bool, absent means false
createdAt        ISO
updatedAt        ISO
```

**Stable ids, never display labels.** A label is a translation and a product
decision; an id is a contract. `'cash_equivalents'` never changes, the words on
screen can.

**Legacy mapping is derived, never written.** An account with no `subtype` is
read as its legacy equivalent at display time:

```
cash     -> Asset / Cash and cash equivalents / Cash on hand
savings  -> Asset / Cash and cash equivalents / Savings account
checking -> Asset / Cash and cash equivalents / Checking account
ewallet  -> Asset / Cash and cash equivalents / E-wallet
```

Deriving rather than backfilling means no migration runs over user data, and an
RN backup restored tomorrow reads correctly without ever having been touched.

---

## 5. Multi-currency

**DECISION 3: ship the account-level currency FIELD and the display, but do NOT
convert in net worth until the honest-total rules below are built.**

R2 is the most dangerous item in this document, so the order matters:

1. Store `currencyCode` per account. Display foreign amounts in their own
   currency, with the code beside them.
2. **Exclude un-converted foreign accounts from every converted total, and say
   so on screen.** A total that names what it is missing is honest; a total that
   silently adds USD to PHP is not.
3. Only then wire `FxService` into `netWorthParts`, behind rules that never
   produce a silent wrong number:
   - a rate exists and is fresh: convert, and show the rate's age
   - a rate is stale: convert, and label the total as using an old rate
   - no rate at all: exclude, name the excluded accounts, offer a manual rate
   - a manual rate: use it, and label it as manual

Net worth is always in the base currency. `USD 1` is never `PHP 1`. There is no
state in which a converted total is shown without the reader being able to see
what it was converted with.

This is also a money-math change, so it falls under the golden-vector rule in
CLAUDE.md: the conversion path needs test vectors before it merges.

---

## 6. Institutions and logos

A catalog in code, not in user data:

```dart
class FinancialInstitution {
  final String id;              // 'bpi', stable forever
  final String displayName;     // 'BPI'
  final InstitutionType type;   // bank | digitalBank | eWallet | lender | broker
  final List<String> aliases;   // 'Bank of the Philippine Islands', 'BPI Family'
  final List<String> supportedCurrencies;
  final String? localAssetPath; // null until a logo is cleared for use
}
```

User data stores `institutionId` only. **Never an asset path**, so a renamed or
removed image can never corrupt stored data or break a screen.

Covering the institutions the brief lists: BDO, BPI, Metrobank, UnionBank,
Security Bank, RCBC, PNB, LandBank, China Bank, EastWest, PSBank, AUB, Bank of
Commerce; Maya Bank, GoTyme, CIMB, SeaBank, Tonik, UNO, OwnBank; GCash, Maya
Wallet, GrabPay, ShopeePay. Plus `other`, `none`, and a custom name.

**USD is not an institution.** It is a currency chosen after the institution.
The brief says this explicitly and it is repeated here because the RN screenshot
groups by institution and it would be an easy mistake.

**DECISION 4: ship initials first, real logos later or never.**

An `InstitutionAvatar` renders, in order: a cleared local asset if one exists,
otherwise the institution's initials on a tinted circle, otherwise a generic
bank, wallet, or card icon. Never a network fetch, never a hotlink, never a
scrape. The feature must be complete and shippable with zero image files.

The reason is R5 plus trademark: using a bank's mark needs permission we do not
have, and each batch of images costs the founder a manual APK install. Initials
look deliberate, work offline, cost nothing, and never need clearing.

---

## 7. Testing plan

Money and data first, screens second.

**Golden and parity**
- The existing backup goldens must stay green with zero fixture edits. If a
  fixture needs editing, the design is wrong.
- Round trip: Flutter blob with every new field, exported, restored, unchanged.
- RN backup in, Flutter backup out, restored in RN: no field lost either way.

**Migration and legacy**
- Each legacy `kind` derives the right class, category and subtype.
- An account with an unknown `subtype` still loads and still spends.
- `kind` still clamps: a stored `kind: 'payroll'` reads as `cash`, proving
  DECISION 2 is why we did not touch it.

**Financial integrity** (the brief's list, each as a named test)
- assets raise net worth, liabilities lower it
- a credit limit changes nothing
- `includeInNetWorth: false` excludes an item from totals but not from its list
- an archived item leaves totals and stays reachable
- a foreign account converts correctly, and with no rate is EXCLUDED and named,
  never silently added
- transfers still work, investments are not transfer sources
- a debt payment reduces the liability
- editing a balance still writes a ledger adjustment
- every existing account remains editable

**Screens**
- classification, dynamic categories, dynamic subtypes, dynamic fields
- institution search by name AND by alias, custom institution, none
- last four rejects three digits, five digits, and letters
- keyboard does not cover the save button, text scaling to 2x
- save maps to the correct collection, and an edit never moves collections
- a missing logo shows initials and the row still renders

**Look at it.** Every new screen rendered through the shot harness and actually
looked at, dark first, per CLAUDE.md.

---

## 8. Files expected to change

New:
```
lib/money/account_taxonomy.dart      categories, subtypes, legacy derivation
lib/money/institutions.dart          the catalog and search
lib/screens/add_account_flow.dart    the guided flow
lib/widgets/institution_avatar.dart  logo or initials
```

Changed:
```
lib/data/backup.dart        conditional keys only, no new unconditional fields
lib/data/store.dart         create and edit paths for the new metadata
lib/screens/accounts.dart   one Add button, grouped sections, avatars
lib/screens/debts.dart      liabilities created through the same flow
lib/money/statements.dart   includeInNetWorth, isArchived, later FX
lib/money/currencies.dart   per-item currency helpers
pubspec.yaml                ONLY if real logos are approved (base APK)
```

Not changed, deliberately: `lib/money/debts.dart`, `debtmath.dart`,
`accounts_calc.dart`. No proven defect, so no rewrite.

---

## 9. Recommended plan

The brief's phases 2 to 4 are, honestly, more than one delivery. They touch
backup, net worth and every financial screen at once, which is the combination
most likely to produce a wrong number on the founder's phone. My recommendation
is five deliveries, each one shippable and each one useful alone:

**A. Taxonomy and institutions, no UI.** `account_taxonomy.dart`,
`institutions.dart`, legacy derivation, conditional-key persistence, and their
tests. Ships over the air, changes nothing visible, and proves the data design
before a single screen depends on it.

**B. The unified Add account flow.** One button, five steps, mapping to the
existing three collections. The biggest visible win, and no new totals.

**C. The Accounts screen redesign.** Grouped sections, subtotals, institution
avatars with initials. Still no FX.

**D. Currency per account, displayed but not converted.** Foreign amounts shown
in their own currency, excluded from converted totals with an on-screen reason.

**E. FX in net worth**, under the honest-total rules in section 5, with golden
vectors. Separately gated, because it is the one that can produce a wrong
number.

Real logos are deliberately not in the list. They are a base APK and a manual
install for decoration, and initials make the feature complete without them.

**Recommended first: A.** It is invisible, it is the foundation everything else
sits on, and it is the cheapest possible place to discover the data design is
wrong.

**Founder sign off needed on DECISIONS 1 to 4 before Phase 2 begins.**
