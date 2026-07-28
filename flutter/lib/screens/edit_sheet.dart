// Fix a typo without deleting the entry. The RN app has had this from the
// start; Flutter was swipe-to-delete only, so a wrong amount meant delete
// and re-log, and a non-deletable row meant living with the mistake.
//
// The edit goes through the golden-tested ledger engine's reverse-then-apply
// (the same semantics the RN updateTransaction uses), exposed as
// store.updateEntry, so a changed amount, type, or account can never drift a
// balance. Rows the delete gate refuses (records of money moves, utang
// linked legs) get a read-only explainer instead, one step STRICTER than RN,
// which let legacy utang legs through by accident and called it a hole.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import 'log_sheet.dart' show parseAmount;
import 'overview.dart' show formatMoney, prettyDay;
import 'split_expense.dart' show showSplitSheet;
import '../money/currencies.dart' show baseCurrencySymbol;

/// Opens the right sheet for a history row: the edit form when the row is
/// editable, otherwise the read-only explainer that says why not and where
/// to manage it.
Future<void> showEntrySheet(
  BuildContext context,
  SalapifyStore store,
  Map<String, dynamic> t, {
  required bool editable,
  required bool splittable,
  bool utangLinked = false,
}) {
  if (editable) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Barako.card,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: EditSheet(store: store, tx: t, splittable: splittable),
      ),
    );
  }
  return _showRecordSheet(context, t, utangLinked: utangLinked);
}

