// Make a goal, change one, put money in it, and pause it.
//
// Without this file the Goals segment is a list of things the app can display
// and nobody can create, which is the same defect the budget editor was built
// to fix ("a screen called Budget, showing four rows that all said No limit
// set, with nothing anywhere in the app that could set one").
//
// NO ACCOUNT PICKER, AND THAT IS THE POINT. A debt payment needs one, because
// money genuinely leaves an account. A goal does not, because a goal's money is
// a NUMBER THE USER TRACKS and not a balance: the 12,000 saved toward an
// emergency fund is already sitting in a bank account, counted once there. The
// rule is the engine's, stated at the top of core/money/goal_plan.dart, and
// obeyed by the shipped app's `addGoalFunds`, which writes `saved` and a
// `contributions` row and touches no account. Adding a picker here would make
// the app subtract the same peso twice.
//
// Every stored field written below already exists in the v12 schema and is
// already read by the golden locked `goalPace`: id, name, target, saved,
// targetDate, createdAt, startSaved, paused, contributions. No migration.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/editor_safety.dart';

/// yyyy-mm-dd, the one format every stored date in this app uses.
String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Open the goal editor. [existing] edits, null creates. True when saved.
Future<bool> showGoalEditor(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final store = context.ledger;
  final now = context.now;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // The shell draws the nav bar over the tab's own Navigator, so a sheet
    // without this lands underneath it with Save unreachable. See
    // account_editor.dart, which learned it the hard way.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LedgerScope(
      store: store,
      child: AppClock(
        now: now,
        child: _GoalSheet(existing: existing),
      ),
    ),
  );
  return saved ?? false;
}

/// Put money into a goal. True when something was added.
Future<bool> showGoalFunding(
  BuildContext context, {
  required Map<String, dynamic> goal,
}) async {
  final store = context.ledger;
  final now = context.now;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LedgerScope(
      store: store,
      child: AppClock(
        now: now,
        child: _FundingSheet(goal: goal),
      ),
    ),
  );
  return saved ?? false;
}

