// The "Choose Your Next Path" section on the Learn screen, Build Your
// Business's own coverage (Money Courses Phase 13, extended by three later
// courses): shows Build Your Business below Grow Your Money and Protect
// Your Future, with its own independent progress, and never a hard lock.
// Phase 13 shipped this path's first course (Start Your Business Legally);
// later phases added its second (BIR Registration and Local Permits) and
// third (Taxes & Filing for Your Business) courses, and Phase 15 added a fourth
// (Permits, People, and Compliance), so the path card now lists all four
// courses' lessons flattened together, per screens/learn.dart's own
// one-card-per-path design. The core "X of 22" figure and the other two
// paths' own progress must never move because of it. Mirrors
// test/learn_screen_protect_path_test.dart's own structure on purpose, the
// established shape for a Money Courses catalog test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/learning_paths.dart' show lessonsForPath;
import 'package:salapify/content/lessons_bir_local_permits.dart';
import 'package:salapify/content/lessons_bir_tax_setup.dart';
import 'package:salapify/content/lessons_business_permits_compliance.dart';
import 'package:salapify/content/lessons_business_registration.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/screens/path_screen.dart';
import 'package:salapify/widgets/paged_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

final int _businessPathTotal = lessonsForPath('build_your_business').length;
final int _protectPathTotal = lessonsForPath('protect_your_future').length;
final int _growPathTotal = lessonsForPath('grow_your_money').length;

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

// Tall enough that the whole catalog (four core tracks plus all three path
// cards) renders without the ListView virtualizing any of it away, so a
// plain find.text() works without a scroll-then-tap dance.
Future<void> _pumpTall(WidgetTester tester, SalapifyStore store) async {
  tester.view.physicalSize = const Size(390, 5200) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: LearnScreen(store: store)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Build Your Business appears below Protect Your Future, with its own '
    'path total',
    (tester) async {
      final store = await _freshStore();
      await _pumpTall(tester, store);

      expect(find.text('Build Your Business'), findsOneWidget);
      expect(
        find.textContaining(
          'Choose a structure, find the right agency, and map what comes '
          'next.',
        ),
        findsOneWidget,
      );
      // Six from Start Your Business Legally, six from BIR Registration
      // and Local Permits, six from Taxes & Filing for Your Business, six from
      // Permits, People, and Compliance, flattened into one path total per
      // screens/learn.dart's own one-card-per-path design.
      expect(_businessPathTotal, 24);
      // Scoped to Build Your Business's own Card, not a bare find.text():
      // a scoped finder stays correct even if some other path's own total
      // ever happens to match this one.
      final businessCard = find.ancestor(
        of: find.text('Build Your Business'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: businessCard,
          matching: find.text(
            '0 of $_businessPathTotal lessons in this '
            'path',
          ),
        ),
        findsOneWidget,
      );
      // No "Recommended first" note: this path has no
      // prerequisiteLessonIds (learning_paths.dart), unlike Grow Your Money
      // and Protect Your Future.
      expect(
        find.descendant(
          of: businessCard,
          matching: find.textContaining('Recommended first:'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('Start is never disabled for Build Your Business', (
    tester,
  ) async {
    final store = await _freshStore();
    await _pumpTall(tester, store);

    // Scoped to Build Your Business's own Card: three path cards render
    // now, so a positional or '.last' finder would be fragile the moment a
    // fourth path is added.
    final businessCard = find.ancestor(
      of: find.text('Build Your Business'),
      matching: find.byType(Card),
    );
    // Since Phase 4 this pushes a PathScreen listing this path's four
    // courses, rather than expanding twenty four lesson rows inline.
    final allCoursesButton = find.descendant(
      of: businessCard,
      matching: find.widgetWithText(TextButton, 'All courses'),
    );
    expect(allCoursesButton, findsOneWidget);
    await tester.tap(allCoursesButton);
    await tester.pumpAndSettle();
    expect(find.byType(PathScreen), findsOneWidget);
    expect(find.text('Start Your Business Legally'), findsOneWidget);

    await tester.tap(find.text('Start Your Business Legally'));
    await tester.pumpAndSettle();
    expect(find.text('Before You Register'), findsOneWidget);
    expect(find.text('Build Your Registration Roadmap'), findsOneWidget);

    await tester.tap(find.text('Before You Register'));
    await tester.pumpAndSettle();
    expect(find.byType(PagedLessonReader), findsOneWidget);
  });

  testWidgets('finishing every lesson in all four Build Your Business courses '
      'never changes the core "X of 22" figure or the other two paths\' own '
      'progress', (tester) async {
    final store = await _freshStore();
    for (final lesson in [
      ...startABusinessLegallyLessons,
      ...birRegistrationAndLocalPermitsLessons,
      ...birRegistrationTaxSetupLessons,
      ...businessPermitsAndComplianceLessons,
    ]) {
      await store.markExpansionLessonCompleted(
        'build_your_business',
        lesson.id,
      );
    }
    await _pumpTall(tester, store);

    // Was an assertion on the on-screen "0 of 22 lessons" figure. The
    // headline now counts the whole catalog by the founder's decision (audit
    // H2), so the invariant is asserted against the store directly, which is
    // what it always meant.
    expect(
      store.lessonProgress,
      isEmpty,
      reason: 'an expansion write leaked into the core progress store',
    );
    expect(
      find.text(
        '$_businessPathTotal of $_businessPathTotal lessons in this '
        'path',
      ),
      findsOneWidget,
    );
    // The other two paths' own progress stays untouched.
    expect(
      find.text('0 of $_growPathTotal lessons in this path'),
      findsOneWidget,
    );
    expect(
      find.text('0 of $_protectPathTotal lessons in this path'),
      findsOneWidget,
    );
  });

  testWidgets(
    'progressing Protect Your Future never changes Build Your Business\'s '
    'own path progress',
    (tester) async {
      final store = await _freshStore();
      for (final lesson in insuranceDecodedLessons) {
        await store.markExpansionLessonCompleted(
          'protect_your_future',
          lesson.id,
        );
      }
      await _pumpTall(tester, store);

      expect(
        find.text('0 of $_businessPathTotal lessons in this path'),
        findsOneWidget,
      );
    },
  );
}
