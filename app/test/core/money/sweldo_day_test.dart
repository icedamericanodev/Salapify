import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/payday_schedule.dart';
import 'package:salapify/core/money/sweldo_day.dart';
import 'package:salapify/models/models.dart';

/// When the Sweldo Day card shows (D31): the payday and the day after, the
/// payday only for weekly pay, never for "no fixed payday", and gone once
/// money has moved into a Set aside account since that payday.
void main() {
  final PaydaySchedule twiceAMonth = PaydaySchedule(const <int>[15, 30]);

  const Account cash = Account(
    id: 'acc_cash',
    name: 'Cash',
    kind: AccountKind.cash,
    institution: 'Cash',
    balance: Money.pesos(5000),
    monogram: 'C',
  );
  const Account ipon = Account(
    id: 'acc_ipon',
    name: 'Ipon',
    kind: AccountKind.bank,
    institution: 'Bank',
    balance: Money.pesos(0),
    monogram: 'I',
    purpose: AccountPurpose.protected,
  );

  Transaction move(String date, {String to = 'acc_ipon'}) => Transaction(
    id: 'tx_$date$to',
    type: TransactionType.transfer,
    amount: const Money.pesos(1000),
    category: 'Transfer',
    accountId: 'acc_cash',
    toAccountId: to,
    date: date,
    createdAt: 1,
  );

  DateTime? on(
    DateTime now, {
    PaydaySchedule? schedule,
    bool noPayday = false,
    List<Transaction> txs = const <Transaction>[],
  }) => sweldoDayFor(
    schedule: noPayday ? null : schedule ?? twiceAMonth,
    now: now,
    transactions: txs,
    accounts: const <Account>[cash, ipon],
  );

  test('the payday and the day after, and not before or after that', () {
    expect(on(DateTime(2026, 10, 14, 9)), isNull);
    expect(on(DateTime(2026, 10, 15, 9)), DateTime(2026, 10, 15));
    expect(on(DateTime(2026, 10, 16, 21)), DateTime(2026, 10, 15));
    expect(on(DateTime(2026, 10, 17, 9)), isNull);
  });

  test('weekly pay: the payday only, or it would be up two days in seven', () {
    final PaydaySchedule fridays = PaydaySchedule.weekly(DateTime.friday);
    // 2026-10-16 is a Friday.
    expect(on(DateTime(2026, 10, 16), schedule: fridays), isNotNull);
    expect(on(DateTime(2026, 10, 17), schedule: fridays), isNull);
  });

  test('never for no fixed payday, and never with no payday set', () {
    expect(
      on(
        DateTime(2026, 10, 15),
        schedule: PaydaySchedule.lastUntil(DateTime(2026, 10, 25)),
      ),
      isNull,
    );
    expect(on(DateTime(2026, 10, 15), noPayday: true), isNull);
  });

  test('a move into Set aside since the payday ends it; a move before it, '
      'or into an everyday account, does not', () {
    final DateTime payday = DateTime(2026, 10, 15, 9);
    expect(on(payday, txs: <Transaction>[move('2026-10-15')]), isNull);
    expect(
      on(payday, txs: <Transaction>[move('2026-10-14')]),
      isNotNull,
      reason: 'last cycle\'s saving answered this payday',
    );
    expect(
      on(payday, txs: <Transaction>[move('2026-10-15', to: 'acc_cash')]),
      isNotNull,
      reason: 'a move into an everyday account saves nothing',
    );
  });

  test('a move that was taken back does not count as saved', () {
    final Transaction undone = Transaction(
      id: 'tx_undone',
      type: TransactionType.transfer,
      amount: const Money.pesos(1000),
      category: 'Transfer',
      accountId: 'acc_cash',
      toAccountId: 'acc_ipon',
      date: '2026-10-15',
      createdAt: 1,
      status: TransactionStatus.excluded,
    );
    expect(on(DateTime(2026, 10, 15), txs: <Transaction>[undone]), isNotNull);
  });
}
