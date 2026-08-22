// Safe to spend: the honest fortnight buffer (f4.62).
//
// The Accounts hero answers "what am I worth". It does not answer the question
// a person actually asks before tapping pay: "can I spend this right now, or is
// it already promised to a bill?". This card answers that, and only that.
//
// The number is safeToSpendBuffer(...), the founder's "minimum due only,
// conservative-safe" rule: liquid cash you can reach now (cash, e-wallet,
// checking, never savings, never a foreign balance) minus every payment landing
// in the next 14 days, where a credit card counts for its MINIMUM only. It is
// an engine value, golden-locked in test/safe_buffer_golden_test.dart; this
// widget renders it and never does money math of its own. The buffer can be
// negative, and a negative buffer is shown plainly, not floored to zero: a
// person already overcommitted for the fortnight needs to see that most of all.
//
// The toggle flips the same card to Net worth, the founder's chosen second
// lens, so "what I can safely spend" and "what I am worth" sit one tap apart
// instead of a scroll apart. Net worth taps through to the trend screen.
//
// Every peso figure routes through the injected [money] formatter, the same one
// the rest of the screen uses, so the privacy eye hides this card's figures at
// the same instant it hides the hero's. No second formatter, no drift.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';
import 'segmented.dart';

/// Which lens the card is showing.
enum SafeToSpendView { buffer, netWorth }

class SafeToSpendCard extends StatelessWidget {
  /// The current lens, held and persisted by the screen so it survives a reopen.
  final SafeToSpendView view;

  /// Flip the lens. The screen persists the choice.
  final void Function(SafeToSpendView) onView;

  /// The whole safeToSpendBuffer(...) map: liquid, committed, cardDue, billsDue,
  /// buffer, dueCount, windowDays. Passed as-is so this widget stays a renderer.
  final Map<String, dynamic> buffer;

  /// netWorthParts(...)['netWorth'], for the second lens. Same figure the hero
  /// shows, so the two can never disagree.
  final double netWorth;

  /// The screen's masked money formatter (hides to dots under the privacy eye).
  final String Function(double) money;

  /// True when the privacy eye is on: the figures are dots and the plain-English
  /// sentence is suppressed, so a shoulder glance reads nothing.
  final bool hideBalances;

  /// Opens the net worth trend, from the Net worth lens.
  final VoidCallback onOpenTrend;

  // Not const: build() reads mutable Barako getters, so a const call site would
  // freeze this card in the previous palette after a theme switch.
  // ignore: prefer_const_constructors_in_immutables
  SafeToSpendCard({
    super.key,
    required this.view,
    required this.onView,
    required this.buffer,
    required this.netWorth,
    required this.money,
    required this.hideBalances,
    required this.onOpenTrend,
  });

