// One rule: a peso total never contains a non-peso amount.
//
// Delivery D of docs/features/unified-financial-accounts.md, and the part of
// that document that calls itself the most dangerous item in it. Worth
// restating, because it is the reason this file exists rather than a currency
// dropdown and nothing else:
//
//   A MISSING feature is visible. A WRONG TOTAL is not.
//
// Every engine in this app adds balances as if they were all in one currency,
// because until now they were: `currencyCode` is an app-wide SETTING and no
// account has ever had one of its own. The moment a US dollar account can
// exist, a $1,000 balance lands in a peso net worth as ₱1,000 and understates
// the truth by roughly ₱55,000, with nothing on screen to suggest anything is
// off. Adding the field without this rule would be shipping that.
//
// So the rule is: a row whose currency differs from the base currency is
// EXCLUDED from every base-currency total, and the screen SAYS SO. Excluding
// it silently would be the same failure wearing a different mask.
//
// Conversion is deliberately not here. It arrives with the honest-total rules
// in section 5 of the design document (a fresh rate converts and shows its
// age, a stale one converts and says so, no rate excludes and names what it
// excluded, a manual rate is labelled manual), and it needs golden vectors
// because it changes a number. None of that is needed to stop the total being
// wrong today, and stopping that is what this file does.

/// The app-wide currency code, read straight from the data blob.
///
/// Defaults to PHP, which is what `resolveBaseCurrency` does with a missing or
/// unusable setting, so a blob with no currency behaves exactly as every blob
/// did before this existed.
String baseCurrencyOf(dynamic data) {
  final d = data is Map ? data : const {};
  final s = d['settings'];
  final code = (s is Map ? s['currencyCode'] : null);
  if (code is String && RegExp(r'^[A-Za-z]{3}$').hasMatch(code)) {
    return code.toUpperCase();
  }
  return 'PHP';
}

/// Does this row belong in a total denominated in [base]?
///
/// A row with NO currency of its own is in the base currency. That is not a
/// guess, it is what every row in every existing backup means: there was no
/// per-row currency to disagree with, so all of them were the app's one
/// currency by construction. Treating absent as foreign would empty every
/// total in the app on the day this shipped.
bool inBaseCurrency(dynamic row, String base) {
  final r = row is Map ? row : const {};
  final code = r['currencyCode'];
  if (code is! String || code.isEmpty) return true;
  return code.toUpperCase() == base.toUpperCase();
}

/// The rows left OUT of the base-currency totals, so a screen can name them.
///
/// Returning the rows rather than a count, because "2 accounts are not
/// counted" tells somebody there is a problem and not which one, and the whole
/// point of excluding rather than converting is that the person can see
/// exactly what is missing and decide for themselves.
List<Map<String, dynamic>> foreignRows(dynamic list, String base) => [
  for (final r in (list as List? ?? const []))
    if (r is Map && !inBaseCurrency(r, base)) r.cast<String, dynamic>(),
];

/// Every foreign row across the collections that feed a base-currency total.
///
/// Receivables and payables are deliberately absent: they carry no currency
/// field, they are person-to-person amounts recorded in whatever the two
/// people agreed, and inventing a currency for them would be a guess dressed
/// as a fact.
List<Map<String, dynamic>> allForeignRows(dynamic data) {
  final d = data is Map ? data : const {};
  final base = baseCurrencyOf(d);
  return [
    ...foreignRows(d['accounts'], base),
    ...foreignRows(d['assets'], base),
    ...foreignRows(d['debts'], base),
  ];
}

/// The one sentence a screen shows when something was left out.
///
/// Null when nothing was excluded, so a screen can render it or not without
/// deciding anything itself. Names up to two rows and then counts the rest,
/// because a list of six names is a paragraph and stops being read.
String? excludedNotice(dynamic data) {
  final rows = allForeignRows(data);
  if (rows.isEmpty) return null;
  String nameOf(Map<String, dynamic> r) {
    final n = r['name'];
    final c = r['currencyCode'];
    final label = (n is String && n.trim().isNotEmpty) ? n.trim() : 'One item';
    return c is String && c.isNotEmpty ? '$label ($c)' : label;
  }

  final base = baseCurrencyOf(data);
  final named = rows.take(2).map(nameOf).join(' and ');
  final rest = rows.length - 2;
  final subject = rest > 0
      ? '$named and $rest more are'
      : (rows.length == 1 ? '$named is' : '$named are');
  return '$subject not counted in the total above, because Salapify cannot '
      'convert to $base yet. The amounts are still yours, and still shown '
      'below in their own currency.';
}
