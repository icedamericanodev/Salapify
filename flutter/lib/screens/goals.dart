// Goals: the plan-first list. Reached from the Overview, Menu, Search, Pan,
// and lessons; the constructor is unchanged on purpose so every caller and
// the readability sweep keep working.
//
// The screen answers, per goal, without opening anything: what it is, how
// much is in, how much is left, what pace the plan asks, whether it is on
// track, and the one next action. Money rule, stated where the user reads
// it: a goal tracks a NUMBER (money usually kept in a bank or wallet), so
// nothing on this screen moves an account balance, ever.
//
// Templates are authored by Salapify and carry semantic icon keys through
// salapify_icon.dart; a goal the USER gave an emoji keeps that emoji
// forever, because their icon field is their data.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/format.dart'
    show formatMoney, formatMoneyAbout, prettyMonthYear;
import '../money/goal_plan.dart';
import '../money/goals_calc.dart' show goalPercent;
import '../money/ledger.dart' show amountOf;
import '../theme.dart';
import '../typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/pan_mascot.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/progress_bar.dart';
import '../widgets/salapify_icon.dart';
import 'goal_create.dart';
import 'goal_detail.dart';

class GoalsScreen extends StatefulWidget {
  final SalapifyStore store;
  const GoalsScreen({super.key, required this.store});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool _reordering = false;
  bool _showPaused = true;
  bool _showCompleted = false;

  List<Map<String, dynamic>> _goals() {
    final raw = widget.store.data['goals'];
    final rows = [
      for (final g in (raw is List ? raw : const []))
        if (g is Map) g.cast<String, dynamic>(),
    ];
    // User priority first where set; everything else keeps stored order.
    // A plain sort would not be stable, so rank through an index pair.
    final indexed = List.generate(rows.length, (i) => (rows[i], i));
    indexed.sort((a, b) {
      final pa = a.$1['priority'];
      final pb = b.$1['priority'];
      if ((pa is num) != (pb is num)) return pa is num ? -1 : 1;
      if (pa is num && pb is num && pa != pb) return pa.compareTo(pb);
      return a.$2.compareTo(b.$2);
    });
    return [for (final e in indexed) e.$1];
  }

  /// A goal's display figures, one place: savings goals read their own
  /// fields, debt goals derive live from the linked debt so no balance is
  /// ever stored twice.
  ({double target, double saved, bool done, bool broken}) _figures(
    Map<String, dynamic> g,
  ) {
    if (g['kind'] == 'debt') {
      final f = debtGoalFigures(g, widget.store.data.cast<String, dynamic>());
      if (f == null) return (target: 0, saved: 0, done: false, broken: true);
      return (
        target: amountOf(f['target']),
        saved: amountOf(f['saved']),
        done: f['done'] == true,
        broken: false,
      );
    }
    final target = amountOf(g['target']);
    final saved = amountOf(g['saved']);
    return (
      target: target,
      saved: saved,
      done: target > 0 && saved >= target,
      broken: false,
    );
  }

  void _openCreate([GoalTemplate? t]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalCreateScreen(store: widget.store, template: t),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> g, {bool openAddMoney = false}) {
    final id = g['id'];
    if (id is! String) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalDetailScreen(
          store: widget.store,
          goalId: id,
          openAddMoney: openAddMoney,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Goals'),
        actions: [
          TextButton(
            onPressed: () => _openCreate(),
            child: Text(
              '+ Add',
              style: TextStyle(
                color: Barako.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final goals = _goals();
            if (goals.isEmpty) return _emptyState(context);
            return _activeState(context, goals);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- empty

  Widget _emptyState(BuildContext context) {
    final now = DateTime.now();
    final templates = goalTemplates(
      widget.store.data.cast<String, dynamic>(),
      now,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns only when both the width and the text scale allow a
        // card to keep whole words; one column everywhere else.
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final twoColumns = constraints.maxWidth >= 560 && textScale <= 1.3;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const SizedBox(height: 8),
            // The shared empty-state shape; the template cards below stay,
            // because they are the real invitation on this screen.
            EmptyState(
              icon: 'goal',
              // Pan holds a sprout here: an empty goals list is the start of
              // something growing, not a blank you failed to fill.
              showPan: true,
              panExpression: PanExpression.grow,
              title: 'What are you saving for?',
              body:
                  'Choose a goal and Salapify will help you build a plan '
                  'you can adjust anytime.',
              actionLabel: 'Create a goal',
              onAction: () => _openCreate(),
            ),
            const SizedBox(height: Gap.xl),
            Text('POPULAR GOAL TEMPLATES', style: Barako.kickerStyle),
            const SizedBox(height: Gap.sm),
            if (twoColumns)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final t in templates)
                    SizedBox(
                      width: (constraints.maxWidth - 52) / 2,
                      child: _templateCard(t),
                    ),
                ],
              )
            else
              for (final t in templates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _templateCard(t),
                ),
          ],
        );
      },
    );
  }

