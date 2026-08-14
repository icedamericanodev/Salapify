// Pure vectors for the Money Mindset decision-history helpers: the today
// summary counts and money-avoided sum, the recent ordering, the "when" label,
// and the flow-outcome mapping. No widgets, no store, so every number is pinned
// exactly.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_decisions.dart';

Map<String, dynamic> _d(
  String outcome, {
  double? amount,
  required DateTime at,
  String? item,
  String? note,
}) => {
  'id': 'd_${at.millisecondsSinceEpoch}',
  'itemName': item ?? 'thing',
  'amount': ?amount,
  'outcome': outcome,
  'note': ?note,
  'createdAt': at.toIso8601String(),
};

void main() {
  final now = DateTime(2026, 8, 14, 9, 5);
  DateTime todayAt(int h, int m) => DateTime(2026, 8, 14, h, m);
  final yesterday = DateTime(2026, 8, 13, 20, 0);
  final lastWeek = DateTime(2026, 8, 7, 12, 0);

  group('mindsetTodayStats', () {
    test('counts today only, and money avoided sums avoided amounts', () {
      final decisions = [
        _d(MindsetOutcome.purchased, amount: 500, at: todayAt(8, 0)),
        _d(MindsetOutcome.avoided, amount: 350, at: todayAt(8, 30)),
        _d(MindsetOutcome.avoided, amount: 150, at: todayAt(8, 45)),
        _d(MindsetOutcome.waiting, amount: 200, at: todayAt(8, 50)),
        // Yesterday's avoided must NOT count toward today.
        _d(MindsetOutcome.avoided, amount: 900, at: yesterday),
      ];
      final s = mindsetTodayStats(decisions, now);
      expect(s.decisions, 4);
      expect(s.purchased, 1);
      expect(s.avoided, 2);
      // 350 + 150, never the 500 purchased, the 200 waiting, or the 900
      // avoided yesterday.
      expect(s.moneyAvoided, 500.0);
    });

    test('a waiting or purchased buy never adds to money avoided', () {
      final s = mindsetTodayStats([
        _d(MindsetOutcome.purchased, amount: 1000, at: todayAt(7, 0)),
        _d(MindsetOutcome.waiting, amount: 2000, at: todayAt(7, 1)),
      ], now);
      expect(s.moneyAvoided, 0.0);
      expect(s.decisions, 2);
    });

    test('empty and junk are zero, never a crash', () {
      expect(mindsetTodayStats(null, now).decisions, 0);
      expect(mindsetTodayStats([1, 'x', null], now).decisions, 0);
    });
  });

  group('recentMindsetDecisions', () {
    test('newest first; a row with no timestamp sorts last', () {
      final a = _d(MindsetOutcome.avoided, at: todayAt(8, 0), item: 'a');
      final b = _d(MindsetOutcome.avoided, at: todayAt(9, 0), item: 'b');
      final c = _d(MindsetOutcome.avoided, at: yesterday, item: 'c');
      final junk = {'itemName': 'junk', 'outcome': 'avoided'};
      final out = recentMindsetDecisions([a, c, b, junk], limit: -1);
      expect(out.map((e) => e['itemName']), ['b', 'a', 'c', 'junk']);
    });

    test('limit caps the list', () {
      final list = [
        for (var i = 0; i < 8; i++)
          _d(MindsetOutcome.avoided, at: todayAt(1, i), item: 'i$i'),
      ];
      expect(recentMindsetDecisions(list, limit: 5).length, 5);
      expect(recentMindsetDecisions(list, limit: -1).length, 8);
    });
  });

  group('mindsetDecisionWhen', () {
    test('today shows a 12-hour clock time', () {
      expect(
        mindsetDecisionWhen(todayAt(10, 30).toIso8601String(), now),
        '10:30 AM',
      );
      expect(
        mindsetDecisionWhen(todayAt(0, 5).toIso8601String(), now),
        '12:05 AM',
      );
      expect(
        mindsetDecisionWhen(todayAt(13, 7).toIso8601String(), now),
        '1:07 PM',
      );
    });
    test('yesterday and older read as words then a date', () {
      expect(
        mindsetDecisionWhen(yesterday.toIso8601String(), now),
        'Yesterday',
      );
      expect(mindsetDecisionWhen(lastWeek.toIso8601String(), now), 'Aug 7');
    });
    test('junk is empty, never a throw', () {
      expect(mindsetDecisionWhen('not-a-date', now), '');
      expect(mindsetDecisionWhen(null, now), '');
    });
  });

  group('mapping and labels', () {
    test('flow outcome maps to the stored outcome', () {
      expect(mindsetOutcomeFromFlow('bought'), MindsetOutcome.purchased);
      expect(mindsetOutcomeFromFlow('skipped'), MindsetOutcome.avoided);
      expect(mindsetOutcomeFromFlow('waiting'), MindsetOutcome.waiting);
    });
    test('labels', () {
      expect(mindsetOutcomeLabel(MindsetOutcome.purchased), 'Purchased');
      expect(mindsetOutcomeLabel(MindsetOutcome.avoided), 'Avoided');
      expect(mindsetOutcomeLabel(MindsetOutcome.waiting), 'Waiting');
      expect(mindsetOutcomeLabel('nonsense'), '');
    });
  });
}
