import 'package:flutter/material.dart';

import '../../core/money/fast_log.dart';
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
  final TextEditingController _quick = TextEditingController();

  TransactionType _type = TransactionType.expense;
  late String _accountId;
  late String _toAccountId;
  String _category = 'Food & Dining';
  bool _showMore = false;

  /// Defaults to today and is set from the picker. Late because it reads the
  /// store's clock, which a test pins.
  late DateTime _date;

  List<Account> get _spendable =>
      widget.state.accounts.where((Account a) => a.isLiquid).toList();

  @override
  void initState() {
    super.initState();
    final List<Account> usable = _spendable;
    _date = widget.state.now;
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
    _quick.dispose();
    super.dispose();
  }

  double? get _amountValue => parseLoggedAmount(_amount.text);

  /// What the quick line currently means, or null when it means nothing yet.
  FastLogResult? get _preview {
    if (_quick.text.trim().isEmpty) return null;
    final FastLogResult r = parseFastLog(_quick.text);
    return r.isValid ? r : null;
  }

  /// Fills the form from one typed line.
  ///
  /// It fills the FORM rather than saving, deliberately. The parser is a good
  /// guess and a guess about money should be visible before it is committed:
  /// everything it worked out lands in the controls below, where it can be
  /// corrected, and Save is the same button it always was.
  void _applyQuick() {
    final FastLogResult? r = _preview;
    if (r == null) return;

    setState(() {
      _type = r.type;
      _amount.text = r.amount == r.amount.roundToDouble()
          ? r.amount.toStringAsFixed(0)
          : r.amount.toStringAsFixed(2);
      _merchant.text = r.merchant;
      if (r.person != null) _person.text = r.person!;

      // The account hint is a KIND, not an account. Match the first real one
      // of that kind and ignore the hint when nothing fits, rather than
      // silently leaving the wrong account selected.
      if (r.accountKind != null) {
        for (final Account a in _spendable) {
          if (a.kind == r.accountKind) {
            _accountId = a.id;
            break;
          }
        }
      }

      // The category is applied ONLY when the line actually named one, and
      // only when it belongs to the chosen type.
      //
      // The first half of that is the founder's "Electricity" report. The
      // parser's fallback category is 'Food & Dining', so a word it does not
      // know produces a confident wrong answer rather than no answer, and
      // applying it would overwrite a correct selection with a guess. Now an
      // unrecognised line leaves the picker exactly where it was and the
      // read-back says so.
      //
      // The second half: "mp2 2000" parses as an expense in Investment &
      // Passive Income, an income category, and the picker below filters by
      // type, so applying it would select something the person cannot see and
      // cannot change.
      if (r.categoryMatched && r.type != TransactionType.transfer) {
        final bool usable = widget.state.categories.any(
          (CategoryInfo c) =>
              c.name == r.category &&
              (c.kind == CategoryKind.both ||
                  (r.type == TransactionType.income
                      ? c.kind == CategoryKind.income
                      : c.kind == CategoryKind.expense)),
        );
        if (usable) _category = r.category;
      }

      // Keep a transfer from pointing at its own source after a type change.
      if (_type == TransactionType.transfer && _toAccountId == _accountId) {
        for (final Account a in _spendable) {
          if (a.id != _accountId) {
            _toAccountId = a.id;
            break;
          }
        }
      }

      _quick.clear();
    });
  }

  /// Changes the type AND reconciles the category to it.
  ///
  /// The category picker filters by type, so switching to Received while
  /// "Food & Dining" was selected left NOTHING highlighted and saved the
  /// income under an expense category anyway, because Save never looked at
  /// the category. The mirror case is worse: a spend filed under Salary is
  /// invisible to every category total and budget. The prototype does this
  /// same reconciliation in a useEffect on type.
  void _setType(TransactionType next) {
    setState(() {
      _type = next;
      if (next == TransactionType.transfer) return;

      final List<CategoryInfo> usable = _categoriesFor(next);
      final bool stillValid = usable.any(
        (CategoryInfo c) => c.name == _category,
      );
      if (!stillValid && usable.isNotEmpty) _category = usable.first.name;

      if (_toAccountId == _accountId) {
        for (final Account a in _spendable) {
          if (a.id != _accountId) {
            _toAccountId = a.id;
            break;
          }
        }
      }
    });
  }

  /// The categories that belong to one side of the ledger. One definition,
  /// used by the picker AND by the reconciliation above, so they cannot
  /// disagree about what is selectable.
  List<CategoryInfo> _categoriesFor(TransactionType type) {
    return widget.state.categories.where((CategoryInfo c) {
      // Transfer is a TYPE, not a category somebody picks.
      if (c.name == 'Transfer') return false;
      if (c.kind == CategoryKind.both) return true;
      return type == TransactionType.income
          ? c.kind == CategoryKind.income
          : c.kind == CategoryKind.expense;
    }).toList();
  }

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
        date: _iso(_date),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        merchant: _merchant.text.trim().isEmpty ? null : _merchant.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        person: _person.text.trim().isEmpty ? null : _person.text.trim(),
        tags: parseTags(_tags.text),
        // STAMPED, never left null. The prototype stores the active profile on
        // every entry and falls back to personal when the "All" tab is
        // selected. Leaving it null here meant the ledger had to guess, and an
        // entry logged while a profile tab was active vanished from the very
        // screen the app navigated to after saving it.
        profile: widget.state.activeProfile ?? ProfileEntity.personal,

        // STAMPED, never left null. The prototype stores the active profile on
        // every entry and falls back to personal when the "All" tab is
        // selected. Leaving it null here meant the ledger had to guess, and
        // an entry logged while a profile tab was active vanished from the
        // very screen the app navigated to after saving it.
      ),
    );
  }

  String _iso(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// Opens the date picker.
  ///
  /// BOUNDS, and why they are a decision rather than a copy. The prototype is
  /// a bare <input type="date"> with no min and no max, so it accepts any date
  /// in either direction. Flutter's showDatePicker REQUIRES a first and last
  /// date, so something has to be chosen either way.
  ///
  /// The past is open, five years, which is more than anybody will backfill on
  /// a phone. The future is NOT, and that is the deliberate half: logging an
  /// entry moves the account balance immediately, so a future-dated expense
  /// would take the money out today and then file the entry under a day that
  /// has not happened. The balance and the ledger would disagree until that
  /// date arrived. Scheduling a payment is a real need and it belongs to the
  /// Upcoming feature, which already exists to say what has not happened yet.
  Future<void> _pickDate() async {
    final DateTime today = widget.state.now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(today.year - 5, today.month, today.day),
      lastDate: DateTime(today.year, today.month, today.day),
      helpText: 'When did this happen',
    );
    if (picked != null) setState(() => _date = picked);
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
          _QuickParseField(
            palette: p,
            controller: _quick,
            preview: _preview,
            onChanged: (_) => setState(() {}),
            onApply: _applyQuick,
          ),
          const SizedBox(height: Spacing.lg),

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
            onSelect: _setType,
          ),
          const SizedBox(height: Spacing.md),

          SheetField(
            // Keyed so a test names THIS field rather than "the first one".
            // Adding the quick-parse line above it silently turned four tests
            // into tests of a different field.
            key: const Key('log-amount'),
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
              // Keyed so a test can name a category in THIS control. Category
              // names also appear in the read-back sentence above it.
              key: const Key('log-category-picker'),
              palette: p,
              categories: _categoriesFor(_type),
              selected: _category,
              onSelect: (String c) => setState(() => _category = c),
            ),
          ],

          const SizedBox(height: Spacing.md),
          SheetField(
            key: const Key('log-merchant'),
            palette: p,
            label: isTransfer ? 'What for (optional)' : 'Where (optional)',
            controller: _merchant,
            hint: isTransfer ? 'e.g. Top up GCash' : 'e.g. Jollibee, Meralco',
            keyboardType: TextInputType.text,
          ),

          const SizedBox(height: Spacing.md),
          _DateField(
            palette: p,
            date: _date,
            now: widget.state.now,
            onTap: _pickDate,
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
              backdated: _iso(_date) != _iso(widget.state.now),
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
    required this.backdated,
    this.to,
  });

  final Palette palette;
  final TransactionType type;
  final double amount;
  final String from;
  final String? to;

  /// Whether the entry is dated before today. It changes what this card has to
  /// say, not how it looks.
  final bool backdated;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            sentence,
            style: AppType.body(palette).copyWith(color: palette.accent),
          ),
          if (backdated) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              // The balance moves NOW even for an entry dated last week. That
              // is correct for a ledger catching up on a receipt, and it is
              // surprising enough to say out loud rather than let somebody
              // discover it by watching a figure change.
              'The balance changes now, even though the entry is dated '
              'earlier.',
              style: AppType.caption(palette),
            ),
          ],
        ],
      ),
    );
  }
}

