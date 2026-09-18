import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/academy_data.dart';
import 'package:salapify/design/salapify_icon.dart';
import 'package:salapify/models/academy.dart';

/// Guards on the Academy curriculum.
///
/// These exist because of a real failure, not a hypothetical one. An earlier
/// pass built this segment with SIX courses written from my own head, having
/// never looked in src/data/ where the prototype's thirty-two actually live,
/// and renamed the feature from Academy to "Learn" while it was at it. The
/// founder spotted both from a screenshot of their own prototype.
///
/// So the counts are asserted rather than assumed. A curriculum that quietly
/// shrinks is exactly the shape of that mistake repeating.
void main() {
  test('all 32 courses are present', () {
    // The prototype has 32. If a regeneration drops one, this says so rather
    // than the screen quietly listing fewer.
    expect(
      academyCourses.length,
      32,
      reason:
          'the curriculum lost or gained a course. Regenerate from '
          'src/data/academyData.ts rather than editing the Dart by hand',
    );
  });

  test('the lesson content came across, all 96 sections of it', () {
    final int sections = academyCourses.fold<int>(
      0,
      (int n, CourseModule c) => n + c.sections.length,
    );
    expect(sections, 96, reason: 'lesson sections were lost in the port');

    final int quizzes = academyCourses
        .where((CourseModule c) => c.knowledgeCheck != null)
        .length;
    expect(quizzes, 24, reason: 'knowledge checks were lost in the port');
  });

  test('no course is a stub', () {
    // The six invented courses had a one-line summary and nothing else. A
    // real one has objectives, sections with actual prose, and takeaways.
    for (final CourseModule c in academyCourses) {
      expect(c.title.trim(), isNotEmpty, reason: '${c.id} has no title');
      expect(
        c.description.trim().length,
        greaterThan(30),
        reason: '${c.id} has no real description',
      );
      expect(c.durationMinutes, greaterThan(0), reason: '${c.id} has no time');
      expect(c.sections, isNotEmpty, reason: '${c.id} has no lesson body');
      expect(
        c.keyTakeaways,
        isNotEmpty,
        reason: '${c.id} has no key takeaways',
      );
      for (final LessonSection s in c.sections) {
        expect(
          s.content.trim().length,
          greaterThan(100),
          reason: '${c.id}/${s.id} is too short to be a real lesson section',
        );
      }
    }
  });

  test('every quiz has a reachable correct answer', () {
    for (final CourseModule c in academyCourses) {
      final KnowledgeCheck? k = c.knowledgeCheck;
      if (k == null) continue;
      expect(
        k.options.length,
        greaterThanOrEqualTo(2),
        reason: '${c.id} has a quiz with nothing to choose between',
      );
      expect(
        k.correctAnswerIndex,
        inInclusiveRange(0, k.options.length - 1),
        reason:
            '${c.id} points at an option that does not exist, so the quiz '
            'can never be answered correctly',
      );
      expect(
        k.explanation.trim().length,
        greaterThan(20),
        reason:
            '${c.id} explains nothing after the answer, which is the '
            'whole point of asking',
      );
    }
  });

  test('every icon name resolves to a real glyph', () {
    // The resolver falls back to a neutral marker so a typo can never take a
    // screen down. This test is what stops that fallback being reached
    // silently, which would leave a course with a meaningless circle.
    final List<String> unresolved =
        academyCourses
            .map((CourseModule c) => c.icon)
            .toSet()
            .where((String n) => !SalapifyIcon.glyphs.containsKey(n))
            .toList()
          ..sort();

    expect(
      unresolved,
      isEmpty,
      reason:
          'these icon names fall through to the neutral marker: '
          '$unresolved',
    );
  });

  test('the nine categories all have courses in them', () {
    const List<String> expected = <String>[
      'Psychology & Mindset',
      'Basics & Fundamentals',
      'Safety & Preparation',
      'Credit & Debt',
      'Investing & Wealth',
      'Tax & Security',
      'Relationships & Culture',
      'Income & Freelancing',
      'Business & Startups',
    ];

    final Set<String> actual = academyCourses
        .map((CourseModule c) => c.category)
        .toSet();

    expect(
      actual,
      expected.toSet(),
      reason:
          'the category list drifted from the prototype. The screen '
          'derives its filter chips from the courses, so a renamed category '
          'silently changes the filters too',
    );
  });

  test('course ids are unique', () {
    final List<String> ids = academyCourses
        .map((CourseModule c) => c.id)
        .toList();
    expect(
      ids.toSet().length,
      ids.length,
      reason: 'two courses share an id, so completion marks the wrong one',
    );
  });
}
