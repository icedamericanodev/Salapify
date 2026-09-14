// One entry, and the two things you can do to it.
//
// This is the biggest gap the expert reviews found, and both called it a
// pre-launch blocker rather than a roadmap item: until now nothing in the app
// could open, fix or remove a single entry. No row tap, no swipe, no search.
// Every competitor has this, and it matters MORE here than for them, because
// the fast log parser guesses. Fast entry with a wrong guess and no repair path
// accumulates silent garbage, and the only remedy was restoring a backup, for
// which there is also no screen.
//
// It is also the thing Reconcile depends on. Reconcile writes `adjustment` rows
// into the ledger, and shipping it into a ledger nobody can open would give the
// founder an audit trail nobody can read.
//
// NO MONEY IS COMPUTED HERE. `updateTransaction` and `removeTransaction` are
// golden locked and already do the hard part: an edit REVERSES the old entry's
// effect on the account balance and applies the new one's, so no edit can drift
// a balance, and a delete undoes exactly what the entry did. A screen that
// adjusted a balance by hand would be a bug however small the adjustment.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../core/money/ledger.dart'
    show amountOf, removeTransaction, updateTransaction;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'entry_presentation.dart';
import 'ledger_screen.dart' show signedAmount;

class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final entry = findEntry(data, id);

    if (entry == null) {
      // Reachable for real: delete an entry and the route is still on the
      // stack behind the pop, and a deep link can name a row that is gone.
      return const _Page(
        children: [
          BackBar(),
          SizedBox(height: 20),
          EmptyState(
            icon: Icons.help_outline_rounded,
            title: 'Entry not found',
            body: 'It may have been deleted since this link was made.',
          ),
        ],
      );
    }

    final skin = context.skin;
    final signed = signedAmount(entry);

    return _Page(
      children: [
        const BackBar(),
        const SizedBox(height: 6),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (entry['label'] ?? '').toString(),
                style: TypeScale.screenTitle(skin.text),
              ),
              const SizedBox(height: 2),
              Text(
                entrySubtitle(data, entry) ?? _typeWord(entry),
                style: TypeScale.quiet(skin.text3),
              ),
              const SizedBox(height: 14),
              Text(
                formatMoney(signed),
                style: TypeScale.hero(signed > 0 ? skin.good : skin.text),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Head(title: 'Details'),
        const SizedBox(height: 8),
        Group(
          children: [
            ItemRow(
              icon: entryIcon(entry),
              title: 'Type',
              amount: _typeWord(entry),
            ),
            ItemRow(
              icon: Icons.event_outlined,
              title: 'Date',
              amount: prettyDay((entry['date'] ?? '').toString()),
            ),
            ItemRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Account',
              amount: _nameIn(data, 'accounts', entry['accountId']) ?? 'None',
            ),
            if (entry['type'] == 'expense')
              ItemRow(
                icon: Icons.sell_outlined,
                title: 'Category',
                amount:
                    _nameIn(data, 'categories', entry['categoryId']) ?? 'None',
              ),
          ],
        ),
        const SizedBox(height: 20),
        PillButton(
          label: 'Edit this entry',
          icon: Icons.edit_outlined,
          onTap: () => _edit(context, entry),
        ),
        const SizedBox(height: 10),
        _DeleteAction(entry: entry),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    Map<String, dynamic> entry,
  ) async {
    final store = context.ledger;
    final patch = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LedgerScope(store: store, child: _EditSheet(entry: entry)),
    );
    if (patch == null) return;
    // The golden locked edit: it reverses the old entry's effect on the
    // balance and applies the new one's. No balance is touched here.
    await store.apply((s) => updateTransaction(s, entry['id'] as String, patch));
  }
}

/// [Screen] plus the Scaffold a pushed route has to bring with it.
///
/// The shell gives every TAB screen its Scaffold, so none of them carries one,
/// and a route pushed OVER the shell has no such parent. Account detail shipped
/// once without this and every line of text came out with a yellow double
/// underline, which is what Flutter draws for text with no Material ancestor.
class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.skin.bg,
    body: Screen(children: children),
  );
}

