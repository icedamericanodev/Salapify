// The first-run onboarding: the gate that decides who sees it, the flow
// that writes the one settings patch, the sample seed that leaves in one
// tap, and the first-log prompt that fires exactly once.
//
// The most important test in this file is the one asserting an EXISTING
// blob with no onboarded flag never sees onboarding. That is the founder's
// phone upgrading into the first build that has this flow, and it is the
// RN derivation ported on purpose: a successfully loaded blob counts as
// onboarded unless the flag is literally false.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/backup.dart' show sanitizeData;
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/chain.dart';
import 'package:salapify/money/sample_data.dart';
import 'package:salapify/screens/log_sheet.dart' show LogSheet;
import 'package:salapify/screens/onboarding.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _boot(WidgetTester tester) async {
  final store = SalapifyStore();
  await tester.pumpWidget(SalapifyApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

Map _settings(SalapifyStore store) =>
    (store.data['settings'] as Map?) ?? const {};

void main() {
  group('the gate', () {
    testWidgets('a fresh install shows onboarding', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await _boot(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
    });

    testWidgets('an existing blob WITHOUT the flag never sees onboarding', (
      tester,
    ) async {
      // The founder's phone: real data saved by a build that predates the
      // flag. Loading it must land on the shell like every day before.
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'accounts': [
            {'id': 'a1', 'name': 'Wallet', 'icon': 'W', 'balance': 500},
          ],
        }),
      });
      await _boot(tester);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.text('SALAPIFY'), findsOneWidget);
    });

    testWidgets('an explicit onboarded false shows onboarding', (tester) async {
      // A fresh user who quit mid-welcome on another phone and restored.
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'settings': {'onboarded': false},
        }),
      });
      await _boot(tester);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('a failed read never shows onboarding', (tester) async {
      // Broken JSON: loadError set, writes shut. Greeting this user with a
      // welcome flow whose finish WRITES would overwrite what we failed to
      // read, so the gate must stand down and let Home show the error card.
      SharedPreferences.setMockInitialValues({storageKey: '{broken'});
      final store = await _boot(tester);
      expect(store.loadError, isNotNull);
      expect(find.byType(OnboardingScreen), findsNothing);
    });
  });

  group('the flow', () {
    testWidgets('the clean-slate walk writes the RN settings patch exactly', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final store = await _boot(tester);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('STEP 1 OF 2'), findsOneWidget);

      await tester.tap(find.text(r'$ USD'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '25,000');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('How do you want to start?'), findsOneWidget);

      await tester.tap(find.text('Start with a clean slate'));
      await tester.pumpAndSettle();

      final s = _settings(store);
      expect(s['currency'], r'$');
      expect(s['currencyCode'], 'USD');
      expect(s['monthlyLimit'], 25000);
      expect(s['onboarded'], true);
      // Nothing was seeded on the clean path.
      expect(store.data['accounts'], isEmpty);
      expect(store.data['transactions'], isEmpty);

      // The shell opened the log sheet once, unasked, and burned the flag
      // doing it, so it can never nag on the next open.
      expect(find.byType(LogSheet), findsOneWidget);
      expect(s['firstLogPrompt'], false);
    });

    testWidgets('a typed 0 budget is honored and junk falls back', (
      tester,
    ) async {
      // 0 is a real answer ("do not budget me"), the RN parse rule. Junk is
      // not, and falls back to the default instead of storing NaN.
      SharedPreferences.setMockInitialValues({});
      final store = await _boot(tester);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start with a clean slate'));
      await tester.pumpAndSettle();
      expect(_settings(store)['monthlyLimit'], 0);
    });

    testWidgets('junk budget input falls back to the default', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await _boot(tester);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start with a clean slate'));
      await tester.pumpAndSettle();
      expect(_settings(store)['monthlyLimit'], 20000);
    });

    testWidgets('existing data means one honest button and no seed offer', (
      tester,
    ) async {
      // onboarded false restored ONTO data: never offer the sample, never
      // offer a wipe.
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'settings': {'onboarded': false},
          'accounts': [
            {'id': 'a1', 'name': 'Wallet', 'icon': 'W', 'balance': 500},
          ],
        }),
      });
      final store = await _boot(tester);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('You are all set.'), findsOneWidget);
      expect(find.text('Explore the sample data first'), findsNothing);
      expect(find.text('Start with a clean slate'), findsNothing);
      await tester.tap(find.text('Start tracking'));
      await tester.pumpAndSettle();
      expect(_settings(store)['onboarded'], true);
    });
  });

  group('the sample data', () {
    testWidgets('the sample walk seeds, marks, and removes in one tap', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final store = await _boot(tester);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore the sample data first'));
      await tester.pumpAndSettle();

      expect(hasSampleData(store.data), isTrue);
      expect((store.data['accounts'] as List).length, 3);
      expect((store.data['transactions'] as List).length, 5);

      // The log sheet opened over Home; close it to reach the banner.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // The onboarding promise: clearly marked, gone in one tap.
      expect(find.text('SAMPLE DATA'), findsOneWidget);
      await tester.tap(find.text('Remove sample data'));
      await tester.pumpAndSettle();
      expect(hasSampleData(store.data), isFalse);
      expect(store.data['accounts'], isEmpty);
      expect(store.data['transactions'], isEmpty);
      expect(store.data['receivables'], isEmpty);
      expect(store.data['people'], isEmpty);
      expect(find.text('SAMPLE DATA'), findsNothing);
    });

    test('removeSampleData removes exactly the sample rows', () async {
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'settings': {'onboarded': true},
          'accounts': [
            {'id': 'mine', 'name': 'Real wallet', 'icon': 'W', 'balance': 100},
            ...sampleData(DateTime(2026, 7, 15))['accounts'] as List,
          ],
          'transactions': [
            {
              'id': 'tx_mine',
              'type': 'expense',
              'label': 'Coffee',
              'amount': 90,
              'date': '2026-07-15',
            },
            ...sampleData(DateTime(2026, 7, 15))['transactions'] as List,
          ],
        }),
      });
      final store = SalapifyStore();
      await store.load();
      await store.removeSampleData();
      final accounts = (store.data['accounts'] as List)
          .map((a) => (a as Map)['id'])
          .toList();
      final txs = (store.data['transactions'] as List)
          .map((t) => (t as Map)['id'])
          .toList();
      expect(accounts, ['mine']);
      expect(txs, ['tx_mine']);
    });

    test('sample transactions never feed the chain', () {
      // The RN three-place rule: a chain lit by demo data would be a lie the
      // user did not tell. Sample rows dated today must count for nothing.
      final ref = DateTime(2026, 7, 15);
      final seeded = sampleData(ref)['transactions'] as List;
      final state = chainState(seeded, ref);
      expect(state.count, 0, reason: 'sample rows must not light the chain');
      // And a real row beside them still counts normally.
      final withReal = [
        ...seeded,
        {
          'id': 'tx_real',
          'type': 'expense',
          'label': 'Coffee',
          'amount': 90,
          'date': '2026-07-15',
        },
      ];
      expect(chainState(withReal, ref).count, 1);
    });

    test('every seeded row id carries the sample_ prefix', () {
      // This is what makes exact one-tap removal possible at all, the
      // deliberate improvement over the RN seed.
      final seed = sampleData(DateTime(2026, 7, 15));
      for (final entry in seed.entries) {
        for (final row in entry.value as List) {
          expect(
            isSampleId((row as Map)['id']),
            isTrue,
            reason: '${entry.key} row ${row['id']} must be sample_ prefixed',
          );
        }
      }
      // Payables are deliberately never seeded: no fake debt the user owes.
      expect(seed.containsKey('payables'), isFalse);
    });
  });

  group('backup safety', () {
    test('sanitizeData passes the onboarding flags through untouched', () {
      // A backup written by this build must restore with its onboarding
      // state intact on the next phone; the sanitizer keeps unknown settings
      // keys by spread, and this pins that contract for these two.
      final out = sanitizeData({
        'settings': {'onboarded': true, 'firstLogPrompt': false},
      });
      final s = out['settings'] as Map;
      expect(s['onboarded'], true);
      expect(s['firstLogPrompt'], false);
    });

    test('sanitizeData does NOT invent onboarding flags', () {
      // The golden backup tests compare exported key sets against real RN
      // fixtures, so emitting a new key unconditionally would break
      // round-tripping. Absent stays absent.
      final s = sanitizeData({})['settings'] as Map;
      expect(s.containsKey('onboarded'), isFalse);
      expect(s.containsKey('firstLogPrompt'), isFalse);
    });
  });
}
