// What the app asks for after an entry lands, and what it never asks twice.
//
// Two offers, each attached to something the person has just done rather than
// to a screen they met before the app had earned anything.
//
// The notification permission is the sharper of the two. Android gives one
// chance: after a denial the only route back is a system settings screen
// nobody finds, which `ReminderSettings.phoneEnabled` already documents. So
// it is asked once, immediately after somebody's first self-made entry, when
// the benefit is concrete because they have just performed the exact
// behaviour the reminder supports.
//
// The payday is the other. Not asked at install, where a dropdown spends the
// moment money is salient weeks before it pays off, but at the first income
// entry, as a yes or no rather than a form.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reminders.dart';
import 'package:salapify/data/notification_gateway.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/features/log/log_sheet.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Android, answering whichever way a test needs.
class _Phone implements NotificationGateway {
  _Phone({this.grant = true});

  final bool grant;
  bool asked = false;

  @override
  Future<bool> requestPermission() async {
    asked = true;
    return grant;
  }

  @override
  Future<bool> hasPermission() async => grant;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan) async {}

  @override
  Future<void> cancelAll() async {}
}

void main() {
  late _Phone phone;

  /// An app somebody has already started with their own money: one account,
  /// no demo, nothing logged. The state a first entry is made from.
  Future<FinancialState> startedApp(
    WidgetTester tester, {
    bool grant = true,
  }) async {
    await tester.runAsync(loadRealFonts);

    // Taller than the 800 by 600 default, which is shorter than any phone.
    // Home is a lazily built list and this file taps controls below the fold.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    phone = _Phone(grant: grant);
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18),
      store: MemorySnapshotStore(),
      notifications: phone,
    );
    await state.restore();
    state.startWithOwnMoney(accountName: 'GCash', opening: Money.pesos(5140));
    addTearDown(state.dispose);

    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  Future<void> tapIt(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  /// Log one entry through the real sheet, from the Today row on Home.
  ///
  /// Driven by the sheet's own KEYS rather than by field order, the way
  /// log_journey_test does it. A positional `byType(TextField).at(1)` reads
  /// as fine and silently types the merchant into whatever field happens to
  /// sit second today.
  Future<void> logOne(
    WidgetTester tester, {
    required String amount,
    required String merchant,
    bool income = false,
  }) async {
    // THE BOTTOM BAR, not the Today row, and that is not laziness. Saving
    // lands the app on Activity, so a second call would find no Today row at
    // all, and after the first entry that row carries a figure rather than
    // the empty state anyway. The row's own job as a door is asserted once,
    // in the first test, where it is the thing being measured.
    await tapIt(tester, find.text('Log').last);
    expect(find.byType(LogSheet), findsOneWidget);

    if (income) await tapIt(tester, find.text('Received'));

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      amount,
    );
    await tester.pumpAndSettle();

    await tapIt(
      tester,
      find.descendant(
        of: find.byKey(const Key('log-source-picker')),
        matching: find.text('GCash'),
      ),
    );

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-merchant')),
        matching: find.byType(TextField),
      ),
      merchant,
    );
    await tester.pumpAndSettle();

    await tapIt(tester, find.text('Save entry'));
  }

  testWidgets('the Today row is the door, and it carries the figure after', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await startedApp(tester);

    // THE EMPTY STATE IS THE CALL TO ACTION. On a started app with nothing
    // logged it is the only thing on Home that leads anywhere useful.
    expect(find.text('Nothing logged yet'), findsOneWidget);

    await logOne(tester, amount: '320', merchant: 'Jeepney');

    // The offer fires on a first entry, so clear it before reading Home.
    await tapIt(tester, find.text('Not now'));

    expect(
      state.spentToday,
      Money.pesos(320),
      reason: 'the entry did not land, so the row below proves nothing',
    );
    expect(find.text('Nothing logged yet'), findsNothing);
  });

  testWidgets('the first entry offers the nudge, and a yes asks the phone', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await startedApp(tester);
    expect(state.reminderSettings.phoneEnabled, isFalse);

    await logOne(tester, amount: '320', merchant: 'Jeepney');

    expect(
      find.text('That is one entry'),
      findsOneWidget,
      reason: 'nothing offered the daily nudge after the first ever entry',
    );

    // THE TIME COMES FROM THE SETTINGS, never written into the sentence, so
    // the promise cannot disagree with the Reminders screen.
    expect(find.textContaining('8pm'), findsWidgets);

    // NOT ASKED UNTIL THE TAP. The whole design is that the Android dialog
    // reads as confirmation of a choice the person just made.
    expect(phone.asked, isFalse);

    await tapIt(tester, find.text('Remind me at 8pm'));

    expect(phone.asked, isTrue);
    expect(state.reminderSettings.phoneEnabled, isTrue);
    expect(find.textContaining('Salapify will nudge you at 8pm'), findsOne);
  });

  testWidgets('a phone that says no is reported, not pretended past', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await startedApp(tester, grant: false);

    await logOne(tester, amount: '320', merchant: 'Jeepney');
    await tapIt(tester, find.text('Remind me at 8pm'));

    expect(phone.asked, isTrue);
    expect(
      state.reminderSettings.phoneEnabled,
      isFalse,
      reason: 'the setting went on while the phone had refused',
    );
    // A refusal dressed as a success leaves somebody waiting for a nudge that
    // is never coming, and blaming the app when they forget to log.
    expect(find.textContaining('Your phone said no'), findsOne);
  });

  testWidgets('it is offered ONCE, not on every entry', (
    WidgetTester tester,
  ) async {
    await startedApp(tester);

    await logOne(tester, amount: '320', merchant: 'Jeepney');
    await tapIt(tester, find.text('Not now'));

    await logOne(tester, amount: '180', merchant: 'Kape');

    expect(
      find.text('That is one entry'),
      findsNothing,
      reason:
          'the nudge was offered a second time, which is how an app '
          'teaches somebody to dismiss without reading',
    );
  });

  testWidgets('the payday is asked at the first income, not at install', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await startedApp(tester);

    // NOTHING asked for it during onboarding, which is the whole point. A
    // form on screen one spends the moment money is salient weeks early.
    expect(state.payday.isSet, isFalse);

    // The first entry spends its one offer on the nudge, by design: the
    // reminder is the lever on whether there is a second session at all.
    await logOne(tester, amount: '320', merchant: 'Jeepney');
    await tapIt(tester, find.text('Not now'));

    await logOne(tester, amount: '18000', merchant: 'Sweldo', income: true);

    expect(
      find.text('When do you get paid?'),
      findsOneWidget,
      reason: 'money came in and nothing asked about the cycle',
    );

    await tapIt(tester, find.text('Yes, 15th and 30th'));

    expect(
      state.payday.isSet,
      isTrue,
      reason: 'a single yes did not actually set the cycle',
    );
    expect(state.payday.paydayDays, <int>[15, 30]);
  });

  testWidgets('an expense never triggers the payday question', (
    WidgetTester tester,
  ) async {
    await startedApp(tester);

    await logOne(tester, amount: '320', merchant: 'Jeepney');
    await tapIt(tester, find.text('Not now'));
    await logOne(tester, amount: '180', merchant: 'Kape');

    expect(
      find.text('When do you get paid?'),
      findsNothing,
      reason: 'spending money is not evidence about when you are paid',
    );
  });

  testWidgets('a SECOND launch does not ask again, having been declined once', (
    WidgetTester tester,
  ) async {
    // THE ONLY SHAPE THAT REACHES THE GUARD, and it took a break that failed
    // to fail to find it.
    //
    // `firstEver` was deliberately removed from the condition and all six
    // tests above stayed green, because within one run the session latch
    // already stops a second offer, so the two conditions covered for each
    // other. The branch `firstEver` actually protects is a NEW APP RUN: the
    // latch resets with the widget, the person still has not enabled
    // reminders, and without it the app would ask again on their next entry,
    // and the one after that, forever.
    //
    // That is the difference between an offer and a nag, and it is only
    // visible across a restart, which is why this test pumps a second app
    // over the file the first one wrote.
    await tester.runAsync(loadRealFonts);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);

    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState first = FinancialState(
      clock: DateTime(2026, 9, 18),
      store: store,
      notifications: _Phone(),
    );
    await first.restore();
    first.startWithOwnMoney(accountName: 'GCash', opening: Money.pesos(5140));
    // An entry already made, and the nudge never turned on: somebody who
    // tapped Not now yesterday.
    first.logTransaction(
      Transaction(
        id: 'tx_1759000000000',
        type: TransactionType.expense,
        amount: Money.pesos(320),
        category: 'Transportation',
        accountId: first.accounts.single.id,
        date: '2026-09-18',
        createdAt: 1,
        merchant: 'Jeepney',
      ),
    );
    await first.flushWrites();
    first.dispose();

    phone = _Phone();
    final FinancialState second = FinancialState(
      clock: DateTime(2026, 9, 19),
      store: store,
      notifications: phone,
    );
    await second.restore();
    addTearDown(second.dispose);

    expect(
      second.reminderSettings.phoneEnabled,
      isFalse,
      reason: 'the fixture already has reminders on, so this proves nothing',
    );
    expect(
      second.transactions.where((Transaction t) => !t.isSample).length,
      1,
      reason:
          'the earlier entry did not survive, so nothing is second about '
          'the entry below',
    );

    await tester.pumpWidget(SalapifyApp(state: second));
    await tester.pumpAndSettle();

    await logOne(tester, amount: '180', merchant: 'Kape');

    expect(
      find.text('That is one entry'),
      findsNothing,
      reason:
          'a new run offered the nudge again to somebody who had already '
          'declined it, which is a nag rather than an offer',
    );
    expect(phone.asked, isFalse);
  });
}
