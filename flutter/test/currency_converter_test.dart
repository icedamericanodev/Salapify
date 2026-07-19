// The currency converter flow: open from Tools, and with rates cached (so no
// network is needed) type an amount and see the converted value and the rate
// line. A fresh cache is seeded under the fx key so the test is deterministic
// and offline; the pure conversion is already golden-locked in fx_golden_test.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/fx_service.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('converts PHP to USD from cached rates', (tester) async {
    SharedPreferences.setMockInitialValues({
      // A fresh cache (fetchedAt = now) so FxService.load returns it without
      // any network call.
      FxService.cacheKey: jsonEncode({
        'base': 'PHP',
        'rates': {'PHP': 1, 'USD': 0.0176, 'JPY': 2.62},
        'fetchedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    });
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Tools'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Currency converter'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Currency converter'));
    await tester.pumpAndSettle();

    // Default is base (PHP) to USD. Type 1,000 PHP.
    await tester.enterText(find.byType(TextField), '1000');
    await tester.pumpAndSettle();

    // 1000 x 0.0176 = 17.60, and the rate line shows the cross rate.
    expect(find.text('\$17.60'), findsOneWidget);
    expect(find.textContaining('1 PHP = 0.0176 USD'), findsOneWidget);
  });
}
