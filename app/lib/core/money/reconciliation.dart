/// Reconciliation, ported from the fourth tab of
/// src/components/ReportsScreen.tsx and the two reducers behind it in
/// src/context/FinancialContext.tsx (`createAdjustmentTransaction`,
/// `recordReconciliation`).
///
/// This is the one place in Salapify where the app admits it might be wrong.
/// Everywhere else the ledger IS the truth; here somebody holds a bank
/// statement next to it and the two disagree, and the question is what to do
/// about the difference.
///
/// The answer, and it is the whole design: NEVER silently edit the balance.
/// A traceable ADJUSTMENT ENTRY is posted instead, so the account moves for a
/// reason that is written down, appears in Activity, and can be found again in
/// a year. Quietly setting the number to match the statement would leave an
/// account whose history does not add up to its own balance, which for
/// anybody who keeps books is worse than the discrepancy.
library;

import '../../models/models.dart';
import 'debt.dart' show isoDate;

/// The two categories an adjustment is filed under. Both already exist in the
/// app's category list, so an adjustment lands somewhere Reports and Budgets
/// can see it.
const String foundCashCategory = 'Adjustments & Found Cash';
const String writeOffCategory = 'Adjustments & Write-offs';

/// Anything under a centavo is not a discrepancy, it is floating point. The
/// prototype's own threshold.
const double reconciliationTolerance = 0.01;

/// One completed reconciliation, kept as history.
class ReconciliationRecord {
  const ReconciliationRecord({
    required this.id,
    required this.accountId,
    required this.date,
    required this.bookBalance,
    required this.actualBalance,
    required this.variance,
    required this.balanced,
    required this.createdAt,
    this.notes,
    this.adjustmentTxId,
  });

  final String id;
  final String accountId;
  final String date;

  /// What Salapify thought the account held.
  final double bookBalance;

  /// What the statement said.
  final double actualBalance;

  /// Statement minus book. POSITIVE means there is more money than the app
  /// knew about, negative means less.
  final double variance;
  final bool balanced;
  final String? notes;

  /// The adjustment entry posted to close the gap, when one was.
  final String? adjustmentTxId;
  final int createdAt;
}

/// What the app believes an account holds. Its stored balance, which the
/// ledger keeps up to date on every write.
double bookBalanceOf(Account account) => account.balance;

/// Statement minus book.
double varianceOf(double bookBalance, double actualBalance) =>
    actualBalance - bookBalance;

bool isBalanced(double variance) => variance.abs() < reconciliationTolerance;

/// The adjustment entry that closes a gap.
///
/// A POSITIVE variance means the statement holds more than the app knew, so
/// the entry is INCOME, filed as found cash. A negative one is an expense,
/// filed as a write-off. It is marked `reconciled` rather than `confirmed`,
/// which is what tells a later reader this row came from a reconciliation and
/// not from something somebody bought.
Transaction? adjustmentEntry({
  required Account account,
  required double variance,
  required DateTime today,
  required String id,
  String? note,
}) {
  if (isBalanced(variance)) return null;

  final bool found = variance > 0;
  final double amount = variance.abs();
  final String reason = note?.trim().isNotEmpty == true
      ? note!.trim()
      : 'Statement balance alignment';

  return Transaction(
    id: id,
    type: found ? TransactionType.income : TransactionType.expense,
    amount: amount,
    category: found ? foundCashCategory : writeOffCategory,
    subcategory: found
        ? 'Reconciliation Upward Adjustment'
        : 'Reconciliation Discrepancy Write-down',
    accountId: account.id,
    profile: account.profile ?? ProfileEntity.personal,
    merchant: 'Reconciliation adjustment (${account.name})',
    date: isoDate(today),
    note: 'Traceable reconciliation adjustment: $reason.',
    tags: const <String>['#reconciliation', '#traceable-adjustment'],
    status: TransactionStatus.reconciled,
    createdAt: today.millisecondsSinceEpoch,
  );
}

/// A pair of entries that look like the same thing logged twice.
class DuplicatePair {
  const DuplicatePair({
    required this.first,
    required this.second,
    required this.daysApart,
  });

  final Transaction first;
  final Transaction second;
  final int daysApart;

  String get reason =>
      'Same amount on the same account, '
      '${daysApart == 0 ? 'on the same day' : '$daysApart day${daysApart == 1 ? '' : 's'} apart'}';
}

/// Finds entries that may have been logged twice.
///
/// The prototype's rule, verbatim: same amount, same account, same type,
/// within two days, and NEITHER already marked duplicate. That last clause
/// matters more than it looks: without it, an entry somebody has already
/// judged and marked keeps being offered back to them, and a list that will
/// not take an answer is one people stop reading.
///
/// It is a SUGGESTION and never an action. Two identical jeepney fares on the
/// same day are two jeepney fares, and only the person who spent the money
/// knows which. Nothing here changes anything.
List<DuplicatePair> findDuplicates(List<Transaction> transactions) {
  final List<DuplicatePair> pairs = <DuplicatePair>[];

  for (int i = 0; i < transactions.length; i++) {
    for (int j = i + 1; j < transactions.length; j++) {
      final Transaction a = transactions[i];
      final Transaction b = transactions[j];

      if (a.amount != b.amount) continue;
      if (a.accountId != b.accountId) continue;
      if (a.type != b.type) continue;
      if (a.status == TransactionStatus.duplicate) continue;
      if (b.status == TransactionStatus.duplicate) continue;

      final DateTime? da = DateTime.tryParse(a.date);
      final DateTime? db = DateTime.tryParse(b.date);
      if (da == null || db == null) continue;

      final int days = da.difference(db).inDays.abs();
      if (days <= 2) {
        pairs.add(DuplicatePair(first: a, second: b, daysApart: days));
      }
    }
  }
  return pairs;
}

/// Changes one entry's status, which is the Activity correction path.
///
/// This is how somebody says "that one is a duplicate" or "that was not mine
/// to pay". It changes what the entry MEANS to every total, because excluded
/// and duplicate entries are left out of them, and it changes nothing about
/// the money itself.
List<Transaction> applyStatusChange(
  List<Transaction> transactions,
  String id,
  TransactionStatus status,
) {
  return transactions
      .map((Transaction t) => t.id == id ? t.withStatus(status) : t)
      .toList();
}

/// Sums what the ledger says has moved through an account, to compare against
/// its stored balance.
///
/// NOT used to derive the book balance, deliberately. The stored balance is
/// the book balance, because the seeded accounts carry opening balances that
/// no entry explains. This exists so a screen can say how much of the balance
/// the ledger actually accounts for, which is a different and honest question.
double ledgerMovementFor(List<Transaction> transactions, String accountId) {
  double sum = 0;
  for (final Transaction t in transactions) {
    if (t.status == TransactionStatus.excluded ||
        t.status == TransactionStatus.duplicate) {
      continue;
    }
    if (t.accountId == accountId) {
      switch (t.type) {
        case TransactionType.income:
          sum += t.amount;
        case TransactionType.expense:
        case TransactionType.transfer:
          sum -= t.amount;
      }
    }
    if (t.type == TransactionType.transfer && t.toAccountId == accountId) {
      sum += t.amount;
    }
  }
  return sum;
}
