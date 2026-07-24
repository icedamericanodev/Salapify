// The milestone engine: only genuinely achieved wins appear, every amount
// comes from the data, and junk never throws. Net-new logic, unit-tested with
// hard invariants (no RN counterpart to golden-replay).

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/milestones.dart';

void main() {
  group('debt paid off', () {
    test(
      'a zeroed debt with logged payments is a win, amount = payments sum',
      () {
        final ms = milestones({
          'debts': [
            {'id': 'd1', 'name': 'BPI card', 'remaining': 0},
          ],
          'payments': [
            {'id': 'p1', 'debtId': 'd1', 'amount': 3000, 'date': '2026-06-01'},
            {'id': 'p2', 'debtId': 'd1', 'amount': 2000, 'date': '2026-07-01'},
            {
              'id': 'p3',
              'debtId': 'other',
              'amount': 999,
              'date': '2026-07-01',
            },
          ],
        });
        expect(ms.length, 1);
        final m = ms.single;
        expect(m.kind, 'debt');
        expect(m.name, 'BPI card');
        expect(m.amount, 5000);
        expect(m.headline, 'Debt free');
        expect(m.sub, contains('BPI card'));
      },
    );

    test('a debt zeroed by hand (no payments) is NOT a win', () {
      final ms = milestones({
        'debts': [
          {'id': 'd1', 'name': 'Mystery', 'remaining': 0},
        ],
        'payments': [],
      });
      expect(ms, isEmpty);
    });

    test('a debt still owing is not a win', () {
      final ms = milestones({
        'debts': [
          {'id': 'd1', 'name': 'BPI card', 'remaining': 100},
        ],
        'payments': [
          {'id': 'p1', 'debtId': 'd1', 'amount': 3000, 'date': '2026-06-01'},
        ],
      });
      expect(ms, isEmpty);
    });
  });

  group('goal funded', () {
    test('saved at or past a positive target is a win', () {
      final ms = milestones({
        'goals': [
          {'name': 'Emergency fund', 'target': 10000, 'saved': 10000},
          {'name': 'Japan trip', 'target': 50000, 'saved': 20000},
          {'name': 'No target', 'target': 0, 'saved': 500},
        ],
      });
      expect(ms.length, 1);
      expect(ms.single.kind, 'goal');
      expect(ms.single.name, 'Emergency fund');
      expect(ms.single.amount, 10000);
    });
  });

  group('utang settled', () {
    test('a receivable settled via the paid flag or via payments', () {
      final ms = milestones({
        'receivables': [
          {'person': 'Migs', 'amount': 500, 'paid': true, 'payments': []},
          {
            'person': 'Ana',
            'amount': 800,
            'paid': false,
            'payments': [
              {'amount': 800, 'date': '2026-07-01'},
            ],
          },
          {'person': 'Leo', 'amount': 300, 'paid': false, 'payments': []},
        ],
      });
      expect(ms.length, 2);
      expect(ms[0].kind, 'utangIn');
      expect(ms[0].name, 'Migs');
      expect(ms[1].name, 'Ana');
      expect(ms[1].amount, 800);
    });

    test('a settled payable reads as paid back', () {
      final ms = milestones({
        'payables': [
          {'person': 'Kuya Jun', 'amount': 2000, 'paid': true, 'payments': []},
        ],
      });
      expect(ms.single.kind, 'utangOut');
      expect(ms.single.headline, 'All paid back');
      expect(ms.single.sub, contains('Kuya Jun'));
    });

    test('a zero-amount utang is never a win', () {
      final ms = milestones({
        'receivables': [
          {'person': 'Migs', 'amount': 0, 'paid': true, 'payments': []},
        ],
      });
      expect(ms, isEmpty);
    });
  });

  test('order is debts, then goals, then utang both ways', () {
    final ms = milestones({
      'debts': [
        {'id': 'd1', 'name': 'Card', 'remaining': 0},
      ],
      'payments': [
        {'id': 'p1', 'debtId': 'd1', 'amount': 100, 'date': '2026-06-01'},
      ],
      'goals': [
        {'name': 'Fund', 'target': 100, 'saved': 100},
      ],
      'receivables': [
        {'person': 'A', 'amount': 50, 'paid': true, 'payments': []},
      ],
      'payables': [
        {'person': 'B', 'amount': 60, 'paid': true, 'payments': []},
      ],
    });
    expect(ms.map((m) => m.kind).toList(), [
      'debt',
      'goal',
      'utangIn',
      'utangOut',
    ]);
  });

  test('junk never throws and yields no milestones', () {
    expect(milestones(null), isEmpty);
    expect(milestones('junk'), isEmpty);
    expect(
      milestones({
        'debts': ['x', 42],
        'goals': 'nope',
        'receivables': [
          {'amount': 'abc', 'paid': 'yes'},
        ],
        'payments': {'not': 'a list'},
      }),
      isEmpty,
    );
  });

  group('milestoneText', () {
    const m = Milestone(
      kind: 'goal',
      name: 'Fund',
      amount: 10000,
      headline: 'Goal reached',
      sub: 'Fund, fully funded',
      amountLabel: 'Saved up',
    );

    test('includes the amount row when shown', () {
      final t = milestoneText(m, (n) => 'P$n');
      expect(t, contains('Goal reached: Fund, fully funded.'));
      expect(t, contains('Saved up: P10000.0.'));
      expect(t, contains('Salapify'));
    });

    test('hideAmounts drops the amount row', () {
      final t = milestoneText(m, (n) => 'P$n', true);
      expect(t.contains('Saved up'), isFalse);
    });
  });
}
