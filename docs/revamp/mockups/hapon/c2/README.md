# C2, the Accounts screen

Phase 3 step 3. Question 2 of the five in `01-vision.md`: what do I own and owe?

| Gabi (dark) | Hapon (light) |
|---|---|
| ![Gabi](gabi-accounts.png) | ![Hapon](hapon-accounts.png) |

The screen leads with net worth and then answers "where is it" by kind. That
order is the point: a list of balances is a filing cabinet, one number with the
list under it is an answer.

Every figure comes from the golden locked engine. `netWorthParts` produces the
hero and its sentence, `resolveKind` decides each row's section,
`trackedRemaining` totals both directions of debt, and `initialsFor` makes the
monogram. The screen groups and paints and does no arithmetic on money.

It reconciles, which is the only way to read it honestly:

    assets       53,760.50   =  8,410.50 + 42,300 + 1,250 + 1,800 receivable
    liabilities  10,120.00   =  4,120 credit card + 6,000 loan
    net worth    43,640.50

## Four defects the first render caught, that 370 green tests did not

None of these was a screen bug. All four were the screen faithfully drawing
data that had been shaped wrong, which is exactly the class of thing a test
written from the same wrong assumption cannot see.

**A credit card was counted as cash.** `account_taxonomy.dart` puts credit,
loans and installments in `AccountStore.debts`, so a card filed under
`accounts` derives to cash on hand. It sat in "Cash and e-wallets", took no
utilisation bar, and was ADDED to assets instead of subtracted. The screen said
the founder was ₱8,240 better off than they were.

**A bank was labelled "Cash on hand".** `_kindToSubtype` maps exactly four
kinds: cash, savings, checking, ewallet. There is no `bank`, and anything
unknown derives to cash on hand, silently.

**A receivable counted as zero.** Receivables key on `amount` minus payments
and only count when `cashLeg` is true. The fixture wrote `remaining`, which
`trackedRemaining` does not read, so assets were ₱1,800 short with every test
still green.

**A loan appeared twice.** Once as its own section and once inside "You owe",
on the same screen, which is how somebody comes to believe they owe it twice.
`04-screens.md` names the kind sections exactly, "Cash and e-wallets, Bank,
Credit", so loans and installments roll into the Debt summary instead. Credit
cards keep a row on purpose: they are the only liability with a limit, so the
only one with a utilisation bar worth showing.

## What guards it now

`app/test/features/accounts_test.dart`, eleven cases, one per defect above plus
the edges. The double-count guard was proven by breaking it: forcing loans back
into their own section reddens two tests, one of them naming the reason.

    Expected: not contains 'loans'
