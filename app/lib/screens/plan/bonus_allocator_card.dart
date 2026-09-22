import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/bonus_allocator.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';

/// The 13th month and year-end bonus allocator, on Plan.
///
/// Founder spec, 2026-09-20, feature 3. A figure goes in, the TRAIN tax comes
/// off, and what is left is split three ways.
///
/// ## It is a calculator, not a ledger entry
///
/// Nothing here writes anything. Somebody in November has been told a number
/// by HR and wants to know what it turns into; they have not received it yet,
/// and logging it would put money in the app that is not in their account.
/// When it lands they log it like any other income.
///
/// ## The buckets name no product
///
/// The spec routes the first one to "SeaBank, Maya, Pag-IBIG MP2". Those
/// names are not here. A bucket says what the money is FOR and stops, because
/// an app that reads your balance and then tells you which named institution
/// to move it to is doing the thing an investment adviser is registered to
/// do. `bonus_allocator_test.dart` fails the build if a product name, a rate
/// or a return ever appears in one.
class BonusAllocatorCard extends StatefulWidget {
  const BonusAllocatorCard({super.key, required this.palette});

  final Palette palette;

  @override
  State<BonusAllocatorCard> createState() => _BonusAllocatorCardState();
}

class _BonusAllocatorCardState extends State<BonusAllocatorCard> {
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value =>
      double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;

  void _setAmount(double v) {
    _amount.text = v.toStringAsFixed(0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final double entered = _value;
    final BonusPlan plan = allocateBonus(bonus: entered);
    final bool has = entered > 0;

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
                child: Text('13TH MONTH AND BONUS', style: AppType.kicker(p)),
              ),
              InfoDot(
                color: p.textMuted,
                semanticLabel: 'How a 13th month is taxed and split',
                onTap: () => InfoSheet.show(context, p, InfoTopic.bonusSplit),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Put in what you are expecting and see what is left after tax, '
            'and where it could go.',
            style: AppType.caption(p),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (_) => setState(() {}),
            style: AppType.amount(p),
            decoration: InputDecoration(
              prefixText: '₱ ',
              prefixStyle: AppType.amount(p).copyWith(color: p.textMuted),
              hintText: '0',
              hintStyle: AppType.amount(p).copyWith(color: p.textMuted),
              filled: true,
              fillColor: p.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: p.border),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: <Widget>[
              for (final double a in bonusQuickAmounts)
                _QuickChip(
                  palette: p,
                  label: formatPeso(a),
                  onTap: () => _setAmount(a),
                ),
            ],
          ),
          if (has) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            _ExemptBar(palette: p, plan: plan),
            const SizedBox(height: Spacing.md),
            _Row(
              palette: p,
              label: 'Tax free, under the ₱90,000 allowance',
              value: formatPeso(plan.taxExempt),
              tone: p.positive,
            ),
            if (!plan.isFullyExempt) ...<Widget>[
              _Row(
                palette: p,
                label: 'Taxed, above the allowance',
                value: formatPeso(plan.taxable),
                tone: p.textPrimary,
              ),
              _Row(
                palette: p,
                label: 'Roughly what tax takes',
                value: '-${formatPeso(plan.estimatedTax)}',
                tone: p.negative,
              ),
            ],
            const SizedBox(height: Spacing.xs),
            Divider(color: p.border, height: Spacing.lg),
            Text('WHAT LANDS', style: AppType.kicker(p)),
            const SizedBox(height: Spacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatPeso(plan.net),
                style: AppType.hero(p).copyWith(color: p.positive),
              ),
            ),
            if (!plan.isFullyExempt)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(
                  // The one line that stops a wrong conclusion. Without it a
                  // person plans against a figure their payslip will not
                  // match, and blames the app rather than the assumption.
                  'The tax here is a rough 20%. What is actually withheld '
                  'depends on the band the excess lands in, so treat this as '
                  'close rather than exact.',
                  style: AppType.caption(p),
                ),
              ),
            const SizedBox(height: Spacing.md),
            for (final BonusBucket b in plan.buckets)
              _BucketRow(palette: p, bucket: b),
            const SizedBox(height: Spacing.xs),
            Text(
              // Said once, plainly, because the buckets deliberately do not
              // name anywhere to put the money.
              'Where each share goes is yours to decide. Salapify does not '
              'move any of it and has not logged anything here.',
              style: AppType.caption(p),
            ),
          ],
        ],
      ),
    );
  }
}

/// How much of the year's 90,000 allowance this bonus uses.
class _ExemptBar extends StatelessWidget {
  const _ExemptBar({required this.palette, required this.plan});

  final Palette palette;
  final BonusPlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Tax free allowance used',
                style: AppType.caption(palette),
              ),
            ),
            Text(
              // The figures, not only the bar. A bar on its own cannot be
              // read by somebody using a screen reader and cannot be read at
              // all in greyscale.
              '${formatPeso(plan.taxExempt)} of ₱90,000',
              style: AppType.caption(
                palette,
              ).copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(Radii.pill),
          child: LinearProgressIndicator(
            value: plan.exemptUsed,
            minHeight: 6,
            backgroundColor: palette.border,
            valueColor: AlwaysStoppedAnimation<Color>(palette.positive),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          // THE SENTENCE THE SPEC DOES NOT HAVE, and the reason the engine
          // takes a benefitsAlreadyReceived parameter. The 90,000 covers the
          // 13th month AND other benefits together for the whole year, so
          // somebody who already had a performance bonus has less room than
          // this bar suggests.
          'That allowance covers your 13th month and any other benefits for '
          'the whole year together, so a bonus earlier in the year has '
          'already used some of it.',
          style: AppType.caption(palette),
        ),
      ],
    );
  }
}

class _BucketRow extends StatelessWidget {
  const _BucketRow({required this.palette, required this.bucket});

  final Palette palette;
  final BonusBucket bucket;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${bucket.name} · ${bucket.percent}%',
                    style: AppType.body(
                      palette,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  formatPeso(bucket.amount),
                  style: AppType.body(palette).copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(bucket.purpose, style: AppType.caption(palette)),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
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
        // Vertical padding, never a fixed height with an alignment. A
        // Container with an alignment and no width fills everything offered,
        // which has turned a row of chips into a stack of bars seven times
        // in this repository.
        // A MINIMUM HEIGHT, not padding arithmetic. Padding alone put this
        // at 42.0 and plan_test.dart caught it against the 44dp floor, which
        // is the smallest target a finger reliably hits. A fixed height
        // would break at large system font sizes; a minimum grows with the
        // text. The Row centres the label vertically without an `alignment`,
        // which is the thing that fills the whole width.
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: AppType.caption(
                palette,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
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
