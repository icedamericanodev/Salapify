// Your debts in one place, f4.66. A consolidated view of every debt the person
// entered, with a Save/Share PDF export. It is NOT a bank statement and says so:
// a plain title, an honest disclaimer, and only the figures the person entered,
// composed through the golden-locked consolidatedDebtStatement. No fabricated
// badge, no "verified", no encryption or regulator claim.

import 'package:flutter/material.dart';

import '../data/export_files.dart'
    show
        debtStatementDisclaimer,
        saveConsolidatedDebtStatementPdfToDevice,
        shareConsolidatedDebtStatementPdf;
import '../data/store.dart';
import '../money/credit_utilization.dart' show UtilizationBand;
import '../money/debt_statement.dart'
    show DebtStatementRow, consolidatedDebtStatement, maskDebtName;
import '../money/format.dart' show formatMoney;
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';

class DebtStatementScreen extends StatelessWidget {
  final SalapifyStore store;
  const DebtStatementScreen({super.key, required this.store});

  static String _longDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final p = iso.split('-');
    if (p.length < 3) return iso;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (m == null || d == null || m < 1 || m > 12) return iso;
    return '${months[m - 1]} $d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your debts')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final s = consolidatedDebtStatement(store.data, DateTime.now());
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text('Your debts in one place', style: AppText.title.w8),
              const SizedBox(height: Gap.sm),
              Text(
                debtStatementDisclaimer,
                style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
              ),
              const SizedBox(height: Gap.lg),
              if (s == null)
                _empty()
              else ...[
                _summary(s),
                const SizedBox(height: Gap.lg),
                _exportRow(context),
                const SizedBox(height: Gap.lg),
                Text('EACH DEBT', style: Barako.kickerStyle),
                const SizedBox(height: Gap.sm),
                for (final r in (s['rows'] as List<DebtStatementRow>)) ...[
                  _debtRow(r),
                  const SizedBox(height: Gap.sm),
                ],
                const SizedBox(height: Gap.md),
                Text(
                  'Your yearly rate is the monthly rate you entered times '
                  'twelve. The figure in brackets adds monthly compounding, so '
                  'it is closer to the true yearly cost, and it is still not the '
                  'bank\'s official rate, which also includes fees.',
                  style: AppText.caption
                      .tint(Barako.muted)
                      .copyWith(height: 1.4),
                ),
                const SizedBox(height: Gap.lg),
                _warning(s),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _empty() => Container(
    padding: Insets.card,
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: Barako.border),
    ),
    child: Text(
      'You have no debts recorded, so there is nothing to consolidate yet. Add '
      'a card, a loan, or a BNPL plan on the Debts screen and it shows up here.',
      style: AppText.small.tint(Barako.textSecondary).copyWith(height: 1.4),
    ),
  );

  Widget _summary(Map<String, dynamic> s) {
    final util = s['utilization'] as double?;
    final minsUnset = s['minsUnset'] as int;
    final totalMin = s['totalMinDue'] as double;
    final minText = minsUnset == 0
        ? formatMoney(totalMin)
        : (totalMin == 0
              ? 'not set'
              : '${formatMoney(totalMin)} +$minsUnset');
    return Container(
      padding: Insets.card,
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _tile('Total you owe', formatMoney(s['totalDebt'] as double),
                  Barako.warningStrong),
              _tile('Total of your minimums', minText, Barako.text),
            ],
          ),
          const SizedBox(height: Gap.lg),
          Row(
            children: [
              _tile(
                'Est. interest this month',
                formatMoney(s['estMonthlyInterest'] as double),
                Barako.warning,
              ),
              _tile(
                'Card usage',
                util == null ? 'n/a' : '${(util * 100).round()}%',
                _bandColor(s['utilizationBand'] as UtilizationBand),
              ),
            ],
          ),
          if (minsUnset > 0) ...[
            const SizedBox(height: Gap.md),
            Text(
              minsUnset == 1
                  ? '1 debt has no minimum saved, so it is not in the total above.'
                  : '$minsUnset debts have no minimum saved, so they are not in '
                        'the total above.',
              style: AppText.caption.tint(Barako.muted),
            ),
          ],
          const SizedBox(height: Gap.md),
          Text(
            'Estimated interest is at today\'s balances and counts interest '
            'only, not fees. Pay a card in full by its due date and it owes no '
            'interest, so your real cost is lower.',
            style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.micro.copyWith(letterSpacing: 0.4)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.amount.w8.tint(color)),
        ),
      ],
    ),
  );

  static Color _bandColor(UtilizationBand b) => switch (b) {
    UtilizationBand.healthy => Barako.primary,
    UtilizationBand.watch => Barako.celebrate,
    UtilizationBand.high => Barako.warning,
    UtilizationBand.maxed => Barako.warningStrong,
    UtilizationBand.none => Barako.text,
  };

  Widget _exportRow(BuildContext context) {
    Future<void> guardOffline(Future<void> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      // The privacy note the legal review asked for: the PDF is plain text and
      // leaves the app the moment it is shared, so name that before it happens.
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Before you export'),
          content: const Text(
            'This PDF lists your debts and card details in plain text. It is '
            'made on your phone and Salapify never sees it. Once you share or '
            'save it, it is out of the app\'s protection, so only send it to '
            'people you trust.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await action();
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not make the PDF just now.')),
        );
      }
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => guardOffline(
              () => shareConsolidatedDebtStatementPdf(
                store.data,
                DateTime.now(),
              ),
            ),
            icon: Icon(salapifyIcon('share'), size: IconSizes.dense),
            label: const Text('Share PDF'),
          ),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => guardOffline(
              () => saveConsolidatedDebtStatementPdfToDevice(
                store.data,
                DateTime.now(),
              ),
            ),
            icon: Icon(salapifyIcon('pdf'), size: IconSizes.dense),
            label: const Text('Save PDF'),
          ),
        ),
      ],
    );
  }

  Widget _debtRow(DebtStatementRow r) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  maskDebtName(r.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                formatMoney(r.balance),
                style: AppText.amountReference.tint(Barako.warningStrong),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              r.typeLabel,
              if (r.aprAnnual != null)
                r.aprEffective == null
                    ? '${r.aprAnnual!.toStringAsFixed(1)}% a year'
                    : '${r.aprAnnual!.toStringAsFixed(1)}% a year '
                          '(${r.aprEffective!.toStringAsFixed(1)}% compounded)',
            ].join('  ·  '),
            style: AppText.caption.tint(Barako.muted),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: _mini(
                  'Minimum due',
                  r.minDue == null ? '-' : formatMoney(r.minDue!),
                ),
              ),
              Expanded(
                child: _mini(
                  'Due',
                  r.dueISO == null ? '-' : _longDate(r.dueISO),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.micro),
      const SizedBox(height: 1),
      Text(value, style: AppText.small.tint(Barako.text)),
    ],
  );

  Widget _warning(Map<String, dynamic> s) {
    final payoff = s['payoff'] as Map<String, dynamic>?;
    final totalMin = formatMoney(s['totalMinDue'] as double);
    final String text;
    if (payoff != null && (payoff['months'] as int) > 0) {
      text =
          'Paying only the minimum each month keeps a debt alive far longer and '
          'adds a lot of interest. If you keep paying about $totalMin in total '
          'every month and put each finished debt\'s payment straight onto the '
          'next one, you would be debt free around '
          '${_longDate(payoff['date'] as String)} and pay about '
          '${formatMoney(payoff['totalInterest'] as double)} in interest along '
          'the way. Pay less than that, or stop rolling the freed payments '
          'forward, and it takes longer and costs more.';
    } else {
      text =
          'On these payments the balance never clears, because the interest '
          'keeps pace with what is being paid. Paying more than the minimum is '
          'what starts bringing the balance down.';
    }
    return Container(
      padding: Insets.card,
      decoration: BoxDecoration(
        color: Barako.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            salapifyIcon('info'),
            size: IconSizes.dense,
            color: Barako.warning,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              text,
              style: AppText.small.tint(Barako.text).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
