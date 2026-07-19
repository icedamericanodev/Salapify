// The Learn flow: open from Tools, read a lesson, and see it marked done with
// the progress count going up. The lesson content is locked separately in
// lessons_golden_test; this covers the screen and the read-tracking write.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('reading a lesson marks it done and bumps the progress',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = SalapifyStore();
    await tester.pumpWidget(SalapifyApp(store: store));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Tools'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Money lessons'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Money lessons'));
    await tester.pumpAndSettle();

    expect(find.text('YOUR PROGRESS'), findsOneWidget);
    expect(find.text('0 of ${lessons.length} lessons read'), findsOneWidget);

    // The featured card sits above the full list, so its title's first match
    // is the featured card. Computing it here keeps the tap deterministic.
    final featured = lessonOfTheDay(DateTime.now());
    await tester.tap(find.text(featured['title'] as String).first);
    await tester.pumpAndSettle();

    // A body paragraph appears only in the reader, so this confirms it opened.
    final firstPara = (featured['body'] as List).first as String;
    expect(find.textContaining(firstPara.substring(0, 40)), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 of ${lessons.length} lessons read'), findsOneWidget);
  });
}
