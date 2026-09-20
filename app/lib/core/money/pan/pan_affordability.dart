/// "Can I afford this?", answered from the ledger rather than from a mood.
///
/// Ported in intent from section 1 of src/utils/panAiEngine.ts. The
/// arithmetic is the prototype's, the sentences are not: its version tells
/// the reader to hold off until payday, which is an instruction about their
/// money, and this one says what the figures become and stops there.
///
/// The one real change to the MATH is the bills check. The prototype compares
/// a purchase against Safe to Spend alone, and Safe to Spend already sets
/// money aside for bills, so a purchase that eats the reserve looked fine.
/// This version names what is due before payday, because "you can afford it"
/// and "your electricity is due on Friday" are the same answer.
library;

import '../../../models/models.dart';
import 'pan_context.dart';

/// How a purchase lands. Three states, deliberately, because two is a yes and
/// a no, and the useful answer most of the time is "yes, and here is what it
/// costs you for the rest of the cycle".
enum Afford { comfortable, tight, overBuffer }

class AffordVerdict {
  const AffordVerdict({
    required this.amount,
    required this.status,
    required this.safeToSpendNow,
    required this.safeToSpendAfter,
    required this.dailyPaceNow,
    required this.dailyPaceAfter,
    required this.daysToPayday,
    required this.shareOfBuffer,
    required this.billsBeforePayday,
    required this.billsDueBeforePayday,
  });

  final double amount;
  final Afford status;

  final double safeToSpendNow;

  /// Can be NEGATIVE, and is kept negative on purpose. The size of the hole
  /// is the answer; clamping it to zero was the prototype's habit and it
  /// turns "you are 1,400 short" into "you have nothing left", which reads
  /// like the same thing and is not.
  final double safeToSpendAfter;

  final double dailyPaceNow;
  final double dailyPaceAfter;
  final int daysToPayday;

  /// What fraction of the remaining buffer this purchase uses, 0 to 1 or
  /// more. Null when there is no buffer to take a share of.
  final double? shareOfBuffer;

  final double billsBeforePayday;
  final List<BillItem> billsDueBeforePayday;

  bool get paydayKnown => daysToPayday > 0;
}

/// A day below this is the point at which a person is counting coins for
/// meals and fares. It is a rule of thumb and is named as one wherever it is
/// shown, never as a threshold anybody official set.
const double tightDailyPace = 150;

AffordVerdict judgeAffordability(double amount, PanFacts facts) {
  final int days = facts.payday.daysToPayday;
  final double after = facts.safeToSpendUntilPayday - amount;

  // Divide by the real number of days when there is one. With no payday set,
  // a daily pace is arithmetic on a date nobody gave us, so it stays at zero
  // and the sentence built from this says the cycle is not set yet.
  final double paceAfter = days > 0 ? after / days : 0;

  final List<BillItem> due = _billsBeforePayday(facts);
  final double dueTotal = due.fold(0, (double s, BillItem b) => s + b.amount);

  Afford status;
  if (after < 0) {
    status = Afford.overBuffer;
  } else if (days > 0 && paceAfter < tightDailyPace) {
    status = Afford.tight;
  } else if (days <= 0 && amount > facts.safeToSpendUntilPayday * 0.5) {
    // No payday set, so there is no pace to judge. Half the buffer in one
    // purchase is still worth calling tight rather than waving through.
    status = Afford.tight;
  } else {
    status = Afford.comfortable;
  }

  return AffordVerdict(
    amount: amount,
    status: status,
    safeToSpendNow: facts.safeToSpendUntilPayday,
    safeToSpendAfter: after,
    dailyPaceNow: facts.safeToSpendPerDay,
    dailyPaceAfter: paceAfter < 0 ? 0 : paceAfter,
    daysToPayday: days,
    shareOfBuffer: facts.safeToSpendUntilPayday > 0
        ? amount / facts.safeToSpendUntilPayday
        : null,
    billsBeforePayday: dueTotal,
    billsDueBeforePayday: due,
  );
}

/// Unpaid bills falling between today and the next payday.
///
/// An empty list when the payday is unset, rather than every bill ever
/// recorded: without a horizon there is nothing for "before payday" to mean,
/// and listing them all would present a year of bills as this fortnight's.
List<BillItem> _billsBeforePayday(PanFacts facts) {
  final int days = facts.payday.daysToPayday;
  if (days <= 0) return const <BillItem>[];

  final DateTime horizon = DateTime(
    facts.now.year,
    facts.now.month,
    facts.now.day,
  ).add(Duration(days: days));

  final List<BillItem> out = <BillItem>[];
  for (final BillItem b in facts.bills) {
    if (b.isPaid) continue;
    final DateTime? d = DateTime.tryParse(b.dueDate);
    if (d == null) continue;
    final DateTime day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(
      DateTime(facts.now.year, facts.now.month, facts.now.day),
    )) {
      continue;
    }
    if (day.isAfter(horizon)) continue;
    out.add(b);
  }
  out.sort((BillItem a, BillItem b) => a.dueDate.compareTo(b.dueDate));
  return out;
}
