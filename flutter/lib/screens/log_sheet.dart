// The log sheet: the first WRITE path of the Flutter rebuild. A bottom sheet
// with the expense or income choice, amount, label, and an optional account
// to take the money from (or add it to). Saving goes through
// SalapifyStore.addEntry, which runs the golden-verified transaction engine,
// so a logged entry moves balances exactly like the RN app would. Every QA
// finding on this path is guarded here: a busy flag stops double saves, ids
// carry a random suffix so two quick saves can never collide, the amount is
// parsed strictly (finite, plain decimal, commas only as thousands), and a
// failed save shows a message instead of freezing the sheet.

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';

final Random _rand = Random();

/// Unique entry id: timestamp plus 48 random bits, so two saves that land in
/// the same millisecond still get distinct ids (a duplicated id would let one
/// delete remove both copies but reverse only one balance move). Two draws
/// keep the collision odds far below anything a test suite could flake on.
String newEntryId(DateTime now) => 't${now.millisecondsSinceEpoch}'
    '${_rand.nextInt(0x1000000).toRadixString(36)}'
    '${_rand.nextInt(0x1000000).toRadixString(36)}';

/// Parse the amount field strictly. Commas are accepted only as thousands
/// separators (1,250 or 12,345.60). A bare comma decimal (2,50) is rejected
/// with guidance instead of silently becoming 250. Returns null when the
/// text is not a plain positive finite number.
double? parseAmount(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;
  final thousands = RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$');
  if (thousands.hasMatch(text)) text = text.replaceAll(',', '');
  // Plain decimals only; a bare ".50" for fifty centavos is fine too.
  if (!RegExp(r'^(\d+(\.\d+)?|\.\d+)$').hasMatch(text)) return null;
  final parsed = double.tryParse(text);
  if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
  return parsed;
}

Future<void> showLogSheet(BuildContext context, SalapifyStore store) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      // Lift the sheet above the keyboard.
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: LogSheet(store: store),
    ),
  );
}

class LogSheet extends StatefulWidget {
  final SalapifyStore store;
  const LogSheet({super.key, required this.store});

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  final amountController = TextEditingController();
  final labelController = TextEditingController();
  String type = 'expense';
  String? accountId;
  String? error;
  bool saving = false;

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
      setState(() => error = amountController.text.contains(',')
          ? 'Use a period for centavos, like 2.50. Commas only group thousands.'
          : 'Enter a plain amount above zero, like 250 or 99.50.');
      return;
    }
    setState(() => saving = true);
    final label = labelController.text.trim();
    final now = DateTime.now();
    final tx = <String, dynamic>{
      'id': newEntryId(now),
      'type': type,
      'label': label.isEmpty ? (type == 'income' ? 'Income' : 'Expense') : label,
      'amount': amount,
      'date': now.toIso8601String().substring(0, 10),
      if (accountId != null) 'accountId': accountId,
    };
    try {
      await widget.store.addEntry(tx);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // The store rolled the entry back, so nothing was half-applied. Say so.
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
    // Only accounts with a real string id can be linked (the engine ignores
    // anything else), and only those get chips, so an odd id from an imported
    // backup can never crash the sheet.
    final accounts = (widget.store.data['accounts'] as List)
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
            Row(
              children: [
                _typeChip('Expense', 'expense'),
                const SizedBox(width: 8),
                _typeChip('Income', 'income'),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  color: Barako.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700),
              decoration: _decor('0.00', prefix: '₱ '),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelController,
              style: TextStyle(color: Barako.text, fontSize: 16),
              decoration:
                  _decor(type == 'income' ? 'e.g. Sweldo' : 'e.g. Groceries'),
            ),
            if (accounts.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('FROM WHICH ACCOUNT',
                  style: TextStyle(
                      color: Barako.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _accountChip('No account', null),
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
                child: Text(saving ? 'Saving...' : 'Save entry',
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
            color: Barako.muted, fontSize: 28, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Barako.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Barako.border),
        ),
      );

  Widget _typeChip(String label, String value) {
    final on = type == value;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => type = value),
      selectedColor: Barako.primary,
      backgroundColor: Barako.card,
      labelStyle: TextStyle(
          color: on ? Barako.onPrimary : Barako.textSecondary,
          fontWeight: FontWeight.w600),
      side: BorderSide(color: Barako.border),
    );
  }

  Widget _accountChip(String label, String? id) {
    final on = accountId == id;
    return ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => setState(() => accountId = id),
      selectedColor: Barako.primary,
      backgroundColor: Barako.card,
      labelStyle: TextStyle(
          color: on ? Barako.onPrimary : Barako.textSecondary,
          fontWeight: FontWeight.w600),
      side: BorderSide(color: Barako.border),
    );
  }
}
