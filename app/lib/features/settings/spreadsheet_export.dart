// Your entries as a spreadsheet, which is NOT a backup.
//
// The founder asked "Only a json format? what about other formats people can
// choose from?" and the honest answer has a fork in it, so the fork lives here
// in code rather than only in a chat message.
//
// A BACKUP has to be able to come BACK. It carries accounts, debts, people,
// receivables, payables, recurring rows, budgets, goals, settings, and the
// links between them, and restoring it has to rebuild every one. JSON does
// that. A spreadsheet cannot: it is a flat grid, and flattening a ledger throws
// away the structure that makes it a ledger. There is no honest way to restore
// one.
//
// So CSV is offered for READING, in Excel, Sheets, or by an accountant, and it
// is labelled as that everywhere it appears. The dangerous version of this
// feature is a "CSV backup" button: somebody saves one, believes they are
// covered, loses their phone, and discovers at the worst possible moment that
// it was never a backup. The word backup is deliberately not used on this path.
//
// Written by hand rather than pulling the `csv` package, because the whole job
// is one escaping rule and a package is a dependency to keep current forever.
// The rule is RFC 4180 and it is implemented in [_cell] below.
import '../../core/money/ledger.dart' show amountOf;

const _headers = ['Date', 'Type', 'Label', 'Amount', 'Account', 'Note'];

Map<String, String> _accountNames(Map<String, dynamic> data) {
  final out = <String, String>{};
  for (final a in (data['accounts'] is List ? data['accounts'] as List : [])) {
    if (a is Map && a['id'] is String) {
      out[a['id'] as String] = (a['name'] ?? '').toString();
    }
  }
  return out;
}

/// One CSV field, quoted when it has to be.
///
/// RFC 4180: a field containing a comma, a double quote, or a newline is
/// wrapped in double quotes, and each embedded quote is doubled. This matters
/// more here than in most apps because Filipino money labels routinely carry
/// commas and apostrophes ("Lola's, paid back"), and an unquoted comma silently
/// shifts every column after it, which turns an amount into a date and looks
/// like the app got the number wrong.
String _cell(dynamic value) {
  if (value is num) return value.toString();
  final s = (value ?? '').toString();
  if (!s.contains(',') && !s.contains('"') && !s.contains('\n')) return s;
  return '"${s.replaceAll('"', '""')}"';
}

/// Every entry as CSV text, newest first.
String transactionsCsv(Map<String, dynamic> data) {
  final names = _accountNames(data);
  final txns = [
    for (final t in (data['transactions'] is List
        ? data['transactions'] as List
        : []))
      if (t is Map) t.cast<String, dynamic>(),
  ]..sort(
    (a, b) =>
        (b['date'] ?? '').toString().compareTo((a['date'] ?? '').toString()),
  );

  final buffer = StringBuffer()..writeln(_headers.join(','));
  for (final t in txns) {
    buffer.writeln(
      [
        _cell(t['date']),
        _cell(t['type']),
        _cell(t['label']),
        // The raw number, NOT a formatted peso string. A spreadsheet has to be
        // able to sum this column, and "PHP1,250.00" is text that sums to zero.
        _cell(amountOf(t['amount'])),
        _cell(names[t['accountId']] ?? ''),
        _cell(t['note']),
      ].join(','),
    );
  }
  return buffer.toString();
}

/// The file name a spreadsheet export is offered under.
///
/// Says "entries", never "backup", because the name is the last thing somebody
/// sees months later when they are deciding which file to trust.
String csvFileName(DateTime now) {
  String two(int n) => n.toString().padLeft(2, '0');
  return 'salapify-entries-${now.year}-${two(now.month)}-${two(now.day)}.csv';
}
