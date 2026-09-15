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
import 'package:salapify/features/settings/spreadsheet_export.dart';

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

/// Scroll until [what] is on screen.
///
/// `Screen` is a lazy ListView, so anything below the fold is NOT BUILT and a
/// plain `find` reports it missing. That is not a detail: two tests here went
/// red the moment the screen grew a spreadsheet section, for a reason that had
/// nothing to do with the section being wrong. "It is reachable" is the claim
/// this screen can make; "it is on the first viewport" is not.
Future<void> _scrollTo(WidgetTester tester, Finder what) async {
  await tester.scrollUntilVisible(
    what,
    200,
    scrollable: find.byType(Scrollable).first,
  );
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
      find.widgetWithText(PillButton, 'Save to this phone'),
      findsOneWidget,
      reason:
          'there is no way to keep a backup without sharing it, which is what '
          'the founder asked for: "what if i do not like to share it but just '
          'want to save in my device?"',
    );
    expect(
      find.widgetWithText(PillButton, 'Send it somewhere'),
      findsOneWidget,
      reason: 'sharing is gone, which was the only way out before',
    );
    expect(
      find.text('Restore from a file'),
      findsOneWidget,
      reason: 'there is no way to restore from the Settings screen',
    );
  });

  testWidgets('a consequence is readable WITHOUT tapping anything', (
    tester,
  ) async {
    // THE RULE THE REDESIGN APPLIES, as a test. A sentence stays visible if
    // not reading it can cost money or data; it may hide only if not reading
    // it costs understanding.
    //
    // The founder asked whether these paragraphs should go behind an "i" like
    // the budget sheet's. They must not, and this is the guard on that: that
    // copy teaches what a category cap IS, and skipping it costs only
    // comprehension. This copy says what is about to be destroyed. An "i" on a
    // destructive screen is a consent box nobody ticks.
    await _openSettings(tester);

    expect(
      find.textContaining('Replaces everything'),
      findsOneWidget,
      reason:
          'the most destructive action on the screen no longer says what it '
          'does until you tap it',
    );
    expect(
      find.textContaining('cannot be restored'),
      findsOneWidget,
      reason:
          'nothing on the resting screen says a spreadsheet is not a backup, '
          'so it reads as a second kind of one',
    );
  });

  testWidgets('the spreadsheet is never called a backup', (tester) async {
    // A CSV cannot be restored. The dangerous version of that feature is a
    // button somebody trusts as a backup, discovering at the worst possible
    // moment that it never was one. So the word is kept off that path, in the
    // section heading, the card, and the file name.
    await _openSettings(tester);

    // The warning is on the row at rest AND again in the sheet, which is where
    // the decision is actually made. Both, because the row has room for one
    // clause and the sheet is the last moment it can still change the answer.
    await _scrollTo(tester, find.text('Entries as a spreadsheet'));
    await tester.tap(find.text('Entries as a spreadsheet'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('cannot be restored'),
      findsWidgets,
      reason:
          'the sheet that makes the file does not say it cannot be restored, '
          'so somebody can walk away from it believing they have a backup',
    );
    expect(
      find.textContaining('Keep a backup as well'),
      findsOneWidget,
      reason: 'the sheet does not tell them what to do instead',
    );
    expect(csvFileName(DateTime(2026, 9, 15)), isNot(contains('backup')));
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
    await _scrollTo(tester, find.textContaining('plain text'));
    expect(find.textContaining('plain text'), findsOneWidget);
    expect(
      find.textContaining('including hidden accounts'),
      findsOneWidget,
      reason:
          'the warning no longer says hidden accounts are in the file, which '
          'is the part somebody who hid one would most want to know',
    );
  });
}
