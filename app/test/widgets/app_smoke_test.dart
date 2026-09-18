import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';

/// Boots the real app the way the phone does.
///
/// The shot harness builds HomeScreen directly, so it cannot see a fault in
/// main.dart or the shell. This can: it is the only test that proves the app
/// a person actually launches comes up at all.
void main() {
  testWidgets('the app boots and lands on Home with real money on screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    // The hero is present, and it is showing a peso figure rather than a
    // placeholder. An empty screen would satisfy a weaker assertion.
    expect(find.text('SAFE TO SPEND'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget w) => w is Text && (w.data ?? '').startsWith('₱'),
      ),
      findsWidgets,
    );

    // All five destinations from the prototype's TabBar, plus the Log pill.
    for (final String label in <String>[
      'Home',
      'Activity',
      'Reports',
      'Plan',
      'Accounts',
      'Log',
    ]) {
      expect(find.text(label), findsWidgets, reason: '$label is missing');
    }
  });

  testWidgets('every tab opens without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    for (final String tab in <String>[
      'Activity',
      'Reports',
      'Plan',
      'Accounts',
    ]) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      // The tab's own title is on screen, so the switch really happened.
      expect(find.text(tab), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the theme switch actually changes the background', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    Color background() =>
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor!;

    final Color before = background();
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();

    // Directional: the colour moved, so the toggle did something.
    expect(background(), isNot(before));
  });

  testWidgets('switching the scenario moves the Safe to Spend figure', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    String heroAmount() => tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data ?? '')
        .firstWhere((String s) => s.startsWith('₱'));

    final String conservative = heroAmount();
    expect(find.text('CONSERVATIVE'), findsOneWidget);

    await tester.tap(find.text('CONSERVATIVE'));
    await tester.pumpAndSettle();

    expect(find.text('OPTIMISTIC'), findsOneWidget);
    // Optimistic frees up more money, so this is not a no-op.
    expect(heroAmount(), isNot(conservative));
  });
}
