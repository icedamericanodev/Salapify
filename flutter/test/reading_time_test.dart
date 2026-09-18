// Guards for money/reading_time.dart: the honest time estimate.
//
// The bug being fixed was a promise the app could not keep, so the tests
// that matter most are the ones asserting the estimate never comes out
// SHORTER than reality. Proven to fail before being trusted.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_ph_government_securities.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/money/reading_time.dart';

MoneyLesson _lesson({
  int declared = 1,
  List<LessonBlock> blocks = const [],
  List<InteractionBlock> interactions = const [],
  KnowledgeCheck? check,
}) => MoneyLesson(
  id: 'x',
  trackId: 't',
  title: 'T',
  icon: 'growth',
  minutes: declared,
  summary: 's',
  objective: 'o',
  sections: const [],
  authoredBlocks: blocks,
  interactionBlocks: interactions,
  check: check,
);

String _wordsOf(int n) => List.filled(n, 'word').join(' ');

void main() {
  group('word counting', () {
    test('counts prose, nuggets and the check', () {
      final l = _lesson(
        blocks: [
          ProseBlock(paragraphs: [_wordsOf(100)]),
          NuggetsBlock([_wordsOf(50)]),
        ],
        check: KnowledgeCheck(
          question: _wordsOf(10),
          choices: [_wordsOf(5), _wordsOf(5), _wordsOf(5)],
          correctIndex: 0,
          explanation: _wordsOf(20),
        ),
      );
      expect(lessonWordCount(l), 195);
    });

    test('reference blocks count as zero, because they sit collapsed', () {
      // Counting the citation cards would inflate every regulated lesson by
      // a paragraph the reader was never made to read.
      final l = _lesson(
        blocks: [
          const OfficialSourceBlock(
            agency: 'A very long agency name here',
            sourceTitle: 'A very long source title here as well',
            canonicalUrl: 'https://example.test/some/long/path',
          ),
          const EducationalBoundaryBlock(sourceLabel: 'someone'),
        ],
      );
      expect(lessonWordCount(l), 0);
    });

    test('a risk warning DOES count, because it stays inline', () {
      final l = _lesson(
        blocks: [RiskWarningBlock(title: _wordsOf(4), text: _wordsOf(30))],
      );
      expect(lessonWordCount(l), 34);
    });
  });

  group('estimatedMinutes', () {
    test('180 words is one minute of reading', () {
      final l = _lesson(
        blocks: [
          ProseBlock(paragraphs: [_wordsOf(180)]),
        ],
      );
      expect(estimatedMinutes(l), 1);
    });

    test('each interaction adds real time on top of the reading', () {
      final blocks = [
        ProseBlock(paragraphs: [_wordsOf(180)]),
      ];
      final without = _lesson(blocks: blocks);
      final with4 = _lesson(
        blocks: blocks,
        interactions: const [
          MythOrFactBlock(
            blockId: 'a',
            statement: 's',
            correctAnswer: MythOrFactAnswer.myth,
            explanation: 'e',
          ),
          MythOrFactBlock(
            blockId: 'b',
            statement: 's',
            correctAnswer: MythOrFactAnswer.myth,
            explanation: 'e',
          ),
          MythOrFactBlock(
            blockId: 'c',
            statement: 's',
            correctAnswer: MythOrFactAnswer.myth,
            explanation: 'e',
          ),
          MythOrFactBlock(
            blockId: 'd',
            statement: 's',
            correctAnswer: MythOrFactAnswer.myth,
            explanation: 'e',
          ),
        ],
      );
      expect(estimatedMinutes(with4), greaterThan(estimatedMinutes(without)));
    });

    test('never returns zero for a tiny lesson', () {
      expect(estimatedMinutes(_lesson()), 1);
    });
  });

  group('displayMinutes never under-promises', () {
    test('a long lesson shows the computed figure, not the authored one', () {
      final l = _lesson(
        declared: 2,
        blocks: [
          ProseBlock(paragraphs: [_wordsOf(1800)]),
        ],
      );
      // 1800 words at the 200 wpm rate is exactly 9 minutes of reading.
      expect(l.minutes, 2);
      expect(displayMinutes(l), 9);
    });

    test('an author who says LONGER is respected', () {
      final l = _lesson(
        declared: 9,
        blocks: [
          ProseBlock(paragraphs: ['hi']),
        ],
      );
      expect(displayMinutes(l), 9);
    });

    test('displayMinutes is never below the authored figure, anywhere', () {
      // The one property that matters across all shipped content.
      for (final l in [
        ...growYourMoneyLessons,
        ...phGovernmentSecuritiesLessons,
      ]) {
        expect(
          displayMinutes(l),
          greaterThanOrEqualTo(l.minutes),
          reason: '${l.id} would be shown as shorter than authored',
        );
      }
    });
  });

  group('against real shipped content', () {
    test('the worst offender the audit named is no longer under-promised', () {
      // "Risks and Scam Checks": the audit measured 1,379 words plus three
      // interactions behind a 6 minute label.
      final l = phGovernmentSecuritiesLessons.firstWhere(
        (x) => x.id == gsRisksAndScamChecks,
      );
      expect(
        displayMinutes(l),
        greaterThan(l.minutes),
        reason: 'this is the lesson the honest-minutes fix exists for',
      );
    });

    test('the core 22 never drift more than a minute from their label', () {
      // This started life asserting the core figures were UNCHANGED, on the
      // strength of the audit calling them accurate. That assertion was
      // wrong, and finding out why was the useful part: the audit measured
      // an AVERAGE of 194 words per core lesson, and `freelancer-setaside`
      // is 453, because it carries the dense 8 percent tax explanation. At
      // an ordinary reading rate that is genuinely past two minutes, so
      // showing 3 is the fix working rather than a regression.
      //
      // What is worth guarding is not "never moves" but "never runs away":
      // a model that inflated a short core lesson to six minutes would be
      // broken, and this catches that while leaving room for one honest
      // minute of correction.
      for (final raw in core.lessons) {
        final l = lessonFromMap(raw);
        expect(
          displayMinutes(l) - l.minutes,
          lessThanOrEqualTo(1),
          reason:
              '${l.id} authored ${l.minutes} but computes '
              '${estimatedMinutes(l)} from ${lessonWordCount(l)} words',
        );
      }
    });

    test('exactly one core lesson moves, and it is the known long one', () {
      // Named rather than counted loosely, so a future content edit that
      // quietly pushes another core lesson over the line has to be noticed
      // and re-agreed instead of hiding inside a tolerance.
      final moved = [
        for (final raw in core.lessons)
          if (displayMinutes(lessonFromMap(raw)) != lessonFromMap(raw).minutes)
            lessonFromMap(raw).id,
      ];
      expect(moved, ['freelancer-setaside']);
    });
  });
}
