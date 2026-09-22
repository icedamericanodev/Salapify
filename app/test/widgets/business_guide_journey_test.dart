// Tick a box in the registration checklist, and can anybody SEE that you did?
//
// The storage round trip is held by test/data/guide_steps_test.dart, and it
// proves the money-equivalent half: the write is correct where it is written.
// This file is the other half, which is the one this repository keeps losing:
// a write is not tested until somebody can follow it afterwards, by tapping.
//
// The concrete failure that rule came from was a debt payment that moved a
// balance and left nothing in the account's history. The shape here is the
// same. `toggleGuideStep` can be flawless and `isGuideStepDone` can be
// flawless while the screen that reads them never redraws, and every unit
// test in the repository would still be green. That is not hypothetical for
// this screen in particular: it is PUSHED over the shell, so it sits outside
// the ListenableBuilder that redraws the tabs, and a tick would stay invisible
// until you left the screen and came back.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/business_guide_data.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/design/app_theme.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/plan/business_guide_screen.dart';
import 'package:salapify/shell/app_shell.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Opens the guide the way a person does: Plan, Academy, scroll, tap.
///
/// Top level rather than a closure inside main(), because the roadmap and
/// structure journeys added later live outside main() too and a helper only
/// half the file can reach gets copied instead of shared.
Future<FinancialState> openChecklistFor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final FinancialState state = FinancialState(clock: DateTime.utc(2026, 9, 22));
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Palette.of(state.theme), state.theme),
      home: AppShell(state: state),
    ),
  );
  await tester.pumpAndSettle();

  // Plan tab, then the Academy segment, then the card. Tapped, not
  // constructed: a screen somebody cannot REACH is not shipped, and this
  // one replaced a card that deliberately opened nothing.
  await tester.tap(find.text('Plan').last);
  await tester.pumpAndSettle();

  // ensureVisible before the tap, both times. On an 844dp phone the Academy
  // tile sits below the fold, and tapping a finder whose centre is off
  // screen does NOT fail: it warns and the tap lands nowhere, so the screen
  // simply does not change and every assertion afterwards fails for a
  // reason that has nothing to do with what is being tested.
  await tester.ensureVisible(find.text('Academy').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Academy').last);
  await tester.pumpAndSettle();

  // SCROLLED to, because on a real 844dp phone the card is below the fold,
  // and a door somebody has to scroll to is still a door. The first version
  // of this helper used a 1400dp tall viewport so everything was on screen
  // at once, which is not a phone and which turned out to hide an unrelated
  // Home overflow that only exists at that height.
  final Finder door = find.textContaining('step checklist');
  if (door.evaluate().isNotEmpty) {
    await tester.ensureVisible(door);
    await tester.pumpAndSettle();
  }
  expect(
    door,
    findsOneWidget,
    reason: 'the Academy card no longer offers a way into the checklist',
  );
  await tester.tap(door);
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('the checklist is reachable and shows the real steps', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);

    expect(find.text('Registering a business'), findsOneWidget);
    // A real step from the data file, not a placeholder.
    expect(find.text('Register Business Name & Entity'), findsOneWidget);
    expect(find.textContaining('0 of 23 done'), findsOneWidget);
  });

  testWidgets('ticking a step shows on THIS screen immediately', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await openChecklistFor(tester);

    await tester.tap(find.text('Register Business Name & Entity'));
    await tester.pumpAndSettle();

    // The directional half: the count moved, and it moved by exactly one.
    // Without this the test would pass on a screen that redrew and changed
    // nothing, which is the shape an invariant alone cannot catch.
    expect(find.textContaining('1 of 23 done'), findsOneWidget);
    expect(state.isGuideStepDone('chk_dti_sec'), isTrue);
  });

  testWidgets('the tick is still there after leaving and coming back', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);

    await tester.tap(find.text('Register Business Name & Entity'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // The card behind it has to agree. Two screens reading the same store and
    // disagreeing about it is the exact defect journeys exist to catch.
    expect(find.textContaining('1 of 23 done'), findsOneWidget);

    await tester.tap(find.textContaining('1 of 23 done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 23 done'), findsOneWidget);
  });

  testWidgets('ticking twice takes it back off', (WidgetTester tester) async {
    await openChecklistFor(tester);

    await tester.tap(find.text('Register Business Name & Entity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Register Business Name & Entity'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0 of 23 done'), findsOneWidget);
  });

  testWidgets('a tick reaches the file a backup would be made from', (
    WidgetTester tester,
  ) async {
    // The founder chose "save them, include in backup" over the two cheaper
    // options, so the backup is the thing that choice was ABOUT. Asserting it
    // on the store alone would pass for a build that never wrote the key.
    final FinancialState state = await openChecklistFor(tester);

    await tester.tap(find.text('Register Business Name & Entity'));
    await tester.pumpAndSettle();

    final Map<String, dynamic> file = state.snapshot().toJson(
      at: DateTime.utc(2026, 9, 22),
    );
    expect(file[Snapshot.kGuideSteps], contains('chk_dti_sec'));
  });

  testWidgets('filtering narrows the list and never inflates progress', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);

    await tester.tap(find.text('Employer'));
    await tester.pumpAndSettle();

    // An employer step is on screen and a local government one is not.
    expect(find.text('Register as Employer with SSS'), findsOneWidget);
    expect(find.text('Obtain Barangay Business Clearance'), findsNothing);

    // Progress still counts the WHOLE list. Counting the filtered list would
    // let somebody reach "4 of 4 done" by tapping a chip, on a screen where
    // that reads as having finished registering a business.
    expect(find.textContaining('of 23 done'), findsOneWidget);
  });

  testWidgets('the confirm-before-filing notice is ON the screen', (
    WidgetTester tester,
  ) async {
    // The exception to the dot rule, asserted rather than trusted. Twenty
    // three steps naming forms, agencies and deadlines read as a definitive
    // statement of what the law requires today, and some of it will go out of
    // date. Silence there misleads, so the warning does not live behind the
    // dot, and this is what stops it drifting back there.
    //
    // The first version of this port DID put it behind the dot.
    await openChecklistFor(tester);

    expect(find.text('Confirm before you file'), findsOneWidget);
    expect(
      find.textContaining('check with the agency or an accountant'),
      findsOneWidget,
    );
  });

  _roadmapAndStructure();

  _roadmapAndStructure();

  _readabilityChecks();

  testWidgets('every step id in the data file is unique', (
    WidgetTester tester,
  ) async {
    // Ids are STORED. Two steps sharing one would make ticking either tick
    // both, forever, on real people's phones.
    final Set<String> seen = <String>{};
    for (final BusinessStep s in businessChecklist) {
      expect(seen.add(s.id), isTrue, reason: 'duplicate id ${s.id}');
      expect(s.id, startsWith('chk_'));
    }
  });
}

