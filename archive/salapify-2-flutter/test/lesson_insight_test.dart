// The personal line at the top of a lesson.
//
// This engine is allowed to say things about the user's own money, which makes
// it the one part of the courses that can be WRONG about a person rather than
// merely unhelpful. So the tests care most about two things: it never claims a
// fact that is not in the data, and when there is not enough data it says so
// instead of guessing.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/money/lesson_insight.dart';

final _now = DateTime(2026, 7, 25);

Map<String, dynamic> _data({
  List<Map<String, dynamic>>? transactions,
  List<Map<String, dynamic>>? debts,
  List<Map<String, dynamic>>? goals,
}) => {
  'transactions': transactions ?? const [],
  'debts': debts ?? const [],
  'goals': goals ?? const [],
};

Map<String, dynamic> _tx(String type, String date) => {
  'id': '$type$date',
  'type': type,
  'amount': 100,
  'date': date,
};

void main() {
  group('when there is nothing to say', () {
    test('an empty store gets the honest fallback, not an invented fact', () {
      final i = lessonInsight(_data(), 'cushion', _now);
      expect(i.personalized, isFalse);
      expect(i.text, contains('Nothing here is a guess'));
    });

    test('junk data never throws and never personalizes', () {
      for (final junk in [null, 'nope', 42, <String, dynamic>{}]) {
        final i = lessonInsight(junk, 'debt', _now);
        expect(i.text, isNotEmpty);
        expect(i.personalized, isFalse);
      }
    });

    test('a junk date is ignored rather than read as today', () {
      final i = lessonInsight(
        _data(
          transactions: [
            {'id': 'a', 'type': 'income', 'amount': 1, 'date': 'not-a-date'},
            {'id': 'b', 'type': 'income', 'amount': 1, 'date': '2026-02-31'},
          ],
        ),
        'swing',
        _now,
      );
      expect(
        i.personalized,
        isFalse,
        reason: 'an impossible date must not become a claim about the user',
      );
    });
  });

  group('when the data supports a claim', () {
    test('active debt is named, without judgment', () {
      final i = lessonInsight(
        _data(
          debts: [
            {'id': 'd1', 'name': 'Card', 'remaining': 5000},
          ],
        ),
        'debt',
        _now,
      );
      expect(i.personalized, isTrue);
      expect(i.text, contains('one debt'));
      // Tone guard: this line appears above every debt lesson, so it must
      // never editorialise about the amount.
      for (final word in ['too much', 'should', 'bad', 'worry']) {
        expect(i.text.toLowerCase(), isNot(contains(word)));
      }
    });

    test('a settled debt is not counted as active', () {
      final i = lessonInsight(
        _data(
          debts: [
            {'id': 'd1', 'name': 'Card', 'remaining': 0},
          ],
        ),
        'debt',
        _now,
      );
      expect(i.personalized, isFalse);
    });

    test('a long gap since income is stated as a plain fact', () {
      final i = lessonInsight(
        _data(transactions: [_tx('income', '2026-06-01')]),
        'cushion',
        _now,
      );
      expect(i.personalized, isTrue);
      expect(i.text, contains('54 days'));
    });

    test('plenty of logging says the numbers are the user own', () {
      final i = lessonInsight(
        _data(
          transactions: [
            for (var d = 1; d <= 25; d++)
              _tx('expense', '2026-07-${d.toString().padLeft(2, '0')}'),
          ],
        ),
        'cushion',
        _now,
      );
      expect(i.personalized, isTrue);
      expect(i.text, contains('25 expenses'));
    });

    test('the track steers which true thing gets said', () {
      final data = _data(
        transactions: [
          for (var d = 1; d <= 5; d++)
            _tx('income', '2026-07-${d.toString().padLeft(2, '0')}'),
        ],
        debts: [
          {'id': 'd1', 'remaining': 900},
        ],
      );
      // Same data, different lesson: each leads with its own relevant fact,
      // and neither contradicts the other.
      expect(lessonInsight(data, 'debt', _now).text, contains('debt'));
      expect(lessonInsight(data, 'swing', _now).text, contains('income'));
    });
  });

  group('the block architecture covers every lesson', () {
    test('all 22 lessons produce renderable blocks', () {
      for (final raw in lessons) {
        final l = lessonFromMap(raw);
        expect(
          l.blocks,
          isNotEmpty,
          reason: '${l.id} would open as a blank screen',
        );
      }
    });

    test('a lesson written before the redesign still gets real blocks', () {
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'sections': [
          {
            'kind': 'steps',
            'body': ['one', 'two'],
          },
          {
            'kind': 'example',
            'body': ['once upon a time'],
          },
        ],
        'takeaway': 'remember this',
      });
      // Steps become a flow, an example becomes a story, the takeaway becomes
      // the closing line. None of them stay as undifferentiated prose.
      expect(l.blocks.whereType<DiagramBlock>(), isNotEmpty);
      expect(l.blocks.whereType<StoryBlock>(), isNotEmpty);
      expect(l.blocks.last, isA<ReflectionBlock>());
    });

    test('authored blocks win over the older fields', () {
      final l = lessonFromMap({
        'id': 'x',
        'track': 't',
        'title': 'T',
        'body': ['old prose'],
        'blocks': [
          {
            'kind': 'nuggets',
            'items': ['new nugget'],
          },
        ],
      });
      expect(l.blocks.length, 1);
      expect(l.blocks.single, isA<NuggetsBlock>());
    });

    test('a half-built block is dropped, never rendered empty', () {
      expect(blockFromMap({'kind': 'nuggets', 'items': []}), isNull);
      expect(blockFromMap({'kind': 'discovery', 'question': 'q'}), isNull);
      expect(
        blockFromMap({
          'kind': 'diagram',
          'steps': ['only one'],
        }),
        isNull,
      );
      expect(blockFromMap('not a map'), isNull);
    });
  });
}
