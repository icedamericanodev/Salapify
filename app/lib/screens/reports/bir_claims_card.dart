import 'package:flutter/material.dart';

import '../../core/money/bir_claims.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../models/models.dart';

/// The BIR receipts hub, on Reports.
///
/// Founder spec, 2026-09-20, feature 4. Three figures and a toggle.
///
/// ## Why the tax saving is not the headline
///
/// The spec's second metric is "Estimated BIR Tax Shield (25% rate)". That
/// number is zero for anybody on the 8 percent election, which has no
/// itemised deductions at all, and for anybody on the optional standard
/// deduction, which is 40 percent of gross whatever the receipts say. Even on
/// graduated and itemised, 25 percent is one bracket of six, and somebody
/// under the 250,000 exemption saves nothing.
///
/// So the figures that are TRUE for everybody lead: what you have marked, and
/// how much of it you could actually defend. The saving sits underneath, only
/// after the person picks their own bracket, and says out loud what it
/// assumes. A tax figure nobody can act on is worse than no tax figure,
/// because somebody plans around it.
class BirClaimsCard extends StatefulWidget {
  const BirClaimsCard({
    super.key,
    required this.palette,
    required this.transactions,
    this.onFilterChanged,
    this.filterOn = false,
  });

  final Palette palette;

  /// ALREADY filtered to the active period by the caller, so this card and
  /// the figures above it can never disagree about which month they describe.
  final List<Transaction> transactions;

  final ValueChanged<bool>? onFilterChanged;
  final bool filterOn;

  @override
  State<BirClaimsCard> createState() => _BirClaimsCardState();
}

