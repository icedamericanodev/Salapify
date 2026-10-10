/// One payment, written down twice.
///
/// WHY THIS EXISTS. Salapify keeps money going out in four registers, and
/// nothing stops the same real obligation living in two of them. The shipped
/// sample ledger does it twice over: the Home Credit phone plan is a Debt and
/// an Upcoming item, and Meralco is a Bill and an Upcoming item three days
/// apart. The projection counts both, so it takes 4,900 out for one 2,450
/// phone plan and says nothing.
///
/// IT FLAGS, IT NEVER DROPS, and that is the opposite of what the engine does
/// for income. The asymmetry has one stated reason: counting a BILL twice
/// tells somebody they are tighter than they are, and nobody bounces a
/// payment because an app was careful; counting a SALARY twice hands them
/// cash that is not coming. Income is identifiable, one amount against one
/// stored rule, so it can be suppressed safely. An outflow has no such
/// anchor, so both sides stay counted and the person is told.
///
/// ERR TOWARD SILENCE. A missed notice costs a projection that is slightly
/// pessimistic, which is the safe direction. A FALSE notice costs the notice
/// its credibility, which is permanent: somebody who opens Coming Up, finds
/// two unrelated bills and learns the line says nothing will never read it
/// again. Every clause below is tuned that way, and the measurement that
/// forced it is in [sharedIdentifyingWord].
library;

import '../../models/models.dart';
import 'debt.dart';
import 'money.dart';
import 'reminders.dart';

/// Which register an obligation was written into.
enum ObligationRegister {
  bill,
  upcoming,
  installment,
  debt;

  /// The place a person would go to find it, in the app's own words.
  String get whereSeen => switch (this) {
    ObligationRegister.bill => 'Coming Up',
    ObligationRegister.upcoming => 'Coming Up',
    ObligationRegister.installment => 'Coming Up',
    ObligationRegister.debt => 'Debts',
  };
}

/// One obligation as the detector sees it.
class _Candidate {
  const _Candidate({
    required this.label,
    required this.amount,
    required this.register,
    required this.days,
  });

  final String label;
  final Money amount;
  final ObligationRegister register;

  /// Days from today to the date the PERSON WROTE, never the date the engine
  /// placed it on. The seed's Meralco pair is three days apart as written and
  /// eight days apart as placed, across the overdue boundary, so a rule that
  /// compared placed positions would find nothing at all.
  final int days;
}

/// A pair that looks like one payment recorded twice.
class SuspectedDuplicate {
  const SuspectedDuplicate({
    required this.label,
    required this.otherLabel,
    required this.amount,
    required this.register,
    required this.otherRegister,
    required this.days,
  });

  /// The ENTRY side's name where there is one, because that is the row the
  /// person will go looking for.
  final String label;
  final String otherLabel;
  final Money amount;
  final ObligationRegister register;
  final ObligationRegister otherRegister;

  /// Days until the earlier of the two written dates.
  final int days;

  /// The two places to look, de-duplicated: three of the four registers are
  /// all "Coming Up" on screen, so a pair inside that group would otherwise
  /// read "in Coming Up and Coming Up".
  List<String> get places =>
      <String>{register.whereSeen, otherRegister.whereSeen}.toList();
}

/// Words that identify a REGISTER rather than an obligation.
///
/// Without this list "Meralco Electricity" and "BPI Electric Bill" share
/// "electric" and look like one payment. These are the nouns people reach for
/// when naming the KIND of thing, so they carry no identity.
const Set<String> _noiseWords = <String>{
  'bill',
  'bills',
  'payment',
  'monthly',
  'installment',
  'instalment',
  'plan',
  'loan',
  'premium',
  'electric',
  'electricity',
  'fee',
  'due',
  'the',
  'and',
  'for',
};

