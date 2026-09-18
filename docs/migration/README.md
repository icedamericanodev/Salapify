# Prototype to Flutter migration

The Google AI Studio prototype in `src/` is the source of truth. This folder
tracks what has crossed over into the Flutter app in `app/`, with a picture of
every screen so it can be reviewed without a phone.

Founder direction, 2026-09-18: rebuild `app/` from zero against the prototype,
and migrate the tabs in the prototype's own order.

## Migration order

The prototype's tab order, finished one tab at a time including its modals.

| # | Tab | Prototype source | Status |
|---|-----|------------------|--------|
| 1 | Home | `Header`, `HeroPanel`, `BudgetPulseCard`, `QuickActions`, reminders banner, `DebtBeamCard`, `ComingUpCard`, `LatestTransactions`, `PanFloatingButton` | Built to match the prototype |
| 2 | Activity (Ledger) | `LedgerScreen`, `LogSheet`, `TransactionDetailModal` | Not started |
| 3 | Reports | `ReportsScreen` | Not started |
| 4 | Plan | `PlanScreen`, `AcademyView`, `CalculatorLibrary`, trackers | Not started |
| 5 | Accounts | `AccountsScreen`, `BankCard`, `InvestmentsView` | Not started |

Screens that hang off several tabs (Safe to Spend, Health Check, Pan chat,
Collaboration, the business guides) migrate with the tab that opens them.

## Screens

Dark first, because that is what the founder uses.

### Home

Rebuilt against the founder's own prototype screenshots, 2026-09-18. The card
order is App.tsx's: hero, budget pulse, quick actions, reminders, debts,
coming up, latest.

Full page, the whole scroll in one image:

| Gabi (dark) | Hapon (light) |
|---|---|
| ![Home full, Gabi](screens/home-gabi-full.png) | ![Home full, Hapon](screens/home-hapon-full.png) |

Phone sized, what actually fits on a 390dp screen:

| Gabi (dark) | Hapon (light) |
|---|---|
| ![Home, Gabi](screens/home-gabi.png) | ![Home, Hapon](screens/home-hapon.png) |

Rendered by `app/test/shots/screens_shot.dart`. To regenerate:

    cd app
    flutter test test/shots/screens_shot.dart --update-goldens

## How the money math is verified

Every ported calculation is locked to vectors produced by running the
prototype's OWN TypeScript, not by working the numbers out by hand:

    bun run <a script that imports src/utils/<engine>.ts>

Those figures become expectations in `app/test/engine/`. If a Dart figure ever
disagrees with the prototype, the port is wrong and the vector stands.

Covered so far: `safeToSpendEngine.ts`, locked by
`app/test/engine/safe_to_spend_golden_test.dart` across three vectors
(conservative, optimistic, and with recent spending).