/// Delete, behind a confirmation, because it cannot be undone.
///
/// A confirmation rather than an undo snackbar on purpose: the store persists
/// before it notifies, so by the time a snackbar is on screen the write has
/// already landed, and an undo would be a second write racing the first. Asking
/// first is the honest version.
class _DeleteAction extends StatelessWidget {
  const _DeleteAction({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _confirm(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            'Delete this entry',
            textAlign: TextAlign.center,
            style: TypeScale.button(skin.bad),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final store = context.ledger;
    final skin = context.skin;
    final label = (entry['label'] ?? 'this entry').toString();
    final amount = formatMoney(amountOf(entry['amount']));

    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: skin.card,
        title: Text('Delete $label?', style: TypeScale.sheetTitle(skin.text)),
        // Names the amount AND what it will do to the balance, because
        // "are you sure" on its own asks somebody to confirm something they
        // cannot see.
        content: Text(
          '$amount will be removed, and the account balance it moved goes '
          'back to what it was. This cannot be undone.',
          style: TypeScale.subtitle(skin.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text('Keep it', style: TypeScale.button(skin.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text('Delete', style: TypeScale.button(skin.bad)),
          ),
        ],
      ),
    );

    if (yes != true) return;
    await store.apply((s) => removeTransaction(s, entry['id'] as String));
    if (context.mounted) context.pop();
  }
}

/// Edit amount, label, category and account. Nothing else, on purpose.
///
/// Type and date are deliberately not editable yet: changing a type changes
/// what the entry MEANS to every total that reads it, and changing a date moves
/// it between cycles. Both are real features and both deserve their own
/// thinking rather than being smuggled in beside a typo fix.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.entry});
  final Map<String, dynamic> entry;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _label = TextEditingController(
    text: (widget.entry['label'] ?? '').toString(),
  );
  late final TextEditingController _amount = TextEditingController(
    text: amountOf(widget.entry['amount']).toStringAsFixed(2),
  );
  late String? _categoryId = widget.entry['categoryId'] as String?;
  late String? _accountId = widget.entry['accountId'] as String?;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _rows(String collection) => [
    for (final c in (context.ledger.data[collection] as List? ?? const []))
      if (c is Map) c.cast<String, dynamic>(),
  ];

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isExpense = widget.entry['type'] == 'expense';

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit entry', style: TypeScale.sheetTitle(skin.text)),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text('Cancel', style: TypeScale.action(skin.text2)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('What', style: TypeScale.fieldLabel(skin.text3)),
            const SizedBox(height: 8),
            TextField(
              controller: _label,
              style: TypeScale.input(skin.text),
              decoration: _box(skin),
            ),
            const SizedBox(height: 16),
            Text('How much', style: TypeScale.fieldLabel(skin.text3)),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TypeScale.input(skin.text),
              decoration: _box(skin),
            ),
            if (isExpense) ...[
              const SizedBox(height: 18),
              Text('Category', style: TypeScale.fieldLabel(skin.text3)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _rows('categories'))
                    PickChip(
                      label: (c['name'] ?? '').toString(),
                      on: c['id'] == _categoryId,
                      onTap: () => setState(
                        () => _categoryId = c['id'] == _categoryId
                            ? null
                            : c['id'] as String?,
                      ),
                    ),
                ],
              ),
            ],
            if (_rows('accounts').isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Account', style: TypeScale.fieldLabel(skin.text3)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in _rows('accounts'))
                    PickChip(
                      label: (a['name'] ?? '').toString(),
                      on: a['id'] == _accountId,
                      onTap: () => setState(
                        () => _accountId = a['id'] == _accountId
                            ? null
                            : a['id'] as String?,
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            PillButton(label: 'Save changes', onTap: _save),
          ],
        ),
      ),
    );
  }

  InputDecoration _box(Skin skin) => InputDecoration(
    filled: true,
    fillColor: skin.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  void _save() {
    final typed = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    // A blank or unparseable amount leaves the amount ALONE rather than
    // writing a zero. A zero is a real figure and "I could not read this" is
    // not the same statement.
    Navigator.of(context).pop(<String, dynamic>{
      'label': _label.text.trim(),
      if (typed != null && typed > 0) 'amount': typed,
      'categoryId': _categoryId,
      'accountId': _accountId,
    });
  }
}

String _typeWord(Map<String, dynamic> t) => switch (t['type']) {
  'income' => 'Income',
  'transfer' => 'Transfer',
  'debt' => 'Debt',
  'adjustment' => 'Adjustment',
  _ => 'Expense',
};

String? _nameIn(Map<String, dynamic> data, String collection, dynamic id) {
  if (id is! String || id.isEmpty) return null;
  for (final row in (data[collection] as List? ?? const [])) {
    if (row is Map && row['id'] == id) return (row['name'] ?? '').toString();
  }
  return null;
}

/// One entry by id, or null when it is gone.
Map<String, dynamic>? findEntry(Map<String, dynamic> state, String id) {
  for (final t in (state['transactions'] is List
      ? state['transactions'] as List
      : const [])) {
    if (t is Map && t['id'] == id) return t.cast<String, dynamic>();
  }
  return null;
}
