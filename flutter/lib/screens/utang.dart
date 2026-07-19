// The utang ledger: who owes you, aged, and now actionable. Per-person
// groups come from the golden-verified utangAging engine; tapping a person
// opens the action hub the UX critique asked for (log a payment, mark paid,
// undo a fat-fingered payment) built on the golden-verified receivables
// engine. Warning color stays reserved for genuinely overdue money, amounts
// use tabular figures, and every money action confirms or can be reversed,
// never both silent and permanent.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/receivables.dart' as engine;
import '../money/utang.dart';
import '../theme.dart';
import 'log_sheet.dart' show parseAmount;
import 'overview.dart' show formatMoney;

/// The open receivables behind one aging row. utangAging folds rows by the
/// lowercased resolved name (personId row and legacy name row together), so
/// the action hub must gather by the same rule or a person's older utang
/// would silently miss from their own sheet.
List<Map<String, dynamic>> openUtangFor(Map<String, dynamic> data, String name) {
  final key = name.trim().toLowerCase();
  final out = <Map<String, dynamic>>[];
  for (final r in (data['receivables'] as List? ?? [])
      .cast<Map<String, dynamic>>()) {
    if (r['paid'] == true) continue;
    if (engine.remainingOf(r) <= 0) continue;
    if (engine.nameOf(data, r).trim().toLowerCase() == key) out.add(r);
  }
  return out;
}

class UtangScreen extends StatelessWidget {
  final SalapifyStore store;
  const UtangScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final aging = utangAging(store.data, DateTime.now());
    final people = (aging['people'] as List).cast<Map<String, dynamic>>();
    final total = aging['totalOutstanding'] as double;
    final overdueTotal = aging['overdueTotal'] as double;
    final overdueCount = aging['overdueCount'] as int;

