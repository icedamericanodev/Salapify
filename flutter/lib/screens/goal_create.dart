// Create a goal: template-prefilled or from scratch, every field editable,
// and fast on purpose. The template path is tap, glance, Save; the form is
// one scrollable column that stays out of the keyboard's way.
//
// Money rules, stated because they are the design: creating a goal moves no
// money, the saved amount is a NUMBER the user tracks (usually held in a
// bank or wallet outside this app), and a debt-payoff goal never copies a
// balance: it links a debt the user already tracks and derives everything
// live, so payments logged on the debt move the goal by themselves.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../money/format.dart'
    show formatMoney, formatMoneyAbout, prettyMonthYear;
import '../money/goal_plan.dart';
import '../money/goals_calc.dart' show goalNum;
import '../money/ledger.dart' show amountOf;
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';

/// The curated icon choices for a new goal, semantic key to the spoken
/// label a screen reader announces (a raw key like "familySupport" read
/// aloud is nobody's language). A goal saved from here stores the KEY; a
/// goal whose owner typed an emoji in the edit sheet keeps the emoji. Both
/// are honored forever by the cards.
const Map<String, String> goalIconChoices = {
  'goal': 'Target',
  'emergency': 'Emergency fund',
  'pasko': 'Pasko',
  'travel': 'Travel',
  'education': 'Education',
  'familySupport': 'Family support',
  'health': 'Health',
  'gadget': 'Gadget',
  'wedding': 'Wedding',
  'house': 'House',
  'savings': 'Savings',
  'cash': 'Cash',
};

/// The accent choices, as theme token NAMES so a palette switch or a
/// restored backup can never carry a stale hex.
const List<(String, String)> goalAccentChoices = [
  ('primary', 'Orange'),
  ('caramel', 'Caramel'),
  ('celebrate', 'Gold'),
];

Color goalAccentColor(String? key) => switch (key) {
  'caramel' => Barako.caramel,
  'celebrate' => Barako.celebrate,
  _ => Barako.primary,
};

class GoalCreateScreen extends StatefulWidget {
  final SalapifyStore store;
  final GoalTemplate? template;
  const GoalCreateScreen({super.key, required this.store, this.template});

  @override
  State<GoalCreateScreen> createState() => _GoalCreateScreenState();
}

