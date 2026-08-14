// Renders the Money Mindset flow (Step 1, Context) so it can be looked at.
// Not *_test.dart, so `flutter test` never collects it.
//   flutter test test/mindset_flow_shot.dart --update-goldens
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/mindset_flow.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show livedInBlob, loadPanFaces, loadRealFonts;

void main() {
  testWidgets('Money Mindset flow, Step 1 Context, dark', (tester) async {
    await loadRealFonts(tester);
    await loadPanFaces(tester);
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode(livedInBlob),
    });
    final store = SalapifyStore();
    await store.load();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    Barako.current = Barako.currentTheme.resolve(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(Barako.current),
        debugShowCheckedModeBanner: false,
        home: MindsetFlowScreen(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // Fill it in so the amount field and enabled Continue show.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'New headphones');
    await tester.enterText(fields.at(1), '14990');
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/mindset-flow-step1-dark.png'),
    );
  });
}
