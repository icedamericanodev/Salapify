// The things that repeat: rent, Meralco, Spotify, and the sweldo.
//
// Plan > Upcoming already draws what is COMING, day by day, out to the payday
// after next. This file is the list of things that GENERATE it, which until
// now a person could neither see nor add.
//
// WHY THIS MATTERS MORE THAN IT LOOKS. `upcomingCommitments` reads
// `data['recurring']` to decide what is set aside before payday, and safe to
// spend is liquid MINUS that. With no way to add a recurring bill, every bill
// in the app had to arrive from a restored backup, so a new user's safe to
// spend counted their rent as spendable. The figure was not slightly off, it
// was flattering, and a flattering safe-to-spend is the one number in this app
// that can actively cost somebody money.
//
// This file derives and formats. `postDueRecurring`, `recurringSaveLastPosted`
// and `stampRecurringOnRestore` in core/money/recurring.dart are golden locked
// to the shipped app and own every rule about WHEN a thing posts.
import '../../core/money/format.dart' show formatMoney;
import '../../core/money/ledger.dart' show amountOf;

/// One repeating item, as the screen draws it.
class RecurringRow {
  const RecurringRow({
    required this.id,
    required this.label,
    required this.amount,
    required this.dayOfMonth,
    required this.income,
    required this.accountId,
    required this.lastPosted,
  });

  final String id;
  final String label;
  final double amount;

  /// 1 to 31. A day past the end of a short month is CLAMPED by the engine
  /// rather than skipped, so a 31st bill lands on the 28th in February. That
  /// rule lives in `recurring.dart` and is not repeated here.
  final int dayOfMonth;

  /// Money coming IN rather than going out. The sweldo is a recurring item.
  final bool income;

  /// Which account it moves. May be empty on a row from an older backup.
  final String accountId;

  /// The month key ('2026-09') this last posted in, or empty.
  final String lastPosted;

  /// Whether this month's occurrence is already accounted for.
  ///
  /// `upcomingCommitments` skips an item stamped for this month or later, so
  /// this is the same test that decides whether it is still counted against
  /// safe to spend.
  bool postedIn(DateTime now) {
    final key = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return lastPosted.isNotEmpty && lastPosted.compareTo(key) >= 0;
  }
}

/// Every repeating item, income first, then largest.
///
/// Income first because there are usually one or two of them and a dozen
/// bills, and burying the sweldo at the bottom of a list of things that take
/// money reads as a list of bad news. Within each group, largest first: the
/// rent is the one somebody is looking for.
List<RecurringRow> recurringRows(Map<String, dynamic> state) {
  final rows = <RecurringRow>[];
  for (final r
      in (state['recurring'] is List ? state['recurring'] as List : const [])) {
    if (r is! Map) continue;
    final row = r.cast<String, dynamic>();
    final day = amountOf(row['dayOfMonth']).round();
    rows.add(
      RecurringRow(
        id: (row['id'] ?? '').toString(),
        label: (row['label'] ?? 'Recurring').toString(),
        amount: amountOf(row['amount']),
        dayOfMonth: day < 1 ? 1 : (day > 31 ? 31 : day),
        income: row['type'] == 'income',
        accountId: (row['accountId'] ?? '').toString(),
        lastPosted: (row['lastPosted'] ?? '').toString(),
      ),
    );
  }

  rows.sort((a, b) {
    if (a.income != b.income) return a.income ? -1 : 1;
    final byAmount = b.amount.compareTo(a.amount);
    // Ties break on the id so the order is stable between builds, or two
    // equal bills swap places on every rebuild and the list looks like it is
    // twitching.
    return byAmount != 0 ? byAmount : a.id.compareTo(b.id);
  });
  return rows;
}

/// "the 3rd", as a day of the month.
///
/// Deliberately NOT a date. The stored value is a day number that repeats every
/// month, and printing it as a full date would invent a month the data never
/// said. The Accounts screen carries the same helper for a card's due day, for
/// exactly the same reason.
String ordinalDay(int day) {
  final suffix = (day % 100 >= 11 && day % 100 <= 13)
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return 'the $day$suffix';
}

/// The line under a repeating item's name.
///
/// It says whether this month is already dealt with, because that is the only
/// thing about the row a person cannot work out by looking at it, and it is
/// what decides whether the amount is still standing between them and their
/// safe to spend.
String recurringCaption(RecurringRow row, DateTime now) {
  final when = 'Every month on ${ordinalDay(row.dayOfMonth)}';
  if (row.postedIn(now)) {
    return row.income
        ? '$when · already in this month'
        : '$when · already counted this month';
  }
  return when;
}

/// What the section says above the list.
///
/// Two figures rather than a net, because "you are 34,500 ahead each month" is
/// a different and much weaker claim than "18,500 comes in and 3,394 is
/// committed". A net hides the size of the commitment, which is the thing
/// somebody is deciding about.
String recurringSummary(List<RecurringRow> rows) {
  if (rows.isEmpty) return '';
  final out = rows.where((r) => !r.income).fold(0.0, (t, r) => t + r.amount);
  final income = rows.where((r) => r.income).fold(0.0, (t, r) => t + r.amount);

  if (income > 0 && out > 0) {
    return '${formatMoney(income)} comes in and ${formatMoney(out)} goes out '
        'every month, before anything you choose to spend.';
  }
  if (out > 0) {
    return '${formatMoney(out)} goes out every month, before anything you '
        'choose to spend.';
  }
  return '${formatMoney(income)} comes in every month.';
}
