// Unit suite for the pure part of data/export_files.dart: the CSV / row builder
// that both the CSV and Excel exports share. The binary xlsx/pdf builders are
// exercised only for "produces bytes, never throws" since their content is not
// text-diffable. Invariants: a header row, newest-first order, amounts as real
// numbers, account ids mapped to names, and junk never throwing.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/export_files.dart';

void main() {
  final data = {
    'accounts': [
      {'id': 'c', 'name': 'Cash'},
      {'id': 'g', 'name': 'GCash'},
    ],
    'transactions': [
      {'id': '1', 'date': '2026-07-05', 'type': 'expense', 'label': 'Food', 'amount': 250, 'accountId': 'c'},
      {'id': '2', 'date': '2026-07-15', 'type': 'income', 'label': 'Sweldo', 'amount': 20000, 'accountId': 'g'},
      {'id': '3', 'date': '2026-07-10', 'type': 'expense', 'label': 'Load, and snacks', 'amount': 100, 'accountId': 'c', 'note': 'with "quotes"'},
    ],
  };

  test('rows start with the header and list newest first', () {
    final rows = transactionRows(data);
    expect(rows.first, ['Date', 'Type', 'Label', 'Amount', 'Account', 'Note']);
    // Newest date first: 07-15, then 07-10, then 07-05.
    expect(rows[1][0], '2026-07-15');
    expect(rows[2][0], '2026-07-10');
    expect(rows[3][0], '2026-07-05');
  });

  test('amounts are real numbers and accounts map to names', () {
    final rows = transactionRows(data);
    final sweldo = rows[1];
    expect(sweldo[3], 20000); // amount as a number, not text
    expect(sweldo[4], 'GCash'); // accountId g -> GCash
  });

  test('CSV quotes commas and quotes in a label or note', () {
    final csv = transactionsCsv(data);
    expect(csv.contains('"Load, and snacks"'), true);
    expect(csv.contains('""quotes""'), true); // CSV-escaped inner quotes
    // Header present.
    expect(csv.startsWith('Date,Type,Label,Amount,Account,Note'), true);
  });

  test('the Excel builder produces non-empty bytes', () {
    final bytes = transactionsXlsx(data);
    expect(bytes, isNotEmpty);
  });

  test('the PDF builder produces a PDF, and empty data is safe', () async {
    final ref = DateTime(2026, 7, 15);
    final bytes = await reportPdf(data, ref);
    expect(bytes.length, greaterThan(100));
    // %PDF- magic header.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final empty = await reportPdf({}, ref);
    expect(empty.length, greaterThan(100));
  });

  test('junk data never throws', () {
    final junk = {
      'accounts': [null, 42, {'id': 5}],
      'transactions': [null, 7, {'amount': 'abc', 'date': 3}],
    };
    expect(() => transactionRows(junk), returnsNormally);
    expect(() => transactionsCsv(junk), returnsNormally);
    expect(() => transactionsXlsx(junk), returnsNormally);
  });
}
