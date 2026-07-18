// Notes end to end: create from the Overview tools row, type a receipt,
// watch the CALCULATIONS panel compute live, persist on close, discard
// empty notes quietly, and delete behind a confirm.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('a receipt note computes live and persists on close',
      (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);

    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField),
        'Pasalubong\nlunch 120\njeep 24 + 24\n7-11 run 250');
    await tester.pumpAndSettle();

    // The live panel: three computed rows and the total.
    expect(find.text('CALCULATIONS'), findsOneWidget);
    expect(find.text('₱48'), findsOneWidget); // jeep 24 + 24
    expect(find.text('₱418'), findsOneWidget); // 120 + 48 + 250

    // Close: the debounce is flushed and the list shows the note.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Pasalubong'), findsOneWidget);
    expect(find.text('₱418'), findsOneWidget);

    // Persisted for a fresh store.
    final fresh = SalapifyStore();
    await fresh.load();
    final notes = (fresh.data['notes'] as List).cast<Map<String, dynamic>>();
    expect(notes.length, 1);
    expect(notes.single['text'],
        'Pasalubong\nlunch 120\njeep 24 + 24\n7-11 run 250');
  });

  testWidgets('an empty note is discarded quietly on close', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('No notes yet'), findsOneWidget);
    expect((store.data['notes'] as List), isEmpty);
  });

  testWidgets('deleting a note asks first', (tester) async {
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'keep me?');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete this note?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);
    expect((store.data['notes'] as List), isEmpty);
  });
}
