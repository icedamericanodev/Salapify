// History: every entry, grouped under date headers (Today, Yesterday, then
// the date) with a type filter chip row, per the UX critique of the RN
// screen. Swipe to delete with a 5 second undo replaces the scary confirm
// dialog, but ONLY for plain income and expense rows; transfers, debt legs,
// adjustments, and utang-linked rows stay read-only here so the sync
// contract with the receivables engine can never be broken from this screen.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/search.dart' as search;
import '../theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_header.dart';
import 'overview.dart' show formatMoney, prettyDay;
import 'edit_sheet.dart' show showEntrySheet;

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
  // Human, not ISO: "Sat, Jul 12" instead of "2026-07-12". A date formatter
  // existed one import away (prettyDay) the whole time this printed raw
  // strings at people. Junk in, junk out, same contract as prettyDay: an
  // unparseable date renders unchanged rather than throwing.
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[d.weekday - 1]}, ${prettyDay(iso)}';
}

class HistoryScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Seed the text filter (e.g. from a global search result). When set, the
  /// screen also shows a back-capable app bar because it was pushed as its own
  /// route rather than shown as the History tab.
  final String initialQuery;
  final bool pushed;
  final VoidCallback? onMenu;
  const HistoryScreen({
    super.key,
    required this.store,
    this.initialQuery = '',
    this.pushed = false,
    this.onMenu,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = 'all';
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the store so a swipe delete (or any mutation) rebuilds the
    // list. The History tab is already under main's ListenableBuilder, but the
    // pushed-from-search route is not, so it needs its own here.
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final all = (widget.store.data['transactions'] as List)
        .cast<Map<String, dynamic>>();
    final locked = ledgerLinkedTxnIds(widget.store.data);
    // Text filter uses the golden-locked txMatches so a row found in global
    // search stays found here, and category/account names match too.
    final q = _query.text;
    final maps = search.transactionNameMaps(widget.store.data);
    // Keep the insertion index as the same-day tie-break (newest log first,
    // matching the RN app). List.sort alone is not stable, so without it rows
    // logged on the same day would shuffle between rebuilds.
    final indexed = <(Map<String, dynamic>, int)>[];
    for (var i = 0; i < all.length; i++) {
      final t = all[i];
      final keepType =
          filter == 'all' ||
          (filter == 'records'
              ? t['type'] != 'income' && t['type'] != 'expense'
              : t['type'] == filter);
      final keepText =
          q.trim().isEmpty || search.txMatches(t, q, maps.cat, maps.acct);
      if (keepType && keepText) indexed.add((t, i));
    }
    indexed.sort((a, b) {
      final byDate = (b.$1['date'] ?? '').toString().compareTo(
        (a.$1['date'] ?? '').toString(),
      );
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
        items.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            // The shared kicker voice, not a third hand-rolled variant. The
            // sweep left exactly two uppercase treatments in the app: the
            // outside kicker and the in-card caramel kicker.
            child: Text(header, style: Barako.kickerStyle),
          ),
        );
      }
      items.add(_row(t, locked, maps));
    }

    // Two shapes, one screen. As a TAB it is a plain body inside the shell's
    // Scaffold, like every other destination. Pushed from Search or Reports it
    // still needs its own Scaffold and an AppBar to carry the back button.
    //
    // Keeping the Scaffold in the tab case would nest one inside the shell's
    // for no reason, and its SafeArea would inset a second time under the nav
    // bar.
    if (!widget.pushed) return _body(items, txs, all);
    return Scaffold(
      appBar: widget.pushed
          ? AppBar(
              backgroundColor: Barako.background,
              foregroundColor: Barako.text,
              title: Text(
                'Activity',
                style: TextStyle(
                  color: Barako.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
      body: _body(items, txs, all),
    );
  }

  /// The screen's content, shared by the tab shape and the pushed shape.
  ///
  /// The three lists are passed rather than recomputed: they come from one
  /// filter-and-sort pass in build(), and doing it twice would be both slower
  /// and a chance for the two shapes to disagree.
  Widget _body(
    List<Widget> items,
    List<Map<String, dynamic>> txs,
    List<Map<String, dynamic>> all,
  ) {
    return SafeArea(
      top: !widget.pushed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The last hand-rolled title in the app. It was 26/w800 with 3 of
            // letter spacing, the pre-ScreenHeader treatment that every other
            // tab moved off, so "History" sat shouting above a sentence-case
            // nav label saying the same word. Now it is the shared header,
            // which also gives it the Menu action for free.
            if (!widget.pushed) ScreenHeader('Activity', onMenu: widget.onMenu),
            const SizedBox(height: 12),
            TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: TextStyle(color: Barako.text, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Filter entries, like jollibee or 1500',
                hintStyle: TextStyle(color: Barako.faint),
                prefixIcon: Icon(Icons.search, color: Barako.faint, size: 20),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, color: Barako.muted, size: 18),
                        tooltip: 'Clear filter',
                        onPressed: () => setState(() => _query.clear()),
                      ),
                filled: true,
                fillColor: Barako.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Barako.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Barako.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Barako.primary),
                ),
              ),
            ),
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
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(color: Barako.border),
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
                      children: items,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Top-aligned in a scroll view rather than centred in the leftover space.
  // Centred, it floated at whatever height the filter bar happened to leave,
  // which read as an accident rather than a decision, and it moved as soon as
  // a chip wrapped to a second line.
  Widget _empty(bool trulyEmpty) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
    children: [
      trulyEmpty
          ? EmptyState(
              icon: 'receipt',
              showPan: true,
              title: 'Nothing here yet',
              body:
                  'Every expense and every peso in shows up here, newest '
                  'first, the moment you log it. This is also where you '
                  'search and filter once there is something to look through.',
            )
          : EmptyState(
              icon: 'inspect',
              title: 'No entries match',
              body:
                  'Nothing fits this search and filter. The entries are still '
                  'there, they are just hidden by what is selected right now.',
              actionLabel: 'Show all',
              onAction: () => setState(() {
                filter = 'all';
                _query.clear();
              }),
            ),
    ],
  );

  Widget _row(
    Map<String, dynamic> t,
    Set<String> locked,
    ({Map<String, String> cat, Map<String, String> acct}) maps,
  ) {
    // The context line: which account and category this row belongs to,
    // from the maps the text filter already computes. Two rows both named
    // "Expense" for ₱500 were indistinguishable without it.
    final rowContext = [
      ?maps.acct[(t['accountId'] ?? '').toString()],
      ?maps.cat[(t['categoryId'] ?? '').toString()],
    ].join(' · ');
    final type = (t['type'] ?? '').toString();
    final isIncome = type == 'income';
    final record = type != 'income' && type != 'expense';
    final amount = t['amount'] is num ? (t['amount'] as num).toDouble() : 0.0;
    final label = (t['label'] ?? '').toString().isEmpty
        ? (record ? type : (isIncome ? 'Income' : 'Expense'))
        : (t['label']).toString();

    // A plain expense you fronted can be split with friends. It must clear the
    // SAME safety gate as delete (isDeletable): a real, unlocked expense with
    // no flow leg, no source stamp, and nothing a payable or receivable payment
    // points at, plus no debt link. Splitting a ledger-linked or debt-interest
    // expense would desync the payable/debt to ledger contract and invent money
    // (a linked payment would later reverse a now-smaller txn). Already-split
    // expenses (shrunk to your share) can be split again on the remainder.
    final splittable =
        isDeletable(t, lockedIds: locked) &&
        t['type'] == 'expense' &&
        amount > 0 &&
        t['debtId'] == null;
    // Editable under the exact gate delete uses: a plain unlocked income or
    // expense. Everything else opens a read-only explainer, which is one
    // step STRICTER than RN (whose type-only rule let legacy utang legs
    // through into the editor by accident).
    final editable = isDeletable(t, lockedIds: locked);
    // Advertise the split affordance only on rows not yet split; an already
    // split expense stays tappable (to split the remainder) but without the
    // loud hint, so the list does not repeat the CTA on every single row.
    final alreadySplit = t['splitActivityId'] != null;
    final showSplitHint = splittable && !alreadySplit;

    final rowContent = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Barako.text, fontSize: 15)),
                if (record)
                  Text(
                    'Record of a money move, read-only here',
                    style: TextStyle(color: Barako.faint, fontSize: 11),
                  )
                else if (rowContext.isNotEmpty)
                  // The context beats the tap hint when both apply: "GCash ·
                  // Food" tells you which row this is, and tappability is
                  // one experiment away. The hints remain for rows with no
                  // context to show.
                  Text(
                    rowContext,
                    style: TextStyle(color: Barako.muted, fontSize: 11),
                  )
                else if (showSplitHint)
                  Text(
                    'Tap to edit or split with friends',
                    style: TextStyle(color: Barako.muted, fontSize: 11),
                  )
                else if (editable)
                  Text(
                    'Tap to edit',
                    style: TextStyle(color: Barako.faint, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (showSplitHint) ...[
            ExcludeSemantics(
              child: Icon(Icons.call_split, size: 16, color: Barako.muted),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            '${isIncome
                ? '+'
                : record
                ? ''
                : '-'}${formatMoney(amount)}',
            style: TextStyle(
              color: isIncome
                  ? Barako.primary
                  : record
                  ? Barako.muted
                  : Barako.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    // Every row is tappable, RN semantics: editable rows open the edit form
    // (with split reachable inside it), record and utang-linked rows open a
    // read-only explainer saying why not and where to manage them.
    final row = Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Semantics(
        button: true,
        label: editable ? 'Edit $label' : 'About $label',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => showEntrySheet(
            context,
            widget.store,
            t,
            editable: editable,
            splittable: splittable,
            // Tells the explainer WHY a plain-looking row is locked, so a
            // CSV import or an interest row stops being told it is "part of
            // an utang" (QA found exactly that).
            utangLinked: locked.contains((t['id'] ?? '').toString()),
          ),
          child: rowContent,
        ),
      ),
    );

    if (!editable) return row;

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
          color: Barako.warning,
          borderRadius: BorderRadius.circular(12),
        ),
        // Palette-driven ink so the icon clears contrast on the warning
        // fill in every mood (white sat at 2.97:1 in the dark moods).
        child: Icon(Icons.delete_outline, color: Barako.onPrimary),
      ),
      confirmDismiss: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final removed = await widget.store.removeEntry(
            (t['id'] ?? '').toString(),
          );
          if (removed == null) return false;
          // Only claim a balance moved back when the entry was actually
          // linked to an account that still exists; the engine moves a
          // balance only under that same condition, so the message never
          // over-claims.
          final acctId = removed['accountId'];
          final wasLinked =
              acctId is String &&
              acctId.isNotEmpty &&
              (widget.store.data['accounts'] as List? ?? const []).any(
                (a) => a is Map && a['id'] == acctId,
              );
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                wasLinked
                    ? 'Deleted. The linked account got its money back.'
                    : 'Deleted.',
              ),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    await widget.store.addEntry(removed);
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Could not restore the entry, it is still deleted. $e',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          );
          return true;
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Could not delete, nothing was changed. $e'),
            ),
          );
          return false;
        }
      },
      child: row,
    );
  }
}
