import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/debt/amortization_table.dart';
import 'package:salapify/state/financial_state.dart';

/// The schedule, reached the way a person reaches it.
///
/// Every loan calculator produced an amortisation schedule from the day the
/// engine was ported, and not one of them SHOWED it. The engine tests were
/// green the whole time, because an engine test cannot tell you that nothing
/// renders its output. Only a walk to the screen can.
void main() {
  Future<void> tapAndSettle(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> reach(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(
      f,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAmortization(WidgetTester tester) async {
    await tester.pumpWidget(
      SalapifyApp(
        state: FinancialState(
          clock: DateTime(2026, 9, 18, 12),
          store: MemorySnapshotStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byIcon(Icons.track_changes_outlined));
    await tapAndSettle(tester, find.text('Calculators'));
    await tapAndSettle(tester, find.text('Debt and loan'));
    await tapAndSettle(tester, find.text('Amortization'));
  }

  testWidgets('the tab is called Amortization, not Work it out', (
    WidgetTester tester,
  ) async {
    await openAmortization(tester);
    expect(find.text('Amortization'), findsOneWidget);
    expect(find.text('Work it out'), findsNothing);
  });

  testWidgets('a Pag-IBIG loan shows its month by month statement', (
    WidgetTester tester,
  ) async {
    await openAmortization(tester);

    await reach(tester, find.byType(AmortizationTable));
    expect(
      find.byType(AmortizationTable),
      findsOneWidget,
      reason:
          'THE test. The engine has produced a schedule since the day it was '
          'ported and nothing ever drew one.',
    );

    await reach(tester, find.text('Month 1'));
    expect(find.text('Month 1'), findsOneWidget);
    expect(find.text('Month 2'), findsOneWidget);
  });

  testWidgets('the totals match what the calculator said above them', (
    WidgetTester tester,
  ) async {
    await openAmortization(tester);
    await reach(tester, find.text('TOTAL PAYABLE'));

    // The defaults are the prototype's own, so these are the prototype's own
    // figures. A statement that disagrees with the summary six inches above
    // it is worse than no statement.
    expect(find.text('PRINCIPAL LOAN'), findsOneWidget);
    expect(find.textContaining('₱1,500,000.00'), findsWidgets);
    expect(find.textContaining('₱2,355,171.14'), findsWidgets);
    expect(find.textContaining('₱855,171.14'), findsWidgets);
  });

  testWidgets('the pager says where you are and moves', (
    WidgetTester tester,
  ) async {
    await openAmortization(tester);
    await reach(tester, find.textContaining('Showing 1 to 24 of'));
    expect(find.textContaining('Showing 1 to 24 of 205'), findsOneWidget);
    expect(find.text('1 / 9'), findsOneWidget);

    await tapAndSettle(tester, find.byIcon(Icons.chevron_right));
    expect(find.text('2 / 9'), findsOneWidget);
    expect(
      find.textContaining('Showing 25 to 48 of 205'),
      findsOneWidget,
      reason: 'the page moved but the rows did not',
    );
    await reach(tester, find.text('Month 25'));
    expect(find.text('Month 25'), findsOneWidget);
    expect(find.text('Month 1'), findsNothing);
  });

  testWidgets('the annual summary really is years, not months', (
    WidgetTester tester,
  ) async {
    await openAmortization(tester);
    await reach(tester, find.textContaining('Annual summary'));
    await tapAndSettle(tester, find.textContaining('Annual summary'));

    await reach(tester, find.text('Year 1'));
    expect(find.text('Year 1'), findsOneWidget);
    expect(
      find.text('Month 1'),
      findsNothing,
      reason: 'the toggle changed the label and not the rows',
    );
    expect(find.textContaining('of 18'), findsOneWidget);
  });

  testWidgets('Copy puts a real CSV on the clipboard', (
    WidgetTester tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await openAmortization(tester);
    await reach(tester, find.text('Copy'));
    await tapAndSettle(tester, find.text('Copy'));

    expect(copied, isNotNull);
    expect(copied, contains('SALAPIFY 3 - PAG-IBIG HOUSING LOAN STATEMENT'));
    expect(copied, contains('Cumulative Principal Paid (PHP)'));
    expect(
      copied!.split('\r\n').length,
      greaterThan(200),
      reason: 'the clipboard got the header and none of the 205 rows',
    );
  });

  testWidgets('every loan type that repays over time has a statement', (
    WidgetTester tester,
  ) async {
    // The founder asked for this "for each type of loan". A test that checked
    // only Pag-IBIG would pass while five of the six were still bare.
    //
    // Opened ONCE, outside the loop. Re-pumping SalapifyApp does not pop the
    // pushed debt route, so calling the opener again lands on whatever
    // calculator the last iteration left behind and then hunts for a tab that
    // is no longer on screen. The nine calculators share one screen anyway.
    await openAmortization(tester);

    for (final String calculator in <String>[
      'Bank housing',
      'Car loan',
      'SSS and Pag-IBIG salary',
      'Personal and digital',
      'Consolidation',
    ]) {
      await reach(tester, find.text(calculator));
      await tapAndSettle(tester, find.text(calculator));
      await reach(tester, find.byType(AmortizationTable));
      expect(
        find.byType(AmortizationTable),
        findsOneWidget,
        reason: '$calculator has no schedule on screen',
      );
      await reach(tester, find.text('Export CSV'));
      expect(
        find.text('Export CSV'),
        findsOneWidget,
        reason: '$calculator cannot be exported',
      );
    }
  });

  testWidgets('a calculator that answers a question has no schedule', (
    WidgetTester tester,
  ) async {
    // The directional companion. If every calculator showed a table, the test
    // above would pass for the wrong reason.
    await openAmortization(tester);
    await tapAndSettle(tester, find.text('Can I afford it'));
    expect(
      find.byType(AmortizationTable),
      findsNothing,
      reason:
          'the affordability check does not repay anything, so a repayment '
          'schedule under it would be an answer to a question nobody asked',
    );
  });
}
