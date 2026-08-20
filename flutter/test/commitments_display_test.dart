// The two small display helpers new payment-due surfaces share:
// shortDueDate ("Jun 15") and daysUntilWords ("in 3 days" / "today" /
// "tomorrow" / "yesterday" / "3 days ago"). Both are pure and easy to pin
// exactly, unlike the widgets that call DateTime.now(), so the exact-value
// proof belongs here rather than in a flaky wall-clock widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/commitments.dart'
    show shortDueDate, daysUntilWords, debtsWithSchedule;

void main() {
  group('shortDueDate', () {
    test('month and day, no year, no leading zero', () {
      expect(shortDueDate(DateTime(2026, 6, 15)), 'Jun 15');
      expect(shortDueDate(DateTime(2026, 1, 1)), 'Jan 1');
      expect(shortDueDate(DateTime(2026, 12, 31)), 'Dec 31');
    });
  });

  group('daysUntilWords', () {
    test('today, tomorrow and yesterday are named, not counted', () {
      expect(daysUntilWords(0), 'today');
      expect(daysUntilWords(1), 'tomorrow');
      expect(daysUntilWords(-1), 'yesterday');
    });

    test('a future count reads "in N days"', () {
      expect(daysUntilWords(3), 'in 3 days');
      expect(daysUntilWords(14), 'in 14 days');
    });

    test('a past count reads "N days ago"', () {
      expect(daysUntilWords(-3), '3 days ago');
      expect(daysUntilWords(-14), '14 days ago');
    });
  });

  group('debtsWithSchedule', () {
    final from = DateTime(2026, 6, 1);

    test('counts a debt with a due day and money still owed', () {
      final debts = [
        {'name': 'Card', 'remaining': 5000, 'dueDay': 15},
      ];
      expect(debtsWithSchedule(debts, from).length, 1);
    });

    test('a paid-off debt does not count, even with a due day', () {
      final debts = [
        {'name': 'Card', 'remaining': 0, 'dueDay': 15},
      ];
      expect(debtsWithSchedule(debts, from), isEmpty);
    });

    test('a debt with no schedule does not count', () {
      final debts = [
        {'name': 'Family loan', 'remaining': 5000, 'dueDay': 0},
      ];
      expect(debtsWithSchedule(debts, from), isEmpty);
    });

    test('counts each qualifying debt once, ignores junk entries', () {
      final debts = [
        {'name': 'Card', 'remaining': 5000, 'dueDay': 15},
        {'name': 'Loan', 'remaining': 2000, 'dueDay': 3},
        {'name': 'Settled', 'remaining': 0, 'dueDay': 10},
        'not a map',
      ];
      expect(debtsWithSchedule(debts, from).length, 2);
    });

    test('a non-list debts value counts as none', () {
      expect(debtsWithSchedule(null, from), isEmpty);
    });
  });
}
