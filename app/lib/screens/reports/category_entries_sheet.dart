import 'package:flutter/material.dart';

import '../../core/money/bir_claims.dart';
import '../../core/money/format.dart';
import '../../core/money/ledger.dart';
import '../../core/money/reports.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../activity/day_group.dart';

/// The entries behind one category bar on Reports (D31, drill-down).
///
/// A SHEET, not a jump to Activity. Activity has no category or date filter,
/// its search matches any part of a name (so "Food" also catches merchants),
/// and it lists excluded entries struck through, so no total it could show
/// would equal the bar somebody tapped.
///
/// ## The figure and the list come from the same place
///
/// The amount at the top is the breakdown row itself, computed the way the
/// bar was ([computeCategoryBreakdown]), and the list is [entriesInCategory]
/// over the same scoped entries. Both use [categoryKeyOf], so the sum of the
/// rows below IS the figure above, to the centavo.
///
/// ## It stays live
///
/// Each row opens the entry's own sheet, where it can be edited or taken
/// back. The sheet rebuilds from the store with the same period, so the total
/// moves with what was changed rather than going stale over it.
class CategoryEntriesSheet extends StatelessWidget {
  const CategoryEntriesSheet({
    super.key,
    required this.state,
    required this.period,
    required this.back,
    required this.type,
    required this.category,
    this.claimableOnly = false,
  });

  final FinancialState state;
  final ReportPeriod period;

  /// How many periods back the report was stepped when the bar was tapped.
  final int back;
  final TransactionType type;
  final String category;
  final bool claimableOnly;

  static Future<void> show(
    BuildContext context, {
    required FinancialState state,
    required ReportPeriod period,
    required int back,
    required TransactionType type,
    required String category,
    bool claimableOnly = false,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => CategoryEntriesSheet(
        state: state,
        period: period,
        back: back,
        type: type,
        category: category,
        claimableOnly: claimableOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (BuildContext context, Widget? _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final Palette p = Palette.of(state.theme);
    final String when = periodLabel(period, state.now, back);
    final ReportSet r = buildReports(
      transactions: state.transactions,
      accounts: state.accounts,
      period: period,
      now: periodAnchor(period, state.now, back),
      profile: state.activeProfile,
      debts: state.debts,
      plans: state.installments,
    );
    final List<Transaction> scoped = claimableOnly
        ? r.transactions.where(isClaimable).toList()
        : r.transactions;

    CategoryBreakdown? row;
    for (final CategoryBreakdown c in computeCategoryBreakdown(scoped, type)) {
      if (c.category == category) row = c;
    }
    final List<Transaction> entries = entriesInCategory(scoped, type, category);
    final String ofWhat = type == TransactionType.income
        ? 'of money in'
        : claimableOnly
        ? 'of claimable spending'
        : 'of spending';

    return SheetScaffold(
      palette: p,
      icon: type == TransactionType.income
          ? Icons.south_west
          : Icons.north_east,
      title: category,
      subtitle: when,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            formatPeso(row?.total ?? 0),
            key: const Key('category-sheet-total'),
            style: AppType.amount(p),
          ),
          const SizedBox(height: Spacing.xs),
          if (row != null)
            Text(
              '${row.percentage.toStringAsFixed(1)}% $ofWhat, '
              '${row.count == 1 ? '1 entry' : '${row.count} entries'}',
              style: AppType.caption(p),
            ),
          const SizedBox(height: Spacing.lg),
          if (entries.isEmpty)
            // Reached when the last entry here was edited away or taken
            // back from its own sheet while this one was open.
            Text('Nothing left in $category for $when.', style: AppType.body(p))
          else
            for (final LedgerDay day in groupByDay(entries)) ...<Widget>[
              DayGroup(
                palette: p,
                day: day,
                state: state,
                accounts: state.accounts,
                now: state.now,
              ),
              const SizedBox(height: Spacing.md),
            ],
        ],
      ),
    );
  }
}
