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
import 'package:salapify/money/quickadd.dart';
import 'package:salapify/money/coach.dart' as coach;
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

  group('the QA round', () {
    test('the first log sheet never preselects a sample account', () {
      // QA MUST FIX: with only the seed present, lastUsedAccountId derived
      // "BPI Savings" from the sample transactions, so the auto-opened first
      // log sheet funneled a new user's real entries into an account that
      // Remove sample data then deletes from under them.
      final seed = sampleData(DateTime(2026, 7, 15));
      final valid = {'sample_cash', 'sample_bpi', 'sample_gcash'};
      expect(lastUsedAccountId(seed['transactions'], valid), isNull);
      // And even a REAL transaction pointed at a sample account must not
      // invite the next one there.
      final real = [
        ...seed['transactions'] as List,
        {
          'id': 'tx_real',
          'type': 'expense',
          'label': 'Coffee',
          'amount': 90,
          'date': '2026-07-16',
          'accountId': 'sample_bpi',
        },
      ];
      expect(lastUsedAccountId(real, valid), isNull);
    });

    test('quick-add chips never offer sample labels', () {
      final seed = sampleData(DateTime(2026, 7, 15));
      expect(recentLabels(seed['transactions'], 'expense'), isEmpty);
      expect(recentLabels(seed['transactions'], 'income'), isEmpty);
    });

    test('removal unlinks real entries logged into a sample account', () async {
      // The rows survive with their money; only the pointer at the account
      // that stops existing goes.
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      await store.completeOnboarding(
        currencyCode: 'PHP',
        currencySymbol: '₱',
        monthlyLimit: 20000,
        withSampleData: true,
      );
      await store.addEntry({
        'type': 'expense',
        'label': 'Real coffee',
        'amount': 90.0,
        'accountId': 'sample_bpi',
        'date': '2026-07-16',
      });
      await store.removeSampleData();
      final survivors = (store.data['transactions'] as List)
          .whereType<Map>()
          .toList();
      expect(survivors, hasLength(1));
      expect(survivors.single['label'], 'Real coffee');
      expect(
        survivors.single.containsKey('accountId'),
        isFalse,
        reason: 'the pointer at the deleted sample account must go',
      );
    });

    test('removal drops payment residue from sample fixtures', () async {
      // QA SHOULD FIX: paying the sample credit card writes a payments row
      // and debt/interest transactions with REAL ids carrying its debtId,
      // which survived removal and fed the month recap forever.
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'settings': {'onboarded': true},
          'debts': [
            ...sampleData(DateTime(2026, 7, 15))['debts'] as List,
            {
              'id': 'd_real',
              'name': 'My loan',
              'type': 'personal loan',
              'remaining': 5000,
              'monthlyRate': 1,
              'minPayment': 500,
            },
          ],
          'payments': [
            {
              'id': 'payments_1',
              'debtId': 'sample_d1',
              'amount': 1500,
              'date': '2026-07-15',
            },
            {
              'id': 'payments_2',
              'debtId': 'd_real',
              'amount': 500,
              'date': '2026-07-15',
            },
          ],
          'transactions': [
            {
              'id': 'txn_1',
              'type': 'debt',
              'label': 'Debt payment: Credit Card',
              'amount': 1400,
              'date': '2026-07-15',
              'debtId': 'sample_d1',
            },
            {
              'id': 'txn_2',
              'type': 'expense',
              'label': 'Interest: Credit Card',
              'amount': 100,
              'date': '2026-07-15',
              'debtId': 'sample_d1',
              'source': 'interest',
            },
            {
              'id': 'txn_3',
              'type': 'debt',
              'label': 'Debt payment: My loan',
              'amount': 500,
              'date': '2026-07-15',
              'debtId': 'd_real',
            },
          ],
        }),
      });
      final store = SalapifyStore();
      await store.load();
      await store.removeSampleData();
      final paymentIds = (store.data['payments'] as List)
          .map((p) => (p as Map)['id'])
          .toList();
      final txnIds = (store.data['transactions'] as List)
          .map((t) => (t as Map)['id'])
          .toList();
      expect(paymentIds, ['payments_2']);
      expect(txnIds, ['txn_3']);
    });

    test(
      'erase everything leads back to onboarding, restore never does',
      () async {
        // QA SHOULD FIX: startFresh left firstRun alone, so erase showed
        // onboarding only after a restart. And the counterweight: a backup
        // imported after an erase must land on the shell, not the welcome.
        SharedPreferences.setMockInitialValues({});
        final store = SalapifyStore();
        await store.load();
        await store.completeOnboarding(
          currencyCode: 'PHP',
          currencySymbol: '₱',
          monthlyLimit: 20000,
          withSampleData: false,
        );
        expect(store.needsOnboarding, isFalse);
        await store.startFresh();
        expect(store.needsOnboarding, isTrue, reason: 'erased means fresh');
        await store.importBackupText(
          jsonEncode({
            'app': 'Salapify',
            'kind': 'backup',
            'schemaVersion': 12,
            'exportedAt': '2026-07-15T00:00:00.000Z',
            'data': {
              'schemaVersion': 12,
              'accounts': [
                {'id': 'a1', 'name': 'Wallet', 'icon': 'W', 'balance': 500},
              ],
            },
          }),
        );
        expect(
          store.needsOnboarding,
          isFalse,
          reason: 'a restored user is never a first-run user',
        );
      },
    );

    test('the log-today nudge ignores sample rows', () {
      // The seed's clamped dates land on today early in the month; the coach
      // must still ask for the first real log while the chain does.
      final ref = DateTime(2026, 7, 5);
      final data = {
        'accounts': [
          {'id': 'a1', 'name': 'Wallet', 'balance': 500},
        ],
        'transactions': [
          {
            'id': 'sample_t3',
            'type': 'expense',
            'label': 'Groceries',
            'amount': 2300,
            'date': '2026-07-05',
          },
        ],
      };
      final kinds = coach
          .decisionCandidates(data, ref)
          .map((c) => c['kind'])
          .toList();
      expect(kinds, contains('logtoday'));
    });

    testWidgets('a stored budget of 0 survives a re-walk untouched', (
      tester,
    ) async {
      // QA NICE: the field seeded 20000 over a deliberate stored 0, so a
      // restored onboarded-false backup got its "do not budget me" answer
      // overwritten by a tap-through.
      SharedPreferences.setMockInitialValues({
        storageKey: jsonEncode({
          'schemaVersion': 12,
          'settings': {'onboarded': false, 'monthlyLimit': 0},
        }),
      });
      final store = await _boot(tester);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start with a clean slate'));
      await tester.pumpAndSettle();
      expect(_settings(store)['monthlyLimit'], 0);
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
