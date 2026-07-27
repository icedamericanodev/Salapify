# Flutter UI Phase 1: navigation and Home usability

Written 2026-07-27, before any code changed, as the workflow requires.

## Context

Salapify's Flutter rebuild has strong foundations: a tested money engine, eight
AA-checked palettes, spacing and radius tokens, and a render harness. What it
does not have is a navigation shape or a Home hierarchy that were ever designed
as a whole. Both grew one card and one tab at a time.

Two concrete symptoms:

**Six bottom destinations, one of which is a menu.** A bottom bar is for places
you go often. Menu is a drawer of everything else, and it was taking a sixth of
the most valuable strip on the screen. The bar's own theme comment admits the
cost: `height: 68` and `fontSize: 10` were both shrunk below Material's
defaults specifically to fit six labels.

**Home answers its main question below the vertical midpoint.** The coach's
check-in card always renders, because `weeklyCheckIn` falls back to a cheerful
"You are on track this week" when nothing is wrong. So a user in perfect
financial health pays 180 to 210 logical pixels of good news before reaching
the number they opened the app for. Measured on a 360x800 device, Your Number's
top edge sits at roughly 325 to 340, and the figure itself lands near 50 percent
of the viewport. On payday the ritual card pushes it to about 530, at the fold.

Nothing here changes money math, storage, migrations, or transaction integrity.
This is layout, ordering, and reachability.

## Founder decisions taken during planning

1. **Utang and Debts merge into one tab**, with a segmented control. **"I owe"
   is the default** and holds the Debts content; "Owed to me" holds today's
   receivables. Today the smaller screen owns a bottom tab while the richer one
   (strategy switch, debt-free projection, interest cost) is buried in Menu.
2. **Home keeps the SALAPIFY wordmark** and gains the Menu action beside search.
   The other four primary screens adopt the shared header.
3. **The payday ritual sits above Your Number only until the salary is logged**,
   and below it afterwards.
4. **The merge is the last commit**, explicitly droppable if it runs long.

## Current hierarchy

### Navigation

`main.dart:87` holds `int tab`. `main.dart:124` is a root `Scaffold` whose body
is a `switch (tab)` returning one screen. The old screen's `State` is **disposed
on every tab change**, so Activity's search text and filter chip reset, and every
scroll position is lost. Six destinations: Home, Budget, History, Utang,
Insights, Menu, using raw `Icons.*` rather than the app's own
`salapify_icon.dart` name indirection.

Each of the six screens returns **its own** `Scaffold` and **its own**
`SafeArea`, nested inside the root one. Two carry a FAB: Home's "Log" and
Utang's "New utang".

### Home, in render order

Header, greeting, then: load error, payday ritual, **Pan check-in**, Your Number
(or the days countdown as its `else if`), bills, net worth, then a welded
`if (!hasStarted) ... else ...` block holding MY MONEY and THIS MONTH.

## Proposed hierarchy

### Navigation

Five destinations: **Home, Activity, Budget, Utang, Insights**. Menu becomes a
header action, reachable in one tap from all five. One root shell owns the nav
bar and a single `FloatingActionButton.extended` labelled **Log**, wired to the
existing `showLogSheet`. The five screens lose their Scaffold, SafeArea and FAB
and become plain bodies. This **removes** a nesting level rather than adding one.

Destinations are mounted in a **lazy `IndexedStack`**: only Home builds on the
first frame, and a tab is added on first visit and never unmounted after. State
and scroll position then survive by construction.

### Home, in decision order

```
header + greeting
payday ritual            if (ritual.isPayday && !ritual.salaryLogged)
urgent check-in          if (checkIn.tone == 'urgent')
YOUR NUMBER              if (cycle.show)
  or DAYS TO PAYDAY      else if (hasStarted && dues['daysLeft'] is int)
bills before payday      if (hasStarted && bills.isNotEmpty)
payday ritual            if (ritual.isPayday && ritual.salaryLogged)
normal check-in          if (checkIn.tone != 'urgent')
this month  /  my money  /  net worth        (inside the existing else branch)
```

**Why demoting the check-in cannot suppress a warning.** The coach's only
`urgent` candidate is `crunch`, fired by `liquid > 0 && available <= 0`
(`coach.dart:158`). `cycleStatus` hides Your Number on exactly that condition
(`cycle.dart:399`). Both read the same `safeToSpend` call with the same clock.
So an urgent check-in and a visible Your Number are already mutually exclusive,
and the urgent branch in practice sits above `_daysToPaydayCard`, not above Your
Number. That is worth writing in the code comment, or a later reader deletes the
guard as dead.

## Affected files

| Area | Files |
|---|---|
| Shell and nav | `lib/main.dart`, new `lib/screens/shell.dart` |
| Destinations lose Scaffold/SafeArea/FAB | `overview.dart`, `budget.dart`, `history.dart`, `utang.dart`, `insights.dart` (two Scaffolds) |
| Shared header | `lib/widgets/screen_header.dart` gains `leading`, `onMenu`, and a shared `MenuAction` |
| Icons | `lib/widgets/salapify_icon.dart` gains the five destination names plus `menu` |
| Segmented control | new `lib/widgets/segmented.dart`, extracted from `appearance.dart` |
| Home order and duplication | `overview.dart`, `widgets/bills_before_payday.dart` |
| The merge | new `lib/screens/money.dart`, `debts.dart` and `utang.dart` split into view + pushed wrapper |
| Test seam | new `test/support/app_harness.dart`, plus 37 migrated files |

