import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reminders.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/features/reminders/reminders_sheet.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// The bell, tapped through the way a person uses it.
///
/// A write path is not tested until somebody can SEE what it did, and the
/// reminder sweep is a write path: it puts rows in the tray and saves them.
/// The engine tests in test/core/money/reminders_test.dart prove WHAT is due.
/// This file proves a person can find it, act on it, and switch it off, and
/// that what the header claims matches what the tray holds.
void main() {
  Future<void> pump(WidgetTester tester, FinancialState state) async {
    await tester.runAsync(loadRealFonts);
    final Palette p = Palette.of(state.theme);
    await tester.pumpWidget(
      MaterialApp(
        theme: salapifyTheme(p, state.theme),
        home: AppShell(state: state),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A phone tall enough that a sheet does not need scrolling to be read.
  void bigPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<FinancialState> ready({DateTime? at}) async {
    final FinancialState state = FinancialState(
      clock: at ?? DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    return state;
  }

  Future<void> openBell(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.notifications_none).first);
    await tester.pumpAndSettle();
  }

  testWidgets('the bell opens a tray holding real reminders from the ledger', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final FinancialState state = await ready();

    // Half one: the sweep actually wrote something. Directional, not a
    // conservation statement: the tray was empty at construction and is not
    // empty now, and what is in it names a bill that is in the ledger.
    expect(
      state.notifications,
      isNotEmpty,
      reason: 'nothing was raised on a ledger full of bills past their date',
    );

    await pump(tester, state);
    await openBell(tester);

    // Half two: a person can SEE it. The Converge bill falls due tomorrow on
    // this clock, and it is in the seeded bills.
    expect(find.textContaining('Converge'), findsWidgets);
    expect(find.text('Reminders'), findsWidgets);
  });

  testWidgets('the screen says plainly that the phone will not buzz', (
    WidgetTester tester,
  ) async {
    // The one sentence that is neither a figure nor a message, and the reason
    // it is allowed to stay on the screen: somebody who opens a screen headed
    // Reminders will otherwise rely on being reminded and miss a payment.
    bigPhone(tester);
    await pump(tester, await ready());
    await openBell(tester);

    expect(
      find.textContaining('Your phone does not buzz'),
      findsOneWidget,
      reason:
          'the app quietly implies a notification it has never had permission '
          'to send',
    );
  });

  testWidgets('the filter pills sit in a row, not stacked full width', (
    WidgetTester tester,
  ) async {
    // Measured on the PILL, never on find.text. A Text hugs its content even
    // when the box around it has expanded to the whole line, so an assertion
    // about the label would pass with the defect fully present. That is the
    // trap this repository has already fallen into once.
    bigPhone(tester);
    await pump(tester, await ready());
    await openBell(tester);

    final Finder pill = find
        .ancestor(
          of: find.textContaining('Payment due ('),
          matching: find.byType(Material),
        )
        .first;
    final double width = tester.getSize(pill).width;
    final double screen = tester.getSize(find.byType(MaterialApp)).width;

    expect(
      width,
      lessThan(screen * 0.6),
      reason:
          'a pill grew to the whole line, so five filters became five stacked '
          'bars. A Container with an alignment and no width fills everything '
          'a Wrap offers it.',
    );
  });

  testWidgets('the header badge is the tray, not a number from the seed', (
    WidgetTester tester,
  ) async {
    // It used to read 12 on a brand new phone, from a seed constant, for
    // notifications that had never been sent.
    bigPhone(tester);
    final FinancialState state = await ready();

    expect(state.unreadNotificationsCount, isNot(12));
    expect(
      state.unreadNotificationsCount,
      state.notifications.where((n) => !n.isRead).length,
    );

    await pump(tester, state);

    // And the mark a person actually sees says the same thing. Asserting on
    // the getter alone would pass with the header still painting a constant.
    final int unread = state.unreadNotificationsCount;
    expect(
      find.text(unread > 9 ? '9+' : '$unread'),
      findsWidgets,
      reason: 'the bell badge and the tray disagree about how many there are',
    );

    await openBell(tester);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(state.unreadNotificationsCount, 0);
    expect(
      state.notifications,
      isNotEmpty,
      reason: 'marking read must not delete anything',
    );
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('clearing empties the tray and says so', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final FinancialState state = await ready();
    await pump(tester, state);
    await openBell(tester);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(state.notifications, isEmpty);
    expect(find.text('Nothing to tell you'), findsOneWidget);
  });

  testWidgets('switching a rule off silences that kind, and only that kind', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final FinancialState state = await ready();
    await pump(tester, state);
    await openBell(tester);

    // Start from an empty tray so the next sweep is the only thing in it.
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();

    final Finder billSwitch = find.descendant(
      of: find.byKey(ruleKey(ReminderKind.billDue)),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(billSwitch);
    await tester.pumpAndSettle();
    await tester.tap(billSwitch);
    await tester.pumpAndSettle();

    expect(state.reminderSettings.billEnabled, isFalse);
    expect(
      state.notifications.any((n) => n.kind == ReminderKind.billDue),
      isFalse,
      reason: 'bills were switched off and a bill reminder was raised anyway',
    );

    // The other half of the alarm: a rule that was left alone still fires. A
    // switch that silenced everything would pass the assertion above.
    expect(state.reminderSettings.paymentDueEnabled, isTrue);
    expect(
      state.notifications.any((n) => n.kind == ReminderKind.paymentDue),
      isTrue,
      reason:
          'switching bills off took the payment reminders with it, so the '
          'setting is not the switch it appears to be',
    );
  });

  testWidgets('a test reminder says, in its own body, that it is a test', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final FinancialState state = await ready();
    await pump(tester, state);
    await openBell(tester);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test a bill reminder'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('This is a test, not a real reminder'),
      findsOneWidget,
      reason:
          'a drill that reads like the real thing is how somebody learns to '
          'ignore the real thing',
    );
  });

  testWidgets('reopening does not say the same thing twice', (
    WidgetTester tester,
  ) async {
    bigPhone(tester);
    final FinancialState state = await ready();
    final int first = state.notifications.length;

    await pump(tester, state);
    await openBell(tester);
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    await openBell(tester);

    expect(
      state.notifications.length,
      first,
      reason:
          'every open of the bell raised the whole set again, so an evening '
          'of checking would bury the one that matters',
    );
  });

  testWidgets('the tray survives a restart', (WidgetTester tester) async {
    // It is stored, not recomputed, which is what makes "mark read" mean
    // anything at all.
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState first = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: store,
    );
    await first.restore();
    await first.flushWrites();
    first.markAllNotificationsRead();
    await first.flushWrites();

    final FinancialState second = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: store,
    );
    await second.restore();

    expect(second.notifications, isNotEmpty);
    expect(
      second.unreadNotificationsCount,
      0,
      reason:
          'the read marks were lost on restart, so every reminder comes back '
          'shouting on the next app open',
    );
  });
}
