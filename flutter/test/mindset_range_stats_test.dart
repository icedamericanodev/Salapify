// Vectors for the rolling-window dashboard stats: days:1 is today only, days:30
// is a 30-day rolling window, future-dated rows are excluded.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_decisions.dart';

void main() {
  final now = DateTime(2026, 8, 15, 12);
  String iso(int daysAgo) => DateTime(
    2026,
    8,
    15,
    9,
  ).subtract(Duration(days: daysAgo)).toIso8601String();

  List<Map<String, dynamic>> decisions() => [
    {'outcome': MindsetOutcome.avoided, 'amount': 500, 'createdAt': iso(0)},
    {'outcome': MindsetOutcome.purchased, 'amount': 1000, 'createdAt': iso(0)},
    {'outcome': MindsetOutcome.avoided, 'amount': 800, 'createdAt': iso(5)},
    {'outcome': MindsetOutcome.avoided, 'amount': 999, 'createdAt': iso(29)},
    {'outcome': MindsetOutcome.avoided, 'amount': 1234, 'createdAt': iso(30)},
    // Future-dated: must never count.
    {
      'outcome': MindsetOutcome.avoided,
      'amount': 7777,
      'createdAt': DateTime(2026, 8, 20).toIso8601String(),
    },
  ];

  test('days:1 counts only today (matches mindsetTodayStats)', () {
    final r = mindsetRangeStats(decisions(), now, days: 1);
    final t = mindsetTodayStats(decisions(), now);
    expect(r.decisions, 2); // one avoided + one purchased today
    expect(r.avoided, 1);
    expect(r.purchased, 1);
    expect(r.moneyAvoided, closeTo(500, 0.001));
    // Same as the today-only function.
    expect(r.decisions, t.decisions);
    expect(r.moneyAvoided, closeTo(t.moneyAvoided, 0.001));
  });

  test('days:30 includes today..29 days ago, excludes 30+ and the future', () {
    final r = mindsetRangeStats(decisions(), now, days: 30);
    // today (avoided 500 + purchased 1000), 5 days (800), 29 days (999).
    // Excluded: 30 days ago (1234) and the future row (7777).
    expect(r.decisions, 4);
    expect(r.avoided, 3);
    expect(r.purchased, 1);
    expect(r.moneyAvoided, closeTo(500 + 800 + 999, 0.001));
  });

  test('junk in, safe out', () {
    expect(mindsetRangeStats(null, now, days: 30).decisions, 0);
    expect(mindsetRangeStats(['x', 42], now, days: 30).decisions, 0);
    // days floored to 1.
    expect(mindsetRangeStats(decisions(), now, days: 0).decisions, 2);
  });
}
