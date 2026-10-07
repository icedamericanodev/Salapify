// Bills and spending, f4.67. One honest place that answers three plain
// questions from figures the person already entered: how much of this month's
// spending is committed versus everyday, what the recurring bills add up to at
// a week / month / year cadence, and what is due next before payday.
//
// It grows on top of what exists and invents nothing: the split composes
// spendingSplit (which re-buckets the exact expense universe the budget counts),
// the projection composes recurringBillsMonthly, and the due-date list is the
// golden-locked upcomingCommitments rendered straight. No new stored data, no
// migration, no money calculation changed.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/commitments.dart'
    show daysUntil, daysUntilWords, shortDueDate, upcomingCommitments;
import '../money/format.dart' show formatMoney;
import '../money/spending_breakdown.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_card.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/segmented.dart';
import 'recurring.dart' show RecurringScreen;

class BillsSpendingScreen extends StatefulWidget {
  final SalapifyStore store;
  const BillsSpendingScreen({super.key, required this.store});

  @override
  State<BillsSpendingScreen> createState() => _BillsSpendingScreenState();
}

class _BillsSpendingScreenState extends State<BillsSpendingScreen> {
  // The period toggle is a view preference, not saved money data, so it lives
  // in local state and resets to monthly (the cadence people budget in).
  BillPeriod _period = BillPeriod.monthly;

