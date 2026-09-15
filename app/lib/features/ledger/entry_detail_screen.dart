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
import '../categories/category_rows.dart' show pickableCategories;
import '../../core/money/format.dart';
import '../../core/money/ledger.dart'
    show amountOf, removeTransaction, updateTransaction;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'entry_presentation.dart';

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
    // TONE still comes from the sign; the TEXT does not. `entryAmountText` is
    // the one place Home and the Ledger draw an entry's figure from, and this
    // screen was left behind when it was introduced: a transfer read -5,000
    // here and 5,000 on the two screens you reach it from. A move is not a
    // loss, and three screens describing one row three ways is the drift that
    // shared function exists to prevent.
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
                entryAmountText(entry),
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

  Future<void> _edit(BuildContext context, Map<String, dynamic> entry) async {
    final store = context.ledger;
    final patch = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      // This screen is already pushed over the shell, so the nearest Navigator
      // IS the root one and this changes nothing today. It is here so that
      // moving the screen inside a tab later cannot quietly park the save
      // button behind the nav bar (see account_editor.dart).
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LedgerScope(
        store: store,
        child: _EditSheet(entry: entry),
      ),
    );
    if (patch == null) return;
    // The golden locked edit: it reverses the old entry's effect on the
    // balance and applies the new one's. No balance is touched here.
    await store.apply(
      (s) => updateTransaction(s, entry['id'] as String, patch),
    );
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
        //
        // AND IT TELLS THE TRUTH FOR A MOVE, which the single sentence here
        // did not. `removeTransaction` undoes a row through its accountId,
        // and a transfer deliberately has none (the engine moved both
        // balances itself), so deleting one leaves every peso where it is
        // and takes away the only row explaining the movement. The old
        // wording promised the exact opposite: "the account balance it moved
        // goes back to what it was". Somebody keeping books would have read
        // that, tapped it, and been left with two balances they could no
        // longer account for.
        content: Text(
          entry['type'] == 'transfer'
              ? '$amount already moved between the two accounts, and '
                    'deleting this does NOT move it back. The balances stay '
                    'exactly as they are and you lose the only record of why '
                    'they changed. Move it back yourself if that is what you '
                    'want. This cannot be undone.'
              : '$amount will be removed, and the account balance it moved '
                    'goes back to what it was. This cannot be undone.',
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

  /// The category chips: what you can still pick, PLUS this entry's own.
  ///
  /// The second half is the whole point. Filtering to pickable alone would
  /// make an entry tagged with a since-retired category show no chip selected,
  /// so opening the sheet to fix a typo in the amount and saving would quietly
  /// strip a tag the person never touched. Retiring a label is not permission
  /// to rewrite the history filed under it.
  List<Map<String, dynamic>> _pickableCategoriesKeepingMine() {
    final pickable = pickableCategories(context.ledger.data);
    final mine = _categoryId;
    if (mine == null || pickable.any((c) => c['id'] == mine)) return pickable;
    final own = _rows('categories').where((c) => c['id'] == mine);
    return [...pickable, ...own];
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final isExpense = widget.entry['type'] == 'expense';
    // A TRANSFER IS NOT AN ORDINARY ENTRY and this sheet was written before
    // one could exist. It carries no accountId and no flow ON PURPOSE: the
    // engine moved BOTH balances itself when it was created, and the row is
    // the receipt rather than the instruction (core/money/transfers.dart).
    //
    // Two fields on this form therefore corrupt it, and both were reachable
    // in four taps from Home:
    //
    //   ACCOUNT. `updateTransaction` reverses the old row through its
    //   accountId, finds none, and reverses NOTHING. It then applies the new
    //   row, which now HAS an accountId, at balanceSign = -1 (no flow, not
    //   income). Tapping the account the money came from took another 5,000
    //   out of it with nothing receiving it and no entry saying why.
    //
    //   AMOUNT. Neither side has an accountId, so no balance moves at all,
    //   and the stored row silently stops matching the money that actually
    //   moved. A row reading 3,000 against balances that shifted 5,000 can
    //   never be reconciled by anyone.
    //
    // The label stays editable, because a name is not money.
    final isTransfer = widget.entry['type'] == 'transfer';

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
            if (!isTransfer) ...[
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
            ] else ...[
              const SizedBox(height: 16),
              Text(
                // SAYS WHY THE FIELDS ARE GONE. A form that silently drops
                // two of its fields for one kind of entry reads as broken,
                // and somebody who wanted to correct a figure needs to know
                // what to do instead, not just that they cannot do it here.
                'The amount and accounts of a move cannot be edited. Both '
                'balances already moved when it was made, and changing the '
                'row here would not move them back. Delete it and make the '
                'move again instead.',
                style: TypeScale.caption(skin.text3),
              ),
            ],
            if (isExpense) ...[
              const SizedBox(height: 18),
              Text('Category', style: TypeScale.fieldLabel(skin.text3)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _pickableCategoriesKeepingMine())
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
            if (!isTransfer && _rows('accounts').isNotEmpty) ...[
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
    // A TRANSFER PATCHES ITS LABEL AND NOTHING ELSE, enforced here and not
    // only by hiding the fields above. The form is one way into this patch
    // and the guard belongs with the write, or the next screen that opens
    // this sheet reintroduces the defect by not knowing it existed.
    final isTransfer = widget.entry['type'] == 'transfer';
    // A blank or unparseable amount leaves the amount ALONE rather than
    // writing a zero. A zero is a real figure and "I could not read this" is
    // not the same statement.
    Navigator.of(context).pop(<String, dynamic>{
      'label': _label.text.trim(),
      if (!isTransfer && typed != null && typed > 0) 'amount': typed,
      if (!isTransfer) 'categoryId': _categoryId,
      if (!isTransfer) 'accountId': _accountId,
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
  for (final t
      in (state['transactions'] is List
          ? state['transactions'] as List
          : const [])) {
    if (t is Map && t['id'] == id) return t.cast<String, dynamic>();
  }
  return null;
}
