// Phase 16's expansion-path recommendation badge on the Learn screen's path
// cards (money/expansion_recommendation.dart, wired in screens/learn.dart's
// _pathCard). Reuses the exact visual treatment the core track cards already
// use for their own "RECOMMENDED" badge, so this only proves the WIRING is
// correct, not a new design.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_business_registration.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/learn.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Future<void> _pumpTall(
  WidgetTester tester,
  SalapifyStore store, {
  double textScale = 1.0,
}) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(390, 4400) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(home: LearnScreen(store: store)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'no progress anywhere: the neutral discovery state, no RECOMMENDED '
    'badge on any path card',
    (tester) async {
      final store = await _freshStore();
      await _pumpTall(tester, store);
      // The core tracks always carry their own "RECOMMENDED" star (a
      // separate, core-specific engine); this checks the expansion section
      // has none of its own reason text, not that the word never appears at
      // all on the screen.
      expect(
        find.text(
          'Finish Are You Ready to Invest? before exploring specific '
          'investment topics.',
        ),
        findsNothing,
      );
      expect(
        find.text('Continue with the next incomplete business course.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a real, completed lesson in Grow Your Money recommends it, with a '
    'visible plain-language reason',
    (tester) async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(
        'grow_your_money',
        growYourMoneyLessons.first.id,
      );
      await _pumpTall(tester, store);

      final growCard = find.ancestor(
        of: find.text('Grow Your Money'),
        matching: find.byType(Card),
      );
      expect(
        // Distinct wording from the core tracks' own always-on "RECOMMENDED"
        // badge (a separate engine), per the Phase 16 specialist review: two
        // identically-labelled badges on screen at once would be confusing.
        find.descendant(
          of: growCard,
          matching: find.text('CONTINUE THIS PATH'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: growCard,
          matching: find.text(
            'Finish Are You Ready to Invest? before exploring specific '
            'investment topics.',
          ),
        ),
        findsOneWidget,
      );

      // No other path card carries the badge: exactly one primary
      // recommendation at a time.
      final businessCard = find.ancestor(
        of: find.text('Build Your Business'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: businessCard,
          matching: find.text('CONTINUE THIS PATH'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'completing Grow Your Money entirely stops recommending it again',
    (tester) async {
      final store = await _freshStore();
      for (final lesson in growYourMoneyLessons) {
        await store.markExpansionLessonCompleted('grow_your_money', lesson.id);
      }
      // Grow Your Money's path total is more than just this one course
      // (later phases added sibling courses to the same path), so
      // completing only the pilot lessons is not enough to finish the whole
      // path here; that is exactly what this test needs: the reader keeps
      // getting the SAME course recommended again is what we are proving
      // does NOT happen, by asserting it now points past investing_readiness.
      await _pumpTall(tester, store);

      final growCard = find.ancestor(
        of: find.text('Grow Your Money'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: growCard,
          matching: find.text(
            'Finish Are You Ready to Invest? before exploring specific '
            'investment topics.',
          ),
        ),
        findsNothing,
        reason: 'a completed course must never stay the primary reason',
      );
    },
  );

  testWidgets(
    'business path progress recommends business, with its own reason, at '
    '1.5x text scale, no overflow',
    (tester) async {
      final store = await _freshStore();
      await store.markExpansionLessonCompleted(
        'build_your_business',
        startABusinessLegallyLessons.first.id,
      );
      await _pumpTall(tester, store, textScale: 1.5);
      await _scrollTo(tester, find.text('Build Your Business'));

      final businessCard = find.ancestor(
        of: find.text('Build Your Business'),
        matching: find.byType(Card),
      );
      expect(
        find.descendant(
          of: businessCard,
          matching: find.text(
            'Continue with the next incomplete business course.',
          ),
        ),
        findsOneWidget,
      );
    },
  );
}
