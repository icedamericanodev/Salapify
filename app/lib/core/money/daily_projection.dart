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
    this.overdueTotal = Money.zero,
    this.overdueCount = 0,
    this.beyondHorizonTotal = Money.zero,
    this.beyondHorizonCount = 0,
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

  /// Unpaid, dated, and already in the past.
  ///
  /// Excluding these from the day grid is deliberate: an overdue bill is a
  /// problem but it is not a FUTURE movement, and putting it on today claims
  /// money leaves today that may have left weeks ago. The first version of
  /// this engine made that decision and then said nothing, which is the same
  /// silent drop the undated bucket exists to prevent. On the shipped sample
  /// ledger it was hiding 8,840.
  final Money overdueTotal;
  final int overdueCount;

  /// Dated, not overdue, and past the end of the window.
  ///
  /// Also a deliberate exclusion that used to be silent. Worse than the
  /// overdue case, because an item the person entered INSIDE the window could
  /// leave it: a bill due on the last day that lands on a Saturday is shifted
  /// to the Monday and fell off the end, counted nowhere. The horizon is now
  /// judged on the date the person wrote, not the date the bank moves it.
  final Money beyondHorizonTotal;
  final int beyondHorizonCount;

  /// Every eligible peso, wherever it ended up.
  ///
  /// THE REAL FOOTING CHECK. The obvious one, opening plus every inflow less
  /// every outflow equals closing, is an identity: both sides are computed
  /// from the same accumulator loop, so it passes with every input list
  /// deleted. It restates the loop rather than testing it. This is the sum
  /// that can actually disagree with the ledger.
  Money get accountedOutflow {
    Money placed = Money.zero;
    for (final ProjectedDay d in days) {
      placed += d.moneyOut;
    }
    return placed + undatedTotal + overdueTotal + beyondHorizonTotal;
  }

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
  Money overdue = Money.zero;
  int overdueCount = 0;
  Money beyond = Money.zero;
  int beyondCount = 0;

  /// Put one movement on one day, given how many days away it is.
  void placeOn(String label, Money amount, int days, bool isIncome) {
    if (!amount.isPositive) return;

    // Already gone. A bill due last week that is still unpaid is a problem,
    // but it is not a FUTURE movement and putting it on today would claim
    // money leaves today that may have left already. COUNTED, not dropped.
    if (days < 0) {
      overdue += amount;
      overdueCount += 1;
      return;
    }

    // JUDGED ON THE DATE THE PERSON WROTE, before any banking shift. A bill
    // due on the last day of the window that happens to fall on a Saturday
    // would otherwise be shifted past the end and vanish, counted nowhere, on
    // a window the person themselves chose.
    if (days > horizonDays) {
      beyond += amount;
      beyondCount += 1;
      return;
    }

    final DateTime due = today.add(Duration(days: days));

    // Income is not shifted. A salary credited on a Saturday is in the
    // account on Saturday; it is PAYMENTS that wait for a banking day.
    final BankingDay when = isIncome
        ? (date: due, moved: false, reason: '')
        : nextBankingDay(due);

    // The banking shift can push the last day or two of the window past its
    // end. That is kept rather than dropped: the person entered it inside the
    // window, so it belongs on the grid, and the grid runs to horizonDays.
    final int offset = when.date.difference(today).inDays.clamp(0, horizonDays);

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

  /// Put a dated obligation on the grid, EVERY TIME IT FALLS in the window.
  ///
  /// A forty-five day window is a month and a half, so a bill on the 15th
  /// falls twice in it and the payday rule that produced both falls three
  /// times. Until 2026-10-04 this placed each bill, each debt minimum and
  /// each instalment exactly ONCE while the payday walk looped, which made
  /// the projection optimistic by construction: roughly half a month of
  /// outgoings missing from the closing balance and from the shortfall date,
  /// every time, and always in the direction that tells somebody they are
  /// fine.
  ///
  /// THE RECURRENCE IS READ, NEVER ASSUMED. Only a day-of-month due date
  /// repeats, because only that shape says so: "15" and "10th of the month"
  /// name a day that comes round again, while "2026-10-15" and "Sep 25" name
  /// one day and are then over. [monthlyDayOf] is the single place that
  /// distinction lives, and it reads with the same pattern [daysUntil] does
  /// so the two can never disagree.
  void place(String label, Money amount, String? dueDate, bool isIncome) {
    if (!amount.isPositive) return;

    final int? days = daysUntil(dueDate, today);
    if (days == null) {
      // Could not be read as a date. Counted separately, never dropped.
      undated += amount;
      undatedCount += 1;
      return;
    }

    final int? repeatsOn = monthlyDayOf(dueDate);
    if (repeatsOn == null) {
      placeOn(label, amount, days, isIncome);
      return;
    }

    // Walk the month boundary rather than adding thirty days, so the 31st
    // lands on the last day of a short month exactly as `_onDayOf` does for
    // the first occurrence.
    DateTime when = today.add(Duration(days: days));
    // One more step than the window can hold, so the loop is bounded by
    // arithmetic rather than by a number somebody liked.
    for (int step = 0; step <= horizonDays ~/ 28 + 1; step++) {
      final int offset = when.difference(today).inDays;
      if (offset > horizonDays) break;
      placeOn(label, amount, offset, isIncome);
      final int lastDay = DateTime(when.year, when.month + 2, 0).day;
      when = DateTime(
        when.year,
        when.month + 1,
        repeatsOn < lastDay ? repeatsOn : lastDay,
      );
    }
  }

  for (final BillItem b in bills.where((BillItem b) => !b.isPaid)) {
    place(b.name, b.amount, b.dueDate, false);
  }

  for (final UpcomingItem u in upcoming.where((UpcomingItem u) => !u.isPaid)) {
    place(u.name, u.amount, u.dueDate, u.countsAsIncome);
  }

  // Payment plans ARE DATED, and this comment used to say the opposite.
  //
  // It read "instalments have no due date of their own in this model", which
  // was never true: `nextInstallmentDate` in reminders.dart derives one from
  // the start date, the instalments already paid and the frequency, and the
  // reminder engine has used it all along. So Salapify knew when the Home
  // Credit payment was due, told the person so in the tray, and the cash
  // projection over the same ledger called it undatable. That is exactly the
  // two-readings-of-one-ledger problem this file's own header warns about,
  // and it left the projected balance 2,000 too high for most of the window
  // on a plan the app could place to the day.
  //
  // Every instalment inside the window is placed, not just the next one, for
  // the reason written on `place` above. A plan whose start date cannot be
  // read is still counted as undated, which is the honest answer when the
  // app genuinely does not know.
  for (final InstallmentPlan i in installments.where(
    (InstallmentPlan i) => !i.isSettled,
  )) {
    Money left = i.runningBalance;
    bool placedAny = false;
    for (int skip = 0; left.isPositive; skip++) {
      final DateTime? due = nextInstallmentDate(i, skip: skip);
      if (due == null) break;
      final int offset = _midnight(due).difference(today).inDays;
      if (offset > horizonDays) break;
      final Money each = minMoney(i.installmentAmount, left);
      if (!each.isPositive) break;
      placeOn(i.name, each, offset, false);
      left -= each;
      placedAny = true;
    }
    if (!placedAny) {
      // Either the start date is unreadable or the next instalment falls
      // past the window. Counted, never dropped.
      final Money each = minMoney(i.installmentAmount, i.runningBalance);
      if (nextInstallmentDate(i) == null) {
        undated += each;
        undatedCount += 1;
      } else {
        beyond += each;
        beyondCount += 1;
      }
    }
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
  //
  // A MONTHLY MINIMUM IS MONTHLY, whatever shape the due date is written in.
  // `place` above only repeats a day-of-month date, which is right for a bill
  // (a bill written "2026-10-15" is one bill) and wrong here: the field is
  // called monthlyMinimum, so the date says WHEN IN THE MONTH and the name
  // says how often. The seed's Home Credit phone plan carries an ISO date
  // and was therefore counted once in a forty-five day window, which is half
  // of what it really costs over that window.
  //
  // BOUNDED BY WHAT IS ACTUALLY OWED, so a plan with one instalment left is
  // placed once and not twice. Running past the balance would invent an
  // obligation, which is the same mistake as the eight percent rule P2.4
  // removed, just made with a calendar instead of a percentage.
  for (final Debt d in debts.where(
    (Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe,
  )) {
    final Money? min = d.monthlyMinimum;
    if (min == null) continue;

    final int? firstIn = daysUntil(d.dueDate, today);
    if (firstIn == null) {
      undated += min;
      undatedCount += 1;
      continue;
    }

    Money left = d.remaining;
    DateTime when = today.add(Duration(days: firstIn));
    for (int step = 0; left.isPositive; step++) {
      final int offset = when.difference(today).inDays;
      if (offset > horizonDays) {
        if (step == 0) {
          beyond += min;
          beyondCount += 1;
        }
        break;
      }
      final Money each = min > left ? left : min;
      placeOn(d.person, each, offset, false);
      left -= each;
      final int lastDay = DateTime(when.year, when.month + 2, 0).day;
      when = DateTime(
        when.year,
        when.month + 1,
        when.day < lastDay ? when.day : lastDay,
      );
    }
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
      // SIZED TO THE HORIZON, not to a number somebody liked. A bare 8
      // silently dropped a real payday: with a rule of the 5th, 10th, 15th,
      // 20th, 25th and 30th, which a commission earner genuinely has, the
      // walk stopped at offset 39 and never placed the one at 44. The loop
      // already has its true exit two lines down; this bound exists only so
      // a pathological rule cannot spin forever.
      for (int guard = 0; guard <= horizonDays + 2; guard++) {
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
    overdueTotal: overdue,
    overdueCount: overdueCount,
    beyondHorizonTotal: beyond,
    beyondHorizonCount: beyondCount,
  );
}
