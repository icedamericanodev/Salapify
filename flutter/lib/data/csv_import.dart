// Import transactions from a bank, GCash, Maya, or spreadsheet CSV. Every
// source lays its columns out differently, so this does NOT guess: it parses
// the file into rows, the screen lets the user say which column is the date,
// the amount, and the description (and the date format and sign convention),
// then this builds candidate transactions and reports how many rows it could
// not read. Nothing is written until the user confirms the preview.
//
// Pure and unit tested. Amounts and dates are parsed defensively; a row that
// cannot be read is skipped and counted, never guessed into a wrong entry.

import 'package:csv/csv.dart';

/// How the date column is written, chosen by the user because D/M/Y and M/D/Y
/// are otherwise ambiguous.
enum DateFormatChoice { iso, mdy, dmy }

class ParsedCsv {
  final List<List<String>> rows; // every row as trimmed strings
  const ParsedCsv(this.rows);

  int get columnCount =>
      rows.fold(0, (m, r) => r.length > m ? r.length : m);
}

/// Parse CSV text into string rows. Tolerant of quoting and of ragged rows.
ParsedCsv parseCsv(String text) {
  final raw = const CsvToListConverter(
    shouldParseNumbers: false,
    eol: '\n',
  ).convert(text.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
  final rows = <List<String>>[];
  for (final r in raw) {
    final cells = r.map((c) => (c ?? '').toString().trim()).toList();
    // Drop fully blank lines.
    if (cells.every((c) => c.isEmpty)) continue;
    rows.add(cells);
  }
  return ParsedCsv(rows);
}

/// The user's mapping from columns to fields.
class ColumnMap {
  final int date;
  final int amount;
  final int? description;
  final int? type; // a column holding "income"/"expense" style text
  final DateFormatChoice dateFormat;

  /// When there is no type column, the amount's sign decides: by default a
  /// negative amount is an expense and a positive one is income (the common
  /// bank convention).
  final bool negativeIsExpense;

  const ColumnMap({
    required this.date,
    required this.amount,
    this.description,
    this.type,
    this.dateFormat = DateFormatChoice.iso,
    this.negativeIsExpense = true,
  });
}

class ImportResult {
  /// Ready-to-store transactions (no id yet; the store assigns one).
  final List<Map<String, dynamic>> transactions;

  /// Rows that could not be read (bad or missing date/amount).
  final int skipped;

  const ImportResult(this.transactions, this.skipped);

  int get imported => transactions.length;
}

String _cell(List<String> row, int i) =>
    (i >= 0 && i < row.length) ? row[i] : '';

// Clean an amount string: strip currency letters/symbols and thousands commas,
// read parentheses as a negative. Returns null if there is no number in it.
double? parseAmount(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  var negative = false;
  if (s.startsWith('(') && s.endsWith(')')) {
    negative = true;
    s = s.substring(1, s.length - 1);
  }
  if (s.contains('-')) negative = true;
  // Keep digits and the decimal point only.
  final cleaned = s.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty || cleaned == '.') return null;
  final value = double.tryParse(cleaned);
  if (value == null || !value.isFinite) return null;
  return negative ? -value : value;
}

// Parse a date cell to an ISO 'YYYY-MM-DD' using the chosen format, rejecting
// impossible dates (a 2026-13-40 stays unparsed, never rolls over).
String? parseDate(String raw, DateFormatChoice fmt) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  int? y, mo, d;
  if (fmt == DateFormatChoice.iso) {
    final m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (m == null) return null;
    y = int.parse(m.group(1)!);
    mo = int.parse(m.group(2)!);
    d = int.parse(m.group(3)!);
  } else {
    final m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})').firstMatch(s);
    if (m == null) return null;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    var yy = int.parse(m.group(3)!);
    if (yy < 100) yy += 2000; // a two-digit year is this century
    y = yy;
    if (fmt == DateFormatChoice.mdy) {
      mo = a;
      d = b;
    } else {
      d = a;
      mo = b;
    }
  }
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  // Reject a day the month cannot have (Feb 30, Apr 31).
  final lastDay = DateTime(y, mo + 1, 0).day;
  if (d > lastDay) return null;
  return '${y.toString().padLeft(4, '0')}-'
      '${mo.toString().padLeft(2, '0')}-'
      '${d.toString().padLeft(2, '0')}';
}

bool _typeIsIncome(String raw) {
  final s = raw.toLowerCase();
  return s.contains('income') ||
      s.contains('credit') ||
      s.contains('deposit') ||
      s.contains('received') ||
      s == 'in';
}

/// Build candidate transactions from data rows (header already removed by the
/// caller) and the user's column mapping. Rows missing a readable date or
/// amount are skipped and counted.
ImportResult buildImport(List<List<String>> dataRows, ColumnMap map,
    {String? defaultAccountId}) {
  final out = <Map<String, dynamic>>[];
  var skipped = 0;
  for (final row in dataRows) {
    final iso = parseDate(_cell(row, map.date), map.dateFormat);
    final amt = parseAmount(_cell(row, map.amount));
    if (iso == null || amt == null || amt == 0) {
      skipped += 1;
      continue;
    }
    String type;
    if (map.type != null && _cell(row, map.type!).isNotEmpty) {
      type = _typeIsIncome(_cell(row, map.type!)) ? 'income' : 'expense';
    } else {
      final isExpense = map.negativeIsExpense ? amt < 0 : amt > 0;
      type = isExpense ? 'expense' : 'income';
    }
    final label = map.description != null
        ? _cell(row, map.description!)
        : '';
    final tx = <String, dynamic>{
      'date': iso,
      'type': type,
      'label': label.isNotEmpty ? label : 'Imported',
      'amount': amt.abs(),
      'source': 'import',
    };
    if (defaultAccountId != null && defaultAccountId.isNotEmpty) {
      tx['accountId'] = defaultAccountId;
    }
    out.add(tx);
  }
  return ImportResult(out, skipped);
}
