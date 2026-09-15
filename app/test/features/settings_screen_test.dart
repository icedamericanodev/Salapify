// The Settings screen, BUILT.
//
// This file exists because of a specific failure. Settings shipped with 524
// green tests behind it and drew nothing at all on the founder's phone: they
// opened it and reported "I do not see a Save button" and "no Restore button
// either". Both were true. The screen was throwing while building, because
// `initState` read the ledger through an inherited widget, which Flutter
// forbids.
//
// Not one of those 524 tests had ever built this widget. The backup logic was
// covered thoroughly and purely, the store was covered, the journey was
// covered, and the SCREEN was covered by nothing, so the one defect that could
// only appear in a screen had nowhere to be caught.
//
// The lesson is narrow and worth keeping: a feature is not tested until
// something has pumped the widget a person actually taps.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart' show sampleAnchor;

import '../support/memory_store.dart';

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

/// Walk there the way a person does, from the bottom of Accounts.
Future<void> _openSettings(WidgetTester tester) async {
  await tester.pumpWidget(_app(await memoryStore(livedIn())));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(NavBar),
      matching: find.byIcon(Icons.account_balance_wallet_outlined),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('Backup and settings'),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Backup and settings'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the way IN exists, from the bottom of Accounts', (tester) async {
    // Half of what the founder reported could have been the door rather than
    // the room. This pins the door.
    await _openSettings(tester);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('and BOTH buttons are actually on it', (tester) async {
    // The exact report, as an assertion. With the initState bug back, the
    // screen throws while building and neither of these is found.
    await _openSettings(tester);

    expect(
      find.widgetWithText(PillButton, 'Save a copy'),
      findsOneWidget,
      reason: 'there is no Save button on the Settings screen',
    );
    expect(
      find.widgetWithText(PillButton, 'Choose a file'),
      findsOneWidget,
      reason: 'there is no Restore button on the Settings screen',
    );
  });

  testWidgets('it names what is actually on the phone, not a placeholder', (
    tester,
  ) async {
    // A screen that builds but shows invented figures would pass the test
    // above. The Save card quotes the real ledger, so the founder can tell
    // before tapping whether it is about to back up what they think it is.
    await _openSettings(tester);
    expect(find.textContaining('3 accounts'), findsWidgets);
  });

  testWidgets('no Undo card until there is something to undo', (tester) async {
    // The card is the whole safety net after a restore, so it must not be
    // sitting there beforehand offering to undo something that never happened.
    await _openSettings(tester);
    expect(find.text('Undo the last restore'), findsNothing);
  });

  testWidgets('the plaintext warning is on the screen that makes the file', (
    tester,
  ) async {
    // Founder-approved on the condition that users are told. A warning that
    // lives only in a policy nobody opens is not telling anybody.
    await _openSettings(tester);
    expect(find.textContaining('plain readable text'), findsOneWidget);
  });
}
