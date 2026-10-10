/// One obligation, recorded both as an ACCOUNT and on the Debt screen.
///
/// WHY THIS EXISTS, AND WHY IT EXISTS NOW. Until 2026-10-05 the balance sheet
/// read accounts and nothing else, so somebody who recorded their BPI loan as
/// a loan account AND as a debt saw it counted once and never knew. Putting
/// debts on the sheet fixed a real understatement and made this one visible:
/// the shipped sample ledger carries 10,000 as both `acc_personal_loan` and
/// `debt_bpi_loan`, and 6,250 as both the receivable account and two
/// `owedToMe` debts. 16,250 that is now counted twice.
///
/// IT FLAGS, IT NEVER DROPS, the same way `duplicate_obligations.dart` does
/// for outflows. Dropping one side would mean choosing which record the
/// person meant, and both are reasonable: an account is the right home for a
/// loan you watch a balance on, and a debt row is the right home for one you
/// make payments against. Only they know which they intended, so the totals
/// stay whole and the person is told.
///
/// SEPARATE FROM `findDuplicateOutflows`, deliberately, because the two
/// answer different questions. That one asks whether the same PAYMENT is
/// scheduled twice in the next forty five days, and matches on a monthly
/// amount. This one asks whether the same OBLIGATION is on the balance sheet
/// twice, and matches on a balance. The one thing they share is the rule for
/// deciding that two names refer to the same thing, which is imported rather
/// than copied: a matching rule written twice is how two detectors start
/// disagreeing about one peso.
library;

import '../../models/models.dart';
import 'duplicate_obligations.dart' show sharedIdentifyingWord;
import 'money.dart';
import 'reports.dart' show liabilityKinds;

/// Which of the two shapes was found.
enum BalanceOverlapKind {
  /// One account against one debt, matched by name and amount.
  oneToOne,

  /// A receivable account holding the running total of every live `owedToMe`
  /// debt. People keep this alongside the per-person list.
  runningTotal,
}

/// A balance that appears to be on the sheet twice.
class SuspectedDuplicateBalance {
  const SuspectedDuplicateBalance({
    required this.kind,
    required this.accountId,
    required this.accountName,
    required this.amount,
    required this.debtNames,
    required this.isLiability,
  });

  final BalanceOverlapKind kind;
  final String accountId;
  final String accountName;

  /// The overlap: what is being counted a second time.
  final Money amount;

  /// The debt row or rows on the other side.
  final List<String> debtNames;

  /// Which side of the sheet is overstated. Both are real and they pull net
  /// worth in opposite directions, which is why the flag says which.
  final bool isLiability;
}

/// Every balance that looks like it is on the sheet twice.
///
/// ERR TOWARD SILENCE, exactly as the outflow detector does. A missed flag
/// costs a figure that is wrong in a way the person cannot see, which is bad.
/// A false flag tells somebody their own correct bookkeeping is a mistake,
/// which is worse, because it is the app being confidently wrong about
/// something they know better than it does.
List<SuspectedDuplicateBalance> findDuplicateBalances({
  required List<Account> accounts,
  required List<Debt> debts,
}) {
  final List<Debt> liveIOwe = debts
      .where(
        (Debt d) =>
            d.direction == DebtDirection.iOwe && !d.isSettled && !d.isArchived,
      )
      .toList();
  final List<Debt> liveOwedToMe = debts
      .where(
        (Debt d) =>
            d.direction == DebtDirection.owedToMe &&
            !d.isSettled &&
            !d.isArchived,
      )
      .toList();

  // FOREIGN ACCOUNTS ARE SKIPPED ENTIRELY. `balanceInPhp` has a live exchange
  // rate inside it and `Debt` has no currency field at all, so an exact match
  // across a rate is a coincidence of the rate rather than of the obligation,
  // and it would appear and disappear as the rate moved.
  final List<Account> usable = accounts
      .where((Account a) => !a.isForeign && a.balance.isPositive)
      .toList();

  final List<SuspectedDuplicateBalance> found = <SuspectedDuplicateBalance>[];

  // SHAPE ONE: one account against one debt.
  for (final Account a in usable) {
    final bool isLiability = liabilityKinds.contains(a.kind);
    final bool isReceivable = a.kind == AccountKind.receivable;
    if (!isLiability && !isReceivable) continue;

    // SAME SIDE OF THE SHEET. A loan account never pairs with money somebody
    // owes you, however well the figures line up.
    final List<Debt> candidates = isLiability ? liveIOwe : liveOwedToMe;

    for (final Debt d in candidates) {
      // EXACT, to the centavo, against EITHER figure and never a band.
      //
      // Two comparisons rather than one because people record it both ways.
      // `remaining` catches somebody who typed today's balance into both
      // places, which is the sample ledger's case: `acc_personal_loan` holds
      // 10,000 and `debt_bpi_loan` is 15,000 less 5,000 paid. `totalAmount`
      // catches somebody who put the original principal on the account and
      // never updated it.
      final bool amountMatches =
          a.balanceInPhp == d.remaining || a.balanceInPhp == d.totalAmount;
      if (!amountMatches) continue;

      // A SHARED IDENTIFYING WORD, and this clause is what makes the rule
      // usable at all. Philippine lenders quote round figures, so two
      // genuinely different 10,000 obligations at one institution are
      // ordinary. The sibling detector measured that collision at one in
      // three on a twenty row ledger.
      if (!sharedIdentifyingWord(
        '${a.institution} ${a.name} ${a.notes ?? ''}',
        '${d.person} ${d.notes ?? ''}',
      )) {
        continue;
      }

      found.add(
        SuspectedDuplicateBalance(
          kind: BalanceOverlapKind.oneToOne,
          accountId: a.id,
          accountName: a.name,
          amount: a.balanceInPhp,
          debtNames: <String>[d.person],
          isLiability: isLiability,
        ),
      );
    }
  }

  // SHAPE TWO: a receivable account holding the running total.
  //
  // ONE COMPARISON, NEVER A SEARCH. Over n debts there are 2^n subsets and
  // one of them hits almost any balance, so a subset match is evidence of
  // arithmetic rather than of duplication. The all-or-nothing shape is the
  // whole reason this means something.
  //
  // The shared-word clause does NOT apply here and must not be bolted on.
  // The anchor is the kind plus the exact total: "Accounts Receivable
  // (Pahiram & Split)" shares no word with "Kuya Mark", which is exactly why
  // the one-to-one rule above cannot see this pair at all.
  if (liveOwedToMe.isNotEmpty) {
    Money total = Money.zero;
    for (final Debt d in liveOwedToMe) {
      total += d.remaining;
    }
    for (final Account a in usable) {
      if (a.kind != AccountKind.receivable) continue;
      if (a.balanceInPhp != total) continue;
      // Not if the one-to-one rule already named this account, or the person
      // would be told about one account twice.
      if (found.any((SuspectedDuplicateBalance f) => f.accountId == a.id)) {
        continue;
      }
      found.add(
        SuspectedDuplicateBalance(
          kind: BalanceOverlapKind.runningTotal,
          accountId: a.id,
          accountName: a.name,
          amount: total,
          debtNames: liveOwedToMe.map((Debt d) => d.person).toList(),
          isLiability: false,
        ),
      );
    }
  }

  return found;
}
