// Tell Salapify about your rent.
//
// Until this existed there was no way to. Every bill in the app arrived from a
// restored backup, `recurring.dart` was reachable by nothing, and the Upcoming
// segment's own empty state said "Add a bill that repeats" on a screen where
// that could not be done. An instruction nobody can follow is the defect this
// app has now shipped three times.
//
// THE FIGURE THIS FIXES. `upcomingCommitments` reads `data['recurring']` and
// safe to spend is liquid MINUS what it finds. With no bills recorded, rent
// counted as spendable. That is not a rounding error, it is the app being
// FLATTERING about the one number somebody spends against.
//
// Every field written here already exists in the v12 schema and is already
// normalised by `sanitizeData`: id, type, label, amount, dayOfMonth, accountId,
// lastPosted. No migration.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/account_taxonomy.dart' show AccountStore;
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/recurring.dart' show recurringSaveLastPosted;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../accounts/accounts_screen.dart' show accountKindLabel;
import '../shared/editor_safety.dart';
import 'recurring_rows.dart' show ordinalDay;

/// Open the editor. [existing] edits, null creates. True when saved.
Future<bool> showRecurringEditor(
  BuildContext context, {
  Map<String, dynamic>? existing,
}) async {
  final store = context.ledger;
  final now = context.now;
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    // The shell draws the nav bar over the tab's own Navigator, so a sheet
    // without this lands underneath it with Save unreachable.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LedgerScope(
      store: store,
      child: AppClock(
        now: now,
        child: _RecurringSheet(existing: existing),
      ),
    ),
  );
  return saved ?? false;
}

class _RecurringSheet extends StatefulWidget {
  const _RecurringSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_RecurringSheet> createState() => _RecurringSheetState();
}

class _RecurringSheetState extends State<_RecurringSheet> {
  late final _label = TextEditingController(
    text: (widget.existing?['label'] ?? '').toString(),
  );
  late final _amount = TextEditingController(
    text: widget.existing == null
        ? ''
        // `moneyField`, never toStringAsFixed(0). Opening the editor on a
        // 1,234.56 bill and pressing Save with no edit would otherwise store
        // 1,235: a stored figure changed by the act of looking at it.
        : moneyField(amountOf(widget.existing!['amount'])),
  );

  late bool _income = widget.existing?['type'] == 'income';
  late int _day = _initialDay();
  late String _accountId = (widget.existing?['accountId'] ?? '').toString();

  bool _saving = false;
  String? _error;

