/// Sweldo Runway: what the balance does, day by day, between now and payday.
///
/// EVERY OTHER FIGURE IN SALAPIFY IS AN AMOUNT. This one produces a DATE, and
/// that is the whole point of it: "tightest day, Friday 12 Oct, short 1,840"
/// is something a person can act on today, where "safe to spend 6,083" is
/// something they can only obey.
///
/// IT IS NOT A SECOND OPINION ABOUT SAFE TO SPEND, and the two must never be
/// merged. `computeSafeToSpend` answers "how much may I spend between now and
/// payday", over a window, from reserves. This answers "on which DAY do I run
/// out", over a calendar, from dated events. Two engines over one ledger is
/// exactly the Home-versus-Plan disagreement this project has been bitten by,
/// so the journey test asserts that every bill one of them names appears in
/// the other on the same date for the same peso.
library;

import '../../models/models.dart';
import 'accounts.dart';
import 'payday_schedule.dart';
import 'money.dart';
import 'ph_calendar.dart';
import 'reminders.dart';

/// One thing that moves money on one day.
class ProjectedEvent {
  const ProjectedEvent({
    required this.label,
    required this.amount,
    required this.isIncome,
    this.movedFrom,
    this.movedReason = '',
  });

  final String label;
  final Money amount;
  final bool isIncome;

  /// The date it was DUE, when that is not the date it actually moves.
  ///
  /// Banks do not move money on a weekend or a holiday, so a bill due on
  /// Sunday leaves on Monday. Keeping the original date means a screen can
  /// say "due Sunday, leaves Monday" rather than silently showing a date the
  /// person never wrote down.
  final DateTime? movedFrom;

  /// Why it moved, as a fragment that reads inside a sentence: "a Sunday",
  /// "Christmas Day".
  final String movedReason;

  bool get moved => movedFrom != null;
}

/// One day in the projection.
class ProjectedDay {
  const ProjectedDay({
    required this.date,
    required this.moneyIn,
    required this.moneyOut,
    required this.balanceAfter,
    required this.events,
  });

  final DateTime date;
  final Money moneyIn;
  final Money moneyOut;

  /// What is left at the END of this day.
  final Money balanceAfter;
  final List<ProjectedEvent> events;

  bool get isQuiet => events.isEmpty;
}

/// The whole answer.
class DailyProjection {
  const DailyProjection({
    required this.openingBalance,
    required this.days,
    required this.undatedTotal,
    required this.undatedCount,
  });

  /// Spendable cash at the start, NOT total cash.
  ///
  /// Money the person set aside is not available to cover Friday's bill,
  /// which is the whole of P2.3. Starting from total would make this engine
  /// disagree with Safe to Spend about the same money on the same screen.
  final Money openingBalance;

  final List<ProjectedDay> days;

  /// What could not be placed on a calendar, and how many items.
  ///
  /// RETURNED RATHER THAN DROPPED. Due dates are free text in this app, so
  /// some of them genuinely cannot be read. An app that silently leaves an
  /// undated bill out of a cash projection is worse than one that says it did,
  /// because the person reads a clean projection and believes it is complete.
  final Money undatedTotal;
  final int undatedCount;

  Money get closingBalance =>
      days.isEmpty ? openingBalance : days.last.balanceAfter;

  /// The day the balance is at its lowest, or null when nothing is projected.
  ProjectedDay? get tightestDay {
    if (days.isEmpty) return null;
    ProjectedDay worst = days.first;
    for (final ProjectedDay d in days) {
      if (d.balanceAfter < worst.balanceAfter) worst = d;
    }
    return worst;
  }

  /// The FIRST day the balance goes below zero, which is the one that matters.
  ///
  /// Not the same as [tightestDay]: the lowest point may come later, and by
  /// then the person has already bounced a payment. The first crossing is the
  /// day they have to act before.
  ProjectedDay? get firstShortfall {
    for (final ProjectedDay d in days) {
      if (d.balanceAfter.isNegative) return d;
    }
    return null;
  }

