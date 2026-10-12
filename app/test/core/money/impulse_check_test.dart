import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/impulse_check.dart';

/// The prototype's own weights and thresholds, and the boundaries that decide
/// which verdict somebody actually sees.
void main() {
  ImpulseResult run({
    NeedOrWant need = NeedOrWant.want,
    UseFrequency use = UseFrequency.weekly,
    CheaperAlternative cheaper = CheaperAlternative.yes,
    double price = 4500,
    double income = 35000,
  }) => checkImpulse(
    price: price,
    monthlyIncome: income,
    needOrWant: need,
    useFrequency: use,
    cheaperAlternative: cheaper,
  );

  group('the score', () {
    test('the prototype default is 45, which is a yellow', () {
      // want 10 + weekly 30 + cheaper-exists 5.
      final ImpulseResult r = run();
      expect(r.score, 45);
      expect(r.verdict, ImpulseVerdict.yellow);
    });

    test('the best possible case is 100', () {
      final ImpulseResult r = run(
        need: NeedOrWant.need,
        use: UseFrequency.daily,
        cheaper: CheaperAlternative.no,
      );
      expect(r.score, 100);
      expect(r.verdict, ImpulseVerdict.green);
    });

    test('the worst possible case is 25, not zero', () {
      // Every question carries a floor, so nothing scores nothing. Worth
      // pinning: a zero would make the bar look broken rather than damning.
      final ImpulseResult r = run(
        need: NeedOrWant.want,
        use: UseFrequency.rarely,
        cheaper: CheaperAlternative.yes,
      );
      expect(r.score, 25);
      expect(r.verdict, ImpulseVerdict.red);
    });
  });

  group('the thresholds, at the boundary', () {
    test('70 is green and 69 would not be', () {
      // need 40 + weekly 30 + cheaper 5 = 75, green.
      expect(run(need: NeedOrWant.need).score, 75);
      expect(run(need: NeedOrWant.need).verdict, ImpulseVerdict.green);

      // want 10 + daily 40 + no-cheaper 20 = 70, exactly the boundary.
      final ImpulseResult edge = run(
        use: UseFrequency.daily,
        cheaper: CheaperAlternative.no,
      );
      expect(edge.score, 70);
      expect(
        edge.verdict,
        ImpulseVerdict.green,
        reason: '70 is green in the prototype, not amber. It is >= not >.',
      );
    });

    test('40 is yellow and 39 is red', () {
      // want 10 + rarely 10 + no-cheaper 20 = 40, exactly the boundary.
      final ImpulseResult edge = run(
        use: UseFrequency.rarely,
        cheaper: CheaperAlternative.no,
      );
      expect(edge.score, 40);
      expect(edge.verdict, ImpulseVerdict.yellow);

      // want 10 + rarely 10 + cheaper 5 = 25, below it.
      expect(run(use: UseFrequency.rarely).verdict, ImpulseVerdict.red);
    });
  });

  group('hours of work', () {
    test('4,500 against a 35,000 salary is about twenty hours', () {
      // 35,000 / 160 = 218.75 an hour. 4,500 / 218.75 = 20.57.
      expect(run().hoursOfWork, closeTo(20.57, 0.01));
    });

    test('no salary means no figure, rather than zero hours', () {
      expect(
        run(income: 0).hoursOfWork,
        isNull,
        reason: '"0.0 hours of work" reads as free',
      );
    });

    test('a free item has no hours either', () {
      expect(run(price: 0).hoursOfWork, isNull);
    });
  });

  group('the words', () {
    test('every verdict says what to DO, not just how it scored', () {
      for (final ImpulseResult r in <ImpulseResult>[
        run(need: NeedOrWant.need, use: UseFrequency.daily),
        run(),
        run(use: UseFrequency.rarely),
      ]) {
        expect(r.headline, isNotEmpty);
        expect(
          r.advice.length,
          greaterThan(40),
          reason:
              'a verdict with no instruction in it is a number wearing a '
              'colour, and somebody standing in a shop cannot act on it',
        );
      }
    });
  });
}
