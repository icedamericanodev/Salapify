import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../engine/format.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// Lets a test grab the split bar and measure it. The bar once rendered at
/// zero height while the card around it looked finished, which no assertion
/// about text could ever have caught.
const Key debtBeamKey = ValueKey<String>('debt-beam');

/// Debts, both directions, ported from src/components/DebtBeamCard.tsx.
///
/// Salapify means both halves of debt: what you owe and what is owed to you.
/// The beam shows the balance between them at a glance, and it never lets
/// either side collapse to nothing so both figures stay readable.
class DebtBeamCard extends StatelessWidget {
  const DebtBeamCard({
    super.key,
    required this.state,
    this.onSeeAll,
    this.onInfo,
  });

  final FinancialState state;
  final VoidCallback? onSeeAll;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(state.theme);
    final double owedToMe = state.debtsOwedToMe;
    final double iOwe = state.debtsIOwe;
    final double combined = owedToMe + iOwe;

    final double owedToMePercent = combined > 0
        ? ((owedToMe / combined) * 100).clamp(12, 88)
        : 50;
    final Debt? nextDue = state.nextDueDebt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'Debts (Both ways)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            InfoDot(
              color: palette.textMuted,
              semanticLabel: 'What Debts both ways means',
              onTap: onInfo,
            ),
            const Spacer(),
            SectionLink(palette: palette, label: 'See all', onTap: onSeeAll),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        SectionCard(
          palette: palette,
          onTap: onSeeAll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Side(
                      palette: palette,
                      label: 'Owed to you',
                      amount: owedToMe,
                      color: palette.positive,
                      alignEnd: false,
                    ),
                  ),
                  Expanded(
                    child: _Side(
                      palette: palette,
                      label: 'You owe',
                      amount: iOwe,
                      color: palette.accent,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: SizedBox(
                  key: debtBeamKey,
                  height: 5,
                  child: Row(
                    // stretch is load-bearing. A Row gives its children LOOSE
                    // vertical constraints, and a ColoredBox with no child
                    // takes the smallest size it is allowed, which is zero
                    // height. The beam then renders as nothing at all: the
                    // card looked complete and the bar was simply absent.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Expanded(
                        flex: owedToMePercent.round(),
                        child: ColoredBox(color: palette.positive),
                      ),
                      const SizedBox(width: 2),
                      Expanded(
                        flex: (100 - owedToMePercent).round(),
                        child: ColoredBox(color: palette.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Divider(height: 1, color: palette.border),
              const SizedBox(height: Spacing.sm),
              if (nextDue == null)
                Text(
                  'No outstanding payment deadlines',
                  style: TextStyle(fontSize: 12, color: palette.textMuted),
                )
              else
                Row(
                  children: <Widget>[
                    Expanded(
                      // Text.rich, NOT RichText. RichText ignores the
                      // surrounding DefaultTextStyle, so it drew this line in
                      // the framework fallback face instead of Plus Jakarta
                      // Sans: in the render the whole sentence came out as
                      // grey boxes.
                      child: Text.rich(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: palette.textSecondary,
                          ),
                          children: <InlineSpan>[
                            const TextSpan(text: 'Next due: '),
                            TextSpan(
                              text: nextDue.person,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                            ),
                            TextSpan(text: ' (${nextDue.dueDate})'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '${formatPeso(nextDue.remaining)} left',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.palette,
    required this.label,
    required this.amount,
    required this.color,
    required this.alignEnd,
  });

  final Palette palette;
  final String label;
  final double amount;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: palette.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatPeso(amount),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
