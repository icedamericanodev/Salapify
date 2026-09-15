// What is coming, day by day, out to the payday after next.
//
// 04-screens.md: "Rows from today to the payday after next, with date captions;
// payday rows with their amount in green. This is the Sweldo Timeline as a
// list, the rail as a drawing."
//
// So this invents nothing and computes nothing. It calls the golden locked
// `sweldoTimeline`, which already knows every hard part: every recurring
// occurrence inside the window with the day clamped to each month's real
// length, a bill skipped when its month is already posted, debt minimums on
// bank-adjusted dates (a weekend or a PH holiday pushes payment to the next
// banking day), and the running balance after each event with money in ordered
// before money out within a day. All this file does is pick the horizon and
// drop the days where nothing happens.
//
// WHY TWO PAYDAYS AND NOT THIRTY DAYS. A semimonthly earner does not live in
// months, they live from sweldo to sweldo, and the question this screen answers
// is "does the money I am about to be paid cover what is coming before the one
// after it". A fixed thirty day window cuts that in half for anyone paid on the
// 15th and the 30th, and a calendar month cuts it somewhere different every
// month. Home already answers the nearer question, what is due before THIS
// payday, so a horizon that stopped there would just be Home again.
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/schedule.dart' show nextPayday;
import '../../core/money/timeline.dart' show sweldoTimeline;

/// One thing happening on one day.
class UpcomingEvent {
  const UpcomingEvent({
    required this.label,
    required this.amount,
    required this.kind,
  });

  final String label;
  final double amount;

  /// What the engine called it: `income`, `bill`, `debt`, or a scenario kind.
  /// Only the DIRECTION is read here, never the wording, because the engine
  /// owns these strings and a screen that string-matches them breaks silently
  /// when one is renamed.
  final String kind;

  /// Money coming in, rather than going out.
  ///
  /// The same test the engine itself applies when it decides which side of the
  /// day a row falls on (`timeline.dart`, the `isIn` in `add`). Written once
  /// here so the list and the engine cannot drift into disagreeing about which
  /// way a peso moved.
  bool get isIncome => kind == 'income' || kind == 'scenarioIn';
}

/// One day with something on it, and what the money looks like afterwards.
class UpcomingDay {
  const UpcomingDay({
    required this.date,
    required this.events,
    required this.balanceAfter,
    required this.isPayday,
  });

  /// ISO yyyy-mm-dd, the engine's own format.
  final String date;
  final List<UpcomingEvent> events;

  /// The projected liquid balance at the end of this day.
  final double balanceAfter;
  final bool isPayday;

  double get moneyIn => [
    for (final e in events)
      if (e.isIncome) e.amount,
  ].fold(0.0, (a, b) => a + b);

  double get moneyOut => [
    for (final e in events)
      if (!e.isIncome) e.amount,
  ].fold(0.0, (a, b) => a + b);
}

/// Everything between now and the payday after next, worst day named.
class Upcoming {
  const Upcoming({
    required this.days,
    required this.horizonDays,
    required this.lowest,
    required this.lowestDate,
    required this.goesNegative,
  });

  final List<UpcomingDay> days;
  final int horizonDays;

  /// The lowest the projected balance gets inside the window, and when.
  ///
  /// This is the whole reason the screen is a projection and not a calendar. A
  /// list of dates tells you what is coming; the low point tells you whether
  /// you make it.
  final double lowest;
  final String lowestDate;
  final bool goesNegative;

  bool get isEmpty => days.isEmpty;
}

/// How many days out to look: to the payday AFTER the next one.
///
/// Falls back to 30 when there is no usable schedule, rather than to zero.
/// Zero would render an empty screen on a ledger that has bills in it, which
/// reads as "nothing is coming" rather than "we do not know your payday", and
/// those are opposite statements.
int upcomingHorizonDays(Map<String, dynamic> data, DateTime ref) {
  final today = DateTime(ref.year, ref.month, ref.day);
  final schedule = data['settings'] is Map
      ? (data['settings'] as Map)['paydaySchedule']
      : null;

  var first = nextPayday(today, schedule);
  // Payday today is the START of a cycle, not the end of one. Home's
  // `upcomingCommitments` makes the same call for the same reason, and the two
  // screens naming different paydays on the same morning is exactly the class
  // of contradiction this app has already had to fix once.
  if (!first.isAfter(today)) {
    first = nextPayday(
      DateTime(today.year, today.month, today.day + 1),
      schedule,
    );
  }
  final second = nextPayday(
    DateTime(first.year, first.month, first.day + 1),
    schedule,
  );

  final days = second.difference(today).inDays;
  return days > 0 ? days : 30;
}

/// The list the Upcoming segment draws.
Upcoming upcomingFrom(Map<String, dynamic> data, DateTime ref) {
  final horizon = upcomingHorizonDays(data, ref);
  final t = sweldoTimeline(data, ref, horizonDays: horizon);

  final days = <UpcomingDay>[];
  for (final raw in (t['days'] is List ? t['days'] as List : const [])) {
    if (raw is! Map) continue;
    final d = raw.cast<String, dynamic>();
    final events = [
      for (final e in (d['events'] is List ? d['events'] as List : const []))
        if (e is Map)
          UpcomingEvent(
            label: (e['label'] ?? '').toString(),
            amount: amountOf(e['amount']),
            kind: (e['kind'] ?? '').toString(),
          ),
    ];
    final isPayday = d['isPayday'] == true;

    // A day with nothing on it is not a row. Thirty empty rows between two
    // bills is a calendar, and a calendar is what the user already has on
    // their phone. A payday with no recurring income attached still earns a
    // row, because the DATE is the information.
    if (events.isEmpty && !isPayday) continue;

    days.add(
      UpcomingDay(
        date: (d['date'] ?? '').toString(),
        events: events,
        balanceAfter: amountOf(d['balance']),
        isPayday: isPayday,
      ),
    );
  }

  final lowest = t['lowest'] is Map
      ? (t['lowest'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};

  return Upcoming(
    days: days,
    horizonDays: horizon,
    lowest: amountOf(lowest['balance']),
    lowestDate: (lowest['date'] ?? '').toString(),
    goesNegative: t['anyNegative'] == true,
  );
}
