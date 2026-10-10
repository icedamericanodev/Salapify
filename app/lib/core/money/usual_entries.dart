/// The entries a person logs over and over, offered as one-tap chips in the
/// Log sheet (D31, 2026-10-09).
///
/// The daily heartbeat of this app is the same small spends every day: the
/// jeep, the kape, the load. Typing them is where people give up, so the
/// sheet offers the ones this ledger already repeats. Read from the ledger,
/// never stored: there is nothing to keep in step and nothing to lose.
///
/// A chip FILLS the form, it does not save. That is the rule the quick-parse
/// line already follows: a guess about money is shown before it is kept.
library;

import '../../models/models.dart';
import 'money.dart';

/// One repeated entry: what, how much, out of which account.
class UsualEntry {
  const UsualEntry({
    required this.label,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.merchant,
    required this.count,
  });

  /// What the chip says: the merchant if there was one, else the category.
  final String label;
  final Money amount;
  final String category;
  final String accountId;

  /// Null when the entries had none, so the form is not filled with a label
  /// that was only ever a category.
  final String? merchant;

  /// How many times it was logged, which orders the chips.
  final int count;
}

/// The [max] most repeated EXPENSES, each seen at least [minCount] times.
///
/// Two entries are "the same" when the merchant (or, with no merchant, the
/// category), the amount to the centavo and the account all match, ignoring
/// case and spaces in the merchant. An amount that differs is a different
/// habit: "Kape 150" and "Kape 180" are two chips, because filling the wrong
/// one fills the wrong money.
///
/// Sample entries are left out, so the examples never become somebody's
/// "usual". Ties go to the most recently logged, so a new habit can overtake
/// an old one. The order is deterministic: Dart's sort is not stable, so the
/// last tiebreak is the label.
List<UsualEntry> usualEntries(
  List<Transaction> transactions, {
  int max = 6,
  int minCount = 2,
}) {
  final Map<String, _Tally> tallies = <String, _Tally>{};
  for (final Transaction t in transactions) {
    if (t.type != TransactionType.expense || t.isSample) continue;
    // A share a friend paid touched none of the person's accounts, so it
    // cannot be "the usual" from one (D34).
    if (t.isFromOutside) continue;
    final String? merchant = t.merchant?.trim().isEmpty ?? true
        ? null
        : t.merchant!.trim();
    final String what = (merchant ?? t.category).toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final String key = '$what|${t.amount.centavos}|${t.accountId}';
    final _Tally tally = tallies.putIfAbsent(key, () => _Tally(t, merchant));
    tally.count++;
    if (t.createdAt > tally.latest.createdAt) {
      tally.latest = t;
      tally.merchant = merchant;
    }
  }

  final List<_Tally> repeated =
      tallies.values.where((_Tally x) => x.count >= minCount).toList()
        ..sort((_Tally a, _Tally b) {
          final int byCount = b.count.compareTo(a.count);
          if (byCount != 0) return byCount;
          final int byRecent = b.latest.createdAt.compareTo(a.latest.createdAt);
          if (byRecent != 0) return byRecent;
          return a.label.compareTo(b.label);
        });

  return <UsualEntry>[
    for (final _Tally x in repeated.take(max))
      UsualEntry(
        label: x.label,
        amount: x.latest.amount,
        category: x.latest.category,
        accountId: x.latest.accountId,
        merchant: x.merchant,
        count: x.count,
      ),
  ];
}

class _Tally {
  _Tally(this.latest, this.merchant);

  Transaction latest;
  String? merchant;
  int count = 0;

  String get label => merchant ?? latest.category;
}
