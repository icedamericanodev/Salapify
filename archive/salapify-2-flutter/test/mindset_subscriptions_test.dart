// Vectors for the subscriptions overview: annual prices normalize to a monthly
// figure, and the two totals always reconcile (annual == monthly * 12).
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/mindset_subscriptions.dart';

void main() {
  test('a monthly and an annual subscription normalize to per-month', () {
    final subs = [
      const Subscription(
        id: 'a',
        name: 'Streaming',
        amount: 149,
        cycle: 'monthly',
      ),
      const Subscription(
        id: 'b',
        name: 'Storage',
        amount: 1200,
        cycle: 'annual',
      ),
    ];
    final o = subscriptionsOverview(subs);
    expect(o.count, 2);
    // 149 + 1200/12 = 149 + 100 = 249
    expect(o.monthlyTotal, closeTo(249, 0.001));
    // annual is exactly monthly * 12, so the two figures cannot disagree
    expect(o.annualTotal, closeTo(2988, 0.001));
    expect(o.annualTotal, closeTo(o.monthlyTotal * 12, 0.0001));
  });

  test('per-item equivalents: annual divides by 12, monthly times 12', () {
    const annual = Subscription(
      id: 'x',
      name: 'Cloud',
      amount: 2400,
      cycle: 'annual',
    );
    expect(annual.monthlyEquivalent, closeTo(200, 0.001));
    expect(annual.annualEquivalent, closeTo(2400, 0.001));
    const monthly = Subscription(
      id: 'y',
      name: 'Music',
      amount: 99,
      cycle: 'monthly',
    );
    expect(monthly.monthlyEquivalent, closeTo(99, 0.001));
    expect(monthly.annualEquivalent, closeTo(1188, 0.001));
  });

  test('an empty list is a clean zero, never NaN', () {
    final o = subscriptionsOverview(const []);
    expect(o.count, 0);
    expect(o.monthlyTotal, 0);
    expect(o.annualTotal, 0);
  });

  test('junk in, safe out: bad rows are coerced, non-maps dropped', () {
    final subs = parseSubscriptions([
      {'id': 'a', 'name': 'Good', 'amount': 100, 'cycle': 'monthly'},
      {'id': 'b', 'amount': -50, 'cycle': 'weird'}, // negative, unknown cycle
      'not a map',
      42,
    ]);
    expect(subs.length, 2); // the two maps survive, the non-maps are dropped
    expect(subs[0].amount, 100);
    expect(subs[1].amount, 0); // negative coerced to 0
    expect(subs[1].cycle, 'monthly'); // unknown cycle coerced to monthly
    expect(subs[1].name, 'Subscription'); // missing name gets a safe label
    // Totals stay finite and sane.
    final o = subscriptionsOverview(subs);
    expect(o.monthlyTotal, closeTo(100, 0.001));
  });

  test('parseSubscriptions tolerates a non-list', () {
    expect(parseSubscriptions(null), isEmpty);
    expect(parseSubscriptions('nope'), isEmpty);
    expect(parseSubscriptions(7), isEmpty);
  });
}
