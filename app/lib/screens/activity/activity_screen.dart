import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/ledger.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'day_group.dart';
import 'ledger_summary_card.dart';

/// Activity, the prototype's second tab, from src/components/LedgerScreen.tsx.
///
/// Every figure on this screen comes out of core/money/ledger.dart, which is
/// locked to vectors generated from the prototype's own code. This file
/// decides what the screen LOOKS like and nothing about what it says.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.state});

  final FinancialState state;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final TextEditingController _search = TextEditingController();

  TransactionStatus? _status;
  String? _accountId;
  LedgerTypeFilter _type = LedgerTypeFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);

    final LedgerQuery query = LedgerQuery(
      search: _search.text,
      status: _status,
      accountId: _accountId,
      profile: widget.state.activeProfile,
    );

    // Scope first, total off the scoped set, then narrow by type for the list.
    // That order is the prototype's and it is what keeps the summary card
    // describing the whole selection while the list below it narrows.
    final List<Transaction> scoped = scopeTransactions(
      widget.state.transactions,
      query,
    );
    final LedgerTotals totals = computeTotals(scoped);
    final List<Transaction> listed = filterByType(scoped, _type);
    final List<LedgerDay> days = groupByDay(listed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.lg,
        88,
      ),
      children: <Widget>[
        Text('Activity', style: AppType.title(p)),
        Text(
          'Every peso in and out, and where it went',
          style: AppType.caption(p),
        ),
        const SizedBox(height: Spacing.lg),

        _SearchField(
          palette: p,
          controller: _search,
          // The count must describe the LIST, not the scoped set. Searching
          // "meralco" and then tapping In showed "Showing 2 of 11" above the
          // words "Nothing matches these filters", in the same frame.
          matchCount: listed.length,
          totalCount: widget.state.transactions.length,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.md),

        _FilterRow(
          palette: p,
          accounts: widget.state.accounts,
          status: _status,
          accountId: _accountId,
          onStatus: (TransactionStatus? s) => setState(() => _status = s),
          onAccount: (String? a) => setState(() => _accountId = a),
        ),
        const SizedBox(height: Spacing.lg),

        LedgerSummaryCard(palette: p, totals: totals),
        const SizedBox(height: Spacing.lg),

        _TypeTabs(
          palette: p,
          selected: _type,
          onSelect: (LedgerTypeFilter t) => setState(() => _type = t),
        ),
        const SizedBox(height: Spacing.md),

        if (days.isEmpty)
          _EmptyState(palette: p, hasFilters: _hasFilters)
        else
          for (final LedgerDay day in days) ...<Widget>[
            DayGroup(
              palette: p,
              day: day,
              accounts: widget.state.accounts,
              now: widget.state.now,
            ),
            const SizedBox(height: Spacing.lg),
          ],
      ],
    );
  }

  /// The PROFILE counts as a filter even though it is not set on this screen.
  /// It is chosen on Home, and leaving it out meant a full ledger could show
  /// "No entries yet", which is the exact lie the empty state was written to
  /// avoid: it sends somebody hunting for a bug instead of for the filter.
  bool get _hasFilters =>
      _search.text.trim().isNotEmpty ||
      _status != null ||
      _accountId != null ||
      _type != LedgerTypeFilter.all ||
      widget.state.activeProfile != null;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.palette,
    required this.controller,
    required this.matchCount,
    required this.totalCount,
    required this.onChanged,
  });

  final Palette palette;
  final TextEditingController controller;
  final int matchCount;
  final int totalCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool searching = controller.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: controller,
          onChanged: onChanged,
          style: AppType.rowTitle(palette).copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search a merchant, category or amount',
            hintStyle: AppType.body(palette).copyWith(color: palette.textMuted),
            prefixIcon: Icon(Icons.search, size: 18, color: palette.textMuted),
            suffixIcon: searching
                ? IconButton(
                    // 44dp of tappable area, not just the glyph.
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: Icon(Icons.close, size: 18, color: palette.textMuted),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    tooltip: 'Clear the search',
                  )
                : null,
            filled: true,
            fillColor: palette.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.accent, width: 2),
            ),
          ),
        ),
        if (searching) ...<Widget>[
          const SizedBox(height: Spacing.xs),
          Text(
            matchCount == 0
                ? 'Nothing matches. Try part of a name, or just the amount.'
                : 'Showing $matchCount of $totalCount entries',
            style: AppType.caption(palette),
          ),
        ],
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.palette,
    required this.accounts,
    required this.status,
    required this.accountId,
    required this.onStatus,
    required this.onAccount,
  });

  final Palette palette;
  final List<Account> accounts;
  final TransactionStatus? status;
  final String? accountId;
  final ValueChanged<TransactionStatus?> onStatus;
  final ValueChanged<String?> onAccount;

  @override
  Widget build(BuildContext context) {
    // Scrolls sideways rather than wrapping. A filter strip that grows taller
    // pushes the money off the screen, which is the opposite of what a filter
    // is for.
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _Chip(
            palette: palette,
            label: 'All entries',
            selected: status == null && accountId == null,
            onTap: () {
              onStatus(null);
              onAccount(null);
            },
          ),
          for (final TransactionStatus s in <TransactionStatus>[
            TransactionStatus.confirmed,
            TransactionStatus.pending,
            TransactionStatus.excluded,
          ])
            _Chip(
              palette: palette,
              label: statusLabel(s),
              selected: status == s,
              onTap: () => onStatus(status == s ? null : s),
            ),
          for (final Account a in accounts.where((Account a) => a.isLiquid))
            _Chip(
              palette: palette,
              label: a.name,
              selected: accountId == a.id,
              onTap: () => onAccount(accountId == a.id ? null : a.id),
            ),
        ],
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({
    required this.palette,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final LedgerTypeFilter selected;
  final ValueChanged<LedgerTypeFilter> onSelect;

  static const Map<LedgerTypeFilter, String> _labels =
      <LedgerTypeFilter, String>{
        LedgerTypeFilter.all: 'All',
        LedgerTypeFilter.income: 'In',
        LedgerTypeFilter.expense: 'Out',
        LedgerTypeFilter.transfer: 'Moves',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.trackSoft,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: <Widget>[
          for (final LedgerTypeFilter t in LedgerTypeFilter.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: t == selected,
                child: Material(
                  color: t == selected ? palette.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(Radii.tile),
                  child: InkWell(
                    onTap: () => onSelect(t),
                    borderRadius: BorderRadius.circular(Radii.tile),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      child: Text(
                        _labels[t]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: t == selected
                              ? palette.onAccent
                              : palette.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? palette.accent : palette.card,
          borderRadius: BorderRadius.circular(Radii.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                  color: selected ? palette.accent : palette.border,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? palette.onAccent : palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette, required this.hasFilters});

  final Palette palette;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.receipt_long_outlined, size: 28, color: palette.textMuted),
          const SizedBox(height: Spacing.sm),
          Text(
            // Two different situations. "No entries yet" on a screen with a
            // filter on it is a lie, and it sends somebody looking for a bug
            // instead of looking at the filter they set.
            hasFilters ? 'Nothing matches these filters' : 'No entries yet',
            style: AppType.rowTitle(palette),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            hasFilters
                ? 'Clear a filter above to see more.'
                : 'Log something and it shows up here, newest first.',
            style: AppType.caption(palette),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The badge wording from src/data/categories.ts, kept identical so the two
/// apps describe the same row the same way.
String statusLabel(TransactionStatus s) => switch (s) {
  TransactionStatus.confirmed => 'Confirmed',
  TransactionStatus.reconciled => 'Reconciled',
  TransactionStatus.pending => 'Pending',
  TransactionStatus.duplicate => 'Duplicate',
  TransactionStatus.corrected => 'Corrected',
  TransactionStatus.excluded => 'Excluded',
};

/// Money the ledger is not counting is drawn struck through, which is the
/// prototype's own treatment and the clearest way to say "this is here, and it
/// is deliberately not in your totals".
bool statusIsStruckThrough(TransactionStatus s) =>
    s == TransactionStatus.excluded || s == TransactionStatus.duplicate;

String formatDayOut(double out) => 'Out: ${formatPeso(out)}';
