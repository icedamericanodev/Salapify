import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/split_bill.dart';

/// Golden vectors for the Split Bill port.
///
/// EVERY figure below was printed by running the prototype's own
/// `calculateSplitShares` over these exact fixtures, through
/// `app/tool/gen_split_vectors.ts` under bun. None of it was worked out by
/// hand, which is the whole point: a number I derive myself can agree with my
/// own misreading of the source.
///
/// Five of these lock behaviour that looks wrong and IS the prototype's. They
/// are reproduced rather than corrected, per the repository rule that the
/// engine matches and the defence lives in the UI. Each is named so nobody
/// later "fixes" one into a mismatch.
void main() {
  List<SplitShare> split(
    double total,
    SplitMethod method,
    List<String> names, [
    Map<String, double> inputs = const <String, double>{},
  ]) => calculateSplitShares(
    total: total,
    method: method,
    names: names,
    inputs: inputs,
  );

  group('equal', () {
    test('an even split is even', () {
      final List<SplitShare> s = split(1200, SplitMethod.equal, <String>[
        'You',
        'Carla',
      ]);
      expect(s.map((SplitShare p) => p.amount), <double>[600, 600]);
      expect(s.first.percentage, 50);
    });

    test('the odd centavo goes to the FIRST person', () {
      // 1000 three ways. 333.33 each leaves a centavo, and the prototype
      // hands it to index 0 rather than spreading it or dropping it.
      final List<SplitShare> s = split(1000, SplitMethod.equal, <String>[
        'You',
        'A',
        'B',
      ]);
      expect(s.map((SplitShare p) => p.amount), <double>[
        333.34,
        333.33,
        333.33,
      ]);
      expect(sharesTotal(s), closeTo(1000, 0.001));
    });

    test('ODD THING 1: seven ways on 100 gives a float wart, not 14.32', () {
      // 14.28 + 0.04 in binary floating point is 14.319999999999999, and that
      // is what the prototype returns. Reproduced exactly rather than
      // rounded, because the alternative is a port that disagrees with the
      // source in the fourteenth decimal place and nobody knowing which is
      // right later.
      final List<SplitShare> s = split(100, SplitMethod.equal, <String>[
        'You',
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
      ]);
      expect(s.first.amount, 14.319999999999999);
      expect(s[1].amount, 14.28);
      expect(s.first.percentage, 14.3);
    });

    test('one person pays the lot', () {
      final List<SplitShare> s = split(500, SplitMethod.equal, <String>['You']);
      expect(s.single.amount, 500);
      expect(s.single.percentage, 100);
    });

    test('a bill that is already centavos still divides', () {
      final List<SplitShare> s = split(33.33, SplitMethod.equal, <String>[
        'You',
        'A',
        'B',
      ]);
      expect(s.map((SplitShare p) => p.amount), <double>[11.11, 11.11, 11.11]);
    });
  });

  group('percentage', () {
    test('a half and a half', () {
      final List<SplitShare> s = split(
        1000,
        SplitMethod.percentage,
        <String>['You', 'Carla'],
        <String, double>{'You': 50, 'Carla': 50},
      );
      expect(s.map((SplitShare p) => p.amount), <double>[500, 500]);
    });

    test('thirds that do not divide still add to the bill', () {
      final List<SplitShare> s = split(
        1000,
        SplitMethod.percentage,
        <String>['You', 'A', 'B'],
        <String, double>{'You': 33.3, 'A': 33.3, 'B': 33.4},
      );
      expect(s.map((SplitShare p) => p.amount), <double>[333, 333, 334]);
    });

    test('ODD THING 2: percentages over 100 still total the bill', () {
      // Two people at 80% each. The first gets their 800; the LAST is handed
      // whatever is left, which is 200, while still displaying 80%. The
      // amount is right and the percentage beside it is a lie, and that is
      // the prototype. The screen has to show the amount, not the percentage.
      final List<SplitShare> s = split(
        1000,
        SplitMethod.percentage,
        <String>['You', 'A'],
        <String, double>{'You': 80, 'A': 80},
      );
      expect(s.map((SplitShare p) => p.amount), <double>[800, 200]);
      expect(
        s[1].percentage,
        80,
        reason:
            'the displayed percentage is stale '
            'by design, which is why the UI leads with the amount',
      );
      expect(sharesReconcile(1000, s), isTrue);
    });

    test('ODD THING 2 again: percentages under 100 also total the bill', () {
      // 20% and 20% gives 200 and 800. The second person is charged four
      // times what they said, and the column adds up perfectly.
      final List<SplitShare> s = split(
        1000,
        SplitMethod.percentage,
        <String>['You', 'A'],
        <String, double>{'You': 20, 'A': 20},
      );
      expect(s.map((SplitShare p) => p.amount), <double>[200, 800]);
    });

    test('no percentages given falls back to an even share', () {
      final List<SplitShare> s = split(900, SplitMethod.percentage, <String>[
        'You',
        'A',
        'B',
      ]);
      expect(s.map((SplitShare p) => p.amount), <double>[300, 300, 300]);
      expect(s.first.percentage, closeTo(33.333333333333336, 1e-12));
    });
  });

  group('fixed', () {
    test('amounts that happen to add up', () {
      final List<SplitShare> s = split(
        1000,
        SplitMethod.fixed,
        <String>['You', 'A'],
        <String, double>{'You': 400, 'A': 600},
      );
      expect(s.map((SplitShare p) => p.amount), <double>[400, 600]);
      expect(s.map((SplitShare p) => p.percentage), <double>[40, 60]);
    });

    test('ODD THING 3: fixed amounts are never reconciled, short', () {
      // 100 and 200 against a 1,000 bill. 700 is simply unaccounted for and
      // nothing in the engine objects.
      final List<SplitShare> s = split(
        1000,
        SplitMethod.fixed,
        <String>['You', 'A'],
        <String, double>{'You': 100, 'A': 200},
      );
      expect(sharesTotal(s), 300);
      expect(
        sharesReconcile(1000, s),
        isFalse,
        reason: 'this is what the screen warns about',
      );
    });

    test('ODD THING 3: and over', () {
      final List<SplitShare> s = split(
        1000,
        SplitMethod.fixed,
        <String>['You', 'A'],
        <String, double>{'You': 900, 'A': 900},
      );
      expect(sharesTotal(s), 1800);
      expect(sharesReconcile(1000, s), isFalse);
    });

    test('ODD THING 4: no amounts given lands a centavo short', () {
      // 1000 three ways gives 333.33 each, summing to 999.99. The equal
      // method would have given the missing centavo to somebody; this one
      // does not.
      final List<SplitShare> s = split(1000, SplitMethod.fixed, <String>[
        'You',
        'A',
        'B',
      ]);
      expect(s.map((SplitShare p) => p.amount), <double>[
        333.33,
        333.33,
        333.33,
      ]);
      expect(sharesTotal(s), closeTo(999.99, 0.0001));
      // RECONCILED, and this assertion said isFalse the first time I wrote
      // it. I expected a warning. A centavo lost to the engine's own rounding
      // is not worth interrupting somebody over, which is what the scaling
      // slack in sharesReconcile is for. The case worth warning about is the
      // 700 peso one above, not this.
      expect(sharesReconcile(1000, s), isTrue);
    });

    test('seven ways rounds UP and is still reconciled', () {
      // 142.86 each comes to more than the bill rather than less. A flat one
      // centavo tolerance would have called this a mismatch and warned, which
      // is the defect the per-person slack fixes: a warning that fires on
      // three centavos of rounding gets ignored, and then it is not there for
      // the real one.
      final List<SplitShare> s = split(1000, SplitMethod.fixed, <String>[
        'You',
        'A',
        'B',
        'C',
        'D',
        'E',
        'F',
      ]);
      expect(sharesTotal(s), greaterThan(1000));
      expect(sharesReconcile(1000, s), isTrue);
    });
  });

  group('shares', () {
    test('two shares against one', () {
      final List<SplitShare> s = split(
        900,
        SplitMethod.shares,
        <String>['You', 'A'],
        <String, double>{'You': 2, 'A': 1},
      );
      expect(s.map((SplitShare p) => p.amount), <double>[600, 300]);
      expect(s.map((SplitShare p) => p.percentage), <double>[66.7, 33.3]);
    });

    test('no shares given means one each', () {
      final List<SplitShare> s = split(900, SplitMethod.shares, <String>[
        'You',
        'A',
        'B',
      ]);
      expect(s.map((SplitShare p) => p.amount), <double>[300, 300, 300]);
    });

    test('ODD THING 4 again: one each on 1000 is a centavo short', () {
      final List<SplitShare> s = split(
        1000,
        SplitMethod.shares,
        <String>['You', 'A', 'B'],
        <String, double>{'You': 1, 'A': 1, 'B': 1},
      );
      expect(sharesTotal(s), closeTo(999.99, 0.0001));
    });

    test('a typed ZERO becomes one share, not none', () {
      // The prototype writes `customInputs?.[id] || 1`, not `?? 1`. A zero is
      // falsy in JavaScript, so it falls through to 1. Swapping the operator
      // would silently change who pays what, in either direction.
      final List<SplitShare> s = split(
        900,
        SplitMethod.shares,
        <String>['You', 'A', 'B'],
        <String, double>{'You': 0, 'A': 1, 'B': 1},
      );
      expect(
        s.map((SplitShare p) => p.amount),
        <double>[300, 300, 300],
        reason:
            'zero shares is treated as one share, which is the '
            'prototype and is NOT the same as ?? 1',
      );
    });
  });

  group('a negative half, the one case JS and Dart round differently', () {
    // THIS GROUP EXISTS BECAUSE THE FIXTURE AUDIT FAILED.
    //
    // The porting rule says: after the replay goes green, break the core
    // semantic on purpose and require it to fail. Swapping _jsRound for
    // Dart's round() passed all twenty original cases, which proved the
    // fixtures were incomplete rather than the port correct.
    //
    // JavaScript rounds a half toward positive infinity, so Math.round(-0.5)
    // is -0. Dart rounds away from zero, so (-0.5).round() is -1. Nothing
    // else in the engine can tell them apart. Both figures below were printed
    // by the real engine, not reasoned out.
    //
    // It is reachable: the prototype runs parseFloat over a text field and
    // never checks the sign of a fixed amount.
    test('a fixed amount of -0.50 shows as 0 percent, not -0.1', () {
      final List<SplitShare> s = split(
        1000,
        SplitMethod.fixed,
        <String>['You', 'A'],
        <String, double>{'You': -0.5, 'A': 1000.5},
      );
      expect(s.first.amount, -0.5);
      expect(
        s.first.percentage,
        0,
        reason: 'Dart round() would give -0.1 here, and did',
      );
      expect(s[1].percentage, 100.1);
    });

    test('a negative percentage pushes the remainder onto the last person', () {
      final List<SplitShare> s = split(
        1000,
        SplitMethod.percentage,
        <String>['You', 'A'],
        <String, double>{'You': -0.05, 'A': 100},
      );
      expect(s.first.amount, -0.5);
      expect(s[1].amount, 1000.5);
    });
  });

  group('ODD THING 5: nothing to split returns nothing', () {
    test('a zero bill gives no shares, rather than zeroes', () {
      expect(split(0, SplitMethod.equal, <String>['You', 'A']), isEmpty);
    });

    test('a negative bill gives no shares', () {
      expect(split(-100, SplitMethod.equal, <String>['You', 'A']), isEmpty);
    });

    test('nobody to split with gives no shares', () {
      expect(split(1000, SplitMethod.equal, <String>[]), isEmpty);
    });

    test('an empty result never reconciles', () {
      // Guards the helper rather than the engine: a sum of nothing is zero,
      // and zero equals a zero bill, so a naive reconcile would call an
      // empty split balanced and the screen would say it adds up.
      expect(sharesReconcile(0, const <SplitShare>[]), isFalse);
    });
  });

  group('the engine survives what a backup can smuggle in', () {
    test('a non-finite bill gives no shares rather than throwing', () {
      expect(
        split(double.infinity, SplitMethod.equal, <String>['You']),
        isEmpty,
      );
      expect(split(double.nan, SplitMethod.equal, <String>['You']), isEmpty);
    });
  });
}
