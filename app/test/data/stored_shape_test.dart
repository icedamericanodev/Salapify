import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/models/models.dart';

/// THE PROMISE THAT KEEPS THE MONEY MIGRATION SAFE.
///
/// P2.1 moves the app's internal money representation to whole centavos. It
/// deliberately does NOT move the file on disk, because a stored-format change
/// is a migration, a migration can lose somebody's records, and that decision
/// belongs to P2.2 where it is founder gated and will have a pre-migration
/// backup behind it.
///
/// So the promise is: a file written by this version opens in the version
/// before it, and the other way round. A promise nobody tests is a comment, so
/// this asserts the stored shape directly, on the raw JSON, rather than
/// round-tripping through the codec and proving only that it agrees with
/// itself.
///
/// It will fail the moment somebody writes centavos to disk. That is the
/// point: when P2.2 deliberately changes the stored format, this test is the
/// thing that has to be changed on purpose, with the founder's answer in hand.
void main() {
  group('a goal is still stored in pesos, not centavos', () {
    const Goal goal = Goal(
      id: 'g1',
      name: 'Emergency fund',
      emoji: 'x',
      targetAmount: Money.pesos(60000),
      currentAmount: Money.of(42500, 75),
      targetDate: 'Dec 2026',
      monthlyTarget: Money.pesos(5000),
    );

    test('the written JSON holds plain peso numbers', () {
      final Map<String, dynamic> wire = goalToJson(goal);

      // The exact figures an older build wrote, and would still read.
      expect(wire['targetAmount'], 60000.0);
      expect(wire['currentAmount'], 42500.75);
      expect(wire['monthlyTarget'], 5000.0);

      // And nothing in there is a centavo count. 6000000 in a file an older
      // build opens is sixty times the goal, which is the shape of mistake
      // this test exists to make impossible to ship quietly.
      for (final String field in <String>[
        'targetAmount',
        'currentAmount',
        'monthlyTarget',
      ]) {
        expect(
          wire[field],
          isA<num>(),
          reason: '$field stopped being a plain number',
        );
        expect(
          (wire[field]! as num) < 1000000,
          isTrue,
          reason:
              '$field looks like centavos, not pesos. If that is deliberate, '
              'it is a stored-format change and belongs to P2.2 with the '
              'founder decision and the pre-migration backup.',
        );
      }
    });

    test('and a file written by the OLD build still reads correctly', () {
      // Hand-written the way a previous version would have serialised it, so
      // this is not the codec agreeing with itself.
      final Map<String, dynamic> old =
          jsonDecode('''
        {
          "id": "g1",
          "name": "Emergency fund",
          "emoji": "x",
          "targetAmount": 60000,
          "currentAmount": 42500.75,
          "targetDate": "Dec 2026",
          "monthlyTarget": 5000
        }
      ''')
              as Map<String, dynamic>;

      final Goal read = goalFromJson(old);
      expect(read.targetAmount, const Money.pesos(60000));
      expect(read.currentAmount, const Money.of(42500, 75));
      expect(read.monthlyTarget, const Money.pesos(5000));
    });

    test(
      'a round trip returns the same centavos, not merely something close',
      () {
        final Goal back = goalFromJson(goalToJson(goal));
        expect(back.targetAmount, goal.targetAmount);
        expect(back.currentAmount, goal.currentAmount);
        expect(back.monthlyTarget, goal.monthlyTarget);
        expect(back.currentAmount.centavos, 4250075);
      },
    );

    test('an integer in the file is read as pesos, not as centavos', () {
      // JSON has one number type and a whole peso figure is usually written
      // without a decimal point. Reading 5000 as fifty pesos would be the
      // single easiest way to be out by a hundred, in the direction nobody
      // notices until a goal says it is 1% funded.
      final Goal read = goalFromJson(<String, dynamic>{
        'id': 'g',
        'name': 'g',
        'emoji': 'x',
        'targetAmount': 5000,
        'currentAmount': 0,
        'targetDate': 'Dec 2026',
        'monthlyTarget': 100,
      });
      expect(read.targetAmount.centavos, 500000);
      expect(read.targetAmount.pesos, 5000.0);
    });
  });
}