  double get _buffer => (buffer['buffer'] as num?)?.toDouble() ?? 0;
  double get _liquid => (buffer['liquid'] as num?)?.toDouble() ?? 0;
  double get _committed => (buffer['committed'] as num?)?.toDouble() ?? 0;
  double get _cardDue => (buffer['cardDue'] as num?)?.toDouble() ?? 0;
  int get _dueCount => (buffer['dueCount'] as num?)?.toInt() ?? 0;
  int get _minsUnset => (buffer['minsUnset'] as num?)?.toInt() ?? 0;
  int get _windowDays => (buffer['windowDays'] as num?)?.toInt() ?? 14;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      padding: Insets.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Segmented<SafeToSpendView>(
            current: view,
            onPick: onView,
            options: const [
              SegmentOption(
                value: SafeToSpendView.buffer,
                label: 'Safe to spend',
              ),
              SegmentOption(
                value: SafeToSpendView.netWorth,
                label: 'Net worth',
              ),
            ],
          ),
          const SizedBox(height: Gap.lg),
          if (view == SafeToSpendView.buffer)
            _bufferFace(context)
          else
            _netWorthFace(context),
        ],
      ),
    );
  }

  // The buffer lens: the fortnight figure, one honest sentence, and the
  // liquid-minus-due breakdown that shows the person exactly where it came from.
  Widget _bufferFace(BuildContext context) {
    final positive = _buffer > 0;
    final figureColor = positive ? Barako.celebrate : Barako.warningStrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SAFE TO SPEND · NEXT $_windowDays DAYS',
          style: Barako.kickerStyle,
        ),
        const SizedBox(height: Gap.xs),
        Semantics(
          label: hideBalances
              ? 'Safe to spend for the next $_windowDays days, hidden.'
              : 'Safe to spend for the next $_windowDays days, ${money(_buffer)}.',
          child: ExcludeSemantics(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                money(_buffer),
                maxLines: 1,
                style: AppText.amountLg.w8.tint(figureColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        if (!hideBalances)
          Text(_sentence(), style: AppText.small.tint(Barako.textSecondary)),
        const SizedBox(height: Gap.lg),
        Container(height: 1, color: Barako.border),
        const SizedBox(height: Gap.lg),
        _breakdownRow(
          'Money you can reach now',
          _liquid,
          Barako.text,
          dotColor: Barako.primary,
        ),
        const SizedBox(height: Gap.md),
        _breakdownRow(
          _dueCount == 1
              ? 'Bills and card minimums due (1 item)'
              : 'Bills and card minimums due ($_dueCount items)',
          _committed,
          Barako.warning,
          dotColor: Barako.warning,
          negative: true,
        ),
        // The honesty line both reviewers asked for: a card is counted at its
        // minimum, and paying only the minimum is not the same as clearing it.
        // Static and true, with no invented interest figure.
        if (_cardDue > 0) ...[
          const SizedBox(height: Gap.md),
          _caveat(
            'Card figures are the minimum due only. Paying just the minimum '
            'still leaves the rest growing interest.',
          ),
        ],
        // A debt due this fortnight with no minimum saved is left out rather
        // than reserved at its full balance, so the buffer stays meaningful.
        // Say so, so the person can set the minimum and get a truer number.
        if (_minsUnset > 0) ...[
          const SizedBox(height: Gap.md),
          _caveat(
            _minsUnset == 1
                ? '1 debt due soon has no minimum set, so it is not counted '
                      'here yet. Add its minimum for a truer number.'
                : '$_minsUnset debts due soon have no minimum set, so they are '
                      'not counted here yet. Add their minimums for a truer '
                      'number.',
          ),
        ],
      ],
    );
  }

  // A small, muted caveat line with an info glyph. Kept visually quiet so it
  // informs without competing with the figure.
  Widget _caveat(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(salapifyIcon('info'), size: IconSizes.dense, color: Barako.muted),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(text, style: AppText.caption.tint(Barako.muted)),
        ),
      ],
    );
  }

  // The net worth lens: the hero's figure, one tap from the trend, framed as the
  // bigger picture so the two numbers read as a pair rather than a repeat.
  Widget _netWorthFace(BuildContext context) {
    return Semantics(
      button: true,
      label: hideBalances
          ? 'Net worth hidden. Opens the trend over time.'
          : 'Net worth ${money(netWorth)}. Opens the trend over time.',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Haptics.select();
            onOpenTrend();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NET WORTH · THE FULL PICTURE', style: Barako.kickerStyle),
              const SizedBox(height: Gap.xs),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(netWorth),
                        maxLines: 1,
                        style: AppText.amountLg.w8,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Icon(
                    salapifyIcon('forward'),
                    size: IconSizes.inline,
                    color: Barako.muted,
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              if (!hideBalances)
                Text(
                  'Everything you own, minus everything you owe. Tap to see how '
                  'it has moved over time.',
                  style: AppText.small.tint(Barako.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // One breakdown line: a status dot, a plain label, and the figure on the
  // right in tabular figures so the two line up. The due line carries a minus,
  // because it is money leaving, and reads in the warning tint.
  Widget _breakdownRow(
    String label,
    double value,
    Color valueColor, {
    required Color dotColor,
    bool negative = false,
  }) {
    final shown = hideBalances
        ? money(value)
        : (negative ? '- ${money(value)}' : money(value));
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.small.tint(Barako.textSecondary),
          ),
        ),
        const SizedBox(width: Gap.md),
        Text(shown, style: AppText.amountReference.tint(valueColor)),
      ],
    );
  }

  // The one honest sentence under the figure. Three states, no invented
  // thresholds: overcommitted (negative), nothing set aside yet (no dues), and
  // the ordinary healthy case. Wording taken from the financial-coach review
  // (2026-08-22): always name "bills and card minimums", never imply the cards
  // are cleared, and on a negative buffer lead with the shortfall, never a spend
  // figure. Savings are named as protected, not as money you forgot you had.
  String _sentence() {
    if (_buffer < 0) {
      return 'You are ${money(_buffer.abs())} short for the next $_windowDays '
          'days. Your bills and card minimums due are more than the cash you '
          'can reach right now.';
    }
    if (_committed <= 0) {
      return 'Nothing is due in the next $_windowDays days, so this is simply '
          'your liquid cash. Your savings are kept out of it, so your safety '
          'net is not on the table here.';
    }
    return 'You have ${money(_buffer)} free to spend over the next $_windowDays '
        'days, after setting aside ${money(_committed)} for upcoming bills and '
        'card minimums. Savings are not counted.';
  }
}
