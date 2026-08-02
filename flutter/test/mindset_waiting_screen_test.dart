// Money Mindset Phase 3: the "Revisit in 24 hours" save, the Waiting section
// (due and not-due states, cancel with undo), the "Do you still want this?"
// prompt (review again, skip it, wait another 24 hours), persistence across
// a simulated restart, junk records staying readable, and that none of this
// ever creates a transaction or moves a balance.
//
// Mounts MindsetScreen directly (the categories_screen_test.dart pattern),
// since none of this needs the full app shell.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _waitingItem({
  String id = 'w1',
  String itemName = 'New shoes',
  double? amount = 1500,
  String? categoryId,
  String status = 'waiting',
  required DateTime revisitAt,
  DateTime? createdAt,
}) => {
  'id': id,
  'itemName': itemName,
  'amount': ?amount,
  'categoryId': ?categoryId,
  'essential': false,
  'affordableWithoutReserved': true,
  'waited24h': false,
  'result': 'pause24h',
  'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
  'revisitAt': revisitAt.toIso8601String(),
  'status': status,
};

Map<String, dynamic> _blob({
  List<Map<String, dynamic>> waiting = const [],
  List<Map<String, dynamic>> categories = const [],
  List<Map<String, dynamic>> transactions = const [],
  List<Map<String, dynamic>> accounts = const [],
}) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true, 'mindsetWaiting': waiting},
  'categories': categories,
  'transactions': transactions,
  'accounts': accounts,
};

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

// scrollUntilVisible, not ensureVisible: a waiting item seeded straight into
// the starting blob (rather than grown through interaction) can sit past
// what the ListView built on its first layout pass (viewport plus a small
// cache extent), so the element does not exist in the tree yet for
// ensureVisible/find to locate. scrollUntilVisible scrolls and re-checks in
// steps, which forces more of the list to build.
Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 400, scrollable: find.byType(Scrollable).first);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

// scrollUntilVisible only ever drags one direction (down, revealing later
// content), so once it has overshot a target that sits ABOVE the current
// scroll position, it can never find it again by continuing to scroll the
// same way. A prior _scrollTo/_tap in the same test can leave the list
// scrolled well past a section that later needs finding again (WAITING,
// once Undo brings it back); dragging all the way back to the top first
// guarantees the next _scrollTo always has somewhere forward to go.
Future<void> _scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
  await tester.pumpAndSettle();
}

Future<void> _answer(WidgetTester tester, int i, bool yes) =>
    _tap(tester, find.text(yes ? 'Yes' : 'No').at(i));

