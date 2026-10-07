// One-shot render of the new panda Pan, for founder review. NOT a test (no
// _test suffix), so `flutter test` never collects it. Run from flutter/:
//   flutter test test/pan_panda_preview.dart --update-goldens
// Outputs under test/shots/ (gitignored):
//   panda-accounts-dark.png / panda-accounts-light.png  (the real Accounts
//     screen: Pan on the hero and on the Pan insight card)
//   panda-emotions-dark.png / panda-emotions-light.png  (all six feelings
//     through the actual PanMascot widget, on the card surface)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';

import 'screens_shot.dart' show loadRealFonts, loadPanFaces, livedInBlob;

Future<void> _accounts(WidgetTester tester, Brightness b, String out) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(livedInBlob)});
  final store = SalapifyStore();
  await store.load();

  tester.view.physicalSize = const Size(1170, 5200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  Barako.current = Barako.currentTheme.resolve(b);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      debugShowCheckedModeBanner: false,
      home: AccountsScreen(store: store),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(out));
}

Future<void> _emotions(WidgetTester tester, Brightness b, String out) async {
  Barako.current = Barako.currentTheme.resolve(b);
  Widget cell(PanEmotion e, String label) => Container(
    width: 250,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanMascot.emotion(emotion: e, size: 150),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: Barako.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Barako.background,
        body: Center(
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              cell(PanEmotion.content, 'content'),
              cell(PanEmotion.worried, 'worried'),
              cell(PanEmotion.sad, 'sad'),
              cell(PanEmotion.angry, 'angry'),
              cell(PanEmotion.tired, 'tired'),
              cell(PanEmotion.celebrate, 'celebrate'),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await expectLater(find.byType(MaterialApp), matchesGoldenFile(out));
}

void main() {
  testWidgets('panda Pan preview', (tester) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);

    await _emotions(tester, Brightness.dark, 'shots/panda-emotions-dark.png');
    await _emotions(tester, Brightness.light, 'shots/panda-emotions-light.png');
    await _accounts(tester, Brightness.dark, 'shots/panda-accounts-dark.png');
    await _accounts(tester, Brightness.light, 'shots/panda-accounts-light.png');
  });
}
