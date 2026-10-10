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

  /// Whether the band picker is OPEN. Closed by default.
  ///
  /// Founder direction, 2026-10-07: screens are "too wordy and the users may
  /// feel flooded and overwhelmed". Before a band was chosen this card showed
  /// a kicker, a two-line prompt and six band chips, about 49 words, which
  /// was more than the rest of the card put together, on every visit to
  /// anyone with something marked. They are now one tap away.
  ///
  /// SESSION ONLY, like [_rate]. Remembering the band would be a stored data
  /// change, which is founder gated, and for a figure about somebody's tax it
  /// is better asked than assumed anyway.
  bool _picking = false;

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
                //
                // THE SECOND SENTENCE WAS FALSE and is replaced, not trimmed.
                // It said "Tick a business expense when you log it", and the
                // Log sheet has no such control: isTaxDeductible is set only
                // by the scan receipt sheet's switch and by OCR. Filing under
                // the business category genuinely works, because isClaimable
                // accepts that category on its own. The other two routes are
                // behind the dot.
                'Nothing marked as claimable this period. File business '
                'costs under Business & Freelance Ops to see them here.',
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
                  //
                  // "AN INVOICE OR RECEIPT", not "the official receipt". The
                  // Ease of Paying Taxes Act (RA 11976, effective 22 January
                  // 2024) and RR 7-2024 made the invoice the primary document
                  // for goods and services alike; the official receipt is now
                  // only supplementary. The old wording named the document
                  // that is no longer the main one. Flagged by a tax
                  // professional review, 2026-10-07.
                  'A claim needs an invoice or receipt behind it. The '
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
              picking: _picking,
              // Choosing a band closes the picker; the figure replaces it.
              onRate: (double r) => setState(() {
                _rate = r;
                _picking = false;
              }),
              onTogglePicker: () => setState(() => _picking = !_picking),
              // CHANGE OPENS THE PICKER STRAIGHT AWAY. A plain reset would
              // land on the collapsed control and make Change cost two taps,
              // from somebody who has already said they want to pick again.
              onChange: () => setState(() {
                _rate = null;
                _picking = true;
              }),
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
///
/// REVIEWED BY A TAX PROFESSIONAL, 2026-10-07, alongside a design review on
/// founder direction that the card was too wordy. Where the two disagreed,
/// the tax review won on every sentence that states a tax rule. What changed
/// and why:
///
///   COLLAPSED BY DEFAULT. The band prompt and six chips are one tap away,
///   behind one control, instead of about 49 words on every visit.
///
///   "UP TO". The engine multiplies the backed up receipts by ONE marginal
///   rate, which is exact only while taxable income stays inside the chosen
///   band after the deduction. Crossing into a lower band it overstates: on
///   the 2023 table, taxable 420,000 with 50,000 of receipts truly saves
///   8,500 while one rate at 20% says 10,000. So the figure is a ceiling,
///   and says so. The arithmetic is unchanged and is right inside a band.
///
///   WHO IT APPLIES TO. TRAIN removed the personal exemptions and a pure
///   compensation earner has no itemised deductions at all: Sec 34 covers
///   expenses of a trade, business or profession, and Sec 36(A)(1) makes
///   personal expenses non-deductible. Employees file on the graduated rates
///   too, so the old condition did not exclude them, and they were shown a
///   saving they can never claim. The condition now names business or
///   professional income.
///
///   INCOME TAX, AND YEARLY TAXABLE. A non-VAT filer on graduated rates still
///   owes 3% percentage tax on gross, which receipts do not touch. And the
///   bands are annual taxable income while this card is usually a month.
///
/// What deliberately did NOT change: no default band, and no peso figure of
/// any kind until a band is chosen. A default rate is how a made-up tax
/// saving reaches a screen.
class _ShieldSection extends StatelessWidget {
  const _ShieldSection({
    required this.palette,
    required this.summary,
    required this.rate,
    required this.picking,
    required this.onRate,
    required this.onTogglePicker,
    required this.onChange,
  });

  final Palette palette;
  final BirClaimSummary summary;
  final double? rate;
  final bool picking;
  final ValueChanged<double> onRate;
  final VoidCallback onTogglePicker;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;

    if (rate == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PickerToggle(palette: p, open: picking, onTap: onTogglePicker),
          if (picking) ...<Widget>[
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
                    : 'At $pct%, up to',
                style: AppType.kicker(p),
              ),
            ),
            Semantics(
              button: true,
              label: 'Change income tax band',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onChange,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Change',
                    style: AppType.caption(p).copyWith(color: p.accent),
                  ),
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
        // THE CONDITION, BESIDE THE FIGURE, and it stays on screen. It is the
        // wrong-conclusion stopper the house rule makes an exception for: the
        // people most likely to be misled by a peso saving are exactly those
        // on the 8% election or the 40% standard deduction, which is most
        // self-employed Filipinos, and employees, for whom it is always zero.
        //
        // At 0% there is nothing to qualify: "take nothing off" beside 0.00
        // cannot mislead, so the explanation of the exemption is behind the
        // dot rather than here.
        if (rate != 0) ...<Widget>[
          const SizedBox(height: Spacing.xs),
          Text(
            'Off your income tax, only for business or professional income '
            'filed on graduated rates with itemised deductions. On the 8% '
            'election or the 40% standard deduction, it is ₱0.',
            style: AppType.caption(p),
          ),
        ],
      ],
    );
  }
}

/// The one control that stands in for the band prompt and its six chips.
///
/// A full width row at the 44dp floor, so it is an obvious target and wraps
/// rather than truncating at 320dp and 1.5x text. Accent text on the card
/// surface, which is the pair "Change" already uses, so no new colour pair
/// reaches the contrast test.
class _PickerToggle extends StatelessWidget {
  const _PickerToggle({
    required this.palette,
    required this.open,
    required this.onTap,
  });

  final Palette palette;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  // OPEN, it says what to pick and which income: YEARLY and
                  // TAXABLE, because the card is usually filtered to a month
                  // and someone earning 40,000 a month would otherwise read
                  // "up to 250,000" as their month and pick the 0% band. The
                  // rates year is here too, so the table is not timeless.
                  open
                      ? 'Pick your yearly taxable income band (2023+ rates)'
                      : 'See what these could save on income tax',
                  style: AppType.caption(
                    p,
                  ).copyWith(color: p.accent, fontWeight: FontWeight.w800),
                ),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: p.accent,
              ),
            ],
          ),
        ),
      ),
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
        // A MINIMUM HEIGHT, for the 44dp floor. The same padding-only version
        // of this measured 42.0 on the Plan card and was caught there; it is
        // the same chip and would have been the same two pixels short here,
        // on a screen whose own test did not happen to measure it.
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[Text(label, style: AppType.caption(palette))],
        ),
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
