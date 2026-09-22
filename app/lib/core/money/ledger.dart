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

/// Rounds, or returns a stated fallback when the value is not a real number.
int _safeRound(double v, {required int ifBroken}) =>
    v.isFinite ? v.round() : ifBroken;

/// Applies the profile, status, account and search filters, in that order.
///
/// The TYPE filter is deliberately not applied here. The prototype scopes
/// first, computes the totals off the scoped set, and only then filters by
/// type for the list, so the summary card keeps describing the whole selection
/// while the list below it narrows. Collapsing the two would make the card's
/// figures change every time somebody tapped a tab.
///
/// The profile is READ, never guessed. The prototype's rule is exactly
/// `t.profile || 'personal'` (LedgerScreen.tsx), and an earlier version of
/// this function ran the keyword inference that belongs to UPCOMING ROWS over
/// transactions too. That quietly reassigned every peso of salary to Business
/// on the strength of the word "payroll" in a merchant name, so selecting the
/// Personal profile showed income of zero on a ledger holding 51,000.
List<Transaction> scopeTransactions(
  List<Transaction> transactions,
  LedgerQuery query,
) {
  return transactions.where((Transaction t) {
    if (query.profile != null) {
      final ProfileEntity p = t.profile ?? ProfileEntity.personal;
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
  //
  // _safeRound is the one addition. .round() on a non-finite double raises
  // "Unsupported operation: Infinity or NaN toInt", and this runs inside
  // build(), so a single bad row turned the whole screen into a red error box
  // that no tapping could clear. parseLoggedAmount now stops such a row being
  // written; this makes the READER safe as well, which is where a restored
  // backup or an imported file will eventually arrive from.
  final int outflowPercentage = totalIn > 0
      ? _safeRound((totalOut / totalIn) * 100, ifBroken: 100).clamp(0, 100)
      : (totalOut > 0 ? 100 : 0);
  final int retentionPercentage = totalIn > 0
      ? _safeRound((net / totalIn) * 100, ifBroken: 0).clamp(0, 1 << 31)
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

// ------------------------------------------------------------------- writing

/// Applies a newly logged entry to the account balances, ported from
/// addTransaction in src/context/FinancialContext.tsx.
///
/// The rules, all of them the prototype's:
///   expense   the source account falls
///   income    the source account rises
///   transfer  the source falls AND the destination rises
///   excluded or duplicate  NOTHING moves, because those mean "this is not
///             really money that moved", exactly as they do in the totals
///
/// A PRESERVED QUIRK, named rather than fixed: a transfer whose destination
/// id matches no account debits the source and credits nobody, so money
/// simply disappears from net worth. That is what the prototype does, and the
/// vectors lock it, because changing a number nobody decided to change is the
/// worse error. The defence is that the UI must make it unreachable: a
/// destination is picked from the account list and cannot be the source. If a
/// caller ever manages to produce it, that is a bug in the caller.
List<Account> applyToBalances(List<Account> accounts, Transaction tx) {
  if (!tx.countsTowardTotals) return accounts;

  return accounts.map((Account a) {
    if (a.id == tx.accountId) {
      final double delta = switch (tx.type) {
        TransactionType.income => tx.amount,
        TransactionType.expense => -tx.amount,
        TransactionType.transfer => -tx.amount,
      };
      return a.copyWith(balance: a.balance + delta);
    }
    if (tx.type == TransactionType.transfer && a.id == tx.toAccountId) {
      return a.copyWith(balance: a.balance + tx.amount);
    }
    return a;
  }).toList();
}

/// Takes a transaction's effect back OFF the balances.
///
/// The exact inverse of [applyToBalances], and the word exact is the point:
/// this is how an undo gives somebody their money back, so a sign wrong here
/// is a balance wrong forever, silently, on a screen that looks fine.
///
/// It is written as a mirror rather than derived from the original, because
/// the obvious derivation, applying a transaction with a negated amount, is
/// wrong in two ways at once: `countsTowardTotals` and the transfer's second
/// leg both read fields that negation does not touch. A mirror can drift from
/// its original, so `ledger_golden_test.dart` pins the ROUND TRIP instead of
/// the arithmetic: apply then reverse must return the balances untouched, for
/// every transaction shape. That property cannot pass if either function
/// changes without the other.
List<Account> reverseFromBalances(List<Account> accounts, Transaction tx) {
  if (!tx.countsTowardTotals) return accounts;

  return accounts.map((Account a) {
    if (a.id == tx.accountId) {
      final double delta = switch (tx.type) {
        TransactionType.income => -tx.amount,
        TransactionType.expense => tx.amount,
        TransactionType.transfer => tx.amount,
      };
      return a.copyWith(balance: a.balance + delta);
    }
    if (tx.type == TransactionType.transfer && a.id == tx.toAccountId) {
      return a.copyWith(balance: a.balance - tx.amount);
    }
    return a;
  }).toList();
}

/// Splits the Log sheet's tag field the way the prototype does: on commas,
/// trimmed, empties dropped, and every tag forced to start with a hash so the
/// stored shape cannot depend on whether somebody typed one.
List<String> parseTags(String raw) {
  return raw
      .split(',')
      .map((String t) => t.trim())
      .where((String t) => t.isNotEmpty)
      .map((String t) => t.startsWith('#') ? t : '#$t')
      .toList();
}

/// The Log sheet's amount parse: commas stripped, and anything that is not a
/// positive number is refused. The prototype returns early rather than saving
/// a zero, so a blank or a minus sign writes nothing at all.
double? parseLoggedAmount(String raw) {
  final double? v = double.tryParse(raw.replaceAll(',', '').trim());
  // isFinite is doing real work here, not being defensive. Dart parses the
  // literal text "NaN" and "Infinity" into real doubles, and EVERY comparison
  // against NaN is false, so `v <= 0` waves both through. Typing NaN into the
  // amount field then set an account balance to NaN, which nothing can undo,
  // and made Activity and Home throw "Unsupported operation: Infinity or NaN
  // toInt" on every rebuild. "1e400" overflows to Infinity and does the same.
  // The prototype is protected twice over, by isNaN and by an <input
  // type="number">; Dart has neither for free.
  if (v == null || !v.isFinite || v <= 0) return null;
  return v;
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