class _GoalCreateScreenState extends State<GoalCreateScreen> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  final TextEditingController _saved = TextEditingController();
  String _deadline = ''; // ISO or empty
  String _frequency = 'monthly';
  late String _icon;
  late String _accent;
  String? _linkedDebtId;
  String? _error;
  bool _saving = false;

  bool get _isDebt => widget.template?.kind == 'debt';

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _name = TextEditingController(
      text: t == null || t.key == 'custom' ? '' : t.name,
    );
    _target = TextEditingController(
      text: t?.suggestedTarget != null
          ? t!.suggestedTarget!.toInt().toString()
          : '',
    );
    _deadline = t?.suggestedDeadline ?? '';
    _icon = t?.icon ?? 'goal';
    _accent = t?.accent ?? 'primary';
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _liveDebts => [
    for (final d
        in (widget.store.data['debts'] is List
            ? widget.store.data['debts'] as List
            : const []))
      if (d is Map && amountOf(d['remaining']) > 0) d.cast<String, dynamic>(),
  ];

  /// The review line: what the numbers on this form add up to, before Save.
  String? _reviewLine() {
    if (_isDebt) return null;
    final target = goalNum(_target.text);
    if (target <= 0) return null;
    final saved = goalNum(_saved.text);
    final draft = {
      'target': target,
      'saved': saved,
      'targetDate': _deadline,
      'frequency': _frequency,
    };
    final r = requiredContribution(draft, DateTime.now());
    final amount = (r['amount'] as double);
    final word = _frequency == 'weekly' ? 'week' : 'month';
    if (saved >= target) {
      return 'Already at the target. Save it to keep the record.';
    }
    if (!(r['hasDeadline'] as bool) || amount <= 0) {
      return 'No deadline set. Add money at your own pace, and the goal '
          'will show how far along you are.';
    }
    return 'To reach ${formatMoney(target)} by '
        '${prettyMonthYear(_deadline)}, set aside about '
        '${formatMoneyAbout(amount)} each $word.';
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_deadline);
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(now)
          ? DateTime(now.year, now.month + 3, now.day)
          : current,
      firstDate: now,
      lastDate: DateTime(now.year + 30),
      helpText: 'Target date',
    );
    if (picked == null) return;
    setState(() {
      _deadline =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    if (!widget.store.canWrite) {
      setState(() {
        _error =
            'Saving is off because your data could not be read. Import a '
            'backup to recover first.';
      });
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (_isDebt) {
      final debt = _liveDebts
          .where((d) => d['id'] == _linkedDebtId)
          .firstOrNull;
      if (debt == null) {
        setState(() => _error = 'Pick which debt this goal follows.');
        return;
      }
      final name = _name.text.trim().isEmpty
          ? 'Pay off ${debt['name'] ?? 'a debt'}'
          : _name.text.trim();
      setState(() => _saving = true);
      try {
        await widget.store.addGoal(
          name: name,
          target: 0, // derived live from the debt; a copy here would go stale
          saved: 0,
          targetDate: '',
          kind: 'debt',
          iconKey: _icon,
          accent: _accent,
          linkedDebtId: debt['id'] as String,
          startLevel: amountOf(debt['remaining']),
          createdAt: DateTime.now().toIso8601String().substring(0, 10),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _error = 'That did not save, so nothing changed. Please try again.';
        });
        return;
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Goal created. Payments you log on the debt move it forward.',
          ),
        ),
      );
      nav.pop();
      return;
    }
    final target = goalNum(_target.text);
    if (target <= 0) {
      setState(() => _error = 'Enter a target amount above zero.');
      return;
    }
    final saved = goalNum(_saved.text);
    // A custom goal must be NAMED: its template name is the picker copy
    // ("Your own goal"), which would read like the app named it.
    if (_name.text.trim().isEmpty &&
        (widget.template == null || widget.template!.key == 'custom')) {
      setState(() => _error = 'Give this goal a name.');
      return;
    }
    final name = _name.text.trim().isEmpty
        ? (widget.template?.name ?? 'Goal')
        : _name.text.trim();
    setState(() => _saving = true);
    try {
      await widget.store.addGoal(
        name: name,
        target: target,
        saved: saved,
        targetDate: _deadline,
        kind: 'savings',
        iconKey: _icon,
        accent: _accent,
        frequency: _frequency,
        createdAt: DateTime.now().toIso8601String().substring(0, 10),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'That did not save, so nothing changed. Please try again.';
      });
      return;
    }
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    final review = _reviewLine();
    return Scaffold(
      backgroundColor: Barako.background,
      appBar: AppBar(
        title: Text(t == null || t.key == 'custom' ? 'Create a goal' : t.name),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (t != null && t.why != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.field),
                  border: Border.all(color: Barako.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WHERE THIS SUGGESTION COMES FROM',
                      style: Barako.kickerStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(t.why!, style: AppText.small.copyWith(height: 1.45)),
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),
            ],
            if (t != null &&
                t.key == 'emergency' &&
                t.suggestedTarget == null) ...[
              Text(
                'Not enough data for a suggestion. Enter the amount that '
                'would cover your month.',
                style: AppText.small.tint(Barako.muted),
              ),
              const SizedBox(height: Gap.md),
            ],
            _label('Name'),
            _input(
              _name,
              hint: t == null || t.key == 'custom'
                  ? 'e.g. Emergency fund'
                  : t.name,
              action: TextInputAction.next,
            ),
            if (_isDebt) ...[
              _label('Which debt does this follow?'),
              const SizedBox(height: 4),
              for (final d in _liveDebts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.field),
                    onTap: () =>
                        setState(() => _linkedDebtId = d['id'] as String?),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Barako.card,
                        borderRadius: BorderRadius.circular(Radii.field),
                        border: Border.all(
                          color: _linkedDebtId == d['id']
                              ? Barako.primary
                              : Barako.border,
                          width: _linkedDebtId == d['id'] ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            salapifyIcon(
                              _linkedDebtId == d['id']
                                  ? 'selected'
                                  : 'unselected',
                            ),
                            size: 20,
                            color: _linkedDebtId == d['id']
                                ? Barako.primary
                                : Barako.muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              (d['name'] ?? 'Debt').toString(),
                              style: TextStyle(
                                color: Barako.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            formatMoney(amountOf(d['remaining'])),
                            style: TextStyle(
                              color: Barako.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_liveDebts.isEmpty)
                Text(
                  'No debts with a balance right now. Track one on the '
                  'Utang tab first.',
                  style: AppText.small.tint(Barako.muted),
                ),
            ] else ...[
              _label('Target amount'),
              _input(
                _target,
                hint: '0',
                number: true,
                action: TextInputAction.next,
              ),
              _label('Saved so far (kept in your bank or wallet)'),
              _input(
                _saved,
                hint: '0',
                number: true,
                action: TextInputAction.done,
              ),
              _label('Target date'),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDeadline,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Barako.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(
                        salapifyIcon('calendar'),
                        size: SalapifyIconSize.inline,
                        color: Barako.primaryText,
                      ),
                      label: Text(
                        _deadline.isEmpty
                            ? 'Pick a date (optional)'
                            : prettyMonthYear(_deadline),
                        style: TextStyle(color: Barako.text),
                      ),
                    ),
                  ),
                  if (_deadline.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _deadline = ''),
                      child: Text(
                        'Clear',
                        style: TextStyle(color: Barako.muted),
                      ),
                    ),
                ],
              ),
              _label('How often will you add to it?'),
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
                        selected: _frequency == f.$1,
                        onSelected: (_) => setState(() => _frequency = f.$1),
                        selectedColor: Barako.primary,
                        labelStyle: TextStyle(
                          color: _frequency == f.$1
                              ? Barako.onPrimary
                              : Barako.text,
                          fontWeight: FontWeight.w600,
                        ),
                        avatar: _frequency == f.$1
                            ? Icon(
                                salapifyIcon('check'),
                                size: 16,
                                color: Barako.onPrimary,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ],
            _label('Icon'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: key, value: spoken)
                    in goalIconChoices.entries)
                  Semantics(
                    button: true,
                    selected: _icon == key,
                    label: '$spoken icon',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.field),
                      onTap: () => setState(() => _icon = key),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _icon == key
                              ? goalAccentColor(_accent).withValues(alpha: 0.16)
                              : Barako.card,
                          borderRadius: BorderRadius.circular(Radii.field),
                          border: Border.all(
                            color: _icon == key
                                ? goalAccentColor(_accent)
                                : Barako.border,
                            width: _icon == key ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          salapifyIcon(key),
                          size: SalapifyIconSize.action,
                          color: _icon == key
                              ? goalAccentColor(_accent)
                              : Barako.muted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            _label('Color'),
            Row(
              children: [
                for (final (key, label) in goalAccentChoices)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Semantics(
                      button: true,
                      selected: _accent == key,
                      label: 'Color $label',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.pill),
                        onTap: () => setState(() => _accent = key),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: goalAccentColor(key),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _accent == key
                                      ? Barako.text
                                      : Barako.border,
                                  width: _accent == key ? 2 : 1,
                                ),
                              ),
                              // Selection is never color alone: the picked
                              // disc carries the check.
                              child: _accent == key
                                  ? Icon(
                                      salapifyIcon('check'),
                                      size: 18,
                                      color: Barako.onPrimary,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(label, style: AppText.micro.w4),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (review != null) ...[
              const SizedBox(height: Gap.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.field),
                  border: Border.all(color: Barako.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR PLAN, IN ONE LINE', style: Barako.kickerStyle),
                    const SizedBox(height: 6),
                    Text(
                      review,
                      style: AppText.label.w4.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Gap.md),
              Text(_error!, style: AppText.small.tint(Barako.warningStrong)),
            ],
            const SizedBox(height: Gap.xl),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Barako.primary,
                foregroundColor: Barako.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _saving ? 'Saving' : 'Save goal',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Creating a goal never moves money. Your account balances '
              'stay exactly as they are.',
              textAlign: TextAlign.center,
              style: AppText.caption.tint(Barako.faint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: Gap.lg, bottom: 6),
    child: Text(text, style: AppText.caption),
  );

  Widget _input(
    TextEditingController c, {
    String? hint,
    bool number = false,
    TextInputAction? action,
  }) {
    return TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textInputAction: action,
      inputFormatters: number
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))]
          : null,
      style: AppText.body,
      // The theme's input decoration carries fill, borders and hint color.
      decoration: InputDecoration(hintText: hint),
    );
  }
}
