import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import '../../core/money/format.dart';
import '../../core/money/plan.dart' show UpcomingTotals, computeUpcomingTotals;
import '../../core/money/reminders.dart' show daysUntil;
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';
import 'pay_bill_flow.dart';

/// Bills and scheduled payments, from Home's shortcut row.
///
/// Ported from the list half of `archive/prototype-google-ai-studio/src/components/BillsModal.tsx` on founder
/// direction, 2026-10-01 ("Migrate bills and move quick actions"), which
/// replaces the "Bills is not migrated yet" placeholder.
///
/// THE LIST ONLY, by founder choice between two options: "List first, then the
/// rest". The prototype's modal has three tabs. The other two, a month
/// calendar of which days bills land on and a cash flow timeline showing the
/// dip before payday, are a separate batch so this one can be looked at
/// sooner.
///
/// ## Why a sheet when Plan already shows bills
///
/// `BillsSegment` on the Plan tab lists the same items and is READ ONLY: it
/// even renders a struck-through paid state that nothing in the app could
/// set. That is the gap this fills. The segment stays as the place bills are
/// read in context alongside goals and budgets; every WRITE lives here, so
/// there is one place that changes a bill rather than two that can drift.
class BillsSheet extends StatefulWidget {
  const BillsSheet({super.key, required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  static Future<void> show(
    BuildContext context, {
    required Palette palette,
    required FinancialState state,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) =>
          BillsSheet(palette: palette, state: state),
    );
  }

  @override
  State<BillsSheet> createState() => _BillsSheetState();
}

class _BillsSheetState extends State<BillsSheet> {
  bool _adding = false;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _due = TextEditingController();
  UpcomingItemType _type = UpcomingItemType.bill;

  /// "Repeats every month" (D31). Off by default: a one-off is the old
  /// behaviour, and a monthly bill is a choice the person makes.
  bool _monthly = false;

