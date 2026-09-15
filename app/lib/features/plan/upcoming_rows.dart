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
import '../../core/money/schedule.dart'
    show hasExplicitPaydaySchedule, nextPayday;
import '../../core/money/timeline.dart' show sweldoTimeline;
import '../../core/state/visibility.dart' show spendableOnly;

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
    required this.firstNegativeDate,
    required this.horizonEnd,
    required this.todayIso,
    required this.anyIncome,
  });

  final List<UpcomingDay> days;
  final int horizonDays;

  /// The last day of the window, as an ISO date.
  ///
  /// Carried rather than derived in the widget from `days.last.date`, which is
  /// right today only because the last day happens to carry a row. The moment
  /// the window ends on a quiet day it would silently name the wrong date.
  final String horizonEnd;

  /// The lowest the projected balance gets inside the window, and when.
  ///
  /// This is the whole reason the screen is a projection and not a calendar. A
  /// list of dates tells you what is coming; the low point tells you whether
  /// you make it.
  final double lowest;
  final String lowestDate;
  final bool goesNegative;

  /// The day the balance FIRST goes below zero, which is not the same day as
  /// [lowestDate] and is the one a person has to act before.
  ///
  /// Dip under on the 13th, keep sinking to the minimum on the 25th, and a
  /// screen that says "your money runs out around the 25th" is twelve days
  /// late. "Around" does not cover twelve days. The first version of this
  /// screen made exactly that mistake, with the right value sitting unread in
  /// the engine's own return map.
  final String firstNegativeDate;

  /// Today, in the engine's format, so the hero can tell "you go below zero on
  /// Sep 11" from "you are already below zero" without reaching for a clock of
  /// its own. `timeline.dart` sets [firstNegativeDate] to today when the
  /// starting balance is already negative.
  final String todayIso;

  /// Whether ANY money comes in across the whole window.
  ///
  /// The payday copy needs this because the per-day answer cannot carry the
  /// claim it was making. A recurring row has one `dayOfMonth` and a
  /// semimonthly schedule has two paydays, so "no salary set up yet" appeared
  /// on half of every semimonthly earner's payday rows with their salary
  /// printed two rows above it.
  final bool anyIncome;

  bool get isEmpty => days.isEmpty;

  /// Everything due to go OUT across the window.
  ///
  /// Summed from the days already built, so the list underneath the hero
  /// always adds up to the figure above it. Note the wording it earns on
  /// screen: "due to go out", never "goes out". `timeline.dart` counts a debt
  /// cycle while the balance is above zero even if the user already paid early,
  /// because debts carry no per-cycle paid marker. That overstatement is
  /// correct and safe for a projection and would be simply wrong as a claim
  /// about what left the account.
  double get totalOut => days.fold(0.0, (sum, d) => sum + d.moneyOut);
}

