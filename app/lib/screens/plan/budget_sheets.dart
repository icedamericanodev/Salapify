import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/plan.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';

/// Plan's four write paths.
///
/// Each one says what it is about to do BEFORE it does it, and says out loud
/// that nothing is saved to the phone yet, the same two rules the Log sheet
/// follows. A guess about money should be visible before it is committed.

// ------------------------------------------------------- edit a budget limit

class EditBudgetSheet extends StatefulWidget {
  const EditBudgetSheet({super.key, required this.state, required this.row});

  final FinancialState state;
  final BudgetStatus row;

  static Future<void> show(
    BuildContext context,
    FinancialState state,
    BudgetStatus row,
  ) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) =>
          EditBudgetSheet(state: state, row: row),
    );
  }

  @override
  State<EditBudgetSheet> createState() => _EditBudgetSheetState();
}

class _EditBudgetSheetState extends State<EditBudgetSheet> {
  late final TextEditingController _limit = TextEditingController(
    text: widget.row.limit.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  double? get _value => parsePlanAmount(_limit.text);

  void _save() {
    final double? v = _value;
    if (v == null) return;
    widget.state.setBudgetLimit(widget.row.category, v);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final double? v = _value;

    // What the NEW limit means against what is ALREADY spent. Raising a limit
    // to something you have already passed is a thing people do by accident,
    // and the only moment to notice is before saving.
    final double? remaining = v == null ? null : v - widget.row.spent;

    return SheetScaffold(
      palette: p,
      icon: Icons.pie_chart_outline,
      title: widget.row.category,
      subtitle: 'Monthly limit',
      footer: PrimaryButton(
        palette: p,
        label: 'Save limit',
        icon: Icons.check,
        onTap: v == null ? null : _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetField(
            key: const Key('budget-limit'),
            palette: p,
            label: 'Limit for this month',
            controller: _limit,
            hint: '0',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          BreakdownRow(
            palette: p,
            label: 'Already spent this month',
            value: formatPeso(widget.row.spent),
          ),
          if (remaining != null)
            BreakdownRow(
              palette: p,
              label: remaining < 0 ? 'Would be over by' : 'Would leave',
              value: formatPeso(remaining.abs()),
              emphasis: true,
              valueColor: remaining < 0 ? p.negative : p.positive,
            ),
          if (remaining != null && remaining < 0) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              'This limit is below what you have already spent, so the budget '
              'starts over.',
              style: AppType.caption(p).copyWith(color: p.negative),
            ),
          ],
          const SizedBox(height: Spacing.md),
          Text(
            'Not saved to the phone yet, so this clears when the app closes.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- add a goal

class AddGoalSheet extends StatefulWidget {
  const AddGoalSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => AddGoalSheet(state: state),
    );
  }

  @override
  State<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<AddGoalSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _target = TextEditingController();
  final TextEditingController _monthly = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _monthly.dispose();
    super.dispose();
  }

  double? get _targetValue => parsePlanAmount(_target.text);

  /// Defaults to a twelfth of the target when left blank, which is the
  /// prototype's `target / 12`. A goal with no monthly figure cannot answer
  /// "when do I get there", and a sensible default beats an empty answer.
  double get _monthlyValue =>
      parsePlanAmount(_monthly.text) ?? ((_targetValue ?? 0) / 12);

  bool get _canSave => _name.text.trim().isNotEmpty && _targetValue != null;

  void _save() {
    if (!_canSave) return;
    widget.state.addGoal(
      Goal(
        id: 'goal_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        // The user's own emoji, not a Salapify icon. Goals are their data.
        emoji: '🎯',
        targetAmount: _targetValue!,
        currentAmount: 0,
        targetDate: 'Dec 2026',
        monthlyTarget: _monthlyValue.roundToDouble(),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final double? target = _targetValue;
    final int? months = (target != null && _monthlyValue > 0)
        ? (target / _monthlyValue).ceil()
        : null;

    return SheetScaffold(
      palette: p,
      icon: Icons.flag_outlined,
      title: 'New goal',
      subtitle: 'What are you saving for',
      footer: PrimaryButton(
        palette: p,
        label: 'Create goal',
        icon: Icons.check,
        onTap: _canSave ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetField(
            key: const Key('goal-name'),
            palette: p,
            label: 'Name',
            controller: _name,
            hint: 'e.g. Emergency fund',
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            key: const Key('goal-target'),
            palette: p,
            label: 'Target amount',
            controller: _target,
            hint: '0',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            key: const Key('goal-monthly'),
            palette: p,
            label: 'Putting aside each month (optional)',
            controller: _monthly,
            hint: 'A twelfth of the target',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          if (months != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: p.border),
              ),
              child: Text(
                'At ${formatPeso(_monthlyValue, showDecimals: false)} a month '
                'this takes about $months months.',
                style: AppType.body(p).copyWith(color: p.accent),
              ),
            ),
          const SizedBox(height: Spacing.md),
          Text(
            'A goal records what you are aiming for. It does NOT move money '
            'out of an account, so your balances do not change.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------- contribute to a goal

class ContributeSheet extends StatefulWidget {
  const ContributeSheet({super.key, required this.state, required this.row});

  final FinancialState state;
  final GoalStatus row;

  static Future<void> show(
    BuildContext context,
    FinancialState state,
    GoalStatus row,
  ) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) =>
          ContributeSheet(state: state, row: row),
    );
  }

  @override
  State<ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends State<ContributeSheet> {
  final TextEditingController _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => parsePlanAmount(_amount.text);

  void _save() {
    final double? v = _value;
    if (v == null) return;
    widget.state.contributeToGoal(widget.row.goal.id, v);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final Goal g = widget.row.goal;
    final double? v = _value;

    // Clamped in the preview exactly as the engine clamps it, so the sentence
    // cannot promise something the save will not do.
    final double after = v == null
        ? g.currentAmount
        : ((g.currentAmount + v) > g.targetAmount
              ? g.targetAmount
              : g.currentAmount + v);

    return SheetScaffold(
      palette: p,
      icon: Icons.savings_outlined,
      title: g.name,
      subtitle: 'Add to this goal',
      footer: PrimaryButton(
        palette: p,
        label: 'Add to goal',
        icon: Icons.check,
        onTap: v == null ? null : _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetField(
            key: const Key('contribute-amount'),
            palette: p,
            label: 'Amount',
            controller: _amount,
            hint: '0.00',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          BreakdownRow(
            palette: p,
            label: 'Saved so far',
            value: formatPeso(g.currentAmount),
          ),
          BreakdownRow(
            palette: p,
            label: 'After this',
            value: formatPeso(after),
            emphasis: true,
            valueColor: p.positive,
          ),
          BreakdownRow(
            palette: p,
            label: 'Still to go',
            value: formatPeso(g.targetAmount - after),
          ),
          if (v != null && g.currentAmount + v > g.targetAmount) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              'That is more than the goal needs, so only '
              '${formatPeso(g.targetAmount - g.currentAmount)} is recorded '
              'against it.',
              style: AppType.caption(p).copyWith(color: p.warning),
            ),
          ],
          const SizedBox(height: Spacing.md),
          Text(
            'This records progress towards the goal. It does NOT take money '
            'out of an account, so log a transfer as well if you actually '
            'moved it.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------ add an income stream

class AddStreamSheet extends StatefulWidget {
  const AddStreamSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => AddStreamSheet(state: state),
    );
  }

  @override
  State<AddStreamSheet> createState() => _AddStreamSheetState();
}

class _AddStreamSheetState extends State<AddStreamSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  IncomeStreamType _type = IncomeStreamType.semimonthlySalary;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  double? get _value => parsePlanAmount(_amount.text);
  bool get _canSave => _name.text.trim().isNotEmpty && _value != null;

  static String _label(IncomeStreamType t) => switch (t) {
    IncomeStreamType.weeklyIncome => 'Weekly',
    IncomeStreamType.semimonthlySalary => '15 and 30 sweldo',
    IncomeStreamType.monthlySalary => 'Monthly salary',
    IncomeStreamType.freelance => 'Freelance',
    IncomeStreamType.irregular => 'Irregular',
    IncomeStreamType.thirteenthMonth => '13th month',
    IncomeStreamType.remittance => 'Remittance',
  };

  void _save() {
    if (!_canSave) return;
    widget.state.addIncomeStream(
      IncomeStream(
        id: 'stream_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        type: _type,
        expectedAmount: _value!,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);

    return SheetScaffold(
      palette: p,
      icon: Icons.south_west,
      title: 'Income stream',
      subtitle: 'Money you expect to come in',
      footer: PrimaryButton(
        palette: p,
        label: 'Add stream',
        icon: Icons.check,
        onTap: _canSave ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SheetField(
            key: const Key('stream-name'),
            palette: p,
            label: 'What is it',
            controller: _name,
            hint: 'e.g. Weekend tutoring',
            keyboardType: TextInputType.text,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            key: const Key('stream-amount'),
            palette: p,
            label: 'Expected amount',
            controller: _amount,
            hint: '0',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),
          Text('How often', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xs,
            children: <Widget>[
              for (final IncomeStreamType t in IncomeStreamType.values)
                Semantics(
                  selected: t == _type,
                  button: true,
                  child: InkWell(
                    onTap: () => setState(() => _type = t),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: t == _type ? p.accent : p.card,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(
                          color: t == _type ? p.accent : p.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            _label(t),
                            style: AppType.button(
                              p,
                              color: t == _type ? p.onAccent : p.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Text(
            // This sentence used to claim the stream raises Safe to Spend. It
            // does NOT, and a test written to prove the claim is what caught
            // it: computeSafeToSpend works out totalExpectedInflow and then
            // never uses it, deriving the headline from liquid cash less
            // reserves alone. That is the prototype's own behaviour and the
            // engine is vector-locked to it, so the copy was corrected rather
            // than the arithmetic. Whether expected income SHOULD raise Safe
            // to Spend is a money decision, and it is written up for the
            // founder rather than taken here.
            'This records what you expect to receive before payday. Safe to '
            'Spend is worked out from money you already hold, so it does not '
            'move until the income actually arrives and you log it.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }
}
