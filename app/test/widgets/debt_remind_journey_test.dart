import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';

import '../support/pinned_app.dart';

/// Asking for money owed to you (D31): an overdue line on the card, and a
/// polite message handed to the phone's share sheet.
///
/// The share is checked at the plugin's own channel, so the test reads what
/// the phone would actually receive, not what a helper says it would send.
void main() {
  const MethodChannel share = MethodChannel('dev.fluttercommunity.plus/share');
  final List<String> shared = <String>[];

  setUp(() {
    shared.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(share, (MethodCall call) async {
          final Object? args = call.arguments;
          if (args is Map && args['text'] is String) {
            shared.add(args['text'] as String);
          }
          return 'dev.fluttercommunity.plus/share/unavailable';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(share, null);
  });

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openOwedToYou(WidgetTester tester) async {
    await pumpSalapify(tester);
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(DebtBeamCard),
        matching: find.text('See all'),
      ),
    );
    await tapAndSettle(tester, find.text('Owed to you'));
  }

  testWidgets('a receivable two days past due SAYS it is overdue', (
    WidgetTester tester,
  ) async {
    await openOwedToYou(tester);
    // Sarah's lunch money is seeded as due two days before the fixture date.
    expect(find.text('Overdue by 2 days'), findsOneWidget);
  });

  testWidgets('Send a reminder hands a polite message, with the amount, to '
      'the share sheet', (WidgetTester tester) async {
    await openOwedToYou(tester);
    final Finder remind = find.text('Send a reminder');
    expect(remind, findsWidgets, reason: 'no reminder control on Owed to you');

    await tapAndSettle(tester, remind.first);
    expect(shared, hasLength(1), reason: 'nothing reached the share sheet');
    expect(shared.single, startsWith('Hi '));
    expect(shared.single, contains('₱'));
    expect(shared.single, contains('thank you'));
  });

  testWidgets('money YOU owe offers no reminder to send', (
    WidgetTester tester,
  ) async {
    await pumpSalapify(tester);
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(DebtBeamCard),
        matching: find.text('See all'),
      ),
    );
    await tapAndSettle(tester, find.text('You owe'));
    expect(find.text('Send a reminder'), findsNothing);
  });
}
