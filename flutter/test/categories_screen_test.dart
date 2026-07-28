// The Categories screen: caps, nesting, and above all the delete flow.
//
// The delete flow is a founder decision made into a screen, so it gets the
// heaviest guards here: an entry's money and date must survive a category
// being deleted, the count shown must be the real count, and untagging must
// be a deliberate choice rather than the default. The reshaping itself is
// golden locked in categories_golden_test.dart; this file proves the screen
// asks the right question and passes the right answer down.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/categories.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob({bool pro = false}) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true, if (pro) 'pro': true},
  'categories': [
    {'id': 'food', 'name': 'Food', 'icon': '🍚', 'monthlyCap': 0},
    {'id': 'bills', 'name': 'Bills', 'icon': '💡', 'monthlyCap': 0},
    {
      'id': 'grocery',
      'name': 'Groceries',
      'icon': '🛒',
      'monthlyCap': 0,
      'parentId': 'food',
    },
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Jollibee',
      'amount': 250,
      'date': _today(),
      'categoryId': 'food',
    },
    {
      'id': 't2',
      'type': 'expense',
      'label': 'Meralco',
      'amount': 1800,
      'date': _today(),
      'categoryId': 'bills',
    },
  ],
};

String _today() {
  final n = DateTime.now();
  return '${n.year.toString().padLeft(4, '0')}-'
      '${n.month.toString().padLeft(2, '0')}-'
      '${n.day.toString().padLeft(2, '0')}';
}

Future<SalapifyStore> _open(
  WidgetTester tester, {
  Map<String, dynamic>? blob,
}) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(blob ?? _blob()),
  });
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(MaterialApp(home: CategoriesScreen(store: store)));
  await tester.pumpAndSettle();
  return store;
}

List<Map<String, dynamic>> _cats(SalapifyStore s) =>
    (s.data['categories'] as List).cast<Map<String, dynamic>>();
List<Map<String, dynamic>> _txns(SalapifyStore s) =>
    (s.data['transactions'] as List).cast<Map<String, dynamic>>();

