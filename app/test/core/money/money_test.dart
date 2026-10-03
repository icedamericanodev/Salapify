import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';

/// The type exists because a double cannot hold a peso. Every test here is
/// either a case a double gets WRONG, stated as the double failing first so
/// the reason is on the page, or a rule the rest of the app will lean on.
void main() {
  group('the double failures this type exists to end', () {
    test('a double cannot add ten centavos to twenty', () {
      // The canonical one. Stated here rather than cited, because somebody
      // reading this file in a year should be able to see it fail.
      expect(0.1 + 0.2 == 0.3, isFalse);
      expect(0.1 + 0.2, 0.30000000000000004);

      const Money ten = Money(10);
      const Money twenty = Money(20);
      expect(ten + twenty, const Money(30));
      expect(ten + twenty == const Money(30), isTrue);
    });

    test('a double loses a centavo rounding 1.005 to the centavo', () {
      // 1.005 is really 1.00499999999999989, so the usual trick of
      // multiplying by 100 and rounding gives 100 rather than 101. Anybody
      // who has written money code in a float language has shipped this.
      expect((1.005 * 100).round(), 100);
      // Money takes the double as given. It cannot invent the hundredth that
      // was already lost before the call, and it does not pretend to: what it
      // guarantees is that nothing drifts AFTER this point.
      expect(Money.fromDouble(1.005).centavos, 100);
      // Written as centavos, which is what the app will do everywhere once
      // the migration is done, the figure is simply exact.
      expect(const Money.of(1, 1).centavos, 101);
    });

    test('a thousand additions of a tenth drift, and centavos do not', () {
      double d = 0;
      Money m = Money.zero;
      for (int i = 0; i < 1000; i++) {
        d += 0.1;
        m += const Money(10);
      }
      expect(d == 100.0, isFalse, reason: 'the double missed by a sliver');
      expect(m, const Money.pesos(100));
      expect(m.centavos, 10000);
    });
  });

  group('reading and writing a peso figure', () {
    test('pesos and centavos do not get multiplied by the wrong hundred', () {
      expect(const Money.pesos(4200).centavos, 420000);
      expect(const Money.of(1200, 50).centavos, 120050);
      expect(const Money(420000).pesos, 4200.0);
      expect(Money.fromDouble(4200.50).centavos, 420050);
    });

    test('a negative amount keeps its centavos on the same side', () {
      // Money.of(-1200, 50) is minus 1,200.50. Adding the centavos instead of
      // subtracting them gives minus 1,199.50, which is a peso of somebody
      // else's money in the wrong direction.
      expect(const Money.of(-1200, 50).centavos, -120050);
      expect(const Money.of(-1200, 50).toString(), '-1200.50');
    });

    test('a half centavo rounds the prototype\'s way, not Dart\'s', () {
      // JS Math.round sends a half toward positive infinity; Dart's round()
      // sends it away from zero. They differ only on a negative half, which
      // is exactly the case nobody has a fixture for.
      expect((-2.5).round(), -3);
      expect(Money.fromDouble(-0.025).centavos, -2);
      expect(Money.fromDouble(0.025).centavos, 3);
    });

    test(
      'a value that is not a usable peso figure is refused, not rendered',
      () {
        // A restored backup can carry an Infinity or a NaN. round() throws on
        // both, so the choice is between a crash on a screen somebody opened and
        // a rejected record. tryFromDouble lets the caller pick.
        expect(Money.tryFromDouble(double.infinity), isNull);
        expect(Money.tryFromDouble(double.nan), isNull);
        expect(Money.tryFromDouble(-double.infinity), isNull);
        expect(() => Money.fromDouble(double.nan), throwsFormatException);
        // And a figure so large the double can no longer count centavos.
        expect(Money.tryFromDouble(1e18), isNull);
        // A real balance, however large, still works.
        expect(Money.fromDouble(50000000).centavos, 5000000000);
      },
    );
  });

  group('arithmetic', () {
    test('a rate rounds to the centavo exactly as the prototype did', () {
      // The prototype's rule is Math.round(pesos * rate * 100) / 100, and in
      // centavos that is jsRound(centavos * rate). Same figure, no float step
      // in the middle.
      expect(const Money.pesos(10000).times(0.0625), const Money(62500));
      expect(const Money.of(1234, 56).times(0.03), const Money(3704));
    });

    test('a ratio against zero is null, never an infinity', () {
      // "Spent 400 of a 0 budget" has no percentage. A screen that shows one
      // is showing a figure nobody can act on.
      expect(const Money.pesos(400).ratioTo(Money.zero), isNull);
      expect(const Money.pesos(400).ratioTo(const Money.pesos(1000)), 0.4);
    });

    test('a total of nothing is zero, not a throw', () {
      expect(sumMoney(const <Money>[]), Money.zero);
      expect(
        sumMoney(const <Money>[Money.pesos(10), Money.of(5, 50)]),
        const Money.of(15, 50),
      );
    });
  });

  group('splitting a bill cannot lose a centavo', () {
    test('100 pesos three ways sums back to exactly 100', () {
      final List<Money> parts = const Money.pesos(100).split(3);
      expect(parts, <Money>[
        const Money(3334),
        const Money(3333),
        const Money(3333),
      ]);
      expect(sumMoney(parts), const Money.pesos(100));
    });

    test('and so does every awkward amount over every party size', () {
      // The property, not a handful of cases. A split that loses a centavo
      // leaves whoever paid quietly short, and it is the one place people
      // check the arithmetic by hand.
      for (int centavos = 1; centavos <= 2000; centavos++) {
        for (int parts = 1; parts <= 9; parts++) {
          final List<Money> shares = Money(centavos).split(parts);
          expect(shares.length, parts);
          expect(
            sumMoney(shares).centavos,
            centavos,
            reason: '$centavos centavos over $parts did not sum back',
          );
          // And no share is more than a centavo off any other, or one person
          // is carrying the rounding for everybody.
          final int hi = shares
              .map((Money m) => m.centavos)
              .reduce((int a, int b) => a > b ? a : b);
          final int lo = shares
              .map((Money m) => m.centavos)
              .reduce((int a, int b) => a < b ? a : b);
          expect(hi - lo <= 1, isTrue, reason: 'one share carried the lot');
        }
      }
    });

    test('a refund splits the same way, and still sums back', () {
      final List<Money> parts = const Money.pesos(-100).split(3);
      expect(sumMoney(parts), const Money.pesos(-100));
      expect(parts.first, const Money(-3334));
    });

    test('splitting into no parts is refused rather than silently zero', () {
      expect(() => const Money.pesos(100).split(0), throwsArgumentError);
    });
  });

  group('comparison', () {
    test('equal amounts are equal, and usable as a map key', () {
      expect(const Money.pesos(100) == const Money(10000), isTrue);
      expect(
        <Money, String>{const Money(10000): 'x'}[const Money.pesos(100)],
        'x',
      );
    });

    test('sorting puts the smallest first, including negatives', () {
      final List<Money> list = <Money>[
        const Money.pesos(50),
        const Money.pesos(-20),
        Money.zero,
      ]..sort();
      expect(list, <Money>[
        const Money.pesos(-20),
        Money.zero,
        const Money.pesos(50),
      ]);
    });
  });
}
