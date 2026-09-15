// "Rent was due on the 14th. Did it happen?"
//
// The one place a recurring bill stops being a projection and becomes a real
// entry, and it needs a tap because the founder decided it does (2026-09-15,
// "Ask me first, then post"). Every peso that moves here moves through the
// golden locked engine; this file draws the question and nothing else.
//
// WHY IT LIVES ON HOME. Recurring items live on Plan, and the pending ones do
// not belong there. Plan answers "what is coming", which is a planning
// question somebody opens deliberately. This answers "what is waiting for me",
// which is the question Home exists for, and a confirmation nobody sees is a
// confirmation nobody gives: the bill stays pending forever, the projection
// keeps showing it as upcoming, and the feature quietly does nothing.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/format.dart' show formatMoney, prettyDay;
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../plan/pending_bills.dart';

class DueBillsCard extends StatelessWidget {
  const DueBillsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final now = context.now;
    final due = pendingBills(data, now);
    if (due.isEmpty) return const SizedBox.shrink();

    final total = due
        .where((b) => b.row['type'] != 'income')
        .fold(0.0, (t, b) => t + amountOf(b.row['amount']));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Head(title: due.length == 1 ? 'One is due' : '${due.length} are due'),
        const SizedBox(height: 6),
        Text(
          // ONE SENTENCE, and it carries the only thing a person cannot see by
          // looking: that nothing has moved yet. "2 are due" on its own is a
          // notification rather than a reason to act, and the whole point of
          // confirming instead of posting is that the balances everywhere else
          // in the app are still the old ones until you tap.
          total > 0
              ? '${formatMoney(total)} is waiting. Nothing moves until you add '
                    'it.'
              : 'Nothing moves until you add it.',
          style: TypeScale.caption(context.skin.text2),
        ),
        const SizedBox(height: 10),
        Group(
          inset: 0,
          children: [for (final b in due) _DueRow(bill: b.row, date: b.date)],
        ),
      ],
    );
  }
}

class _DueRow extends StatefulWidget {
  const _DueRow({required this.bill, required this.date});
  final Map<String, dynamic> bill;

  /// The date the entry will carry, from the engine rather than from today.
  final String date;

  @override
  State<_DueRow> createState() => _DueRowState();
}

class _DueRowState extends State<_DueRow> {
  /// So a second tap while the write is in flight cannot post twice.
  ///
  /// `postOneBill` already refuses a row that is no longer pending, and the
  /// engine's own stamp refuses it after that, so this is the third guard and
  /// the cheapest. It exists for the FEEL rather than the correctness: a button
  /// that does nothing visible for half a second gets tapped again, and the
  /// person deserves to see that their tap landed.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final b = widget.bill;
    final income = b['type'] == 'income';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (b['label'] ?? 'Recurring').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.rowTitle(skin.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      // A REAL DATE, and this is the one place in the app where
                      // that is right for a recurring item. Everywhere else it
                      // prints "the 11th", because a stored day repeats every
                      // month and a date would invent one. Here the engine has
                      // already picked the month, so the date is a fact rather
                      // than an invention, and it comes back from the engine's
                      // own probe post so the short-month clamp is never
                      // restated in a screen file.
                      //
                      // It says WILL BE DATED rather than "was due", because
                      // that is the question a person is about to have. The
                      // entry lands on the day it fell due, not today, so
                      // confirming a bill from the 3rd on the 11th files it
                      // eight days back behind everything logged since, and
                      // somebody who checks the top of their Ledger will not
                      // find it.
                      'Will be dated ${prettyDay(widget.date)}',
                      style: TypeScale.caption(skin.text3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                formatMoney(amountOf(b['amount'])),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.rowAmount(income ? skin.good : skin.text),
              ),
            ],
          ),
          // A BILL WITH NO ACCOUNT RECORDS AN ENTRY AND MOVES NOTHING, and the
          // card's own sentence above promises the opposite. `postDueRecurring`
          // only adjusts a balance when `accountId` names a live account; with
          // none it appends the transaction and stops, which is the shipped
          // app's behaviour and is golden locked, so the fix is to say so
          // rather than to change it.
          //
          // It is not a corner case. The recurring editor lets the account be
          // left empty, and a restored backup can carry rows from a version
          // that never had the field, so a person can easily hold several.
          if (!income && !_movesAnAccount(context, b)) ...[
            const SizedBox(height: 5),
            Text(
              'No account linked, so no balance moves.',
              style: TypeScale.caption(skin.bad),
            ),
          ],
          const SizedBox(height: 10),
          // ONE BUTTON. There was a "Not yet" beside it whose entire effect was
          // a dialog saying nothing had happened, which is a control that does
          // nothing dressed as a choice. Not yet is what happens when you do
          // not tap: the row stays, and the sentence above the list already
          // says nothing moves until you add it. Two buttons also made every
          // row twice as tall on the screen the founder opens most.
          // COMPACT, because this is a confirmation on a list row and not a
          // page's one action. Left to fill, the pill became the largest object
          // on Home, louder than the safe to spend figure, and three due bills
          // would have stacked three of them.
          Align(
            alignment: Alignment.centerLeft,
            child: PillButton(
              compact: true,
              label: _busy ? 'Adding' : (income ? 'It arrived' : 'I paid it'),
              onTap: _busy ? null : _post,
            ),
          ),
        ],
      ),
    );
  }

  /// Whether confirming this bill will actually move a balance.
  ///
  /// The account has to EXIST, not merely be named: `postDueRecurring` looks
  /// the id up in the accounts list and silently skips the movement when it
  /// finds nothing, so an id left behind by a deleted account behaves exactly
  /// like an empty one and has to read the same way here.
  bool _movesAnAccount(BuildContext context, Map<String, dynamic> bill) {
    final id = (bill['accountId'] ?? '').toString();
    if (id.isEmpty) return false;
    final accounts = context.ledger.data['accounts'];
    if (accounts is! List) return false;
    return accounts.any((a) => a is Map && a['id'] == id);
  }

  Future<void> _post() async {
    setState(() => _busy = true);
    final store = context.ledger;
    final now = context.now;
    final id = (widget.bill['id'] ?? '').toString();
    try {
      await store.apply(
        (s) => postOneBill(
          s,
          id,
          now,
          () => 'tx_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
    } finally {
      // The row usually disappears with the rebuild, so this only matters when
      // the write FAILED and the row is still here. Without it a failed write
      // leaves a permanently disabled button and no way to try again, which is
      // the same defect the account flag switch shipped once.
      if (mounted) setState(() => _busy = false);
    }
  }
}
