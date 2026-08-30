# Salapify design + UX overhaul plan

Founder direction (2026): "thinking about building Salapify from scratch again,
not contented, looks like it has so many bugs and the UI/UX is not greatly
designed." Founder chose, via AskUserQuestion: **Design & UX overhaul, keep the
brain** (redesign look and flows on top of the existing money engine, tests, and
delivery pipeline; no third rebuild).

Three independent expert passes ran over the LIVE Flutter app (flutter/lib):
a bug hunt (qa-tester), a competitor UX benchmark (riley-competitor-ux), and a
craft/design-system critique (flutter-ux-craftsman). They converge.

## Headline verdict: do NOT rebuild

All three passes independently concluded the FOUNDATION is genuinely strong, not
a buggy mess:
- The money engines, store write paths, backup/restore, and formatters are
  "unusually careful": every `.round()`/`.toInt()` is non-finite guarded,
  divisions guard denominators, the write layer is a serialized rollback queue
  with a pre-import undo snapshot. The bug hunt could not produce a reproducible
  crash in the paths it reviewed.
- The design system (Barako tokens, the RN-anchored type scale, IBM Plex ledger
  face, four WCAG-AA-checked themes, the bank_card visuals) is "disciplined and
  genuinely premium in places."
- The information architecture (four-tab spine, state-aware Home ordering,
  decision-first Insights) is "more thoughtful than most competitors."

A from-scratch rebuild would spend months re-earning correctness the app already
has, and the same bug classes would return before parity. The app FEELS buggy
and unpolished for a small, specific, fixable set of reasons.

## What is actually wrong (two buckets)

### Bucket A: real bugs, almost all in the multi-currency (foreign account) feature

This feature was added on top of the golden-locked RN money engines and is not
threaded consistently through display and transfers. This is the likeliest
source of the "so many bugs" feeling.

- A1 (WRONG-NUMBER, money integrity, HIGH): a cross-currency transfer changes
  net worth. `transfers.dart:191-207` checks the typed amount against the raw
  foreign balance and moves it 1:1; net worth (which FX-converts) then drifts.
  Breaks the app's own "a transfer between your own accounts conserves net
  worth" invariant. Founder-gated (money meaning). Fix: block or FX-convert a
  cross-currency transfer.
- A2 (WRONG-LABEL, HIGH-visible): foreign balances wear the base peso sign.
  `formatMoney` always uses the base symbol, so a USD account shows "₱100" on
  the detail and transfer chip while net worth counts it as ~₱5,600. A
  `formatForeign`/`currencySymbol` helper already exists and is used on Home but
  not for account balances. Fix: format a non-base balance with its own symbol.
- A3 (minor label): the FX conversion notice can call a hand-entered rate a
  "stale download" (ordering bug in `fx_totals.dart:146-150`).
- A4 (minor data): restored utang payment fallback ids collide across
  receivables (`backup.dart:781`, counter reset inside the per-receivable map).
- A5 (minor input): the transfer amount field accepts hex/octal literals via
  paste (`jsNumber`, kept for RN parity; known footgun).

Everything else the bug hunt checked (formatters, projections, recurring,
import/restore, CSV, chart painters) was found safe and guarded.

### Bucket B: "feels flat, not premium", almost all design-SYSTEM inconsistency

The tokens are good; they are applied inconsistently, so the eye never gets a
clean hierarchy. Both UX passes independently flagged the same causes:

- B1: no card primitive. The `Card > Padding > Kicker > content` pattern is
  hand-typed on nearly every card with different interior padding (16/14/18/20)
  and kicker gaps (4/6/8/10), so cards visibly breathe differently on one
  scroll. THE highest-leverage fix.
- B2: section labels look identical to card labels (both `kickerStyle`, 12/w600),
  so a 10-card screen (Insights) reads as one undifferentiated stack with no
  grouping. Need a distinct section-title tier.
- B3: hero numbers do not animate. `CountUpText` is built, accessible, pure
  Dart, and used in exactly one non-hero place; none of the five money heroes
  roll up. Cheapest "feels alive" win.
- B4: Home crowns the wrong number. Net worth draws at 42px hero; Safe-to-Spend,
  "the question the screen exists to answer," draws at 34px. The calm number is
  bigger than the daily-decision number. (IA/product call to reorder.)
- B5: off-ladder spacing (43 raw 14/18 literals) and three near-identical tint
  disc alphas (0.12/0.14/0.15); no between-section rhythm.
- B6: the Debts screen is the weakest surface for this audience: a hand-rolled
  empty state (no icon/Pan/way-forward), raw `ChoiceChip`s instead of the shared
  `Segmented`/`SalapifyChoiceChip` (misses the selection haptic), a plain hero,
  and one card-per-row instead of the rows-in-one-card physics the rest of the
  app moved to.
- B7: Activity and other lists lean on text where Revolut/GCash lean on a leading
  category/account glyph; adding one small glyph disc per row lifts the ledger to
  "premium tracker" (the id is already resolved).
- B8: Insights defers the category donut (the most-wanted "where did it go" view)
  to Reports; the `SalapifyDonutChart` widget and palette already exist.

### The one structural gap both UX passes named

- C1: the log sheet does NOT capture category at log time (reserved as
  "Planned, not yet built" in entry_form.dart). Category is inferred later by
  label-match, which starves every downstream breakdown (this is why Insights
  has to route category to Reports). Highest-value single change, but it is a
  data-write change: founder-gated (data/migration).

## Proposed phasing

Phase 0, real bugs (ship first, restores trust): A2 foreign-balance labels
(OTA, presentation) and A1 cross-currency transfer (money-meaning, founder-gated,
needs golden vectors + a journey-test invariant). A3/A4/A5 folded in as small
fixes. This is the honest answer to "so many bugs".

Phase 1, design-system lift (OTA, no product forks, lifts every screen at once):
B1 SalapifyCard primitive, B2 section-title tier, B3 hero roll-ups, B5 spacing
tokens + sweep. Plus the two clean Debts bug-fixes (empty state, raw chips).

Phase 2, per-screen polish (OTA): B7 Activity glyphs, B8 Insights donut + section
structure, B6 Debts hero + list physics, Accounts roll-up, log-sheet toggle, and
the kicker-density reduction.

Founder-gated decisions to settle before touching (do not decide unilaterally):
- C1 category at log time (data write + migration).
- B4 Home hero reordering (information architecture / product).
- Hero shadow on the one raised card per screen (changes the documented
  borders-only surface-model rule).
- Fraunces font: two bundled TTFs no live code draws; keep-and-deploy on non-money
  display type, or drop on the next native bump (base-APK decision).
- Budget model: YNAB-style per-category remaining vs the current tracker model
  (product fork).

## Guardrails (unchanged)

Every phase keeps the money engine, schema, and the 3,115 tests green; each visual
change is rendered dark and looked at and the picture sent to the founder; nothing
merges without the QA gate and the delivery-log row; no em/en dashes; small tested
steps; enhance, never regress.
