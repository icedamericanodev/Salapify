// Hatian: the sheet that splits an expense you already logged. You fronted the
// bill; this turns each friend's share into utang you can collect, and shrinks
// the logged expense to your own share, so exactly the fronted total ever left
// your account. Every peso shown comes from money/splits.dart, never invented
// here. Reached from a logged expense row in History.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/ledger.dart' show amountOf;
import '../money/splits.dart' as splits;
import '../theme.dart';
import '../widgets/pressable_scale.dart';

/// Open the split sheet for a logged expense transaction. No-op if the txn is
/// not a plain expense with a positive amount.
void showSplitSheet(
  BuildContext context,
  SalapifyStore store,
  Map<String, dynamic> txn,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SplitSheet(store: store, txn: txn),
  );
}

class _Participant {
  final String name;
  final bool isYou;
  bool included = true;
  final TextEditingController custom = TextEditingController();
  _Participant(this.name, {this.isYou = false});
}

class _SplitSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic> txn;
  const _SplitSheet({required this.store, required this.txn});

  @override
  State<_SplitSheet> createState() => _SplitSheetState();
}

class _SplitSheetState extends State<_SplitSheet> {
  late final double _total;
  late final TextEditingController _activity;
  final List<_Participant> _people = [];
  final TextEditingController _newName = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _total = amountOf(widget.txn['amount']);
    _activity = TextEditingController(
      text: widget.txn['label']?.toString().trim() ?? '',
    );
    _people.add(_Participant('You', isYou: true));
  }

  @override
  void dispose() {
    _activity.dispose();
    _newName.dispose();
    for (final p in _people) {
      p.custom.dispose();
    }
    super.dispose();
  }

  List<String> get _existingNames {
    final seen = <String>{'you'};
    for (final p in _people) {
      seen.add(p.name.toLowerCase());
    }
    final out = <String>[];
    for (final p in (widget.store.data['people'] as List? ?? const [])) {
      if (p is Map && p['name'] is String) {
        final n = (p['name'] as String).trim();
        if (n.isNotEmpty && !seen.contains(n.toLowerCase())) {
          seen.add(n.toLowerCase());
          out.add(n);
        }
      }
    }
    return out;
  }

  void _addPerson(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    if (_people.any((p) => p.name.toLowerCase() == n.toLowerCase())) return;
    setState(() => _people.add(_Participant(n)));
  }

  List<Map<String, dynamic>> get _planInput => [
    for (final p in _people)
      {
        'name': p.name,
        'isYou': p.isYou,
        'included': p.included,
        if (p.custom.text.trim().isNotEmpty) 'amount': p.custom.text.trim(),
      },
  ];

  Map<String, dynamic> get _plan => splits.splitExpense(_total, _planInput);

  double _shareFor(String name) {
    final plan = _plan;
    if (plan['ok'] != true) return 0;
    for (final s in plan['shares'] as List) {
      if (s['name'] == name) return (s['share'] as num).toDouble();
    }
    return 0;
  }

  String? _errorText(Map<String, dynamic> plan) {
    if (plan['ok'] == true) return null;
    switch (plan['error']) {
      case 'over':
        return 'The exact amounts add up to more than the bill. Lower one.';
      case 'mismatch':
        final gap = (plan['gap'] as num?)?.toDouble() ?? 0;
        return 'The exact amounts are short by ${formatMoneyText(gap)}. '
            'Add someone to split the rest, or adjust an amount.';
      case 'empty':
        return 'Add at least one person to split with.';
      default:
        return 'This split does not add up yet.';
    }
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final plan = _plan;
    if (plan['ok'] != true) return;
    if ((plan['collectFrom'] as int) == 0) {
      setState(() {}); // nothing to collect; the button is already disabled
      return;
    }
    if (!widget.store.canWrite) return;
    _saving = true;
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final toCollect = (plan['toCollect'] as num).toDouble();
    try {
      final created = await widget.store.splitExpense(
        txnId: (widget.txn['id'] ?? '').toString(),
        participants: _planInput,
        activityLabel: _activity.text,
      );
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            created > 0
                ? 'Split done. ${formatMoneyText(toCollect)} coming back from '
                      '$created ${created == 1 ? 'person' : 'people'}.'
                : 'Nothing to split.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      _saving = false;
      if (mounted) setState(() {});
      messenger.showSnackBar(
        SnackBar(content: Text('Could not split, nothing changed. $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final plan = _plan;
    final ok = plan['ok'] == true;
    final yourShare = ok ? (plan['yourShare'] as num).toDouble() : 0.0;
    final toCollect = ok ? (plan['toCollect'] as num).toDouble() : 0.0;
    final collectFrom = ok ? (plan['collectFrom'] as int) : 0;
    final err = _errorText(plan);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.of(context).size.height - bottomInset) * 0.92,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Split this bill',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You fronted ${formatMoneyText(_total)}. Pick who shared it '
                'and each person owes you their part.',
                style: TextStyle(
                  color: Barako.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              _label('What was this for?'),
              _input(_activity, hint: 'e.g. Baler trip, Grab, dinner'),
              _label('Sino kasama?'),
              for (final p in _people) _personRow(p),
              const SizedBox(height: 10),
              _addRow(),
              const SizedBox(height: 18),
              _summary(yourShare, toCollect, collectFrom, ok),
              if (err != null) ...[
                const SizedBox(height: 12),
                Text(
                  err,
                  style: TextStyle(color: Barako.warningStrong, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Barako.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: (!ok || collectFrom == 0 || _saving)
                        ? null
                        : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      disabledBackgroundColor: Barako.primary.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                    ),
                    child: Text(
                      collectFrom == 0
                          ? 'Add someone'
                          : 'Create ${formatMoneyText(toCollect)} utang',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personRow(_Participant p) {
    final share = _shareFor(p.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _includeBox(p),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.isYou ? 'You' : p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: p.included ? Barako.text : Barako.faint,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: TextField(
              controller: p.custom,
              enabled: p.included,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
              ],
              onChanged: (_) => setState(() {}),
              textAlign: TextAlign.right,
              style: TextStyle(color: Barako.text, fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: p.included ? formatMoneyText(share) : '',
                hintStyle: TextStyle(color: Barako.faint, fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Barako.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Barako.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Barako.primary),
                ),
              ),
            ),
          ),
          if (!p.isYou)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: Barako.faint),
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove ${p.name}',
              onPressed: () => setState(() {
                p.custom.dispose();
                _people.remove(p);
              }),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _includeBox(_Participant p) {
    return Semantics(
      button: true,
      selected: p.included,
      label:
          '${p.isYou ? 'You' : p.name}, ${p.included ? 'included' : 'not in'}',
      child: PressableScale(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => p.included = !p.included);
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: p.included ? Barako.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: p.included ? Barako.primary : Barako.border,
                width: 1.5,
              ),
            ),
            child: p.included
                ? Icon(Icons.check, size: 16, color: Barako.onPrimary)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _addRow() {
    final names = _existingNames;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (names.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final n in names)
                ActionChip(
                  label: Text('+ $n'),
                  onPressed: () => _addPerson(n),
                  backgroundColor: Barako.card,
                  labelStyle: TextStyle(
                    color: Barako.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: Barako.border),
                ),
            ],
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _input(_newName, hint: 'Add a name')),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                _addPerson(_newName.text);
                _newName.clear();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Barako.card,
                foregroundColor: Barako.primaryText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                side: BorderSide(color: Barako.border),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summary(
    double yourShare,
    double toCollect,
    int collectFrom,
    bool ok,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('You fronted', _total, Barako.text),
          const SizedBox(height: 6),
          _summaryRow(
            'Your share (stays your expense)',
            yourShare,
            Barako.textSecondary,
          ),
          const SizedBox(height: 6),
          Divider(color: Barako.border, height: 12),
          const SizedBox(height: 6),
          _summaryRow(
            collectFrom == 0
                ? 'Coming back to you'
                : 'Collect from $collectFrom ${collectFrom == 1 ? 'person' : 'people'}',
            toCollect,
            Barako.primaryText,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    double value,
    Color color, {
    bool bold = false,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: Barako.textSecondary,
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      Text(
        formatMoneyText(value),
        style: TextStyle(
          color: color,
          fontSize: bold ? 16 : 14,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: TextStyle(color: Barako.muted, fontSize: 12)),
  );

  Widget _input(TextEditingController c, {String? hint}) => TextField(
    controller: c,
    style: TextStyle(color: Barako.text, fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Barako.faint),
      filled: true,
      fillColor: Barako.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
