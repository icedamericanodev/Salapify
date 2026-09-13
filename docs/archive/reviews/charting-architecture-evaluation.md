# Charting architecture evaluation (fl_chart vs custom)

Date: 2026-08-12. Founder directed (Decision 4). Read-only evaluation plus the
first implementation step.

## The question

The founder asked, before dropping the currently-unused `fl_chart` dependency,
for a real evaluation against target architecture and product needs, and was
explicit: do not drop it just because it is unused, do not keep it just because
it is installed, and do not default to hand-drawn charts to shave a dependency.

## Evidence (current state)

- **fl_chart is dead today.** One import in the whole app, in
  `lib/widgets/salapify_chart.dart`, whose two widgets (`SalapifyLineChart`,
  `SalapifyDonutChart`) had zero callers. `fl_chart ^1.2.0` is pinned.
- **Every live chart is a hand-rolled `CustomPainter` or plain-widget bar**, all
  theme-aware (fed `Barako.*`) and `shouldRepaint`-guarded: the Income vs
  Spending trend (`insights.dart` `_TrendPainter`), the Sweldo Timeline balance
  line (`cashflow.dart` `_BalancePainter`), the Home sparkline
  (`timeline_sparkline.dart` `_SparkPainter`), plus split/category/progress
  bars in plain widgets.
- **There is no donut anywhere**, though the founder's design spec features a
  "Spending Overview" donut. **There is no categorical colour system**: category
  spending is monochrome (`Barako.primary` with alpha).
- Chart geometry is unit-tested (`chartgeom.dart` goldens); colour correctness
  rides on the WCAG palette sweep.

## fl_chart, verified via Context7 (`/imanneo/fl_chart`)

High reputation, actively maintained. Covers Line, Bar, **Pie/Donut**, Scatter,
Radar, and **Candlestick**, with built-in touch tooltips and implicit
animations. Donut is a `PieChart` with `centerSpaceRadius`; per-section colours;
`pieTouchData` for interaction.

## Assessment against the founder's criteria

| Criterion | fl_chart | Custom CustomPainter |
|---|---|---|
| Chart types needed now (line, bar, donut) | all, incl. donut out of the box | lines/bars done well; donut would be new hand work |
| Future investment charts (candlestick, portfolio) | candlestick supported | very expensive to hand-roll |
| Visual consistency with Salapify | good once wrapped in theme tokens + `ChartFrame` | perfect (already bespoke) |
| Interaction (touch tooltips, scrub) | built in | hand-coded per chart (the Timeline already does this well) |
| Maintainability | one library, less bespoke code for rich charts | more code, but total control |
| Performance | fine; CustomPaint under the hood | excellent, `shouldRepaint`-guarded |
| Accessibility | same pattern applies (ExcludeSemantics + a spoken sentence + printed legend) | same |
| Theming / tokens | must be wired to `Barako.*` (done in the wrapper) | native |
| Dependency cost | already present, no new cost | none |
| Package health / compat | healthy, pinned `^1.2.0`, compatible | n/a |

## Decision: keep fl_chart, put it to real use (fit-based hybrid)

Not "drop it," not "hand-draw everything." Use each tool where it fits:

- **fl_chart** carries the data-rich, part-to-whole, and future investment
  charts: the category **donut** now, and candlestick / portfolio-allocation
  later. This is exactly where a mature library earns its place and where
  hand-rolling is most expensive.
- **CustomPainter** stays the renderer for the bespoke, brand-defining, cheap
  line micro-charts already shipped (Sweldo Timeline, Home sparkline, the trend
  line). They are theme-perfect, tested, and lightweight; replacing them with
  fl_chart would risk the exact look for no gain. This preserves proven work
  (constitution: preserve first, replace only when justified).

The unused `SalapifyLineChart` wrapper was removed (the live line charts are the
CustomPainters, so a second line renderer was redundant). `SalapifyDonutChart`
was rehabilitated into the sanctioned donut: theme-tokened, hairline-stroked for
light-card visibility, accessible (hidden from the screen reader, one spoken
sentence, printed legend beside it).

## First implementation step (f4.07)

- Added `Barako.dataSeries`, a theme-invariant categorical "dopamine" palette
  (orange, teal, blue, green, violet, rose) with a distinctness and
  dark-surface-visibility guard (`data_palette_test.dart`).
- Built the category donut into the Reports "Where it went" section using
  fl_chart, with the existing category rows as its colour-matched legend (a
  colour dot per row, the bar recoloured to the category hue; the over-budget
  red flag preserved). Presentation only: the numbers still come from
  `categoryVsAverage`; no money math changed.

## Deferred (scoped follow-ups)

- Extend the dopamine palette into the Insights trend legend and the
  income-vs-expense semantics (income green `#22C55E`) where it reads well.
- Candlestick / portfolio charts when the investment domain is built (Phase 8),
  reusing this fl_chart layer.
