// Smoke test: the app boots, shows the brand, the empty-state import path,
// and the update stamp. The stamp matters because it is how the founder
// verifies which build arrived, so a build where it vanished must fail CI.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('overview shows the brand, import path, and the update stamp',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('SALAPIFY'), findsOneWidget);
    expect(find.text('NET WORTH'), findsOneWidget);
    // The stamp card sits at the bottom of the list, so scroll it into build.
    await tester.scrollUntilVisible(find.text('Update stamp'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Update stamp'), findsOneWidget);
    expect(find.textContaining('f0.'), findsOneWidget);
    expect(find.text('Import backup'), findsOneWidget);
  });
}
