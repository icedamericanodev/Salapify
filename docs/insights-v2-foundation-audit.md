# Insights v2 — foundation audit

## Scope

This PR establishes reusable chart, motion, and loading primitives. It deliberately does **not** replace `InsightsScreen` yet.

## What already works and must survive

- `flutter/lib/screens/insights.dart` is a presentation/decision screen over existing ledger and money engines. Its header comment explicitly prohibits inventing figures in the screen.
- Existing analytics include safe-to-spend, health score, six-month trend, top categories, emergency runway, debt projections, goals, commitment load, and insight feed behavior.
- `ChartFrame` already owns shared chart furniture: kicker, context, legend, caption/footer, and trailing controls. The new chart widgets are renderers that can sit inside this existing frame rather than replacing it.
- Theme colors are dynamic getters over the active Salapify palette. New widgets read `Barako` during build and do not freeze theme colors in const UI.
- Typography already has semantic roles and tabular money figures. New widgets reuse `AppText`.
- Insights already distinguishes unreadable data from genuinely empty data. The redesign must preserve this honesty.

## Dependencies

Added:

- `fl_chart` — chart rendering only; financial computation stays in existing engines.
- `animations` — restrained state transitions with reduced-motion support.
- `flutter_spinkit` — compact progress feedback only.

Not added:

- `getwidget` — rejected for the foundation. Salapify already has a mature shared component system; adopting a second widget system without a demonstrated gap would increase visual and maintenance drift.

These selected packages are Dart/Flutter dependencies and this PR does not intentionally add Android/iOS source, manifest, resources, or assets. Delivery compatibility still must be proven by the repository's normal Shorebird/build workflow before claiming OTA delivery.

## New primitives

### `SalapifyLineChart`

- accepts precomputed chart points
- never computes accounting values
- supports a second comparable series
- uses the active Salapify palette
- touch tooltip support
- reduced-motion aware animation
- one semantic summary supplied by the caller

### `SalapifyDonutChart`

- accepts precomputed slices
- intended as enhancement beside printed amounts/percentages
- reduced-motion aware animation
- semantic summary supplied by caller

### `SalapifyFadeThrough`

- shared state transition using the Flutter `animations` package
- becomes static when reduced motion is requested

### `SalapifyUpdatingIndicator`

- compact SpinKit feedback
- intended for long-enough refresh work, not full-screen blocking
- live-region semantic label

## Next PR

Migrate the Insights Overview onto these primitives without changing the canonical financial engines. Target: summary hierarchy, real cash-flow chart, expense composition, period controls, and existing honest empty/error states.
