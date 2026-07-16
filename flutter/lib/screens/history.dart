// History: every entry, grouped under date headers (Today, Yesterday, then
// the date) with a type filter chip row, per the UX critique of the RN
// screen. Swipe to delete with a 5 second undo replaces the scary confirm
// dialog, but ONLY for plain income and expense rows; transfers, debt legs,
// adjustments, and utang-linked rows stay read-only here so the sync
// contract with the receivables engine can never be broken from this screen.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;

const _filters = [
  ('all', 'All'),
  ('expense', 'Expenses'),
  ('income', 'Income'),
  ('records', 'Records'),
];

/// Only a plain logged income or expense may be swiped away: no flow legs,
/// no utang-sourced income, no record rows, and nothing a payable or
/// receivable payment points at through txnId (the legacy payable payment
/// posts a plain expense with no source stamp, so the txnId link is the only
/// thing marking it as spoken for). A row with no usable id is not deletable
/// either: the store could never find it, and the swipe would ghost the row.
bool isDeletable(Map<String, dynamic> t, {Set<String> lockedIds = const {}}) {
  final id = t['id'];
  if (id is! String || id.isEmpty) return false;
  if (lockedIds.contains(id)) return false;
  final type = t['type'];
  if (type != 'income' && type != 'expense') return false;
  if (t['flow'] != null) return false;
  if (t['source'] != null) return false;
  return true;
}

/// Every transaction id referenced by a payable or receivable payment.
Set<String> ledgerLinkedTxnIds(Map<String, dynamic> data) {
  final ids = <String>{};
  for (final key in ['payables', 'receivables']) {
    final list = data[key];
    if (list is! List) continue;
    for (final item in list) {
      if (item is! Map) continue;
      final payments = item['payments'];
      if (payments is! List) continue;
      for (final p in payments) {
        if (p is Map) {
          final txnId = p['txnId'];
          if (txnId is String && txnId.isNotEmpty) ids.add(txnId);
        }
      }
    }
  }
  return ids;
}

String dateHeader(String iso, DateTime now) {
  final today =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final yesterdayDt = now.subtract(const Duration(days: 1));
  final yesterday =
      '${yesterdayDt.year.toString().padLeft(4, '0')}-${yesterdayDt.month.toString().padLeft(2, '0')}-${yesterdayDt.day.toString().padLeft(2, '0')}';
  if (iso == today) return 'Today';
  if (iso == yesterday) return 'Yesterday';
  return iso;
}

class HistoryScreen extends StatefulWidget {
  final SalapifyStore store;
  const HistoryScreen({super.key, required this.store});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final all = (widget.store.data['transactions'] as List)
        .cast<Map<String, dynamic>>();
    final locked = ledgerLinkedTxnIds(widget.store.data);
    // Keep the insertion index as the same-day tie-break (newest log first,
    // matching the RN app). List.sort alone is not stable, so without it rows
    // logged on the same day would shuffle between rebuilds.
    final indexed = <(Map<String, dynamic>, int)>[];
    for (var i = 0; i < all.length; i++) {
      final t = all[i];
      final keep = filter == 'all' ||
          (filter == 'records'
              ? t['type'] != 'income' && t['type'] != 'expense'
              : t['type'] == filter);
      if (keep) indexed.add((t, i));
    }
    indexed.sort((a, b) {
      final byDate = (b.$1['date'] ?? '')
          .toString()
          .compareTo((a.$1['date'] ?? '').toString());
      if (byDate != 0) return byDate;
      return b.$2.compareTo(a.$2);
    });
    final txs = [for (final e in indexed) e.$1];

    final now = DateTime.now();
    // Rows interleaved with headers, newest day first.
    final items = <Widget>[];
    String? lastHeader;
    for (final t in txs) {
      final header = dateHeader((t['date'] ?? '').toString(), now);
      if (header != lastHeader) {
        lastHeader = header;
        items.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(header,
              style: const TextStyle(
                  color: Barako.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ));
      }
      items.add(_row(t, locked));
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('HISTORY',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (value, label) in _filters) ...[
                      ChoiceChip(
                        label: Text(label),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                        selectedColor: Barako.primary,
                        backgroundColor: Barako.card,
                        labelStyle: TextStyle(
                            color: filter == value
                                ? Barako.onPrimary
                                : Barako.textSecondary,
                            fontWeight: FontWeight.w600),
                        side: const BorderSide(color: Barako.border),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: txs.isEmpty
                    ? _empty(all.isEmpty)
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: items),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(bool trulyEmpty) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(trulyEmpty ? 'Nothing here yet' : 'No entries match',
                style: const TextStyle(
                    color: Barako.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                trulyEmpty
                    ? 'Entries you log will show up here.'
                    : 'Try a different filter.',
                style: const TextStyle(color: Barako.muted, fontSize: 13)),
            if (!trulyEmpty) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() => filter = 'all'),
                child: const Text('Show all',
                    style: TextStyle(color: Barako.primary)),
              ),
            ],
          ],
        ),
      );

  Widget _row(Map<String, dynamic> t, Set<String> locked) {
    final type = (t['type'] ?? '').toString();
    final isIncome = type == 'income';
    final record = type != 'income' && type != 'expense';
    final amount = t['amount'] is num ? (t['amount'] as num).toDouble() : 0.0;
    final label = (t['label'] ?? '').toString().isEmpty
        ? (record ? type : (isIncome ? 'Income' : 'Expense'))
        : (t['label']).toString();

    final row = Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Barako.text, fontSize: 15)),
                  if (record)
                    const Text('Record of a money move, read-only here',
                        style:
                            TextStyle(color: Barako.faint, fontSize: 11)),
                ],
              ),
            ),
            Text('${isIncome ? '+' : record ? '' : '-'}${formatMoney(amount)}',
                style: TextStyle(
                    color: isIncome
                        ? Barako.primary
                        : record
                            ? Barako.muted
                            : Barako.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );

    if (!isDeletable(t, lockedIds: locked)) return row;

    // The delete runs inside confirmDismiss, so the row only leaves the tree
    // AFTER the store really removed and persisted it. Doing the work in
    // onDismissed instead would drop the row from the tree first and then
    // throw "dismissed Dismissible still part of the tree" whenever the
    // delete failed or the id did not match anything.
    return Dismissible(
      key: ValueKey(t['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: Barako.warning, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final removed =
              await widget.store.removeEntry((t['id'] ?? '').toString());
          if (removed == null) return false;
          messenger.showSnackBar(SnackBar(
            content: const Text(
                'Deleted. A linked account got its money back.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                try {
                  await widget.store.addEntry(removed);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(
                      content: Text(
                          'Could not restore the entry, it is still deleted. $e')));
                }
              },
            ),
          ));
          return true;
        } catch (e) {
          messenger.showSnackBar(SnackBar(
              content: Text('Could not delete, nothing was changed. $e')));
          return false;
        }
      },
      child: row,
    );
  }
}
