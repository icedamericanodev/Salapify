# Accounts, the fifth tab

Built 2026-09-18 on branch `claude/flutter-final`, from
`src/components/AccountsScreen.tsx` (986 lines) and `BankCard.tsx` (134).

Every tab in the prototype now has a real screen in `app/`. The migration
table's tab column is complete; `docs/migration/coverage-audit.md` is the list
of what is still missing INSIDE those tabs.

## Scope

**Built.** The Accounts screen: net worth scoped to the active entity, four
view filters, eight collapsible account groups with subtotals, debit and
credit accounts drawn as cards with their scheme, tier, digits, limit and
utilisation, the both-ways debt register card, and the add and edit write
path. Multi-currency support underneath it, with a peso equivalent under any
foreign balance.

**Deliberately not built,** each with its reason below: account deletion, and
the holdings tracker behind the Investments filter.

## What changed

| File | Lines | What |
|---|---|---|
| `lib/core/money/currencies.dart` | new | `CurrencyCode`, symbols, names, fixed rates, `convertToPhp`, `formatCurrency` |
| `lib/core/money/accounts.dart` | new | Grouping, peso-converting sums, filtering, credit utilisation, monograms, the hero summary |
| `lib/screens/accounts/accounts_screen.dart` | new | The tab |
| `lib/screens/accounts/bank_card.dart` | new | A debit or credit account drawn as plastic |
| `lib/features/accounts/account_sheet.dart` | new | Add and edit |
| `lib/models/models.dart` | edited | `Account` gains `currency`, `dueDate`, `statementDate`, `cardNetwork`, `cardTier`, plus `balanceInPhp` and `isForeign` |
| `lib/core/money/reports.dart` | edited | `toPhp` now converts instead of returning its argument |
| `lib/state/financial_state.dart` | edited | `addAccount`, `updateAccount` |
| `lib/design/type.dart` | edited | Every style names the font family. See the defects below |
| `lib/data/seed_data.dart` | edited | One monogram corrected, five fields the prototype's seed carries restored |
| `lib/shell/app_shell.dart` | edited | Tab 5 wired |
| `lib/features/info/info_sheet.dart` | edited | The `accounts` explainer topic |

Tests: `test/core/money/currencies_test.dart` (6 groups, 90 golden vectors),
`test/core/money/accounts_test.dart` (18), `test/widgets/accounts_test.dart`
(16), `test/widgets/accounts_journey_test.dart` (3),
`test/widgets/font_inheritance_test.dart` (1). Renders: 11 new PNGs in
`test/shots/screens_shot.dart`, committed to `docs/migration/screens/`.

## Money behaviour

**Changed: one thing, and it moves no figure today.**
`reports.dart`'s `toPhp` was the identity function, left as a named seam for
the day the model carried a currency. That day is now, so it converts. Every
account in the fixture is PHP, so every reports vector is unchanged, and the
229 money tests staying green is what proves that rather than my saying so.

**Everything else is unchanged.** Accounts computes net worth as
`assets - liabilities` from the same two kind lists Reports uses, imported
rather than redeclared, and `accounts_test` asserts the two agree to the
centavo on the seed. The prototype declares those lists twice, in
`AccountsScreen.tsx` and `ReportsScreen.tsx`, which is how two screens end up
disagreeing about the same money.

### Three deliberate divergences from the prototype

1. **The hero's liabilities figure.** The prototype's hero prints
   `totalCreditUsed + totalDebtsIOwe`, which does not add up with the net
   worth directly above it: that net worth subtracts loans and mortgages and
   does not subtract debts. Salapify prints the figure that actually makes the
   hero's own arithmetic work, and the debt register keeps its own two figures
   in its own card below, with a line on the hero saying so.
2. **No invented credit limit.** The prototype falls back to a 40,000 limit
   when a card has none recorded, which produces a made up percentage that the
   screen then colours red or green and a person reads as advice. Here a card
   with no limit says so and asks for one.
3. **No bank logos.** The prototype fetches each institution's logo from a
   remote URL. Salapify is offline first, so the monogram is the mark. That
   raises the stakes on the monogram being right, which is why there is now a
   test for it.

## Defects found and fixed

Three, and two of them were invisible to every passing test.

1. **A MariBank account labelled "SB".** SeaBank was renamed MariBank; the
   prototype's seed kept the old monogram, so its own `computeMonogram` and
   its own data disagreed. Whoever read that tile was told the wrong bank.
   Fixed in the seed, and guarded: no stored monogram may be another
   institution's short code. The guard was proved by putting "SB" back.
2. **The "You own / You owe" line rendered as solid boxes.** `RichText` takes
   the style it is handed and nothing else, so a style with no `fontFamily`
   fell back to a font the render harness has no glyphs for. Fifteen
   assertions about that screen were green.
3. **The account kind pills stacked into ten full width rows.** A `Container`
   with an `alignment` and no width expands to fill everything it is offered.
   The same trap stacked the Reports period picker once before.

Only looking at the picture found 2 and 3, which is the whole reason the rule
exists. Both now have guards that do not need an eye: a source check that no
screen builds a bare `RichText`, and a layout measurement that the first two
kind pills share a line. Both were proved by reintroducing the bug.

The underlying cause of 2 was closed rather than the instance: every style in
`AppType` now names `PlusJakartaSans`, so a widget that REPLACES the ambient
text style instead of merging it, which `DropdownButton` also does, cannot
silently lose the typeface. The three dropdowns in the add sheet had exactly
that problem and were fixed by the same edit.

## Validation

- `flutter analyze`: no issues, Flutter 3.47.4 at the CI pin.
- `flutter test`: 374 passing, 0 failing.
- `dart format`: clean.
- Renders: 11 new, looked at in dark first, then light.
- 320dp at every view, and every tappable control measured against the 44dp
  floor.
- The write path has both halves: the money, and a journey that taps to
  Reports and to the Log sheet and asserts the new account is genuinely on
  screen there.

## Two founder decisions

Neither blocks anything. Both are in categories CLAUDE.md does not delegate.

### 1. Deleting an account

Not built, because it is user data deletion. What I would build, for a yes:

- Delete is offered only on the edit sheet, behind a confirmation that names
  the account and what it holds.
- An account with transactions, debts or bills pointing at it is NOT
  deletable. The sheet says how many entries are attached and offers to hide
  it instead, so the history stays readable.
- An account with nothing attached deletes outright.

The alternative is no delete at all and a "hide" that always keeps the record.
That is safer and slightly more cluttered. My recommendation is the first,
because an account added by mistake with nothing in it is the common case and
there is nothing to lose.

### 2. Storage

Nothing in `app/` persists. Every write says so on screen, and this screen is
where that starts to hurt: somebody who spends ten minutes entering their real
wallets loses all of it when they close the app.

This is the point where storage earns its place ahead of more screens. It
needs a decision on the shape before it is built, because the format is the
expensive thing to change later. I would put it after the Debt screen, which
is the last big read-only surface, and before anything else.

## Deferred, in writing

- `InvestmentsView`, the holdings tracker: units, cost basis, valuations,
  market data adapters, and `src/data/initialInvestments.ts`. 1,114 lines.
- The institution default in the add sheet is GCash regardless of kind, which
  reads oddly when adding a credit card. The prototype does the same. A
  kind-aware default is a small improvement for a later pass.
- `src/utils/logos.ts`: not ported, and not planned while the app is offline
  first.
- `lib/screens/placeholder/placeholder_screen.dart` is now unreferenced, every
  tab having a real screen. Kept rather than deleted, because deleting a file
  that exists on main is founder-gated and the Debt screen batch will want it.
