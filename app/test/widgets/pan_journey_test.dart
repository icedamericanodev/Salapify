import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/pan/pan_engine.dart';
import 'package:salapify/core/money/pan/pan_context.dart';
import 'package:salapify/core/money/pan/pan_knowledge.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/state/financial_state.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Asking Pan, by tapping and typing, against the real ledger.
///
/// The engine tests prove the answers. This proves a person can reach them,
/// that the answer on screen is about THEIR money rather than a sample, and
/// that the two disclosures are where somebody reading an answer will see
/// them rather than in Settings, where the person reading a recommendation
/// never goes.
void main() {
  Future<FinancialState> ready() async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    return state;
  }

  Future<void> pump(WidgetTester tester, FinancialState state) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(loadRealFonts);
    await tester.pumpWidget(SalapifyApp(state: state));
    await tester.pumpAndSettle();
  }

  Future<void> openPan(WidgetTester tester) async {
    await tester.tap(find.text('Ask Pan').first);
    await tester.pumpAndSettle();
  }

  testWidgets('Pan opens and says what it is before anything is asked', (
    WidgetTester tester,
  ) async {
    await pump(tester, await ready());
    await openPan(tester);

    expect(find.textContaining('no AI model'), findsOneWidget);
    expect(
      find.text('General info, not financial advice'),
      findsOneWidget,
      reason:
          'the disclosure is not on screen at the moment somebody reads an '
          'answer, which is the only moment it does any work',
    );
    expect(find.text('Works offline'), findsOneWidget);
  });

  testWidgets('a tapped question is answered with the real ledger figure', (
    WidgetTester tester,
  ) async {
    final FinancialState state = await ready();
    await pump(tester, state);
    await openPan(tester);

    await tester.tap(find.text('How much do I have right now?'));
    await tester.pumpAndSettle();

    // Against the store, not against a literal: the point is that the answer
    // is about THIS ledger.
    final PanAnswer expected = askPan(
      'How much do I have right now?',
      state.panFacts,
    );
    expect(expected.topic, 'cash');
    expect(find.textContaining(expected.figures.first.value), findsWidgets);
  });

  testWidgets('a typed question works too, and the chips follow the answer', (
    WidgetTester tester,
  ) async {
    await pump(tester, await ready());
    await openPan(tester);

    await tester.enterText(find.byType(TextField), 'who do i owe');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    // findsWidgets, not findsOneWidget: the answer says it in the sentence
    // AND repeats it as a figure row, which is deliberate. A number inside a
    // paragraph is read; a number in a row is seen.
    expect(find.textContaining('You owe'), findsWidgets);
    expect(
      find.text('Who owes me money?'),
      findsWidgets,
      reason:
          'the follow-up chips did not change with the answer, so the screen '
          'offers the same four openers forever',
    );
  });

  testWidgets('asking what to do gets the boundary, not a confident answer', (
    WidgetTester tester,
  ) async {
    await pump(tester, await ready());
    await openPan(tester);

    await tester.enterText(
      find.byType(TextField),
      'where should i put my savings',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not something Salapify can work out'),
      findsOneWidget,
    );
    expect(
      find.textContaining(PanAnswer.trailer),
      findsOneWidget,
      reason: 'a money answer went out without the one line trailer',
    );
  });

  testWidgets('nothing Pan says is stored', (WidgetTester tester) async {
    // A question somebody typed about their own money is not something
    // Salapify needs to keep, and keeping it would leave a list of sentences
    // like "should I put my inheritance somewhere" on the phone forever.
    final MemorySnapshotStore store = MemorySnapshotStore();
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 19, 12),
      store: store,
    );
    await state.restore();
    await state.flushWrites();

    await pump(tester, state);
    await openPan(tester);
    await tester.enterText(
      find.byType(TextField),
      'should i put my inheritance in something',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    await state.flushWrites();

    expect(
      store.contents ?? '',
      isNot(contains('inheritance')),
      reason: 'what somebody asked Pan was written into their data file',
    );
  });

  group('the sweep', () {
    /// Every answer Pan can actually produce, against eight different ledgers.
    ///
    /// The source scan in pan_test.dart catches a banned word where it is
    /// written. This catches one that only appears when a particular branch
    /// runs against a particular ledger, which is the half a source scan
    /// cannot see.
    test('no answer, on any ledger, tells somebody what to do', () async {
      final List<String> imperatives = <String>[
        'you should',
        'we recommend',
        'i recommend',
        'put your money',
        'move your money',
        'invest in ',
        'best place to',
        'you must ',
      ];

      final List<FinancialState> ledgers = <FinancialState>[];
      for (final bool wiped in <bool>[false, true]) {
        final FinancialState s = FinancialState(
          clock: DateTime(2026, 9, 19, 12),
          store: MemorySnapshotStore(),
        );
        await s.restore();
        if (wiped) await s.deleteEverything();
        ledgers.add(s);
      }

      final List<String> questions = <String>[
        ...panStarters,
        'who owes me money',
        'what is my net worth',
        'how are my budgets doing',
        'when is payday',
        'should i invest in something',
        'which bank is best',
        'should i borrow money',
        'how do reminders work',
        'how do i back up my records',
        'what is reconciliation',
        'qwertyuiop',
        '',
      ];

      for (final FinancialState s in ledgers) {
        final PanFacts f = s.panFacts;
        for (final String q in questions) {
          final String said = askPan(q, f).display.toLowerCase();
          for (final String bad in imperatives) {
            expect(
              said.contains(bad),
              isFalse,
              reason: 'asking "$q" produced an instruction containing "$bad"',
            );
          }
        }
      }
    });
  });

  group('an answer can be acted on', () {
    // The prototype's chat carries deep link buttons, and three of its
    // seventeen action ids point at screens that were never built. A button
    // that renders, invites a tap and does nothing is worse than no button:
    // somebody taps it twice and decides the app is broken. So every id Pan
    // can emit is walked here.

    testWidgets('an affordability answer offers buttons that go somewhere', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await ready();
      await pump(tester, state);
      await openPan(tester);

      await tester.enterText(find.byType(TextField), 'can i afford 500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final Finder button = find.text('Inspect Safe to Spend');
      expect(button, findsOneWidget, reason: 'the answer carried no way on');

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      // Pan is gone, and the screen it pointed at is here. Both halves
      // matter: leaving Pan open would stack a sheet on a sheet, and the
      // destination arriving is the thing the button promised.
      // NOT find.text('Ask Pan'): that is also the floating button's own
      // label on Home, which never leaves, so asserting on it would pass with
      // the sheet still open. The subtitle belongs to the sheet alone.
      expect(
        find.text('Your own figures, worked out on this phone'),
        findsNothing,
        reason: 'Pan stayed open under the screen it pointed at',
      );
      expect(find.textContaining('Safe to Spend'), findsWidgets);
    });

    test('every id the engine can emit has a case in the handler', () {
      // Read from the source rather than asserted by hand, so an id added to
      // the engine without a destination reddens here instead of shipping as
      // a dead button.
      final String home = File(
        'lib/screens/home/home_screen.dart',
      ).readAsStringSync();
      for (final String id in panActionIds) {
        expect(
          home.contains("case '$id':"),
          isTrue,
          reason: 'Pan can offer "$id" and Home does not know where it goes',
        );
      }
    });
  });

  group('the card on Home', () {
    testWidgets('a chip lands on the ANSWER, not on an empty chat', (
      WidgetTester tester,
    ) async {
      // The whole reason the card carries questions. Tapping one and
      // arriving at Pan's introduction, with the question still to type,
      // would be worse than no chip: it costs a tap and delivers nothing.
      final FinancialState state = await ready();
      await pump(tester, state);

      final Finder chip = find.text('How am I doing?').first;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(
        find.text('Your own figures, worked out on this phone'),
        findsOneWidget,
        reason: 'the chip did not open Pan at all',
      );
      expect(
        find.textContaining('out of 100'),
        findsWidgets,
        reason: 'Pan opened without the question being asked',
      );
    });

    testWidgets('the card says something true about THIS ledger', (
      WidgetTester tester,
    ) async {
      // A card that prints the same sentence whatever the ledger holds is
      // decoration. This one reads the store, so the assertion is that a
      // figure from the store reaches the screen.
      final FinancialState state = await ready();
      await pump(tester, state);

      expect(find.text('Ask Pan'), findsWidgets);
      expect(
        find.textContaining(RegExp(r'₱[0-9,]+')),
        findsWidgets,
        reason: 'the card showed no figure from the ledger',
      );
    });
  });

  group('a pill is a pill, not a bar', () {
    // The sixth and seventh occurrence of the same defect in this app: a
    // Container with an alignment and no width fills every pixel it is
    // offered. Three chips became three full width bars stacked down the
    // Home card, and two action buttons became two stacked bars in a chat
    // bubble. It is invisible to find.text, which hugs the content, so it
    // has to be MEASURED against the thing around it.

    testWidgets('the chips on the Home card sit side by side', (
      WidgetTester tester,
    ) async {
      await pump(tester, await ready());

      final Finder chip = find.ancestor(
        of: find.text('How am I doing?'),
        matching: find.byType(Container),
      );
      await tester.ensureVisible(find.text('How am I doing?'));
      await tester.pumpAndSettle();

      final double chipWidth = tester.getSize(chip.first).width;
      final double screen =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;

      expect(
        chipWidth,
        lessThan(screen * 0.7),
        reason:
            'the chip is $chipWidth wide on a $screen screen, so it is a bar '
            'rather than a pill',
      );
    });

    testWidgets('an action button in a bubble does not fill the bubble', (
      WidgetTester tester,
    ) async {
      final FinancialState state = await ready();
      await pump(tester, state);
      await openPan(tester);

      await tester.enterText(find.byType(TextField), 'can i afford 500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final Finder button = find.ancestor(
        of: find.text('Log it as an expense'),
        matching: find.byType(Container),
      );
      await tester.ensureVisible(find.text('Log it as an expense'));
      await tester.pumpAndSettle();

      final double screen =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(tester.getSize(button.first).width, lessThan(screen * 0.7));
    });
  });
}
