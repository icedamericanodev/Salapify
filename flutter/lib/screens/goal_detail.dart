// One goal, in full: the numbers, the plan and its reasoning, the history,
// the what-if, and every action, with the rarely-used ones behind a MORE
// section instead of crowding the top. Progressive disclosure is the layout
// rule: Add money and Adjust the plan are primary, everything else earns its
// place further down.
//
// Money rules: adding money edits the goal's tracked NUMBER (usually money
// kept in a bank or wallet outside Salapify) and never touches an account;
// moving money between goals is bookkeeping between two numbers, so net
// worth cannot change; a debt-payoff goal derives everything live from its
// linked debt and its "add money" is the debt's own payment flow, so a
// balance is never stored twice.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../money/format.dart'
    show formatMoney, formatMoneyAbout, prettyDay, prettyMonthYear;
import '../money/goal_plan.dart';
import '../money/goals_calc.dart' show goalNum, goalPercent;
import '../money/ledger.dart' show amountOf;
import '../money/milestones.dart' show milestoneFor;
import '../theme.dart';
import '../widgets/salapify_icon.dart';
import 'goal_create.dart' show goalAccentColor;
import 'milestone_share.dart' show showMilestoneCelebration;

const _tabular = [FontFeature.tabularFigures()];

class GoalDetailScreen extends StatefulWidget {
  final SalapifyStore store;
  final String goalId;