Future<void> _openDeleteFor(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deleting a category MOVES its entries, keeping every peso', (
    tester,
  ) async {
    // The founder's rule, end to end. Food has one entry; it must survive the
    // delete with its amount, date and label intact, wearing the new tag.
    final store = await _open(tester);
    await _openDeleteFor(tester, 'Food');
    expect(find.textContaining('1 entry is tagged'), findsOneWidget);

    await tester.tap(find.text('💡 Bills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    expect(_cats(store).any((c) => c['id'] == 'food'), isFalse);
    // Asserted BEFORE reading the row, so a delete that drops entries fails
    // with the sentence that names the harm rather than "Bad state: No
    // element" three lines later.
    expect(
      _txns(store).any((t) => t['id'] == 't1'),
      isTrue,
      reason: 'the entry must survive its category being deleted',
    );
    final moved = _txns(store).firstWhere((t) => t['id'] == 't1');
    expect(moved['categoryId'], 'bills');
    expect(moved['amount'], 250);
    expect(moved['label'], 'Jollibee');
    expect(moved['date'], _today());
    // Nothing else was touched.
    expect(
      _txns(store).firstWhere((t) => t['id'] == 't2')['categoryId'],
      'bills',
    );
    expect(_txns(store), hasLength(2));
  });

  testWidgets('a child is promoted, not deleted, with its parent', (
    tester,
  ) async {
    final store = await _open(tester);
    await _openDeleteFor(tester, 'Food');
    await tester.tap(find.text('💡 Bills'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    final grocery = _cats(store).firstWhere((c) => c['id'] == 'grocery');
    expect(grocery['parentId'], isNull, reason: 'promoted to top level');
    expect(grocery['name'], 'Groceries');
  });

  testWidgets('the DEFAULT is moving, not untagging', (tester) async {
    // Looking at the render caught this: the sheet opened with "No category"
    // selected, so someone tapping straight through lost every tag. The
    // founder's rule is that entries MOVE, so the sheet opens on a real
    // category and a straight-through tap moves them.
    //
    // The first version of this test asserted that untagging was "a
    // deliberate second choice" while the code made it the default. It
    // passed. A test written from the same mistaken picture as the code
    // certifies the mistake.
    final store = await _open(tester);
    await _openDeleteFor(tester, 'Food');
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    final t1 = _txns(store).firstWhere((t) => t['id'] == 't1');
    expect(
      t1['categoryId'],
      isNotNull,
      reason: 'tapping straight through must not drop the tag',
    );
    expect(t1['amount'], 250);
  });

  testWidgets('untagging happens only when it is chosen', (tester) async {
    final store = await _open(tester);
    await _openDeleteFor(tester, 'Food');
    await tester.tap(find.text('No category'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('They stay in your history with no category'),
      findsOneWidget,
    );
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();

    final t1 = _txns(store).firstWhere((t) => t['id'] == 't1');
    expect(t1.containsKey('categoryId'), isFalse);
    // Losing a tag is recoverable; losing the row is not, and the difference
    // is the whole feature.
    expect(t1['amount'], 250);
    expect(t1['label'], 'Jollibee');
  });

  testWidgets('the count in the sheet is the real count', (tester) async {
    // A confirmation that lies about size is worse than no confirmation.
    final store = await _open(tester);
    await store.addEntry({
      'type': 'expense',
      'label': 'Grab',
      'amount': 120.0,
      'date': _today(),
      'categoryId': 'food',
    });
    await tester.pumpAndSettle();
    await _openDeleteFor(tester, 'Food');
    expect(find.textContaining('2 entries are tagged'), findsOneWidget);
  });

  testWidgets('a category with nothing tagged says so plainly', (tester) async {
    final store = await _open(tester);
    await store.saveCategory(name: 'Empty', icon: '📦', capText: '');
    await tester.pumpAndSettle();
    await _openDeleteFor(tester, 'Empty');
    expect(find.textContaining('Nothing is tagged'), findsOneWidget);
    expect(find.text('No category'), findsNothing, reason: 'nothing to move');
  });

  testWidgets('caps are refused without Pro, and honoured with it', (
    tester,
  ) async {
    final store = await _open(tester);
    final refused = await store.saveCategory(
      name: 'Food',
      icon: '🍚',
      capText: '3000',
    );
    expect(refused, contains('Pro'));

    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(_blob(pro: true)),
    });
    final proStore = SalapifyStore();
    await proStore.load();
    final ok = await proStore.saveCategory(
      id: 'food',
      name: 'Food',
      icon: '🍚',
      capText: '3,000',
    );
    expect(ok, isNull);
    expect(
      _cats(proStore).firstWhere((c) => c['id'] == 'food')['monthlyCap'],
      3000,
    );
  });

  testWidgets('a cap that is being blown says so on the row', (tester) async {
    final store = await _open(tester, blob: _blob(pro: true));
    await store.saveCategory(
      id: 'bills',
      name: 'Bills',
      icon: '💡',
      capText: '1000',
    );
    await tester.pumpAndSettle();
    // 1,800 spent against a 1,000 cap.
    expect(find.textContaining('Over the cap.'), findsOneWidget);
  });

  testWidgets('a junk cap is refused with a sentence, not a crash', (
    tester,
  ) async {
    final store = await _open(tester, blob: _blob(pro: true));
    expect(
      await store.saveCategory(name: 'X', icon: '', capText: 'abc'),
      'Enter a valid monthly cap, or leave it empty.',
    );
    expect(
      await store.saveCategory(name: 'X', icon: '', capText: '-5'),
      'Enter a valid monthly cap, or leave it empty.',
    );
    expect(
      await store.saveCategory(name: '   ', icon: '', capText: ''),
      'Please enter a name.',
    );
  });
}
