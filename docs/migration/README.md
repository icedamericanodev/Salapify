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

## Money engines

Ported into `app/lib/core/money/`, locked by vectors in `app/test/core/money/`.

Every vector was produced by RUNNING the prototype's own TypeScript under bun
against the prototype's own inputs, never by working the formula out by hand
and never by reading the Dart back. If a Dart figure ever disagrees with the
prototype, the port is wrong and the vector stands.

| Prototype source | Dart | Covers | Tests |
|---|---|---|---|
| `safeToSpendEngine.ts` | `safe_to_spend.dart` | Safe to Spend, reserves, buffer, cash runway, payday cadence | 11 |
| `philippineFinances.ts` | `ph_tax.dart` | SSS, PhilHealth, Pag-IBIG, TRAIN withholding, 13th month and its 90k exemption, freelance 8% vs graduated | 24 |
| `businessTaxes.ts` | `business_tax.dart` | Sole prop and partnership, 8% / OSD / itemized / RCIT, VAT vs percentage tax, BIR form list | 14 |
| `loanCalculators.ts` | `loan.dart` | Diminishing and flat add-on amortization, extra payments, balloons, DSR against the BSP bands | 18 |

### Not ported yet, and named rather than implied

- `financialTruthEngine.ts`: `runControlCenterScan`, `simulateDigitalTwin`,
  `analyzeScamRisk`. Roughly 600 lines. These drive the Health Check surface,
  which migrates with the screen that opens it.
- `loanCalculators.ts` product wrappers: Pag-IBIG, bank housing, car, salary,
  personal and business loans, debt consolidation, credit card payoff, and the
  avalanche and snowball strategy simulator. All of them sit on top of
  `calculateAmortization`, which IS ported and locked, so they are preset
  plumbing rather than new math.
- `philippineFinances.ts` helpers: remittance fee estimation, cash
  denomination counting, and the Taglish reminder text.

### Quirks preserved on purpose

Three places where the prototype does something surprising and the port keeps
it, because changing a number nobody decided to change is the worse error:

1. A **balloon payment overruns the stated term.** 900,000 at 8% over 36
   months with a 200,000 balloon runs 45 months, because the schedule keeps
   amortising to zero instead of stopping and charging the balloon.
2. **VAT contributes nothing.** A VAT registered business shows zero business
   tax, because the engine treats VAT as pure pass-through. That is a
   cash-flow view, not a filing figure.
3. **The 13th month gross is rounded in one function and not the other.**
   `calculateEmployeeTaxDeductions` rounds it, `calculate13thMonthPay` does
   not. Making them agree would move a figure on a screen.

## Brand mark

The founder supplied the logo on 2026-09-18: a ribbon "S" wrapped around a peso
coin, with a small bar chart, on a teal and navy plate. The artwork is theirs
and is unchanged. Only the COLOUR was brought onto the Salapify palette, since
teal sits on the opposite side of the wheel from Hapon and Gabi.

Recoloured by mapping LUMINANCE onto real palette colours rather than tinting.
The mark has three tonal layers (dark plate, mid ghost strokes, near-white
ribbons) and a tint flattens them into mud; a ramp keeps every offset stroke,
every anti-aliased edge, and the plate's own diagonal gradient.

| | |
|---|---|
| Original, then rust, Gabi and hero variants | ![variants](screens/logo-variants.png) |
| The shipped icon on both theme backgrounds | ![on both themes](screens/logo-on-both-themes.png) |

**Rust ships.** It carries Hapon's accent `#B03C09`, and it holds the most
contrast between plate and ribbon, which is what decides whether an icon still
reads at 48dp. The Gabi variant is the closest runner-up. The hero variant is
the weakest: cream ribbons on amber lose contrast at small sizes.

Where it is used:

    android/.../mipmap-*/ic_launcher.png     the launcher icon, five densities
    android/.../drawable-*/launch_image.png  the launch screen, five densities
    app/assets/brand/salapify_logo.png       in app, currently the Home header

The launch screen also stopped being white. It now uses Salapify's own
background, resolved per theme through `values/colors.xml` and
`values-night/colors.xml`, so opening the app at night no longer starts with a
white flash.
