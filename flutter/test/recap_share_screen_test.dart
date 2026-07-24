// The Share your month flow: open from Menu, the branded recap card renders
// from the golden-locked monthRecap engine, and the hide-amounts toggle swaps
// peso figures for ***. The actual share sheet is a platform channel, so the
// test stops at the buttons being present.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _thisMonth(int day) {
  final now = DateTime.now();
  final m = now.month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  return '${now.year}-$m-$d';
}

Future<void> _openRecap(WidgetTester tester) async {
  await tester.tap(find.text('Menu'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Share your month'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text('Share your month'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Share your month'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recap card renders and the hide-amounts toggle swaps to ***', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'transactions': [
          {
            'id': 'i1',
            'date': _thisMonth(15),
            'type': 'income',
            'label': 'Sweldo',
            'amount': 20000,
          },
          {
            'id': 'e1',
            'date': _thisMonth(5),
            'type': 'expense',
            'label': 'Groceries',
            'amount': 5000,
          },
        ],
      }),
    });
    // A tall viewport so the card, the toggle, and both buttons all lay out
    // (a ListView culls off-screen children, which would hide them from finds).
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openRecap(tester);

    // The card and its footer wordmark render (twice: the visible preview and
    // the off-screen fixed-size capture source), and both share buttons exist.
    expect(find.text("Salapify, on your money's side"), findsWidgets);
    expect(find.text('Share the card'), findsOneWidget);
    expect(find.text('Share as text'), findsOneWidget);
    // A kept month puts a happy Pan on the card. (The off-screen capture copy
    // does not surface a second semantics node, so presence is the pin.)
    expect(find.bySemanticsLabel('Pan looking happy'), findsWidgets);
    // Amounts are shown, not hidden.
    expect(find.textContaining('***'), findsNothing);

    // Flip the privacy toggle: the money rows become ***.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('***'), findsWidgets);
  });

  testWidgets('an over month puts a worried, sympathetic Pan on the card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'transactions': [
          {
            'id': 'i1',
            'date': _thisMonth(15),
            'type': 'income',
            'label': 'Sweldo',
            'amount': 5000,
          },
          {
            'id': 'e1',
            'date': _thisMonth(5),
            'type': 'expense',
            'label': 'Rent',
            'amount': 9000,
          },
        ],
      }),
    });
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openRecap(tester);

    expect(find.bySemanticsLabel('Pan looking worried'), findsWidgets);
    // The honest over line still reads sympathetic, not shameful.
    expect(find.textContaining('over'), findsWidgets);
  });

  testWidgets('a no-verdict month (expenses only) shows a calm Pan', (
    tester,
  ) async {
    // No income means no keptRate, so the card celebrates the habit instead
    // and Pan rests calm, completing the three-mood pin.
    SharedPreferences.setMockInitialValues({
      'salapify_data_v2': jsonEncode({
        'transactions': [
          {
            'id': 'e1',
            'date': _thisMonth(5),
            'type': 'expense',
            'label': 'Food',
            'amount': 400,
          },
          {
            'id': 'e2',
            'date': _thisMonth(6),
            'type': 'expense',
            'label': 'Fare',
            'amount': 60,
          },
        ],
      }),
    });
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();
    await _openRecap(tester);

    expect(find.bySemanticsLabel('Pan looking calm'), findsWidgets);
    expect(find.textContaining('days logged'), findsWidgets);
  });
}
