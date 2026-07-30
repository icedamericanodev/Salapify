// Loading the sample set from a phone already in use, and the promise that it
// cannot cost you anything.
//
// The generator has always existed and was reachable from exactly one place: the
// last step of onboarding. So the founder, who asked for data to poke at while
// they were at work, could not get to data the app had all along.
//
// The reason this is safe is a property of the seed rather than a promise in a
// comment. Every seeded row carries the `sample_` id prefix, the write APPENDS
// and reads nothing existing, and removal drops exactly that prefix. The tests
// below assert each of those separately, because "it appends" and "removal takes
// back exactly what it added" are two different claims and only one of them is
// obvious from the code.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/sample_data.dart' show hasSampleData;
import 'package:salapify/screens/menu.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A phone with real money already on it. The whole point is that this survives.
Map<String, dynamic> _realData() => {
  'schemaVersion': 12,
  'settings': {'onboarded': true, 'monthlyLimit': 18000},
  'accounts': [
    {'id': 'mine', 'name': 'My Bank', 'kind': 'savings', 'balance': 41234.56},
  ],
  'transactions': [
    {
      'id': 'real1',
      'type': 'expense',
      'label': 'My real groceries',
      'amount': 1234.56,
      'date': '2026-07-10',
      'accountId': 'mine',
    },
  ],
  'receivables': [
    {'id': 'realr', 'person': 'My friend', 'amount': 500, 'dueDate': '2026-07-20'},
  ],
  'debts': <Map<String, dynamic>>[],
};

Future<SalapifyStore> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 4200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(_realData()),
  });
  final store = SalapifyStore();
  await store.load();
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: MenuScreen(store: store, onSwitchTab: (_) {}),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// The rows a person actually typed, as a comparable string.
String _realRows(SalapifyStore store) {
  String rows(String key) {
    final list = store.data[key];
    if (list is! List) return '';
    return list
        .whereType<Map>()
        .where((r) => !'${r['id']}'.startsWith('sample_'))
        .map(jsonEncode)
        .join('|');
  }

  return [
    rows('accounts'),
    rows('transactions'),
    rows('receivables'),
    rows('debts'),
  ].join('#');
}

void main() {
  testWidgets('the card is reachable from Menu and loads the sample set', (
    tester,
  ) async {
    final store = await _open(tester);
    expect(hasSampleData(store.data), isFalse);

    final button = find.text('Load sample data');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(
      hasSampleData(store.data),
      isTrue,
      reason: 'the button did nothing, which is the whole feature',
    );
    // And the card now offers the way back, in the same place.
    expect(find.text('Remove sample data'), findsOneWidget);
  });

  testWidgets('loading it cannot touch a single real row', (tester) async {
    // The promise the card makes in plain words. Asserted on the real rows
    // specifically, rather than on a count, because a count would also pass if
    // the seed quietly rewrote an account it did not create.
    final store = await _open(tester);
    final realBefore = _realRows(store);

    await tester.ensureVisible(find.text('Load sample data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load sample data'));
    await tester.pumpAndSettle();

    expect(
      _realRows(store),
      realBefore,
      reason:
          'a row the person typed changed when sample data was loaded. This is '
          'the one thing this feature must never do.',
    );
  });

  testWidgets('removing it puts the phone back exactly as it was', (
    tester,
  ) async {
    final store = await _open(tester);
    final realBefore = _realRows(store);

    await tester.ensureVisible(find.text('Load sample data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load sample data'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Remove sample data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove sample data'));
    await tester.pumpAndSettle();

    expect(hasSampleData(store.data), isFalse, reason: 'sample rows survived');
    expect(
      _realRows(store),
      realBefore,
      reason: 'the round trip did not land back where it started',
    );
  });

  testWidgets('loading twice does not make two of everything', (tester) async {
    // Without the idempotence guard there would be two sample cards and two
    // Jollibees, every figure in between would be quietly doubled, and one
    // Remove would clear both so the doubling would never be visible
    // afterwards. Worth its own case because the failure hides its own cause.
    final store = await _open(tester);
    await tester.ensureVisible(find.text('Load sample data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load sample data'));
    await tester.pumpAndSettle();
    final once = jsonEncode(store.data);

    // Straight at the store, because the button correctly becomes Remove.
    await store.addSampleData();
    expect(
      jsonEncode(store.data),
      once,
      reason: 'a second load added a second copy of the sample set',
    );
  });

  testWidgets('it is offered in a read-only state as disabled, not hidden', (
    tester,
  ) async {
    // Sample data during app-lock read-only mode must not be loadable, and the
    // card must still be visible: a control that vanishes reads as a bug,
    // whereas a greyed one reads as a state.
    final store = await _open(tester);
    expect(find.text('Load sample data'), findsOneWidget);
    final btn = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Load sample data'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      btn.onPressed,
      store.canWrite ? isNotNull : isNull,
      reason: 'the button ignores whether the store is writable',
    );
  });
}