/// The new screen, held to the bar the rest of the app was just held to.
///
/// The readability sweep in test/screen_readability_test.dart only walks the
/// five TABS, and this screen is pushed over them, so none of its checks can
/// reach it. That gap is real and known; this is the narrow version of it for
/// one screen, rather than a promise to fix the sweep later.
///
/// 320dp is here because the nav bar turned out to truncate at 320 at the
/// ordinary font size and no test could see it, the sweep rendering 390 only.
void _readabilityChecks() {
  for (final double width in <double>[320, 390]) {
    for (final double scale in <double>[1.0, 1.5]) {
      testWidgets('the checklist survives ${width}dp at ${scale}x', (
        WidgetTester tester,
      ) async {
        await tester.runAsync(loadRealFonts);
        tester.view.physicalSize = Size(width * 3, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        final List<String> overflows = <String>[];
        final void Function(FlutterErrorDetails)? previous =
            FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails d) {
          final String s = d.exceptionAsString();
          if (s.contains('overflowed')) {
            overflows.add(s.split('\n').first);
          } else {
            previous?.call(d);
          }
        };

        try {
          final FinancialState state = FinancialState(
            clock: DateTime.utc(2026, 9, 22),
          );
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: MaterialApp(
                theme: salapifyTheme(Palette.of(state.theme), state.theme),
                home: Scaffold(
                  body: SafeArea(
                    child: BusinessGuideScreen(state: state, onBack: () {}),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Nothing painted past the edge of the phone.
          expect(overflows, isEmpty, reason: overflows.join('\n'));

          // And nothing a person needs was cut short. A step's TITLE and its
          // AGENCY are the two things somebody reads to know what to go and
          // do, so an ellipsis in either is a defect rather than a tradeoff.
          final List<String> cut = <String>[];
          for (final Element e in find.byType(Text).evaluate()) {
            final RenderObject? ro = e.renderObject;
            if (ro is! RenderParagraph || !ro.attached) continue;
            if (!ro.didExceedMaxLines) continue;
            cut.add('"${(e.widget as Text).data}"');
          }
          expect(
            cut,
            isEmpty,
            reason: 'cut off at ${width}dp / ${scale}x: ${cut.join(', ')}',
          );
        } finally {
          FlutterError.onError = previous;
        }
      });
    }
  }
}

/// Scrolls the guide's own list until [f] exists, then returns.
///
/// Needed because the roadmap and the structure comparison are both longer
/// than a phone, and `find.text` only sees widgets a lazy ListView has
/// actually BUILT. The first version of these journeys asserted straight
/// after switching segment and failed on content that was simply further
/// down, which reads exactly like content that is missing.
///
/// `.last` picks the pushed screen's list rather than the shell's underneath,
/// which is still mounted behind the route.
Future<void> reveal(WidgetTester tester, Finder f) async {
  final Finder list = find.byType(ListView).last;
  // UP first, then down. Scrolling only downward found nothing once, and the
  // reason is worth keeping: answering a matcher question inserts a result
  // card BELOW it, so a test that scrolls down to read the result has left
  // the questions behind, and a lazy list disposes what it scrolled past.
  // The target can be either side of where the last assertion left us.
  for (int i = 0; i < 30 && f.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, 300));
    await tester.pumpAndSettle();
  }
  for (int i = 0; i < 30 && f.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  expect(f, findsWidgets, reason: 'never found it after scrolling the list');
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
}

/// Reveal, then tap. Tapping a finder whose centre is off screen does NOT
/// fail in Flutter: it warns and lands nowhere, so every assertion after it
/// fails for a reason unrelated to the feature.
Future<void> revealAndTap(WidgetTester tester, Finder f) async {
  await reveal(tester, f);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// The two views added on 2026-09-22, reached by tapping rather than built.
void _roadmapAndStructure() {
  testWidgets('the Order segment shows the phases in sequence', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);
    await revealAndTap(tester, find.text('Order'));

    // Phase one is open on arrival, so the screen is never a column of shut
    // drawers with nothing to read.
    expect(find.text('Register the name and the entity'), findsOneWidget);
    expect(find.textContaining('bnrs.dti.gov.ph'), findsOneWidget);

    await reveal(tester, find.text('Protect the brand'));
  });

  testWidgets('opening another phase closes the first', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);
    await revealAndTap(tester, find.text('Order'));
    expect(find.textContaining('bnrs.dti.gov.ph'), findsOneWidget);

    await revealAndTap(tester, find.text('Protect the brand'));

    // Directional: the new one opened AND the old one shut. Asserting only
    // the first would pass on a screen that opens everything and never
    // closes anything.
    expect(find.textContaining('IPOPHL e-Search'), findsOneWidget);
    expect(find.textContaining('bnrs.dti.gov.ph'), findsNothing);
  });

  testWidgets('the DOLE deadline reads BEFORE, not after', (
    WidgetTester tester,
  ) async {
    // The inverted deadline was the worst defect the factual review found,
    // and it was in TWO places: the checklist step and phase five. This pins
    // the second one on the screen a person actually reads.
    await openChecklistFor(tester);
    await revealAndTap(tester, find.text('Order'));
    await revealAndTap(tester, find.text('Employer registrations'));
    await reveal(tester, find.textContaining('BEFORE you start operating'));

    expect(find.textContaining('within 30 days of commercial'), findsNothing);
  });

  testWidgets('the matcher says nothing until you answer question one', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);
    await revealAndTap(tester, find.text('Structure'));

    expect(find.text('Which structure fits?'), findsOneWidget);
    expect(
      find.text('CLOSEST FIT'),
      findsNothing,
      reason: 'a recommendation nobody asked for is one somebody might act on',
    );
  });

  testWidgets('answering changes what is recommended', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);
    await revealAndTap(tester, find.text('Structure'));
    await revealAndTap(tester, find.text('Just me'));

    await reveal(tester, find.text('CLOSEST FIT'));
    expect(find.text('Sole Proprietorship'), findsWidgets);

    // Changing an answer changes the answer, which is the whole point of a
    // matcher and the thing a one-shot quiz gets wrong.
    await revealAndTap(
      tester,
      find.text('My own house and savings must be safe'),
    );
    await reveal(tester, find.text('One Person Corporation (OPC)'));
  });

  testWidgets('the corrected 8% sentence is on the screen', (
    WidgetTester tester,
  ) async {
    // entity_matcher_test.dart pins the data. This pins that a person can
    // actually SEE it, which is the half this repository keeps losing.
    await openChecklistFor(tester);
    await revealAndTap(tester, find.text('Structure'));
    await revealAndTap(tester, find.text('Just me'));
    await reveal(tester, find.textContaining('gross sales above 250,000'));
  });

  testWidgets('the progress bar belongs to the checklist only', (
    WidgetTester tester,
  ) async {
    await openChecklistFor(tester);
    expect(find.textContaining('of 23 done'), findsOneWidget);

    await revealAndTap(tester, find.text('Order'));
    expect(
      find.textContaining('of 23 done'),
      findsNothing,
      reason: 'a tick count over a roadmap implies the roadmap has ticks',
    );
  });
}
