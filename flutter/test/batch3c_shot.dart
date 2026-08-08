// One-off renders for Phase 3 batch 3c (the lighter Home tail), dark first,
// built ON TOP of the lived-in fixture so every frame carries real money.
// Not *_test.dart on purpose, same as screens_shot.dart: pictures to look at,
// never a CI gate. Run deliberately, from flutter/:
//   flutter test test/batch3c_shot.dart --update-goldens

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts, loadPanFaces, livedInBlob;

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The lived-in phone plus a mid-journey treat (2 of 5), so the slim treat
/// line renders with real progress instead of the empty invite.
Map<String, dynamic> _blobWithTreat() {
  final b = jsonDecode(jsonEncode(livedInBlob)) as Map<String, dynamic>;
  final today = DateTime.now();
  (b['settings'] as Map)['treats'] = [
    {
      'id': 'treat-milktea',
      'treat': 'Milk tea',
      'action': 'walk',
      'emoji': '',
      'target': 5,
      'windowDays': 7,
      'checkIns': [
        _iso(today.subtract(const Duration(days: 1))),
        _iso(today.subtract(const Duration(days: 3))),
      ],
    },
  ];
  return b;
}

/// The same phone on payday morning with the salary already logged, so the
/// payday card renders its one-row receipt above a fresh number.
Map<String, dynamic> _blobOnPaydayLogged() {
  final b = _blobWithTreat();
  final today = DateTime.now();
  (b['settings'] as Map)['paydaySchedule'] = {
    'mode': 'monthly',
    'day': today.day,
  };
  ((b['transactions'] as List)).add({
    'id': 'shot-sweldo',
    'type': 'income',
    'label': 'Sweldo',
    'amount': 38000,
    'date': _iso(today),
    'accountId': 'pay',
  });
  return b;
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  Map<String, dynamic> blob, {
  double scrollBy = 0,
}) async {
  await loadRealFonts(tester);
  await loadPanFaces(tester);
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
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
      home: Scaffold(
        body: OverviewScreen(store: store, onSwitchTab: (_) {}, onMenu: () {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (scrollBy != 0) {
    await tester.drag(find.byType(ListView).first, Offset(0, -scrollBy));
    await tester.pumpAndSettle();
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('shots/$name-dark.png'),
  );
}

void main() {
  testWidgets('payday receipt row above the fresh number', (tester) async {
    await _shoot(tester, 'batch3c-home-receipt', _blobOnPaydayLogged());
  });

  testWidgets('the tail: slim treat line, dense chain, accounts preview', (
    tester,
  ) async {
    await _shoot(tester, 'batch3c-home-tail', _blobWithTreat(), scrollBy: 1450);
  });
}
