// One financial truth, composed once, read by every screen.
//
// THE DEFECT THIS EXISTS TO MAKE IMPOSSIBLE. On 2026-09-14 Home said
// "₱1,566.63 a day until payday" and Plan said "₱697.73 a day for the 20 days
// left this month", on the same ledger, at the same moment. Both were
// individually correct: Home divided by days to the next PAYDAY, Plan divided
// by days to CALENDAR MONTH END. Two periods, two denominators, two numbers
// that can never agree, and no test caught it because neither was wrong on its
// own terms. The render harness photographed both and nobody noticed.
//
// The founder's Financial Operating System brief warns about exactly this in
// its section 5, in these words:
//
//     Dashboard = calculation A
//     Reports   = calculation B
//
// So this is the fix, and the rule that makes it hold is one sentence:
//
//     A SCREEN MAY NOT CALL A MONEY ENGINE DIRECTLY. It reads this.
//
// With that rule, "how many days are left" is defined in one place and two
// screens cannot disagree by construction rather than by vigilance. Vigilance
// is what failed.
//
// WHAT THIS IS NOT. It computes nothing. Every figure below comes out of
// `core/money`, which is byte identical to the shipped app's engine and locked
// by `check-engine-identical.sh`. This file composes and names; it must never
// become a second place where money is decided. If a figure is needed that no
// engine produces, the engine is where it goes, behind the golden vectors.
import '../money/budget.dart' show budgetSummary;
import '../money/commitments.dart' show safeToSpend;
import '../money/ledger.dart' show amountOf;
import '../money/schedule.dart'
    show hasExplicitPaydaySchedule, nextPayday, prevPayday;
import 'visibility.dart' show Excluded, spendableOnly;

/// The pay period the user is actually living in.
///
/// THE period. Not "the month", not "the month unless the screen prefers
/// otherwise". A Filipino semimonthly earner does not run out of money in month
/// four, they run out on the 27th, and every pace figure in the app has to
/// answer to the same span or it is answering a question nobody asked.
class Cycle {
  const Cycle({
    required this.start,
    required this.end,
    required this.daysLeft,
    required this.explicit,
  });

  /// The payday this cycle began on.
  final DateTime start;

  /// The payday it ends on, taken from the ENGINE's own answer rather than
  /// re-derived. On payday itself `nextPayday` returns today while the engine
  /// has already skipped to the next one, and re-deriving it put "payday on
  /// Tuesday" above "15 days to payday" on the same panel.
  final DateTime end;

  /// Days from today to [end], never below one. The engine floors it so a
  /// per-day figure cannot divide by zero.
  final int daysLeft;

  /// Whether the user actually SET a payday, as opposed to the engine falling
  /// back to 15/31 so a forecast has something to work with.
  ///
  /// `schedule.dart` is explicit that guessing for a forecast is harmless and
  /// guessing for a CLAIM is not, because "payday is Tuesday" is either true or
  /// a lie. Anything that states a date must check this first.
  final bool explicit;

  /// Whole days between the two paydays, at least one.
  int get span {
    final d = end.difference(start).inDays;
    return d <= 0 ? 1 : d;
  }

  /// How much of the cycle is gone, 0 to 1, for the rail.
  ///
  /// Zero on payday itself, never one: a span of zero is the moment a cycle
  /// BEGINS, and filling the bar there told somebody they had used up a cycle
  /// that had not started.
  double elapsedFraction(DateTime now) {
    final gone = now.difference(start).inDays;
    if (end.difference(start).inDays <= 0) return 0;
    return (gone / span).clamp(0.0, 1.0);
  }
}

/// Everything the screens are allowed to know about the user's money.
class FinancialState {
  const FinancialState({
    required this.now,
    required this.cycle,
    required this.liquid,
    required this.committed,
    required this.available,
    required this.perDay,
    required this.billCount,
    required this.budgetLimit,
    required this.budgetSpent,
    required this.budgetRemaining,
    required this.budgetOver,
    required this.excluded,
  });

