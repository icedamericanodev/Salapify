// The greeting has to work for the user who never gave a name.
//
// That is not the edge case, it is the DEFAULT. Every user who already has
// Salapify has no name stored, and the ask is skippable on purpose, so the
// nameless path is the one most people will see. A greeting that only reads
// well once a name exists would ship broken for everybody and look fine in
// the screenshot the person who built it took.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/greeting.dart';

void main() {
  group('it reads right with no name at all', () {
    test('no name gives a clean greeting, not a dangling comma', () {
      expect(greetingFor(DateTime(2026, 7, 26, 9)), 'Good morning');
      expect(greetingFor(DateTime(2026, 7, 26, 9), name: null), 'Good morning');
    });

    test('a blank or whitespace name is the same as no name', () {
      for (final n in ['', '   ', '\t', '\n  \n']) {
        expect(
          greetingFor(DateTime(2026, 7, 26, 9), name: n),
          'Good morning',
          reason:
              'A name of ${n.runes.length} whitespace characters produced a '
              'greeting with punctuation hanging off it.',
        );
      }
    });

    test('a non-string from a hand-edited backup is ignored, not crashed on', () {
      expect(normalizeDisplayName(42), isNull);
      expect(normalizeDisplayName(['Ana']), isNull);
      expect(normalizeDisplayName({'name': 'Ana'}), isNull);
      expect(normalizeDisplayName(null), isNull);
    });
  });

  group('it uses the name when there is one', () {
    test('the name is greeted by part of day', () {
      expect(greetingFor(DateTime(2026, 7, 26, 9), name: 'Ana'),
          'Good morning, Ana');
      expect(greetingFor(DateTime(2026, 7, 26, 14), name: 'Ana'),
          'Good afternoon, Ana');
      expect(greetingFor(DateTime(2026, 7, 26, 20), name: 'Ana'),
          'Good evening, Ana');
    });

    test('surrounding and doubled spaces are tidied', () {
      expect(normalizeDisplayName('  Ana  '), 'Ana');
      expect(normalizeDisplayName('Ana   Maria'), 'Ana Maria');
    });

    test('a pasted paragraph cannot push Home off the screen', () {
      // The realistic way this arrives is a hand-edited backup file, not
      // someone typing it. The cap is a LAYOUT guard, so what matters is that
      // the result is short and still a sensible string.
      final huge = 'A' * 4000;
      final got = normalizeDisplayName(huge)!;
      expect(got.length, displayNameMaxLength);
      expect(greetingFor(DateTime(2026, 7, 26, 9), name: huge).length,
          lessThan(60));
    });

    test('a name that is all emoji survives, because that is the user\'s call', () {
      // Category and treat icons are user data and stay emoji by house rule.
      // The same respect applies here: if someone wants to be a star, the app
      // does not get an opinion.
      expect(normalizeDisplayName('⭐'), '⭐');
    });
  });

  group('the clock boundaries', () {
    test('midnight through to the last minute before noon is morning', () {
      expect(partOfDay(0), 'morning');
      expect(partOfDay(11), 'morning');
    });

    test('noon starts the afternoon, 6pm starts the evening', () {
      expect(partOfDay(12), 'afternoon');
      expect(partOfDay(17), 'afternoon');
      expect(partOfDay(18), 'evening');
      expect(partOfDay(23), 'evening');
    });

    test('every hour of the day produces one of exactly three greetings', () {
      // Guards a future "clever" fourth bucket (a small-hours greeting, say)
      // from being added without anyone deciding it out loud.
      final seen = <String>{};
      for (var h = 0; h < 24; h++) {
        final g = greetingFor(DateTime(2026, 7, 26, h));
        expect(g.startsWith('Good '), isTrue, reason: 'hour $h gave "$g"');
        seen.add(g);
      }
      expect(seen.length, 3, reason: 'got ${seen.toList()..sort()}');
    });
  });
}
