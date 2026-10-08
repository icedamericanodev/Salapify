import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/plan.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../../core/money/money.dart';

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
    // `plain`, NOT toStringAsFixed(0). The rounded version turned a stored
    // 3,500.55 into "3501" in the box, and saving without editing would then
    // have written 3501 over it. Found by the founder on the emulator,
    // 2026-10-03, running the centavo case.
    text: widget.row.limit.plain,
  );

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  /// The typed limit as money, or null when the box holds nothing usable.
  ///
  /// `tryFromDouble`, not `fromDouble`: this is read on every keystroke, and
  /// a half typed figure must not throw on a screen somebody is looking at.
  /// It is also the boundary where a typed number becomes money, which is
  /// the only place a NaN or an Infinity can be turned away.
  Money? get _value {
    final double? typed = parsePlanAmount(_limit.text);
    return typed == null ? null : Money.tryFromDouble(typed);
  }

  void _save() {
    final Money? v = _value;
    if (v == null) return;
    widget.state.setBudgetLimit(widget.row.category, v);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final Money? v = _value;

    // What the NEW limit means against what is ALREADY spent. Raising a limit
    // to something you have already passed is a thing people do by accident,
    // and the only moment to notice is before saving.
    final Money? remaining = v == null ? null : v - widget.row.spent;

    return SheetScaffold(
      palette: p,
      icon: Icons.pie_chart_outline,
      title: widget.row.category,
      subtitle: 'Monthly limit',
      footer: PrimaryButton(
        palette: p,
        label: 'Save limit',
        icon: Icons.check,
        // Positive, not merely present: a typed "0.004" rounds to zero, the
        // engine refuses it, and the sheet used to close as if it had saved.
        onTap: (v?.isPositive ?? false) ? _save : null,
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
            value: formatPeso(widget.row.spent.pesos),
          ),
          if (remaining != null)
            BreakdownRow(
              palette: p,
              label: remaining.isNegative ? 'Would be over by' : 'Would leave',
              value: formatPeso(remaining.abs.pesos),
              emphasis: true,
              valueColor: remaining.isNegative ? p.negative : p.positive,
            ),
          if (remaining != null && remaining.isNegative) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              'This limit is below what you have already spent, so the budget '
              'starts over.',
              style: AppType.caption(p).copyWith(color: p.negative),
            ),
          ],
          // A "not saved yet" caption stood here until storage landed. It is
          // gone rather than reversed: silence used to mislead, and now that
          // saving is what actually happens, silence is simply correct. A
          // line reassuring somebody about the ordinary case is clutter on
          // every visit after the first.
          const SizedBox(height: Spacing.lg),
          // THE WAY OUT of a budget set on the wrong category (founder
          // direction 2026-10-08). Quiet, at the foot of the sheet, so it is
          // never mistaken for the main action; asked about before it
          // happens, and undoable after.
          Center(
            child: TextButton.icon(
              key: const Key('remove-budget'),
              onPressed: _remove,
              icon: Icon(Icons.delete_outline, size: 18, color: p.negative),
              label: Text(
                'Remove this budget',
                style: AppType.button(p, color: p.negative),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _remove() async {
    final Palette p = Palette.of(widget.state.theme);
    final String name = widget.row.category;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Remove the $name budget?', style: AppType.title(p)),
        content: Text(
          // Said out loud because it is the opposite of what somebody fears:
          // removing a cap must not look like it erases spending.
          'Your spending in $name stays in Activity. Only the limit goes, '
          'and Left to spend stops counting it.',
          style: AppType.body(p),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep it', style: AppType.body(p)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: AppType.body(
                p,
              ).copyWith(color: p.negative, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ({Budget budget, int index})? gone = widget.state.removeBudget(name);
    Navigator.of(context).pop();
    if (gone == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$name budget removed.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () =>
                widget.state.restoreBudget(gone.budget, gone.index),
          ),
        ),
      );
  }
}

// ------------------------------------------------------------- add a budget

/// Sets a monthly cap for one spending category.
///
/// Built 2026-10-08 on founder direction ("yes build add a budget"): until
/// then budgets only arrived with the example data, so clearing it left
/// Budgets empty for good. Same shape as [AddGoalSheet] and the same two
/// rules every Plan write follows: say what it will mean before saving, and
/// leave the decision about what is valid to the engine (`applyNewBudget`).
class AddBudgetSheet extends StatefulWidget {
  const AddBudgetSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => AddBudgetSheet(state: state),
    );
  }

  @override
  State<AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends State<AddBudgetSheet> {
  final TextEditingController _limit = TextEditingController();
  CategoryInfo? _category;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  /// Read on every keystroke, so `tryFromDouble`: a half typed figure must
  /// never throw on a sheet somebody is filling in.
  Money? get _value {
    final double? typed = parsePlanAmount(_limit.text);
    return typed == null ? null : Money.tryFromDouble(typed);
  }

  /// POSITIVE, not merely present, for the same reason as the limit edit.
  bool get _canSave => _category != null && (_value?.isPositive ?? false);

  /// What this category has already cost this month, worked out by the same
  /// engine Plan uses, so the sheet and the card it creates agree.
  Money _spentSoFar(CategoryInfo c) {
    final List<BudgetStatus> rows = computeBudgets(
      budgets: <Budget>[
        Budget(category: c.name, limit: const Money.pesos(1), emoji: c.emoji),
      ],
      transactions: widget.state.transactions,
      now: widget.state.now,
    );
    return rows.isEmpty ? Money.zero : rows.first.spent;
  }

  void _save() {
    final CategoryInfo? c = _category;
    final Money? v = _value;
    if (c == null || v == null) return;
    final bool added = widget.state.addBudget(
      category: c.name,
      emoji: c.emoji,
      limit: v,
    );
    if (added) saveHaptic();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final List<CategoryInfo> open = budgetableCategories(
      widget.state.categories,
      widget.state.budgets,
    );
    final CategoryInfo? c = _category;
    final Money? v = _value;
    final Money? spent = c == null ? null : _spentSoFar(c);
    final Money? remaining = (spent == null || v == null) ? null : v - spent;

    return SheetScaffold(
      palette: p,
      icon: Icons.pie_chart_outline,
      title: 'New budget',
      subtitle: 'A monthly cap for one category',
      footer: PrimaryButton(
        palette: p,
        label: 'Set budget',
        icon: Icons.check,
        onTap: _canSave ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Category', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          if (open.isEmpty)
            Text(
              'Every spending category already has a budget. Tap one on '
              'the Budgets screen to change its limit.',
              style: AppType.caption(p),
            )
          else
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: <Widget>[
                for (final CategoryInfo o in open)
                  _CategoryChip(
                    palette: p,
                    category: o,
                    selected: o.name == c?.name,
                    onTap: () => setState(() => _category = o),
                  ),
              ],
            ),
          const SizedBox(height: Spacing.lg),
          SheetField(
            key: const Key('new-budget-limit'),
            palette: p,
            label: 'Limit each month',
            controller: _limit,
            hint: '0',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          if (spent != null) ...<Widget>[
            const SizedBox(height: Spacing.md),
            BreakdownRow(
              palette: p,
              label: 'Already spent this month',
              value: formatPeso(spent.pesos),
            ),
            if (remaining != null)
              BreakdownRow(
                palette: p,
                label: remaining.isNegative
                    ? 'Would be over by'
                    : 'Would leave',
                value: formatPeso(remaining.abs.pesos),
                emphasis: true,
                valueColor: remaining.isNegative ? p.negative : p.positive,
              ),
          ],
          const SizedBox(height: Spacing.md),
          Text(
            'A budget is a limit you set for yourself. It does not move or '
            'hold back any money.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }
}

/// One spending category to pick, with its own emoji (user data, so an
/// emoji and not a Salapify icon).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.palette,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final CategoryInfo category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.accent : palette.card,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(
                  child: Text(
                    category.emoji,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                Flexible(
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? palette.onAccent : palette.textPrimary,
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
        targetAmount: Money.fromDouble(_targetValue!),
        currentAmount: Money.zero,
        targetDate: 'Dec 2026',
        monthlyTarget: Money.fromDouble(_monthlyValue.roundToDouble()),
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
    final Goal before = widget.row.goal;
    final bool wasShort = before.currentAmount < before.targetAmount;
    widget.state.contributeToGoal(before.id, Money.fromDouble(v));
    // A firmer buzz when THIS contribution is the one that reaches the goal.
    final Goal? after = widget.state.goals
        .where((Goal g) => g.id == before.id)
        .firstOrNull;
    saveHaptic(
      milestone:
          wasShort &&
          after != null &&
          after.currentAmount >= after.targetAmount,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final Goal g = widget.row.goal;
    final double? v = _value;

    // Clamped in the preview exactly as the engine clamps it, so the sentence
    // cannot promise something the save will not do.
    final Money contribution = v == null ? Money.zero : Money.fromDouble(v);
    final Money after = v == null
        ? g.currentAmount
        : ((g.currentAmount + contribution) > g.targetAmount
              ? g.targetAmount
              : g.currentAmount + contribution);

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
            value: formatPeso(g.currentAmount.pesos),
          ),
          BreakdownRow(
            palette: p,
            label: 'After this',
            value: formatPeso(after.pesos),
            emphasis: true,
            valueColor: p.positive,
          ),
          BreakdownRow(
            palette: p,
            label: 'Still to go',
            value: formatPeso((g.targetAmount - after).pesos),
          ),
          if (v != null &&
              g.currentAmount + contribution > g.targetAmount) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              'That is more than the goal needs, so only '
              '${formatPeso((g.targetAmount - g.currentAmount).pesos)} is recorded '
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

  /// The typed figure as money, or null when it is not a usable amount.
  ///
  /// `parsePlanAmount` already turns away nothing, a NaN, an Infinity and
  /// anything at or below zero. `tryFromDouble` covers the one case it does
  /// not: a figure that is finite and positive and still too large to be a
  /// peso amount anybody holds. Null then disables Save rather than throwing
  /// on a screen.
  Money? get _value {
    final double? typed = parsePlanAmount(_amount.text);
    return typed == null ? null : Money.tryFromDouble(typed);
  }

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
