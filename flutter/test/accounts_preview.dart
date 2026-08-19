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
import 'package:salapify/widgets/salapify_icon.dart' show salapifyIcon;

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

    // Masked state: tap the hide-balances eye (visible at the top before any
    // group scrolls the hero away) and render, to review that every figure
    // hides at once and nothing leaks. Then unmask before expanding.
    await tester.tap(find.byIcon(salapifyIcon('reveal')));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/accounts-hidden-dark.png'),
    );
    await tester.tap(find.byIcon(salapifyIcon('hide')));
    await tester.pumpAndSettle();

    // Expand every category group to review the accordion open state: bank rows
    // with real logos, the rich credit-card treatment, and the loan rows.
    for (final label in const [
      'E-Wallets',
      'Investments',
      'Property',
      'Credit Cards',
      'Loans',
    ]) {
      final header = find.text(label);
      if (header.evaluate().isEmpty) continue;
      await tester.ensureVisible(header.first);
      await tester.tap(header.first);
      await tester.pumpAndSettle();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/accounts-expanded-dark.png'),
    );
  });
}
