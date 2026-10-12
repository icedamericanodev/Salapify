import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

/// Reminders to ask for money owed to you, by tapping (D38.1).
///
/// The rule is test/core/money/collection_reminders_test.dart. This is what a
/// person meets: the bell holds "Owed to you", its "Send a reminder" hands the
/// friendly message to the share sheet, and once the debt is cleared the same
/// message no longer offers to ask for money nobody owes.
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

  // The seed's Sarah owes 1,250, due two days before the fixture date.
  final Finder sarah = find.text('Owed to you: Sarah (Office lunch)');

  testWidgets('the bell holds the ask, and Send a reminder hands the message '
      'to the share sheet', (WidgetTester tester) async {
    final FinancialState state = await pumpSalapify(tester);
    await tapAndSettle(tester, find.byIcon(Icons.notifications_none).first);

    expect(sarah, findsOneWidget, reason: 'no reminder about Sarah');
    expect(
      find.textContaining('owes you ₱1,250.00, due 2 days ago'),
      findsOneWidget,
    );

    final Finder send = find.text('Send a reminder');
    expect(send, findsOneWidget);
    await tapAndSettle(tester, send);

    expect(shared, hasLength(1), reason: 'nothing reached the share sheet');
    expect(shared.single, startsWith('Hi Sarah'));
    expect(shared.single, contains('₱1,250.00'));
    // Sending is reading it: the unread dot does not linger on a done task.
    expect(
      state.notifications
          .firstWhere((n) => n.id.startsWith('collect-debt_sarah-'))
          .isRead,
      isTrue,
    );
  });

  testWidgets('once the debt is cleared, the message stays but no longer '
      'offers to ask', (WidgetTester tester) async {
    final FinancialState state = await pumpSalapify(tester);
    state.refreshReminders();
    state.toggleDebtSettledById('debt_sarah');
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.byIcon(Icons.notifications_none).first);
    expect(sarah, findsOneWidget);
    expect(find.text('Send a reminder'), findsNothing);
  });

  testWidgets('switching "Money owed to you" off raises no new ask', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await pumpSalapify(tester);
    state.clearAllNotifications();
    state.updateReminderSettings(
      state.reminderSettings.copyWith(collectionEnabled: false),
    );
    await tester.pumpAndSettle();

    await tapAndSettle(tester, find.byIcon(Icons.notifications_none).first);
    expect(sarah, findsNothing);
  });
}
