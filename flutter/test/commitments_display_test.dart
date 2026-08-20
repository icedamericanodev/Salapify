// The two small display helpers new payment-due surfaces share:
// shortDueDate ("Jun 15") and daysUntilWords ("in 3 days" / "today" /
// "tomorrow" / "yesterday" / "3 days ago"). Both are pure and easy to pin
// exactly, unlike the widgets that call DateTime.now(), so the exact-value
// proof belongs here rather than in a flaky wall-clock widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/commitments.dart' show shortDueDate, daysUntilWords;

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
}