    return Scaffold(
      floatingActionButton: store.canWrite
          ? FloatingActionButton.extended(
              onPressed: () => showAddUtangSheet(context, store),
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('New utang',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Text('UTANG',
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3)),
            const SizedBox(height: 4),
            Text('Money owed to you, oldest first',
                style: TextStyle(color: Barako.muted, fontSize: 13)),
            const SizedBox(height: 20),
            if (people.isEmpty)
              Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nobody owes you right now',
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text(
                          'When someone borrows, tap New utang to log it, so '
                          'it never gets awkward later.',
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 14,
                              height: 1.4)),
                    ],
                  ),
                ),
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('STILL OUT',
                          style: TextStyle(
                              color: Barako.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(formatMoney(total),
                            maxLines: 1,
                            style: TextStyle(
                                fontFamily: Barako.displayFont,
                                color: Barako.primary,
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()])),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        overdueCount > 0
                            ? '${formatMoney(overdueTotal)} of it is overdue with $overdueCount ${overdueCount == 1 ? 'person' : 'people'}. Follow up gently, oldest first.'
                            : 'Nothing is overdue yet, so a gentle reminder is enough.',
                        style: TextStyle(
                            color: overdueCount > 0
                                ? Barako.warning
                                : Barako.muted,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < people.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: Barako.border),
                        _PersonRow(
                            person: people[i],
                            onTap: () => showPersonSheet(
                                context, store, people[i]['name'] as String)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 80), // room above the FAB
            ],
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final Map<String, dynamic> person;
  final VoidCallback onTap;
  const _PersonRow({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final days = person['daysOverdue'] as int;
    final count = person['count'] as int;
    final overdue = days > 0;
    final sub = overdue
        ? 'Overdue $days ${days == 1 ? 'day' : 'days'}'
        : (person['oldestDue'] as String).isNotEmpty
            ? 'Due ${person['oldestDue']}'
            : 'No due date';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person['name'] as String,
                      style: TextStyle(
                          color: Barako.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '$sub · $count ${count == 1 ? 'utang' : 'utang entries'}',
                    style: TextStyle(
                        color: overdue ? Barako.warning : Barako.muted,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(formatMoney(person['outstanding'] as double),
                style: TextStyle(
                    color: overdue ? Barako.warning : Barako.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: Barako.faint, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Person action hub: every open utang for one person, with log payment,
// mark paid, and remove payment. Rebuilt live from the store so a logged
// payment updates the sheet in place.
// ---------------------------------------------------------------------------

Future<void> showPersonSheet(
    BuildContext context, SalapifyStore store, String name) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: PersonSheet(store: store, name: name),
    ),
  );
}

class PersonSheet extends StatefulWidget {
  final SalapifyStore store;
  final String name;
  const PersonSheet({super.key, required this.store, required this.name});

  @override
  State<PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<PersonSheet> {
  final payController = TextEditingController();
  String? payingFor; // receivable id the payment field is open for
  String? error;
  bool busy = false;

  @override
  void dispose() {
    payController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) setState(() => busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Nothing was changed. $e';
        });
      }
    }
  }

  Future<void> _logPayment(Map<String, dynamic> r) async {
    final amount = parseAmount(payController.text);
    if (amount == null) {
      setState(() =>
          error = 'Enter a plain amount above zero, like 250 or 99.50.');
      return;
    }
    final text = payController.text;
    await _run(() async {
      await widget.store
          .collectUtangPayment((r['id'] ?? '').toString(), text);
      // The sheet may have been dismissed while the save was in flight; the
      // payment is already persisted, so only touch the controller if the
      // widget is still alive.
      if (mounted) {
        payController.clear();
        payingFor = null;
      }
    });
  }

  Future<void> _markPaid(Map<String, dynamic> r) async {
    final remaining = engine.remainingOf(r);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Mark as paid?',
            style: TextStyle(color: Barako.text)),
        content: Text(
          'Log ${formatMoney(remaining)} from ${widget.name} as received and close this utang?',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child:
                  Text('Cancel', style: TextStyle(color: Barako.muted))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Mark paid',
                  style: TextStyle(color: Barako.primary))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => widget.store.markUtangPaid((r['id'] ?? '').toString()));
  }

  Future<void> _removePayment(
      Map<String, dynamic> r, Map<String, dynamic> p) async {
    final linked = p['txnId'] is String && (p['txnId'] as String).isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Remove payment?',
            style: TextStyle(color: Barako.text)),
        content: Text(
          linked
              ? 'Remove this ${formatMoney((p['amount'] as num).toDouble())} payment? Its money entry will be reversed too.'
              : 'Remove this ${formatMoney((p['amount'] as num).toDouble())} payment? It was logged before payment tracking, so no money entry is linked to reverse.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child:
                  Text('Cancel', style: TextStyle(color: Barako.muted))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Remove',
                  style: TextStyle(color: Barako.warning))),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => widget.store.removeUtangPayment(
        (r['id'] ?? '').toString(), (p['id'] ?? '').toString()));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final items = openUtangFor(widget.store.data, widget.name);
        final total =
            items.fold(0.0, (t, r) => t + engine.remainingOf(r));
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Barako.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(widget.name,
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                Text(
                    items.isEmpty
                        ? 'All settled. Salamat, ${widget.name}!'
                        : '${formatMoney(total)} still out',
                    style: TextStyle(
                        color:
                            items.isEmpty ? Barako.primaryText : Barako.muted,
                        fontSize: 13)),
                const SizedBox(height: 12),
                for (final r in items) _utangCard(r),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style: TextStyle(
                          color: Barako.warning, fontSize: 13)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _utangCard(Map<String, dynamic> r) {
    final remaining = engine.remainingOf(r);
    final amount = (r['amount'] is num) ? (r['amount'] as num).toDouble() : 0.0;
    final paidPart = engine.paidSumOf(r);
    final due = (r['dueDate'] ?? '').toString();
    final note = (r['note'] ?? '').toString();
    final payments =
        (r['payments'] as List? ?? []).cast<Map<String, dynamic>>();
    final rId = (r['id'] ?? '').toString();
    final open = payingFor == rId;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    paidPart > 0
                        ? '${formatMoney(remaining)} left of ${formatMoney(amount)}'
                        : formatMoney(remaining),
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                ),
                Text(due.isNotEmpty ? 'due $due' : 'no due date',
                    style:
                        TextStyle(color: Barako.muted, fontSize: 12)),
              ],
            ),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(note,
                    style: TextStyle(color: Barako.faint, fontSize: 12)),
              ),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final p in payments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Barako.muted, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${formatMoney((p['amount'] as num?)?.toDouble() ?? 0)} on ${(p['date'] ?? '').toString()}',
                          style: TextStyle(
                              color: Barako.textSecondary, fontSize: 12),
                        ),
                      ),
                      InkWell(
                        onTap: busy ? null : () => _removePayment(r, p),
                        customBorder: const CircleBorder(),
                        // A real 44dp tap target around the small icon.
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.close,
                              color: Barako.faint, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            if (open) ...[
              TextField(
                controller: payController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'How much came back?',
                  hintStyle:
                      TextStyle(color: Barako.faint, fontSize: 14),
                  prefixText: '₱ ',
                  prefixStyle: TextStyle(
                      color: Barako.muted,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                  filled: true,
                  fillColor: Barako.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Barako.border),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Barako.primary,
                          foregroundColor: Barako.onPrimary),
                      onPressed: busy ? null : () => _logPayment(r),
                      child: Text(busy ? 'Saving...' : 'Save payment',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              payingFor = null;
                              payController.clear();
                            }),
                    child: Text('Cancel',
                        style: TextStyle(color: Barako.muted)),
                  ),
                ],
              ),
            ] else
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Barako.border),
                        foregroundColor: Barako.text),
                    onPressed: busy
                        ? null
                        : () => setState(() {
                              payingFor = rId;
                              payController.clear();
                              error = null;
                            }),
                    child: const Text('Log payment'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Barako.border),
                        foregroundColor: Barako.primary),
                    onPressed: busy ? null : () => _markPaid(r),
                    child: const Text('Mark paid'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// New utang sheet: person (with chips for existing people), amount, optional
// due date, optional source account for the lending cash leg.
// ---------------------------------------------------------------------------

Future<void> showAddUtangSheet(BuildContext context, SalapifyStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: AddUtangSheet(store: store),
    ),
  );
}

