# Pan on the empty states: real renders

Real renders from `app/test/shots/screens_shot.dart` (`panEmptyShots`), the
app on the founder's emulator, on a book with the example data cleared. They
replace the HTML reference pictures in `docs/revamp/mockups/pan/` as the
evidence. Review note: [../pan-character.md](../pan-character.md).

Each shot is taken after the idle has finished, so Pan is shown at rest.

## Every screen, dark (Gabi) and light (Hapon)

| Screen | Pan | Dark | Light |
|---|---|---|---|
| Home, first run | wave | <img src="pan_home_gabi.png" width="220"> | <img src="pan_home_hapon.png" width="220"> |
| Activity | sleep | <img src="pan_activity_gabi.png" width="220"> | <img src="pan_activity_hapon.png" width="220"> |
| Plan, Budgets | idea | <img src="pan_plan_budgets_gabi.png" width="220"> | <img src="pan_plan_budgets_hapon.png" width="220"> |
| Plan, Goals | idea | <img src="pan_plan_goals_gabi.png" width="220"> | <img src="pan_plan_goals_hapon.png" width="220"> |
| Accounts | coin | <img src="pan_accounts_gabi.png" width="220"> | <img src="pan_accounts_hapon.png" width="220"> |
| Reports, Performance | thinking | <img src="pan_reports_gabi.png" width="220"> | <img src="pan_reports_hapon.png" width="220"> |
| Debts, You owe | calm | <img src="pan_debt_gabi.png" width="220"> | <img src="pan_debt_hapon.png" width="220"> |

## The Home entrance, frozen

Rendered by pumping exactly 0, 320, 600, 760, 1080 and 2200 ms, dark.

<img src="frame_strip.png" width="900">

The target, from `docs/revamp/mockups/pan/motion-frames-home.png`:

<img src="../../revamp/mockups/pan/motion-frames-home.png" width="900">

What differs on purpose: in the target the whole page fades in from black
at 0 ms because it is a page demo. In the app the screen is already there, so
at 0 ms you see the card with only Pan's drawn shadow in it, which is the
target's 320 ms frame. From 600 ms on the two match: Pan mid-pop with the title
fading in, the text and button rising at 760, settled at 1080, and the button's
ring plus a sparkle at 2200.

## Add a budget, and Pan on Ask Pan (founder direction 2026-10-08)

"yes build add a budget, keep ask pan" and "can we also put mascot on it?"

Left to right: the empty Budgets card now with its button, the new sheet
(dark), the Budgets list with "Add a budget" under it, the sheet (light). The
category emoji draw as boxes here only because this machine has no emoji
font; they show on the phone.

<img src="add_budget.png" width="900">

Ask Pan with Pan's face: the floating button (dark), the Ask Pan card on
Home, and the floating button (light).

<img src="ask_pan.png" width="700">