  Widget _templateCard(GoalTemplate t) {
    // A suggested figure appears ONLY when the engine could explain it; the
    // old cards carried fixed pesos that meant nothing about anyone.
    final suggestion = t.suggestedTarget != null
        ? 'Suggested: ${formatMoney(t.suggestedTarget!)}'
        : t.suggestedDeadline != null
        ? 'Aims at ${prettyMonthYear(t.suggestedDeadline!)}'
        : null;
    return PressableScale(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => _openCreate(t),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SalapifyGlyph(
                  t.icon,
                  size: 22,
                  color: goalAccentColor(t.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: AppText.bodyStrong.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(t.blurb, style: AppText.caption),
                      if (suggestion != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          suggestion,
                          style: AppText.caption.w6.tabular.tint(
                            Barako.primaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  salapifyIcon('forward'),
                  color: Barako.faint,
                  size: SalapifyIconSize.inline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- active

  Widget _activeState(BuildContext context, List<Map<String, dynamic>> goals) {
    final now = DateTime.now();
    final active = <Map<String, dynamic>>[];
    final paused = <Map<String, dynamic>>[];
    final completed = <Map<String, dynamic>>[];
    var totalSaved = 0.0;
    for (final g in goals) {
      final f = _figures(g);
      if (g['paused'] == true) {
        paused.add(g);
      } else if (f.done) {
        completed.add(g);
      } else {
        active.add(g);
        totalSaved += f.saved;
      }
    }
    final focus = focusGoal(active, now);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (active.isNotEmpty) ...[
          Text(
            // "put toward", not "saved": a debt goal's figure is paid-off
            // debt, and calling that savings would overstate what is in the
            // bank.
            // The second sentence kills the double-counting confusion that
            // made a savings ACCOUNT and a savings GOAL feel like rival
            // features: goals earmark money that already sits in accounts.
            '${formatMoney(totalSaved)} put toward '
            '${active.length == 1 ? 'one active goal' : '${active.length} active goals'}. '
            'This money stays in your accounts; goals just earmark it.',
            style: AppText.small.tabular,
          ),
          const SizedBox(height: Gap.md),
        ],
        // The header row exists whenever there is something to arrange, NOT
        // only when a focus exists: two debt-payoff goals produce no focus
        // (their raw target is zero) and still deserve Reorder. And a single
        // active goal skips the FOCUS treatment entirely; a suggestion with
        // no alternative answers a question nobody asked.
        if (active.length > 1) ...[
          Row(
            children: [
              Text(
                _reordering
                    ? 'YOUR ORDER'
                    : (focus != null ? 'FOCUS' : 'YOUR GOALS'),
                style: Barako.kickerStyle,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _reordering
                      ? 'top is first'
                      : (focus != null ? 'a suggestion, not an order' : ''),
                  style: AppText.micro.w4.tint(Barako.faint),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _reordering = !_reordering),
                child: Text(
                  _reordering ? 'Done' : 'Reorder',
                  style: AppText.smallStrong.tint(Barako.primaryText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!_reordering && focus != null) ...[
            _goalCard(focus, now, focus: true),
            const SizedBox(height: Gap.md),
          ],
        ],
        for (final (i, g) in active.indexed)
          if (_reordering ||
              active.length == 1 ||
              focus == null ||
              g['id'] != focus['id'])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _reordering
                  ? _reorderRow(g, i, active)
                  : _goalCard(g, now),
            ),
        if (paused.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          _sectionToggle(
            'PAUSED',
            paused.length,
            _showPaused,
            () => setState(() => _showPaused = !_showPaused),
          ),
          if (_showPaused)
            for (final g in paused)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _goalCard(g, now),
              ),
        ],
        if (completed.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          _sectionToggle(
            'COMPLETED',
            completed.length,
            _showCompleted,
            () => setState(() => _showCompleted = !_showCompleted),
          ),
          if (_showCompleted)
            for (final g in completed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _goalCard(g, now),
              ),
        ],
      ],
    );
  }

  Widget _sectionToggle(
    String label,
    int count,
    bool open,
    VoidCallback onTap,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.control),
      onTap: onTap,
      child: Padding(
        // 12 vertical keeps the toggle at a real 44dp touch target; 8 left
        // it around 31dp.
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text('$label ($count)', style: Barako.kickerStyle),
            const SizedBox(width: 4),
            Icon(
              salapifyIcon(open ? 'collapse' : 'expand'),
              size: SalapifyIconSize.detail,
              color: Barako.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _reorderRow(
    Map<String, dynamic> g,
    int index,
    List<Map<String, dynamic>> active,
  ) {
    Future<void> move(int delta) async {
      final ids = [for (final a in active) (a['id'] ?? '').toString()];
      final to = index + delta;
      if (to < 0 || to >= ids.length) return;
      final id = ids.removeAt(index);
      ids.insert(to, id);
      if (widget.store.canWrite) await widget.store.reorderGoals(ids);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              (g['name'] ?? 'Goal').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.w7,
            ),
          ),
          IconButton(
            tooltip: 'Move up',
            onPressed: index == 0 ? null : () => move(-1),
            icon: Icon(
              salapifyIcon('moveUp'),
              size: SalapifyIconSize.inline,
              color: index == 0 ? Barako.faint : Barako.primaryText,
            ),
          ),
          IconButton(
            tooltip: 'Move down',
            onPressed: index == active.length - 1 ? null : () => move(1),
            icon: Icon(
              salapifyIcon('moveDown'),
              size: SalapifyIconSize.inline,
              color: index == active.length - 1
                  ? Barako.faint
                  : Barako.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard(Map<String, dynamic> g, DateTime now, {bool focus = false}) {
    final f = _figures(g);
    final isDebt = g['kind'] == 'debt';
    final pct = goalPercent(f.saved, f.target);
    final accent = goalAccentColor(
      g['accent'] is String ? g['accent'] as String : null,
    );
    final label = f.broken
        ? 'Needs adjustment'
        : g['paused'] == true
        ? 'Paused'
        : f.done
        ? 'Completed'
        : isDebt
        ? 'On track'
        : goalStatusLabel(g, now);
    final contribution = isDebt ? null : requiredContribution(g, now);
    final remaining = f.target - f.saved > 0 ? f.target - f.saved : 0.0;
    final targetDate = (g['targetDate'] ?? '').toString();
    // The status word carries the state; the tint only underlines it, so a
    // colourblind reader loses nothing.
    final warning = label == 'Overdue' || label == 'Needs adjustment';

    String? paceLine;
    if (contribution != null &&
        (contribution['hasDeadline'] as bool) &&
        (contribution['amount'] as double) > 0 &&
        !f.done &&
        g['paused'] != true) {
      final word = contribution['frequency'] == 'weekly' ? 'weekly' : 'monthly';
      paceLine =
          '${formatMoneyAbout(contribution['amount'] as double)} $word'
          '${targetDate.isNotEmpty ? ' · target ${prettyMonthYear(targetDate)}' : ''}';
    } else if (isDebt && !f.broken && !f.done) {
      paceLine = 'Moves with the payments you log on the debt.';
    }

    return PressableScale(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => _openDetail(g),
          child: Padding(
            padding: EdgeInsets.all(focus ? 16 : 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _cardGlyph(g, accent),
                    const SizedBox(width: 10),
                    Expanded(
                      // Status UNDER the name, the detail screen's layout: a
                      // side-by-side status word crushed long names into an
                      // ellipsis stub at 320dp with large fonts.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (g['name'] ?? 'Goal').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyLg.w8.copyWith(
                              fontSize: focus ? 16.5 : 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: AppText.caption.w7.tint(
                              warning ? Barako.warningStrong : Barako.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  f.broken
                      ? 'The linked debt is gone. Open to sort it out.'
                      : '${formatMoney(f.saved)} of ${formatMoney(f.target)}',
                  style: AppText.label.w7.tabular,
                ),
                if (!f.broken) ...[
                  const SizedBox(height: 8),
                  SalapifyProgressBar(
                    value: (pct / 100).clamp(0.0, 1.0),
                    semanticsLabel: 'Goal progress',
                    color: accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    f.done ? 'Fully funded.' : '${formatMoney(remaining)} left',
                    style: AppText.caption.copyWith(fontSize: 12.5).tabular,
                  ),
                  if (paceLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      paceLine,
                      style: AppText.caption
                          .copyWith(fontSize: 12.5)
                          .tabular
                          .tint(Barako.textSecondary),
                    ),
                  ],
                ],
                Align(
                  alignment: Alignment.centerRight,
                  // A real button, not a label in button costume, and "Add
                  // money" delivers: it opens the detail WITH the add sheet
                  // already up, one tap from the list to money logged.
                  child: TextButton(
                    onPressed: () => _openDetail(
                      g,
                      openAddMoney:
                          !f.broken &&
                          g['paused'] != true &&
                          !f.done &&
                          !isDebt,
                    ),
                    child: Text(
                      f.broken
                          ? 'Open'
                          : g['paused'] == true
                          ? 'Resume'
                          : f.done
                          ? 'See the story'
                          : isDebt
                          ? 'Open the debt goal'
                          : 'Add money',
                      style: AppText.smallStrong.tint(Barako.primaryText),
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

  Widget _cardGlyph(Map<String, dynamic> g, Color accent) {
    // A user-typed emoji is their choice, rendered untouched; a template
    // goal carries a semantic key; a legacy goal falls to the neutral goal
    // glyph rather than to nothing.
    final emoji = (g['icon'] ?? '').toString();
    if (emoji.isNotEmpty) {
      return Text(emoji, style: const TextStyle(fontSize: 20));
    }
    return SalapifyGlyph(
      (g['iconKey'] ?? 'goal').toString(),
      size: 18,
      color: accent,
      boxed: false,
    );
  }
}
