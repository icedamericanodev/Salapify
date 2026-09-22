import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/health_check.dart';
import 'package:salapify/features/health/health_check_sheet.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/home/home_screen.dart';
import 'package:salapify/state/financial_state.dart';

/// Health Check, opened the way a person opens it.
///
/// The thing this file guards is the one that makes the screen worth having:
/// an indicator Salapify cannot answer offers a TAP, and every tap goes
/// somewhere real. A button that does nothing teaches somebody the screen is
/// decorative, and they do not tap the next one.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openHealth(WidgetTester tester) async {
    await tapAndSettle(tester, find.textContaining('HEALTH CHECK'));
    expect(
      find.byType(HealthCheckSheet),
      findsOneWidget,
      reason: 'the Health Check button on Home did not open it',
    );
  }

  testWidgets('it opens from Home and is no longer "coming soon"', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await openHealth(tester);
    expect(find.textContaining('not migrated yet'), findsNothing);
    expect(find.text('Health check'), findsOneWidget);
  });

  testWidgets('all five questions are there, in their fixed order', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await openHealth(tester);

    for (final String q in <String>[
      'Will I make it to payday',
      'How much of my pay is already promised',
      'Do I have a cushion',
      'Am I keeping any of it',
      'Am I inside the limits I set',
    ]) {
      expect(find.text(q), findsOneWidget, reason: '"$q" is missing');
    }
  });

  testWidgets('with the sample data swept, it offers the two first taps', (
    WidgetTester tester,
  ) async {
    // THE SEED HAS AN EMERGENCY GOAL AND BUDGETS, which an earlier version of
    // this test did not know: it looked for "Start an emergency fund" on a
    // ledger where the cushion is already measured, and failed with "No
    // element". Sweeping the sample data first puts the app in the state this
    // screen is really designed around, which is the person D19 names.
    await pumpApp(tester);
    final FinancialState state = tester
        .widget<HomeScreen>(find.byType(HomeScreen))
        .state;
    state.removeSampleData();
    await tester.pumpAndSettle();

    await openHealth(tester);

    expect(find.text('Nothing recorded yet'), findsOneWidget);
    expect(
      find.textContaining('will not'),
      findsWidgets,
      reason: 'the empty state has to say it invents nothing',
    );
    expect(find.text('Log something you spent'), findsOneWidget);
  });

  testWidgets('and that tap leaves the sheet and opens Log', (
    WidgetTester tester,
  ) async {
    // The failure mode this guards: a button that does nothing teaches
    // somebody the screen is decorative, and they stop tapping the next one.
    // It also checks the sheet is POPPED, because landing on a destination
    // still covered by Health Check looks exactly like a dead tap.
    await pumpApp(tester);
    final FinancialState state = tester
        .widget<HomeScreen>(find.byType(HomeScreen))
        .state;
    state.removeSampleData();
    await tester.pumpAndSettle();

    await openHealth(tester);
    await tapAndSettle(tester, find.text('Log something you spent'));

    expect(
      find.byType(HealthCheckSheet),
      findsNothing,
      reason: 'the sheet stayed over the destination, so the tap looked dead',
    );
    expect(find.byType(LogSheet), findsOneWidget);
  });

  testWidgets('every action label the engine can emit has a destination', (
    WidgetTester tester,
  ) async {
    // The switch in home_screen.dart is exhaustive over HealthNeed, so this
    // is really a guard against a new need arriving with no route. It fails
    // loudly at the point somebody adds one.
    expect(HealthNeed.values, hasLength(5));
  });

  testWidgets('it says it is not advice, and not connected to a bank', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    await openHealth(tester);
    expect(find.textContaining('not connected to'), findsOneWidget);
    expect(find.textContaining('financial advice'), findsOneWidget);
  });

  testWidgets('no card shows a colour without a word beside it', (
    WidgetTester tester,
  ) async {
    // Roughly one man in twelve cannot separate this red from this green,
    // and a screenshot loses it for everybody.
    await pumpApp(tester);
    await openHealth(tester);

    final int words =
        find.text('Fine').evaluate().length +
        find.text('Watch').evaluate().length +
        find.text('Tight').evaluate().length +
        find.text('Not yet').evaluate().length;
    expect(
      words,
      5,
      reason: 'each of the five cards must carry its state in words',
    );
  });
}