void main() {
  group('Revisit in 24 hours', () {
    testWidgets('only offered for a Pause for 24 hours verdict', (
      tester,
    ) async {
      await _openDirect(tester, _blob());

      // Fits your plan: no button.
      await _answer(tester, 0, true);
      await _answer(tester, 1, true);
      await _answer(tester, 2, true);
      expect(find.text('Fits your plan'), findsOneWidget);
      expect(find.text('Revisit in 24 hours'), findsNothing);

      // Not in the plan: no button either.
      await _tap(tester, find.text('Clear check'));
      await _answer(tester, 0, true);
      await _answer(tester, 1, false);
      await _answer(tester, 2, true);
      expect(find.text('Not in the plan right now'), findsOneWidget);
      expect(find.text('Revisit in 24 hours'), findsNothing);

      // Pause for 24 hours: the button appears.
      await _tap(tester, find.text('Clear check'));
      await _answer(tester, 0, false);
      await _answer(tester, 1, true);
      await _answer(tester, 2, false);
      expect(find.text('Pause for 24 hours'), findsOneWidget);
      expect(find.text('Revisit in 24 hours'), findsOneWidget);
    });

    testWidgets('saving is optional: reaching pause24h alone saves nothing', (
      tester,
    ) async {
      final store = await _openDirect(tester, _blob());

      await _answer(tester, 0, false);
      await _answer(tester, 1, true);
      await _answer(tester, 2, false);
      expect(find.text('Pause for 24 hours'), findsOneWidget);

      expect(store.mindsetWaiting, isEmpty);
    });

    testWidgets(
      'tapping it saves the item, answers, and result, then clears the check',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            categories: [
              {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 0},
            ],
          ),
        );

        await tester.enterText(
          find.byKey(const Key('mindsetItemName')),
          'New shoes',
        );
        await tester.enterText(find.byKey(const Key('mindsetAmount')), '1500');
        await tester.pumpAndSettle();
        await _tap(tester, find.widgetWithText(ChoiceChip, '🍚 Food'));
        await _answer(tester, 0, false); // essential = false
        await _answer(tester, 1, true); // affordableWithoutReserved = true
        await _answer(tester, 2, false); // waited24h = false
        expect(find.text('Pause for 24 hours'), findsOneWidget);

        await _tap(tester, find.text('Revisit in 24 hours'));

        expect(store.mindsetWaiting, hasLength(1));
        final saved = store.mindsetWaiting.single;
        expect(saved['itemName'], 'New shoes');
        expect(saved['amount'], 1500.0);
        expect(saved['categoryId'], 'food');
        expect(saved['essential'], isFalse);
        expect(saved['affordableWithoutReserved'], isTrue);
        expect(saved['waited24h'], isFalse);
        expect(saved['result'], 'pause24h');
        expect(saved['status'], 'waiting');
        expect(saved['id'], isA<String>());
        expect(saved['createdAt'], isA<String>());
        final revisitAt = DateTime.parse(saved['revisitAt'] as String);
        final createdAt = DateTime.parse(saved['createdAt'] as String);
        expect(
          revisitAt.difference(createdAt),
          const Duration(hours: 24),
          reason: 'the whole point of "Pause for 24 hours"',
        );

        // The check clears: back to neutral, considering fields empty.
        expect(
          find.text('Answer all three questions to see where this fits.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('mindsetItemName')))
              .controller!
              .text,
          isEmpty,
        );
      },
    );

    testWidgets('an untitled item still saves, with a safe fallback name', (
      tester,
    ) async {
      final store = await _openDirect(tester, _blob());

      await _answer(tester, 0, false);
      await _answer(tester, 1, true);
      await _answer(tester, 2, false);
      await _tap(tester, find.text('Revisit in 24 hours'));

      expect(store.mindsetWaiting.single['itemName'], isNotEmpty);
      expect(
        (store.mindsetWaiting.single['itemName'] as String).toLowerCase(),
        isNot(contains('null')),
      );
    });

    testWidgets('a fast double tap saves only one item, not two', (
      tester,
    ) async {
      // Guards against a real bug qa-tester found: without _savingToWaiting,
      // two fast taps could fire _saveToWaiting twice on identical answers.
      // Honesty about this test's own limit, per this repo's prove-it-can-
      // fail discipline: disabling the guard and rerunning this exact test
      // still passed. tester.tap()'s own internal pump appears to let the
      // mocked (near-instant) store write finish between the two calls in
      // this harness, so the race the guard defends against did not
      // reproduce here even with the fix removed. The guard itself still
      // matches the same busy-flag pattern every sibling save action in this
      // app already uses (payday.dart, recurring.dart, paluwagan.dart,
      // treats.dart), so it stays; this test is basic regression coverage
      // for the visible outcome, not proven-failing evidence for the race.
      final store = await _openDirect(tester, _blob());

      await _answer(tester, 0, false);
      await _answer(tester, 1, true);
      await _answer(tester, 2, false);
      await _scrollTo(tester, find.text('Revisit in 24 hours'));
      await tester.pumpAndSettle();

      // Two taps back to back, no settle in between.
      await tester.tap(find.text('Revisit in 24 hours'));
      await tester.tap(find.text('Revisit in 24 hours'));
      await tester.pumpAndSettle();

      expect(store.mindsetWaiting, hasLength(1));
    });
  });

  group('the Waiting section', () {
    testWidgets('lists item, amount, and a remaining-time label', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          waiting: [
            _waitingItem(
              itemName: 'New shoes',
              amount: 1500,
              revisitAt: DateTime.now().add(const Duration(hours: 20)),
            ),
          ],
        ),
      );

      await _scrollTo(tester, find.text('WAITING'));
      expect(find.text('WAITING'), findsOneWidget);
      expect(find.text('New shoes'), findsOneWidget);
      expect(find.text('₱1,500'), findsOneWidget);
      expect(find.textContaining('Revisit in'), findsOneWidget);
      expect(find.text('Ready to revisit'), findsNothing);
    });

    testWidgets('hidden entirely when nothing is waiting', (tester) async {
      await _openDirect(tester, _blob());
      expect(find.text('WAITING'), findsNothing);
    });

    testWidgets('a due item reads "Ready to revisit" and opens the prompt', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          waiting: [
            _waitingItem(
              revisitAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      );

      await _scrollTo(tester, find.text('Ready to revisit'));
      expect(find.text('Ready to revisit'), findsOneWidget);
      await _tap(tester, find.text('Ready to revisit'));

      expect(find.text('Do you still want this?'), findsOneWidget);
      expect(find.text('Yes, review again'), findsOneWidget);
      expect(find.text('No, skip it'), findsOneWidget);
      expect(find.text('Not sure, wait another 24 hours'), findsOneWidget);
    });

    testWidgets('a not-due item does not open the prompt on tap', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          waiting: [
            _waitingItem(
              revisitAt: DateTime.now().add(const Duration(hours: 5)),
            ),
          ],
        ),
      );

      await _tap(tester, find.text('New shoes'));

      expect(find.text('Do you still want this?'), findsNothing);
    });

    testWidgets('Cancel dismisses the item, Undo brings it back', (
      tester,
    ) async {
      final store = await _openDirect(
        tester,
        _blob(
          waiting: [
            _waitingItem(
              revisitAt: DateTime.now().add(const Duration(hours: 5)),
            ),
          ],
        ),
      );
      final id = store.mindsetWaiting.single['id'];

      await _tap(tester, find.byTooltip('Cancel'));

      expect(find.text('WAITING'), findsNothing);
      // store.mindsetWaiting is the raw list (every status); the screen's own
      // waitingItems() filter is what drops a dismissed row from the section.
      expect(
        store.mindsetWaiting.singleWhere((w) => w['id'] == id)['status'],
        'dismissed',
        reason: 'patched, not deleted',
      );

      await _tap(tester, find.text('Undo'));

      await _scrollToTop(tester);
      await _scrollTo(tester, find.text('WAITING'));
      expect(find.text('WAITING'), findsOneWidget);
      expect(store.mindsetWaiting.single['id'], id);
      expect(store.mindsetWaiting.single['status'], 'waiting');
    });
  });

  group('the Do you still want this prompt', () {
    testWidgets('Yes, review again: restores the item and clears the answers', (
      tester,
    ) async {
      final store = await _openDirect(
        tester,
        _blob(
          categories: [
            {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 0},
          ],
          waiting: [
            _waitingItem(
              itemName: 'New shoes',
              amount: 1500,
              categoryId: 'food',
              revisitAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      );

      await _scrollTo(tester, find.text('Ready to revisit'));
      await _tap(tester, find.text('Ready to revisit'));
      await _tap(tester, find.text('Yes, review again'));

      expect(
        store.mindsetWaiting.single['status'],
        'reviewed',
        reason: 'patched, not deleted; the screen filters it out of Waiting',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mindsetItemName')))
            .controller!
            .text,
        'New shoes',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mindsetAmount')))
            .controller!
            .text,
        '1500',
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '🍚 Food'))
            .selected,
        isTrue,
      );
      // The three answers come back BLANK, not inherited from before.
      expect(
        find.text('Answer all three questions to see where this fits.'),
        findsOneWidget,
      );
    });

    testWidgets('No, skip it: prefills Small Wins without saving a win', (
      tester,
    ) async {
      final store = await _openDirect(
        tester,
        _blob(
          waiting: [
            _waitingItem(
              itemName: 'New shoes',
              revisitAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      );

      await _scrollTo(tester, find.text('Ready to revisit'));
      await _tap(tester, find.text('Ready to revisit'));
      await _tap(tester, find.text('No, skip it'));

      expect(store.mindsetWaiting.single['status'], 'skipped');
      await _scrollTo(tester, find.byKey(const Key('mindsetWinText')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mindsetWinText')))
            .controller!
            .text,
        contains('New shoes'),
      );
      // The waiting item's own estimated amount (1500, _waitingItem's
      // default) prefills the optional "Spending avoided" field too, and
      // that field's own panel opens automatically to show it, rather than
      // leaving the amount collapsed and invisible.
      await _scrollTo(tester, find.byKey(const Key('mindsetWinAmount')));
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('mindsetWinAmount')))
            .controller!
            .text,
        '1500',
      );
      expect(
        (store.data['wins'] as List? ?? const []),
        isEmpty,
        reason: 'prefilled, never auto-saved',
      );
    });

    testWidgets(
      'Not sure, wait another 24 hours: stays waiting with a later revisit time',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            waiting: [
              _waitingItem(
                revisitAt: DateTime.now().subtract(const Duration(hours: 1)),
              ),
            ],
          ),
        );
        final before = DateTime.parse(
          store.mindsetWaiting.single['revisitAt'] as String,
        );

        await _scrollTo(tester, find.text('Ready to revisit'));
        await _tap(tester, find.text('Ready to revisit'));
        await _tap(tester, find.text('Not sure, wait another 24 hours'));

        expect(store.mindsetWaiting, hasLength(1));
        expect(store.mindsetWaiting.single['status'], 'waiting');
        final after = DateTime.parse(
          store.mindsetWaiting.single['revisitAt'] as String,
        );
        expect(after.isAfter(before), isTrue);
        expect(find.text('Ready to revisit'), findsNothing);
      },
    );

    testWidgets(
      'Review again on a due item asks before replacing unsaved considering input',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            waiting: [
              _waitingItem(
                itemName: 'Old shoes',
                revisitAt: DateTime.now().subtract(const Duration(hours: 1)),
              ),
            ],
          ),
        );

        // Something unrelated already typed in the considering panel.
        await tester.enterText(
          find.byKey(const Key('mindsetItemName')),
          'Something else entirely',
        );
        await tester.pumpAndSettle();

        await _scrollTo(tester, find.text('Ready to revisit'));
        await _tap(tester, find.text('Ready to revisit'));
        await _tap(tester, find.text('Yes, review again'));

        // The confirm dialog appears instead of silently overwriting.
        expect(find.text('Replace what you have?'), findsOneWidget);
        expect(
          store.mindsetWaiting.single['status'],
          'waiting',
          reason: 'not yet acted on',
        );

        // Cancel: nothing changes.
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('mindsetItemName')))
              .controller!
              .text,
          'Something else entirely',
        );
        expect(store.mindsetWaiting.single['status'], 'waiting');

        // Try again and confirm Replace this time: proceeds as normal.
        await _tap(tester, find.text('Ready to revisit'));
        await _tap(tester, find.text('Yes, review again'));
        await tester.tap(find.text('Replace'));
        await tester.pumpAndSettle();

        expect(store.mindsetWaiting.single['status'], 'reviewed');
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('mindsetItemName')))
              .controller!
              .text,
          'Old shoes',
        );
      },
    );

    testWidgets('Yes, review again clears the decision-check log guard too, so '
        're-answering the three questions logs a fresh completed check', (
      tester,
    ) async {
      // Money Mindset Phase 4's decision-check log guards against logging
      // the same completed check twice while an answer is flipped back
      // and forth, but "Yes, review again" blanks the three answers the
      // same way Clear check does, and has to reset that same guard, or
      // the SECOND check completed in one screen visit is silently never
      // logged.
      final store = await _openDirect(
        tester,
        _blob(
          waiting: [
            _waitingItem(
              itemName: 'Old shoes',
              revisitAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      );

      await _answer(tester, 0, true);
      await _answer(tester, 1, true);
      await _answer(tester, 2, true);
      expect(store.mindsetChecks, hasLength(1));

      await _scrollTo(tester, find.text('Ready to revisit'));
      await _tap(tester, find.text('Ready to revisit'));
      await _tap(tester, find.text('Yes, review again'));
      await _tap(tester, find.text('Replace'));

      await _answer(tester, 0, false);
      await _answer(tester, 1, true);
      await _answer(tester, 2, false);
      expect(
        store.mindsetChecks,
        hasLength(2),
        reason:
            're-answering after review again is a second, separate '
            'completed check',
      );
    });
  });

  group('persistence survives a restart', () {
    testWidgets('a saved waiting item reloads from disk with the same id', (
      tester,
    ) async {
      final storeA = await _openDirect(tester, _blob());
      await _answer(tester, 0, false);
      await _answer(tester, 1, true);
      await _answer(tester, 2, false);
      await tester.enterText(
        find.byKey(const Key('mindsetItemName')),
        'New shoes',
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Revisit in 24 hours'));
      final savedId = storeA.mindsetWaiting.single['id'];

      // A fresh store instance over the SAME mock storage, the "restart".
      final storeB = SalapifyStore();
      await storeB.load();

      expect(storeB.mindsetWaiting, hasLength(1));
      expect(storeB.mindsetWaiting.single['id'], savedId);
      expect(storeB.mindsetWaiting.single['itemName'], 'New shoes');
    });
  });

  group('existing records remain readable', () {
    testWidgets('junk-shaped waiting entries do not crash the screen', (
      tester,
    ) async {
      await _openDirect(
        tester,
        _blob(
          waiting: [
            {'not': 'a real item'},
            {'id': 'x', 'status': 'waiting'}, // no revisitAt
            {'id': 'y', 'status': 'waiting', 'revisitAt': 'garbage'},
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      // Missing/unreadable revisitAt fails toward due, per money/mindset_waiting.dart.
      await _scrollTo(tester, find.text('WAITING'));
      expect(find.text('WAITING'), findsOneWidget);
    });
  });

  group('money is never touched', () {
    testWidgets(
      'the full waiting-list flow creates no transaction and moves no balance',
      (tester) async {
        final store = await _openDirect(
          tester,
          _blob(
            accounts: [
              {'id': 'a1', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
            ],
          ),
        );

        await _answer(tester, 0, false);
        await _answer(tester, 1, true);
        await _answer(tester, 2, false);
        await _tap(tester, find.text('Revisit in 24 hours'));
        expect(store.mindsetWaiting, hasLength(1));

        // Push it through the full lifecycle: due, waited more, then reviewed.
        await store.patchMindsetWaitingItem(
          store.mindsetWaiting.single['id'] as String,
          {
            'revisitAt': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
          },
        );
        await tester.pumpAndSettle();
        await _tap(tester, find.text('Ready to revisit'));
        await _tap(tester, find.text('Not sure, wait another 24 hours'));

        expect(store.data['transactions'], isEmpty);
        expect(
          (store.data['accounts'] as List).cast<Map>().single['balance'],
          5000,
        );
      },
    );
  });
}
