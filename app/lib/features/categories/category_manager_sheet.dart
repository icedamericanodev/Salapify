import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// The Category Manager, ported from src/components/CategoryManager.tsx.
///
/// Search, filter by kind, expand a category to see its sub-categories, and
/// add one. Deleting is offered but REFUSED when entries are tagged with the
/// category, and the refusal says so with a count rather than hiding the
/// control, which is the lesson the shipped app already learned: a button that
/// disappears when unavailable teaches nobody that the feature exists.
class CategoryManagerSheet extends StatefulWidget {
  const CategoryManagerSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => CategoryManagerSheet(state: state),
    );
  }

  @override
  State<CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<CategoryManagerSheet> {
  final TextEditingController _search = TextEditingController();
  CategoryKind? _filter;
  String? _expandedId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// How many ledger entries carry this category. The number that decides
  /// whether it can be deleted, and the number the refusal quotes.
  int _entryCount(CategoryInfo c) => widget.state.transactions
      .where((Transaction t) =>
          t.category.toLowerCase() == c.name.toLowerCase())
      .length;

  double _spent(CategoryInfo c) => widget.state.transactions
      .where((Transaction t) =>
          t.type == TransactionType.expense &&
          t.category.toLowerCase() == c.name.toLowerCase())
      .fold<double>(0, (double s, Transaction t) => s + t.amount);

  List<CategoryInfo> get _visible {
    final String q = _search.text.trim().toLowerCase();
    return widget.state.categories.where((CategoryInfo c) {
      if (_filter != null && c.kind != _filter) return false;
      if (q.isEmpty) return true;
      // Searching matches sub-categories too, because that is usually what
      // somebody is actually hunting for.
      return c.name.toLowerCase().contains(q) ||
          c.subcategories.any((String s) => s.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final List<CategoryInfo> visible = _visible;

    return SheetScaffold(
      palette: p,
      icon: Icons.sell_outlined,
      title: 'Categories',
      subtitle: '${widget.state.categories.length} categories, '
          'and the sub-categories under them',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetField(
            palette: p,
            label: 'Search',
            controller: _search,
            hint: 'Search categories or sub-categories',
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          SegmentedChoice<CategoryKind?>(
            palette: p,
            selected: _filter,
            options: const <(CategoryKind?, String)>[
              (null, 'All'),
              (CategoryKind.expense, 'Spending'),
              (CategoryKind.income, 'Income'),
              (CategoryKind.both, 'Both'),
            ],
            onSelect: (CategoryKind? k) => setState(() => _filter = k),
          ),
          const SizedBox(height: Spacing.lg),
          if (visible.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.xl),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Column(
                children: <Widget>[
                  Text(
                    'Nothing matches "${_search.text.trim()}"',
                    style: AppType.rowTitle(p),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Try a shorter search, or clear the filter above.',
                    style: AppType.caption(p),
                  ),
                ],
              ),
            )
          else
            for (final CategoryInfo c in visible) _categoryCard(p, c),
        ],
      ),
    );
  }

  Widget _categoryCard(Palette p, CategoryInfo c) {
    final bool expanded = _expandedId == c.id;
    final int entries = _entryCount(c);
    final double spent = _spent(c);

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: expanded ? p.accent : p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            Semantics(
              button: true,
              expanded: expanded,
              child: InkWell(
                onTap: () => setState(
                  () => _expandedId = expanded ? null : c.id,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    children: <Widget>[
                      // The user's own emoji, drawn as-is. Salapify never
                      // substitutes its icon set here.
                      Text(c.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.rowTitle(p),
                            ),
                            Text(
                              '${c.subcategories.length} sub-categories'
                              '${spent > 0 ? ' · ${formatPeso(spent, showDecimals: false)} spent' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.rowMeta(p),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      _kindChip(p, c.kind),
                      Icon(
                        expanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: p.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (expanded) _expandedBody(p, c, entries),
          ],
        ),
      ),
    );
  }

  Widget _expandedBody(Palette p, CategoryInfo c, int entries) {
    final bool canDelete = entries == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        0,
        Spacing.md,
        Spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Divider(height: Spacing.md, color: p.border),
          Text('Sub-categories', style: AppType.label(p)),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (final String sub in c.subcategories)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(color: p.border),
                  ),
                  child: Text(sub, style: AppType.rowMeta(p)),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          // The delete control always occupies its place. Live and red when it
          // can happen, quiet and untappable when it cannot, with the reason
          // where the consequence would otherwise be.
          Semantics(
            button: true,
            enabled: canDelete,
            child: InkWell(
              onTap: canDelete ? () => _confirmDelete(p, c) : null,
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.all(Spacing.md),
                decoration: BoxDecoration(
                  color: canDelete ? p.negativeSoft : p.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      canDelete ? Icons.delete_outline : Icons.lock_outline,
                      size: 16,
                      color: canDelete ? p.negative : p.textMuted,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        canDelete
                            ? 'Delete this category'
                            : entries == 1
                                ? 'One entry is tagged with this, so deleting '
                                    'it would leave that entry with no category.'
                                : '$entries entries are tagged with this, so '
                                    'deleting it would leave them with no category.',
                        style: canDelete
                            ? AppType.button(p, color: p.negative)
                            : AppType.caption(p),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Palette p, CategoryInfo c) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: p.card,
        title: Text('Delete ${c.name}?', style: AppType.title(p)),
        content: Text(
          'Nothing is tagged with it, so nothing loses its category. '
          'Its ${c.subcategories.length} sub-categories go with it.',
          style: AppType.body(p),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Keep it', style: AppType.button(p, color: p.textMuted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Deleting is wired up when categories become editable.',
                    style: TextStyle(color: p.onAccent),
                  ),
                  backgroundColor: p.accent,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text('Delete', style: AppType.button(p, color: p.negative)),
          ),
        ],
      ),
    );
  }

  Widget _kindChip(Palette p, CategoryKind kind) {
    final (String label, Color colour) = switch (kind) {
      CategoryKind.income => ('Income', p.positive),
      CategoryKind.both => ('Both', p.textMuted),
      CategoryKind.expense => ('Spending', p.accent),
    };

    return Container(
      margin: const EdgeInsets.only(right: Spacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colour,
        ),
      ),
    );
  }
}