  /// Open the Add money sheet as soon as the screen lands. The list card's
  /// "Add money" action passes this, so the promise on the card is one tap
  /// away from money logged, not a scavenger hunt.
  final bool openAddMoney;
  const GoalDetailScreen({
    super.key,
    required this.store,
    required this.goalId,
    this.openAddMoney = false,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  double _whatIfAmount = 0;
  bool _showEstimateParts = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAddMoney) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final g = _goal();
        if (g != null && g['kind'] != 'debt' && g['paused'] != true) {
          _addMoneySheet(g);
        }
      });
    }
  }

  Map<String, dynamic>? _goal() {
    for (final g
        in (widget.store.data['goals'] is List
            ? widget.store.data['goals'] as List
            : const [])) {
      if (g is Map && g['id'] == widget.goalId) {
        return g.cast<String, dynamic>();
      }
    }
    return null;
  }

  void _offBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Saving is off because your data could not be read. Import a '
            'backup to recover first.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Barako.background,
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Goal',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final g = _goal();
            if (g == null) {
              // Deleted on another screen while this one was open. Say so;
              // nothing else here can be trusted.
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'This goal is gone from your book. Nothing else changed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Barako.muted, fontSize: 14),
                  ),
                ),
              );
            }
            return _body(context, g);
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> g) {
    final now = DateTime.now();
    final isDebt = g['kind'] == 'debt';
    final debtFigures = isDebt
        ? debtGoalFigures(g, widget.store.data.cast<String, dynamic>())
        : null;
    final target = isDebt
        ? amountOf(debtFigures?['target'])
        : amountOf(g['target']);
    final saved = isDebt
        ? amountOf(debtFigures?['saved'])
        : amountOf(g['saved']);
    final remaining = target - saved > 0 ? target - saved : 0.0;
    final pct = goalPercent(saved, target);
    final label = isDebt
        ? (debtFigures == null
              ? 'Needs adjustment'
              : (debtFigures['done'] == true ? 'Completed' : 'On track'))
        : goalStatusLabel(g, now);
    final paused = g['paused'] == true;
    final accent = goalAccentColor(
      g['accent'] is String ? g['accent'] as String : null,
    );
    final contribution = requiredContribution(g, now);
    final quarters = quartersReached(
      isDebt ? {'target': target, 'saved': saved} : g,
    );
    final targetDate = (g['targetDate'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            _goalGlyph(g, accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (g['name'] ?? 'Goal').toString(),
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: label == 'Overdue' || label == 'Needs adjustment'
                          ? Barako.warningStrong
                          : Barako.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Gap.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: Barako.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${formatMoney(saved)} of ${formatMoney(target)}',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  fontFeatures: _tabular,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.pill),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 10,
                  semanticsLabel: 'Goal progress',
                  backgroundColor: Barako.border,
                  color: accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                remaining > 0
                    ? '${formatMoney(remaining)} left'
                          '${targetDate.isNotEmpty ? ' · target ${prettyMonthYear(targetDate)}' : ''}'
                    : 'Fully funded.',
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 13,
                  fontFeatures: _tabular,
                ),
              ),
              // The quarter milestones, drawn AND said: four dots is a
              // picture; the semantics carry the words.
              const SizedBox(height: 10),
              Semantics(
                label: quarters.isEmpty
                    ? 'No milestones reached yet'
                    : 'Milestones reached: ${quarters.join(', ')} percent',
                child: ExcludeSemantics(
                  // Wrap, not Row: four groups at 2.0x on a 320dp phone
                  // overflow a Row, and the sweep runs at 390dp so only a
                  // Wrap keeps this honest everywhere.
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      for (final q in const [25, 50, 75, 100])
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              salapifyIcon(
                                quarters.contains(q)
                                    ? 'selected'
                                    : 'unselected',
                              ),
                              size: SalapifyIconSize.detail,
                              color: quarters.contains(q)
                                  ? accent
                                  : Barako.faint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$q%',
                              style: TextStyle(
                                color: quarters.contains(q)
                                    ? Barako.text
                                    : Barako.faint,
                                fontSize: 11,
                                fontFeatures: _tabular,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.lg),
        if (isDebt) ...[
          _debtNote(debtFigures),
        ] else ...[
          _planCard(g, contribution, now),
          const SizedBox(height: Gap.lg),
          if (!paused)
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _addMoneySheet(g),
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Add money',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _editSheet(g),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Barako.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'Adjust the plan',
                      style: TextStyle(
                        color: Barako.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: Gap.lg),
          _whatIfCard(g, now),
        ],
        const SizedBox(height: Gap.lg),
        _historyCard(g),
        const SizedBox(height: Gap.lg),
        _moreCard(g, paused),
      ],
    );
  }

  Widget _goalGlyph(Map<String, dynamic> g, Color accent) {
    // A user-typed emoji is their choice and renders untouched; a template
    // goal carries a semantic key; a legacy goal gets the neutral goal
    // glyph. All three read as one family through the shared disc.
    final emoji = (g['icon'] ?? '').toString();
    if (emoji.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      );
    }
    final key = (g['iconKey'] ?? 'goal').toString();
    return SalapifyGlyph(key, size: 26, color: accent);
  }

  Widget _planCard(
    Map<String, dynamic> g,
    Map<String, dynamic> contribution,
    DateTime now,
  ) {
    final amount = contribution['amount'] as double;
    final word = contribution['frequency'] == 'weekly' ? 'week' : 'month';
    final targetDate = (g['targetDate'] ?? '').toString();
    final status = contribution['status'];
    final estimate = safeToSetAside(
      widget.store.data.cast<String, dynamic>(),
      now,
    );
    String line;
    if (status == 'done') {
      line = 'Funded. Nothing more is owed to this one.';
    } else if (status == 'behind') {
      line =
          'The date passed with ${formatMoney(contribution['remaining'] as double)} '
          'to go. Pick a new date, or keep adding at your own pace; the goal '
          'keeps every peso you already put in.';
    } else if (!(contribution['hasDeadline'] as bool)) {
      line =
          'No deadline. Add money when you can, and this screen will show '
          'how far along you are.';
    } else {
      line =
          'To reach ${formatMoney(amountOf(g['target']))}'
          '${targetDate.isNotEmpty ? ' by ${prettyMonthYear(targetDate)}' : ''}, '
          'set aside about ${formatMoneyAbout(amount)} each $word.';
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THE PLAN', style: Barako.kickerStyle),
          const SizedBox(height: 6),
          Text(
            line,
            style: TextStyle(color: Barako.text, fontSize: 14, height: 1.45),
          ),
          if (estimate != null) ...[
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(Radii.sm),
              onTap: () =>
                  setState(() => _showEstimateParts = !_showEstimateParts),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Estimated safe amount right now: '
                        '${formatMoneyAbout(estimate['amount'] as double)}',
                        style: TextStyle(
                          color: Barako.primaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ),
                    Icon(
                      salapifyIcon(_showEstimateParts ? 'collapse' : 'expand'),
                      size: SalapifyIconSize.inline,
                      color: Barako.muted,
                    ),
                  ],
                ),
              ),
            ),
            if (_showEstimateParts) ...[
              const SizedBox(height: 6),
              Text(
                'An estimate, not a guarantee: '
                '${formatMoney(estimate['liquid'] as double)} spendable, minus '
                '${formatMoney(estimate['committed'] as double)} of bills due '
                'before payday, minus your ${formatMoney(estimate['buffer'] as double)} '
                'buffer. It never moves money by itself.',
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Add upcoming bills or income dates to get a safe-amount '
              'estimate.',
              style: TextStyle(color: Barako.faint, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _whatIfCard(Map<String, dynamic> g, DateTime now) {
    final contribution = requiredContribution(g, now);
    final base = contribution['amount'] as double;
    final word = contribution['frequency'] == 'weekly' ? 'week' : 'month';
    final freq = contribution['frequency'] as String;
    final chips = <double>{
      if (base > 0) (base / 2).roundToDouble(),
      if (base > 0) base.roundToDouble(),
      if (base > 0) (base * 1.5).roundToDouble(),
      if (base <= 0) 500,
      if (base <= 0) 1000,
      if (base <= 0) 2000,
    }.where((a) => a > 0).toList();
    // Default to the PLAN's own pace, so the card opens agreeing with the
    // plan and the other chips read as what-if-less and what-if-more. A
    // stale pick (the pace changed under it via Adjust the plan) resets
    // rather than leaving no chip selected.
    final picked = chips.contains(_whatIfAmount)
        ? _whatIfAmount
        : (base > 0 ? base.roundToDouble() : chips.first);
    final projection = goalWhatIf(g, now, perPeriod: picked, frequency: freq);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHAT IF', style: Barako.kickerStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final a in chips)
                ChoiceChip(
                  // No unit in the chip: the sentence below names it, and a
                  // seven-digit pace at 2.0x needs the room.
                  label: Text(formatMoney(a)),
                  selected: picked == a,
                  onSelected: (_) => setState(() => _whatIfAmount = a),
                  selectedColor: Barako.primary,
                  avatar: picked == a
                      ? Icon(
                          salapifyIcon('check'),
                          size: 16,
                          color: Barako.onPrimary,
                        )
                      : null,
                  labelStyle: TextStyle(
                    color: picked == a ? Barako.onPrimary : Barako.text,
                    fontSize: 12.5,
                    fontFeatures: _tabular,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            projection == null
                ? 'That pace would take more than ten years. Try a bigger '
                      'amount, or a smaller target.'
                // prettyMonthYear, never a day without a year: "Apr 1" for
                // a projection landing next April reads as this year, on
                // the one card whose whole job is an honest estimate.
                : 'At ${formatMoney(picked)} a $word, this finishes around '
                      '${prettyMonthYear(projection['finishDate'] as String)}'
                      '${(g['targetDate'] ?? '').toString().isNotEmpty ? (projection['meetsDeadline'] as bool ? ', inside your target date.' : ', after your target date.') : '.'}'
                      ' Nothing changes unless you adjust the plan yourself.',
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _debtNote(Map<String, dynamic>? figures) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LINKED TO YOUR DEBT', style: Barako.kickerStyle),
          const SizedBox(height: 6),
          Text(
            figures == null
                ? 'The debt this goal follows is no longer in your book. '
                      'Drop the goal, or keep it as a record.'
                : 'This goal follows ${figures['name']}. Payments you log on '
                      'the Utang tab move it forward by themselves; there is '
                      'nothing separate to add here, so the same peso is '
                      'never counted twice.',
            style: TextStyle(color: Barako.text, fontSize: 14, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> g) {
    final rows = [
      for (final c
          in (g['contributions'] is List
              ? g['contributions'] as List
              : const []))
        if (c is Map) c.cast<String, dynamic>(),
    ].reversed.toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HISTORY', style: Barako.kickerStyle),
          const SizedBox(height: 6),
          if (rows.isEmpty)
            Text(
              'Money you add will be listed here, dated, so the story of '
              'this goal is always visible.',
              style: TextStyle(color: Barako.muted, fontSize: 13),
            )
          else
            for (final c in rows.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      salapifyIcon(
                        amountOf(c['amount']) >= 0 ? 'incoming' : 'outgoing',
                      ),
                      size: SalapifyIconSize.detail,
                      color: amountOf(c['amount']) >= 0
                          ? Barako.primaryText
                          : Barako.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        // toString, never a cast: a restored backup can put
                        // anything in a note, and junk must not take the
                        // screen down.
                        () {
                          final note = (c['note'] ?? '').toString().trim();
                          return note.isEmpty ? 'Added' : note;
                        }(),
                        style: TextStyle(color: Barako.text, fontSize: 13),
                      ),
                    ),
                    Text(
                      formatMoney(amountOf(c['amount'])),
                      style: TextStyle(
                        color: Barako.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: _tabular,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      prettyDay((c['date'] ?? '').toString()),
                      style: TextStyle(color: Barako.faint, fontSize: 12),
                    ),
                  ],
                ),
              ),
          if (rows.length > 12) ...[
            const SizedBox(height: 4),
            Text(
              'and ${rows.length - 12} earlier '
              '${rows.length - 12 == 1 ? 'contribution' : 'contributions'}',
              style: TextStyle(color: Barako.faint, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moreCard(Map<String, dynamic> g, bool paused) {
    final otherGoals = [
      for (final o
          in (widget.store.data['goals'] is List
              ? widget.store.data['goals'] as List
              : const []))
        if (o is Map && o['id'] != widget.goalId && o['kind'] != 'debt')
          o.cast<String, dynamic>(),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        children: [
          _moreRow(
            icon: paused ? 'play' : 'paused',
            label: paused ? 'Resume this goal' : 'Pause this goal',
            sub: paused
                ? 'Back on the plan, history intact.'
                : 'Keeps every peso and the whole history. No pace is owed '
                      'while paused.',
            onTap: () => _togglePause(g, paused),
          ),
          // Hidden while paused, same as Add money: pause means the number
          // is frozen until the user says otherwise, in every direction.
          if (g['kind'] != 'debt' && !paused && otherGoals.isNotEmpty)
            _moreRow(
              icon: 'swap',
              label: 'Move money to another goal',
              sub: 'Bookkeeping between two goals. Net worth cannot change.',
              onTap: () => _moveMoneySheet(g, otherGoals),
            ),
          _moreRow(
            icon: 'delete',
            label: 'Delete this goal',
            sub:
                'Asks first, and Undo brings back everything, history '
                'included.',
            warning: true,
            onTap: () => _delete(g),
          ),
        ],
      ),
    );
  }

  Widget _moreRow({
    required String icon,
    required String label,
    required String sub,
    bool warning = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(
              salapifyIcon(icon),
              size: SalapifyIconSize.inline,
              color: warning ? Barako.warningStrong : Barako.primaryText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: warning ? Barako.warningStrong : Barako.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(color: Barako.faint, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              salapifyIcon('forward'),
              size: SalapifyIconSize.inline,
              color: Barako.faint,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePause(Map<String, dynamic> g, bool paused) async {
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.patchGoal(widget.goalId, {'paused': !paused});
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('That did not save. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            paused
                ? 'Back on the plan. Welcome back.'
                : 'Paused. The goal keeps everything; the plan just waits.',
          ),
        ),
      );
  }

  Future<void> _addMoneySheet(Map<String, dynamic> g) async {
    final estimate = safeToSetAside(
      widget.store.data.cast<String, dynamic>(),
      DateTime.now(),
    );
    final amount = await showModalBottomSheet<double?>(
      context: context,
      backgroundColor: Barako.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AmountSheet(
        title: 'Add money',
        sub:
            'This updates the goal number only. It never moves money out of '
            'any account.',
        hint: estimate != null && (estimate['amount'] as double) > 0
            ? 'Estimated safe right now: about '
                  '${formatMoneyAbout(estimate['amount'] as double)}'
            : null,
        confirm: 'Add',
      ),
    );
    if (amount == null || !mounted) return;
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final before = amountOf(_goal()?['saved']);
    final target = amountOf(_goal()?['target']);
    final messenger = ScaffoldMessenger.of(context);
    final String? reached;
    try {
      reached = await widget.store.addGoalFunds(widget.goalId, amount);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That did not save, so nothing was added.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final after = amountOf(_goal()?['saved']);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Added ${formatMoney(amount)}. Saved is now '
            '${formatMoney(after)}.',
          ),
        ),
      );
    if (reached != null) {
      final win = milestoneFor(widget.store.data, reached);
      if (win != null && mounted) {
        await showMilestoneCelebration(context, win);
      }
      return;
    }
    final q = quarterCrossed(before, after, target);
    if (q != null) {
      messenger.showSnackBar(SnackBar(content: Text('$q% there. Steady on.')));
    }
  }

  Future<void> _moveMoneySheet(
    Map<String, dynamic> g,
    List<Map<String, dynamic>> others,
  ) async {
    String? toId = others.first['id'] as String?;
    // The controller lives OUTSIDE the StatefulBuilder: created inside the
    // builder, every goal-row tap rebuilt a fresh one and silently wiped the
    // typed amount.
    final amt = TextEditingController();
    // What the source really holds; Move validates against it inline so the
    // receipt can never claim more than actually moved.
    final available = amountOf(g['saved']);
    String? moveError;
    final result = await showModalBottomSheet<(String, double)?>(
      context: context,
      backgroundColor: Barako.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Move money to another goal',
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Bookkeeping between two of your own goals. Your accounts '
                    'and net worth stay exactly as they are.',
                    style: TextStyle(color: Barako.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  for (final o in others)
                    InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () => setSheetState(
                        () => toId = (o['id'] ?? '').toString(),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(
                              salapifyIcon(
                                toId == o['id'] ? 'selected' : 'unselected',
                              ),
                              size: SalapifyIconSize.inline,
                              color: toId == o['id']
                                  ? Barako.primary
                                  : Barako.muted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                (o['name'] ?? 'Goal').toString(),
                                style: TextStyle(
                                  color: Barako.text,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amt,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: Barako.text),
                    decoration: InputDecoration(
                      labelText: 'Amount to move',
                      labelStyle: TextStyle(color: Barako.muted),
                      errorText: moveError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(null),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Barako.muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          final v = goalNum(amt.text);
                          final id = toId;
                          if (v <= 0 || id == null) {
                            setSheetState(() {
                              moveError = 'Enter an amount above zero.';
                            });
                            return;
                          }
                          if (v > available) {
                            setSheetState(() {
                              moveError =
                                  'This goal holds ${formatMoney(available)}; '
                                  'that is the most you can move.';
                            });
                            return;
                          }
                          Navigator.of(sheetContext).pop((id, v));
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Barako.primary,
                          foregroundColor: Barako.onPrimary,
                        ),
                        child: const Text(
                          'Move',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null || !mounted) return;
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.transferGoalFunds(widget.goalId, result.$1, result.$2);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('That did not save, so nothing moved.')),
      );
      return;
    }
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Moved ${formatMoney(result.$2)}. Both goals show it.'),
        ),
      );
  }

  Future<void> _editSheet(Map<String, dynamic> g) async {
    String numText(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    final name = TextEditingController(text: (g['name'] ?? '').toString());
    final target = TextEditingController(text: numText(amountOf(g['target'])));
    // Saved is editable HERE, in both directions: the old screen allowed
    // correcting a typo downward and the first redesign quietly lost that,
    // leaving a fat-fingered "Completed" goal unfixable short of deletion.
    final savedField = TextEditingController(
      text: numText(amountOf(g['saved'])),
    );
    var deadline = (g['targetDate'] ?? '').toString();
    var frequency = g['frequency'] == 'weekly' ? 'weekly' : 'monthly';
    final saved = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      backgroundColor: Barako.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adjust the plan',
                  style: TextStyle(
                    color: Barako.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Same goal, new numbers. A missed month is a plan to '
                  'recalculate, never a failure.',
                  style: TextStyle(color: Barako.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  style: TextStyle(color: Barako.text),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Barako.muted),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: Barako.text),
                  decoration: InputDecoration(
                    labelText: 'Target amount',
                    labelStyle: TextStyle(color: Barako.muted),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: savedField,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(color: Barako.text),
                  decoration: InputDecoration(
                    labelText: 'Saved so far',
                    helperText:
                        'Correct this number any time. It moves no money.',
                    helperStyle: TextStyle(color: Barako.faint, fontSize: 11),
                    labelStyle: TextStyle(color: Barako.muted),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();
                          final cur = DateTime.tryParse(deadline);
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: cur == null || cur.isBefore(now)
                                ? DateTime(now.year, now.month + 3, now.day)
                                : cur,
                            firstDate: now,
                            lastDate: DateTime(now.year + 30),
                            helpText: 'Target date',
                          );
                          if (picked == null) return;
                          setSheetState(() {
                            deadline =
                                '${picked.year.toString().padLeft(4, '0')}-'
                                '${picked.month.toString().padLeft(2, '0')}-'
                                '${picked.day.toString().padLeft(2, '0')}';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Barako.border),
                        ),
                        icon: Icon(
                          salapifyIcon('calendar'),
                          size: SalapifyIconSize.inline,
                          color: Barako.primaryText,
                        ),
                        label: Text(
                          deadline.isEmpty
                              ? 'No deadline'
                              : prettyMonthYear(deadline),
                          style: TextStyle(color: Barako.text),
                        ),
                      ),
                    ),
                    if (deadline.isNotEmpty)
                      TextButton(
                        onPressed: () => setSheetState(() => deadline = ''),
                        child: Text(
                          'Clear',
                          style: TextStyle(color: Barako.muted),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final f in const [
                      ('monthly', 'Monthly'),
                      ('weekly', 'Weekly'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f.$2),
                          selected: frequency == f.$1,
                          onSelected: (_) =>
                              setSheetState(() => frequency = f.$1),
                          selectedColor: Barako.primary,
                          labelStyle: TextStyle(
                            color: frequency == f.$1
                                ? Barako.onPrimary
                                : Barako.text,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(null),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Barako.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final t = goalNum(target.text);
                        if (t <= 0) return;
                        Navigator.of(sheetContext).pop({
                          'name': name.text.trim().isEmpty
                              ? 'Goal'
                              : name.text.trim(),
                          'target': t,
                          // goalNum floors junk at 0, so a cleared field
                          // reads as zero saved, which is a valid correction.
                          'saved': goalNum(savedField.text),
                          'targetDate': deadline,
                          'frequency': frequency,
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.store.patchGoal(widget.goalId, saved);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('That did not save. Please try again.')),
      );
      return;
    }
    if (!mounted) return;
    // The receipt states the new pace: a plan change is a monetary write,
    // and a write shows what actually happened.
    final after = _goal();
    final r = after != null
        ? requiredContribution(after, DateTime.now())
        : null;
    final pace =
        r != null && (r['hasDeadline'] as bool) && (r['amount'] as double) > 0
        ? ' New pace: about ${formatMoneyAbout(r['amount'] as double)} each '
              '${r['frequency'] == 'weekly' ? 'week' : 'month'}.'
        : '';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('Plan updated.$pace')));
  }

  Future<void> _delete(Map<String, dynamic> g) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text(
          'Delete this goal?',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Your money does not change; only the tracking goes. Undo brings '
          'it back exactly as it was.',
          style: TextStyle(color: Barako.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep it', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Barako.warningStrong,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    // The FULL row, so Undo restores history, priority, pause state, and the
    // same id, not a stripped re-creation.
    final snapshot = {...g};
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await widget.store.deleteGoal(widget.goalId);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('That did not save, so the goal is still here.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    // clearSnackBars, not hideCurrentSnackBar: the delete receipt carries a
    // five-second Undo, and queued behind an earlier toast it would surface
    // with its window already spent. A receipt with a deadline never queues.
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Goal deleted'),
          duration: const Duration(seconds: 5),
          persist: false,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (widget.store.canWrite) {
                widget.store.restoreGoalRow(snapshot);
              }
            },
          ),
        ),
      );
    nav.pop();
  }
}

/// A small amount-entry sheet with inline validation, shared by Add money.
class _AmountSheet extends StatefulWidget {
  final String title;
  final String sub;
  final String? hint;
  final String confirm;
  const _AmountSheet({
    required this.title,
    required this.sub,
    this.hint,
    required this.confirm,
  });

  @override
  State<_AmountSheet> createState() => _AmountSheetState();
}

class _AmountSheetState extends State<_AmountSheet> {
  final amt = TextEditingController();
  String? error;

  @override
  void dispose() {
    amt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: Barako.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.sub,
              style: TextStyle(color: Barako.muted, fontSize: 12.5),
            ),
            if (widget.hint != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.hint!,
                style: TextStyle(
                  color: Barako.primaryText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: amt,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
              ],
              style: TextStyle(color: Barako.text),
              decoration: InputDecoration(
                labelText: 'Amount',
                labelStyle: TextStyle(color: Barako.muted),
                errorText: error,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Cancel', style: TextStyle(color: Barako.muted)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final v = goalNum(amt.text);
                    if (v <= 0) {
                      setState(() {
                        error = 'Enter an amount above zero.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(v);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                  ),
                  child: Text(
                    widget.confirm,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
