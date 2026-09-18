// Pan reacts to what the user DID, and stops reacting on his own.
//
// He used to mirror only the coach's ambient item and was otherwise
// indifferent to the person using the app. Logging an expense, the single
// most common action here, changed his face not at all.
//
// Both halves are pinned, and the second is the one that would actually hurt
// if it broke. A reaction that never expires is worse than no reaction: Pan
// grinning about a log from ten minutes ago, while the coach is trying to say
// a bill is due, reads as a broken app rather than a warm one.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final t0 = DateTime(2026, 7, 26, 9, 0, 0);

  group('the reaction fires', () {
    test('logging is acknowledged warmly, and never graded', () {
      expect(
        panMoodForRecentAction('log', t0, t0.add(const Duration(seconds: 1))),
        PanMood.happy,
        reason: 'logging is the habit the whole app rests on',
      );
    });

    test('a funded goal or a cleared debt is a real smile', () {
      for (final kind in ['goal', 'debtpaid', 'utangpaid']) {
        expect(
          panMoodForRecentAction(kind, t0, t0.add(const Duration(seconds: 2))),
          PanMood.happy,
          reason: '$kind should read as a win',
        );
      }
    });
  });

  group('the reaction stops on its own', () {
    test('it expires, so Pan cannot grin over a stale action', () {
      final late = t0.add(panReactionWindow + const Duration(seconds: 1));
      expect(
        panMoodForRecentAction('log', t0, late),
        isNull,
        reason:
            'A reaction that outstays the action stops being a reaction. Pan '
            'smiling about an old log while the coach says a bill is due '
            'reads as a bug, not as warmth.',
      );
    });

    test('nothing recorded means no override at all', () {
      expect(panMoodForRecentAction(null, null, t0), isNull);
      expect(panMoodForRecentAction('log', null, t0), isNull);
      expect(panMoodForRecentAction(null, t0, t0), isNull);
    });

    test('an unknown kind is ignored rather than guessed at', () {
      expect(panMoodForRecentAction('something-new', t0, t0), isNull);
    });

    test('a clock that jumps backwards does not pin Pan forever', () {
      // Phones do this on timezone changes and on network time sync. A
      // future-dated stamp must read as stale, not as permanently fresh.
      final before = t0.subtract(const Duration(hours: 2));
      expect(
        panMoodForRecentAction('log', t0, before),
        isNull,
        reason: 'a future timestamp would otherwise keep Pan reacting forever',
      );
    });
  });

  group('the store records it', () {
    test('adding an entry marks a log action', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      expect(store.lastActionKind, isNull);

      await store.addEntry({
        'type': 'expense',
        'amount': 120.0,
        'category': 'Food',
        'date': DateTime.now().toIso8601String(),
      });

      expect(store.lastActionKind, 'log');
      expect(store.lastActionAt, isNotNull);
    });

    test('the marker never reaches the saved data or a backup', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.addEntry({
        'type': 'expense',
        'amount': 50.0,
        'date': DateTime.now().toIso8601String(),
      });

      // It is a six second smile. It must not become a field the migration
      // and every future backup have to carry forever.
      final blob = store.data.toString();
      expect(blob.contains('lastActionKind'), isFalse);
      expect(blob.contains('lastActionAt'), isFalse);

      final reopened = SalapifyStore();
      await reopened.load();
      expect(
        reopened.lastActionKind,
        isNull,
        reason:
            'a reaction to something done before the app closed is not a '
            'reaction, so it must not survive a restart',
      );
    });
  });
}