  /// Composed from the locked engines, for one moment in time.
  ///
  /// [now] is passed rather than read so the render harness and the tests can
  /// pin it. A screen whose content depends on the date and reads the system
  /// clock cannot be tested on the day before payday, which is exactly the day
  /// it has to get right.
  factory FinancialState.of(Map<String, dynamic> data, DateTime now) {
    final schedule = data['settings'] is Map
        ? (data['settings'] as Map)['paydaySchedule']
        : null;
    // FILTERED, NOT ADJUSTED. Money the user hid, or declared is not theirs,
    // leaves safe to spend. That happens by removing those accounts and asking
    // the golden locked engine the same question, never by subtracting from
    // its answer: `perDay` is `available / daysLeft` with a silence rule in the
    // crunch case, and re-applying that here would make this file a second
    // place where money is decided, which the note at the top of it forbids.
    //
    // The BUDGET is deliberately not filtered. It is computed from
    // transactions, not from balances, and money already spent was spent
    // whatever the account is called today.
    final sts = safeToSpend(spendableOnly(data), now);
    final budget = budgetSummary(data, now);

    // The engine's OWN payday, not a second derivation of it.
    final end =
        DateTime.tryParse((sts['payday'] ?? '').toString()) ??
        nextPayday(now, schedule);

    return FinancialState(
      now: now,
      cycle: Cycle(
        start: prevPayday(now, schedule),
        end: end,
        daysLeft: sts['daysLeft'] as int,
        explicit: hasExplicitPaydaySchedule(data),
      ),
      liquid: amountOf(sts['liquid']),
      committed: amountOf(sts['committed']),
      available: amountOf(sts['available']),
      perDay: amountOf(sts['perDay']),
      billCount: sts['billCount'] as int,
      budgetLimit: amountOf(budget['limit']),
      budgetSpent: amountOf(budget['spent']),
      budgetRemaining: amountOf(budget['remaining']),
      budgetOver: budget['over'] == true,
      excluded: Excluded.of(data),
    );
  }

  final DateTime now;
  final Cycle cycle;

  /// Spendable cash. Savings are excluded by the engine on purpose: the whole
  /// point of a safe to spend figure is to protect them.
  final double liquid;

  /// Bills, debt minimums and dues falling inside this cycle.
  final double committed;

  /// [liquid] minus [committed]. The hero figure.
  final double available;

  /// [available] spread over [Cycle.daysLeft], or zero when there is nothing
  /// left to spread. The engine goes deliberately silent in the crunch case
  /// rather than stating a pace as a fact.
  final double perDay;

  final int billCount;

  /// The monthly budget, which is a DIFFERENT question from safe to spend and
  /// is kept as a monthly figure on purpose: people think in monthly rent and
  /// monthly salary, and `budgetSummary` is golden locked to a calendar month.
  ///
  /// What must never happen again is a SECOND per-day pace derived from it. The
  /// app has exactly one pacing number, [perDay], and it belongs to the cycle.
  final double budgetLimit;
  final double budgetSpent;
  final double budgetRemaining;
  final bool budgetOver;

  /// What was left OUT of [liquid] and [available], so a screen showing them
  /// can say so.
  ///
  /// It travels with the figures rather than being looked up beside them, and
  /// that is the whole reason it is here. `visibility.dart` states the rule,
  /// "every screen that subtracts one of these figures also renders the
  /// matching sentence", and Home broke it on the day the rule was written:
  /// safe to spend fell by 8,410.50 and the only sentence on the screen blamed
  /// the bills. Somebody who hid an account last month and forgot had no way
  /// to reconcile Home against their real balances.
  final Excluded excluded;

  bool get hasBudget => budgetLimit > 0;

  /// Whether the cycle's money is already overcommitted.
  bool get crunch => available <= 0;
}