## Risks

**1. The test suite blast radius is 24 files, not 44.** They reach Menu by
`tap(find.text('Menu'))`, which stops matching when Menu leaves the bottom bar.

**Corrected during planning, with a test.** Both this plan and the design agent
first claimed a second, worse failure: that mounting all five destinations in an
`IndexedStack` would leave hidden screens findable, so `find.text('Insights')`
would match twice and `find.byType(Scrollable).first` would silently target Home
instead of the screen under test. The reasoning was that `IndexedStack` hides
children with `Visibility(maintainSize: true)` rather than `Offstage`, and
`skipOffstage` only skips the latter.

That is wrong on Flutter 3.44.6, and a test proved it before any of it was
built. `IndexedStack` ships its own element which overrides the onstage walk
directly:

```dart
class _IndexedStackElement extends MultiChildRenderObjectElement {
  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final int? index = widget.index;
    if (index != null && children.isNotEmpty) {
      visitor(children.elementAt(index));
    }
  }
}
```

So inactive destinations are invisible to every default finder, and the 13
extra files do not break. `test/nav_ambiguity_test.dart` pins this, because it
is an assumption imported from the SDK rather than owned by this app: if a
future Flutter release changes it, dozens of tests start silently targeting the
wrong screen and the failures will point everywhere except at the cause.

Mitigation for the real 24: **one seam**, `test/support/app_harness.dart`. Nav
finders scope to `find.byType(NavigationBar)` and scrolls scope to the screen
under test. Scoping is kept even though it is not strictly required today,
because it costs nothing and it is what makes the guard above meaningful.

**2. Naive `IndexedStack` runs every engine on cold start.** Insights alone
makes eleven engine calls in its build. Lazy mounting fixes it in about six
lines and is not optional on a low-end Android.

**3. "One tap to Menu" is not met by an in-list header**, because `ScreenHeader`
scrolls away with the content. The fix is to move the four screens to
`Column [header, Expanded(ListView)]`, the shape `history.dart` already uses.
Cost: those screens lose about 60 logical pixels of content height. The
alternative is to restate the requirement honestly as "one tap from the top".

**4. Moving "New utang" and "Add debt" off a FAB is a genuine discoverability
regression.** A FAB is the strongest create affordance Android has. Mitigated,
not eliminated, by a filled `+` button in the header and by empty-state copy
that names it. The trade is one rare action demoted so one frequent action
becomes universal.

**5. The merged tab mounts two scrollables at once**, which throws under a
single `PrimaryScrollController`. It must own explicit controllers. This is the
sharpest edge in the phase and the reason the merge goes last.

**6. Not a risk, verified and dismissed:** the ScaffoldMessenger. Snackbars are
already hosted by the root Scaffold (`_isRoot`, `scaffold.dart:242`), so
History's Undo already survives a tab switch today. Removing the inner Scaffolds
changes nothing. A test will lock it so nobody "fixes" it later.

## Confirmation: no financial or persistence logic changes

Home reads seven engine functions and writes none. The only arithmetic in
`overview.dart` is `s.liquid - s.available`, an algebraic identity for
`committed`, plus two roundings for display. The duplication fix **removes** a
render of an existing value; it computes nothing new. No file under `lib/money/`
or `lib/data/` is modified in any commit of this phase.

## Test plan

New: `tab_state_test`, `scroll_to_top_test`, `home_order_test` (the first
positional Home test in the repo), `home_no_duplicate_money_test`,
`money_tab_test`, `snackbar_survives_tab_switch_test`, `nav_ambiguity_test`,
`segmented_test`, `a11y_test`.

The accessibility suite is new ground: **no test in the repo has ever used any
Flutter accessibility guideline.** Expected first failures, from reading the
code: `menu.dart:1204` (`minimumSize: Size(0, 40)` with `shrinkWrap`),
`overview.dart:1040` (36), `log_sheet.dart:313` (`VisualDensity.compact`), and
`history.dart:242` (a query-clear `IconButton` with no tooltip, so no label).
The least certain and therefore first to write: Activity's filter chips, where
Material 3 *should* pad to 48 but nothing in this app verifies it.

Every new guard is proven by breaking the code first and pasting the failure
line into the commit message, per the house rule. For the Home order that means
both halves: an urgent check-in must appear above the countdown, **and** a
positive one must not appear above Your Number.

Renders to look at before merging, dark first: the shell at each destination,
Home in the reordered states, both merged segments, plus a 320dp frame and a
textScale 2.0 frame.

## Commit order

1. One navigation seam for the widget suite (test only, green on today's code)
2. Name the bottom destinations instead of numbering them
3. Icon names for the bottom bar and the menu action
4. Extract the segmented control, at 48 with a non-colour selected state
5. The root shell owns the nav bar and one Log button (still six tabs)
6. Menu moves from the bottom bar to a header action (now five tabs)
7. History becomes Activity (label only; the class rename is separate)
8. One committed figure on Home, not two
9. Home reads in decision order
10. Three presentation levels
11. The app meets the tap-target, label and contrast guidelines
12. One Utang tab, what you owe first  **(droppable)**

Each is independently green under `flutter analyze` (zero infos),
`flutter test`, and the render harness. `updateStamp` bumps on every push.
