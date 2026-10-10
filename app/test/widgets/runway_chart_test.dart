import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/daily_projection.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/home/runway_chart.dart';

/// The runway chart, and mostly the shapes that break a naive chart.
///
/// A line chart has three classic ways to die and all three are reachable
/// here: no points at all, one point, and every point identical (which puts a
/// zero in the denominator of any min-to-max normaliser). A brand new install
/// produces the first, and an empty wallet with nothing dated produces the
/// third, so neither is theoretical.
/// Scoped to the chart on purpose. A bare `find.byType(CustomPaint)` matches
/// Material's own internals, which paint with it on any screen, so it finds
/// several widgets even when this chart has drawn nothing. It is therefore
/// wrong for "nothing drawn" and wrong for "one thing drawn", which is how
/// five of these tests failed on their first run.
Finder _chartPaint() => find.descendant(
  of: find.byType(RunwayChart),
  matching: find.byType(CustomPaint),
);

void main() {
  ProjectedDay day(int dayOfMonth, double balance) => ProjectedDay(
    date: DateTime.utc(2026, 9, dayOfMonth),
    moneyIn: Money.zero,
    moneyOut: Money.zero,
    balanceAfter: Money.fromDouble(balance),
    events: const <ProjectedEvent>[],
  );

  DailyProjection projectionOf(List<ProjectedDay> days, {double opening = 0}) =>
      DailyProjection(
        openingBalance: Money.fromDouble(opening),
        days: days,
        undatedOutflow: Money.zero,
        undatedOutflowCount: 0,
      );

  Future<void> pump(WidgetTester tester, DailyProjection p) async {
    final Palette palette = Palette.of(ThemeMode2.gabi);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: palette.background,
          body: SizedBox(
            width: 300,
            child: RunwayChart(
              palette: palette,
              projection: p,
              semanticsLabel: runwayChartSemantics(p),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty projection draws nothing rather than throwing', (
    WidgetTester tester,
  ) async {
    await pump(tester, projectionOf(const <ProjectedDay>[]));
    expect(tester.takeException(), isNull);
    expect(_chartPaint(), findsNothing);
  });

  testWidgets('a single day draws nothing, because one point is not a line', (
    WidgetTester tester,
  ) async {
    await pump(tester, projectionOf(<ProjectedDay>[day(18, 5000)]));
    expect(tester.takeException(), isNull);
    expect(_chartPaint(), findsNothing);
  });

  testWidgets('a flat line at exactly zero does not divide by zero', (
    WidgetTester tester,
  ) async {
    // The case that kills a min-to-max normaliser: hi == lo == 0, so the span
    // is zero and every y is NaN. An empty wallet with nothing dated is
    // exactly this, and it is a real first-week state.
    await pump(
      tester,
      projectionOf(<ProjectedDay>[day(18, 0), day(19, 0), day(20, 0)]),
    );
    expect(tester.takeException(), isNull);
    expect(_chartPaint(), findsOneWidget);
  });

  testWidgets('a flat line well above zero still renders', (
    WidgetTester tester,
  ) async {
    // hi == lo but both are 20,000. The span is still zero; only including
    // zero in the range saves this one, which is worth a test of its own
    // because it is saved by a DIFFERENT line of the code than the case above.
    await pump(
      tester,
      projectionOf(<ProjectedDay>[
        day(18, 20000),
        day(19, 20000),
        day(20, 20000),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(_chartPaint(), findsOneWidget);
  });

  testWidgets('an all-negative line renders', (WidgetTester tester) async {
    await pump(
      tester,
      projectionOf(<ProjectedDay>[
        day(18, -500),
        day(19, -2000),
        day(20, -3500),
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(_chartPaint(), findsOneWidget);
  });

  testWidgets('a screen reader hears the shortfall, not a blank painting', (
    WidgetTester tester,
  ) async {
    final DailyProjection p = projectionOf(<ProjectedDay>[
      day(18, 12000),
      day(19, 8000),
      day(20, -2500),
      day(21, 15000),
    ], opening: 12000);

    await pump(tester, p);

    // A CustomPaint has no semantics of its own, so without the wrapper this
    // card would be a hole in the screen reader's reading of Home.
    final String label = runwayChartSemantics(p);
    expect(label, contains('below zero'));
    expect(label, contains('2,500'));
    expect(
      find.bySemanticsLabel(label),
      findsOneWidget,
      reason: 'the chart is not announcing itself',
    );
  });

  testWidgets('a comfortable month is described as a low point, not a fall', (
    WidgetTester tester,
  ) async {
    // THE DIRECTIONAL HALF. Without it, a description that said "below zero"
    // about every ledger would pass the test above perfectly.
    final DailyProjection p = projectionOf(<ProjectedDay>[
      day(18, 12000),
      day(19, 9000),
      day(20, 15000),
    ], opening: 12000);

    await pump(tester, p);

    final String label = runwayChartSemantics(p);
    expect(label, contains('lowest point'));
    expect(label, isNot(contains('below zero')));
  });

  test('the marked day is the first crossing, not the lowest point', () {
    // THIS TEST WAS WRONG ON ITS FIRST DRAFT, in the way the house rule about
    // proving a test can fail exists to catch. It was called "the description
    // names the SAME day the chart marks" and it only ever read the
    // description: the chart and the sentence each held their own copy of the
    // rule, so reversing the chart's copy left this green while the picture
    // marked a different day from the words beside it. The fix was not a
    // better assertion, it was `runwayMarkedDay`, one function both now read,
    // which makes them unable to disagree.
    //
    // What is left to check is the RULE. The discriminator is a ledger where
    // the two candidates differ: the first crossing is the 20th and the
    // lowest point is the 22nd.
    final DailyProjection p = projectionOf(<ProjectedDay>[
      day(18, 5000),
      day(19, 1000),
      day(20, -500),
      day(21, -900),
      day(22, -4000),
      day(23, 20000),
    ], opening: 5000);

    expect(p.firstShortfall?.date.day, 20);
    expect(p.tightestDay?.date.day, 22);

    // The rule itself, which the painting and the sentence both read.
    expect(
      runwayMarkedDay(p)?.date.day,
      20,
      reason:
          'marking the lowest point would point at the bottom of a hole the '
          'person has already fallen into, instead of the edge of it',
    );

    // The sentence must name the 20th, the day somebody has to act before,
    // and the 500 that goes with it. Naming the 22nd would be describing the
    // bottom of a hole the person has already fallen into.
    final String label = runwayChartSemantics(p);
    expect(label, contains('500'));
    expect(label, isNot(contains('4,000')));
  });

  testWidgets('the chart grows with the person\'s font size', (
    WidgetTester tester,
  ) async {
    // The labels used to be drawn at a hard 10px whatever the system setting,
    // because a TextPainter defaults to no scaling. The readability sweep
    // could not catch it: it looks for OVERFLOW, and a label that refuses to
    // grow cannot overflow. So this asserts the growth directly.
    final DailyProjection p = projectionOf(<ProjectedDay>[
      day(18, 12000),
      day(19, 9000),
      day(20, 15000),
    ], opening: 12000);
    final Palette palette = Palette.of(ThemeMode2.gabi);

    Future<double> heightAt(double scale) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                child: RunwayChart(
                  palette: palette,
                  projection: p,
                  semanticsLabel: runwayChartSemantics(p),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(RunwayChart)).height;
    }

    final double normal = await heightAt(1.0);
    final double large = await heightAt(1.5);

    expect(
      large,
      greaterThan(normal),
      reason:
          'the chart is the same height at 1.5x, so its labels are ignoring '
          'the person\'s text size',
    );
    // DIRECTIONAL. Only the LABEL strip grows: 10px of font at 1.5x is 5px
    // more, and the plot keeps its height so the line is never squeezed.
    expect(large - normal, closeTo(5, 0.01));
  });

  group('the dot marks the day the card names, in every state', () {
    // This group exists because the file once said it did not need to. The
    // marker's docstring claimed agreement with the card was "structural, so
    // there is nothing left to assert", and in state S5 it was false: the
    // card named the last day and the dot sat on the first day at the
    // minimum. Each state is pinned below with the discriminator that puts a
    // ledger in it, so a change to either rule reddens here.

    test('S4, a real trough: the tightest day', () {
      // Falls to 9,000 on the 19th and CLIMBS BACK to 15,000, so the low
      // point is a trough and the card says "Tightest day: ... the 19th".
      final DailyProjection p = projectionOf(<ProjectedDay>[
        day(18, 12000),
        day(19, 9000),
        day(20, 15000),
      ], opening: 12000);

      expect(p.firstShortfall, isNull, reason: 'fixture must not go short');
      expect(p.closingBalance.pesos, greaterThan(9000));
      expect(runwayMarkedDay(p)?.date.day, 19);
    });

    test('S5, falls and stays down: the LAST day, not the first low one', () {
      // THE CASE THAT WAS WRONG. Holds 20,000, drops to 17,000 on the 20th
      // and never recovers. The tightest day is the 20th, because a strict
      // less-than returns the EARLIEST day at the minimum, but the closing
      // balance EQUALS it, so this is not a trough and the card names the end
      // of the window: "17,000 left on ..., and that is the lowest it gets".
      final DailyProjection p = projectionOf(<ProjectedDay>[
        day(18, 20000),
        day(19, 20000),
        day(20, 17000),
        day(21, 17000),
        day(22, 17000),
      ], opening: 20000);

      // The discriminator, stated so the fixture cannot drift into S4.
      expect(p.firstShortfall, isNull);
      expect(p.tightestDay?.date.day, 20);
      expect(
        p.closingBalance.pesos,
        closeTo(p.tightestDay!.balanceAfter.pesos, 0.0001),
        reason: 'closing must EQUAL the low point for this to be S5',
      );

      expect(
        runwayMarkedDay(p)?.date.day,
        22,
        reason:
            'the card names the last day here; marking the 20th puts the dot '
            'and the sentence on two different dates about one figure',
      );
    });
  });
}
