// Goals: savings goals with progress bars, reached from the Overview. Add and
// edit goals, add money to a goal (which only updates the goal number, it never
// moves money out of an account), and delete one. Ported from the RN goals
// screen. Goals is an existing backup collection, so nothing here needs a
// migration. The per-month pace reuses the golden-locked analytics.goalPace so
// the number matches the live app and the Insights card.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../money/analytics.dart' as analytics;
import '../money/debtmath.dart' show formatMoneyText;
import '../data/store.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';

// The three or four goals Filipinos actually start with, for the empty state.
const _templates = [
  {'icon': '🛟', 'name': 'Emergency fund', 'target': 10000.0},
  {'icon': '🎄', 'name': 'Pasko fund', 'target': 5000.0},
  {'icon': '✈️', 'name': 'Travel fund', 'target': 15000.0},
  {'icon': '🩺', 'name': 'Health fund', 'target': 10000.0},
];

/// Money fields accept commas: "12,000" means twelve thousand, floored at zero.
/// Matches the RN toNum so a pasted "12,000" is never read as 0.
double goalNum(String t) {
  var cleaned = t.replaceAll(RegExp(r'[, ]'), '');
  // JS Number tolerates a single trailing dot ("100." parses to 100); Dart's
  // parser does not, so drop one trailing dot to match RN toNum exactly.
  if (cleaned.endsWith('.')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  final n = double.tryParse(cleaned) ?? 0;
  return n > 0 ? n : 0;
}

/// Whole-number percent for the badge, min 100, matching the RN display math
/// (Math.round((saved / target) * 100), capped). Math.round is floor(x + 0.5).
int goalPercent(double saved, double target) {
  if (target > 0) {
    final p = (saved / target * 100 + 0.5).floor();
    return p > 100 ? 100 : (p < 0 ? 0 : p);
  }
  return saved > 0 ? 100 : 0;
}

class GoalsScreen extends StatelessWidget {
  final SalapifyStore store;
  const GoalsScreen({super.key, required this.store});

  List<Map<String, dynamic>> _goals() {
    final raw = store.data['goals'];
    return [
      for (final g in (raw is List ? raw : const []))
        if (g is Map) g.cast<String, dynamic>(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Goals',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: () => _openSheet(context, null),
            child: Text('+ Add',
                style: TextStyle(
                    color: Barako.primaryText, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final goals = _goals();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: goals.isEmpty
                  ? _emptyState(context)
                  : [for (final g in goals) _goalCard(context, g)],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _emptyState(BuildContext context) => [
        const SizedBox(height: 8),
        Center(
          child: Column(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 10),
              Text('No goals yet',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Start with a classic, or tap + Add for your own.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Barako.muted, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final t in _templates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PressableScale(
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openSheet(context, null,
                      name: t['name'] as String,
                      target: (t['target'] as double)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(t['icon'] as String,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t['name'] as String,
                                  style: TextStyle(
                                      color: Barako.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                  'Suggested start: ${formatMoneyText(t['target'] as double)}. Change anything.',
                                  style: TextStyle(
                                      color: Barako.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: Barako.faint, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ];

  Widget _goalCard(BuildContext context, Map<String, dynamic> g) {
    final pace = analytics.goalPace(g, DateTime.now());
    final saved = (pace['saved'] as num).toDouble();
    final target = (pace['target'] as num).toDouble();
    final pct = goalPercent(saved, target);
    final targetDate = (pace['targetDate'] as String?) ?? '';
    final isActive = pace['status'] == 'active';
    final perMonth = (pace['perMonth'] as num?) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PressableScale(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openSheet(context, g),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(g['name']?.toString() ?? 'Goal',
                            style: TextStyle(
                                color: Barako.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      Text('$pct%',
                          style: TextStyle(
                              color: Barako.primaryText,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 10,
                      backgroundColor: Barako.border,
                      color: Barako.primary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${formatMoneyText(saved)} of ${formatMoneyText(target)}'
                    '${targetDate.isNotEmpty ? ' . by $targetDate' : ''}',
                    style: TextStyle(color: Barako.muted, fontSize: 13),
                  ),
                  if (isActive && perMonth > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                        'Save ${formatMoneyText(perMonth)} a month and you make it.',
                        style: TextStyle(
                            color: Barako.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context, Map<String, dynamic>? goal,
      {String? name, double? target}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalSheet(
        store: store,
        goal: goal,
        prefillName: name,
        prefillTarget: target,
      ),
    );
  }
}

/// The add/edit form, shown as a bottom sheet. Owns its own controllers so the
/// list behind it stays clean. All writes are guarded on canWrite so a
/// read-only store (after a failed load) never throws.
class _GoalSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic>? goal;
  final String? prefillName;
  final double? prefillTarget;
  const _GoalSheet({
    required this.store,
    required this.goal,
    this.prefillName,
    this.prefillTarget,
  });

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  late final TextEditingController _date;
  final _funds = TextEditingController();
  bool _confirmDel = false;

  bool get _isEdit => widget.goal != null;

  String _numStr(dynamic v) {
    if (v is num) {
      // Whole pesos show without a trailing .0, decimals keep their value.
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    return v?.toString() ?? '';
  }

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _name = TextEditingController(
        text: g != null ? (g['name']?.toString() ?? '') : (widget.prefillName ?? ''));
    _target = TextEditingController(
        text: g != null
            ? _numStr(g['target'])
            : (widget.prefillTarget != null
                ? _numStr(widget.prefillTarget)
                : ''));
    _saved = TextEditingController(text: g != null ? _numStr(g['saved']) : '');
    _date = TextEditingController(
        text: g != null ? (g['targetDate']?.toString() ?? '') : '');
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    _date.dispose();
    _funds.dispose();
    super.dispose();
  }

  void _save() {
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final name = _name.text.trim().isEmpty ? 'Goal' : _name.text.trim();
    final target = goalNum(_target.text);
    final saved = goalNum(_saved.text);
    final date = _date.text.trim();
    if (_isEdit) {
      widget.store.updateGoal(widget.goal!['id'] as String,
          name: name, target: target, saved: saved, targetDate: date);
    } else {
      widget.store
          .addGoal(name: name, target: target, saved: saved, targetDate: date);
    }
    Navigator.of(context).pop();
  }

  void _applyFunds() {
    final amt = goalNum(_funds.text);
    final id = widget.goal?['id'];
    if (id is! String || amt == 0) return;
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    widget.store.addGoalFunds(id, amt);
    // Reflect the new stored total in the editable field, matching RN.
    final g = (widget.store.data['goals'] as List? ?? const [])
        .whereType<Map>()
        .cast<Map<String, dynamic>>()
        .firstWhere((x) => x['id'] == id, orElse: () => <String, dynamic>{});
    if (g.isNotEmpty) _saved.text = _numStr(g['saved']);
    _funds.clear();
    FocusScope.of(context).unfocus();
  }

  void _delete() {
    if (!_confirmDel) {
      setState(() => _confirmDel = true);
      return;
    }
    final id = widget.goal?['id'];
    if (id is String && widget.store.canWrite) {
      widget.store.deleteGoal(id);
    }
    Navigator.of(context).pop();
  }

  void _offBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text(
              'Saving is off because your data could not be read. Import a backup to recover first.')));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit goal' : 'Add goal',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              _field('Name', _name, hint: 'e.g. Emergency fund'),
              _field('Target amount', _target,
                  hint: '0', number: true),
              _field('Saved so far', _saved, hint: '0', number: true),
              _field('Target date (optional)', _date, hint: 'e.g. 2026-12-31'),
              if (_isEdit) ...[
                const SizedBox(height: 18),
                Divider(color: Barako.border, height: 1),
                const SizedBox(height: 12),
                Text('ADD TO SAVINGS', style: Barako.kickerStyle),
                const SizedBox(height: 6),
                Text(
                    'This only updates the goal number. It does not move money out of any account.',
                    style: TextStyle(color: Barako.faint, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _rawInput(_funds, hint: '0', number: true)),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _applyFunds,
                      style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Add',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isEdit)
                    TextButton(
                      onPressed: _delete,
                      child: Text(_confirmDel ? 'Tap to confirm' : 'Delete',
                          style: TextStyle(
                              color: Barako.warningStrong,
                              fontWeight: FontWeight.w600)),
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel',
                            style: TextStyle(color: Barako.textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: Barako.primary,
                          foregroundColor: Barako.onPrimary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 14),
                        ),
                        child: const Text('Save',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {String? hint, bool number = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(label, style: TextStyle(color: Barako.muted, fontSize: 12)),
        const SizedBox(height: 6),
        _rawInput(c, hint: hint, number: number),
      ],
    );
  }

  Widget _rawInput(TextEditingController c,
      {String? hint, bool number = false}) {
    return TextField(
      controller: c,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))]
          : null,
      style: TextStyle(color: Barako.text, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Barako.faint),
        filled: true,
        fillColor: Barako.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Barako.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Barako.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Barako.primary),
        ),
      ),
    );
  }
}