  /// The due date as an ISO date, when the typed text can be read.
  String? get _isoDue {
    final DateTime now = widget.state.now;
    final int? days = daysUntil(_due.text.trim(), now);
    if (days == null) return null;
    final DateTime d = DateTime(now.year, now.month, now.day + days);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// The day of the month a monthly bill comes back on. A bare day the
  /// person typed ("31", "the 31st") wins over the date it lands on this
  /// month, so a bill on the 31st typed in September (30 days) still falls
  /// on the 31st in October.
  int? get _repeatDay {
    final RegExpMatch? bare = RegExp(
      r'^(?:the\s+)?(\d{1,2})(?:st|nd|rd|th)?$',
      caseSensitive: false,
    ).firstMatch(_due.text.trim());
    if (bare != null) {
      final int d = int.parse(bare.group(1)!);
      if (d >= 1 && d <= 31) return d;
    }
    final String? iso = _isoDue;
    return iso == null ? null : DateTime.parse(iso).day;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _due.dispose();
    super.dispose();
  }

  /// The typed amount as money, zero when the box holds nothing usable.
  ///
  /// Zero is the right fallback HERE, unlike the credit limit box, because
  /// `_canAdd` below refuses a zero and the value never reaches a record.
  /// The `isFinite` check the old version did by hand is now
  /// `tryFromDouble`'s job, which also turns away a figure too large to be
  /// a real amount.
  Money get _newAmount {
    final double? v = double.tryParse(_amount.text.replaceAll(',', '').trim());
    return v == null ? Money.zero : Money.tryFromDouble(v) ?? Money.zero;
  }

  bool get _canAdd =>
      _name.text.trim().isNotEmpty &&
      _newAmount.isPositive &&
      // A monthly bill needs a date Salapify can read, or it cannot know
      // which day to come back on.
      (!_monthly || _repeatDay != null);

  void _add() {
    if (!_canAdd) return;
    widget.state.addUpcoming(
      UpcomingItem(
        id: 'up_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        amount: _newAmount,
        // The prototype stores a human label here rather than a date, such as
        // "Today" or "Sep 18", and every screen that reads it prints it
        // straight out. Left empty it reads "Due", which says nothing, so it
        // falls back to a sentence that is at least true.
        dueDate: _monthly
            ? _isoDue!
            : (_due.text.trim().isEmpty ? 'No date set' : _due.text.trim()),
        type: _type,
        // Stored as a real date with the day it repeats on, so paying it can
        // move it to next month (D31).
        repeatDay: _monthly ? _repeatDay : null,
      ),
    );
    setState(() {
      _adding = false;
      _name.clear();
      _amount.clear();
      _due.clear();
      _type = UpcomingItemType.bill;
      _monthly = false;
    });
  }

  Future<void> _confirmDelete(UpcomingItem item) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: widget.palette.surface,
        title: Text(
          'Remove ${item.name}?',
          style: AppType.title(widget.palette),
        ),
        content: Text(
          item.isPaid
              // Said out loud because it is the opposite of what somebody
              // fears. Removing the schedule row must not un-spend money that
              // really left the account, and a person about to tap Remove is
              // entitled to know the payment survives.
              ? 'This takes it off your schedule. The payment you already '
                    'recorded stays in Activity, because it really happened.'
              : 'This takes it off your schedule. Nothing is paid or '
                    'un-paid by removing it.',
          style: AppType.body(widget.palette),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Keep it', style: AppType.body(widget.palette)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: AppType.body(
                widget.palette,
              ).copyWith(color: widget.palette.negative),
            ),
          ),
        ],
      ),
    );
    if (yes ?? false) {
      widget.state.deleteUpcoming(item.id);
      if (mounted) setState(() {});
    }
  }

  /// The bill paid most recently from this sheet, and the entry it wrote.
  ///
  /// Kept so the settled row can offer its own undo. A SnackBar is drawn
  /// BELOW a modal bottom sheet, and this sheet stands at 92% of the screen,
  /// so the usual undo was on screen and physically unreachable. Nothing can
  /// cover a button that is part of the sheet.
  String? _justPaidId;
  Transaction? _justPaidTx;

  Future<void> _pay(UpcomingItem item) async {
    final Transaction? written = await payBillFlow(
      context,
      widget.palette,
      widget.state,
      item,
      confirmWithSnackBar: false,
    );
    if (!mounted) return;
    setState(() {
      if (written != null) {
        _justPaidId = item.id;
        _justPaidTx = written;
      }
    });
  }

  /// Undo the last payment on a MONTHLY bill: the money comes back and the
  /// due date goes back a month. Reads the stored link, so it still works
  /// after the sheet was closed and opened again.
  void _undoMonthly(UpcomingItem item) {
    final String? txId = item.lastPaidTxId;
    if (txId == null) return;
    Transaction? written;
    for (final Transaction t in widget.state.transactions) {
      if (t.id == txId) written = t;
    }
    widget.state.undoUpcomingPaid(item.id, written);
    setState(() {
      if (_justPaidId == item.id) {
        _justPaidId = null;
        _justPaidTx = null;
      }
    });
  }

  void _undoPay() {
    final String? id = _justPaidId;
    if (id == null) return;
    widget.state.undoUpcomingPaid(id, _justPaidTx);
    setState(() {
      _justPaidId = null;
      _justPaidTx = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final List<UpcomingItem> items = widget.state.upcoming;
    final UpcomingTotals t = computeUpcomingTotals(items);

    final List<UpcomingItem> due = items
        .where((UpcomingItem u) => !u.isPaid)
        .toList();
    final List<UpcomingItem> done = items
        .where((UpcomingItem u) => u.isPaid)
        .toList();

    return SheetScaffold(
      palette: p,
      icon: Icons.receipt_long_outlined,
      title: 'Bills',
      subtitle: 'What is due, and what is settled',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // TWO figures, not one, matching what BillsSegment already does on
          // Plan. The prototype prints a single "Total Scheduled Bills" that
          // includes payday, so its headline read 38,029 when the bills came
          // to 5,529.
          StatPair(
            left: StatCard(
              palette: p,
              label: 'Going out',
              value: formatPeso(t.totalOut.pesos),
              caption: t.billCount == 1 ? '1 bill' : '${t.billCount} bills',
              valueColor: p.negative,
            ),
            right: StatCard(
              palette: p,
              label: 'Coming in',
              value: formatPeso(t.totalIn.pesos),
              caption: 'Payday and income',
              valueColor: p.positive,
            ),
          ),
          const SizedBox(height: Spacing.lg),

          if (_adding)
            _AddForm(
              palette: p,
              name: _name,
              amount: _amount,
              due: _due,
              type: _type,
              canAdd: _canAdd,
              monthly: _monthly,
              onMonthly: (bool v) => setState(() => _monthly = v),
              onType: (UpcomingItemType v) => setState(() => _type = v),
              onChanged: () => setState(() {}),
              onCancel: () => setState(() => _adding = false),
              onAdd: _add,
            )
          else
            PrimaryButton(
              palette: p,
              label: 'Schedule a bill',
              icon: Icons.add,
              onTap: () => setState(() => _adding = true),
            ),

          const SizedBox(height: Spacing.lg),
          Text('Due', style: AppType.section(p)),
          const SizedBox(height: Spacing.xs),
          if (due.isEmpty)
            Text(
              'Nothing is waiting. Anything you schedule shows up here.',
              style: AppType.caption(p),
            )
          else
            for (final UpcomingItem u in due)
              _BillRow(
                // Keyed by the item so a test can name ONE row. The actions
                // are words now, and their semantics labels merge into the
                // Text beneath them, so bySemanticsLabel is not a handle a
                // test can grab and "Mark paid" alone matches every unpaid
                // bill on the screen.
                key: ValueKey<String>('bill_${u.id}'),
                palette: p,
                item: u,
                // No pay action on an INCOME row, matching Home's Coming Up
                // card, which has always hidden it. Labelling a payday
                // "Mark paid" is the wrong sentence, and ticking it moves no
                // money anyway, so the control would do nothing visible and
                // say something untrue while doing it.
                onPay: u.countsAsIncome ? null : () => _pay(u),
                onDelete: () => _confirmDelete(u),
                // A MONTHLY bill stays in Due after it is paid, on its next
                // date, so its way back lives here (D31).
                onUndo: u.repeats && u.lastPaidTxId != null
                    ? () => _undoMonthly(u)
                    : null,
                undoLabel: 'Undo last payment',
                now: widget.state.now,
              ),

          if (done.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            Text('Settled', style: AppType.section(p)),
            const SizedBox(height: Spacing.xs),
            for (final UpcomingItem u in done)
              _BillRow(
                key: ValueKey<String>('bill_${u.id}'),
                palette: p,
                item: u,
                onPay: null,
                onDelete: () => _confirmDelete(u),
                onUndo: u.id == _justPaidId ? _undoPay : null,
                now: widget.state.now,
              ),
          ],

          const SizedBox(height: Spacing.lg),
          Text(
            'Ticking a bill paid takes the money out of the account you pick '
            'and records it in Activity. You can undo it straight away. A '
            'monthly bill moves to its next date instead of being ticked off.',
            style: AppType.caption(p),
          ),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    super.key,
    required this.palette,
    required this.item,
    required this.onPay,
    required this.onDelete,
    required this.onUndo,
    required this.now,
    this.undoLabel = 'Undo',
  });

  final Palette palette;
  final UpcomingItem item;
  final VoidCallback? onPay;
  final VoidCallback onDelete;

  /// Set only on the bill paid most recently from this sheet, or on a
  /// monthly bill whose last payment can still be undone.
  final VoidCallback? onUndo;
  final String undoLabel;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final bool income = item.countsAsIncome;

    // TWO ROWS, not one, and the render is why.
    //
    // The first version put the name, the amount, a 44dp tick and a 44dp
    // delete all on one line. On a 390dp phone that leaves the name about
    // 116dp, so EVERY bill read "Meralco Electri...", "Spotify Premium F...",
    // "Home Credit In...". A list where no row can be told from its
    // neighbour is not a list. Nothing failed: the names were ellipsised,
    // which is exactly what the widget was told to do.
    //
    // The name and the amount now own the top line and the controls sit
    // under them, so the name has roughly double the width and the amount
    // keeps its prominence.
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(Radii.control),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: palette.iconTile,
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(
                    income ? Icons.south_west : Icons.north_east,
                    size: 15,
                    color: income ? palette.positive : palette.accent,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        // Two lines, because these are real names with spaces
                        // in them and a long one should wrap rather than
                        // vanish. The mid-word break this repository warns
                        // about happens on single long WORDS, which a bill
                        // name is not.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.rowTitle(palette).copyWith(
                          decoration: item.isPaid
                              ? TextDecoration.lineThrough
                              : null,
                          color: item.isPaid
                              ? palette.textMuted
                              : palette.textPrimary,
                        ),
                      ),
                      Text(
                        // A stored ISO date reads as "Tue, Oct 20"; a
                        // label somebody typed ("Sep 25") prints as typed.
                        item.isPaid
                            ? 'Paid'
                            : item.repeats
                            ? 'Due ${formatDateLabel(item.dueDate, now: now)}'
                                  ' · Every month'
                            : 'Due ${formatDateLabel(item.dueDate, now: now)}',
                        style: AppType.caption(palette),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  formatPeso(item.amount.pesos),
                  style: AppType.amountSmall(palette).copyWith(
                    color: item.isPaid
                        ? palette.textMuted
                        : (income ? palette.positive : palette.textPrimary),
                    decoration: item.isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
            if (onUndo != null || onPay != null)
              Row(
                children: <Widget>[
                  const Spacer(),
                  // The way back, on the row itself. It appears only on the
                  // bill just paid from this sheet, so it reads as "that one,
                  // undo it" rather than as a button every settled bill
                  // carries forever.
                  if (onUndo != null)
                    _RowAction(
                      palette: palette,
                      label: undoLabel,
                      semantics: 'Undo paying ${item.name}',
                      onTap: onUndo!,
                      accent: true,
                    ),
                  if (onPay != null)
                    _RowAction(
                      palette: palette,
                      label: 'Mark paid',
                      semantics: 'Mark ${item.name} as paid',
                      onTap: onPay!,
                      accent: true,
                    ),
                  _RowAction(
                    palette: palette,
                    label: 'Remove',
                    semantics: 'Remove ${item.name} from the schedule',
                    onTap: onDelete,
                    accent: false,
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: _RowAction(
                  palette: palette,
                  label: 'Remove',
                  semantics: 'Remove ${item.name} from the schedule',
                  onTap: onDelete,
                  accent: false,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A small text button on a bill row.
///
/// WORDS, not bare icons. The first version used a tick and an X, and the X
/// was the same glyph the sheet header uses to close itself: two identical
/// marks on one screen meaning "shut this" and "delete this bill". Words cost
/// a little width and remove the whole question.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.palette,
    required this.label,
    required this.semantics,
    required this.onTap,
    required this.accent,
  });

  final Palette palette;
  final String label;
  final String semantics;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semantics,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          // No `alignment`. See the chip comments; a Container given one and
          // no width fills everything it is offered.
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: AppType.body(palette).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent ? palette.accent : palette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddForm extends StatelessWidget {
  const _AddForm({
    required this.palette,
    required this.name,
    required this.amount,
    required this.due,
    required this.type,
    required this.canAdd,
    required this.monthly,
    required this.onMonthly,
    required this.onType,
    required this.onChanged,
    required this.onCancel,
    required this.onAdd,
  });

  final Palette palette;
  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController due;
  final UpcomingItemType type;
  final bool canAdd;
  final bool monthly;
  final ValueChanged<bool> onMonthly;
  final ValueChanged<UpcomingItemType> onType;
  final VoidCallback onChanged;
  final VoidCallback onCancel;
  final VoidCallback onAdd;

  /// The kinds somebody schedules, with payday left out on purpose: payday is
  /// income the app derives from the pay cycle, not something anybody adds by
  /// hand here, and offering it would produce a second source of truth for
  /// when money arrives.
  static const List<(UpcomingItemType, String)> _kinds =
      <(UpcomingItemType, String)>[
        (UpcomingItemType.bill, 'Bill'),
        (UpcomingItemType.subscription, 'Subscription'),
        (UpcomingItemType.rent, 'Rent'),
        (UpcomingItemType.debt, 'Debt'),
        (UpcomingItemType.insurance, 'Insurance'),
        (UpcomingItemType.tuition, 'Tuition'),
        (UpcomingItemType.government, 'Government'),
        (UpcomingItemType.remittance, 'Remittance'),
      ];

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SheetField(
            palette: p,
            label: 'What is it',
            controller: name,
            hint: 'Converge Fibre, Netflix, the barangay fee',
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: 'How much',
            controller: amount,
            prefix: '₱ ',
            hint: '0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.md),
          SheetField(
            palette: p,
            label: 'When it is due (optional)',
            controller: due,
            hint: 'Sep 25, or the 10th',
            keyboardType: TextInputType.text,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: Spacing.xs),
          // ITS OWN MATERIAL, because the form's coloured box would hide the
          // tap ripple, and Flutter asserts on exactly that in a debug build.
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              key: const Key('bill-monthly'),
              contentPadding: EdgeInsets.zero,
              value: monthly,
              onChanged: onMonthly,
              activeTrackColor: p.accent,
              title: Text('Repeats every month', style: AppType.body(p)),
              subtitle: Text(
                'Paying it moves it to the same day next month.',
                style: AppType.caption(p),
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text('What kind', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          // Wrap, not Row. Eight chips cannot fit across a phone, and a Row
          // would overflow rather than fold.
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (final (UpcomingItemType, String) k in _kinds)
                _KindChip(
                  palette: p,
                  label: k.$2,
                  selected: type == k.$1,
                  onTap: () => onType(k.$1),
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton(
                  onPressed: onCancel,
                  child: Text('Cancel', style: AppType.body(p)),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: PrimaryButton(
                  palette: p,
                  label: 'Schedule it',
                  icon: Icons.check,
                  onTap: canAdd ? onAdd : null,
                ),
              ),
            ],
          ),
          if (!canAdd) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              monthly
                  ? 'A name, an amount, and a due date Salapify can read, '
                        'like Sep 25 or the 10th.'
                  : 'A name and an amount, and it is on the list.',
              style: AppType.caption(p),
            ),
          ],
        ],
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          // No `alignment`. A Container given one and no width fills
          // everything it is offered, which turns a Wrap of chips into a
          // stack of full-width bars. This repository has documented that
          // trap eight times, the most recent of them two hours ago in
          // move_money_sheet.dart.
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? Colors.transparent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: AppType.body(palette).copyWith(
              fontSize: 13,
              color: selected ? palette.onAccent : palette.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
