// The display currency: one resolved symbol every formatter reads, defaulting
// to the peso so existing users and every other test see zero change. Nothing
// is ever converted; the sign is a display preference and the numbers are
// sacred.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/money/currencies.dart';
import 'package:salapify/money/debtmath.dart' show formatMoneyText;
import 'package:salapify/screens/menu.dart' show MenuScreen;
import 'package:salapify/screens/overview.dart' show formatMoney;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

void main() {
  // The symbol is a module-level resolve, the Barako.current pattern, so
  // every test here puts the world back the way it found it.
  tearDown(() => resolveBaseCurrency(null));

  group('resolveBaseCurrency', () {
    test(
      'defaults to the peso, bit-identical to before the setting existed',
      () {
        resolveBaseCurrency(null);
        expect(formatMoney(1234.5), '₱1,234.50');
        expect(formatMoneyText(-1234), '-₱1,234');
      },
    );

    test('the symbol key wins, the RN precedence', () {
      resolveBaseCurrency({'currency': r'$', 'currencyCode': 'USD'});
      expect(formatMoney(1234.5), r'$1,234.50');
    });

    test('a code alone resolves through the list', () {
      resolveBaseCurrency({'currencyCode': 'SGD'});
      expect(formatMoney(10), r'S$10');
    });

    test('junk falls back to the peso, never blank', () {
      resolveBaseCurrency({'currency': '', 'currencyCode': 42});
      expect(formatMoney(10), '₱10');
    });
  });

  testWidgets('picking a currency in Menu reflows the amounts on Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
        ],
        'transactions': [
          {
            'id': 't1',
            'type': 'expense',
            'label': 'Groceries',
            'amount': 250,
            'date': '2026-07-20',
            'accountId': 'cash',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await openMenu(tester);
    // Currency lives directly in the SETTINGS card now (menu.dart), reached
    // by a single _navRow, no section to expand first.
    final row = find.text('Currency');
    await scrollTo(tester, row, scope: find.byType(MenuScreen));
    await tester.tap(row);
    await tester.pumpAndSettle();
    // The sheet says out loud that nothing converts.
    expect(find.textContaining('Nothing is converted'), findsOneWidget);
    await tester.tap(find.text(r'USD  $'));
    await tester.pumpAndSettle();

    // The stored keys are the RN keys, so backups round-trip.
    final settings = store.data['settings'] as Map;
    expect(settings['currencyCode'], 'USD');
    expect(settings['currency'], r'$');

    // Back on Home, the balance wears the new sign.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.text(r'$5,000'),
      findsWidgets,
      reason:
          'A currency change must reflow every amount at once, the same '
          'resolve-before-build contract the palette uses.',
    );
    expect(find.text('₱5,000'), findsNothing);
  });

  testWidgets('a stored currency survives a reload', (tester) async {
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        'schemaVersion': 12,
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 5000},
        ],
        'settings': {'currency': r'S$', 'currencyCode': 'SGD'},
      }),
    });
    final store = SalapifyStore();
    await store.load();
    resolveBaseCurrency(store.data['settings']);
    expect(
      formatMoney(5000),
      r'S$5,000',
      reason:
          'The sanitizer must carry the RN currency keys through a '
          'reload; losing them silently reverts a chosen sign.',
    );
  });
}
