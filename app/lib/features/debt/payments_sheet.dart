import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/money.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// The payments recorded against one debt, listed.
///
/// ## Why this exists
///
/// Salapify has stored a register of debt payments for some time, and until
/// now nothing listed it. `.payments` was read for COUNTS ("Its 3 payments are
/// still recorded") and for `payments.last` inside the take-back, so a person
/// could learn that three payments existed and never see what they were.
///
/// CLAUDE.md's rule is that a write path is not finished until somebody can
/// SEE what it did, and the reason is written in the same file: a founder once
/// paid 1,500 off a loan, opened the account it came out of, and found nothing
/// in its history. The money was right and the trail was missing, and for
/// somebody who keeps books the trail IS the feature.
///
/// ## A sheet, not more rows on the card
///
/// The Debts screen is a list of cards and there is no debt detail page. A
/// single live card can already stack nine blocks: name, amount, progress bar,
/// caption, note, two actions, a take-back, an explanatory sentence and an
/// archive control. Expanding a five row register inside one of them would
/// roughly double the tallest card in the app, and because the cards sit in
/// one list, expanding card three pushes cards four and five off screen and
/// the person loses their place.
class DebtPaymentsSheet extends StatefulWidget {
  const DebtPaymentsSheet({
    super.key,
    required this.state,
    required this.debtId,
  });

  final FinancialState state;

  /// The ID rather than the Debt, because this sheet outlives any single copy
  /// of it: taking a payment back rewrites the debt, and a captured value
  /// would then describe a row that no longer exists.
  final String debtId;

  static Future<void> show(
    BuildContext context,
    Palette palette,
    FinancialState state,
    String debtId,
  ) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) =>
          DebtPaymentsSheet(state: state, debtId: debtId),
    );
  }

  @override
  State<DebtPaymentsSheet> createState() => _DebtPaymentsSheetState();
}

class _DebtPaymentsSheetState extends State<DebtPaymentsSheet> {
  bool _busy = false;

  Debt? get _debt => <Debt>[
    ...widget.state.debts,
    ...widget.state.archivedDebts,
  ].where((Debt d) => d.id == widget.debtId).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final Debt? debt = _debt;

    if (debt == null) {
      return SheetScaffold(
        palette: p,
        icon: Icons.history,
        title: 'Payments',
        subtitle: 'This debt is no longer here',
        child: Text(
          'The debt these payments belonged to has been removed.',
          style: AppType.body(p),
        ),
      );
    }

    // NEWEST FIRST, and `reversed` rather than a sort.
    //
    // Dart's sort is NOT stable, and two payments recorded on the same day
    // carry byte identical date strings, so a date sort is free to swap them
    // and put a row that is not `payments.last` at the top. The only take-back
    // the store offers acts on `payments.last`, so the top row would then
    // carry a control that acts on a different payment. The stored order is
    // already the order they happened in, because a payment is always stamped
    // with today and cannot be backdated.
    final List<DebtPayment> rows = debt.payments.reversed.toList();

