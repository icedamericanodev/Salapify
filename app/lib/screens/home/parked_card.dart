import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../plan/budget_sheets.dart';
import 'home_kit.dart';

/// "Still want it?" on Home, once a parked wish's 48 hours are up (D38.2).
///
/// Three answers, all the same weight on purpose. The card exists to let the
/// person decide with a cooler head, and a big orange "I bought it" would
/// decide for them.
///
///   - I bought it: the Log sheet, filled in. Off the list only once the
///     entry saves, so Cancel keeps it parked (the shell does this).
///   - Save up for it: a goal, filled in with the name and the price. A plain
///     "later" postpones forever; a goal turns the impulse into a plan.
///   - Let it go: off the list, and the amount is said once. No running total
///     of money kept, because D30 rules out keeping score.
class ParkedCard extends StatelessWidget {
  const ParkedCard({
    super.key,
    required this.state,
    required this.item,
    required this.onBought,
  });

  final FinancialState state;
  final ParkedItem item;
  final VoidCallback onBought;

  Future<void> _saveUp(BuildContext context) async {
    final bool? saved = await AddGoalSheet.show(
      context,
      state,
      startName: item.name,
      startTarget: item.amount,
    );
    if (saved == true) state.unpark(item.id);
  }

  void _letGo(BuildContext context, Palette p) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ParkedItem? gone = state.unpark(item.id);
    if (gone == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${formatPeso(gone.amount.pesos)} stays with you.'),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => state.restoreParked(gone),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(state.theme);
    final String age = formatAge(
      DateTime.fromMillisecondsSinceEpoch(item.parkedAt).toIso8601String(),
      now: state.now,
    );

    return SectionCard(
      key: const Key('parked-card'),
      palette: p,
      padding: const EdgeInsets.all(Spacing.md),
      radius: Radii.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconTile(palette: p, icon: Icons.hourglass_bottom_outlined),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text('Still want it?', style: AppType.rowTitle(p)),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '${item.name}, ${formatPeso(item.amount.pesos)}. You parked it '
            '$age.',
            style: AppType.body(p),
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              _Answer(palette: p, label: 'I bought it', onTap: onBought),
              _Answer(
                palette: p,
                label: 'Save up for it',
                onTap: () => _saveUp(context),
              ),
              _Answer(
                palette: p,
                label: 'Let it go',
                onTap: () => _letGo(context, p),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.palette,
    required this.label,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: AppType.button(palette, color: palette.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
