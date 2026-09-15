// Ledger. Question 3 of the five in 01-vision.md: what happened?
//
// Grouped by day, newest first, with a day total on each heading. This is the
// smallest thing that makes the Log sheet REVIEWABLE: a save nothing displays
// cannot be checked by the founder or by a test, and "it saved, trust me" is
// not a feature.
//
// Tap to edit is HERE now. Search, filter chips and swipe to delete are the
// roadmap's later steps and are deliberately not here yet.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../core/money/ledger.dart';
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../insights/insights_screen.dart' show InsightsBody;
import 'entry_presentation.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  /// 0 is Entries, 1 is Insights. Local, not in the URL: the segment is a view
  /// preference rather than a place, and it survives a tab switch because the
  /// shell keeps each branch alive.
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    // THE HEADER AND THE SEGMENT ARE BUILT BEFORE ANYTHING BRANCHES ON THE
    // DATA, and that is the whole shape of this method rather than a detail.
    //
    // The old version returned the empty state early, header and all. Adding
    // the segment after that return would have meant a ledger with no entries
    // had no reachable Insights segment at all, which is exactly the defect
    // the Accounts screen shipped: its empty branch swallowed the Settings
    // action, and the backup and restore behind it, on the one ledger where
    // restore is the thing a person most needs.
    return Screen(
      children: [
        const SizedBox(height: 14),
        // ONE SUBTITLE FOR BOTH SEGMENTS. It sits above the segment control,
        // so it cannot describe only the entries. The Plan screen has the same
        // note for the same reason: its subtitle once described Upcoming alone
        // and contradicted the list underneath it the moment that segment grew.
        const ScreenTitle(
          title: 'Ledger',
          sub: 'Everything you have logged, and what it all adds up to.',
        ),
        const SizedBox(height: 16),
        Segmented(
          options: const ['Entries', 'Insights'],
          index: _view,
          onPick: (i) => setState(() => _view = i),
        ),
        const SizedBox(height: 20),
        if (_view == 1) ...InsightsBody.of(context) else ..._entries(context),
      ],
    );
  }

  List<Widget> _entries(BuildContext context) {
    final days = groupByDay(context.ledger.data);

    if (days.isEmpty) {
      return const [
        EmptyState(
          icon: Icons.article_outlined,
          title: 'No entries yet',
          body:
              'Every expense, income and transfer you log lands here, '
              'grouped by the day it happened.',
        ),
      ];
    }

    return [
      // The sentence says what the chevron shows. A marker teaches somebody
      // who is already looking for one; a sentence reaches the person who has
      // not thought to look. The founder asked how a user would ever know a
      // transaction could be corrected, and the honest answer was that nothing
      // on this screen told them.
      //
      // It moved OUT of the screen subtitle when Insights became the second
      // segment, because "tap any entry to edit it" is false of the charts and
      // the subtitle now covers both.
      Text(
        'Tap any entry to edit or delete it.',
        style: TypeScale.caption(context.skin.text3),
      ),
      const SizedBox(height: 14),
      for (final day in days) ...[
        Head(
          title: prettyDay(day.date),
          // amount, not action: a day total is money, so it takes a
          // direction colour and never the accent. See the note on Head.
          amount: day.counts ? formatMoney(day.total) : null,
          tone: day.total > 0 ? Tone.good : Tone.plain,
        ),
        const SizedBox(height: 8),
        Group(
          children: [
            for (final t in day.rows)
              ItemRow(
                icon: entryIcon(t),
                title: (t['label'] ?? '').toString(),
                sub: entrySubtitle(context.ledger.data, t),
                amount: formatMoney(signedAmount(t)),
                tone: _toneFor(t),
                // Tappable at last. Until this, a mistyped entry could only
                // be fixed by restoring a backup, and the parser guesses, so
                // wrong entries are a normal event rather than a rare one.
                onTap: () => context.push(
                  '/entry/${Uri.encodeComponent((t['id'] ?? '').toString())}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    ];
  }
}

/// One day's worth of entries, and what they came to.
class LedgerDay {
  const LedgerDay(this.date, this.rows, this.total, this.counts);
  final String date;
  final List<Map<String, dynamic>> rows;

  /// Signed, so a day with income and spending nets out the way a person
  /// would add it up themselves. Transfers and adjustments are NOT in it: see
  /// the note on _sum.
  final double total;

  /// Whether [total] means anything on this day. False for a day made only of
  /// transfers, where printing a zero would claim the day was neutral rather
  /// than saying it had no spending in it.
  final bool counts;
}

/// Group the ledger by stored date, newest day first.
///
/// Pure and top level so a test can call it without pumping a widget: the
/// grouping is the part with a rule in it, and the widget above is just paint.
List<LedgerDay> groupByDay(Map<String, dynamic> state) {
  final txs = (state['transactions'] as List? ?? const [])
      .whereType<Map>()
      .map((t) => t.cast<String, dynamic>())
      .toList();

  final byDate = <String, List<Map<String, dynamic>>>{};
  for (final t in txs) {
    final d = (t['date'] ?? '').toString();
    if (d.isEmpty) continue;
    byDate.putIfAbsent(d, () => []).add(t);
  }

  // Stored dates are yyyy-mm-dd, so a string sort IS a date sort. That is a
  // property of the format rather than luck, and it is why the v12 shape uses
  // it.
  final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

  return [
    for (final d in dates)
      LedgerDay(
        d,
        byDate[d]!.reversed.toList(),
        _sum(byDate[d]!),
        _hasCountableRows(byDate[d]!),
      ),
  ];
}

/// What a day did to the founder's money.
///
/// TRANSFERS ARE EXCLUDED, and that is the whole of this function. Moving five
/// thousand pesos from BPI to GCash is not five thousand pesos gone: the
/// founder has exactly as much money after it as before. Counting it made
/// Sep 13 read "-P5,100" on a day that actually spent P100, which is a screen
/// telling somebody they are fifty times worse off than they are.
///
/// The row for that transfer still shows its own movement, because THAT
/// account really did fall by five thousand. A row is about one account; a day
/// total is about the person. Those are different questions and the same
/// number cannot answer both.
///
/// Adjustments are excluded for the same reason: they reconcile a balance to
/// reality rather than recording money going anywhere.
double _sum(List<Map<String, dynamic>> rows) {
  var total = 0.0;
  for (final t in rows) {
    if (t['type'] == 'transfer' || t['type'] == 'adjustment') continue;
    total += signedAmount(t);
  }
  return total;
}

/// Did this day contain anything that counts toward its total?
///
/// A day of nothing but transfers has a total of zero, and printing "P0" there
/// would claim the day was neutral rather than saying it had no spending in
/// it at all.
bool _hasCountableRows(List<Map<String, dynamic>> rows) =>
    rows.any((t) => t['type'] != 'transfer' && t['type'] != 'adjustment');

/// What this entry did to the money, with its sign.
///
/// [balanceSign] is the golden-locked rule for which way a type moves a
/// balance, so the Ledger cannot disagree with the account screen about
/// whether something was a credit or a debit.
double signedAmount(Map<String, dynamic> t) =>
    balanceSign(t) * amountOf(t['amount']);

Tone _toneFor(Map<String, dynamic> t) =>
    signedAmount(t) > 0 ? Tone.good : Tone.plain;

// The icon and the caption now live in entry_presentation.dart, shared with
// Home's "Latest", which draws the same row from the same stored entry.