  int _initialDay() {
    final d = amountOf(widget.existing?['dayOfMonth']).round();
    if (d >= 1 && d <= 31) return d;
    return 1;
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_saving) return false;
    if (_label.text.trim().isEmpty) return false;
    final v = readMoney(_amount.text).value;
    return v != null && v > 0;
  }

  /// The cash accounts this can move, with their names.
  ///
  /// Only `accounts`, never assets or debts. A recurring item posts a
  /// transaction into an account and moves that balance; posting rent into a
  /// credit card row would move the wrong number in the wrong direction.
  List<Map<String, dynamic>> get _accounts => [
    for (final a
        in (context.ledger.data['accounts'] is List
            ? context.ledger.data['accounts'] as List
            : const []))
      if (a is Map) a.cast<String, dynamic>(),
  ];

  Future<void> _save() async {
    final read = readMoney(_amount.text);
    if (read.value == null) {
      setState(
        () => _error = read.negative
            ? 'An amount cannot be negative. Use the In or Out switch above.'
            : 'That amount cannot be read.',
      );
      return;
    }
    final amount = read.value!;
    if (amount <= 0) {
      setState(() => _error = 'Give it an amount above zero.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final ledger = context.ledger;
    final now = context.now;
    final id = (widget.existing?['id'] ?? '').toString();
    final label = _label.text.trim();

    // WHETHER THIS MONTH IS ALREADY DEALT WITH, decided by the golden locked
    // engine rather than here. Add a bill on the 20th whose day is the 3rd and
    // it must NOT be counted against what is left before payday: that money
    // already went out, and counting it would make safe to spend too low for
    // the rest of the month. `recurringSaveLastPosted` is the shipped app's own
    // rule for exactly this, including the edit case, where it refuses to stamp
    // backwards past a marker that is already further ahead.
    final stamp = recurringSaveLastPosted(
      dayOfMonth: _day,
      existingLastPosted: (widget.existing?['lastPosted'] ?? '').toString(),
      now: now,
      isEdit: widget.existing != null,
    );

    try {
      await ledger.mutate((draft) {
        final list = draft['recurring'] is List
            ? (draft['recurring'] as List)
            : <dynamic>[];
        final fields = {
          'type': _income ? 'income' : 'expense',
          'label': label,
          'amount': amount,
          'dayOfMonth': _day,
          'accountId': _accountId,
          'lastPosted': stamp,
        };

        if (id.isEmpty) {
          list.add({'id': 'rec_${now.microsecondsSinceEpoch}', ...fields});
        } else {
          for (var i = 0; i < list.length; i++) {
            final r = list[i];
            if (r is Map && r['id'] == id) {
              // SPREAD, never replace. A stored row can carry fields this
              // sheet does not edit, and rebuilding it from the form would
              // drop them silently.
              list[i] = {...r.cast<String, dynamic>(), ...fields};
            }
          }
        }
        draft['recurring'] = list;
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

  Future<void> _delete() async {
    final id = (widget.existing?['id'] ?? '').toString();
    if (id.isEmpty) return;

    // ASKED, because this one is not reversible. There is no undo for a
    // deleted recurring item, and deleting the rent quietly raises safe to
    // spend by the rent. The account editor does not confirm because adding an
    // account back costs a name and a number; a bill carries its posting
    // history marker with it.
    final sure = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialog) => AlertDialog(
        backgroundColor: context.skin.bg,
        title: Text(
          'Delete this?',
          style: TypeScale.sheetTitle(context.skin.text),
        ),
        content: Text(
          'It stops being counted against what you can spend, so your safe to '
          'spend goes UP by ${formatMoney(amountOf(widget.existing?['amount']))} '
          'a month. Entries it already posted stay in your Ledger.',
          style: TypeScale.subtitle(context.skin.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text('Keep it', style: TypeScale.action(context.skin.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text('Delete', style: TypeScale.action(context.skin.accent)),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.ledger.mutate((draft) {
        final list = draft['recurring'] is List
            ? (draft['recurring'] as List)
            : <dynamic>[];
        list.removeWhere((r) => r is Map && r['id'] == id);
        draft['recurring'] = list;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not delete. Nothing was changed.';
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

    return Padding(
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
              Text(
                editing ? 'Edit this' : 'Something that repeats',
                style: TypeScale.sheetTitle(skin.text),
              ),
              const SizedBox(height: 16),

              Segmented(
                options: const ['Goes out', 'Comes in'],
                index: _income ? 1 : 0,
                onPick: _saving
                    ? null
                    : (i) => setState(() => _income = i == 1),
              ),
              const SizedBox(height: 16),

              _Field(
                controller: _label,
                label: _income ? 'What is it' : 'What is the bill',
                hint: _income ? 'Sweldo' : 'Rent',
                autofocus: !editing,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 14),
              _Field(
                controller: _amount,
                label: 'Amount each month',
                number: true,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 16),

              Text(
                'Which day of the month',
                style: TypeScale.caption(skin.text3),
              ),
              const SizedBox(height: 8),
              _DayPicker(
                day: _day,
                enabled: !_saving,
                onPick: (d) => setState(() => _day = d),
              ),
              const SizedBox(height: 8),
              Text(
                // THE SHORT MONTH RULE, said out loud. Somebody picking the
                // 31st deserves to know what February does, and the engine
                // clamps rather than skipping.
                _day > 28
                    ? 'On ${ordinalDay(_day)}. In a shorter month it lands on '
                          'the last day instead.'
                    : 'On ${ordinalDay(_day)}, every month.',
                style: TypeScale.caption(skin.text3),
              ),
              const SizedBox(height: 16),

              Text('Which account', style: TypeScale.caption(skin.text3)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _accounts)
                    PickChip(
                      label: (a['name'] ?? '').toString(),
                      on: _accountId == a['id'],
                      onTap: _saving
                          ? null
                          : () => setState(
                              () => _accountId = (a['id'] ?? '').toString(),
                            ),
                    ),
                ],
              ),
              if (_accountId.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_accountLine(), style: TypeScale.caption(skin.text3)),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Text(_error!, style: TypeScale.caption(skin.accent)),
              ],

              const SizedBox(height: 20),
              PillButton(
                label: _saving ? 'Saving' : 'Save',
                icon: Icons.check_rounded,
                onTap: _canSave ? _save : null,
              ),
              if (editing) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _saving ? null : _delete,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      'Delete this',
                      textAlign: TextAlign.center,
                      style: TypeScale.action(skin.text2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _accountLine() {
    for (final a in _accounts) {
      if (a['id'] != _accountId) continue;
      final kind = accountKindLabel(a, AccountStore.accounts) ?? '';
      return _income
          ? 'It lands in ${a['name']}${kind.isEmpty ? '' : ', $kind'}.'
          : 'It comes out of ${a['name']}${kind.isEmpty ? '' : ', $kind'}.';
    }
    return '';
  }
}

/// 1 to 31, as chips rather than a text field.
///
/// A number field for a day of the month invites 0, 45 and "15th", all of
/// which the engine then has to interpret. Thirty one chips is more pixels and
/// no ambiguity, and it puts the common answers, payday and month end, one tap
/// away.
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.day,
    required this.enabled,
    required this.onPick,
  });

  final int day;
  final bool enabled;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (var d = 1; d <= 31; d++)
        PickChip(
          label: '$d',
          on: d == day,
          onTap: enabled ? () => onPick(d) : null,
        ),
    ],
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.number = false,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
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
            hintText: hint,
            hintStyle: TypeScale.rowTitle(skin.text3),
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
