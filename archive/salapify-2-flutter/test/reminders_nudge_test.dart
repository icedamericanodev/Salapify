// The existing-debts reminder nudge on Notifications and security
// (f4.56). f4.55's opt-in only fires the moment a debt is saved, so a debt
// that already existed before that shipped, or one somebody saved and then
// declined the ask on, is never offered again anywhere. This surfaces the
// same offer on the screen where Bills due already lives, gated purely on
// live state (Bills due off, at least one debt with a resolvable due date),
// so it needs no settings flag of its own and cannot nag: it just stops
// showing once resolved.
//
// Reminders.supported is always false on the widget test platform, exactly
// as debts_screen_test.dart found for the wizard's own opt-in, so this uses
// the same test-seam pattern onboarding.dart's showNudge already
// established: showBillsNudge overrides the platform check for the test.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/notifications_security.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob(List<Map<String, dynamic>> debts) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true},
  'accounts': [],
  'debts': debts,
};

Future<SalapifyStore> _loaded(List<Map<String, dynamic>> debts) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(_blob(debts)),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

Widget _screen(SalapifyStore store, {bool? showBillsNudge}) => MaterialApp(
  theme: salapifyTheme(Barako.current),
  home: NotificationsSecurityScreen(
    store: store,
    showBillsNudge: showBillsNudge,
  ),
);

void main() {
  testWidgets(
    'a debt with a due day and Bills due off gets the nudge, with a live count',
    (tester) async {
      final store = await _loaded([
        {'name': 'Card', 'remaining': 5000, 'dueDay': 15},
        {'name': 'Loan', 'remaining': 2000, 'dueDay': 3},
      ]);
      await tester.pumpWidget(
        _screen(store, showBillsNudge: true),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('2 of your debts have a due date but no reminder set yet.'),
        findsOneWidget,
      );
      expect(find.text('Turn on Bills due'), findsOneWidget);
    },
  );

  testWidgets('no debts with a schedule means no nudge at all', (
    tester,
  ) async {
    final store = await _loaded([
      {'name': 'Family loan', 'remaining': 5000, 'dueDay': 0},
    ]);
    await tester.pumpWidget(_screen(store, showBillsNudge: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('no reminder set yet'), findsNothing);
    expect(find.text('Turn on Bills due'), findsNothing);
  });

  testWidgets('Bills due already on means no nudge, whatever the debts are', (
    tester,
  ) async {
    final store = await _loaded([
      {'name': 'Card', 'remaining': 5000, 'dueDay': 15},
    ]);
    await store.setNotifPref('bills', true);
    await tester.pumpWidget(_screen(store, showBillsNudge: true));
    await tester.pumpAndSettle();

    expect(find.textContaining('no reminder set yet'), findsNothing);
  });

  testWidgets(
    'on an unsupported platform (the real default) the nudge never shows',
    (tester) async {
      final store = await _loaded([
        {'name': 'Card', 'remaining': 5000, 'dueDay': 15},
      ]);
      // showBillsNudge left null: falls back to Reminders.supported, false
      // on the test platform, matching the real behaviour off Android/iOS.
      await tester.pumpWidget(_screen(store));
      await tester.pumpAndSettle();

      expect(find.textContaining('no reminder set yet'), findsNothing);
    },
  );
}
