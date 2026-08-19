// Tall one-shot render of the whole Accounts screen for the redesign review.
// NOT a test (no _test suffix), so `flutter test` never collects it. Run from
// flutter/:
//   flutter test test/accounts_preview.dart --update-goldens
// Output: test/shots/accounts-full-dark.png (gitignored), for LOOKING at the
// full screen top to bottom, including the Pan insight card below the fold.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/theme.dart';

import 'screens_shot.dart' show loadRealFonts, livedInBlob;

void main() {
  testWidgets('accounts full preview', (tester) async {
    await loadRealFonts(tester);
    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode(livedInBlob),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 5200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    Barako.current = Barako.currentTheme.resolve(Brightness.dark);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: AccountsScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    final ctx = tester.element(find.byType(AccountsScreen));
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/pan/emotions/pan-content.png'),
        ctx,
      );
      await precacheImage(
        const AssetImage('assets/pan/emotions/pan-worried.png'),
        ctx,
      );
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/accounts-full-dark.png'),
    );

    // Switch to the Liabilities tab to review the owed (red) subtotal cue and
    // the manage-debts note.
    await tester.scrollUntilVisible(
      find.text('ACCOUNTS BY CATEGORY'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Liabilities'));
    await tester.tap(find.text('Liabilities'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/accounts-liabilities-dark.png'),
    );
  });
}
