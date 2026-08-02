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
import '../typography.dart';
import '../widgets/salapify_icon.dart';
import 'accounts.dart';
import 'debts.dart';
import 'goals.dart';
import 'history.dart';
import 'notes.dart';
import 'shell.dart';

// Semantic names, resolved through the icon system at draw time. This was a
// const IconData table, which is exactly the private re-implementation of
// salapify_icon.dart that the meaning map exists to absorb.
const _groupIcon = <String, String>{
  'transactions': 'receipt',
  'utang': 'handshake',
  'debts': 'card',
  'goals': 'savings',
  'notes': 'note',
  'accounts': 'wallet',
};

// Every group the shared search logic can return now has a destination in the
// Flutter app, so nothing is hidden. This set used to hold 'accounts' with a
// note that the Accounts screen "is not ported to Flutter yet"; it has been
// ported for a long time (lib/screens/accounts.dart), so the note was stale and
// an account match silently vanished from Search. Kept as an empty set, and as
// the one place to add a kind that genuinely has nowhere to land.
const _hiddenKinds = <String>{};

class SearchScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Switch a bottom tab (used to open the Entries and Utang tabs, which live
  /// in the tab bar rather than as pushed routes). Null when the host has no
  /// tab switcher, in which case those groups just close search.
  final void Function(Destination)? onSwitchTab;

  /// Jumps to the Utang tab showing "Owed to me". Receivables taps land
  /// there specifically; plain onSwitchTab would open the "I owe" segment.
  final VoidCallback? onOpenReceivables;
  final VoidCallback? onOpenPayables;
  const SearchScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onOpenReceivables,
    this.onOpenPayables,
  });

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

  // [focusId] is the id of the specific row that was tapped, used only where a
  // result opens a whole screen rather than a filtered one: an account tap
  // opens Accounts scrolled to and highlighting that account. The group's
  // "N more" link passes null, meaning "just open the screen".
  void _openGroup(String kind, String route, {String? focusId}) {
    switch (kind) {
      case 'accounts':
        // The Accounts screen owns accounts, assets, and debts. It reads the
        // live store, so an account deleted between this result rendering and
        // this tap is simply absent from the list; the screen says so with a
        // gentle note rather than crashing on a stale id.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AccountsScreen(
              store: widget.store,
              onOpenPayables: widget.onOpenPayables,
              focusAccountId: focusId,
            ),
          ),
        );
        break;
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
        // popUntil: Search can be reached from Home directly or from Menu,
        // so its depth is not fixed. A single pop was right for one of those.
        Navigator.of(context).popUntil((r) => r.isFirst);
        // A search hit on a receivable means the "Owed to me" segment.
        if (widget.onOpenReceivables != null) {
          widget.onOpenReceivables!();
        } else {
          widget.onSwitchTab?.call(Destination.utang);
        }
        break;
      case 'debts':
        // A search hit on a debt means the "I owe" segment of the Utang tab.
        // Same popUntil reasoning as the utang case above.
        if (widget.onOpenPayables != null) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          widget.onOpenPayables!();
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DebtsScreen(store: widget.store)),
          );
        }
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
        title: Text('Search', style: AppText.title),
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
                style: AppText.bodyLg,
                decoration: InputDecoration(
                  // Shortened so it FITS. The longer version, "Search
                  // anything, like jollibee, Ana, or 1500", was cut off at
                  // default font size on a 390pt phone, so the one example that
                  // taught you you can search a person's name was the part that
                  // vanished. A hint nobody can finish reading is a hint that
                  // does nothing.
                  hintText: 'Search jollibee, Ana, or 1500',
                  hintStyle: TextStyle(color: Barako.faint),
                  prefixIcon: Icon(salapifyIcon('search'), color: Barako.faint, size: 20),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: Icon(
                            salapifyIcon('close'),
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
            style: AppText.heading.w8,
          ),
          const SizedBox(height: 8),
          Text(
            'Search across your entries, IOUs, debts, goals, and notes. Try a name, a place, a category, or an amount.',
            textAlign: TextAlign.center,
            style: AppText.label.w4.tint(Barako.muted).copyWith(height: 1.5),
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
          SalapifyGlyph('search', size: 28),
          const SizedBox(height: 10),
          Text(
            'No matches',
            style: AppText.heading.w8,
          ),
          const SizedBox(height: 4),
          Text(
            'Nothing found for "$q". Try fewer or different words.',
            textAlign: TextAlign.center,
            style: AppText.small.tint(Barako.muted),
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
                  salapifyIcon(_groupIcon[kind] ?? 'search'),
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
                  style: AppText.caption.tint(Barako.faint),
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
                            style: AppText.small.w6.tint(Barako.primaryText),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            salapifyIcon('forward'),
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
      // An account row carries its own id so the Accounts screen can land on
      // exactly the one tapped; every other kind opens its whole screen, so
      // the id is not needed and is left null.
      onTap: () => _openGroup(
        kind,
        route,
        focusId: kind == 'accounts' ? it['id']?.toString() : null,
      ),
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
                    style: AppText.body.w6,
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.caption,
                    ),
                  ],
                ],
              ),
            ),
            if (amount != null) ...[
              const SizedBox(width: 8),
              // The engine's transfer sign stays the RN byte ('⇄', golden
              // locked); the SCREEN draws it as a real glyph so no authored
              // symbol is typeset as text chrome.
              if (sign == search.transferSign) ...[
                Icon(
                  salapifyIcon('swap'),
                  size: 14,
                  color: _amountColor(sign),
                  semanticLabel: 'transfer',
                ),
                const SizedBox(width: 2),
              ],
              Text(
                '${sign.isNotEmpty && sign != search.transferSign ? '$sign ' : ''}${formatMoneyText((amount as num).toDouble())}',
                style: AppText.amountRow
                    .copyWith(fontSize: 14)
                    .tint(_amountColor(sign)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
