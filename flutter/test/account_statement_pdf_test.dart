// The per account statement PDF is read only and built from the golden locked
// engine. A full render needs platform fonts, so here we prove it produces a
// valid, non-empty PDF for the ordinary cases: an account with activity, a card
// carrying its balance as 'remaining', and an account with nothing this month.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/export_files.dart';

// A PDF file begins with the bytes for "%PDF".
bool _isPdf(List<int> bytes) =>
    bytes.length > 4 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ref = DateTime(2026, 8, 15);
  final data = {
    'accounts': [
      {'id': 'a1', 'name': 'BPI Savings', 'kind': 'savings', 'balance': 5000.0},
    ],
    'debts': [
      {
        'id': 'c1',
        'name': 'BPI Credit',
        'remaining': 3200.0,
        'creditLimit': 50000.0,
        'last4': '4821',
      },
    ],
    'transactions': [
      {
        'id': 't1',
        'type': 'income',
        'flow': 'in',
        'accountId': 'a1',
        'amount': 20000.0,
        'label': 'Sweldo',
        'date': '2026-08-05',
      },
      {
        'id': 't2',
        'type': 'expense',
        'flow': 'out',
        'accountId': 'a1',
        'amount': 500.0,
        'label': 'Groceries',
        'date': '2026-08-06',
      },
    ],
  };

  test('an account with activity produces a valid PDF', () async {
    final account = (data['accounts'] as List).first as Map<String, dynamic>;
    final bytes = await accountStatementPdf(data, account, ref);
    expect(_isPdf(bytes), isTrue);
    expect(bytes.length, greaterThan(500));
  });

  test(
    'a credit card (balance under "remaining") produces a valid PDF',
    () async {
      final card = (data['debts'] as List).first as Map<String, dynamic>;
      final bytes = await accountStatementPdf(data, card, ref);
      expect(_isPdf(bytes), isTrue);
    },
  );

  test(
    'an account with no transactions this month still produces a PDF',
    () async {
      final quietData = {
        'accounts': [
          {'id': 'z9', 'name': 'Empty', 'kind': 'cash', 'balance': 0.0},
        ],
        'transactions': const [],
      };
      final account =
          (quietData['accounts'] as List).first as Map<String, dynamic>;
      final bytes = await accountStatementPdf(quietData, account, ref);
      expect(_isPdf(bytes), isTrue);
    },
  );
}
