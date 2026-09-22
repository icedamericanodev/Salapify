// The reference footer's compliance contract.
//
// Collapsing citations into one line is only acceptable while every
// statement stays reachable and the boundary sentence stays VISIBLE without
// a tap. These tests are the guard on that promise, because the failure mode
// is silent: a lesson that reads beautifully and quietly hides its
// disclaimer looks exactly like a lesson that reads beautifully.
//
// Proven to fail before being trusted; the failure lines are in the commit
// message.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/lesson_block_views.dart';
import 'package:salapify/widgets/expansion_lesson_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens_shot.dart' show loadRealFonts;

const _blocks = <LessonBlock>[
  EducationalBoundaryBlock(
    sourceLabel: 'the Securities and Exchange Commission',
    examplesAreFictional: true,
  ),
  OfficialSourceBlock(
    agency: 'Philippine Stock Exchange (PSE Academy)',
    sourceTitle: 'PSE Academy, Market Education for Investors',
    canonicalUrl: 'https://www.pseacademy.com.ph/',
    lastVerifiedDate: '2026-08',
  ),
  OfficialSourceBlock(
    agency: 'Securities and Exchange Commission Philippines',
    sourceTitle: 'Investment 101',
    canonicalUrl: 'https://appointment.sec.gov.ph/',
    lastVerifiedDate: '2026-08',
  ),
];

Future<void> _pump(WidgetTester tester, List<LessonBlock> blocks) async {
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: Scaffold(
        body: SingleChildScrollView(child: LessonReferenceFooter(blocks)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('collapsed, the footer still discloses', () {
    testWidgets('the boundary sentence is visible without any tap', (
      tester,
    ) async {
      await _pump(tester, _blocks);
      expect(
        find.textContaining('Educational, not advice'),
        findsOneWidget,
        reason: 'a disclaimer behind a tap is not a disclaimer',
      );
      expect(find.textContaining('can change'), findsOneWidget);
    });

    testWidgets('every cited agency is named without any tap', (tester) async {
      await _pump(tester, _blocks);
      expect(
        find.textContaining('Philippine Stock Exchange (PSE Academy)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Securities and Exchange Commission Philippines'),
        findsOneWidget,
      );
    });

    testWidgets('the same agency cited twice is named once', (tester) async {
      await _pump(tester, const [
        OfficialSourceBlock(
          agency: 'Bangko Sentral ng Pilipinas',
          sourceTitle: 'Circular A',
          canonicalUrl: 'https://example.test/a',
        ),
        OfficialSourceBlock(
          agency: 'Bangko Sentral ng Pilipinas',
          sourceTitle: 'Circular B',
          canonicalUrl: 'https://example.test/b',
        ),
      ]);
      final line = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((s) => s.contains('Sources:'), orElse: () => '');
      expect(
        'Bangko Sentral'.allMatches(line).length,
        1,
        reason: 'naming one regulator twice in one line reads as a stutter',
      );
    });
  });

  group('expanded, nothing is lost', () {
    testWidgets('every URL and the full notice come back', (tester) async {
      await _pump(tester, _blocks);
      await tester.tap(find.text('Sources and full notice'));
      await tester.pumpAndSettle();

      expect(find.text('https://www.pseacademy.com.ph/'), findsOneWidget);
      expect(find.text('https://appointment.sec.gov.ph/'), findsOneWidget);
      expect(
        find.textContaining('not personalized financial'),
        findsOneWidget,
        reason: 'the full boundary text must still be reachable',
      );
      expect(
        find.textContaining('invented for teaching'),
        findsOneWidget,
        reason: 'the fictional-examples sentence must still be reachable',
      );
    });

    testWidgets('it closes again', (tester) async {
      await _pump(tester, _blocks);
      await tester.tap(find.text('Sources and full notice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide sources'));
      await tester.pumpAndSettle();
      expect(find.text('https://www.pseacademy.com.ph/'), findsNothing);
    });
  });

  testWidgets('an empty list renders nothing at all', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(TextButton), findsNothing);
  });

  group('inside a real lesson', () {
    testWidgets('citations leave the teaching flow but stay on the page', (
      tester,
    ) async {
      // The end-to-end version of the promise, against real shipped content
      // rather than the fixture above.
      SharedPreferences.setMockInitialValues({});
      final store = SalapifyStore();
      await store.load();
      final lesson = growYourMoneyLessons.firstWhere(
        (l) => l.id == investRefMoneyJob,
      );
      await loadRealFonts(tester);
      tester.view.physicalSize = const Size(390, 6000) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      Barako.current = Barako.currentTheme.resolve(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: ExpansionLessonReader(
            pathId: 'grow_your_money',
            lesson: lesson,
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The big grey citation card is no longer sitting in the lesson body.
      expect(
        find.text('OFFICIAL SOURCE'),
        findsNothing,
        reason: 'citations should no longer interrupt the teaching',
      );
      // But the lesson still discloses, in one line, without a tap.
      expect(find.textContaining('Educational, not advice'), findsOneWidget);
      expect(find.textContaining('PSE Academy'), findsWidgets);
      // And the risk warning STAYED inline, because a warning teaches.
      expect(find.text('Investing can lose value'), findsOneWidget);
    });
  });
}