    return SheetScaffold(
      palette: p,
      icon: Icons.history,
      title: 'Payments',
      subtitle: debt.person,
      child: rows.isEmpty ? _empty(p, debt) : _list(p, debt, rows),
    );
  }

  /// Nothing listed, which is the COMMON case rather than an edge one.
  ///
  /// Three of the five debts on a fresh install carry an opening `paidAmount`
  /// and no register at all, and a restored backup does the same. The sentence
  /// has to defeat one specific wrong conclusion: that the payments vanished.
  Widget _empty(Palette p, Debt debt) {
    final bool paidSomething = debt.paidAmount.isPositive;

    if (!paidSomething) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('No payments yet', style: AppType.section(p)),
          const SizedBox(height: Spacing.xs),
          Text(
            'Nothing is recorded against this debt right now. Record a payment '
            'and it will be listed here, newest first.',
            style: AppType.body(p),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${formatPeso(debt.paidAmount.pesos)} of '
          '${formatPeso(debt.totalAmount.pesos)} is recorded as paid',
          style: AppType.section(p),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          'That figure is right and it still counts everywhere in Salapify. '
          'What is missing is the list of the individual payments.',
          style: AppType.body(p),
        ),
        const SizedBox(height: Spacing.sm),
        // NAMES BOTH POSSIBLE CAUSES, because Salapify genuinely cannot tell
        // which one it was and picking one would be a guess presented as a
        // fact. "Nothing has been taken off your totals" is the load bearing
        // half and must not be cut: the failure this state has to defeat is a
        // person reading an empty list as lost money.
        Text(
          'This debt was either restored from a backup or paid before Salapify '
          'kept a payment list. Nothing has been taken off your totals, and '
          'payments you record from now on will be listed here.',
          style: AppType.caption(p),
        ),
      ],
    );
  }

  Widget _list(Palette p, Debt debt, List<DebtPayment> rows) {
    final Money listed = sumMoney(rows.map((DebtPayment r) => r.amount));
    final Money unlisted = debt.paidAmount - listed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: p.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < rows.length; i++) ...<Widget>[
                if (i > 0) Divider(height: 1, color: p.border),
                _PaymentRow(
                  palette: p,
                  row: rows[i],
                  newest: i == 0,
                  laterCount: i,
                  accountLine: _accountLine(rows[i]),
                  dateLine: _dateLine(rows[i]),
                  busy: _busy,
                  onTakeBack: () => _confirmTakeBack(p, debt, rows[i]),
                  onExplain: () => _explain(p, rows[i], i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.sm),
        // THE LIFO LINE, once, under the whole list rather than on four rows
        // out of five. It stays on screen under the founder's own exception:
        // somebody who sees a control on one row and not the others, with no
        // explanation, concludes the feature is broken.
        if (rows.length > 1)
          Text(
            'Only the newest payment can be taken back. An older one needs the '
            'payments after it taken back first.',
            style: AppType.caption(p),
          ),
        // THE DIFFERENCE, as a figure, when the rows do not account for the
        // whole paid amount.
        //
        // This is not an edge case. Three of the five seeded debts carry an
        // opening figure with no register, and "Mark settled" fills the rest
        // of a debt in without writing a row. Without this line the list sits
        // under a card saying a larger number and the person cannot account
        // for the difference, which is the worst thing a money screen can do.
        if (unlisted.isPositive) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          Text(
            'Listed here: ${formatPeso(listed.pesos)}. This debt counts '
            '${formatPeso(debt.paidAmount.pesos)} as paid. The '
            '${formatPeso(unlisted.pesos)} difference was paid before Salapify '
            'kept this list, or filled in by Mark settled.',
            style: AppType.caption(p),
          ),
        ],
        const SizedBox(height: Spacing.sm),
        Text(
          'Each payment with an account also has an entry in Activity. Take a '
          'payment back here, not there, so both move together.',
          style: AppType.caption(p),
        ),
      ],
    );
  }

  String _dateLine(DebtPayment row) {
    // formatDateLabel returns the input verbatim when it cannot parse, which
    // would draw a raw ISO date on screen and is an automatic failure of the
    // readability sweep. A hand edited backup can carry one.
    final DateTime? parsed = DateTime.tryParse(row.date);
    if (parsed == null) return 'Date not recorded';

    final String label = formatDateLabel(row.date, now: widget.state.now);
    // formatDateLabel drops the YEAR, so a payment from 2024 restored out of a
    // backup would read "Mar 12" and look like this year.
    if (parsed.year != widget.state.now.year) {
      return '$label, ${parsed.year}';
    }
    return label;
  }

  String _accountLine(DebtPayment row) {
    if (row.accountId == null) {
      // Word for word the chip label in the payment sheet, so it reads as the
      // choice the person made rather than a field the app failed to fill.
      return 'No account, just the debt';
    }
    final Account? a = widget.state.accounts
        .where((Account x) => x.id == row.accountId)
        .firstOrNull;
    if (a == null) {
      return 'The account this came from is no longer in Salapify';
    }
    // The FULL name, not the short form: with a "GCash Wallet" and a "GCash
    // Savings" the short form is "GCash" for both, and a list somebody audits
    // is the worst place for that ambiguity.
    return a.name;
  }

  Future<void> _explain(Palette p, DebtPayment row, int laterCount) async {
    final String later = laterCount == 1
        ? 'has 1 payment after it. Take that one back first and this one '
              'becomes the newest.'
        : 'has $laterCount payments after it. Take those back first, newest '
              'first, and this one becomes the newest.';

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('This one cannot come back yet', style: AppType.title(p)),
        content: Text(
          'Salapify keeps one running figure for what you have paid, so a '
          'payment can only be taken back if nothing landed after it.\n\n'
          'The ${formatPeso(row.amount.pesos)} from ${_dateLine(row)} '
          '$later\n\n'
          'Nothing is lost by doing that. Each take-back puts the money back '
          'in the account it came from and asks you first.',
          style: AppType.body(p),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: AppType.body(p)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmTakeBack(Palette p, Debt debt, DebtPayment row) async {
    final Account? from = row.accountId == null
        ? null
        : widget.state.accounts
              .where((Account a) => a.id == row.accountId)
              .firstOrNull;

    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Take this payment back?', style: AppType.title(p)),
        content: Text(
          'This takes back the ${formatPeso(row.amount.pesos)} payment you '
          'recorded ${_dateLine(row).toLowerCase()} against '
          '${debt.person}.\n\n'
          '${debt.person} goes back to ${formatPeso(row.paidBefore.pesos)} '
          'paid of ${formatPeso(debt.totalAmount.pesos)}.\n\n'
          '${from == null ? 'No account moves, because this payment was recorded against the debt alone.' : '${from.name} goes back up by ${formatPeso(row.amount.pesos)}, and the entry stays in your Activity, marked as taken back.'}',
          style: AppType.body(p),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Keep it', style: AppType.body(p)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Take it back', style: AppType.body(p)),
          ),
        ],
      ),
    );

    if (yes != true) return;
    setState(() => _busy = true);
    // `row.id` is the payment this dialog just described in pesos, by date and
    // by account. The store acts on THAT row or refuses.
    widget.state.takeBackDebtPayment(debt.id, paymentId: row.id);
    if (mounted) setState(() => _busy = false);
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.palette,
    required this.row,
    required this.newest,
    required this.laterCount,
    required this.accountLine,
    required this.dateLine,
    required this.busy,
    required this.onTakeBack,
    required this.onExplain,
  });

  final Palette palette;
  final DebtPayment row;
  final bool newest;
  final int laterCount;
  final String accountLine;
  final String dateLine;
  final bool busy;
  final VoidCallback onTakeBack;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    return Material(
      // The newest row is drawn differently ONCE, and the absence of a control
      // on the others carries the rest. A sentence on every older row is the
      // per-row clutter the founder ruled against, and a greyed out button on
      // each of them reads as the app being broken.
      color: newest ? palette.accentSoft : palette.surface,
      child: InkWell(
        // Older rows are tappable so the tap lands on an explanation rather
        // than on nothing. Somebody who keeps books WILL try to correct the
        // third payment, and a dead row reads as a dead screen.
        onTap: newest ? null : onExplain,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // The DATE leads, which inverts the Activity row on
                        // purpose. There every row is a different merchant, so
                        // the name is the identity. Here every row is a
                        // payment on one debt to one person, so when it
                        // happened is the only thing telling them apart.
                        Text(dateLine, style: AppType.rowTitle(palette)),
                        const SizedBox(height: 2),
                        Text(
                          accountLine,
                          style: AppType.rowMeta(palette),
                          maxLines: 2,
                        ),
                        if (row.note != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            row.note!,
                            style: AppType.rowMeta(palette),
                            maxLines: 2,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // Not signed and not tinted by direction. The whole sheet is
                  // one debt going one way and the header says which, so a
                  // column of red figures on money somebody is owed would be
                  // plainly wrong.
                  Text(
                    formatPeso(row.amount.pesos),
                    style: AppType.amountSmall(palette),
                  ),
                ],
              ),
              if (newest) ...<Widget>[
                const SizedBox(height: Spacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: busy ? null : onTakeBack,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Radii.control),
                      ),
                    ),
                    // The SAME six words as the card's own button, because
                    // two other screens send people looking for that exact
                    // phrase: the Activity detail sheet and the
                    // reconciliation view both name it.
                    child: Text(
                      'Take back the last payment',
                      style: AppType.body(palette),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
