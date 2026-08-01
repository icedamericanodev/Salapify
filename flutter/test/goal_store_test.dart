// Store-level vectors for the goal write paths the redesign added. The
// money rule under test everywhere: goal writes move tracked NUMBERS, and
// no path may create or destroy one centavo of them.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _store(List<Map<String, dynamic>> goals) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode({'goals': goals}),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

double _saved(SalapifyStore s, String id) {
  final g = (s.data['goals'] as List)
      .whereType<Map>()
      .firstWhere((x) => x['id'] == id);
  return (g['saved'] as num).toDouble();
}

List _contribs(SalapifyStore s, String id) {
  final g = (s.data['goals'] as List)
      .whereType<Map>()
      .firstWhere((x) => x['id'] == id);
  return (g['contributions'] as List? ?? const []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('transferGoalFunds', () {
    test('moves the amount and records history on both sides', () async {
      final s = await _store([
        {'id': 'a', 'name': 'A', 'target': 10000, 'saved': 5000},
        {'id': 'b', 'name': 'B', 'target': 10000, 'saved': 1000},
      ]);
      await s.transferGoalFunds('a', 'b', 2000);
      expect(_saved(s, 'a'), 3000.0);
      expect(_saved(s, 'b'), 3000.0);
      expect((_contribs(s, 'a').last as Map)['amount'], -2000.0);
      expect((_contribs(s, 'b').last as Map)['amount'], 2000.0);
    });

    test('clamps to what the source actually holds', () async {
      final s = await _store([
        {'id': 'a', 'name': 'A', 'target': 10000, 'saved': 500},
        {'id': 'b', 'name': 'B', 'target': 10000, 'saved': 0},
      ]);
      await s.transferGoalFunds('a', 'b', 9999);
      expect(_saved(s, 'a'), 0.0);
      expect(_saved(s, 'b'), 500.0);
    });

    test('a vanished destination cancels the whole transfer', () async {
      // The deduction pass runs first; if the destination was deleted on
      // another screen between opening the sheet and tapping Move, keeping
      // the minus while dropping the plus would DESTROY tracked money. The
      // honest outcome is no transfer at all.
      final s = await _store([
        {'id': 'a', 'name': 'A', 'target': 10000, 'saved': 5000},
      ]);
      await s.transferGoalFunds('a', 'gone', 2000);
      expect(_saved(s, 'a'), 5000.0, reason: 'nothing may leave the source');
      expect(_contribs(s, 'a'), isEmpty, reason: 'and no history row lies');
    });

    test('same goal and non-positive amounts are no-ops', () async {
      final s = await _store([
        {'id': 'a', 'name': 'A', 'target': 10000, 'saved': 5000},
        {'id': 'b', 'name': 'B', 'target': 10000, 'saved': 0},
      ]);
      await s.transferGoalFunds('a', 'a', 2000);
      await s.transferGoalFunds('a', 'b', 0);
      await s.transferGoalFunds('a', 'b', -50);
      await s.transferGoalFunds('a', 'b', double.nan);
      expect(_saved(s, 'a'), 5000.0);
      expect(_saved(s, 'b'), 0.0);
    });
  });

  group('history and restore', () {
    test('addGoalFunds appends a dated history row', () async {
      final s = await _store([
        {'id': 'a', 'name': 'A', 'target': 10000, 'saved': 0},
      ]);
      await s.addGoalFunds('a', 750);
      final row = _contribs(s, 'a').single as Map;
      expect(row['amount'], 750.0);
      expect((row['date'] as String).length, 10);
    });

    test('restoreGoalRow puts the exact row back, history included', () async {
      final s = await _store([
        {'id': 'a', 'name': 'A', 'target': 10000, 'saved': 0},
      ]);
      await s.addGoalFunds('a', 750);
      final snapshot = ((s.data['goals'] as List).first as Map)
          .cast<String, dynamic>();
      await s.deleteGoal('a');
      expect((s.data['goals'] as List), isEmpty);
      await s.restoreGoalRow(snapshot);
      final back = (s.data['goals'] as List).single as Map;
      expect(back['id'], 'a');
      expect(back['saved'], 750.0);
      expect((back['contributions'] as List).length, 1);
    });

    test('new goal fields survive a save and reload round trip', () async {
      final s = await _store([]);
      await s.addGoal(
        name: 'Trip',
        target: 20000,
        saved: 0,
        targetDate: '2030-01-15',
        kind: 'savings',
        iconKey: 'travel',
        accent: 'caramel',
        frequency: 'weekly',
        createdAt: '2026-01-15',
      );
      await s.patchGoal(
        ((s.data['goals'] as List).first as Map)['id'] as String,
        {'paused': true, 'priority': 2},
      );
      // A fresh store reading the same storage: everything must come back.
      final fresh = SalapifyStore();
      await fresh.load();
      final g = (fresh.data['goals'] as List).single as Map;
      expect(g['kind'], 'savings');
      expect(g['iconKey'], 'travel');
      expect(g['accent'], 'caramel');
      expect(g['frequency'], 'weekly');
      expect(g['createdAt'], '2026-01-15');
      expect(g['startSaved'], 0.0);
      expect(g['paused'], true);
      expect(g['priority'], 2);
    });
  });
}
