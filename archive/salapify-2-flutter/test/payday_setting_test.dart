// The payday setting: proof that Salapify never CLAIMS a payday it only
// guessed, and that once the user tells it, every payday surface turns back on.
//
// Why this file exists. normalizeSchedule falls back to semimonthly 15/31 when
// no schedule is stored. That is a fine default for a forecast, and it was
// being used for assertions instead: the Home ritual card and the 9am push
// both told EVERY user "it is payday" on the 15th and the month end. Nothing
// in the app ever wrote settings.paydaySchedule, so a monthly-on-the-30th
// earner, and every swing-income user Steady Pay exists for, was told
// something false with no way to correct it. Neither surface had a test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/cycle.dart' show paydayRitual;
import 'package:salapify/money/goals_calc.dart' show goalNum;
import 'package:salapify/money/reminders.dart' show plannedReminders;
import 'package:salapify/money/schedule.dart'
    show hasExplicitPaydaySchedule, nextPayday;
import 'package:salapify/screens/payday.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('hasExplicitPaydaySchedule', () {
    test('absent, junk, and half-built schedules all read as not set', () {
      expect(hasExplicitPaydaySchedule(null), isFalse);
      expect(hasExplicitPaydaySchedule({}), isFalse);
      expect(hasExplicitPaydaySchedule({'settings': {}}), isFalse);
      expect(
        hasExplicitPaydaySchedule({
          'settings': {'paydaySchedule': 'garbage'},
        }),
        isFalse,
      );
      expect(
        hasExplicitPaydaySchedule({
          'settings': {
            'paydaySchedule': {'mode': 'monthly'},
          },
        }),
        isFalse,
        reason: 'a mode with no day is not an answer',
      );
    });

    test('each real shape reads as set', () {
      for (final s in [
        {
          'mode': 'semimonthly',
          'days': [15, 31],
        },
        {'mode': 'monthly', 'day': 30},
        {'mode': 'weekly', 'weekday': 5},
      ]) {
        expect(
          hasExplicitPaydaySchedule({
            'settings': {'paydaySchedule': s},
          }),
          isTrue,
          reason: '$s should count as set',
        );
      }
    });
  });

  group('a guess never becomes a claim', () {
    Map<String, dynamic> started() => {
      'accounts': [
        {'id': 'a1', 'name': 'Cash', 'balance': 1000},
      ],
      'transactions': <dynamic>[],
      'settings': <String, dynamic>{},
    };

    test('the ritual card stays silent on the 15th and month end', () {
      final d = started();
      for (final day in [15, 30, 31]) {
        expect(
          paydayRitual(d, DateTime(2026, 7, day)).isPayday,
          isFalse,
          reason: 'July $day was claimed as payday from a pure guess',
        );
      }
    });

    test('the 9am push is not scheduled either', () {
      final d = started()
        ..['settings'] = {
          'notifications': {'payday': true},
        };
      final planned = plannedReminders(d, DateTime(2026, 7, 1, 8));
      expect(
        planned.where((p) => p.title == 'Payday!'),
        isEmpty,
        reason: 'no notification may assert a payday we guessed',
      );
    });

    test('setting the payday turns both surfaces back on', () {
      final schedule = {'mode': 'monthly', 'day': 30};
      final d = started()
        ..['settings'] = {
          'paydaySchedule': schedule,
          'notifications': {'payday': true},
        };
      expect(paydayRitual(d, DateTime(2026, 7, 30)).isPayday, isTrue);
      expect(paydayRitual(d, DateTime(2026, 7, 15)).isPayday, isFalse);
      final planned = plannedReminders(d, DateTime(2026, 7, 1, 8));
      final paydays = planned.where((p) => p.title == 'Payday!').toList();
      expect(paydays, isNotEmpty);
      expect(paydays.first.when, DateTime(2026, 7, 30, 9));
    });

    test('forecasts still use the default, only claims are gated', () {
      // nextPayday is deliberately unchanged: "your next payday is probably
      // around then" is a useful guess, unlike "today is payday".
      expect(nextPayday(DateTime(2026, 7, 10), null), DateTime(2026, 7, 15));
    });
  });

  group('the store round trip', () {
    test('set then clear leaves no schedule behind', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.setPaydaySchedule({'mode': 'weekly', 'weekday': 5});
      expect(hasExplicitPaydaySchedule(store.data), isTrue);
      await store.clearPaydaySchedule();
      expect(
        hasExplicitPaydaySchedule(store.data),
        isFalse,
        reason:
            'a user whose pay has no fixed date must read exactly like a '
            'user who never set one, so no other money code needs to change',
      );
    });

    test('other settings survive both writes', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.markLessonRead('see-it-first');
      await store.setPaydaySchedule({'mode': 'monthly', 'day': 7});
      await store.clearPaydaySchedule();
      final settings = store.data['settings'] as Map;
      expect(settings['lessonsRead'], contains('see-it-first'));
    });
  });

  testWidgets('the screen saves a real schedule and can clear it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await store.load();

    await tester.pumpWidget(MaterialApp(home: PaydayScreen(store: store)));
    await tester.pumpAndSettle();

    // A store with nothing set opens on the honest answer, not a guess.
    expect(find.text('My pay has no fixed date'), findsOneWidget);

    await tester.tap(find.text('Once a month'));
    await tester.pumpAndSettle();
    // The Save button lives below the fold in a lazy ListView, so it is not
    // built until scrolled to.
    await tester.scrollUntilVisible(find.text('Save'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(hasExplicitPaydaySchedule(store.data), isTrue);
    final saved = (store.data['settings'] as Map)['paydaySchedule'] as Map;
    expect(saved['mode'], 'monthly');
  });

  test('goalNum refuses a non-finite amount', () {
    // A pasted 400-digit number parses to Infinity, which passes "> 0",
    // reaches the store, and makes jsonEncode throw, so the goal silently
    // never saved and the sheet closed as if it had.
    expect(goalNum('9' * 400), 0);
    expect(goalNum('12,000'), 12000);
    expect(goalNum('-5'), 0);
  });
}
