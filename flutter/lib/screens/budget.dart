// Budget: the daily driver. The monthly limit with optional carry over
// (numbers from the golden-verified budget engine), one-tap quick adds that
// keep balances honest through the ledger engine (remembered account,
// category tagging by label match) with an Undo snackbar, and the where it
// went top groups where a Pro cap turns the bar into a cap meter.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/budget.dart' as budget;
import '../theme.dart';
import '../typography.dart';
import 'quick_add_editor.dart';
import '../money/quick_adds.dart' show QuickAdd;
import '../widgets/empty_state.dart';
import '../widgets/progress_bar.dart';
import '../widgets/screen_header.dart';
import 'log_sheet.dart' show newEntryId, parseAmount, showLogSheet;
import 'overview.dart' show formatMoney;
import '../money/currencies.dart' show baseCurrencySymbol;

/// The RN default quick adds, shown when the imported settings carry none.
class BudgetScreen extends StatelessWidget {
  final SalapifyStore store;

  /// Opens Menu. Menu left the bottom bar, so every primary screen carries
  /// the way in.
  final VoidCallback? onMenu;
  const BudgetScreen({super.key, required this.store, this.onMenu});

  @override
  Widget build(BuildContext context) {
    final data = store.data;
    final ref = DateTime.now();
    final summary = budget.budgetSummary(data, ref);
    final went = budget.whereItWent(data, ref);
    final rows = (went['rows'] as List).cast<Map<String, dynamic>>();
    final max = went['max'] as double;

    // One reader for the presets, shared with the editor, so the chips and the
    // list being edited can never disagree about what is stored. It also
    // decides the defaults question: an empty list means the defaults until
    // the person has actually edited, and means empty afterwards.
    final adds = store.quickAdds;

    // The header is pinned above the list, the money.dart shape, so Menu
    // stays one tap away at any scroll depth. Founder approved for every
    // tab; Activity and Utang already worked this way and the app was split
    // down the middle.
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.sm,
              Gap.gutter,
              0,
            ),
            child: ScreenHeader('Budget', onMenu: onMenu),
          ),
          Expanded(
            child: ListView(
              padding: Insets.tabScreen.copyWith(top: 0),
              children: [
                _limitCard(context, summary),
                if (store.canWrite) ...[
                  const SizedBox(height: Gap.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'QUICK ADD',
                                  style: Barako.cardKickerStyle,
                                ),
                              ),
                              // Edit sits ON the card, not in a settings
                              // screen. Nobody decides their presets are wrong
                              // while browsing Preferences; they decide it
                              // looking at a chip that says Coffee ₱120 when
                              // their coffee is ₱65.
                              TextButton(
                                onPressed: () =>
                                    showQuickAddEditor(context, store),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 40),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                child: Text(
                                  'Edit',
                                  style: AppText.small.w7.tint(
                                    Barako.primaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final q in adds)
                                ActionChip(
                                  label: Text(
                                    '${q.label}  ${formatMoney(q.amount)}',
                                  ),
                                  backgroundColor: Barako.background,
                                  labelStyle: TextStyle(
                                    color: Barako.text,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  side: BorderSide(color: Barako.border),
                                  onPressed: () => _quickAdd(context, q),
                                ),
                              ActionChip(
                                label: const Text('+ Custom'),
                                backgroundColor: Barako.background,
                                labelStyle: TextStyle(
                                  color: Barako.primaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(color: Barako.border),
                                onPressed: () => showLogSheet(context, store),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // A chip tap now has a visible consequence on this screen:
                // today's entries, listed. A filter over the ledger, never a
                // sum; arithmetic does not start living in screens.
                ...(() {
                  final today = DateTime.now().toIso8601String().substring(
                    0,
                    10,
                  );
                  final todays = (data['transactions'] as List? ?? const [])
                      .whereType<Map>()
                      .where(
                        (t) =>
                            t['date'] == today &&
                            (t['type'] == 'expense' || t['type'] == 'income'),
                      )
                      .toList();
                  if (todays.isEmpty) return const <Widget>[];
                  return <Widget>[
                    const SizedBox(height: Gap.lg),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TODAY', style: Barako.cardKickerStyle),
                            const SizedBox(height: 6),
                            for (final t in todays)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        (t['label'] ?? '').toString().isEmpty
                                            ? (t['type'] == 'income'
                                                  ? 'Income'
                                                  : 'Expense')
                                            : (t['label']).toString(),
                                        overflow: TextOverflow.ellipsis,
                                        style: AppText.label.w4,
                                      ),
                                    ),
                                    Text(
                                      '${t['type'] == 'income' ? '+' : '-'}${formatMoney(t['amount'] is num ? t['amount'] as num : 0)}',
                                      style: AppText.label.tabular.tint(
                                        t['type'] == 'income'
                                            ? Barako.primary
                                            : Barako.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ];
                })(),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: Gap.lg),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('WHERE IT WENT', style: Barako.cardKickerStyle),
                          const SizedBox(height: 10),
                          for (final w in rows) _catRow(w, max),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // The 1st of the month is not a broken screen. WHERE IT
                  // WENT simply has nothing to show yet, and this says so
                  // instead of leaving 60 percent of the tab as a void.
                  const SizedBox(height: Gap.lg),
                  EmptyState(
                    icon: 'chart',
                    title: 'Nothing spent yet this month',
                    body:
                        'The chips above log your first one in a single tap, '
                        'and this fills in as the month happens.',
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _limitCard(BuildContext context, Map<String, dynamic> summary) {
    final limit = summary['limit'] as double;
    final spent = summary['spent'] as double;
    final carried = summary['carried'] as double;
    final remaining = summary['remaining'] as double;
    final over = summary['over'] as bool;
    final pct = summary['pct'] as int;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('THIS MONTH', style: Barako.cardKickerStyle),
                ),
                if (store.canWrite)
                  InkWell(
                    onTap: () => _editLimit(context),
                    child: Padding(
                      // A real 44dp tap target, not just the text.
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 4,
                      ),
                      child: Text(
                        limit > 0 ? 'Change limit' : 'Set a limit',
                        style: AppText.caption.w7.tint(Barako.primaryText),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (limit > 0) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatMoney(spent),
                        maxLines: 1,
                        style: AppText.amount.w7.tint(
                          over ? Barako.warning : Barako.text,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 6),
                    child: Text(
                      'of ${formatMoney(limit)}',
                      style: AppText.small.tint(Barako.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SalapifyProgressBar(
                value: pct / 100,
                semanticsLabel: 'Budget used',
                color: over ? Barako.warning : Barako.primary,
              ),
              const SizedBox(height: 8),
              Text(
                over
                    ? 'Over by ${formatMoney(spent - limit)}. No shame, just ease the biggest category below.'
                    : '${formatMoney(remaining)} left this month.'
                          '${carried > 0 ? ' Includes ${formatMoney(carried)} carried over from last month\'s unspent budget.' : ''}',
                style: AppText.small
                    .tint(over ? Barako.warning : Barako.muted)
                    .copyWith(height: 1.4),
              ),
            ] else ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoney(spent),
                  maxLines: 1,
                  style: AppText.amount,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Spent so far this month. Set a monthly limit and the bar will keep you honest.',
                style: AppText.small.tint(Barako.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _catRow(Map<String, dynamic> w, double max) {
    final amount = w['amount'] as double;
    final cap = w['cap'] as double;
    final overCap = cap > 0 && amount > cap;
    final frac = cap > 0
        ? (amount / cap < 1 ? amount / cap : 1.0)
        : (max > 0 ? amount / max : 0.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  w['label'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.small.tint(Barako.text),
                ),
              ),
              Text(
                cap > 0
                    ? '${formatMoney(amount)} of ${formatMoney(cap)} cap'
                    : formatMoney(amount),
                style: AppText.small.w6.tabular.tint(
                  overCap ? Barako.warning : Barako.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SalapifyProgressBar(
            value: frac,
            size: ProgressBarSize.micro,
            semanticsLabel: '${w['label']} spending',
            color: overCap ? Barako.warning : Barako.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _quickAdd(BuildContext context, QuickAdd item) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = store.data;
    final def = (data['settings'] is Map
        ? (data['settings'] as Map)['defaultAccountId']
        : null);
    final hasDefault =
        def is String &&
        def.isNotEmpty &&
        (data['accounts'] as List? ?? const []).any(
          (a) => a is Map && a['id'] == def,
        );
    String? categoryId;
    for (final c in (data['categories'] as List? ?? const [])) {
      if (c is Map && c['name'] == item.label) {
        categoryId = (c['id'] ?? '').toString();
        break;
      }
    }
    final now = DateTime.now();
    final id = newEntryId(now);
    final tx = <String, dynamic>{
      'id': id,
      'type': 'expense',
      'label': item.label,
      'amount': item.amount,
      'date': now.toIso8601String().substring(0, 10),
      if (hasDefault) 'accountId': def,
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
    };
    try {
      await store.addEntry(tx);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${item.label} ${formatMoney(item.amount)} logged.'),
          duration: const Duration(seconds: 4),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await store.removeEntry(id);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not undo, the entry is still logged. $e',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not log, nothing was changed. $e')),
      );
    }
  }

  Future<void> _editLimit(BuildContext context) async {
    final settings = store.data['settings'] is Map
        ? store.data['settings'] as Map
        : const {};
    final current = settings['monthlyLimit'];
    final controller = TextEditingController(
      text: current is num && current > 0
          ? (current % 1 == 0 ? current.toInt().toString() : current.toString())
          : '',
    );
    final messenger = ScaffoldMessenger.of(context);
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Monthly limit', style: TextStyle(color: Barako.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppText.bodyLg.copyWith(fontSize: 20),
          decoration: InputDecoration(
            prefixText: '$baseCurrencySymbol ',
            prefixStyle: AppText.bodyLg
                .copyWith(fontSize: 20)
                .tint(Barako.muted),
            hintText: '15000',
            hintStyle: TextStyle(color: Barako.faint),
          ),
        ),
        actions: [
          if (current is num && current > 0)
            TextButton(
              // 0 clears the limit; the store treats it as none set.
              onPressed: () => Navigator.of(dialogContext).pop(0.0),
              child: Text(
                'Remove limit',
                style: TextStyle(color: Barako.warning),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () {
              final v = parseAmount(controller.text);
              if (v != null) Navigator.of(dialogContext).pop(v);
            },
            child: Text('Save', style: TextStyle(color: Barako.primary)),
          ),
        ],
      ),
    );
    // Deliberately NOT disposed here: the dialog's exit animation still
    // paints the TextField for a few frames after pop, and touching a
    // disposed controller throws. A short-lived listenerless controller is
    // safe to leave to the garbage collector.
    if (value == null) return;
    try {
      await store.setMonthlyLimit(value);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save the limit, nothing was changed. $e'),
        ),
      );
    }
  }
}
