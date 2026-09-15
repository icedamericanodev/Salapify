// The bills whose day has arrived, waiting for you to say they happened.
//
// FOUNDER DECISION, 2026-09-15: "Ask me first, then post." The shipped app
// posts a recurring bill on its own, silently, the moment the day arrives. That
// is proven and it has one honest cost: if the rent posts on the 5th and you
// actually pay on the 10th, your balance is wrong for five days and an entry
// you never typed is sitting in your ledger. The founder chose the other trade,
// one tap per bill per month, and nothing enters the ledger unseen.
//
// THAT CHOICE ALSO DISSOLVED THE RISK THAT MADE THIS FOUNDER-GATED. Automatic
// posting needs `stampRecurringOnRestore` wired beside it, or restoring a
// backup can re-post a bill the app had already posted. With confirmation there
// is nothing to guard: a restored bill with no stamp simply shows up as
// pending, and the person decides. So this file wires neither, deliberately.
//
// NOTHING HERE RESTATES THE DUE RULE. `postDueRecurring` in core/money is
// golden locked to the shipped app and owns every part of it: the month key,
// the clamp of a 31st bill onto a short February, the stamp comparison, and the
// account movement. This file asks that function the question instead of
// answering it, by handing it a ledger whose recurring list holds ONE row and
// reading what comes back. The same shape `visibility.dart` uses to reach a
// figure by removing rows rather than by subtracting from an answer.
import '../../core/money/recurring.dart' show postDueRecurring;

/// One bill waiting to be confirmed, and the date the entry will carry.
///
/// The date is the engine's, read out of the transaction a probe post actually
/// produced, never recomputed here. It is not today's date and it is not a
/// plain restatement of `dayOfMonth` either: a bill on the 31st is CLAMPED onto
/// the last day of a short month, and that rule lives in `recurring.dart`.
/// Screens need it because the entry lands on that day rather than at the top
/// of the ledger, so somebody who taps "I paid it" and looks at today will not
/// find it.
typedef PendingBill = ({Map<String, dynamic> row, String date});

/// Every recurring row `postDueRecurring` would post right now, with the date
/// each one would be filed under.
///
/// The row is the stored map itself, so a caller reads the label, the amount
/// and the type without this file inventing a view model for three fields the
/// screen already knows how to draw.
List<PendingBill> pendingBills(Map<String, dynamic> data, DateTime now) => [
  for (final row in _recurring(data))
    if (_probe(data, row, now) case final String date) (row: row, date: date),
];

/// Post exactly ONE pending bill, returning a new ledger.
///
/// Returns the input map UNCHANGED, and identical, when that id is not pending,
/// so a double tap or a stale screen cannot post a bill twice. The engine's own
/// stamp already makes that impossible; this is the cheaper guard in front of
/// it, and it means the store can skip a redundant write.
///
/// [nextId] mints the transaction id. At runtime the store passes its real
/// genId; a test passes a deterministic stub.
Map<String, dynamic> postOneBill(
  Map<String, dynamic> data,
  String id,
  DateTime now,
  String Function() nextId,
) {
  final all = _recurring(data);
  final one = [
    for (final r in all)
      if (r['id'] == id) r,
  ];
  if (one.isEmpty) return data;

  // The engine sees a ledger with one recurring row, so it can only ever post
  // that one. Its transactions and accounts are the REAL lists, untouched by
  // the filter, so the entry it appends and the balance it moves are exactly
  // what it would have done on its own.
  final asked = {...data, 'recurring': one};
  final posted = postDueRecurring(asked, now, nextId);

  // `postDueRecurring` returns its INPUT map when nothing is due, which is a
  // guarantee of the function rather than a guess about it: its first branch is
  // a bare `return data`. So identity is the reliable test for "did anything
  // happen", and it costs nothing.
  if (identical(posted, asked)) return data;

  // Merge the one stamped row back into the full list, in place, so the order
  // the user arranged is preserved and no other row's stamp can be disturbed.
  final stamped = _recurring(posted).first;
  return {
    ...posted,
    'recurring': [
      for (final r in all)
        if (r['id'] == id) stamped else r,
    ],
  };
}

/// Ask the engine whether it would post this row, and on what date.
///
/// Null means it would not. The probe mints an id it throws away, which is
/// harmless and is the idiom `recordNetWorthSnapshot` already names in
/// core/money/net_worth_history.dart. The alternative is copying `isDue` and
/// the short-month clamp out of the engine into a screen file, where they would
/// drift the first time February is fixed in one place only.
String? _probe(
  Map<String, dynamic> data,
  Map<String, dynamic> row,
  DateTime now,
) {
  final asked = {
    ...data,
    'recurring': [row],
    // The probe reads the transaction the engine APPENDS, so it starts from an
    // empty list and the new one is the only one there. Starting from the real
    // list would mean finding it by the id the probe minted, which works and is
    // one more thing to keep true.
    'transactions': const [],
  };
  final posted = postDueRecurring(asked, now, _probeId);
  if (identical(posted, asked)) return null;
  final made = posted['transactions'];
  if (made is! List || made.isEmpty) return null;
  final tx = made.first;
  return tx is Map ? (tx['date'] ?? '').toString() : null;
}

String _probeId() => 'probe';

List<Map<String, dynamic>> _recurring(Map<String, dynamic> data) => [
  for (final r
      in (data['recurring'] is List ? data['recurring'] as List : const []))
    if (r is Map) r.cast<String, dynamic>(),
];
