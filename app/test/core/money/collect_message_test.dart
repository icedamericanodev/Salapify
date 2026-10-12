import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/collect_message.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/models/models.dart';

/// Asking for money owed to you (D31): the overdue tag and the message the
/// share sheet carries.
void main() {
  final DateTime now = DateTime(2026, 9, 18, 12);

  Debt debt({
    String person = 'Ana Santos',
    String? due,
    bool settled = false,
    String? archivedAt,
    int total = 1500,
    int paid = 0,
  }) => Debt(
    id: 'd1',
    person: person,
    direction: DebtDirection.owedToMe,
    totalAmount: Money.pesos(total),
    paidAmount: Money.pesos(paid),
    isSettled: settled,
    dueDate: due,
    archivedAt: archivedAt,
  );

  group('overdue', () {
    test('a named date two days past is two days overdue', () {
      expect(overdueDays(debt(due: 'Sep 16'), now), 2);
    });

    test('an ISO date in the past counts too', () {
      expect(overdueDays(debt(due: '2026-09-10'), now), 8);
    });

    test('today and the future are not overdue', () {
      expect(overdueDays(debt(due: 'today'), now), isNull);
      expect(overdueDays(debt(due: 'Sep 20'), now), isNull);
    });

    test('a bare day of the month means the NEXT one, never overdue', () {
      expect(overdueDays(debt(due: '15th'), now), isNull);
    });

    test(
      'settled, archived, unreadable and missing dates are never overdue',
      () {
        expect(overdueDays(debt(due: 'Sep 16', settled: true), now), isNull);
        expect(
          overdueDays(debt(due: 'Sep 16', archivedAt: '2026-09-17'), now),
          isNull,
        );
        expect(overdueDays(debt(due: 'sa Biyernes'), now), isNull);
        expect(overdueDays(debt(), now), isNull);
      },
    );
  });

  group('the message', () {
    test('names the first name and what is still owed, not the total', () {
      final String m = collectionMessage(
        debt(total: 1500, paid: 500, due: 'Sep 16'),
        now: now,
      );
      expect(m, startsWith('Hi Ana,'));
      expect(m, contains('₱1,000.00'));
      expect(m, isNot(contains('1,500')));
      expect(m, contains('(due Sep 16)'));
    });

    test('never sounds like a demand', () {
      final String m = collectionMessage(debt(due: 'Sep 1'), now: now);
      for (final String harsh in <String>['overdue', 'late', 'pay now']) {
        expect(m.toLowerCase(), isNot(contains(harsh)));
      }
    });

    test('no due date leaves no empty brackets', () {
      final String m = collectionMessage(debt(), now: now);
      expect(m, isNot(contains('(')));
    });
  });
}
