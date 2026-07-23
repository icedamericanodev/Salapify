// Quick-add helpers for the log sheet, the app's most frequent action. Both
// remove typing from a repeat log: recentLabels surfaces the names the user
// already used so a repeat is a tap, and lastUsedAccountId remembers which
// account they last logged from so it is preselected. Pure and read-only; no
// pesos, so covered by plain unit tests. Ordering matches the History screen
// (newest by date, then by list position) so "recent" means the same thing.

/// The user's most recent DISTINCT entry labels for [type] ('expense' or
/// 'income'), newest first, up to [limit]. Skips blank labels and the generic
/// 'Expense'/'Income' fallbacks the log sheet stores for an empty label, so the
/// chips only offer names the user actually typed. Case-insensitive de-dup, but
/// the first-seen spelling is kept.
List<String> recentLabels(dynamic transactions, String type, {int limit = 6}) {
  final rows = <({String date, int idx, String label})>[];
  final list = transactions is List ? transactions : const [];
  for (var i = 0; i < list.length; i++) {
    final t = list[i];
    if (t is! Map) continue;
    if (t['type'] != type) continue;
    final raw = t['label'];
    if (raw is! String) continue;
    final label = raw.trim();
    if (label.isEmpty || label == 'Expense' || label == 'Income') continue;
    rows.add((date: (t['date'] ?? '').toString(), idx: i, label: label));
  }
  rows.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.idx.compareTo(a.idx);
  });
  final seen = <String>{};
  final out = <String>[];
  for (final r in rows) {
    if (seen.add(r.label.toLowerCase())) {
      out.add(r.label);
      if (out.length >= limit) break;
    }
  }
  return out;
}

/// The account id the user most recently logged from, so the log sheet can
/// preselect it. Newest transaction with a real accountId whose account still
/// exists in [validIds]; null if there is none.
String? lastUsedAccountId(dynamic transactions, Set<String> validIds) {
  final rows = <({String date, int idx, String acct})>[];
  final list = transactions is List ? transactions : const [];
  for (var i = 0; i < list.length; i++) {
    final t = list[i];
    if (t is! Map) continue;
    final acct = t['accountId'];
    if (acct is! String || acct.isEmpty) continue;
    rows.add((date: (t['date'] ?? '').toString(), idx: i, acct: acct));
  }
  rows.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : b.idx.compareTo(a.idx);
  });
  for (final r in rows) {
    if (validIds.contains(r.acct)) return r.acct;
  }
  return null;
}
