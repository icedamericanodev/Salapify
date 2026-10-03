// Pure tests for the per-account This month In/Out/Net. Every literal is an
// amount we put on a transaction; the assertions add those same amounts back up
// by direction, so nothing is checked against a number this file invents.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/account_flow.dart';

void main() {
  // One account 'a', in month 2026-08: salary in, groceries out, a transfer OUT
  // to 'b', a transfer IN from 'c', an expense in a DIFFERENT month, and an
  // unrelated account's transaction. Only the four August 'a' movements count.
  final data = {
    'transactions': [
      {'accountId': 'a', 'type': 'income', 'amount': 30000, 'date': '2026-08-01'},
      {'accountId': 'a', 'type': 'expense', 'amount': 2450, 'date': '2026-08-03'},
      {
        'type': 'transfer', 'amount': 5000, 'date': '2026-08-10',
        'transferFromId': 'a', 'transferToId': 'b',
      },
      {
        'type': 'transfer', 'amount': 1200, 'date': '2026-08-12',
        'transferFromId': 'c', 'transferToId': 'a',
      },
      // Last month, must be ignored.
      {'accountId': 'a', 'type': 'expense', 'amount': 9999, 'date': '2026-07-30'},
      // Another account, must be ignored.
      {'accountId': 'b', 'type': 'income', 'amount': 8888, 'date': '2026-08-05'},
    ],
  };

  test('in is salary plus the transfer received', () {
    final f = accountMonthFlow(data, 'a', '2026-08');
    expect(f.inflow, 31200); // 30000 + 1200
  });

  test('out is the expense plus the transfer sent', () {
    final f = accountMonthFlow(data, 'a', '2026-08');
    expect(f.outflow, 7450); // 2450 + 5000
  });

  test('net is in minus out', () {
    final f = accountMonthFlow(data, 'a', '2026-08');
    expect(f.net, 31200 - 7450);
  });

  test('an expense with no flow field counts as out, not in', () {
    // flow absent and type expense: the fallback must NOT read it as income.
    final f = accountMonthFlow({
      'transactions': [
        {'accountId': 'a', 'type': 'expense', 'amount': 500, 'date': '2026-08-02'},
      ],
    }, 'a', '2026-08');
    expect(f.inflow, 0);
    expect(f.outflow, 500);
  });

  test('an explicit flow overrides the type fallback', () {
    // A refund posted as an inflow even though it is not typed income.
    final f = accountMonthFlow({
      'transactions': [
        {
          'accountId': 'a', 'type': 'expense', 'flow': 'in',
          'amount': 700, 'date': '2026-08-02',
        },
      ],
    }, 'a', '2026-08');
    expect(f.inflow, 700);
    expect(f.outflow, 0);
  });

  test('the same transfer is an out for the sender and an in for the receiver', () {
    final t = {
      'transactions': [
        {
          'type': 'transfer', 'amount': 5000, 'date': '2026-08-10',
          'transferFromId': 'a', 'transferToId': 'b',
        },
      ],
    };
    expect(accountMonthFlow(t, 'a', '2026-08').outflow, 5000);
    expect(accountMonthFlow(t, 'a', '2026-08').inflow, 0);
    expect(accountMonthFlow(t, 'b', '2026-08').inflow, 5000);
    expect(accountMonthFlow(t, 'b', '2026-08').outflow, 0);
  });

  test('an empty month is all zeros, never a crash', () {
    final f = accountMonthFlow(const {}, 'a', '2026-08');
    expect(f.inflow, 0);
    expect(f.outflow, 0);
    expect(f.net, 0);
  });
}