// ---------------------------------------------------------------------------

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final _name = TextEditingController(
    text: (widget.existing?['name'] ?? '').toString(),
  );
  late final _target = TextEditingController(
    text: widget.existing == null
        ? ''
        // `moneyField`, never toStringAsFixed(0). Opening an editor on a
        // target of 45,000.50 and pressing Save with no edit would otherwise
        // store 45,001: a stored figure changed by the act of looking at it.
        : moneyField(amountOf(widget.existing!['target'])),
  );

  /// The deadline, or null for "no date yet", which is a real and common
  /// choice rather than an unfinished form. `goalPace` returns status
  /// 'no-date' for it and asks for no monthly figure, and the row says so.
  late DateTime? _date = _parseStored(widget.existing?['targetDate']);

  bool _saving = false;
  String? _error;

  static DateTime? _parseStored(dynamic v) {
    if (v is! String || v.length < 7) return null;
    final y = int.tryParse(v.substring(0, 4));
    final m = int.tryParse(v.substring(5, 7));
    if (y == null || m == null || m < 1 || m > 12) return null;
    if (v.length < 10) return DateTime(y, m + 1, 0);
    final d = int.tryParse(v.substring(8, 10));
    return d == null ? DateTime(y, m + 1, 0) : DateTime(y, m, d);
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_saving) return false;
    if (_name.text.trim().isEmpty) return false;
    final t = readMoney(_target.text).value;
    return t != null && t > 0;
  }

  Future<void> _save() async {
    final read = readMoney(_target.text);
    if (read.value == null) {
      setState(
        () => _error = read.negative
            ? 'A target cannot be negative.'
            : 'That target cannot be read as an amount.',
      );
      return;
    }
    final target = read.value!;
    if (target <= 0) {
      setState(() => _error = 'Give the goal a target above zero.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ledger = context.ledger;
    final now = context.now;
    final name = _name.text.trim();
    final dateIso = _date == null ? '' : _iso(_date!);
    final id = (widget.existing?['id'] ?? '').toString();

    try {
      await ledger.mutate((draft) {
        final goals = draft['goals'] is List
            ? (draft['goals'] as List)
            : <dynamic>[];
        if (id.isEmpty) {
          goals.add({
            'id': 'goal_${now.microsecondsSinceEpoch}',
            'name': name,
            'target': target,
            'saved': 0.0,
            'targetDate': dateIso,
            // createdAt and startSaved are what `expectedByToday` paces
            // against. A goal without them has no pace to be behind and reads
            // On track forever, which is not wrong but is not useful either.
            'createdAt': _iso(now),
            'startSaved': 0.0,
          });
        } else {
          for (var i = 0; i < goals.length; i++) {
            final g = goals[i];
            if (g is Map && g['id'] == id) {
              // SPREAD, never replace. A stored goal carries fields this
              // sheet does not edit, `contributions` above all, and rebuilding
              // the map from the form would silently delete the user's whole
              // funding history on a rename.
              goals[i] = {
                ...g.cast<String, dynamic>(),
                'name': name,
                'target': target,
                'targetDate': dateIso,
              };
            }
          }
        }
        draft['goals'] = goals;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Nothing was changed.';
      });
      return;
    }

    if (!mounted) return;
    closeAfterSaving(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final editing = widget.existing != null;

    return _Sheet(
      title: editing ? 'Edit goal' : 'New goal',
      children: [
        _Field(controller: _name, label: 'What is it for', autofocus: !editing),
        const SizedBox(height: 14),
        _Field(
          controller: _target,
          label: 'Target amount',
          number: true,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 14),

        Text('Target date', style: TypeScale.caption(skin.text3)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: PillButton(
                label: _date == null
                    ? 'Pick a date'
                    : '${_date!.day}/${_date!.month}/${_date!.year}',
                icon: Icons.event_outlined,
                onTap: _saving ? null : _pickDate,
              ),
            ),
            if (_date != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _saving ? null : () => setState(() => _date = null),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 6,
                  ),
                  child: Text('Clear', style: TypeScale.action(skin.accent)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // NO DATE IS A CHOICE, said plainly, because a blank field with no
        // explanation reads as a form somebody failed to finish. It also says
        // what is lost, so the choice is informed rather than accidental.
        Text(
          _date == null
              ? 'No date is fine. Without one there is nothing to pace '
                    'against, so the row shows what is left instead of a '
                    'monthly figure.'
              : 'The row will show what it takes each month to make this date.',
          style: TypeScale.caption(skin.text3),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: TypeScale.caption(skin.accent)),
        ],

        const SizedBox(height: 20),
        PillButton(
          label: _saving ? 'Saving' : 'Save goal',
          icon: Icons.check_rounded,
          onTap: _canSave ? _save : null,
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = context.now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime(now.year, now.month + 6, now.day),
      // TODAY is the floor. A target date in the past gives goalPace status
      // 'behind' with a deadline it can never divide by, so the row would say
      // "was due" on a goal created five seconds ago.
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }
}

// ---------------------------------------------------------------------------

class _FundingSheet extends StatefulWidget {
  const _FundingSheet({required this.goal});
  final Map<String, dynamic> goal;

  @override
  State<_FundingSheet> createState() => _FundingSheetState();
}

class _FundingSheetState extends State<_FundingSheet> {
  final _amount = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_saving) return false;
    final v = readMoney(_amount.text).value;
    return v != null && v > 0;
  }

  Future<void> _save() async {
    final read = readMoney(_amount.text);
    if (read.value == null || read.value! <= 0) {
      setState(
        () => _error = read.negative
            ? 'Use a positive amount. To correct a mistake, edit the goal.'
            : 'That amount cannot be read.',
      );
      return;
    }
    final amount = read.value!;

    setState(() {
      _saving = true;
      _error = null;
    });

    final ledger = context.ledger;
    final today = _iso(context.now);
    final id = (widget.goal['id'] ?? '').toString();

    try {
      await ledger.mutate((draft) {
        final goals = draft['goals'] is List
            ? (draft['goals'] as List)
            : <dynamic>[];
        for (var i = 0; i < goals.length; i++) {
          final g = goals[i];
          if (g is! Map || g['id'] != id) continue;
          final gm = g.cast<String, dynamic>();

          // ADDS ON TOP OF THE STORED SAVED, never on top of a form field.
          // The shipped app's `addGoalFunds` says exactly this and it is not
          // pedantry: reading the figure into the sheet and writing back a
          // computed total means a stale sheet, left open while something
          // else changed, saves the OLD total and quietly erases whatever
          // happened in between.
          final base = amountOf(gm['saved']);
          final next = base + amount;

          goals[i] = {
            ...gm,
            'saved': next > 0 ? next : 0.0,
            'contributions': [
              ...(gm['contributions'] is List
                  ? gm['contributions'] as List
                  : const []),
              {
                'id': 'goalTx_${DateTime.now().microsecondsSinceEpoch}',
                'amount': amount,
                'date': today,
              },
            ],
          };
        }
        draft['goals'] = goals;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Nothing was added.';
      });
      return;
    }

    if (!mounted) return;
    closeAfterSaving(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final saved = amountOf(widget.goal['saved']);
    final target = amountOf(widget.goal['target']);
    final left = (target - saved) > 0 ? target - saved : 0.0;

    return _Sheet(
      title: 'Add to ${(widget.goal['name'] ?? 'goal')}',
      children: [
        // The two figures somebody needs before typing, so the amount is
        // chosen against the real position rather than from memory.
        Text(
          left > 0
              ? '${formatMoney(saved)} saved of ${formatMoney(target)}. '
                    '${formatMoney(left)} to go.'
              : '${formatMoney(saved)} saved. This goal is already there.',
          style: TypeScale.subtitle(skin.text2),
        ),
        const SizedBox(height: 16),
        _Field(
          controller: _amount,
          label: 'Amount to add',
          number: true,
          autofocus: true,
          onChanged: () => setState(() {}),
        ),
        const SizedBox(height: 10),

        // THE SENTENCE THAT STOPS THE DOUBLE COUNT, and it is the most
        // important copy on this screen. Somebody who has used any envelope
        // app expects this to move money out of an account. It does not, and
        // discovering that later, from a balance that did not change, reads as
        // the app being broken.
        Text(
          'This records what you have set aside. It does not move money '
          'between your accounts, and your balances stay as they are.',
          style: TypeScale.caption(skin.text3),
        ),

        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: TypeScale.caption(skin.accent)),
        ],

        const SizedBox(height: 20),
        PillButton(
          label: _saving ? 'Saving' : 'Add it',
          icon: Icons.add_rounded,
          onTap: _canSave ? _save : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// The sheet chrome both of the above sit in.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Padding(
      // The keyboard inset. Both sheets have a text field and one of them
      // autofocuses, so without this the field the user is typing into sits
      // behind the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: skin.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 26),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TypeScale.sheetTitle(skin.text)),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.number = false,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool number;
  final bool autofocus;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TypeScale.caption(skin.text3)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: TypeScale.rowTitle(skin.text),
          onChanged: (_) => onChanged?.call(),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: skin.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
