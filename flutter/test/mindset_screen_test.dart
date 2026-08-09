// The Money mindset flow: open from Tools, run the decision check to each of
// its three deterministic results, change an answer and see the result
// follow, clear the check, add a small win and see it listed, then delete it.
// Wins persist in data.wins through the store's guarded writes.
//
// The "What are you considering?" section (item, amount, category) and the
// budget impact it can surface are covered lower down, mounting the screen
// directly (the categories_screen_test.dart pattern) since none of that needs
// the full app shell.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

Map<String, dynamic> _blob({
  bool pro = false,
  List<Map<String, dynamic>> categories = const [],
  List<Map<String, dynamic>> transactions = const [],
}) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true, if (pro) 'pro': true},
  'categories': categories,
  'transactions': transactions,
};

String _todayIso() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

Future<SalapifyStore> _openDirect(
  WidgetTester tester,
  Map<String, dynamic> blob,
) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(MaterialApp(home: MindsetScreen(store: store)));
  await tester.pumpAndSettle();
  return store;
}

Future<void> _openMindset(WidgetTester tester) async {
  await openFromMenu(tester, 'Calculators');
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

// The Impulse check card above Small Wins is tall enough that the win entry
// row is not always inside the ListView's first-layout cache, so ensureVisible
// alone (which only nudges something already built) is not enough; this
// forces the sliver to build further down, the same fix scrollUntilVisible
// gives the existing "a small win can be added and removed" test.
Future<void> _scrollToWinEntry(WidgetTester tester) =>
    tester.scrollUntilVisible(
      find.byKey(const Key('mindsetWinText')),
      400,
      scrollable: find.byType(Scrollable).first,
    );

Future<void> _tapNear(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
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

    test('a lesson is only flagged for freelancers when it says so', () {
      expect(mindsetLessonForFreelancers(const {}), isFalse);
      expect(
        mindsetLessonForFreelancers(const {'forFreelancers': false}),
        isFalse,
      );
      // A malformed value (not a real bool) reads as false, never crashes
      // and never defaults to true: showing the label on ordinary advice
      // would be the worse mistake of the two.
      expect(
        mindsetLessonForFreelancers(const {'forFreelancers': 'yes'}),
        isFalse,
      );
      expect(
        mindsetLessonForFreelancers(const {'forFreelancers': true}),
        isTrue,
      );
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
        find.text('No wins yet. Add a small one above.'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('mindsetWinText')),
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
        find.text('Legacy win'),
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

    testWidgets(
      'a legacy win with no amount or note shows no Spending avoided or '
      'reflection line',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'salapify_data_v2': jsonEncode({
            'wins': [
              {'text': 'Legacy win', 'date': '2026-07-01', 'id': 'w_legacy'},
            ],
          }),
        });
        final store = SalapifyStore();
        await tester.pumpWidget(SalapifyApp(store: store));
        await tester.pumpAndSettle();
        await _openMindset(tester);
        await tester.scrollUntilVisible(
          find.text('Legacy win'),
          400,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text('Legacy win'), findsOneWidget);
        // "Spending avoided" alone also names a 30-day snapshot stat label
        // further down the screen; the win row's own amount line always
        // reads "Spending avoided: <amount>", so that colon is what
        // distinguishes "this win recorded no amount" from "the snapshot
        // card exists".
        expect(find.textContaining('Spending avoided:'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('small wins: optional amount and reflection (Phase 4)', () {
    testWidgets(
      'the amount and reflection fields start collapsed; plain manual '
      'entry (no amount) still saves exactly as before',
      (tester) async {
        final store = await _openDirect(tester, _blob());
        await _scrollToWinEntry(tester);

        expect(find.byKey(const Key('mindsetWinAmount')), findsNothing);
        expect(find.byKey(const Key('mindsetWinNote')), findsNothing);
        expect(
          find.text('+ Add spending avoided or a reflection'),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('mindsetWinText')),
          'Packed lunch all week',
        );
        await _tapNear(tester, find.text('Add'));

        expect(find.text('Packed lunch all week'), findsOneWidget);
        final win = (store.data['wins'] as List).single as Map;
        expect(win['amount'], isNull);
        expect(win['note'], isNull);
      },
    );

    testWidgets('an amount and a reflection are saved and shown as "Spending '
        'avoided", never as "money saved"', (tester) async {
      await _openDirect(tester, _blob());
      await _scrollToWinEntry(tester);

      await tester.enterText(
        find.byKey(const Key('mindsetWinText')),
        'New shoes',
      );
      await _tapNear(
        tester,
        find.text('+ Add spending avoided or a reflection'),
      );
      await tester.enterText(find.byKey(const Key('mindsetWinAmount')), '850');
      await tester.enterText(
        find.byKey(const Key('mindsetWinNote')),
        'Already have three pairs',
      );
      await _tapNear(tester, find.text('Add'));

      expect(find.text('Spending avoided: ₱850'), findsOneWidget);
      expect(find.text('Already have three pairs'), findsOneWidget);
      expect(find.textContaining('money saved'), findsNothing);
    });

    testWidgets('a blank text entry is never saved', (tester) async {
      final store = await _openDirect(tester, _blob());
      await _scrollToWinEntry(tester);

      await _tapNear(tester, find.text('Add'));

      expect(store.data['wins'], isEmpty);
      expect(find.text('No wins yet. Add a small one above.'), findsOneWidget);
    });

    testWidgets('an unparsable typed amount blocks the submission instead '
        'of being silently dropped', (tester) async {
      final store = await _openDirect(tester, _blob());
      await _scrollToWinEntry(tester);

      await tester.enterText(
        find.byKey(const Key('mindsetWinText')),
        'New shoes',
      );
      await _tapNear(
        tester,
        find.text('+ Add spending avoided or a reflection'),
      );
      await tester.enterText(
        find.byKey(const Key('mindsetWinAmount')),
        'not a number',
      );
      await _tapNear(tester, find.text('Add'));

      expect(store.data['wins'], isEmpty);
      expect(find.text('Enter a valid amount.'), findsOneWidget);
    });
  });

  group('duplicate protection (store level)', () {
    test('a rapid identical resubmission collapses into one win', () async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      final store = SalapifyStore();
      await store.load();

      final a = store.addWin('Skipped bubble tea', amount: 120);
      final b = store.addWin('Skipped bubble tea', amount: 120);
      await a;
      await b;

      expect(store.data['wins'], hasLength(1));
    });

    test('different content submitted back to back is not treated as a '
        'duplicate', () async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      final store = SalapifyStore();
      await store.load();

      final a = store.addWin('Skipped bubble tea');
      final b = store.addWin('Skipped a taxi, walked instead');
      await a;
      await b;

      expect(store.data['wins'], hasLength(2));
    });

    test('a blank submission is a no-op, not a saved empty win', () async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      final store = SalapifyStore();
      await store.load();

      await store.addWin('   ');

      expect(store.data['wins'], isEmpty);
    });
  });

  group('editing and deleting a win (Phase 4)', () {
    testWidgets(
      'tapping a win opens an edit sheet that updates its text, amount, '
      'and note',
      (tester) async {
        final store = await _openDirect(tester, _blob());
        await store.addWin('New shoes', amount: 1500, note: 'Old note');
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('New shoes'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        // scrollUntilVisible only builds the row into the tree; it can stop
        // with the row still below the fold, where a tap misses. Pull it
        // fully on-screen before tapping.
        await tester.ensureVisible(find.text('New shoes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New shoes'));
        await tester.pumpAndSettle();
        expect(find.text('Edit win'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('mindsetEditWinText')),
          'New shoes, decided against',
        );
        await tester.enterText(
          find.byKey(const Key('mindsetEditWinAmount')),
          '1200',
        );
        await tester.enterText(
          find.byKey(const Key('mindsetEditWinNote')),
          'Found a cheaper pair',
        );
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();

        final win = (store.data['wins'] as List).single as Map;
        expect(win['text'], 'New shoes, decided against');
        expect(win['amount'], 1200.0);
        expect(win['note'], 'Found a cheaper pair');
        expect(find.text('New shoes, decided against'), findsOneWidget);
      },
    );

    testWidgets(
      'Delete inside the edit sheet asks for confirmation before removing '
      'the win',
      (tester) async {
        final store = await _openDirect(tester, _blob());
        await store.addWin('New shoes', amount: 1500);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('New shoes'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('New shoes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('New shoes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete win'));
        await tester.pumpAndSettle();

        expect(find.text('Delete this win?'), findsOneWidget);
        expect(store.data['wins'], hasLength(1), reason: 'not deleted yet');

        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(store.data['wins'], isEmpty);
        expect(find.text('New shoes'), findsNothing);
      },
    );

    testWidgets(
      'the quick delete icon still offers Undo, and Undo restores the '
      'amount and note verbatim',
      (tester) async {
        final store = await _openDirect(tester, _blob());
        await store.addWin('New shoes', amount: 1500, note: 'Found cheaper');
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.byIcon(Icons.close),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(store.data['wins'], isEmpty);

        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        final win = (store.data['wins'] as List).single as Map;
        expect(win['text'], 'New shoes');
        expect(win['amount'], 1500.0);
        expect(win['note'], 'Found cheaper');
      },
    );

    test('editWin clearing the amount and note removes them, rather than '
        'leaving the old values behind under a spread', () async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      final store = SalapifyStore();
      await store.load();
      await store.addWin('New shoes', amount: 1500, note: 'Old note');
      final id = (store.data['wins'] as List).single['id'] as String;

      await store.editWin(id, text: 'New shoes');

      final win = (store.data['wins'] as List).single as Map;
      expect(win['text'], 'New shoes');
      expect(win.containsKey('amount'), isFalse);
      expect(win.containsKey('note'), isFalse);
    });
  });

  group('offline persistence (Phase 4)', () {
    test('a win with an amount and note reloads from disk unchanged', () async {
      SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
      final storeA = SalapifyStore();
      await storeA.load();
      await storeA.addWin('New shoes', amount: 1500, note: 'Found cheaper');

      final storeB = SalapifyStore();
      await storeB.load();

      final win = (storeB.data['wins'] as List).single as Map;
      expect(win['text'], 'New shoes');
      expect(win['amount'], 1500.0);
      expect(win['note'], 'Found cheaper');
    });
  });

  group('the 30-day snapshot (Phase 4)', () {
    testWidgets(
      'reads all zero and a neutral message before any history exists',
      (tester) async {
        await _openDirect(tester, _blob());
        await tester.scrollUntilVisible(
          find.text('30-DAY SNAPSHOT'),
          400,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text('Decision checks'), findsOneWidget);
        expect(find.text('Purchases paused'), findsOneWidget);
        expect(find.text('Purchases skipped'), findsOneWidget);
        expect(find.text('Spending avoided'), findsOneWidget);
        expect(
          find.textContaining('Add an amount to a small win'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'completing a decision check logs once, not once per answer flip',
      (tester) async {
        SharedPreferences.setMockInitialValues(onboardedEmptyStorage());
        final store = SalapifyStore();
        await tester.pumpWidget(SalapifyApp(store: store));
        await tester.pumpAndSettle();
        await _openMindset(tester);

        await _answer(tester, 0, false); // not essential
        await _answer(tester, 1, true); // affordable
        await _answer(tester, 2, false); // has not waited
        expect(find.text('Pause for 24 hours'), findsOneWidget);
        expect(store.mindsetChecks, hasLength(1));

        // Flipping an already-answered question changes the verdict but
        // does not log a second completed check.
        await _answer(tester, 2, true);
        expect(find.text('Pause for 24 hours'), findsNothing);
        expect(find.text('Fits your plan'), findsOneWidget);
        expect(store.mindsetChecks, hasLength(1));
      },
    );

    testWidgets(
      'the spending-avoided total counts only wins with a valid amount, '
      'and only within the last 30 days',
      (tester) async {
        final now = DateTime.now();
        String daysAgo(int n) =>
            now.subtract(Duration(days: n)).toIso8601String().substring(0, 10);
        SharedPreferences.setMockInitialValues({
          storageKey: jsonEncode({
            'schemaVersion': 12,
            'settings': {'onboarded': true},
            'wins': [
              {
                'id': 'w1',
                'text': 'Skipped shoes',
                'amount': 1500,
                'date': daysAgo(1),
              },
              {'id': 'w2', 'text': 'No amount noted', 'date': daysAgo(1)},
              {
                'id': 'w3',
                'text': 'Too old to count',
                'amount': 5000,
                'date': daysAgo(45),
              },
              {
                'id': 'w4',
                'text': 'Packed lunch',
                'amount': 200,
                'date': daysAgo(10),
              },
            ],
          }),
        });
        final store = SalapifyStore();
        await store.load();
        await tester.pumpWidget(MaterialApp(home: MindsetScreen(store: store)));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('₱1,700'),
          400,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.text('₱1,700'), findsOneWidget);
        expect(find.textContaining('From 2 small wins'), findsOneWidget);
      },
    );

    testWidgets('shows the skip-pattern insight once three skips exist in the '
        'window, never fewer', (tester) async {
      final now = DateTime.now();
      Map<String, dynamic> skipped(String id) => {
        'id': id,
        'itemName': 'Item $id',
        'essential': false,
        'affordableWithoutReserved': true,
        'waited24h': false,
        'result': 'pause24h',
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        'revisitAt': now.subtract(const Duration(hours: 1)).toIso8601String(),
        'status': 'skipped',
      };
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'settings': {
            'onboarded': true,
            'mindsetWaiting': [skipped('a'), skipped('b')],
          },
        }),
      });
      final store = SalapifyStore();
      await store.load();
      await tester.pumpWidget(MaterialApp(home: MindsetScreen(store: store)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('30-DAY SNAPSHOT'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Waiting 24 hours helped you skip'),
        findsNothing,
        reason: 'only 2 skips so far',
      );

      // A third skip in the window crosses the minimum.
      await store.patchMindsetWaitingItem('a', {}); // no-op, keeps id
      await store.addMindsetWaitingItem(
        itemName: 'Item c',
        essential: false,
        affordableWithoutReserved: true,
        waited24h: false,
        result: 'pause24h',
      );
      final thirdId = store.mindsetWaiting.last['id'] as String;
      await store.patchMindsetWaitingItem(thirdId, {'status': 'skipped'});
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Waiting 24 hours helped you skip'),
        400,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.text('Waiting 24 hours helped you skip 3 purchases this month.'),
        findsOneWidget,
      );
    });
  });

  group('what are you considering', () {
    testWidgets('item name and amount fields accept typed text', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      await tester.enterText(
        find.byKey(const Key('mindsetItemName')),
        'New shoes',
      );
      await tester.enterText(find.byKey(const Key('mindsetAmount')), '1500');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('New shoes'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
    });

    testWidgets('a blank amount is not treated as an error', (tester) async {
      await _openDirect(tester, _blob());

      expect(find.text('Enter a valid amount.'), findsNothing);
      expect(find.text('That amount is too large to check.'), findsNothing);
    });

    testWidgets('a bare trailing decimal point is not treated as an error', (
      tester,
    ) async {
      // "150." is on the way to "150.50", not yet invalid. A first version
      // of the validation flagged it the instant the "." was typed.
      await _openDirect(tester, _blob());

      await tester.enterText(find.byKey(const Key('mindsetAmount')), '150.');
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid amount.'), findsNothing);
    });

    testWidgets('non-numeric and negative amounts show a validation message', (
      tester,
    ) async {
      await _openDirect(tester, _blob());
      final amountField = find.byKey(const Key('mindsetAmount'));

      await tester.enterText(amountField, 'abc');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount.'), findsOneWidget);

      await tester.enterText(amountField, '-100');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount.'), findsOneWidget);

      await tester.enterText(amountField, '0');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid amount.'), findsOneWidget);
    });

    testWidgets('an excessive amount shows its own validation message', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      await tester.enterText(
        find.byKey(const Key('mindsetAmount')),
        '9999999999999',
      );
      await tester.pumpAndSettle();

      expect(find.text('That amount is too large to check.'), findsOneWidget);
    });

    testWidgets('a category chip selects and deselects on tap', (tester) async {
      await _openDirect(
        tester,
        _blob(
          categories: [
            {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 0},
          ],
        ),
      );
      final chip = find.widgetWithText(ChoiceChip, '🍚 Food');
      expect(chip, findsOneWidget);
      expect(tester.widget<ChoiceChip>(chip).selected, isFalse);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);

      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(chip).selected, isFalse);
    });

    testWidgets(
      'the decision check still reaches a verdict with none of these fields filled',
      (tester) async {
        await _openDirect(tester, _blob());

        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);

        expect(find.text('Fits your plan'), findsOneWidget);
      },
    );
  });

  group('budget impact', () {
    List<Map<String, dynamic>> foodCategory(double cap) => [
      {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': cap},
    ];
    List<Map<String, dynamic>> spentThisMonth(double amount) => [
      {
        'id': 't1',
        'type': 'expense',
        'label': 'Jollibee',
        'amount': amount,
        'date': _todayIso(),
        'categoryId': 'food',
      },
    ];

    Future<void> fillConsider(
      WidgetTester tester, {
      required String amount,
    }) async {
      await tester.enterText(find.byKey(const Key('mindsetAmount')), amount);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.pumpAndSettle();
    }

    testWidgets('no impact shown without Pro, even with a cap stored', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          pro: false,
          categories: foodCategory(1000),
          transactions: spentThisMonth(200),
        ),
      );

      await fillConsider(tester, amount: '300');

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets('no impact shown without a selected category', (tester) async {
      await _openDirect(
        tester,
        _blob(
          pro: true,
          categories: foodCategory(1000),
          transactions: spentThisMonth(200),
        ),
      );

      await tester.enterText(find.byKey(const Key('mindsetAmount')), '300');
      await tester.pumpAndSettle();

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets('no impact shown without a valid amount', (tester) async {
      await _openDirect(
        tester,
        _blob(
          pro: true,
          categories: foodCategory(1000),
          transactions: spentThisMonth(200),
        ),
      );

      await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
      await tester.pumpAndSettle();

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets('no impact shown when the category has no cap set', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          pro: true,
          categories: foodCategory(0),
          transactions: spentThisMonth(200),
        ),
      );

      await fillConsider(tester, amount: '300');

      expect(find.textContaining('BUDGET IMPACT'), findsNothing);
    });

    testWidgets(
      'shows category remaining, purchase amount, and expected remaining when the data is reliable',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(200),
          ),
        );

        await fillConsider(tester, amount: '300');

        expect(find.textContaining('BUDGET IMPACT'), findsOneWidget);
        expect(find.text('Category budget remaining'), findsOneWidget);
        expect(find.text('₱800'), findsOneWidget); // remaining before
        expect(find.text('Purchase amount'), findsOneWidget);
        expect(find.text('₱300'), findsOneWidget);
        expect(find.text('Expected amount remaining'), findsOneWidget);
        expect(find.text('₱500'), findsOneWidget); // 800 - 300
      },
    );

    testWidgets(
      'warns and forces Not in the plan right now when the purchase would exceed the category budget',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(900), // ₱100 left before purchase
          ),
        );

        await fillConsider(tester, amount: '500'); // exceeds by ₱400

        expect(
          find.textContaining('over its ₱1,000 monthly cap'),
          findsOneWidget,
        );

        // Even answers that would otherwise fit the plan under phase 1 do
        // not override reliable budget data.
        await _answer(tester, 0, true); // essential
        await _answer(tester, 1, true); // affordable, not reserved
        await _answer(tester, 2, true); // waited 24h

        expect(find.text('Not in the plan right now'), findsOneWidget);
        expect(find.text('Fits your plan'), findsNothing);
        // The clause now shows up twice: once in the budget impact card,
        // and once folded into "Why this result", per the founder's
        // result-integration rule.
        expect(
          find.textContaining('over its ₱1,000 monthly cap'),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'combines both reasons in Why this result when the reserved-money '
      'answer AND the budget cap both say no',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(900), // ₱100 left before purchase
          ),
        );

        await fillConsider(tester, amount: '500'); // exceeds by ₱400

        await _answer(tester, 0, true); // essential
        await _answer(tester, 1, false); // would touch reserved money
        await _answer(tester, 2, true); // waited 24h

        expect(find.text('Not in the plan right now'), findsOneWidget);
        expect(
          find.textContaining(
            'It would use money already reserved for bills, debt, or '
            'goals, and it would take the Food budget',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'preserves the phase 1 result when the purchase stays within budget',
      (tester) async {
        await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(200),
          ),
        );

        await fillConsider(tester, amount: '300'); // leaves ₱500, no warning

        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);

        expect(find.text('Fits your plan'), findsOneWidget);
        expect(find.text('Not in the plan right now'), findsNothing);
      },
    );

    testWidgets(
      'a store write from OUTSIDE this screen still updates the budget '
      'impact and verdict, not just Small Wins',
      (tester) async {
        // categories, impact and verdict used to be computed in build(),
        // outside the ListenableBuilder that wraps the actual widget tree.
        // ListenableBuilder only re-runs its own builder callback on
        // notifyListeners, never the outer build(), so a write nobody made
        // through this screen's own setState (main.dart posts due recurring
        // transactions on every app-foreground resume, for one real example)
        // rebuilt the Wins list but left the budget card and verdict on
        // stale numbers. This proves the fix by writing directly through
        // the store, with no tap or setState on this screen at all.
        final store = await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: foodCategory(1000),
            transactions: spentThisMonth(200), // ₱800 left
          ),
        );

        await fillConsider(tester, amount: '300'); // leaves ₱500, no warning
        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);
        expect(find.text('Fits your plan'), findsOneWidget);

        // An external write, through the real store, tagging the same
        // category: 600 more spent this month pushes it from 200 to 800,
        // leaving only 200 of the 1,000 cap before the 300 purchase, which
        // now exceeds it by 100. No tap, no setState on this screen.
        await store.addEntry({
          'id': 'ext1',
          'type': 'expense',
          'label': 'Groceries',
          'amount': 600,
          'date': _todayIso(),
          'categoryId': 'food',
        });
        await tester.pump();

        expect(find.text('Not in the plan right now'), findsOneWidget);
        expect(find.text('Fits your plan'), findsNothing);
        expect(find.text('₱200'), findsOneWidget); // new remaining before
      },
    );
  });

  group('clear check resets everything new too', () {
    testWidgets(
      'Clear check empties the item, amount, and category alongside the answers',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: [
              {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 1000},
            ],
          ),
        );

        await tester.enterText(
          find.byKey(const Key('mindsetItemName')),
          'New shoes',
        );
        await tester.enterText(find.byKey(const Key('mindsetAmount')), '300');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.pumpAndSettle();
        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);
        expect(find.text('Fits your plan'), findsOneWidget);

        await tester.ensureVisible(find.text('Clear check'));
        await tester.tap(find.text('Clear check'));
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<TextField>(find.byKey(const Key('mindsetItemName')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('mindsetAmount')))
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '🍚 Food'))
              .selected,
          isFalse,
        );
        expect(
          find.text('Answer all three questions to see where this fits.'),
          findsOneWidget,
        );
        expect(find.text('Clear check'), findsNothing);

        // Clearing the check is purely UI state; the founder's category is
        // still exactly what was loaded.
        expect((store.data['categories'] as List).length, 1);
      },
    );
  });

  group('the decision check never writes a financial record', () {
    testWidgets(
      'entering an item, amount, and category creates no transaction and moves no balance',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            pro: true,
            categories: [
              {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 1000},
            ],
          ),
        );

        final txnsBefore = jsonEncode(store.data['transactions']);
        final catsBefore = jsonEncode(store.data['categories']);

        await tester.enterText(
          find.byKey(const Key('mindsetItemName')),
          'New shoes',
        );
        await tester.enterText(find.byKey(const Key('mindsetAmount')), '300');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.tap(find.widgetWithText(ChoiceChip, '🍚 Food'));
        await tester.pumpAndSettle();
        await _answer(tester, 0, true);
        await _answer(tester, 1, true);
        await _answer(tester, 2, true);

        expect(jsonEncode(store.data['transactions']), txnsBefore);
        expect(jsonEncode(store.data['categories']), catsBefore);
      },
    );
  });
}