class _BirClaimsCardState extends State<BirClaimsCard> {
  /// Null until the person chooses. No default, on purpose: a default rate is
  /// how a made-up tax saving reaches a screen with a peso sign in front of
  /// it, and this one would be on the screen from the first visit.
  double? _rate;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final BirClaimSummary s = summariseClaims(widget.transactions);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('CLAIMABLE EXPENSES', style: AppType.kicker(p)),
              ),
              InfoDot(
                color: p.textMuted,
                semanticLabel: 'What makes an expense claimable',
                onTap: () =>
                    InfoSheet.show(context, p, InfoTopic.claimableExpenses),
              ),
            ],
          ),
          if (!s.any)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                // Nothing marked is not a failure and does not get a zero. A
                // zero is a measurement, and a progress bar at nought on the
                // first visit reads as something already going wrong.
                'Nothing marked as claimable this period. Tick a business '
                'expense when you log it, or scan its receipt, and it '
                'appears here.',
                style: AppType.body(p),
              ),
            )
          else ...<Widget>[
            const SizedBox(height: Spacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatPeso(s.totalClaimable),
                style: AppType.hero(p).copyWith(color: p.textPrimary),
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              '${s.count} ${s.count == 1 ? 'entry' : 'entries'} marked.',
              style: AppType.caption(p),
            ),
            const SizedBox(height: Spacing.md),
            _Row(
              palette: p,
              label: 'With a receipt or reference',
              value:
                  '${s.substantiated} · ${formatPeso(s.substantiatedAmount)}',
              tone: p.positive,
            ),
            _Row(
              palette: p,
              label: 'With nothing behind it yet',
              value: '${s.unsupported} · ${formatPeso(s.unsupportedAmount)}',
              tone: s.unsupported > 0 ? p.warning : p.textPrimary,
            ),
            if (s.unsupported > 0)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(
                  // The one line that stops a wrong conclusion, which is the
                  // exception to putting teaching behind the dot. Without it
                  // the big figure at the top reads as the amount you can
                  // claim, and the difference between the two numbers is the
                  // part that gets disallowed.
                  'A claim needs the official receipt behind it. The '
                  '${formatPeso(s.unsupportedAmount)} above is marked but not '
                  'yet backed up.',
                  style: AppType.caption(p),
                ),
              ),
            const SizedBox(height: Spacing.md),
            _ShieldSection(
              palette: p,
              summary: s,
              rate: _rate,
              onRate: (double? r) => setState(() => _rate = r),
            ),
            if (widget.onFilterChanged != null) ...<Widget>[
              const SizedBox(height: Spacing.md),
              _FilterPill(
                palette: p,
                on: widget.filterOn,
                count: s.count,
                onTap: () => widget.onFilterChanged!(!widget.filterOn),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The saving, and everything it depends on, said out loud.
class _ShieldSection extends StatelessWidget {
  const _ShieldSection({
    required this.palette,
    required this.summary,
    required this.rate,
    required this.onRate,
  });

  final Palette palette;
  final BirClaimSummary summary;
  final double? rate;
  final ValueChanged<double?> onRate;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;

    if (rate == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'What this is worth depends on your band',
            style: AppType.kicker(p),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Pick the income tax band you are in and Salapify will work out '
            'what these receipts could take off your bill.',
            style: AppType.caption(p),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: <Widget>[
              for (final ({String label, double rate}) b in graduatedBrackets)
                _BandChip(
                  palette: p,
                  label: b.label,
                  onTap: () => onRate(b.rate),
                ),
            ],
          ),
        ],
      );
    }

    final double shield = summary.taxShieldAt(rate!);
    final String pct = (rate! * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                rate == 0
                    ? 'In your band, these take nothing off'
                    : 'At $pct%, this could take off',
                style: AppType.kicker(p),
              ),
            ),
            GestureDetector(
              onTap: () => onRate(null),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                alignment: Alignment.centerRight,
                child: Text(
                  'Change',
                  style: AppType.caption(p).copyWith(color: p.accent),
                ),
              ),
            ),
          ],
        ),
        Text(
          formatPeso(shield),
          style: AppType.title(
            p,
          ).copyWith(color: shield > 0 ? p.positive : p.textPrimary),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          // EVERY ASSUMPTION, on the screen, next to the figure. This is the
          // sentence that keeps the number honest, and it is the reason the
          // spec's flat 25 percent was not ported: under the 8 percent
          // election these receipts are worth nothing at all, and somebody
          // who elected it would otherwise be told a quarter of them is
          // coming back.
          rate == 0
              ? 'Income up to ₱250,000 pays no income tax, so there is '
                    'nothing for a deduction to reduce. The records are still '
                    'worth keeping.'
              : 'Only counts the ${formatPeso(summary.substantiatedAmount)} '
                    'with a receipt behind it, and only if you file on the '
                    'graduated rates with itemised deductions. On the 8% '
                    'election or the 40% standard deduction, these receipts '
                    'change nothing.',
          style: AppType.caption(p),
        ),
      ],
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: Container(
        // Vertical padding, NOT a fixed height with an alignment. A Container
        // with an alignment and no width fills everything it is offered, and
        // that has turned a row of chips into a stack of full width bars
        // seven times in this repository.
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: palette.border),
        ),
        child: Text(label, style: AppType.caption(palette)),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.palette,
    required this.on,
    required this.count,
    required this.onTap,
  });

  final Palette palette;
  final bool on;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: on
          ? 'Showing only claimable receipts. Tap to show everything.'
          : 'Show only claimable receipts, $count of them.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: on ? palette.accent : palette.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: on ? palette.accent : palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                on ? Icons.filter_alt : Icons.filter_alt_outlined,
                size: 16,
                color: on ? palette.onAccent : palette.textMuted,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                // The word AND the state, never colour alone.
                on
                    ? 'Showing claimable only ($count)'
                    : 'Filter claimable receipts ($count)',
                style: AppType.caption(palette).copyWith(
                  fontWeight: FontWeight.w800,
                  color: on ? palette.onAccent : palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.palette,
    required this.label,
    required this.value,
    required this.tone,
  });

  final Palette palette;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppType.caption(palette))),
          Text(
            value,
            style: AppType.caption(
              palette,
            ).copyWith(fontWeight: FontWeight.w800, color: tone),
          ),
        ],
      ),
    );
  }
}
