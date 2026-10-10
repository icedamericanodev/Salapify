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
/// ONCE, NEVER TWICE. A bill on both lists (the sample ledger has Meralco
/// and Spotify on both) is reserved once: an added bill with the SAME amount
/// to the centavo and a shared identifying word in its name as an unpaid
/// built-in bill is the same bill. The word rule is
/// [sharedIdentifyingWord], the one the "Counted twice" notice already
/// uses, so the two can never disagree about what "the same" means. Each
/// built-in bill absorbs at most one added bill.
library;

import '../../models/models.dart';
import 'duplicate_obligations.dart';
import 'reminders.dart';

/// Kinds that are a person's own outgoing bill. A payday is income, and a
/// `debt` row is a debt instalment, which Safe to Spend already reserves
/// through the debts themselves; reserving it here as well would count it
/// twice.
const Set<UpcomingItemType> _billKinds = <UpcomingItemType>{
  UpcomingItemType.bill,
  UpcomingItemType.subscription,
  UpcomingItemType.remittance,
  UpcomingItemType.rent,
  UpcomingItemType.insurance,
  UpcomingItemType.tuition,
  UpcomingItemType.government,
};

/// The built-in bills, plus every added bill that is unpaid, outgoing, and
/// due on or before the next payday, as one list for the engine.
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
}) {
  final List<BillItem> unclaimed = bills
      .where((BillItem b) => !b.isPaid)
      .toList();
  final List<BillItem> added = <BillItem>[];
  for (final UpcomingItem u in upcoming) {
    if (u.isPaid || u.countsAsIncome || !_billKinds.contains(u.type)) {
      continue;
    }
    final int? days = daysUntil(u.dueDate, now);
    if (days != null && days > daysToPayday) continue;

    final int twin = unclaimed.indexWhere(
      (BillItem b) =>
          b.amount == u.amount && sharedIdentifyingWord(b.name, u.name),
    );
    if (twin >= 0) {
      unclaimed.removeAt(twin);
      continue;
    }
    added.add(
      BillItem(
        id: 'upcoming:${u.id}',
        name: u.name,
        amount: u.amount,
        // WRITTEN AS A DATE. The Bills screen keeps what the person typed
        // ("Sep 18", "Sunday"), and Pan and the health check read a bill's
        // date with DateTime.tryParse, which returns null for both and then
        // skips the bill. Same bill, held back by Safe to Spend and missing
        // from Pan's "bills before payday": two readers, two answers. An
        // unreadable date keeps its label, since there is no date to write.
        dueDate: days == null ? u.dueDate : _iso(now, days),
        isSample: u.isSample,
      ),
    );
  }
  return <BillItem>[...bills, ...added];
}

String _iso(DateTime now, int days) {
  final DateTime d = DateTime(now.year, now.month, now.day + days);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}
