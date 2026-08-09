// History: every entry, grouped under date headers (Today, Yesterday, then
// the date) with a type filter chip row, per the UX critique of the RN
// screen. Swipe to delete with a 5 second undo replaces the scary confirm
// dialog, but ONLY for plain income and expense rows; transfers, debt legs,
// adjustments, and utang-linked rows stay read-only here so the sync
// contract with the receivables engine can never be broken from this screen.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/search.dart' as search;
import '../money/period.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/choice_chip.dart';
import '../widgets/period_selector.dart';
import '../widgets/empty_state.dart';
import '../widgets/screen_header.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/amount_text.dart';
import '../widgets/pressable_scale.dart';
import 'overview.dart' show formatMoney, prettyDay;
import 'edit_sheet.dart' show showEntrySheet;
import 'log_sheet.dart' show showLogSheet;

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

  /// Injected so a test can pin what "this month" means. Without it the
  /// selector fell back to DateTime.now while the fixtures were hard coded to
  /// July 2026, so three tests were going to start failing on 1 August and
  /// turn the branch check red on main. The generator header next door already
  /// states the rule they broke: an answer that changes with the day it was
  /// run is not a fixed answer.
  final DateTime Function()? clock;

  /// The slice to open on. Reports and Search push this screen after the
  /// person has already narrowed to a month, so they pass their own.
  final Period? initialPeriod;
  const HistoryScreen({
    super.key,
    required this.store,
    this.initialQuery = '',
    this.pushed = false,
    this.onMenu,
    this.clock,
    this.initialPeriod,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String filter = 'all';

  /// The time slice. Opens on ALL TIME rather than this month, deliberately:
  /// Activity has always shown everything, and starting it filtered would make
  /// entries the person logged last month look deleted. The selector is an
  /// addition to the screen, not a new default for it.
  ///
  /// A caller that has ALREADY narrowed, like a Reports month row, passes its
  /// own slice instead: tapping "Food ₱4,200" under June and landing on a list
  /// of Food from every month shows numbers that visibly do not add up, with
  /// nothing on screen explaining why.
  late Period period = widget.initialPeriod ?? const Period.all();

  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// The latest date any entry carries, so the stepper can reach it.
  ///
  /// QA's case: a CSV imported with the wrong day/month order throws a slice
  /// of rows into the future (12/07/2026 read as month first becomes December
  /// 7th). The forward arrow stops at today, so those rows exist, show under
  /// All time, and the stepper physically refuses to walk to them. The engine
  /// rule is golden locked and stays; the SCREEN is allowed to know its own
  /// data goes further.
  String? _lastEntryDate(List<Map<String, dynamic>> all) {
    String? latest;
    for (final t in all) {
      final d = t['date'];
      if (d is! String || d.length < 7) continue;
      if (latest == null || d.compareTo(latest) > 0) latest = d;
    }
    return latest;
  }

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
      final keepDate = inPeriod(t['date'], period);
      if (keepType && keepText && keepDate) indexed.add((t, i));
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
    // ONE card per day, rows separated by hairlines, headers outside. A card
    // per transaction gave a phone six rows and twelve borders per screen;
    // the ledger shape roughly doubles the rows in view and lets the eye run
    // down one column instead of hopping islands. The audit's Phase 4 line
    // ("grouped-day list physics") lands here.
    final items = <Widget>[];
    var group = <Widget>[];
    void flushGroup() {
      if (group.isEmpty) return;
      items.add(
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, r) in group.indexed) ...[
                if (i > 0) Divider(height: 1, color: Barako.border),
                r,
              ],
            ],
          ),
        ),
      );
      group = [];
    }

    String? lastHeader;
    for (final t in txs) {
      final header = dateHeader((t['date'] ?? '').toString(), now);
      if (header != lastHeader) {
        flushGroup();
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
      group.add(_row(t, locked, maps));
    }
    flushGroup();

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
          ? AppBar(title: Text('Activity', style: AppText.title))
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
        // The same 8dp outer top the other four tabs give their header, so
        // Activity stops sitting 8 pixels higher than its siblings. This was
        // the one tab whose header wrap had no top padding at all.
        padding: const EdgeInsets.fromLTRB(Gap.gutter, Gap.sm, Gap.gutter, 0),
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
              style: AppText.bodyLg,
              decoration: InputDecoration(
                hintText: 'Filter entries, like jollibee or 1500',
                hintStyle: TextStyle(color: Barako.faint),
                prefixIcon: Icon(
                  salapifyIcon('search'),
                  color: Barako.faint,
                  size: 20,
                ),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(
                          salapifyIcon('close'),
                          color: Barako.muted,
                          size: 18,
                        ),
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
            PeriodSelector(
              period: period,
              allowAll: true,
              clock: _now,
              lastEntryDate: _lastEntryDate(all),
              onChange: (p) => setState(() => period = p),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // The shared chip: the theme owns the skin, the widget owns
                  // the change-only click, so this row can never buzz or
                  // dress differently from every other chip group.
                  for (final (value, label) in _filters) ...[
                    SalapifyChoiceChip(
                      label: label,
                      selected: filter == value,
                      onSelected: (_) => setState(() => filter = value),
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
    padding: const EdgeInsets.fromLTRB(Gap.gutter, Gap.xs, Gap.gutter, Gap.xl),
    children: [
      trulyEmpty
          ? EmptyState(
              icon: 'receipt',
              showPan: true,
              title: 'Your money story starts with one entry',
              body:
                  'Every expense and every peso in shows up here, newest '
                  'first, the moment you log it. This is also where you '
                  'search and filter once there is something to look through.',
              actionLabel: 'Log your first entry',
              onAction: () => showLogSheet(context, widget.store),
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
                // The period too. It used to be left alone, so stepping back
                // to an empty month and tapping the button that promises to
                // show everything left the list empty and the month chip
                // still set. The sentence beside it says the entries are just
                // hidden, which then read as a lie.
                period = const Period.all();
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
    // The label fallback is capitalized: an imported transfer with no label
    // used to print a lowercase machine word ("transfer") as its title.
    final typeAsTitle = type.isEmpty
        ? 'Record'
        : '${type[0].toUpperCase()}${type.substring(1)}';
    // 'Entry' is sanitizeData's filler for a blank label; on a record row the
    // type makes a better title than the filler ("Transfer", not "Entry").
    final rawLabel = (t['label'] ?? '').toString();
    final label = rawLabel.isEmpty || (record && rawLabel == 'Entry')
        ? (record ? typeAsTitle : (isIncome ? 'Income' : 'Expense'))
        : rawLabel;
    // A money move names its two ends from the entry's own account ids, so
    // the sentence survives an import or a missing label. The old subline
    // ("Record of a money move, read-only here") repeated the same lesson on
    // every record row and named no accounts; the receipt behind the tap
    // carries the read-only explanation.
    final moveFrom = maps.acct[(t['transferFromId'] ?? '').toString()];
    final moveTo = maps.acct[(t['transferToId'] ?? '').toString()];
    final recordLine = moveFrom != null && moveTo != null
        ? 'From $moveFrom to $moveTo'
        : 'Money move';

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
      // 14 vertical came down to 10 with the ledger shape; the day card's own
      // padding stopped double-counting the air between rows.
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body),
                if (record)
                  Row(
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          salapifyIcon('swap'),
                          size: 12,
                          color: Barako.faint,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          recordLine,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.micro.w4.tint(Barako.faint),
                        ),
                      ),
                    ],
                  )
                else if (rowContext.isNotEmpty)
                  // The context beats the tap hint when both apply: "GCash ·
                  // Food" tells you which row this is, and tappability is
                  // one experiment away. The hints remain for rows with no
                  // context to show.
                  Text(rowContext, style: AppText.micro.w4)
                else if (showSplitHint)
                  Text('Tap to open, edit, or split', style: AppText.micro.w4)
                else if (editable)
                  Text(
                    'Tap to open',
                    style: AppText.micro.w4.tint(Barako.faint),
                  ),
              ],
            ),
          ),
          if (showSplitHint) ...[
            ExcludeSemantics(
              child: Icon(salapifyIcon('split'), size: 16, color: Barako.muted),
            ),
            const SizedBox(width: 10),
          ],
          // The shared row face. Direction is carried by the SIGN (a real
          // negative for an expense, an explicit plus for income), never by
          // tint alone, and a record stays unsigned and muted: a move is
          // neither in nor out.
          record
              ? AmountText(amount, role: AmountRole.row, tint: Barako.muted)
              : isIncome
              ? AmountText(
                  amount,
                  role: AmountRole.row,
                  signed: true,
                  tint: Barako.primary,
                )
              : AmountText(
                  -amount,
                  role: AmountRole.row,
                  tint: Barako.textSecondary,
                ),
        ],
      ),
    );

    // Every row is tappable, RN semantics: editable rows open the edit form
    // (with split reachable inside it), record and utang-linked rows open a
    // read-only explainer saying why not and where to manage them.
    //
    // The Semantics label is the WHOLE row as one sentence, money included:
    // "Edit Jollibee" left a screen-reader user hearing a button with no
    // amount and no direction. The visuals are excluded so nothing is read
    // twice.
    final spokenRow =
        '$label, '
        '${record
            ? 'money move'
            : isIncome
            ? 'income'
            : 'expense'}, '
        '${formatMoney(amount)}'
        '${record
            ? ', $recordLine'
            : rowContext.isNotEmpty
            ? ', $rowContext'
            : ''}. '
        '${editable ? 'Opens the receipt, with edit and delete.' : 'Opens the details.'}';
    final row = PressableScale(
      child: Semantics(
        button: true,
        label: spokenRow,
        child: ExcludeSemantics(
          child: InkWell(
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
        // No radius of its own: the day card clips its children, so the
        // reveal hugs the row it belongs to.
        color: Barako.warning,
        // Palette-driven ink so the icon clears contrast on the warning
        // fill in every mood (white sat at 2.97:1 in the dark moods).
        child: Icon(salapifyIcon('delete'), color: Barako.onPrimary),
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
              persist: false,
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
          // The save moment is felt, not just shown, the same word the log
          // and edit sheets speak: a committed delete moves a balance back.
          // The failure and null paths above stay silent on purpose.
          Haptics.moneyWritten();
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