  bool get runsShort => firstShortfall != null;
}

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Project the balance forward, one day at a time.
///
/// [horizonDays] defaults to 45, which covers a full semi-monthly cycle and
/// the one after it with room to spare. It is a cap on work, not a claim
/// about the future.
DailyProjection projectDailyCash({
  required List<Account> accounts,
  required List<BillItem> bills,
  required List<UpcomingItem> upcoming,
  required List<InstallmentPlan> installments,
  required List<Debt> debts,
  required PaydayCycle payday,
  required DateTime now,
  int horizonDays = 45,
}) {
  final DateTime today = _midnight(now);

  // SPENDABLE, converted to pesos. Both halves matter: money set aside is not
  // available for Friday's bill, and a dollar account cannot be added to a
  // peso one. `accountsTotalPhp` is the one place that rule lives.
  final Money opening = Money.fromDouble(
    accountsTotalPhp(accounts.where((Account a) => a.isSpendable)),
  );

  final Map<int, List<ProjectedEvent>> byOffset = <int, List<ProjectedEvent>>{};
  Money undated = Money.zero;
  int undatedCount = 0;

  void place(String label, Money amount, String? dueDate, bool isIncome) {
    if (!amount.isPositive) return;

    final int? days = daysUntil(dueDate, today);
    if (days == null) {
      // Could not be read as a date. Counted separately, never dropped.
      undated += amount;
      undatedCount += 1;
      return;
    }
    // Already gone. A bill due last week that is still unpaid is a problem,
    // but it is not a FUTURE movement and putting it on today would claim
    // money leaves today that may have left already.
    if (days < 0) return;

    final DateTime due = today.add(Duration(days: days));

    // Income is not shifted. A salary credited on a Saturday is in the
    // account on Saturday; it is PAYMENTS that wait for a banking day.
    final BankingDay when = isIncome
        ? (date: due, moved: false, reason: '')
        : nextBankingDay(due);

    final int offset = when.date.difference(today).inDays;
    if (offset > horizonDays) return;

    byOffset
        .putIfAbsent(offset, () => <ProjectedEvent>[])
        .add(
          ProjectedEvent(
            label: label,
            amount: amount,
            isIncome: isIncome,
            movedFrom: when.moved ? due : null,
            movedReason: when.reason,
          ),
        );
  }

  for (final BillItem b in bills.where((BillItem b) => !b.isPaid)) {
    place(b.name, b.amount, b.dueDate, false);
  }

  for (final UpcomingItem u in upcoming.where((UpcomingItem u) => !u.isPaid)) {
    place(u.name, u.amount, u.dueDate, u.countsAsIncome);
  }

  // Instalments have no due date of their own in this model, so they are
  // counted as undated rather than guessed onto a day. Saying "I know you owe
  // this but not when" is honest; putting it on the 1st because that is
  // tidy is not.
  for (final InstallmentPlan i in installments.where(
    (InstallmentPlan i) => !i.isSettled,
  )) {
    undated += minMoney(i.installmentAmount, i.runningBalance);
    undatedCount += 1;
  }

  // Debt minimums ride on their own due date where the debt carries one.
  // P2.4 made these real figures rather than eight percent of a balance.
  // `iOwe` ONLY, and the filter is not decoration.
  //
  // The first version of this loop iterated every Debt, so a scheduled debt
  // owed TO the person reduced THEIR runway: money somebody else has to find
  // came off this person's balance. `monthlyDebtMinimums` in debt.dart has
  // filtered on direction all along, so the two readings of one ledger
  // disagreed, which is exactly what this file's own header warns about.
  //
  // The seed hid it completely, because both of its receivables are
  // `flexible` and `monthlyMinimum` returns null for those. It would have
  // surfaced the first time somebody recorded "Kuya Mark owes me 12,000 over
  // six instalments". Found by the money review, not by the suite.
  for (final Debt d in debts.where(
    (Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe,
  )) {
    final Money? min = d.monthlyMinimum;
    if (min == null) continue;
    place(d.person, min, d.dueDate, false);
  }

  // Payday, from the stored rule. NOTHING IS INVENTED: if the person has not
  // told Salapify when they are paid, no income appears, and the projection
  // simply runs down. A projection that invents a salary is the one mistake
  // that would make this feature dangerous.
  if (payday.isSet && payday.expectedIncome.isPositive) {
    void addPayday(int offset) {
      if (offset < 0 || offset > horizonDays) return;
      byOffset
          .putIfAbsent(offset, () => <ProjectedEvent>[])
          .add(
            ProjectedEvent(
              label: 'Payday',
              amount: payday.expectedIncome,
              isIncome: true,
            ),
          );
    }

    final PaydaySchedule schedule = PaydaySchedule(payday.paydayDays);
    if (schedule.isUsable) {
      // THE STORED RULE, WALKED FORWARD. An earlier draft of this stepped by
      // 15 days from the next payday, which quietly assumed everybody is paid
      // kinsenas and katapusan. That is the same sin as the eight percent
      // debt minimum P2.4 just removed: a plausible guess standing in for
      // something the app was actually told.
      DateTime cursor = today;
      for (int guard = 0; guard < 8; guard++) {
        final PaydayPoints? points = schedule.pointsFrom(cursor);
        if (points == null) break;
        final int offset = points.next.difference(today).inDays;
        if (offset > horizonDays) break;
        addPayday(offset);
        cursor = points.next;
      }
    } else {
      // No day-of-month rule is stored, so only the ONE payday the cycle
      // knows about is projected. Anything past it would be invented.
      addPayday(payday.daysToPayday);
    }
  }

  final List<ProjectedDay> days = <ProjectedDay>[];
  Money running = opening;
  for (int offset = 0; offset <= horizonDays; offset++) {
    final List<ProjectedEvent> events =
        byOffset[offset] ?? const <ProjectedEvent>[];
    Money inToday = Money.zero;
    Money outToday = Money.zero;
    for (final ProjectedEvent e in events) {
      if (e.isIncome) {
        inToday += e.amount;
      } else {
        outToday += e.amount;
      }
    }
    running = running + inToday - outToday;
    days.add(
      ProjectedDay(
        date: today.add(Duration(days: offset)),
        moneyIn: inToday,
        moneyOut: outToday,
        balanceAfter: running,
        events: events,
      ),
    );
  }

  return DailyProjection(
    openingBalance: opening,
    days: days,
    undatedTotal: undated,
    undatedCount: undatedCount,
  );
}