/// True when two labels share a word that identifies the same obligation.
///
/// THIS CLAUSE IS MANDATORY, not a refinement, and the sample ledger is the
/// proof. Matching on amount and date alone produces three pairs on the seed
/// and ONE OF THEM IS WRONG: a Pru Life VUL insurance premium of 2,500 and a
/// BPI personal loan amortisation of 2,500, both due on the same day. That is
/// the round-monthly-figure collision a Philippine ledger produces constantly,
/// because lenders and insurers quote whole pesos, and it is one in three on a
/// ledger of twenty obligations.
///
/// Three characters, not four. "VUL" is three and appears in only one of that
/// pair, so the shorter floor costs nothing here and catches a real acronym.
bool sharedIdentifyingWord(String a, String b) {
  Set<String> words(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((String w) => w.length >= 3 && !_noiseWords.contains(w))
      .toSet();
  return words(a).intersection(words(b)).isNotEmpty;
}

/// Every pair that looks like one obligation recorded in two registers.
///
/// LIABILITY ACCOUNTS ARE DELIBERATELY NOT INCLUDED, and the sample ledger
/// holds such a pair (`acc_personal_loan` against `debt_bpi_loan`, same
/// balance, same date). They are left out because the projection does not
/// read liability accounts AT ALL: it takes accounts only for the opening
/// balance and places nothing from them. Telling somebody a payment is
/// "counted twice" when one of the two is not counted at all would be a
/// sentence that is simply false. Making the projection see liability
/// accounts is a money-meaning change and a founder decision; when it is
/// taken, this function gains a fifth register and the pair starts matching
/// on balance against remaining rather than on amount.
/// Two entries for ONE payment, by the rule the "Counted twice" notice uses
/// and the one Safe to Spend's bill list uses to count a bill once
/// (bills_to_reserve.dart). One rule, so a notice can never call two entries
/// the same while the figure counts them twice, or the other way round.
///
/// 1. EXACT AMOUNT, to the centavo, never a tolerance. A five percent
///    tolerance produces seven extra pairs on the shipped seed, among them
///    the fridge plan against the phone debt, which are two genuinely
///    different obligations from one lender.
/// 2. WITHIN SEVEN DAYS as written. A calendar month is right for income,
///    where there is one sweldo, and far too wide here: two genuine 5,000
///    payments in one month are ordinary. A date nobody can read cannot be
///    compared, so it does not rule a pair out; the notice never sees such
///    an entry anyway, because it can only place a dated one.
/// 3. A SHARED IDENTIFYING WORD. See [sharedIdentifyingWord] for the false
///    positive this removes from the sample ledger.
bool sameObligation({
  required String nameA,
  required Money amountA,
  required int? daysA,
  required String nameB,
  required Money amountB,
  required int? daysB,
}) {
  if (amountA != amountB) return false;
  if (daysA != null && daysB != null && (daysA - daysB).abs() > 7) {
    return false;
  }
  return sharedIdentifyingWord(nameA, nameB);
}

List<SuspectedDuplicate> findDuplicateOutflows({
  required List<BillItem> bills,
  required List<UpcomingItem> upcoming,
  required List<InstallmentPlan> installments,
  required List<Debt> debts,
  required DateTime now,
}) {
  final List<_Candidate> all = <_Candidate>[];

  void add(String label, Money amount, String? due, ObligationRegister r) {
    if (!amount.isPositive) return;
    final int? days = daysUntil(due, now);
    if (days == null) return;
    all.add(_Candidate(label: label, amount: amount, register: r, days: days));
  }

  for (final BillItem b in bills.where((BillItem b) => !b.isPaid)) {
    add(b.name, b.amount, b.dueDate, ObligationRegister.bill);
  }
  for (final UpcomingItem u in upcoming.where(
    (UpcomingItem u) => !u.isPaid && !u.countsAsIncome,
  )) {
    add(u.name, u.amount, u.dueDate, ObligationRegister.upcoming);
  }
  for (final InstallmentPlan i in installments.where(
    (InstallmentPlan i) => !i.isSettled,
  )) {
    final DateTime? when = nextInstallmentDate(i);
    if (when == null) continue;
    add(
      i.name,
      i.installmentAmount,
      isoDate(when),
      ObligationRegister.installment,
    );
  }
  for (final Debt d in debts.where(
    (Debt d) => !d.isSettled && d.direction == DebtDirection.iOwe,
  )) {
    final Money? min = d.monthlyMinimum;
    if (min == null) continue;
    add(d.person, min, d.dueDate, ObligationRegister.debt);
  }

  final List<SuspectedDuplicate> found = <SuspectedDuplicate>[];
  for (int i = 0; i < all.length; i++) {
    for (int j = i + 1; j < all.length; j++) {
      final _Candidate a = all[i];
      final _Candidate b = all[j];

      // 1. DIFFERENT REGISTERS. Two bills, or two upcoming items, are two
      //    real payments: people do have two plans with one provider, and
      //    instalment amounts carry centavos so an exact collision between
      //    two unrelated plans is close to accidental.
      if (a.register == b.register) continue;

      // 2 to 4. The same obligation: exact amount, within seven days, a
      //    shared identifying word. See [sameObligation], which Safe to
      //    Spend's bill list uses too, so the two never disagree.
      if (!sameObligation(
        nameA: a.label,
        amountA: a.amount,
        daysA: a.days,
        nameB: b.label,
        amountB: b.amount,
        daysB: b.days,
      )) {
        continue;
      }

      // The ENTRY side leads, because that is the row the person typed and
      // will go looking for. A debt minimum is generated machinery.
      final bool aIsRule = a.register == ObligationRegister.debt;
      found.add(
        SuspectedDuplicate(
          label: aIsRule ? b.label : a.label,
          otherLabel: aIsRule ? a.label : b.label,
          amount: a.amount,
          register: aIsRule ? b.register : a.register,
          otherRegister: aIsRule ? a.register : b.register,
          days: a.days < b.days ? a.days : b.days,
        ),
      );
    }
  }
  return found;
}
