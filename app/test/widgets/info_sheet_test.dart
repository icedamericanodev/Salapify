import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/features/info/info_dot.dart';
import 'package:salapify/features/info/info_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/state/financial_state.dart';

/// The explainer sheets behind every circled "i".
///
/// These exist because of founder direction on 2026-09-18: the first Reports
/// build explained itself in prose and the screens read as walls of text, so
/// the teaching moved behind the dot. That trade is only sound if the dot
/// actually opens something, which is exactly what stops being true the first
/// time somebody adds a topic and forgets the content.
void main() {
  testWidgets('every topic has content, so no dot can open an empty sheet', (
    WidgetTester tester,
  ) async {
    // InfoSheet reads infoContent[topic]! with a bang. A topic added to the
    // enum without an entry here does not degrade, it THROWS, and it throws
    // on a screen the person tapped deliberately. This test is a derived set
    // rather than a typed list on purpose: a typed list is a promise somebody
    // has to remember to keep, and iterating the enum is a rule.
    final List<InfoTopic> missing = InfoTopic.values
        .where((InfoTopic t) => !infoContent.containsKey(t))
        .toList();

    expect(
      missing,
      isEmpty,
      reason:
          'these topics would crash the app when their dot is tapped: '
          '$missing',
    );
  });

  testWidgets('every explainer says something, rather than being a stub', (
    WidgetTester tester,
  ) async {
    for (final InfoTopic topic in InfoTopic.values) {
      final InfoContent c = infoContent[topic]!;
      expect(c.title.trim(), isNotEmpty, reason: '$topic has no title');
      expect(c.subtitle.trim(), isNotEmpty, reason: '$topic has no subtitle');
      expect(
        c.points,
        isNotEmpty,
        reason: '$topic opens a sheet with nothing in it',
      );
      for (final InfoPoint p in c.points) {
        expect(p.title.trim(), isNotEmpty, reason: 'a point in $topic is bare');
        // Twenty characters is a low bar and it is meant to be: it does not
        // judge the writing, it catches a placeholder like "TODO" or "tbd"
        // shipping behind a dot.
        expect(
          p.body.trim().length,
          greaterThan(20),
          reason: 'a point in $topic explains nothing: "${p.body}"',
        );
      }
    }
  });

  testWidgets('every topic renders without throwing, at 320dp', (
    WidgetTester tester,
  ) async {
    // The narrowest phone still sold. A sheet that overflows here is a red
    // and yellow stripe across an explanation somebody opened for help.
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final InfoTopic topic in InfoTopic.values) {
      final FinancialState state = FinancialState(
        clock: DateTime.utc(2026, 9, 18),
      );
      final Palette palette = Palette.of(state.theme);

      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(palette, state.theme),
          home: Scaffold(
            body: InfoSheet(topic: topic, palette: palette),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$topic overflowed');
      expect(
        find.text(infoContent[topic]!.title),
        findsOneWidget,
        reason: '$topic rendered without its own title',
      );
    }
  });

  testWidgets('the dot on Home opens the debt explainer, not a toast', (
    WidgetTester tester,
  ) async {
    // Two dots on Home used to show a "coming soon" message, which is worse
    // than no dot: it costs a tap and teaches that the dots do nothing.
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    // Home is a lazy list, so the debt card is not BUILT until it is scrolled
    // near. Searching the widget tree for the dot first finds nothing at all,
    // which reads like the dot was removed rather than not yet reached.
    await tester.scrollUntilVisible(
      find.text('Debts (Both ways)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final Finder dot = find.byWidgetPredicate(
      (Widget w) =>
          w is InfoDot && w.semanticLabel == 'What Debts both ways means',
    );
    await tester.tap(dot);
    await tester.pumpAndSettle();

    expect(find.byType(InfoSheet), findsOneWidget);
    expect(find.text('Debt, both ways'), findsOneWidget);
    expect(
      find.textContaining('Most apps ignore this half'),
      findsOneWidget,
      reason: 'the debt dot opened a sheet with the wrong content',
    );
  });
}