/// When it happened. Tapping it opens the date picker.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.palette,
    required this.date,
    required this.now,
    required this.onTap,
  });

  final Palette palette;
  final DateTime date;
  final DateTime now;
  final VoidCallback onTap;

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final String iso = _iso(date);
    final bool isToday = iso == _iso(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('When', style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Semantics(
          button: true,
          label: 'Change the date, currently ${formatDateLabel(iso, now: now)}',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(
                  // Highlighted when it is NOT today, because a date somebody
                  // deliberately changed is the one worth noticing on the way
                  // back down to Save.
                  color: isToday ? palette.border : palette.accent,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_outlined,
                    size: 18,
                    color: isToday ? palette.textMuted : palette.accent,
                  ),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          formatDateLabel(iso, now: now),
                          style: AppType.rowTitle(palette),
                        ),
                        // The stored date as well, for the same reason the
                        // transaction detail shows it: "Yesterday" is useless
                        // beside a bank statement.
                        Text(iso, style: AppType.caption(palette)),
                      ],
                    ),
                  ),
                  Text(
                    'Change',
                    style: AppType.button(palette, color: palette.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    super.key,
    required this.palette,
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;

  /// Already narrowed to the chosen type by _categoriesFor, so this widget
  /// cannot disagree with the reconciliation that keeps the selection valid.
  final List<CategoryInfo> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Category', style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: <Widget>[
            for (final CategoryInfo c in categories)
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

/// The one line that fills the form.
///
/// It sits at the TOP of the sheet and it is optional. Somebody who does not
/// want to type a sentence scrolls past it to the ordinary controls, and
/// somebody who does gets the whole form filled from "Jollibee 500".
class _QuickParseField extends StatelessWidget {
  const _QuickParseField({
    required this.palette,
    required this.controller,
    required this.preview,
    required this.onChanged,
    required this.onApply,
  });

  final Palette palette;
  final TextEditingController controller;
  final FastLogResult? preview;
  final ValueChanged<String> onChanged;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final FastLogResult? r = preview;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.bolt, size: 16, color: palette.accent),
            const SizedBox(width: Spacing.xs),
            Text('Type it in one line', style: AppType.label(palette)),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        TextField(
          key: const Key('log-quick-parse'),
          controller: controller,
          onChanged: onChanged,
          onSubmitted: (_) => onApply(),
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          style: AppType.rowTitle(palette).copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Jollibee 500 gcash',
            hintStyle: AppType.body(palette).copyWith(color: palette.textMuted),
            filled: true,
            fillColor: palette.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.accent, width: 2),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),
        if (r == null)
          Text(
            'An amount plus a word or two. Try "grab 420" or '
            '"padala kay nanay 8000".',
            style: AppType.caption(palette),
          )
        else
          // Shows WHAT IT UNDERSTOOD before anything is filled in, because a
          // parser that guesses silently is a parser nobody should trust with
          // money. Reading it back is what makes a wrong guess obvious.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _readBack(r),
                  style: AppType.body(palette).copyWith(color: palette.accent),
                ),
                const SizedBox(height: Spacing.sm),
                Semantics(
                  button: true,
                  child: InkWell(
                    onTap: onApply,
                    borderRadius: BorderRadius.circular(Radii.control),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.arrow_downward,
                            size: 16,
                            color: palette.accent,
                          ),
                          const SizedBox(width: Spacing.sm),
                          Text(
                            'Fill the form with this',
                            style: AppType.button(
                              palette,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _readBack(FastLogResult r) {
    final String verb = switch (r.type) {
      TransactionType.expense => 'Spent',
      TransactionType.income => 'Received',
      TransactionType.transfer => 'Moved',
    };
    final StringBuffer b = StringBuffer()
      ..write('$verb ${formatPeso(r.amount)}')
      ..write(' at ${r.merchant}');

    // Says "I do not know" instead of naming the fallback category. The
    // fallback is 'Food & Dining', so the old sentence read "filed under Food
    // & Dining" for a word the parser had never seen, which is the most
    // confident possible way to be wrong. The founder typed "Electricity" and
    // this sentence told them it was food.
    if (r.categoryMatched) {
      b.write(', filed under ${r.category}');
    } else {
      b.write(', category not recognized, so pick one below');
    }
    if (r.person != null) b.write(', with ${r.person}');
    b.write('.');
    return b.toString();
  }
}
