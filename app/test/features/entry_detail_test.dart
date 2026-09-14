// Opening, fixing and removing one entry.
//
// These are the first WRITE paths in v3 beyond logging, and every one of them
// moves an account balance, so the money invariants matter more here than the
// widgets do. An edit that leaves a balance drifted is worse than no edit at
// all: the user believes they corrected something and the ledger quietly
// stopped adding up.
//
// The arithmetic is not this screen's. `updateTransaction` and
// `removeTransaction` are golden locked and already reverse the old effect
// before applying the new one. What is tested here is that the screen calls
// them, with the right values, and never touches a balance itself.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/core/money/ledger.dart' show amountOf;
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';
import 'package:salapify/features/ledger/entry_detail_screen.dart';

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

double _balance(LedgerStore s, String id) {
  for (final a in (s.data['accounts'] as List)) {
    if (a is Map && a['id'] == id) return amountOf(a['balance']);
  }
  fail('no account $id');
}

int _count(LedgerStore s) => (s.data['transactions'] as List).length;

/// Walk to the Ledger and tap a row, the way a person does. Pushing the route
/// directly would pass even with the row unwired, which is the defect this is
/// most likely to be protecting against.
Future<void> _openEntry(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavBar), matching: find.text('Ledger')),
  );
  await tester.pumpAndSettle();
  // Scroll to the row before tapping it. The nav bar is drawn OVER the list
  // (app/shell.dart), and the list reserves 130 at the bottom so nothing is
  // ever stranded underneath it on a phone, but a row can still start the
  // frame behind the bar and a bare tap then lands on the bar instead. A
  // person scrolls. Adding one sentence to the Ledger's subtitle moved this
  // row far enough down to prove the point.
  final row = find.text(label).first;
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

/// Scroll down to something below the fold.
///
/// The screen is a lazy list, so a widget past the bottom of the viewport is
/// not in the tree at all and `findsNothing` would be a true statement about a
/// screen that is perfectly correct. Delete in particular sits under the
/// details and the edit button on purpose, which is exactly where a
/// destructive action belongs.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 200, maxScrolls: 20);
  await tester.pumpAndSettle();
}

void main() {
  group('finding one entry', () {
    test('by id, or null when it is gone', () {
      final data = livedIn();
      expect(findEntry(data, 't3')!['label'], 'Jollibee');
      expect(findEntry(data, 'nope'), isNull);
      expect(findEntry(const {}, 't3'), isNull);
    });
  });

  testWidgets('a Ledger row opens the entry', (tester) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openEntry(tester, 'Jollibee');

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Edit this entry'), findsOneWidget);
    await _scrollTo(tester, find.text('Delete this entry'));
    expect(find.text('Delete this entry'), findsOneWidget);
    // The account it moved, named, because that is the fact a person is
    // usually checking when they open an entry at all.
    expect(find.text('GCash'), findsWidgets);
  });

  testWidgets('editing the amount moves the balance by the DIFFERENCE', (
    tester,
  ) async {
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final before = _balance(store, 'a_gcash');

    await _openEntry(tester, 'Jollibee');
    await tester.tap(find.text('Edit this entry'));
    await tester.pumpAndSettle();

    // 250 becomes 300. The account must fall by 50, not by 300.
    await tester.enterText(find.byType(TextField).at(1), '300');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(
      _balance(store, 'a_gcash'),
      before - 50.0,
      reason:
          'the edit applied the new amount without reversing the old one, so '
          'the balance has drifted',
    );
    expect(findEntry(store.data, 't3')!['amount'], 300.0);
    expect(
      _count(store),
      (livedIn()['transactions'] as List).length,
      reason: 'an edit created a second entry instead of changing one',
    );
  });

  testWidgets('editing the label leaves the money exactly alone', (
    tester,
  ) async {
    // The commonest edit by far: the parser read the words wrong and the
    // amount was right. It must not move a peso.
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final before = _balance(store, 'a_gcash');

    await _openEntry(tester, 'Jollibee');
    await tester.tap(find.text('Edit this entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Jollibee Cubao');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(findEntry(store.data, 't3')!['label'], 'Jollibee Cubao');
    expect(_balance(store, 'a_gcash'), before);
  });

  testWidgets('an unreadable amount leaves the amount alone', (tester) async {
    // A zero is a real figure. "I could not read this" is a different
    // statement, and writing a zero for it would silently destroy the entry's
    // value and move the balance by its whole amount.
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final before = _balance(store, 'a_gcash');

    await _openEntry(tester, 'Jollibee');
    await tester.tap(find.text('Edit this entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'abc');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(findEntry(store.data, 't3')!['amount'], 250.0);
    expect(_balance(store, 'a_gcash'), before);
  });

  group('deleting', () {
    testWidgets('asks first, and keeping it changes nothing', (tester) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final before = _balance(store, 'a_gcash');
      final count = _count(store);

      await _openEntry(tester, 'Jollibee');
      await _scrollTo(tester, find.text('Delete this entry'));
      await tester.tap(find.text('Delete this entry'));
      await tester.pumpAndSettle();

      // The dialog names the amount and what it will do, because "are you
      // sure" alone asks somebody to confirm something they cannot see.
      expect(find.textContaining('₱250'), findsWidgets);
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(_count(store), count);
      expect(_balance(store, 'a_gcash'), before);
    });

    testWidgets('confirming removes it and gives the balance back', (
      tester,
    ) async {
      final store = await memoryStore(livedIn());
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();

      final before = _balance(store, 'a_gcash');
      final count = _count(store);

      await _openEntry(tester, 'Jollibee');
      await _scrollTo(tester, find.text('Delete this entry'));
      await tester.tap(find.text('Delete this entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(_count(store), count - 1);
      expect(findEntry(store.data, 't3'), isNull);
      expect(
        _balance(store, 'a_gcash'),
        before + 250.0,
        reason: 'deleting an expense must hand the money back to the account',
      );

      // And it popped, rather than leaving the user staring at an entry that
      // no longer exists.
      expect(find.text('Delete this entry'), findsNothing);
    });
  });
}
