// Budget: the daily driver. The monthly limit with optional carry over
// (numbers from the golden-verified budget engine), one-tap quick adds that
// keep balances honest through the ledger engine (remembered account,
// category tagging by label match) with an Undo snackbar, and the where it
// went top groups where a Pro cap turns the bar into a cap meter.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/budget.dart' as budget;
import '../theme.dart';
import 'log_sheet.dart' show newEntryId, parseAmount, showLogSheet;
import 'overview.dart' show formatMoney;

/// The RN default quick adds, shown when the imported settings carry none.
const List<({String label, num amount})> _defaultQuickAdds = [
  (label: 'Food', amount: 150),
  (label: 'Transport', amount: 50),
  (label: 'Coffee', amount: 120),
  (label: 'Load', amount: 100),
];

class BudgetScreen extends StatelessWidget {
  final SalapifyStore store;
  const BudgetScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final data = store.data;
    final ref = DateTime.now();
    final summary = budget.budgetSummary(data, ref);
    final went = budget.whereItWent(data, ref);
    final rows = (went['rows'] as List).cast<Map<String, dynamic>>();
    final max = went['max'] as double;

    final rawQuickAdds = (data['settings'] is Map
            ? (data['settings'] as Map)['quickAdds']
            : null) as List?;
    // Only positive finite amounts become chips: a hand-edited backup with a
    // negative quick add would otherwise log money BACK on every tap.
    final quickAdds = <({String label, num amount})>[
      for (final q in rawQuickAdds ?? const [])
        if (q is Map &&
            q['label'] is String &&
            q['amount'] is num &&
            (q['amount'] as num) > 0 &&
            (q['amount'] as num).isFinite)
          (label: q['label'] as String, amount: q['amount'] as num),
    ];
    final adds = quickAdds.isNotEmpty ? quickAdds : _defaultQuickAdds;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Text('BUDGET',
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3)),
            const SizedBox(height: 20),
            _limitCard(context, summary),
            if (store.canWrite) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('QUICK ADD',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final q in adds)
                            ActionChip(
                              label: Text(
                                  '${q.label}  ${formatMoney(q.amount)}'),
                              backgroundColor: Barako.background,
                              labelStyle: TextStyle(
                                  color: Barako.text,
                                  fontWeight: FontWeight.w600),
                              side:
                                  BorderSide(color: Barako.border),
                              onPressed: () => _quickAdd(context, q),
                            ),
                          ActionChip(
                            label: const Text('+ Custom'),
                            backgroundColor: Barako.background,
                            labelStyle: TextStyle(
                                color: Barako.primaryText,
                                fontWeight: FontWeight.w700),
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
            if (rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WHERE IT WENT',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 10),
                      for (final w in rows) _catRow(w, max),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
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
                  child: Text('THIS MONTH',
                      style: TextStyle(
                          color: Barako.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                ),
                if (store.canWrite)
                  InkWell(
                    onTap: () => _editLimit(context),
                    child: Padding(
                      // A real 44dp tap target, not just the text.
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 4),
                      child: Text(limit > 0 ? 'Change limit' : 'Set a limit',
                          style: TextStyle(
                              color: Barako.primaryText,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (limit > 0) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatMoney(spent),
                      style: TextStyle(
                          fontFamily: Barako.displayFont,
                          color: over ? Barako.warning : Barako.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ])),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 6),
                    child: Text('of ${formatMoney(limit)}',
                        style: TextStyle(
                            color: Barako.muted, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 8,
                  backgroundColor: Barako.border,
                  color: over ? Barako.warning : Barako.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                over
                    ? 'Over by ${formatMoney(spent - limit)}. No shame, just ease the biggest category below.'
                    : '${formatMoney(remaining)} left this month.'
                        '${carried > 0 ? ' Includes ${formatMoney(carried)} carried over from last month\'s unspent budget.' : ''}',
                style: TextStyle(
                    color: over ? Barako.warning : Barako.muted,
                    fontSize: 13,
                    height: 1.4),
              ),
            ] else ...[
              Text(formatMoney(spent),
                  style: TextStyle(
                      color: Barako.text,
                      fontFamily: Barako.displayFont,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 4),
              Text(
                  'Spent so far this month. Set a monthly limit and the bar will keep you honest.',
                  style: TextStyle(color: Barako.muted, fontSize: 13)),
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
                child: Text(w['label'] as String,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: Barako.text, fontSize: 13)),
              ),
              Text(
                  cap > 0
                      ? '${formatMoney(amount)} of ${formatMoney(cap)} cap'
                      : formatMoney(amount),
                  style: TextStyle(
                      color: overCap ? Barako.warning : Barako.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 5,
              backgroundColor: Barako.border,
              color: overCap ? Barako.warning : Barako.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAdd(
      BuildContext context, ({String label, num amount}) item) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = store.data;
    final def = (data['settings'] is Map
        ? (data['settings'] as Map)['defaultAccountId']
        : null);
    final hasDefault = def is String &&
        def.isNotEmpty &&
        (data['accounts'] as List? ?? const [])
            .any((a) => a is Map && a['id'] == def);
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
      if (categoryId != null && categoryId.isNotEmpty)
        'categoryId': categoryId,
    };
    try {
      await store.addEntry(tx);
      messenger.showSnackBar(SnackBar(
        content: Text('${item.label} ${formatMoney(item.amount)} logged.'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await store.removeEntry(id);
            } catch (e) {
              messenger.showSnackBar(SnackBar(
                  content:
                      Text('Could not undo, the entry is still logged. $e')));
            }
          },
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Could not log, nothing was changed. $e')));
    }
  }

  Future<void> _editLimit(BuildContext context) async {
    final settings =
        store.data['settings'] is Map ? store.data['settings'] as Map : const {};
    final current = settings['monthlyLimit'];
    final controller = TextEditingController(
        text: current is num && current > 0
            ? (current % 1 == 0
                ? current.toInt().toString()
                : current.toString())
            : '');
    final messenger = ScaffoldMessenger.of(context);
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Monthly limit',
            style: TextStyle(color: Barako.text)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: Barako.text, fontSize: 20),
          decoration: InputDecoration(
            prefixText: '₱ ',
            prefixStyle: TextStyle(color: Barako.muted, fontSize: 20),
            hintText: '15000',
            hintStyle: TextStyle(color: Barako.faint),
          ),
        ),
        actions: [
          if (current is num && current > 0)
            TextButton(
                // 0 clears the limit; the store treats it as none set.
                onPressed: () => Navigator.of(dialogContext).pop(0.0),
                child: Text('Remove limit',
                    style: TextStyle(color: Barako.warning))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  Text('Cancel', style: TextStyle(color: Barako.muted))),
          TextButton(
              onPressed: () {
                final v = parseAmount(controller.text);
                if (v != null) Navigator.of(dialogContext).pop(v);
              },
              child: Text('Save',
                  style: TextStyle(color: Barako.primary))),
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
      messenger.showSnackBar(SnackBar(
          content: Text('Could not save the limit, nothing was changed. $e')));
    }
  }
}
