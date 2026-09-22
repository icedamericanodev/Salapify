import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../core/money/format.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// Coming Up, ported from src/components/ComingUpCard.tsx.
///
/// The card answers one question: what is going to happen to my money before
/// the next payday. Profile tabs narrow it, the three boxes total it, and the
/// list names it. Tapping a box filters the list, which is how the prototype
/// connects the summary to the rows instead of leaving them side by side.
class ComingUpCard extends StatelessWidget {
  const ComingUpCard({
    super.key,
    required this.state,
    this.onManage,
    this.onInfo,
    this.onAddItem,
  });

  final FinancialState state;
  final VoidCallback? onManage;
  final VoidCallback? onInfo;
  final VoidCallback? onAddItem;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);

    return SectionCard(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _header(palette),
          const SizedBox(height: Spacing.md),
          _profileTabs(palette),
          const SizedBox(height: Spacing.md),
          _cashBanner(palette),
          const SizedBox(height: Spacing.md),
          if (state.displayedUpcoming.isEmpty)
            _emptyState(palette)
          else
            ...state.displayedUpcoming.map(
              (UpcomingItem item) => _itemRow(palette, item),
            ),
        ],
      ),
    );
  }

  Widget _header(Palette palette) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        IconTile(palette: palette, icon: Icons.schedule),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      'Coming Up',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  InfoDot(
                    color: palette.textMuted,
                    semanticLabel: 'How upcoming items protect Safe to Spend',
                    onTap: onInfo,
                  ),
                ],
              ),
              Text(
                'Expected bills & income before next payday',
                // TWO LINES, because one was never enough for this sentence.
                // It did not fit at the ordinary font size, so every phone
                // has been showing "Expected bills & income before next
                // pay..." since the card was written. A row title cut short
                // is a deliberate pattern; Salapify's own explanation of what
                // a card means is just a sentence the layout lost.
                //
                // Found by screen_readability_test.dart on its first run,
                // and it was the only finding at 1.0x on any tab.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: palette.textMuted),
              ),
            ],
          ),
        ),
        SectionLink(palette: palette, label: 'Manage', onTap: onManage),
      ],
    );
  }

  Widget _profileTabs(Palette palette) {
    const List<(ProfileEntity?, String, IconData)> tabs =
        <(ProfileEntity?, String, IconData)>[
          (null, 'All Profiles', Icons.layers_outlined),
          (ProfileEntity.personal, 'Personal', Icons.person_outline),
          (ProfileEntity.household, 'Household', Icons.home_outlined),
          (ProfileEntity.business, 'Business', Icons.work_outline),
        ];

    return Container(
      padding: const EdgeInsets.all(Spacing.xs),
      decoration: BoxDecoration(
        color: palette.trackSoft,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            for (final (ProfileEntity?, String, IconData) tab in tabs)
              _ProfileTab(
                palette: palette,
                label: tab.$2,
                icon: tab.$3,
                count: state.upcomingCountFor(tab.$1),
                selected: state.activeProfile == tab.$1,
                onTap: () => state.setActiveProfile(tab.$1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cashBanner(Palette palette) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.trackSoft,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: palette.accent,
              ),
              const SizedBox(width: Spacing.sm),
              Flexible(
                child: Text(
                  // An unset cycle has no date. "Next Payday: " with nothing
                  // after the colon reads as a value the app lost.
                  state.payday.isSet
                      ? 'Next Payday: ${state.payday.nextPayday}'
                      : 'Payday not set yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (state.payday.isSet) const SizedBox(width: Spacing.sm),
              // No badge at all when there is no payday. "0 days away" beside
              // "Payday not set yet" is a countdown to nothing.
              if (state.payday.isSet)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    state.payday.daysToPayday == 1
                        ? '1 day away'
                        : '${state.payday.daysToPayday} days away',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: palette.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Divider(height: 1, color: palette.border),
          const SizedBox(height: Spacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatBox(
                  palette: palette,
                  icon: Icons.south_west,
                  label: 'Income',
                  value: state.totalInflows > 0
                      ? formatSignedPeso(state.totalInflows, isIncome: true)
                      : formatPeso(0),
                  valueColor: palette.positive,
                  selected: state.movementFilter == MovementFilter.inflow,
                  onTap: () => state.setMovementFilter(
                    state.movementFilter == MovementFilter.inflow
                        ? MovementFilter.all
                        : MovementFilter.inflow,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _StatBox(
                  palette: palette,
                  icon: Icons.north_east,
                  label: 'Reserved',
                  value: formatPeso(state.totalOutflows),
                  valueColor: palette.negative,
                  selected: state.movementFilter == MovementFilter.outflow,
                  onTap: () => state.setMovementFilter(
                    state.movementFilter == MovementFilter.outflow
                        ? MovementFilter.all
                        : MovementFilter.outflow,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: _StatBox(
                  palette: palette,
                  icon: state.netMovement >= 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  label: 'Remaining',
                  value: state.netMovement >= 0
                      ? formatSignedPeso(state.netMovement, isIncome: true)
                      : formatPeso(state.netMovement),
                  valueColor: state.netMovement >= 0
                      ? palette.positive
                      : palette.negative,
                  selected: state.movementFilter == MovementFilter.all,
                  onTap: () => state.setMovementFilter(MovementFilter.all),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(Palette palette) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: <Widget>[
          IconTile(
            palette: palette,
            icon: Icons.auto_awesome,
            size: 44,
            iconSize: 20,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'No upcoming items for this profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Your Safe to Spend is protected until next payday.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.textMuted),
          ),
          const SizedBox(height: Spacing.md),
          Material(
            color: palette.accent,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: InkWell(
              onTap: onAddItem,
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.add, size: 16, color: palette.onAccent),
                    const SizedBox(width: Spacing.xs),
                    Text(
                      'Add Item',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: palette.onAccent,
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

  Widget _itemRow(Palette palette, UpcomingItem item) {
    final bool isIncome = item.countsAsIncome;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Row(
        children: <Widget>[
          IconTile(
            palette: palette,
            icon: _iconFor(item),
            iconSize: 17,
            background: isIncome ? palette.positiveSoft : palette.iconTile,
            foreground: isIncome ? palette.positive : palette.accent,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  item.dueDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            isIncome
                ? formatSignedPeso(item.amount, isIncome: true)
                : formatPeso(item.amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isIncome ? palette.positive : palette.textPrimary,
            ),
          ),
          // Marking an expectation met is not logging a transaction, so this
          // ticks the row off and leaves the ledger alone.
          if (!isIncome)
            Semantics(
              button: true,
              label: 'Mark ${item.name} as paid',
              child: InkWell(
                onTap: () => state.markUpcomingPaid(item.id),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: palette.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(UpcomingItem item) {
    if (item.countsAsIncome) return Icons.event_available_outlined;
    switch (item.type) {
      case UpcomingItemType.subscription:
        return Icons.music_note_outlined;
      case UpcomingItemType.debt:
        return Icons.credit_card_outlined;
      case UpcomingItemType.rent:
      case UpcomingItemType.insurance:
        return Icons.home_outlined;
      case UpcomingItemType.government:
      case UpcomingItemType.tuition:
        return Icons.account_balance_outlined;
      case UpcomingItemType.bill:
      case UpcomingItemType.remittance:
      case UpcomingItemType.payday:
        return Icons.bolt_outlined;
    }
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.palette,
    required this.label,
    required this.icon,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? palette.accent : palette.textMuted,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? palette.textPrimary : palette.textMuted,
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? palette.accentSoft : palette.border,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected ? palette.accent : palette.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: selected ? palette.accentSoft : palette.surface,
            borderRadius: BorderRadius.circular(Radii.tile),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 12, color: valueColor),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: valueColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