  static DateTime? _parseISO(String s) {
    if (s.length < 10) return null;
    final p = s.split('-');
    if (p.length < 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills and spending')),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final now = DateTime.now();
          final split = spendingSplit(widget.store.data, now);
          final billsMonthly = recurringBillsMonthly(widget.store.data);
          final billsCount = recurringBillsCount(widget.store.data);
          final commitments = upcomingCommitments(widget.store.data, now);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'A plain read on where your money goes each month, built only '
                'from what you have logged. Nothing here leaves your phone.',
                style: AppText.small
                    .tint(Barako.textSecondary)
                    .copyWith(height: 1.4),
              ),
              const SizedBox(height: Gap.lg),
              Text('THIS MONTH', style: Barako.kickerStyle),
              const SizedBox(height: Gap.sm),
              _splitCard(split),
              const SizedBox(height: Gap.lg),
              Text('YOUR RECURRING BILLS', style: Barako.kickerStyle),
              const SizedBox(height: Gap.sm),
              _billsCard(context, billsMonthly, billsCount),
              const SizedBox(height: Gap.lg),
              Text('COMING UP', style: Barako.kickerStyle),
              const SizedBox(height: Gap.sm),
              _radarCard(commitments, now),
            ],
          );
        },
      ),
    );
  }

  // ---- This month: committed vs everyday --------------------------------

  Widget _splitCard(Map<String, dynamic> split) {
    final committed = split['committed'] as double;
    final everyday = split['everyday'] as double;
    final total = split['total'] as double;
    final pct = (split['committedPct'] as double).round();

    return SalapifyCard(
      child: total <= 0
          ? Text(
              'No spending logged this month yet. Once you start logging, this '
              'splits it into committed bills and everyday spending.',
              style: AppText.small
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _figure(
                        'Committed',
                        formatMoney(committed),
                        Barako.celebrate,
                      ),
                    ),
                    Expanded(
                      child: _figure(
                        'Everyday',
                        formatMoney(everyday),
                        Barako.primary,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.md),
                _ratioBar(committed, everyday),
                const SizedBox(height: Gap.sm),
                Text(
                  '$pct% of what you spent this month was committed: bills you '
                  'set up as recurring, debt payments, and card interest. The '
                  'rest is everyday spending not tied to a bill or debt you set '
                  'up. Setting up a recurring bill moves it into committed here.',
                  style: AppText.caption
                      .tint(Barako.muted)
                      .copyWith(height: 1.4),
                ),
              ],
            ),
    );
  }

  Widget _figure(
    String label,
    String value,
    Color color, {
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!alignEnd) ...[_dot(color), const SizedBox(width: Gap.xs)],
            Text(label, style: AppText.micro.copyWith(letterSpacing: 0.4)),
            if (alignEnd) ...[const SizedBox(width: Gap.xs), _dot(color)],
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(value, style: AppText.amount.w8.tint(color)),
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _ratioBar(double committed, double everyday) {
    final total = committed + everyday;
    // Flex weights need integers; scale to basis points so a 0.3% slice still
    // shows. A zero-value side collapses to nothing rather than a stray sliver.
    // Guard non-finite first: round() throws on a NaN/Infinity a junk backup
    // could smuggle in, so an unusable book shows a single neutral bar instead
    // of taking the screen down.
    final ok =
        total.isFinite && total > 0 && committed.isFinite && everyday.isFinite;
    if (!ok) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: SizedBox(height: 16, child: ColoredBox(color: Barako.border)),
      );
    }
    final cFlex = (committed / total * 10000).round();
    final eFlex = (everyday / total * 10000).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: SizedBox(
        height: 16,
        // Stretch, so each ColoredBox (which has no child) fills the 16px
        // height instead of collapsing to nothing under a Row's loose cross
        // constraints.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (cFlex > 0)
              Expanded(
                flex: cFlex,
                child: ColoredBox(color: Barako.celebrate),
              ),
            if (cFlex > 0 && eFlex > 0) const SizedBox(width: 2),
            if (eFlex > 0)
              Expanded(
                flex: eFlex,
                child: ColoredBox(color: Barako.primary),
              ),
          ],
        ),
      ),
    );
  }

  // ---- Recurring bills, per week / month / year -------------------------

  Widget _billsCard(BuildContext context, double monthly, int count) {
    return SalapifyCard(
      child: count == 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You have no recurring bills set up yet. Add your rent, '
                  'utilities, or subscriptions and they show up here and in '
                  'your cash flow.',
                  style: AppText.small
                      .tint(Barako.textSecondary)
                      .copyWith(height: 1.4),
                ),
                const SizedBox(height: Gap.md),
                _manageButton(context, 'Add a recurring bill'),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Segmented<BillPeriod>(
                  current: _period,
                  onPick: (p) => setState(() => _period = p),
                  options: const [
                    SegmentOption(value: BillPeriod.weekly, label: 'Weekly'),
                    SegmentOption(value: BillPeriod.monthly, label: 'Monthly'),
                    SegmentOption(value: BillPeriod.annual, label: 'Yearly'),
                  ],
                ),
                const SizedBox(height: Gap.md),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatMoney(billsForPeriod(monthly, _period)),
                    style: AppText.amountXl.tint(Barako.text),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 1
                      ? 'across 1 recurring bill, ${_periodWord()}'
                      : 'across $count recurring bills, ${_periodWord()}',
                  style: AppText.caption.tint(Barako.muted),
                ),
                const SizedBox(height: Gap.md),
                _manageButton(context, 'Manage recurring bills'),
              ],
            ),
    );
  }

  String _periodWord() {
    switch (_period) {
      case BillPeriod.weekly:
        return 'as a weekly figure';
      case BillPeriod.monthly:
        return 'a month';
      case BillPeriod.annual:
        return 'over a year';
    }
  }

  Widget _manageButton(BuildContext context, String label) {
    return OutlinedButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RecurringScreen(store: widget.store)),
      ),
      icon: Icon(salapifyIcon('repeat'), size: IconSizes.dense),
      label: Text(label),
    );
  }

  // ---- Coming up: the due-date radar ------------------------------------

  Widget _radarCard(Map<String, dynamic> commitments, DateTime now) {
    final bills = (commitments['bills'] as List).cast<Map<String, dynamic>>();
    final payday = _parseISO((commitments['payday'] ?? '').toString());
    return SalapifyCard(
      child: bills.isEmpty
          ? Text(
              payday == null
                  ? 'Nothing is due before your next payday.'
                  : 'Nothing is due before your next payday on '
                        '${shortDueDate(payday)}. You are clear for now.',
              style: AppText.small
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.4),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (payday != null)
                  Text(
                    'Due before your next payday on ${shortDueDate(payday)}',
                    style: AppText.caption.tint(Barako.muted),
                  ),
                const SizedBox(height: Gap.sm),
                for (var i = 0; i < bills.length; i++) ...[
                  if (i > 0) Divider(height: Gap.md, color: Barako.border),
                  _radarRow(bills[i], now),
                ],
                const SizedBox(height: Gap.md),
                Text(
                  'Total of ${formatMoney(commitments['total'] as double)} is '
                  'due before payday. Card and loan payments use your minimum '
                  'due. A debt with no minimum saved shows its full balance '
                  'here instead, so add a minimum to fix that.',
                  style: AppText.caption
                      .tint(Barako.muted)
                      .copyWith(height: 1.4),
                ),
              ],
            ),
    );
  }

  Widget _radarRow(Map<String, dynamic> bill, DateTime now) {
    final name = (bill['name'] ?? '').toString();
    final kind = (bill['kind'] ?? '').toString();
    final date = _parseISO((bill['date'] ?? '').toString());
    final amount = bill['amount'];
    final when = date == null
        ? ''
        : '${shortDueDate(date)}  ·  ${daysUntilWords(daysUntil(date, now))}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          salapifyIcon(kind == 'minimum' ? 'card' : 'repeat'),
          size: IconSizes.dense,
          color: Barako.textSecondary,
        ),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong,
              ),
              if (when.isNotEmpty)
                Text(when, style: AppText.caption.tint(Barako.muted)),
            ],
          ),
        ),
        const SizedBox(width: Gap.sm),
        Text(
          formatMoney(amount is num ? amount.toDouble() : 0.0),
          style: AppText.amountReference.tint(Barako.text),
        ),
      ],
    );
  }
}
