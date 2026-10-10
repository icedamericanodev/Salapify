/// What Safe to Spend holds back for bills: the built-in list AND the bills
/// the person adds on the Bills screen (founder decision D32, 2026-10-09).
///
/// The engine (safe_to_spend.dart) is locked to the prototype's vectors and
/// takes one list of [BillItem]. It reserved every unpaid BillItem and never
/// saw an [UpcomingItem], which is where every bill a person adds is kept.
/// In the ledger-reconciler's fixture 15,500 of bills due before payday was
/// reserved as 0. So the caller now hands the engine both, as one list, and
/// the engine is untouched.
///
/// ONCE, NEVER TWICE. Safe to Spend already holds back three other things
/// an added bill can be a second entry for: a built-in bill, a debt's
/// monthly minimum, and a payment plan's instalment. An added bill that is
/// [sameObligation] with any of them (exact amount, a shared word, and
/// within seven days when both dates can be read) is that same payment and
/// is not held back again. The rule is the "Counted twice" notice's own, so
/// the notice and the figure can never disagree about what "the same"
/// means. Each built-in bill absorbs at most one added bill.
///
/// Decided by MATCHING, never by the type picked on the Bills screen. This
/// skipped every "Debt" row on the belief that the debt already reserved
/// it, and nothing checked that a debt existed: a 5,000 card payment
/// scheduled with no debt behind it was held back by nothing. And a "Bill"
/// row for a debt that does exist was held back twice, once here and once as
/// the debt's minimum. Both found by the ledger-reconciler on 2026-10-10.
library;

import '../../models/models.dart';
import 'duplicate_obligations.dart';
import 'money.dart';
import 'reminders.dart';

/// Every unpaid bill, built-in or added, that is due on or before the next
/// payday, as one list for the engine. Paid built-in bills pass through
/// untouched, because the engine skips them and Pan reports them.
///
/// ONE WINDOW FOR BOTH LISTS (D33, 2026-10-10). The engine holds back every
/// built-in bill it is handed whatever its date, so this list is where the
/// date is applied. Before D33 it was applied to added bills only, and the
/// example's 8,500 tuition due October 5 was held back in a cycle ending
/// September 30 under the label "Upcoming bills before payday", while the
/// same bill typed on the Bills screen was not.
///
/// Overdue counts: it is owed now. A date nobody can read counts too,
/// because Salapify cannot tell it is NOT due before payday, and holding
/// back money for a real bill is the safe direction (a reserve that turns
/// out early costs a smaller figure for a day; a missed one costs a bill).
List<BillItem> billsToReserve({
  required List<BillItem> bills,
  required List<UpcomingItem> upcoming,
  required int daysToPayday,
  required DateTime now,
  List<Debt> debts = const <Debt>[],
  List<InstallmentPlan> installments = const <InstallmentPlan>[],
}) {
  // What the engine already holds back elsewhere, as (name, amount, days).
  // The SAME sets the engine reads: monthlyDebtMinimums and the unsettled
  // plans, so nothing is skipped here that is not reserved there.
  final List<(String, Money, int?)> elsewhere = <(String, Money, int?)>[
    for (final Debt d in debts)
      if (!d.isSettled &&
          d.direction == DebtDirection.iOwe &&
          d.monthlyMinimum != null)
        (d.person, d.monthlyMinimum!, daysUntil(d.dueDate, now)),
    for (final InstallmentPlan i in installments)
      if (!i.isSettled)
        (i.name, i.installmentAmount, _daysTo(nextInstallmentDate(i), now)),
  ];

  bool dueThisCycle(int? days) => days == null || days <= daysToPayday;

  final List<BillItem> unclaimed = bills
      .where((BillItem b) => !b.isPaid)
      .toList();
  // A built-in bill that absorbed its twin, under the twin's date.
  final Map<String, BillItem> redated = <String, BillItem>{};
  final List<BillItem> added = <BillItem>[];
  for (final UpcomingItem u in upcoming) {
    if (u.isPaid || u.countsAsIncome) continue;
    final int? days = daysUntil(u.dueDate, now);
    // WRITTEN AS A DATE. The Bills screen keeps what the person typed
    // ("Sep 18", "Sunday"), and Pan and the health check read a bill's
    // date with DateTime.tryParse, which returns null for both and then
    // skips the bill. Same bill, held back by Safe to Spend and missing
    // from Pan's "bills before payday": two readers, two answers. An
    // unreadable date keeps its label, since there is no date to write.
    final String? iso = days == null ? null : _iso(now, days);

    bool same(String name, Money amount, int? otherDays) => sameObligation(
      nameA: u.name,
      amountA: u.amount,
      daysA: days,
      nameB: name,
      amountB: amount,
      daysB: otherDays,
    );

    final int twin = unclaimed.indexWhere(
      (BillItem b) => same(b.name, b.amount, daysUntil(b.dueDate, now)),
    );
    if (twin >= 0) {
      // THE DATE THE PERSON CAN SEE WINS (D33). The example's Meralco is
      // September 15 on the built-in list, overdue, and Today on the Bills
      // screen; Pan and the health check skip an overdue bill, so keeping
      // the built-in date left a bill due today out of "before payday".
      final BillItem b = unclaimed.removeAt(twin);
      if (iso != null) {
        redated[b.id] = BillItem(
          id: b.id,
          name: b.name,
          amount: b.amount,
          dueDate: iso,
          isPaid: b.isPaid,
          isSample: b.isSample,
        );
      }
      continue;
    }
    if (elsewhere.any(((String, Money, int?) e) => same(e.$1, e.$2, e.$3))) {
      continue;
    }
    if (!dueThisCycle(days)) continue;
    added.add(
      BillItem(
        id: 'upcoming:${u.id}',
        name: u.name,
        amount: u.amount,
        dueDate: iso ?? u.dueDate,
        isSample: u.isSample,
      ),
    );
  }
  return <BillItem>[
    for (final BillItem b in bills)
      if (b.isPaid)
        b
      else if (dueThisCycle(daysUntil((redated[b.id] ?? b).dueDate, now)))
        redated[b.id] ?? b,
    ...added,
  ];
}

int? _daysTo(DateTime? when, DateTime now) => when == null
    ? null
    : DateTime(
        when.year,
        when.month,
        when.day,
      ).difference(DateTime(now.year, now.month, now.day)).inDays;

String _iso(DateTime now, int days) {
  final DateTime d = DateTime(now.year, now.month, now.day + days);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
