// The Money mindset flow: open from Tools, run the decision check to each of
// its three deterministic results, change an answer and see the result
// follow, clear the check, add a small win and see it listed, then delete it.
// Wins persist in data.wins through the store's guarded writes.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Future<void> _openMindset(WidgetTester tester) async {
  await openFromMenu(tester, 'Tools');
  await tester.scrollUntilVisible(
    find.text('Money mindset'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('Money mindset'));
  await tester.pumpAndSettle();
}

/// Answers decision-check question [i] (0-indexed, in the order the screen
/// shows them) by tapping its Yes or No control.
Future<void> _answer(WidgetTester tester, int i, bool yes) async {
  final finder = find.text(yes ? 'Yes' : 'No').at(i);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('the lesson card never shows a missing field as null or blank', () {
    test('a lesson with no title falls back to a safe title', () {
      final title = mindsetLessonTitle(const {
        'summary': 'Some summary',
        'icon': 'mind',
      });
      expect(title, isNot(contains('null')));
      expect(title.trim(), isNotEmpty);
    });

    test('a lesson with a blank title falls back the same way', () {
      final title = mindsetLessonTitle(const {'title': '   '});
      expect(title, isNot(contains('null')));
      expect(title.trim(), isNotEmpty);
    });

    test('a lesson with no summary falls back to a safe summary', () {
      final summary = mindsetLessonSummary(const {
        'title': 'Some title',
        'icon': 'mind',
      });
      expect(summary, isNot(contains('null')));
      expect(summary.trim(), isNotEmpty);
    });

    test('a completely empty lesson map still yields safe text', () {
      expect(mindsetLessonTitle(const {}), isNot(contains('null')));
      expect(mindsetLessonSummary(const {}), isNot(contains('null')));
    });

    testWidgets('the live screen never prints the word null anywhere', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
      await tester.pumpAndSettle();
      await _openMindset(tester);

      expect(find.textContaining('null'), findsNothing);
    });
  });

  group('the decision check', () {
    testWidgets(
      'shows a neutral state until all three questions are answered',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        expect(
          find.text('Answer all three questions to see where this fits.'),
          findsOneWidget,
        );
        expect(find.text('Fits your plan'), findsNothing);
        expect(find.text('Pause for 24 hours'), findsNothing);
        expect(find.text('Not in the plan right now'), findsNothing);
        expect(find.text('Clear check'), findsNothing);

        // Two of three answered is still incomplete.
        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        expect(
          find.text('Answer all three questions to see where this fits.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'essential and affordable, whether or not it waited: fits your plan',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        await _answer(tester, 0, true); // essential
        await _answer(tester, 1, true); // affordable without touching reserved
        await _answer(tester, 2, true); // waited 24h

        expect(find.text('Fits your plan'), findsOneWidget);
        expect(find.text('Why this result'), findsOneWidget);
      },
    );

    testWidgets(
      'not essential, affordable, has not waited 24h: pause for 24 hours',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        await _answer(tester, 0, false); // not essential
        await _answer(tester, 1, true); // affordable without touching reserved
        await _answer(tester, 2, false); // has not waited 24h

        expect(find.text('Pause for 24 hours'), findsOneWidget);
      },
    );

    testWidgets(
      'touches reserved money: not in the plan right now, even if essential',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        await _answer(tester, 0, true); // essential
        await _answer(tester, 1, false); // would touch reserved money
        await _answer(tester, 2, true); // waited 24h

        expect(find.text('Not in the plan right now'), findsOneWidget);
      },
    );

    testWidgets('changing one answer updates the result', (tester) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
      await tester.pumpAndSettle();
      await _openMindset(tester);

      await _answer(tester, 0, false); // not essential
      await _answer(tester, 1, true); // affordable
      await _answer(tester, 2, false); // has not waited
      expect(find.text('Pause for 24 hours'), findsOneWidget);

      // Waiting 24 hours changes the answer, and the result follows it.
      await _answer(tester, 2, true);
      expect(find.text('Pause for 24 hours'), findsNothing);
      expect(find.text('Fits your plan'), findsOneWidget);
    });

    testWidgets('Clear check returns to the neutral state', (tester) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      await tester.pumpWidget(SalapifyApp(store: SalapifyStore()));
      await tester.pumpAndSettle();
      await _openMindset(tester);

      await _answer(tester, 0, true);
      await _answer(tester, 1, true);
      await _answer(tester, 2, true);
      expect(find.text('Fits your plan'), findsOneWidget);

      final clear = find.text('Clear check');
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pumpAndSettle();

      expect(find.text('Fits your plan'), findsNothing);
      expect(
        find.text('Answer all three questions to see where this fits.'),
        findsOneWidget,
      );
      expect(find.text('Clear check'), findsNothing);
    });
  });

  group('small wins', () {
    testWidgets('a small win can be added and removed', (tester) async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      await _openMindset(tester);
      await tester.scrollUntilVisible(
        find.text('SMALL WINS'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'Packed lunch all week',
      );
      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Packed lunch all week'), findsOneWidget);
      expect((store.data['wins'] as List).length, 1);

      await tester.ensureVisible(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Packed lunch all week'), findsNothing);
      expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);
      expect((store.data['wins'] as List).isEmpty, isTrue);
    });

    testWidgets('tapping delete on an imported win with no id does not crash', (
      tester,
    ) async {
      // A hand-edited backup can carry a win with no id (sanitize keeps wins
      // verbatim). The delete must no-op, not throw a cast error.
      SharedPreferences.setMockInitialValues({
        'salapify_data_v2': jsonEncode({
          'wins': [
            {'text': 'Legacy win', 'date': '2026-07-01'},
          ],
        }),
      });
      final store = SalapifyStore();
      await tester.pumpWidget(SalapifyApp(store: store));
      await tester.pumpAndSettle();
      await _openMindset(tester);
      await tester.scrollUntilVisible(
        find.text('SMALL WINS'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Legacy win'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // The idless win cannot be targeted, so it stays and nothing throws.
      expect(tester.takeException(), isNull);
      expect(find.text('Legacy win'), findsOneWidget);
    });
  });
}
