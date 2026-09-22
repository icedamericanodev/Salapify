// Unit suite for money/mindset_purchase.dart (Money Mindset Phase 5).
// Hand-computed literals, edges first: a non-positive amount, no goal
// picked, and a goal already fully funded all have to read as "nothing to
// show" before the reliable cases are worth trusting.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_purchase.dart';

void main() {
  final now = DateTime(2026, 7, 15);

  group('subscriptionEquivalents, the edges first', () {
    test('a zero amount reads as nothing to show', () {
      final r = subscriptionEquivalents(0, 'monthly');
      expect(r['monthly'], 0.0);
      expect(r['annual'], 0.0);
    });

    test('a negative amount reads as nothing to show', () {
      final r = subscriptionEquivalents(-100, 'monthly');
      expect(r['monthly'], 0.0);
      expect(r['annual'], 0.0);
    });

    test('a non-finite amount reads as nothing to show', () {
      final r = subscriptionEquivalents(double.nan, 'monthly');
      expect(r['monthly'], 0.0);
      expect(r['annual'], 0.0);
    });

    test('an unrecognized frequency falls back to monthly', () {
      final r = subscriptionEquivalents(120, 'daily');
      expect(r['monthly'], 120.0);
      expect(r['annual'], 1440.0);
    });

    test('monthly billing is its own monthly figure, times 12 a year', () {
      final r = subscriptionEquivalents(149, 'monthly');
      expect(r['monthly'], 149.0);
      expect(r['annual'], 1788.0);
    });

    test('weekly billing scales by 52 weeks a year', () {
      final r = subscriptionEquivalents(100, 'weekly');
      expect(r['annual'], 5200.0);
      expect(r['monthly'], closeTo(433.33, 0.01));
    });

    test('quarterly billing scales by 4 quarters a year', () {
      final r = subscriptionEquivalents(300, 'quarterly');
      expect(r['annual'], 1200.0);
      expect(r['monthly'], 100.0);
    });

    test('annual billing is its own annual figure, split evenly by month', () {
      final r = subscriptionEquivalents(1200, 'annual');
      expect(r['annual'], 1200.0);
      expect(r['monthly'], 100.0);
    });
  });

  group('goalTradeoff, the edges first', () {
    Map<String, dynamic> activeGoal({
      double target = 12000,
      double saved = 6000,
      String targetDate = '2027-01-15',
      String frequency = 'monthly',
      String name = 'Emergency fund',
    }) => {
      'name': name,
      'target': target,
      'saved': saved,
      'targetDate': targetDate,
      'frequency': frequency,
    };

    test('no goal selected returns null', () {
      expect(goalTradeoff(goal: null, purchaseAmount: 500, now: now), isNull);
    });

    test('no usable purchase amount returns null', () {
      expect(
        goalTradeoff(goal: activeGoal(), purchaseAmount: null, now: now),
        isNull,
      );
      expect(
        goalTradeoff(goal: activeGoal(), purchaseAmount: 0, now: now),
        isNull,
      );
      expect(
        goalTradeoff(goal: activeGoal(), purchaseAmount: -50, now: now),
        isNull,
      );
    });

    test('a goal already fully funded has nothing left to trade off', () {
      final info = goalTradeoff(
        goal: activeGoal(target: 1000, saved: 1000),
        purchaseAmount: 200,
        now: now,
      );
      expect(info, isNull);
    });

    test('a goal saved past its target still reads as nothing left, never a '
        'negative percent', () {
      final info = goalTradeoff(
        goal: activeGoal(target: 1000, saved: 1500),
        purchaseAmount: 200,
        now: now,
      );
      expect(info, isNull);
    });

    test('a goal with a real deadline reports pesos, percent, and a delay '
        'estimate from the same requiredContribution/goalWhatIf engine Goals '
        'already shows', () {
      // requiredContribution on this goal asks for 1000/month (see
      // goal_plan_test.dart's own "active deadline" vector): 6000 short
      // over 6 whole months to 2027-01-15.
      final info = goalTradeoff(
        goal: activeGoal(),
        purchaseAmount: 3000,
        now: now,
      );
      expect(info, isNotNull);
      expect(info!['goalName'], 'Emergency fund');
      expect(info['remaining'], 6000.0);
      expect(info['purchaseAmount'], 3000.0);
      expect(info['percentOfRemaining'], 50.0);
      // Without the purchase: ceil(6000/1000) = 6 months.
      // With it: ceil((6000+3000)/1000) = 9 months. 3 months later.
      final delay = info['delay'] as Map<String, dynamic>;
      expect(delay['periods'], 3);
      expect(delay['frequency'], 'monthly');
    });

    test('a weekly-frequency goal reports the delay in weeks', () {
      // requiredContribution's own weekly vector: 231/week (ceil of 230.77).
      final info = goalTradeoff(
        goal: activeGoal(frequency: 'weekly'),
        purchaseAmount: 2000,
        now: now,
      );
      expect(info, isNotNull);
      // ceil(6000/231) = 26; ceil(8000/231) = 35; delayed by 9 weeks.
      final delay = info!['delay'] as Map<String, dynamic>;
      expect(delay['periods'], 9);
      expect(delay['frequency'], 'weekly');
    });

    test('no deadline means a percent but never a guessed delay', () {
      final info = goalTradeoff(
        goal: activeGoal(targetDate: ''),
        purchaseAmount: 500,
        now: now,
      );
      expect(info, isNotNull);
      expect(info!['percentOfRemaining'], closeTo(8.33, 0.01));
      expect(info['delay'], isNull);
    });

    test('a purchase too small to move the required pace by a whole period '
        'omits the delay rather than claiming a fractional one', () {
      // remaining 5500 over 6 months (Jul 15 to Jan 15) needs
      // ceil(5500/6) = 917/month; that rounding leaves 917*6 - 5500 = 2
      // pesos of slack before a 1-peso purchase pushes the projection
      // into a 7th month, so it stays at 6 months either way.
      final info = goalTradeoff(
        goal: activeGoal(saved: 6500),
        purchaseAmount: 1,
        now: now,
      );
      expect(info, isNotNull);
      expect(info!['delay'], isNull);
    });

    test('a blank goal name falls back to a safe label', () {
      final info = goalTradeoff(
        goal: activeGoal(name: ''),
        purchaseAmount: 500,
        now: now,
      );
      expect(info!['goalName'], 'this goal');
    });
  });
}
