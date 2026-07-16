// The log sheet: the first WRITE path of the Flutter rebuild. A bottom sheet
// with the expense or income choice, amount, label, and an optional account
// to take the money from (or add it to). Saving goes through
// SalapifyStore.addEntry, which runs the golden-verified transaction engine,
// so a logged entry moves balances exactly like the RN app would.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';

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

  @override
  void dispose() {
    amountController.dispose();
    labelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      setState(() => error = 'Enter an amount above zero.');
      return;
    }
    final label = labelController.text.trim();
    final now = DateTime.now();
    final tx = <String, dynamic>{
      'id': 't${now.millisecondsSinceEpoch}',
      'type': type,
      'label': label.isEmpty ? (type == 'income' ? 'Income' : 'Expense') : label,
      'amount': amount,
      'date': now.toIso8601String().substring(0, 10),
      if (accountId != null) 'accountId': accountId,
    };
    await widget.store.addEntry(tx);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        (widget.store.data['accounts'] as List).cast<Map<String, dynamic>>();

    return Padding(
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                color: Barako.text, fontSize: 28, fontWeight: FontWeight.w700),
            decoration: _decor('0.00', prefix: '₱ '),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: labelController,
            style: const TextStyle(color: Barako.text, fontSize: 16),
            decoration:
                _decor(type == 'income' ? 'e.g. Sweldo' : 'e.g. Groceries'),
          ),
          if (accounts.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('FROM WHICH ACCOUNT',
                style: const TextStyle(
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
                      a['name'] as String? ?? 'Account', a['id'] as String?),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!,
                style: const TextStyle(color: Barako.warning, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _save,
              child: const Text('Save entry',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decor(String hint, {String? prefix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Barako.faint),
        prefixText: prefix,
        prefixStyle: const TextStyle(
            color: Barako.muted, fontSize: 28, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Barako.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Barako.border),
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
      side: const BorderSide(color: Barako.border),
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
      side: const BorderSide(color: Barako.border),
    );
  }
}
