import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/ledger.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Log an entry, from src/components/LogSheet.tsx.
///
/// SCOPE, named rather than implied. The prototype's sheet also carries a
/// fast-log text parser, a foreign currency converter, a cash denomination
/// counter, receipt attachment, and quick-add for categories and
/// sub-categories. Each of those needs something app/ does not have yet (a
/// parser, an FX rate source, a camera, a writable category store), and a
/// control that cannot do its job is worse than no control. They migrate with
/// the features behind them.
///
/// What IS here is the whole money path: type, amount, account, category,
/// date, and for a transfer a destination. Everything the ledger needs to be
/// correct.
class LogSheet extends StatefulWidget {
  const LogSheet({super.key, required this.state});

  final FinancialState state;

  static Future<Transaction?> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<Transaction>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => LogSheet(state: state),
    );
  }

  @override
  State<LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<LogSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _merchant = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _person = TextEditingController();

  TransactionType _type = TransactionType.expense;
  late String _accountId;
  late String _toAccountId;
  String _category = 'Food & Dining';
  bool _showMore = false;

  List<Account> get _spendable =>
      widget.state.accounts.where((Account a) => a.isLiquid).toList();

  @override
  void initState() {
    super.initState();
    final List<Account> usable = _spendable;
    _accountId = usable.isNotEmpty ? usable.first.id : '';
    // The destination defaults to a DIFFERENT account. A transfer from an
    // account to itself moves nothing and reads as a bug to whoever logged it.
    _toAccountId = usable.length > 1 ? usable[1].id : _accountId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    _tags.dispose();
    _person.dispose();
    super.dispose();
  }

  double? get _amountValue => parseLoggedAmount(_amount.text);

  bool get _canSave {
    if (_amountValue == null) return false;
    if (_accountId.isEmpty) return false;
    // The quirk guard. applyToBalances reproduces the prototype faithfully,
    // and the prototype DESTROYS money on a transfer whose destination does
    // not exist: it debits the source and credits nobody. The engine keeps
    // that behaviour; this makes it unreachable from the app.
    if (_type == TransactionType.transfer) {
      if (_toAccountId.isEmpty) return false;
      if (_toAccountId == _accountId) return false;
      if (!_spendable.any((Account a) => a.id == _toAccountId)) return false;
    }
    return true;
  }

  void _save() {
    final double? amount = _amountValue;
    if (amount == null || !_canSave) return;

    final bool isTransfer = _type == TransactionType.transfer;
    Navigator.of(context).pop(
      Transaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        type: _type,
        amount: amount,
        // A transfer is not spending and not income, so it carries the one
        // category that says exactly that, and no sub-category.
        category: isTransfer ? 'Transfer' : _category,
        accountId: _accountId,
        toAccountId: isTransfer ? _toAccountId : null,
        date: _isoToday(),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        person: _person.text.trim().isEmpty ? null : _person.text.trim(),
        tags: parseTags(_tags.text),
      ),
    );
  }

  String _isoToday() {
    final DateTime d = widget.state.now;
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final bool isTransfer = _type == TransactionType.transfer;
    final double amount = _amountValue ?? 0;

    return SheetScaffold(
      palette: p,
      icon: Icons.add,
      title: 'Log an entry',
      subtitle: 'What moved, out of which account',
      footer: PrimaryButton(
        palette: p,
        label: 'Save entry',
        icon: Icons.check,
        onTap: _canSave ? _save : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What kind', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          SegmentedChoice<TransactionType>(
            palette: p,
            selected: _type,
            options: const <(TransactionType, String)>[
              (TransactionType.expense, 'Spent'),
              (TransactionType.income, 'Received'),
              (TransactionType.transfer, 'Moved'),
            ],
            onSelect: (TransactionType t) => setState(() => _type = t),
          ),
          const SizedBox(height: Spacing.md),

          SheetField(
            palette: p,
            label: 'Amount',
            controller: _amount,
            hint: '0.00',
            prefix: '₱ ',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Spacing.md),

          _AccountPicker(
            // Keyed because both pickers list account names, so a test (or a
            // screen reader) otherwise has two identical "BPI Preferred
            // Payroll" controls with nothing to tell them apart.
            key: const Key('log-source-picker'),
            palette: p,
            label: isTransfer ? 'From which account' : 'Which account',
            accounts: _spendable,
            selectedId: _accountId,
            onSelect: (String id) => setState(() {
              _accountId = id;
              // Keep a transfer from pointing at itself the moment the source
              // changes, rather than waiting for Save to refuse.
              if (_toAccountId == id) {
                final Account? other = _spendable.cast<Account?>().firstWhere(
                  (Account? a) => a!.id != id,
                  orElse: () => null,
                );
                if (other != null) _toAccountId = other.id;
              }
            }),
          ),

          if (isTransfer) ...<Widget>[
            const SizedBox(height: Spacing.md),
            _AccountPicker(
              key: const Key('log-destination-picker'),
              palette: p,
              label: 'To which account',
              accounts: _spendable
                  .where((Account a) => a.id != _accountId)
                  .toList(),
              selectedId: _toAccountId,
              onSelect: (String id) => setState(() => _toAccountId = id),
            ),
          ] else ...<Widget>[
            const SizedBox(height: Spacing.md),
            _CategoryPicker(
              palette: p,
              categories: widget.state.categories,
              type: _type,
              selected: _category,
              onSelect: (String c) => setState(() => _category = c),
            ),
          ],

          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: isTransfer ? 'What for (optional)' : 'Where (optional)',
            controller: _merchant,
            hint: isTransfer ? 'e.g. Top up GCash' : 'e.g. Jollibee, Meralco',
            keyboardType: TextInputType.text,
          ),

          const SizedBox(height: Spacing.md),
          _MoreToggle(
            palette: p,
            open: _showMore,
            onTap: () => setState(() => _showMore = !_showMore),
          ),
          if (_showMore) ...<Widget>[
            const SizedBox(height: Spacing.md),
            SheetField(
              palette: p,
              label: 'Person (optional)',
              controller: _person,
              hint: 'e.g. Nanay, Kuya Mark, a client',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: Spacing.md),
            SheetField(
              palette: p,
              label: 'Tags (optional)',
              controller: _tags,
              hint: 'weekly, groceries',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: Spacing.md),
            SheetField(
              palette: p,
              label: 'Note (optional)',
              controller: _note,
              hint: 'Anything you want to remember about this',
              keyboardType: TextInputType.text,
            ),
          ],

          if (amount > 0) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            _Confirmation(
              palette: p,
              type: _type,
              amount: amount,
              from: _named(_accountId),
              to: isTransfer ? _named(_toAccountId) : null,
            ),
          ],
        ],
      ),
    );
  }

  String _named(String id) {
    for (final Account a in widget.state.accounts) {
      if (a.id == id) return a.name;
    }
    return 'that account';
  }
}

