/// When Home shows the Sweldo Day card (D31, "a Sweldo Day card").
///
/// Payday is the one moment a twice-a-month earner has money that is not yet
/// spoken for, and "pay yourself first" only works if it happens then. The
/// card asks for one move: money into an account marked Set aside, which is
/// the only kind of saving that changes Safe to Spend (an account's purpose
/// takes it out of the headline; a goal contribution moves no balance at all).
///
/// It stores nothing. It shows on the payday and the day after (weekly pay:
/// the payday only, or it would be up two days in every seven), and it goes
/// away on its own once a move into a Set aside account is dated on or after
/// that payday. That transfer is the "done" signal, read from the ledger,
/// because a stored "dismissed" flag would be a second record of something
/// the ledger already knows.
///
/// Never for "No fixed payday" (there is no payday to ritualise; Home asks
/// for the next date instead) and never with no payday set.
library;

import '../../models/models.dart';
import 'payday_schedule.dart';

/// The payday the card is about, or null when the card should not show.
DateTime? sweldoDayFor({
  required PaydaySchedule? schedule,
  required DateTime now,
  required List<Transaction> transactions,
  required List<Account> accounts,
}) {
  if (schedule == null || schedule.kind == PaydayKind.lastUntil) return null;
  final PaydayPoints? points = schedule.pointsFrom(now);
  if (points == null) return null;

  final DateTime today = DateTime(now.year, now.month, now.day);
  final DateTime payday = points.last;
  final int since = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(payday.year, payday.month, payday.day)).inDays;
  final int window = schedule.kind == PaydayKind.weekly ? 0 : 1;
  if (since < 0 || since > window) return null;

  if (setAsideSince(payday, transactions, accounts)) return null;
  return payday;
}

/// Whether money has moved into a Set aside account on or after [payday].
/// A taken-back or excluded move does not count: it moved nothing.
bool setAsideSince(
  DateTime payday,
  List<Transaction> transactions,
  List<Account> accounts,
) {
  final Set<String> setAside = <String>{
    for (final Account a in accounts)
      if (a.purpose == AccountPurpose.protected) a.id,
  };
  if (setAside.isEmpty) return false;
  final String from = isoDateOf(payday);
  for (final Transaction t in transactions) {
    if (t.type != TransactionType.transfer || !t.countsTowardTotals) continue;
    if (!setAside.contains(t.toAccountId)) continue;
    if (t.date.compareTo(from) >= 0) return true;
  }
  return false;
}
