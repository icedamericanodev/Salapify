import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/usual_entries.dart';
import 'package:salapify/models/models.dart';

/// The one-tap "usual" chips in the Log sheet (D31). Pure, read from the
/// ledger, nothing stored.
void main() {
  int clock = 0;
  Transaction tx(
    String? merchant,
    String amount, {
    String category = 'Transport',
    String account = 'cash',
    TransactionType type = TransactionType.expense,
    bool sample = false,
  }) => Transaction(
    id: 'tx_${clock++}',
    type: type,
    amount: Money.fromDouble(double.parse(amount)),
    category: category,
    accountId: account,
    date: '2026-10-09',
    createdAt: clock,
    merchant: merchant,
    isSample: sample,
  );

  test('a repeated spend becomes a chip, a one-off does not', () {
    clock = 0;
    final List<UsualEntry> u = usualEntries(<Transaction>[
      tx('Jeep', '13'),
      tx('Jeep', '13'),
      tx('Jeep', '13'),
      tx('Shoes', '2500', category: 'Shopping'),
    ]);
    expect(u.map((UsualEntry e) => e.label), <String>['Jeep']);
    expect(u.single.amount, const Money.pesos(13));
    expect(u.single.count, 3);
    expect(u.single.merchant, 'Jeep');
  });

  test('a different amount is a different habit, never merged', () {
    // Filling the wrong one fills the wrong money.
    clock = 0;
    final List<UsualEntry> u = usualEntries(<Transaction>[
      tx('Kape', '150', category: 'Food & Dining'),
      tx('Kape', '150', category: 'Food & Dining'),
      tx('Kape', '180', category: 'Food & Dining'),
      tx('Kape', '180', category: 'Food & Dining'),
    ]);
    expect(u.map((UsualEntry e) => e.amount.centavos).toSet(), <int>{
      15000,
      18000,
    });
  });

  test('case and spaces in the merchant do not split one habit in two', () {
    clock = 0;
    final List<UsualEntry> u = usualEntries(<Transaction>[
      tx('Jeep', '13'),
      tx('  jeep ', '13'),
    ]);
    expect(u, hasLength(1));
    expect(u.single.count, 2);
  });

  test('no merchant groups by category, and the chip says the category', () {
    clock = 0;
    final List<UsualEntry> u = usualEntries(<Transaction>[
      tx(null, '50', category: 'Load'),
      tx('', '50', category: 'Load'),
    ]);
    expect(u.single.label, 'Load');
    expect(u.single.merchant, isNull);
  });

  test('income, transfers and the examples are never a usual', () {
    clock = 0;
    final List<UsualEntry> u = usualEntries(<Transaction>[
      tx('Salary', '20000', type: TransactionType.income),
      tx('Salary', '20000', type: TransactionType.income),
      tx(null, '500', type: TransactionType.transfer, category: 'Transfer'),
      tx(null, '500', type: TransactionType.transfer, category: 'Transfer'),
      tx('Jollibee', '250', sample: true),
      tx('Jollibee', '250', sample: true),
    ]);
    expect(u, isEmpty);
  });

  test('most repeated first, then the most recent, and at most six', () {
    clock = 0;
    final List<Transaction> ledger = <Transaction>[
      for (int i = 0; i < 4; i++) tx('Jeep', '13'),
      tx('Load', '50'),
      tx('Load', '50'),
      tx('Kape', '150'),
      tx('Kape', '150'),
      for (final String m in <String>[
        'A',
        'B',
        'C',
        'D',
        'E',
      ]) ...<Transaction>[tx(m, '1'), tx(m, '1')],
    ];
    final List<UsualEntry> u = usualEntries(ledger);
    expect(u, hasLength(6));
    expect(u.first.label, 'Jeep');
    // Among the twos, the newest wins: E was logged last.
    expect(u[1].label, 'E');
  });
}
