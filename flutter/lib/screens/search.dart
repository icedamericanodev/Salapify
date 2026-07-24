// Global search, reached from the Overview header. Type anything, like a place,
// a name, a category, or an amount, and it finds matching entries, utang,
// debts, goals, and notes across the device. The matching logic lives in the
// golden-locked money/search.dart so results match the live app. Tapping a
// group opens the screen that holds it.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/search.dart' as search;
import '../theme.dart';
import 'debts.dart';
import 'goals.dart';
import 'history.dart';
import 'notes.dart';

const _groupIcon = <String, IconData>{
  'transactions': Icons.receipt_long_outlined,
  'utang': Icons.handshake_outlined,
  'debts': Icons.credit_card_outlined,
  'goals': Icons.savings_outlined,
  'notes': Icons.sticky_note_2_outlined,
  'accounts': Icons.account_balance_wallet_outlined,
};

// Accounts are searchable in the shared logic, but the Accounts screen is not
// ported to Flutter yet, so that group is hidden here until it lands. Every
// other group has a destination.
const _hiddenKinds = {'accounts'};

class SearchScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Switch a bottom tab (used to open the Entries and Utang tabs, which live
  /// in the tab bar rather than as pushed routes). Null when the host has no
  /// tab switcher, in which case those groups just close search.
  final void Function(int)? onSwitchTab;
  const SearchScreen({super.key, required this.store, this.onSwitchTab});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _openGroup(String kind, String route) {
    switch (kind) {
      case 'transactions':
        // Push History pre-filtered to the same words, so tapping a result
        // actually shows it rather than dumping the user on the full list.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HistoryScreen(
              store: widget.store,
              initialQuery: _query.text,
              pushed: true,
            ),
          ),
        );
        break;
      case 'utang':
        Navigator.of(context).pop();
        widget.onSwitchTab?.call(3);
        break;
      case 'debts':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DebtsScreen(store: widget.store)),
        );
        break;
      case 'goals':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => GoalsScreen(store: widget.store)),
        );
        break;
      case 'notes':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => NotesScreen(store: widget.store)),
        );
        break;
    }
  }

  Color _amountColor(String sign) => sign == '+'
      ? Barako.primaryText
      : sign == '-'
      ? Barako.text
      : Barako.muted;

  @override
  Widget build(BuildContext context) {
    final result = search.search(widget.store.data, _query.text);
    final groups = [
      for (final g in (result['groups'] as List).cast<Map<String, dynamic>>())
        if (!_hiddenKinds.contains(g['kind'])) g,
    ];
    final empty = result['empty'] == true;
    // Count only what we can actually show, so a match in a hidden group does
    // not read as results with nothing beneath it.
    final visibleTotal = groups.fold<int>(0, (s, g) => s + (g['count'] as int));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Search',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: Barako.text, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search anything, like jollibee, Ana, or 1500',
                  hintStyle: TextStyle(color: Barako.faint),
                  prefixIcon: Icon(Icons.search, color: Barako.faint, size: 20),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            color: Barako.muted,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _query.clear()),
                        ),
                  filled: true,
                  fillColor: Barako.card,
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
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
            ),
            Expanded(
              child: empty
                  ? _hint()
                  : visibleTotal == 0
                  ? _noMatches(result['query'] as String)
                  : ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      children: [for (final g in groups) _group(g)],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hint() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Find anything, fast',
            style: TextStyle(
              color: Barako.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search across your entries, IOUs, debts, goals, and notes. Try a name, a place, a category, or an amount.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Barako.muted, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    ),
  );

  Widget _noMatches(String q) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(
            'No matches',
            style: TextStyle(
              color: Barako.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing found for "$q". Try fewer or different words.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Barako.muted, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  Widget _group(Map<String, dynamic> g) {
    final kind = g['kind'] as String;
    final route = g['route'] as String;
    final items = (g['items'] as List).cast<Map<String, dynamic>>();
    final more = g['more'] as int;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(
                  _groupIcon[kind] ?? Icons.search,
                  size: 15,
                  color: Barako.muted,
                ),
                const SizedBox(width: 6),
                Text(
                  (g['title'] as String).toUpperCase(),
                  style: Barako.kickerStyle,
                ),
                const SizedBox(width: 8),
                Text(
                  '${g['count']}',
                  style: TextStyle(color: Barako.faint, fontSize: 12),
                ),
              ],
            ),
          ),
          // Multi-row cards do not use PressableScale (that would scale the
          // whole block on a single row tap); the per-row InkWell ripple
          // carries the feedback, matching the Mindset cards.
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  _row(items[i], kind, route, i > 0),
                if (more > 0)
                  InkWell(
                    onTap: () => _openGroup(kind, route),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Barako.border, width: 0.5),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Text(
                            '$more more in ${g['title']}',
                            style: TextStyle(
                              color: Barako.primaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: Barako.primaryText,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    Map<String, dynamic> it,
    String kind,
    String route,
    bool divided,
  ) {
    final amount = it['amount'];
    final sign = (it['sign'] ?? '').toString();
    final sub = (it['subtitle'] ?? '').toString();
    return InkWell(
      onTap: () => _openGroup(kind, route),
      child: Container(
        decoration: divided
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(color: Barako.border, width: 0.5),
                ),
              )
            : null,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    it['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Barako.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (amount != null) ...[
              const SizedBox(width: 8),
              Text(
                '${sign.isNotEmpty ? '$sign ' : ''}${formatMoneyText((amount as num).toDouble())}',
                style: TextStyle(
                  color: _amountColor(sign),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