/// The RN read-only modal, adapted: what this row is, why it cannot be
/// edited, and what deleting it would or would not do.
Future<void> _showRecordSheet(
  BuildContext context,
  Map<String, dynamic> t, {
  required bool utangLinked,
}) {
  final type = (t['type'] ?? '').toString();
  final source = (t['source'] ?? '').toString();
  final String note;
  if (type == 'adjustment') {
    note =
        'This row records a balance adjustment you made to an account. It '
        'cannot be edited, but deleting it with a swipe undoes the change '
        'and moves the balance back.';
  } else if (type == 'transfer' || type == 'debt') {
    final what = type == 'transfer'
        ? 'a transfer between accounts'
        : 'a debt payment';
    // Says "or deleted" out loud, unlike the first version. Swiping one of
    // these does nothing at all (History only offers the swipe on income and
    // expense rows), and a person swiping into silence assumes the app is
    // broken rather than that they are being protected.
    note =
        'This row is a record of $what, written the moment it happened. The '
        'balances already moved then, so the record cannot be edited or '
        'deleted. To undo it, make the opposite move.';
  } else if (utangLinked || source == 'receivable' || source == 'payable') {
    note =
        'This entry is part of an utang. To change or undo it, open the '
        'Utang tab and edit that utang there, so the balance and the utang '
        'stay in sync.';
  } else if (source == 'interest') {
    // QA caught this bucket reading the utang copy: a debt interest row sent
    // the user to a tab with nothing relevant on it. Say what it really is.
    note =
        'This row records interest your debt added for the month, written '
        'by the debt engine. It cannot be edited; the debt it belongs to '
        'lives on the Utang tab, under I owe.';
  } else if (source == 'import') {
    note =
        'This row came in through a CSV import and is kept as a faithful '
        'copy of the imported file, so it cannot be edited here.';
  } else {
    // A row with no usable id, or a source this app does not know. Honest
    // and generic beats confidently wrong.
    note = 'This row cannot be edited here.';
  }
  final label = (t['label'] ?? '').toString().isEmpty
      ? type
      : (t['label']).toString();
  final amount = t['amount'] is num ? (t['amount'] as num).toDouble() : 0.0;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Barako.card,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Barako.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatMoney(amount)} on ${prettyDay((t['date'] ?? '').toString())}',
              style: TextStyle(color: Barako.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              note,
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class EditSheet extends StatefulWidget {
  final SalapifyStore store;
  final Map<String, dynamic> tx;
  final bool splittable;

  // ignore: prefer_const_constructors_in_immutables
  EditSheet({
    super.key,
    required this.store,
    required this.tx,
    required this.splittable,
  });

  @override
  State<EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<EditSheet> {
  late final amountController = TextEditingController(
    text: _plainAmount(widget.tx['amount']),
  );
  late final labelController = TextEditingController(
    text: (widget.tx['label'] ?? '').toString(),
  );
  late String type = widget.tx['type'] == 'income' ? 'income' : 'expense';
  late DateTime day =
      DateTime.tryParse((widget.tx['date'] ?? '').toString()) ?? DateTime.now();

  /// Seeded like RN: a pointer at a deleted account reads as unlinked, so
  /// the chips always show a true selection.
  late String? accountId = _validAccountId(widget.tx['accountId']);
  String? error;
  bool saving = false;

  String? _validAccountId(dynamic id) {
    if (id is! String || id.isEmpty) return null;
    final ok = (widget.store.data['accounts'] as List? ?? const []).any(
      (a) => a is Map && a['id'] == id,
    );
    return ok ? id : null;
  }

  static String _plainAmount(dynamic v) {
    if (v is! num) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  String get _iso => day.toIso8601String().substring(0, 10);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void dispose() {
    amountController.dispose();
    labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => error = null);
    final amount = parseAmount(amountController.text);
    if (amount == null) {
      setState(
        () => error = amountController.text.contains(',')
            ? 'Use a period for centavos, like 2.50. Commas only group thousands.'
            : 'Enter a plain amount above zero, like 250 or 99.50.',
      );
      return;
    }
    setState(() => saving = true);
    final label = labelController.text.trim();
    final shownLabel = label.isEmpty
        ? (type == 'income' ? 'Income' : 'Expense')
        : label;
    // The category follows the label, RN semantics: a label matching a
    // category name adopts it, anything else drops the stale pointer.
    String? categoryId;
    for (final c in (widget.store.data['categories'] as List? ?? const [])) {
      if (c is Map && c['name'] == shownLabel) {
        categoryId = (c['id'] ?? '').toString();
        break;
      }
    }
    final amountChanged = widget.tx['amount'] != amount;
    final patch = <String, dynamic>{
      'type': type,
      'label': shownLabel,
      'amount': amount,
      'date': _iso,
      // null means "remove the key" to updateEntry; unlinking really unlinks.
      'accountId': accountId,
      'categoryId': (categoryId != null && categoryId.isNotEmpty)
          ? categoryId
          : null,
      // A hand-converted original currency pair stops being true the moment
      // the peso amount changes or the row stops being an expense. RN drops
      // it under the same conditions.
      if (amountChanged || type != 'expense') ...{
        'origCurrency': null,
        'origAmount': null,
      },
    };
    final id = (widget.tx['id'] ?? '').toString();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final before = await widget.store.updateEntry(id, patch);
      if (mounted) Navigator.of(context).pop();
      if (before == null) {
        // The row vanished between opening the sheet and saving. A sheet
        // that just closes reads as success, and QA called that quiet, not
        // honest.
        messenger.showSnackBar(
          const SnackBar(
            content: Text('That entry no longer exists, nothing was changed.'),
          ),
        );
        return;
      }
      // The reverse patch restores exactly the keys the edit touched, with
      // null marking the ones the original never had.
      final revert = <String, dynamic>{
        for (final k in patch.keys) k: before.containsKey(k) ? before[k] : null,
      };
      messenger.showSnackBar(
        SnackBar(
          content: Text('$shownLabel updated.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                // null means the row is gone (deleted while the receipt was
                // up). Saying nothing there let the user believe the
                // original was back when the edited version stood.
                final undone = await widget.store.updateEntry(id, revert);
                if (undone == null) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Could not undo, the entry no longer exists.',
                      ),
                    ),
                  );
                }
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not undo, the edit is still applied. $e',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = 'Could not save, so nothing was changed. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = (widget.store.data['accounts'] as List? ?? const [])
        .whereType<Map>()
        .map((a) => a.cast<String, dynamic>())
        .where((a) => a['id'] is String && (a['id'] as String).isNotEmpty)
        .toList();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EDIT ENTRY', style: Barako.cardKickerStyle),
            const SizedBox(height: 12),
            Row(
              children: [
                _choice(
                  'Expense',
                  type == 'expense',
                  () => setState(() => type = 'expense'),
                ),
                const SizedBox(width: 8),
                _choice(
                  'Income',
                  type == 'income',
                  () => setState(() => type = 'income'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: Barako.text,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              decoration: _decor('0.00', prefix: '$baseCurrencySymbol '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelController,
              style: TextStyle(color: Barako.text, fontSize: 16),
              decoration: _decor(
                type == 'income' ? 'e.g. Salary' : 'e.g. Groceries',
              ),
            ),
            const SizedBox(height: 14),
            Text('WHEN', style: Barako.cardKickerStyle),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _dayChips()),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('LINKED ACCOUNT', style: Barako.cardKickerStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _choice(
                    'Not linked',
                    accountId == null,
                    () => setState(() => accountId = null),
                  ),
                  for (final a in accounts)
                    _choice(
                      a['name']?.toString() ?? 'Account',
                      accountId == a['id'],
                      () => setState(() => accountId = a['id'] as String),
                    ),
                ],
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(
                error!,
                style: TextStyle(color: Barako.warning, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: saving ? null : _save,
                child: Text(
                  saving ? 'Saving...' : 'Save changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (widget.splittable)
              Center(
                child: TextButton(
                  onPressed: () {
                    final store = widget.store;
                    final tx = widget.tx;
                    Navigator.of(context).pop();
                    showSplitSheet(context, store, tx);
                  },
                  child: Text(
                    'Split with friends instead',
                    style: TextStyle(
                      color: Barako.primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _dayChips() {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final isToday = _sameDay(day, now);
    final isYesterday = _sameDay(day, yesterday);
    final custom = !isToday && !isYesterday;
    return [
      _choice('Today', isToday, () => setState(() => day = now)),
      _choice('Yesterday', isYesterday, () => setState(() => day = yesterday)),
      _choice(custom ? prettyDay(_iso) : 'Pick a date', custom, () async {
        // BOTH bounds clamped around the row's own date. A restored RN
        // backup can legally carry any date, and showDatePicker asserts
        // initialDate inside [firstDate, lastDate]; the unclamped version
        // crashed on a 2014 entry. Paluwagan learned this first
        // (paluwagan.dart), and QA caught this sheet not copying the clamp.
        final floor = DateTime(2015);
        final picked = await showDatePicker(
          context: context,
          initialDate: day.isAfter(now) ? now : day,
          firstDate: day.isBefore(floor) ? day : floor,
          // No future dates, same rule as logging: this row records money
          // that already moved.
          lastDate: now,
        );
        if (picked != null) setState(() => day = picked);
      }),
    ];
  }

  Widget _choice(String label, bool on, VoidCallback pick) => ChoiceChip(
    label: Text(label),
    selected: on,
    onSelected: (_) => pick(),
    selectedColor: Barako.primary,
    backgroundColor: Barako.background,
    labelStyle: TextStyle(
      color: on ? Barako.onPrimary : Barako.textSecondary,
      fontWeight: FontWeight.w600,
    ),
    side: BorderSide(color: Barako.border),
  );

  InputDecoration _decor(String hint, {String? prefix}) => InputDecoration(
    hintText: hint,
    prefixText: prefix,
    prefixStyle: TextStyle(
      color: Barako.muted,
      fontSize: 24,
      fontWeight: FontWeight.w700,
    ),
    filled: true,
    fillColor: Barako.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: Barako.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: BorderSide(color: Barako.border),
    ),
  );
}