class AddUtangSheet extends StatefulWidget {
  final SalapifyStore store;
  const AddUtangSheet({super.key, required this.store});

  @override
  State<AddUtangSheet> createState() => _AddUtangSheetState();
}

class _AddUtangSheetState extends State<AddUtangSheet> {
  final personController = TextEditingController();
  final amountController = TextEditingController();
  final dueController = TextEditingController();
  final noteController = TextEditingController();
  String fromAccount = '';
  String? error;
  bool saving = false;

  @override
  void dispose() {
    personController.dispose();
    amountController.dispose();
    dueController.dispose();
    noteController.dispose();
    super.dispose();
  }

  String _plusDays(int days) {
    final d = DateTime.now().add(Duration(days: days));
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    if (saving) return;
    // The same strict parse as every other money field: a bare comma decimal
    // like 2,50 is rejected with guidance, never silently read as 250 (which
    // would move 250 real pesos out of the source account).
    final amount = parseAmount(amountController.text);
    if (amount == null) {
      setState(() => error = amountController.text.contains(',')
          ? 'Use a period for centavos, like 2.50. Commas only group thousands.'
          : 'Enter a plain amount above zero, like 250 or 99.50.');
      return;
    }
    setState(() {
      error = null;
      saving = true;
    });
    try {
      await widget.store.addUtang(
        person: personController.text,
        amountText: amount.toString(),
        dueDate: dueController.text,
        note: noteController.text,
        fromAccount: fromAccount,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          saving = false;
          error = e is ArgumentError
              ? e.message.toString()
              : 'Could not save, so nothing was changed. $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = (widget.store.data['people'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((p) => p['name'] is String && (p['name'] as String).isNotEmpty)
        .toList();
    final accounts = (widget.store.data['accounts'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((a) => a['id'] is String && (a['id'] as String).isNotEmpty)
        .toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Barako.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('NEW UTANG',
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2)),
            const SizedBox(height: 12),
            TextField(
              controller: personController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: TextStyle(color: Barako.text, fontSize: 16),
              decoration: _decor('Who borrowed? e.g. Juan'),
              onChanged: (_) => setState(() {}),
            ),
            if (people.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in people)
                    ActionChip(
                      label: Text(p['name'] as String),
                      backgroundColor: Barako.card,
                      labelStyle: TextStyle(
                          color: Barako.textSecondary,
                          fontWeight: FontWeight.w600),
                      side: BorderSide(color: Barako.border),
                      onPressed: () => setState(() =>
                          personController.text = p['name'] as String),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  color: Barako.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700),
              decoration: _decor('0.00', prefix: '₱ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dueController,
              keyboardType: TextInputType.datetime,
              style: TextStyle(color: Barako.text, fontSize: 16),
              decoration: _decor('Due date, like 2026-08-01 (optional)'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (label, days) in [
                  ('In 1 week', 7),
                  ('In 2 weeks', 14),
                  ('In 30 days', 30),
                ])
                  ActionChip(
                    label: Text(label),
                    backgroundColor: Barako.card,
                    labelStyle: TextStyle(
                        color: Barako.textSecondary,
                        fontWeight: FontWeight.w600),
                    side: BorderSide(color: Barako.border),
                    onPressed: () => setState(
                        () => dueController.text = _plusDays(days)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              style: TextStyle(color: Barako.text, fontSize: 16),
              decoration: _decor('Note, like "sa jeep" (optional)'),
            ),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('WHERE DID THE MONEY LEAVE FROM?',
                  style: TextStyle(
                      color: Barako.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(
                  'Pick an account and the lent amount moves out of it now, '
                  'then comes back when they pay. Skip it to just track the utang.',
                  style: TextStyle(color: Barako.faint, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _accountChip('Just track it', ''),
                  for (final a in accounts)
                    _accountChip(
                        a['name']?.toString() ?? 'Account', a['id'] as String),
                ],
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style:
                      TextStyle(color: Barako.warning, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: saving ? null : _save,
                child: Text(saving ? 'Saving...' : 'Save utang',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decor(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Barako.faint),
        prefixText: prefix,
        prefixStyle: TextStyle(
            color: Barako.muted, fontSize: 24, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Barako.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Barako.border),
        ),
      );

  Widget _accountChip(String label, String id) {
    final on = fromAccount == id;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => fromAccount = id),
      selectedColor: Barako.primary,
      backgroundColor: Barako.card,
      labelStyle: TextStyle(
          color: on ? Barako.onPrimary : Barako.textSecondary,
          fontWeight: FontWeight.w600),
      side: BorderSide(color: Barako.border),
    );
  }
}
