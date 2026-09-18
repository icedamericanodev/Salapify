/// The Ledger's filtering, totals and grouping, ported from
/// src/components/LedgerScreen.tsx.
///
/// It lives here rather than in the screen for the reason every engine in this
/// folder does: a figure a person can read off a screen has to be checkable
/// without building the screen. The search in particular has six different ways
/// to match an amount, and none of them is guessable from the UI.
library;

import '../../models/models.dart';

/// The type tabs above the list. `all` is not a type, it is the absence of the
/// filter, which is why this is separate from TransactionType.
enum LedgerTypeFilter { all, income, expense, transfer }

/// Everything the Ledger filters on at once.
class LedgerQuery {
  const LedgerQuery({
    this.search = '',
    this.status,
    this.accountId,
    this.profile,
    this.type = LedgerTypeFilter.all,
  });

  final String search;

  /// null means the prototype's 'all'.
  final TransactionStatus? status;
  final String? accountId;
  final ProfileEntity? profile;
  final LedgerTypeFilter type;
}

/// What the summary card reads.
class LedgerTotals {
  const LedgerTotals({
    required this.totalIn,
    required this.totalOut,
    required this.netMovement,
    required this.inflowCount,
    required this.outflowCount,
    required this.transferCount,
    required this.outflowPercentage,
    required this.retentionPercentage,
  });

  final double totalIn;
  final double totalOut;
  final double netMovement;
  final int inflowCount;
  final int outflowCount;
  final int transferCount;

  /// How much of what came in went back out, capped at 100.
  final int outflowPercentage;

  /// How much of what came in was kept. Never negative.
  final int retentionPercentage;
}

/// One day's entries, newest day first.
class LedgerDay {
  const LedgerDay(this.date, this.transactions);

  /// ISO, YYYY-MM-DD.
  final String date;
  final List<Transaction> transactions;
}

/// Applies the profile, status, account and search filters, in that order.
///
/// The TYPE filter is deliberately not applied here. The prototype scopes
/// first, computes the totals off the scoped set, and only then filters by
/// type for the list, so the summary card keeps describing the whole selection
/// while the list below it narrows. Collapsing the two would make the card's
/// figures change every time somebody tapped a tab.
List<Transaction> scopeTransactions(
  List<Transaction> transactions,
  LedgerQuery query, {
  ProfileEntity Function(Transaction)? profileOf,
}) {
  return transactions.where((Transaction t) {
    if (query.profile != null) {
      final ProfileEntity p =
          t.profile ?? profileOf?.call(t) ?? ProfileEntity.personal;
      if (p != query.profile) return false;
    }

    if (query.status != null && t.status != query.status) return false;

    // Matches EITHER side of a transfer, so filtering by an account shows the
    // money arriving as well as the money leaving.
    if (query.accountId != null &&
        t.accountId != query.accountId &&
        t.toAccountId != query.accountId) {
      return false;
    }

    if (query.search.trim().isEmpty) return true;
    return _matchesSearch(t, query.search);
  }).toList();
}

/// Applies the type tab. Separate from scoping, see scopeTransactions.
List<Transaction> filterByType(
  List<Transaction> scoped,
  LedgerTypeFilter type,
) {
  return switch (type) {
    LedgerTypeFilter.all => scoped,
    LedgerTypeFilter.income =>
      scoped
          .where((Transaction t) => t.type == TransactionType.income)
          .toList(),
    LedgerTypeFilter.expense =>
      scoped
          .where((Transaction t) => t.type == TransactionType.expense)
          .toList(),
    LedgerTypeFilter.transfer =>
      scoped
          .where((Transaction t) => t.type == TransactionType.transfer)
          .toList(),
  };
}

/// The summary figures, computed off the SCOPED set.
///
/// Transfers are in neither total, and that is the transfer invariant rather
/// than an omission: moving money between your own accounts is not income and
/// not spending. They are counted separately so the card can still say how
/// many there were.
LedgerTotals computeTotals(List<Transaction> scoped) {
  double totalIn = 0;
  double totalOut = 0;
  int inflowCount = 0;
  int outflowCount = 0;
  int transferCount = 0;

  for (final Transaction t in scoped) {
    if (t.type == TransactionType.transfer) {
      transferCount++;
      continue;
    }
    if (!t.countsTowardTotals) continue;

    if (t.type == TransactionType.income) {
      totalIn += t.amount;
      inflowCount++;
    } else if (t.type == TransactionType.expense) {
      totalOut += t.amount;
      outflowCount++;
    }
  }

  final double net = totalIn - totalOut;

  // Both percentages are the prototype's own expressions, including what they
  // do when nothing came in: outflow reads 100 if anything went out, and
  // retention reads 0 rather than a negative number.
  final int outflowPercentage = totalIn > 0
      ? ((totalOut / totalIn) * 100).round().clamp(0, 100)
      : (totalOut > 0 ? 100 : 0);
  final int retentionPercentage = totalIn > 0
      ? ((net / totalIn) * 100).round().clamp(0, 1 << 31)
      : 0;

  return LedgerTotals(
    totalIn: totalIn,
    totalOut: totalOut,
    netMovement: net,
    inflowCount: inflowCount,
    outflowCount: outflowCount,
    transferCount: transferCount,
    outflowPercentage: outflowPercentage,
    retentionPercentage: retentionPercentage,
  );
}

