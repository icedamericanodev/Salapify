// The bills standing between now and payday, named.
//
// Home tells you what is safe to spend and, since the bar, that some of the
// cash is already committed. Neither answers the obvious next question: to
// WHAT. "₱250 is spoken for" invites exactly one follow-up, and the app knew
// the answer all along and did not say it.
//
// Every figure here comes from upcomingCommitments, the same engine call the
// safe-to-spend number is built on, so this list can never disagree with the
// number it explains.
//
// Deliberately NOT a running "left after each bill" column, which the older
// app shows. That number is a real subtraction of money, and inventing it in
// a widget would put money math in the UI layer where no golden vector can
// reach it. The total is an engine value and the remainder after it is an
// engine value; the steps in between are not, so they are not shown.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'section.dart';

class BillsBeforePayday extends StatelessWidget {
  /// Rows from `upcomingCommitments(...)['bills']`: name, kind, date, amount.
  final List<Map<String, dynamic>> bills;

  /// `upcomingCommitments(...)['total']`.
  final double total;

  /// Injected rather than imported, so this widget never owns a second money
  /// formatter. Two formatters eventually disagree about a centavo.
  final String Function(num) format;

  /// Formats an ISO date as a short human day. Injected for the same reason.
  final String Function(String) formatDay;

  // ignore: prefer_const_constructors_in_immutables
  BillsBeforePayday({
    super.key,
    required this.bills,
    required this.total,
    required this.format,
    required this.formatDay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The trailing total is why SectionHeader grew that parameter:
            // naming the group and totalling it on one line beats a header
            // followed by a sum the reader has to do themselves.
            SectionHeader(
              'BILLS BEFORE PAYDAY',
              trailing: format(total),
              trailingColor: Barako.warning,
            ),
            const SizedBox(height: Gap.md),
            for (var i = 0; i < bills.length; i++) ...[
              if (i > 0) const SizedBox(height: Gap.md),
              _row(bills[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> b) {
    final name = (b['name'] ?? '').toString();
    final kind = (b['kind'] ?? '').toString();
    final date = (b['date'] ?? '').toString();
    final amount = b['amount'];
    // A card minimum and a full bill are different promises, and the older app
    // says which. Paying a minimum keeps you out of late fees but not out of
    // interest, so a row that hides the distinction quietly overstates how
    // covered you are.
    final sub = kind == 'minimum'
        ? 'minimum · ${formatDay(date)}'
        : formatDay(date);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(color: Barako.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: Gap.md),
        Text(
          // The minus is explicit. These are all outgoings, and a bare peso
          // figure in a list reads as a balance rather than a deduction.
          '- ${format(amount is num ? amount : 0)}',
          style: TextStyle(
            color: Barako.warning,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
