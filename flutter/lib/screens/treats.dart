// Earn your treats. Temptation bundling: pair a small treat with a healthy
// action you define, tap a check-in when you do it, and the treat is earned
// once enough recent check-ins land. It never blocks a purchase and never
// counts your pesos. State lives in settings.treats, an existing backup key, so
// nothing here needs a migration. Every check-in and edit routes through the
// golden-locked treats engine so the rolling window and lifetime match the RN
// app to the day. Ported from the RN treats screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../money/treats.dart' as treats;
import '../theme.dart';
import '../widgets/pressable_scale.dart';

// A user can keep three treats at a time, same as the RN app: enough to bundle
// a few habits, few enough that the list stays a glance, not a chore.
const int maxTreats = 3;

class TreatsScreen extends StatelessWidget {
  final SalapifyStore store;
  const TreatsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Earn your treats',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
        actions: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final atCap = store.treatRules.length >= maxTreats;
              return TextButton(
                onPressed: atCap ? null : () => _openSheet(context, null),
                child: Text('+ Add',
                    style: TextStyle(
                        color: atCap ? Barako.faint : Barako.primaryText,
                        fontWeight: FontWeight.w700)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final rules = store.treatRules;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Pair a small treat with something healthy. Do the healthy '
                  'thing, tap one check-in, and the treat is yours guilt free.',
                  style: TextStyle(
                      color: Barako.textSecondary, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 18),
                if (rules.isEmpty)
                  ..._emptyState(context)
                else
                  for (final t in rules) _treatCard(context, t),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _emptyState(BuildContext context) => [
        Text('PICK ONE TO START', style: Barako.kickerStyle),
        const SizedBox(height: 12),
        for (final tpl in treats.treatTemplates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PressableScale(
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openSheet(context, null, template: tpl),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Text(tpl['emoji'] as String,
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tpl['treat'] as String,
                                  style: TextStyle(
                                      color: Barako.text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('${tpl['target']} x ${tpl['action']}',
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

  Widget _treatCard(BuildContext context, Map<String, dynamic> t) {
    final st = treats.treatStatus(t, DateTime.now());
    final earned = st['earned'] == true;
    final doneToday = st['doneToday'] == true;
    final target = st['target'] as int;
    final recent = st['recent'] as int;
    final remaining = st['remaining'] as int;
    final lifetime = st['lifetime'] as int;
    final treatName = (t['treat']?.toString() ?? 'Treat');
    final action = (t['action']?.toString() ?? 'your action');
    final emoji = st['emoji']?.toString() ?? '☕';

    final line = earned
        ? 'Earned. Enjoy your ${treatName.toLowerCase()}, you paid for it in '
            '${action.toLowerCase()}, not regret.'
        : recent == 0
            ? 'Do your ${action.toLowerCase()}, then tap below. $target check '
                'ins earns it.'
            : '$recent of $target self care check ins. $remaining more and it '
                'is yours.';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: earned ? Barako.positiveSurface : Barako.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: earned ? Barako.positiveBorder : Barako.border),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(treatName,
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(action,
                          style:
                              TextStyle(color: Barako.muted, fontSize: 13)),
                    ],
                  ),
                ),
                if (earned) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Barako.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: Barako.onPrimary, size: 13),
                        const SizedBox(width: 4),
                        Text('EARNED',
                            style: TextStyle(
                                color: Barako.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            // Progress dots, one per check-in needed, filled up to recent.
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < target; i++)
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < recent ? Barako.primary : Barako.border,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(line,
                style: TextStyle(
                    color: earned ? Barako.text : Barako.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: earned ? FontWeight.w600 : FontWeight.w400)),
            const SizedBox(height: 14),
            _CheckInButton(
              doneToday: doneToday,
              onTap: () {
                HapticFeedback.selectionClick();
                final id = t['id'];
                if (id is String && store.canWrite) {
                  store.toggleTreatCheckIn(id);
                } else if (!store.canWrite) {
                  _offBanner(context);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('$lifetime self care check ins in total',
                      style: TextStyle(color: Barako.faint, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _openSheet(context, t),
                  style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(44, 36)),
                  child: Text('Edit',
                      style: TextStyle(
                          color: Barako.primaryText,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _offBanner(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text(
              'Saving is off because your data could not be read. Import a backup to recover first.')));
  }

  void _openSheet(BuildContext context, Map<String, dynamic>? treat,
      {Map<String, dynamic>? template}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TreatSheet(store: store, treat: treat, template: template),
    );
  }
}

// The check-in button, its icon cross-fading between the two states rather than
// popping (polish rule: icon state changes cross-fade).
class _CheckInButton extends StatelessWidget {
  final bool doneToday;
  final VoidCallback onTap;
  const _CheckInButton({required this.doneToday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      child: Material(
        color: doneToday ? Barako.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: doneToday ? Barako.primary : Barako.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    doneToday
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    key: ValueKey(doneToday),
                    color: doneToday ? Barako.onPrimary : Barako.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  doneToday ? 'Done for today, tap to undo' : 'I did it today',
                  style: TextStyle(
                      color: doneToday ? Barako.onPrimary : Barako.primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The create/edit form as a bottom sheet. Owns its own controllers and the
/// target/window state so the list behind it stays clean.
class _TreatSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic>? treat;
  final Map<String, dynamic>? template;
  const _TreatSheet({required this.store, this.treat, this.template});

  @override
  State<_TreatSheet> createState() => _TreatSheetState();
}

class _TreatSheetState extends State<_TreatSheet> {
  late final TextEditingController _treat;
  late final TextEditingController _action;
  late final TextEditingController _emoji;
  late int _target;
  late int _windowDays;
  bool _confirmDel = false;

  bool get _isEdit => widget.treat != null;

  @override
  void initState() {
    super.initState();
    final t = widget.treat;
    final tpl = widget.template;
    _treat = TextEditingController(
        text: t?['treat']?.toString() ?? tpl?['treat']?.toString() ?? '');
    _action = TextEditingController(
        text: t?['action']?.toString() ?? tpl?['action']?.toString() ?? '');
    _emoji = TextEditingController(
        text: t?['emoji']?.toString() ?? tpl?['emoji']?.toString() ?? '☕');
    _target = _asInt(t?['target'] ?? tpl?['target'], 3, 1, 14);
    _windowDays = _asInt(t?['windowDays'] ?? tpl?['windowDays'], 7, 1, 31);
  }

  int _asInt(dynamic v, int dflt, int lo, int hi) {
    final n = v is num ? v.round() : int.tryParse(v?.toString() ?? '') ?? dflt;
    return n < lo ? lo : (n > hi ? hi : n);
  }

  @override
  void dispose() {
    _treat.dispose();
    _action.dispose();
    _emoji.dispose();
    super.dispose();
  }

  void _offBanner() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text(
              'Saving is off because your data could not be read. Import a backup to recover first.')));
  }

  Future<void> _save() async {
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final id = widget.treat?['id'];
    final fields = {
      'treat': _treat.text,
      'action': _action.text,
      'emoji': _emoji.text,
      'target': _target,
      'windowDays': _windowDays,
    };
    if (id is String) {
      await widget.store.updateTreat(id, fields);
    } else {
      // Enforce the cap at save time too, so a second sheet opened before the
      // list refreshed cannot slip past three.
      if (widget.store.treatRules.length >= maxTreats) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text(
                  'You can keep 3 treats at a time. Delete one to add another.')));
        return;
      }
      await widget.store.addTreat(fields);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _delete() {
    if (!_confirmDel) {
      setState(() => _confirmDel = true);
      return;
    }
    if (!widget.store.canWrite) {
      _offBanner();
      return;
    }
    final id = widget.treat?['id'];
    if (id is String) widget.store.deleteTreat(id);
    Navigator.of(context).pop();
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
            maxHeight: (MediaQuery.of(context).size.height - bottomInset) * 0.9),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEdit ? 'Edit treat' : 'New treat',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              _label('Treat'),
              _input(_treat, hint: 'e.g. milk tea'),
              _label('Healthy action'),
              _input(_action, hint: 'e.g. 30-minutong lakad'),
              _label('Emoji'),
              SizedBox(width: 90, child: _input(_emoji, hint: '☕', center: true)),
              _label('Check-ins to earn it'),
              _stepper(),
              _label('Within'),
              _segment(),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isEdit)
                    TextButton(
                      onPressed: _delete,
                      style: _confirmDel
                          ? TextButton.styleFrom(
                              backgroundColor:
                                  Barako.warningStrong.withValues(alpha: 0.12))
                          : null,
                      child: Text(
                          _confirmDel ? 'Tap again to delete' : 'Delete',
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: TextStyle(color: Barako.muted, fontSize: 12)),
      );

  Widget _input(TextEditingController c, {String? hint, bool center = false}) {
    return TextField(
      controller: c,
      textAlign: center ? TextAlign.center : TextAlign.start,
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

  Widget _stepper() {
    return Row(
      children: [
        _stepBtn(Icons.remove, 'Fewer check-ins to earn',
            () => setState(() => _target = _target > 1 ? _target - 1 : 1)),
        SizedBox(
          width: 56,
          child: Text('$_target',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Barako.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ),
        _stepBtn(Icons.add, 'More check-ins to earn',
            () => setState(() => _target = _target < 14 ? _target + 1 : 14)),
      ],
    );
  }

  Widget _stepBtn(IconData icon, String label, VoidCallback onTap) {
    return PressableScale(
      child: Material(
        color: Barako.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Barako.border),
            ),
            child: Semantics(
              label: label,
              button: true,
              child: Icon(icon, color: Barako.primaryText, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _segment() {
    Widget seg(String text, int days) {
      final on = _windowDays == days;
      return Expanded(
        child: PressableScale(
          child: Material(
            color: on ? Barako.primary : Barako.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _windowDays = days);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? Barako.primary : Barako.border),
                ),
                child: Text(text,
                    style: TextStyle(
                        color: on ? Barako.onPrimary : Barako.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        seg('This week', 7),
        const SizedBox(width: 8),
        seg('Two weeks', 14),
      ],
    );
  }
}