/// Says in one sentence what Save is about to do, before it happens.
class _Confirmation extends StatelessWidget {
  const _Confirmation({
    required this.palette,
    required this.type,
    required this.amount,
    required this.from,
    this.to,
  });

  final Palette palette;
  final TransactionType type;
  final double amount;
  final String from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    final String sentence = switch (type) {
      TransactionType.expense => '${formatPeso(amount)} leaves $from.',
      TransactionType.income => '${formatPeso(amount)} goes into $from.',
      TransactionType.transfer =>
        '${formatPeso(amount)} moves from $from to ${to ?? "another account"}. '
            'Your net worth does not change.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        sentence,
        style: AppType.body(palette).copyWith(color: palette.accent),
      ),
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    super.key,
    required this.palette,
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onSelect,
  });

  final Palette palette;
  final String label;
  final List<Account> accounts;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: <Widget>[
            for (final Account a in accounts)
              _Pill(
                palette: palette,
                label: a.name,
                caption: formatPeso(a.balance),
                selected: a.id == selectedId,
                onTap: () => onSelect(a.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.palette,
    required this.categories,
    required this.type,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final List<CategoryInfo> categories;
  final TransactionType type;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // Only the categories that belong to this side of the ledger. Offering
    // Salary under an expense is how a ledger ends up uncategorisable later.
    final List<CategoryInfo> usable = categories.where((CategoryInfo c) {
      // Transfer is a TYPE, not a category somebody picks. It was showing up
      // in the list for a spend, which invites an entry tagged Transfer that
      // is not one, and those are the rows nobody can reconcile later. The
      // sheet sets this category itself when the type is Moved.
      if (c.name == 'Transfer') return false;
      if (c.kind == CategoryKind.both) return true;
      return type == TransactionType.income
          ? c.kind == CategoryKind.income
          : c.kind == CategoryKind.expense;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Category', style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: <Widget>[
            for (final CategoryInfo c in usable)
              _Pill(
                palette: palette,
                label: c.name,
                selected: c.name == selected,
                onTap: () => onSelect(c.name),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
    this.caption,
  });

  final Palette palette;
  final String label;
  final String? caption;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.accent : palette.card,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? palette.onAccent : palette.textSecondary,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: TextStyle(
                      fontSize: 10,
                      color: selected
                          ? palette.onAccent.withValues(alpha: 0.8)
                          : palette.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreToggle extends StatelessWidget {
  const _MoreToggle({
    required this.palette,
    required this.open,
    required this.onTap,
  });

  final Palette palette;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.centerLeft,
          child: Row(
            children: <Widget>[
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: palette.accent,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                open ? 'Fewer details' : 'Add a person, tags or a note',
                style: AppType.button(palette, color: palette.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
