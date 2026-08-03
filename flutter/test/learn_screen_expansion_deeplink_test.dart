// Deep-link coverage for the Money Courses Phase 6 pilot: LearnScreen's
// existing focusId mechanism (screens/learn.dart, documented as a "thin,
// single-caller mechanism" in docs/money_courses_expansion_audit.md) now
// also resolves an expansion-path lesson id, falling back safely (no
// crash, the core screen renders normally) when the id matches neither the
// core 22 nor a published expansion path.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/learn.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _freshStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  testWidgets('a valid expansion lesson id opens the expansion reader', (
    tester,
  ) async {
    final store = await _freshStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LearnScreen(store: store, focusId: investRefMoneyJob),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionLessonReader), findsOneWidget);
    expect(find.text('Give Your Money a Job'), findsOneWidget);
  });

  testWidgets('an unknown focusId is a safe no-op, the catalog just renders', (
    tester,
  ) async {
    final store = await _freshStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LearnScreen(store: store, focusId: 'not-a-real-lesson-id'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionLessonReader), findsNothing);
    expect(find.text('Money courses'), findsOneWidget);
  });

  testWidgets('a core lesson id still opens the core reader as before', (
    tester,
  ) async {
    final store = await _freshStore();
    await tester.pumpWidget(
      MaterialApp(
        home: LearnScreen(store: store, focusId: 'see-it-first'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionLessonReader), findsNothing);
    expect(find.text('See it before you fix it'), findsOneWidget);
  });
}
