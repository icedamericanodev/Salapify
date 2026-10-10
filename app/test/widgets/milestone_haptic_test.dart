// Paying a debt off is a milestone, and the phone says so with a firmer buzz
// than an ordinary save. A part payment gets the ordinary one.
//
// From the motion review of 2026-10-07. The interesting half is the SILENT
// one: a milestone buzz on every payment would be a buzz that means nothing,
// so the partial case is checked as hard as the clearing one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/screens/debt/debt_screen.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';

import '../support/pinned_app.dart';

void main() {
  late List<String> buzzes;

  setUp(() => buzzes = <String>[]);

  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> openFirstPayment(WidgetTester tester) async {
    await pumpSalapify(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          buzzes.add(call.arguments as String);
        }
        return null;
      },
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(DebtBeamCard),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(DebtBeamCard),
        matching: find.text('See all'),
      ),
    );
    expect(find.byType(DebtScreen), findsOneWidget);
    // Home Credit, 7,350 to go; the sheet pre-fills exactly that.
    await tapAndSettle(tester, find.text('Record a payment').first);
  }

  testWidgets('the payment that clears a debt buzzes firmer', (
    WidgetTester tester,
  ) async {
    await openFirstPayment(tester);
    await tapAndSettle(tester, find.text('Record the payment'));
    expect(buzzes, <String>['HapticFeedbackType.mediumImpact']);
  });

  testWidgets('a part payment gets the ordinary buzz', (
    WidgetTester tester,
  ) async {
    await openFirstPayment(tester);
    await tester.enterText(find.widgetWithText(TextField, '7350'), '2450');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Record the payment'));
    expect(buzzes, <String>['HapticFeedbackType.lightImpact']);
  });
}
