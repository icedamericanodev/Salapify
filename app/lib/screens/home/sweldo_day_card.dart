import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_sheet.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// "Pay yourself first", on Home for the day or two after payday (D31).
///
/// Every figure is one the app already computes and shows elsewhere: Safe to
/// Save from the Safe to Spend engine, the bills it holds back, and the daily
/// figure from the hero. Nothing here is a new number. When it is shown and
/// when it goes is [sweldoDayFor] (core/money/sweldo_day.dart).
///
/// ONE action, and it is the one that changes the figure: moving money into
/// an account marked Set aside. A goal contribution moves no balance, so
/// offering it here would be a ritual with no effect. With no Set aside
/// account yet, the button says so and opens Accounts, because a move
/// anywhere else would lower nothing.
///
/// No celebration after the move (D30): the card goes, and the hero moves.
class SweldoDayCard extends StatelessWidget {
  const SweldoDayCard({
    super.key,
    required this.state,
    required this.onMove,
    required this.onChooseSavings,
  });

  final FinancialState state;
  final VoidCallback onMove;
  final VoidCallback onChooseSavings;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(state.theme);
    final SafeToSpendAnalysis a = state.safeToSpendAnalysis;
    final bool hasSetAside = state.accounts.any(
      (Account x) => x.purpose == AccountPurpose.protected,
    );

    Widget row(String label, String value, {Key? key}) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: AppType.body(p))),
          const SizedBox(width: Spacing.sm),
          Text(value, key: key, style: AppType.amountSmall(p)),
        ],
      ),
    );

    return SectionCard(
      key: const Key('sweldo-day-card'),
      palette: p,
      padding: const EdgeInsets.all(Spacing.md),
      radius: Radii.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('SWELDO DAY · PAYDAY', style: AppType.kicker(p)),
              ),
              InfoDot(
                color: p.textMuted,
                semanticLabel: 'Why pay yourself first',
                onTap: () => InfoSheet.show(context, p, InfoTopic.sweldoDay),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text('Pay yourself first', style: AppType.rowTitle(p)),
          const SizedBox(height: Spacing.sm),
          row(
            'Safe to Save',
            formatPeso(a.safeToSave.pesos),
            key: const Key('sweldo-safe-to-save'),
          ),
          row(
            'Bills held back ${state.billWindowPhrase}',
            formatPeso(a.reservedBills.pesos),
          ),
          Text(
            'Then ${formatPeso(state.safeToSpendPerDay.pesos)} a day until '
            '${state.payday.nextPayday}.',
            style: AppType.caption(p),
          ),
          const SizedBox(height: Spacing.sm),
          // STAYS ON SCREEN, under the wrong-conclusion rule: before the pay
          // is logged, last cycle's leftovers divided by a fresh fortnight
          // read as a crisis, and this is the line that says why.
          Text(
            'Log your pay first. These figures count only money already in '
            'your accounts.',
            style: AppType.caption(p),
          ),
          const SizedBox(height: Spacing.md),
          PrimaryButton(
            palette: p,
            icon: hasSetAside ? Icons.savings_outlined : Icons.shield_outlined,
            label: hasSetAside ? 'Move to savings' : 'Choose a savings account',
            onTap: hasSetAside ? onMove : onChooseSavings,
          ),
        ],
      ),
    );
  }
}