/// Groups into days, newest day first.
///
/// Sorted by comparing the ISO date STRINGS, which the prototype does too and
/// which is correct precisely because the format is YYYY-MM-DD: it sorts the
/// same way as the dates it encodes, with no parsing and no time zone to get
/// wrong. Insertion order is preserved inside a day.
List<LedgerDay> groupByDay(List<Transaction> transactions) {
  final Map<String, List<Transaction>> byDate = <String, List<Transaction>>{};
  for (final Transaction t in transactions) {
    byDate.putIfAbsent(t.date, () => <Transaction>[]).add(t);
  }
  final List<String> dates = byDate.keys.toList()
    ..sort((String a, String b) => b.compareTo(a));
  return <LedgerDay>[for (final String d in dates) LedgerDay(d, byDate[d]!)];
}

/// Total spent per category, biggest first, over EVERY transaction rather than
/// the scoped set. The prototype reads the unfiltered list here on purpose:
/// this feeds the Insights segment, which is about the whole picture.
List<({String category, double amount})> categorySpending(
  List<Transaction> transactions,
) {
  final Map<String, double> byCategory = <String, double>{};
  for (final Transaction t in transactions) {
    if (t.type != TransactionType.expense) continue;
    if (!t.countsTowardTotals) continue;
    byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
  }
  final List<({String category, double amount})> rows =
      byCategory.entries
          .map(
            (MapEntry<String, double> e) => (category: e.key, amount: e.value),
          )
          .toList()
        ..sort(
          (
            ({String category, double amount}) a,
            ({String category, double amount}) b,
          ) => b.amount.compareTo(a.amount),
        );
  return rows;
}

// --------------------------------------------------------------------- search

/// The prototype's search, which is far more forgiving than it looks.
///
/// It matches on the words AND on the money, and the money half accepts a
/// currency prefix, thousands separators, and a near-exact numeric value. All
/// six shapes are kept because a person who types "1,250" and a person who
/// types "php1250" are both looking for the same row.
bool _matchesSearch(Transaction t, String rawSearch) {
  final String q = rawSearch.trim().toLowerCase();
  if (q.isEmpty) return true;

  bool has(String? field) => field != null && field.toLowerCase().contains(q);

  if (has(t.merchant) || has(t.note) || has(t.person)) return true;
  if (has(t.category) || has(t.subcategory)) return true;
  if (t.tags.any((String tag) => tag.toLowerCase().contains(q))) return true;

  return _matchesAmount(t.amount, q);
}

bool _matchesAmount(double amount, String q) {
  final String raw = _rawNumberString(amount);
  final String withDecimals = _grouped(amount, decimals: 2);
  final String noDecimals = _grouped(amount, decimals: 0);

  if (raw.contains(q) ||
      withDecimals.toLowerCase().contains(q) ||
      noDecimals.toLowerCase().contains(q) ||
      '₱$raw'.toLowerCase().contains(q) ||
      '₱$withDecimals'.toLowerCase().contains(q)) {
    return true;
  }

  // Strip a currency prefix and any thousands separators, then try again, and
  // finally accept a value within a centavo. That last one is what makes
  // "1250.00" find an amount stored as 1250.
  final String cleaned = q
      .replaceFirst(RegExp(r'^(?:php|₱|p)\s*', caseSensitive: false), '')
      .replaceAll(',', '')
      .trim();
  if (cleaned.isEmpty) return false;
  final double? asNumber = double.tryParse(cleaned);
  if (asNumber == null) return false;

  return raw.contains(cleaned) ||
      withDecimals.contains(cleaned) ||
      noDecimals.contains(cleaned) ||
      (amount - asNumber).abs() < 0.01;
}

/// JavaScript's `Number.prototype.toString()` for the values a ledger holds:
/// a whole number prints without a trailing ".0", which Dart's toString does
/// not do. `1250.0.toString()` is "1250.0" in Dart and "1250" in JS, and the
/// difference decides whether searching "1250" finds the row.
String _rawNumberString(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// `toLocaleString('en-US')` with the given decimals: commas every three
/// digits, no currency symbol.
String _grouped(double v, {required int decimals}) {
  final String fixed = v.toStringAsFixed(decimals);
  final List<String> parts = fixed.split('.');
  final String whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match _) => ',',
  );
  return parts.length > 1 ? '$whole.${parts[1]}' : whole;
}
