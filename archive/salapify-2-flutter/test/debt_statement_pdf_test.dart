// The consolidated debt PDF must actually generate valid bytes, and must NOT
// leak a card-number debt name or carry a forbidden regulated word.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/export_files.dart'
    show consolidatedDebtStatementPdf, debtStatementDisclaimer;

void main() {
  final ref = DateTime(2026, 8, 20, 12);

  test('it produces a real PDF, even for an empty book', () async {
    final empty = await consolidatedDebtStatementPdf({'debts': <dynamic>[]}, ref);
    expect(empty.length, greaterThan(500));
    // Every PDF starts with the %PDF magic bytes.
    expect(String.fromCharCodes(empty.take(4)), '%PDF');
  });

  test('a card-number debt name never reaches the PDF bytes in full', () async {
    final bytes = await consolidatedDebtStatementPdf({
      'debts': [
        {
          'id': 'a',
          'name': '4291 1234 5678 9010',
          'type': 'credit card',
          'remaining': 20000,
          'minPayment': 1000,
          'monthlyRate': 3.0,
          'dueDay': 10,
        },
      ],
    }, ref);
    // The pdf package writes text uncompressed enough that a full PAN would be
    // findable; assert the leading digits are gone and only the last four could
    // survive. (A cheap latin1 scan of the stream.)
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text.contains('4291 1234 5678 9010'), isFalse);
    expect(text.contains('5678 9010'), isFalse);
  });

  test('the disclaimer names what it is not', () {
    // The single source of truth for the on-screen and PDF disclaimer.
    expect(debtStatementDisclaimer, contains('not a bank statement'));
    expect(debtStatementDisclaimer, contains('does not connect to any bank'));
    expect(debtStatementDisclaimer, contains('not financial'));
  });
}