/// How many days out to look: to the payday AFTER the next one.
///
/// Falls back to 30 when there is no usable schedule, rather than to zero.
/// Zero would render an empty screen on a ledger that has bills in it, which
/// reads as "nothing is coming" rather than "we do not know your payday", and
/// those are opposite statements.
int upcomingHorizonDays(Map<String, dynamic> data, DateTime ref) {
  final today = DateTime(ref.year, ref.month, ref.day);

  // NO SCHEDULE, NO GUESSED HORIZON. `normalizeSchedule` invents
  // {semimonthly, [15, 31]} when handed null, so calling nextPayday without
  // this check produces a window measured from a payday the user never
  // described. The kicker then reads "LOWEST IN THE NEXT 19 DAYS" where the 19
  // came from an invention, and `_paydaysInWindow` correctly refuses to draw
  // any payday row that would explain it. Home goes out of its way never to let
  // a guessed payday reach the user (`FinancialState.cycle.explicit`) and this
  // screen has to hold the same line.
  if (!hasExplicitPaydaySchedule(data)) return 30;

  final schedule = (data['settings'] as Map)['paydaySchedule'];

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

  // FILTERED, for the same reason Home's safe to spend is filtered, and this
  // line is the fix for a Home versus Plan contradiction that the hidden
  // accounts feature reintroduced within a day of being written.
  //
  // `sweldoTimeline` seeds its running balance from `_liquidNow(data['accounts'])`.
  // On the raw ledger that sum includes money the user hid, and money they
  // said belongs to somebody else, while Home's figure does not. Measured on
  // the lived-in ledger with one e-wallet marked not mine: Home said the
  // available figure was MINUS 2,144 and "your bills before payday come to
  // more than this", and Plan said the lowest point in the next 19 days was
  // 6,266.50 and "this is as low as it gets". One ledger, one moment, opposite
  // answers to "do I make it", with a paluwagan pot doing the talking.
  //
  // `spendableOnly` touches `accounts` and nothing else, so the timeline's
  // events, its bills and its dues are all unchanged: a bill you hid is still
  // drawn on the day it falls.
  final t = sweldoTimeline(spendableOnly(data), ref, horizonDays: horizon);

  final engineDays = [
    for (final raw in (t['days'] is List ? t['days'] as List : const []))
      if (raw is Map) raw.cast<String, dynamic>(),
  ];

  // THE LOW POINT IS DERIVED FROM THE DAY-END BALANCES, not read from the
  // engine's `lowest`, and that is a fix rather than a preference.
  //
  // `sweldoTimeline` seeds `lowest = start` and `lowestDate = today` BEFORE
  // the loop applies today's events, and only replaces them on a strictly
  // lower day-end balance. So on any day whose net movement is positive, the
  // hero reported the OPENING balance against today's date: a figure that
  // appears on no row in the list underneath it. Measured on payday with the
  // salary landing, the hero said 9,660.50 and the row for the same named day
  // said 24,960.50. One ledger, one named day, two numbers, which is exactly
  // the contradiction FinancialState exists to prevent.
  //
  // Every row shows its day-END balance, so taking the minimum of those is the
  // only definition that can never disagree with the list.
  var lowestBalance = 0.0;
  var lowestOn = '';
  for (var i = 0; i < engineDays.length; i++) {
    final b = amountOf(engineDays[i]['balance']);
    if (i == 0 || b < lowestBalance) {
      lowestBalance = b;
      lowestOn = (engineDays[i]['date'] ?? '').toString();
    }
  }

  // Does ANY income land in this window. Used by the payday copy, which used
  // to make an account-wide claim ("no salary set up yet") from a per-DAY
  // check. A recurring row carries one dayOfMonth and a semimonthly schedule
  // has two paydays, so every semimonthly earner saw that sentence on half
  // their payday rows with their salary printed two rows above it.
  final anyIncome = engineDays.any(
    (d) => (d['events'] is List ? d['events'] as List : const []).any(
      (e) => e is Map && (e['kind'] == 'income' || e['kind'] == 'scenarioIn'),
    ),
  );

  final days = <UpcomingDay>[];
  for (final d in engineDays) {
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
    //
    // The LOW POINT earns one too, even on a quiet day. The hero names that
    // date, and a hero naming a day the list does not contain is the same
    // contradiction in a different shape.
    final isLowest = (d['date'] ?? '').toString() == lowestOn;
    if (events.isEmpty && !isPayday && !isLowest) continue;

    days.add(
      UpcomingDay(
        date: (d['date'] ?? '').toString(),
        events: events,
        balanceAfter: amountOf(d['balance']),
        isPayday: isPayday,
      ),
    );
  }

  final today = DateTime(ref.year, ref.month, ref.day);
  final end = DateTime(today.year, today.month, today.day + horizon);

  return Upcoming(
    days: days,
    horizonDays: horizon,
    horizonEnd: _iso(end),
    lowest: lowestBalance,
    lowestDate: lowestOn,
    anyIncome: anyIncome,
    goesNegative: t['anyNegative'] == true,
    firstNegativeDate: (t['firstNegativeDate'] ?? '').toString(),
    todayIso: _iso(today),
  );
}

/// The engine's own date format, so a date never crosses this file as anything
/// else.
String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
