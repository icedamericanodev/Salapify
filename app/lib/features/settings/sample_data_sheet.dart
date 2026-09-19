import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../data/seed_data.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Where somebody removes Salapify's demo data, and puts it back.
///
/// Founder direction, 2026-09-19, approving the design: a label plus a clear
/// control, rather than never saving the seed. Never saving it was the option
/// that looked safest and was the most dangerous: the first entry somebody
/// logs defaults to the first usable account, which on a new phone is a demo
/// one, so a seed excluded from the file would take the balance half of their
/// very first entry with it and leave a transaction pointing at nothing.
///
/// The confirmation names what leaves AND what stays, with figures computed at
/// the moment it is built. A dialog that says "this cannot be undone" about
/// data it will not name is how people learn to tap through dialogs.
class SampleDataSheet extends StatefulWidget {
  const SampleDataSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => SampleDataSheet(state: state),
    );
  }

  @override
  State<SampleDataSheet> createState() => _SampleDataSheetState();
}

class _SampleDataSheetState extends State<SampleDataSheet> {
  FinancialState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(state.theme);
    final SampleSummary s = state.sampleSummary;

    return SheetScaffold(
      palette: p,
      icon: Icons.science_outlined,
      title: 'Sample data',
      subtitle: 'What Salapify added, and what you added',
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (state.hasSampleData) ...<Widget>[
              Text(_whatIsHere(s), style: AppType.body(p)),
              const SizedBox(height: Spacing.md),
              Text(_whatYouAdded(), style: AppType.body(p)),
              const SizedBox(height: Spacing.lg),
              _Action(
                palette: p,
                label: 'Remove the sample data',
                emphasis: true,
                onTap: () => _confirmRemove(context, p, s),
              ),
            ] else if (state.canRestoreSampleData) ...<Widget>[
              Text(
                'You removed Salapify’s sample data. Everything here is '
                'yours.',
                style: AppType.body(p),
              ),
              const SizedBox(height: Spacing.lg),
              _Action(
                palette: p,
                label: 'Put the sample data back',
                emphasis: false,
                onTap: () {
                  state.restoreSampleData();
                  setState(() {});
                },
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'This adds Salapify’s example accounts and entries again. '
                'Nothing you typed is touched or written over.',
                style: AppType.caption(p),
              ),
            ] else
              Text(
                'There is no sample data on this phone.',
                style: AppType.body(p),
              ),
          ],
        ),
      ),
    );
  }

  /// What leaves, named item by item. Built from its own list rather than by
  /// slicing the sentence above, because a confirmation that is derived from
  /// prose breaks silently the moment the prose is reworded.
  String _outLine(SampleSummary s) {
    final List<String> parts = <String>[
      if (s.accounts > 0)
        '${s.accounts} sample accounts holding ${formatPeso(s.assets)}',
      if (s.transactions > 0) '${s.transactions} sample entries',
      if (s.debts > 0) '${s.debts} sample debts',
      if (s.installments > 0) '${s.installments} sample payment plans',
      if (s.goals > 0) '${s.goals} sample goals',
      if (s.budgets > 0) '${s.budgets} sample budget limits',
      if (s.bills > 0) '${s.bills} sample bills',
      if (s.upcoming > 0) '${s.upcoming} sample reminders',
    ];
    return _list(parts);
  }

  String _whatIsHere(SampleSummary s) {
    final List<String> parts = <String>[
      if (s.accounts > 0) '${s.accounts} accounts',
      if (s.transactions > 0) '${s.transactions} entries',
      if (s.debts > 0) '${s.debts} debts',
      if (s.installments > 0) '${s.installments} payment plans',
      if (s.goals > 0) '${s.goals} goals',
      if (s.budgets > 0) '${s.budgets} budget limits',
      if (s.bills > 0) '${s.bills} bills',
      if (s.upcoming > 0) '${s.upcoming} reminders',
    ];
    return 'Salapify added ${_list(parts)} when you first opened the app, so '
        'no screen was blank. Those accounts hold ${formatPeso(s.assets)} of '
        'savings and ${formatPeso(s.liabilities)} of debts, and none of it is '
        'yours.';
  }

  String _whatYouAdded() {
    final int accounts = state.accounts
        .where((Account a) => !a.isSample)
        .length;
    final int entries = state.transactions
        .where((Transaction t) => !t.isSample)
        .length;
    if (accounts == 0 && entries == 0) {
      return 'You have not added anything yet.';
    }
    final List<String> parts = <String>[
      if (accounts > 0) '$accounts ${accounts == 1 ? 'account' : 'accounts'}',
      if (entries > 0) '$entries ${entries == 1 ? 'entry' : 'entries'}',
    ];
    return 'You have added ${_list(parts)} since.';
  }

  static String _list(List<String> parts) {
    if (parts.isEmpty) return 'nothing';
    if (parts.length == 1) return parts.first;
    return '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  }

  Future<void> _confirmRemove(
    BuildContext context,
    Palette p,
    SampleSummary s,
  ) async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Remove the sample data?', style: AppType.title(p)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Out: ${_outLine(s)}', style: AppType.body(p)),
              const SizedBox(height: Spacing.sm),
              Text(
                'Stays: everything you typed. ${_whatYouAdded()}',
                style: AppType.body(p),
              ),
              // Named one by one, with both figures, because this is the only
              // case where a number a person recognises is going to change.
              for (final Account a in s.keptAccounts) ...<Widget>[
                const SizedBox(height: Spacing.sm),
                Text(
                  '${a.name} stays, because entries you made point at it. Its '
                  'sample money comes out, so it goes from '
                  '${formatPeso(a.balance)} to '
                  '${formatPeso(a.balance - _seeded(a.id))}.',
                  style: AppType.body(p),
                ),
              ],
              const SizedBox(height: Spacing.sm),
              Text(
                'You can put the sample data back from this same screen.',
                style: AppType.caption(p),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it', style: TextStyle(color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove it', style: TextStyle(color: p.negative)),
          ),
        ],
      ),
    );

    if (go != true) return;
    state.removeSampleData();
    if (mounted) setState(() {});
  }

  static double _seeded(String id) {
    for (final Account a in SeedData.accounts) {
      if (a.id == id) return a.balance;
    }
    return 0;
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.palette,
    required this.label,
    required this.emphasis,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool emphasis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: emphasis ? palette.negative : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppType.rowTitle(
                palette,
              ).copyWith(color: emphasis ? Colors.white : palette.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
