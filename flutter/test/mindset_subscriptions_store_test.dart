// Storage contract for the subscriptions list: sanitizeData validates it and
// keeps it a CONDITIONAL key (absent when empty, present when not), and the
// store's add/patch/remove survive a restart.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sanitizeData keeps the key off when the list is empty or absent', () {
    final none = sanitizeData({'settings': {}});
    expect(
      (none['settings'] as Map).containsKey('mindsetSubscriptions'),
      false,
    );
    final empty = sanitizeData({
      'settings': {'mindsetSubscriptions': []},
    });
    expect(
      (empty['settings'] as Map).containsKey('mindsetSubscriptions'),
      false,
    );
  });

  test('sanitizeData validates rows and drops non-maps', () {
    final clean = sanitizeData({
      'settings': {
        'mindsetSubscriptions': [
          {'id': 's1', 'name': 'Streaming', 'amount': 149, 'cycle': 'monthly'},
          {'name': 'Storage', 'amount': -12, 'cycle': 'annual'}, // no id, neg
          'junk',
        ],
      },
    });
    final list = (clean['settings'] as Map)['mindsetSubscriptions'] as List;
    expect(list.length, 2); // the two maps survive, the string is dropped
    expect(list[0]['id'], 's1');
    expect((list[1]['id'] as String).startsWith('sub_restored_'), true);
    expect(list[1]['amount'], 0.0); // negative coerced
    expect(list[1]['cycle'], 'annual');
  });

  test('add, patch, and remove survive a restart', () async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({'settings': {}}),
    });
    final store = SalapifyStore();
    await store.load();
    expect(store.mindsetSubscriptions, isEmpty);

    await store.addMindsetSubscription(
      name: 'Streaming',
      amount: 149,
      cycle: 'monthly',
    );
    await store.addMindsetSubscription(
      name: 'Cloud',
      amount: 2400,
      cycle: 'annual',
    );
    expect(store.mindsetSubscriptions.length, 2);
    final id = store.mindsetSubscriptions.first['id'] as String;

    await store.patchMindsetSubscription(id, {'amount': 199.0});
    expect(store.mindsetSubscriptions.first['amount'], 199.0);

    // Reload from disk: the list persists.
    final reopened = SalapifyStore();
    await reopened.load();
    expect(reopened.mindsetSubscriptions.length, 2);
    expect(reopened.mindsetSubscriptions.first['amount'], 199.0);

    await reopened.removeMindsetSubscription(id);
    expect(reopened.mindsetSubscriptions.length, 1);
    expect(reopened.mindsetSubscriptions.first['name'], 'Cloud');
  });
}
