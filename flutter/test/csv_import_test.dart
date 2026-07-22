// Unit suite for data/csv_import.dart: the pure parse + map engine behind the
// bank/GCash CSV importer. This is the money-correctness crux, so it is tested
// hard: amount cleaning and sign, the three date formats with impossible-date
// rejection, type from a column or from the sign, and unreadable rows being
// skipped and counted rather than guessed into wrong entries.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/csv_import.dart';

void main() {
  group('parseAmount', () {
    test('strips currency and thousands separators', () {
      expect(parseAmount('PHP 1,234.50'), 1234.50);
      expect(parseAmount('  2,000 '), 2000);
    });
    test('parentheses and minus read as negative', () {
      expect(parseAmount('(500.00)'), -500.0);
      expect(parseAmount('-250'), -250);
    });
    test('no number yields null', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('-'), isNull);
    });
  });

  group('parseDate', () {
    test('ISO', () {
      expect(parseDate('2026-07-15', DateFormatChoice.iso), '2026-07-15');
      expect(parseDate('2026/7/5', DateFormatChoice.iso), '2026-07-05');
    });
    test('month-first and day-first are disambiguated by the choice', () {
      expect(parseDate('07/15/2026', DateFormatChoice.mdy), '2026-07-15');
      expect(parseDate('15/07/2026', DateFormatChoice.dmy), '2026-07-15');
      // Same string, different meaning under each format.
      expect(parseDate('03/04/2026', DateFormatChoice.mdy), '2026-03-04');
      expect(parseDate('03/04/2026', DateFormatChoice.dmy), '2026-04-03');
    });
    test('two-digit year becomes this century', () {
      expect(parseDate('07/15/26', DateFormatChoice.mdy), '2026-07-15');
    });
    test('impossible dates are rejected, never rolled over', () {
      expect(parseDate('2026-02-30', DateFormatChoice.iso), isNull);
      expect(parseDate('2026-13-01', DateFormatChoice.iso), isNull);
      expect(parseDate('notadate', DateFormatChoice.iso), isNull);
    });
  });

  group('buildImport', () {
    List<List<String>> rows() => [
          ['2026-07-15', '-1,200.50', 'Groceries'],
          ['2026-07-16', '20000', 'Sweldo'],
          ['bad-date', '100', 'Junk'],
          ['2026-07-18', 'not a number', 'Also junk'],
        ];

    test('maps columns, sets sign from amount, skips unreadable rows', () {
      final r = buildImport(
          rows(), const ColumnMap(date: 0, amount: 1, description: 2));
      expect(r.imported, 2);
      expect(r.skipped, 2);
      final groceries = r.transactions[0];
      expect(groceries['date'], '2026-07-15');
      expect(groceries['type'], 'expense'); // negative
      expect(groceries['amount'], 1200.50); // stored positive
      expect(groceries['label'], 'Groceries');
      expect(groceries['source'], 'import');
      final sweldo = r.transactions[1];
      expect(sweldo['type'], 'income'); // positive
      expect(sweldo['amount'], 20000);
    });

    test('a flipped sign convention makes positives expenses', () {
      final r = buildImport(rows(),
          const ColumnMap(date: 0, amount: 1, negativeIsExpense: false));
      expect(r.transactions[0]['type'], 'income'); // negative now income
      expect(r.transactions[1]['type'], 'expense'); // positive now expense
    });

    test('a type column overrides the sign', () {
      final data = [
        ['2026-07-15', '500', 'Refund', 'credit'],
        ['2026-07-16', '500', 'Snack', 'debit'],
      ];
      final r = buildImport(
          data, const ColumnMap(date: 0, amount: 1, description: 2, type: 3));
      expect(r.transactions[0]['type'], 'income'); // credit
      expect(r.transactions[1]['type'], 'expense'); // debit
    });

    test('a missing description falls back to Imported', () {
      final r = buildImport([
        ['2026-07-15', '100', ''],
      ], const ColumnMap(date: 0, amount: 1, description: 2));
      expect(r.transactions[0]['label'], 'Imported');
    });

    test('no accountId by default, so no balance is moved', () {
      final r = buildImport([
        ['2026-07-15', '100', 'x'],
      ], const ColumnMap(date: 0, amount: 1));
      expect(r.transactions[0].containsKey('accountId'), false);
    });

    test('zero-amount rows are skipped, not logged', () {
      final r = buildImport([
        ['2026-07-15', '0', 'nothing'],
      ], const ColumnMap(date: 0, amount: 1));
      expect(r.imported, 0);
      expect(r.skipped, 1);
    });
  });

  group('parseCsv', () {
    test('handles quoting and blank lines', () {
      final p = parseCsv('Date,Amount,Note\n2026-07-15,100,"Food, and drinks"\n\n');
      expect(p.rows.length, 2);
      expect(p.rows[1][2], 'Food, and drinks');
    });
  });
}
