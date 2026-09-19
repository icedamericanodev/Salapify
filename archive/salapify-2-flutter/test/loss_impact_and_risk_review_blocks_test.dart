// Model and widget tests for the two interaction block kinds Money Courses
// Phase 8 ("Crypto Without the Hype") adds to
// lib/content/interaction_blocks.dart and lib/widgets/interaction_block_views.dart:
// LossImpactSimulatorBlock (Lesson 2's loss-impact simulator) and
// RiskReviewChecklistBlock (Lesson 6's Decision Lab checklist). Mirrors
// interaction_blocks_test.dart (model level) and interaction_block_views_test.dart
// (widget level), the established shape for this codebase's interaction
// block tests.
//
// Real fonts loaded per repo convention (test/screens_shot.dart): the widget
// tests here measure whether text stays on screen, so this is one of the
// tests that rule applies to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/money/interaction_completion.dart';
import 'package:salapify/money/portfolio_shock_illustration.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/interaction_block_views.dart';

import 'screens_shot.dart' show loadRealFonts;

const _narrow = Size(320, 900);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = _narrow * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LossImpactSimulatorBlock (model)', () {
    const block = LossImpactSimulatorBlock(
      blockId: 'sim-1',
      simulatorTitle: 'See a loss in pesos',
      introduction: 'Pick an amount and a scenario.',
      amountOptions: [
        LossImpactAmountOption(id: 'a5000', amountPhp: 5000, label: '₱5,000'),
        LossImpactAmountOption(
          id: 'a20000',
          amountPhp: 20000,
          label: '₱20,000',
        ),
      ],
    );

    test('exposes the shared contract fields', () {
      expect(block.prompt, block.simulatorTitle);
      expect(block.instructions, isNotEmpty);
      expect(block.requiredForCompletion, isFalse);
    });

    test('defaults to the 30, 60, 100 percent scenario set', () {
      expect(block.lossPercentOptions, [30, 60, 100]);
    });

    test('is valid with two or more amount options and at least one '
        'scenario', () {
      expect(block.isValid, isTrue);
    });

    test('a single amount option is invalid', () {
      const invalid = LossImpactSimulatorBlock(
        blockId: 'sim-2',
        simulatorTitle: 'x',
        introduction: 'x',
        amountOptions: [
          LossImpactAmountOption(id: 'only', amountPhp: 1000, label: '₱1,000'),
        ],
      );
      expect(invalid.isValid, isFalse);
    });
  });

  group('RiskReviewChecklistBlock (model)', () {
    const block = RiskReviewChecklistBlock(
      blockId: 'rrc-1',
      checklistPrompt: 'Review before acting',
      foundationCount: 2,
      items: [
        ChecklistItemDef(id: 'f1', label: 'Foundation item 1'),
        ChecklistItemDef(id: 'f2', label: 'Foundation item 2'),
        ChecklistItemDef(id: 'r1', label: 'Risk item 1'),
        ChecklistItemDef(id: 'r2', label: 'Risk item 2'),
      ],
      foundationSummary: 'Review your financial foundation first',
      partialSummary: 'Several risks still need checking',
      completeSummary: 'You have completed a risk review',
    );

    test('exposes the shared contract fields', () {
      expect(block.prompt, block.checklistPrompt);
      expect(block.instructions, isNotEmpty);
    });

    test('foundationItemIds is exactly the leading foundationCount items', () {
      expect(block.foundationItemIds, ['f1', 'f2']);
    });

    test('nothing checked reads as the foundation summary', () {
      expect(block.summaryFor(const {}), block.foundationSummary);
    });

    test('one foundation item still missing reads as the foundation '
        'summary, even if every risk item is checked', () {
      expect(
        block.summaryFor(const {'f1', 'r1', 'r2'}),
        block.foundationSummary,
      );
    });

    test('every foundation item checked but a risk item missing reads as '
        'the partial summary', () {
      expect(block.summaryFor(const {'f1', 'f2', 'r1'}), block.partialSummary);
    });

    test('every item checked reads as the complete summary', () {
      expect(
        block.summaryFor(const {'f1', 'f2', 'r1', 'r2'}),
        block.completeSummary,
      );
    });

    test('isValid requires a non-empty foundation and a non-empty '
        'remainder', () {
      expect(block.isValid, isTrue);
      const noFoundation = RiskReviewChecklistBlock(
        blockId: 'rrc-2',
        checklistPrompt: 'x',
        foundationCount: 0,
        items: [ChecklistItemDef(id: 'a', label: 'a')],
        foundationSummary: 'x',
        partialSummary: 'y',
        completeSummary: 'z',
      );
      expect(noFoundation.isValid, isFalse);
      const allFoundation = RiskReviewChecklistBlock(
        blockId: 'rrc-3',
        checklistPrompt: 'x',
        foundationCount: 2,
        items: [
          ChecklistItemDef(id: 'a', label: 'a'),
          ChecklistItemDef(id: 'b', label: 'b'),
        ],
        foundationSummary: 'x',
        partialSummary: 'y',
        completeSummary: 'z',
      );
      expect(allFoundation.isValid, isFalse);
    });
  });

  group('completion gating (money/interaction_completion.dart) reused for '
      'the new blocks', () {
    const sim = LossImpactSimulatorBlock(
      blockId: 'sim-required',
      simulatorTitle: 'x',
      introduction: 'x',
      amountOptions: [
        LossImpactAmountOption(id: 'a', amountPhp: 1000, label: 'x'),
        LossImpactAmountOption(id: 'b', amountPhp: 2000, label: 'y'),
      ],
      requiredForCompletion: true,
    );

    test('a required simulator blocks completion until fired', () {
      expect(allRequiredInteractionsComplete([sim], const {}), isFalse);
      expect(
        allRequiredInteractionsComplete([sim], const {'sim-required'}),
        isTrue,
      );
    });
  });

  group('portfolioShockImpact wiring sanity', () {
    test('the pure function used by the widget below matches its own unit '
        'tests', () {
      final result = portfolioShockImpact(
        const PortfolioShockAssumptions(
          startingAmountPhp: 20000,
          lossPercent: 60,
        ),
      );
      expect(result.amountLostPhp, 12000);
      expect(result.amountRemainingPhp, 8000);
    });
  });

  group('LossImpactSimulatorView (widget)', () {
    const block = LossImpactSimulatorBlock(
      blockId: 'sim-widget',
      simulatorTitle: 'See a sharp loss in pesos',
      introduction: 'Pick a fictional amount and a scenario.',
      amountOptions: [
        LossImpactAmountOption(id: 'a5000', amountPhp: 5000, label: '₱5,000'),
        LossImpactAmountOption(
          id: 'a20000',
          amountPhp: 20000,
          label: '₱20,000',
        ),
      ],
    );

    testWidgets('no result shown until both an amount and a scenario are '
        'picked', (tester) async {
      await _pump(tester, LossImpactSimulatorView(block, onComplete: (_) {}));
      expect(find.textContaining('Amount lost'), findsNothing);
    });

    testWidgets('picking an amount and a scenario computes the correct '
        'figures and fires onComplete once', (tester) async {
      final completed = <String>[];
      await _pump(
        tester,
        LossImpactSimulatorView(block, onComplete: completed.add),
      );
      await tester.tap(find.text('₱20,000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60 percent'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Amount lost'), findsOneWidget);
      expect(find.textContaining('12,000'), findsOneWidget);
      expect(find.textContaining('8,000'), findsOneWidget);
      expect(completed, ['sim-widget']);
    });

    testWidgets('changing the scenario after picking recomputes without '
        'firing onComplete a second time', (tester) async {
      final completed = <String>[];
      await _pump(
        tester,
        LossImpactSimulatorView(block, onComplete: completed.add),
      );
      await tester.tap(find.text('₱5,000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 percent'));
      await tester.pumpAndSettle();
      expect(completed, ['sim-widget']);

      await tester.tap(find.text('100 percent'));
      await tester.pumpAndSettle();
      expect(completed, ['sim-widget'], reason: 'fires only once');
      expect(find.textContaining('5,000'), findsWidgets);
    });

    testWidgets('the illustration disclaimer never claims to forecast or '
        'save anything', (tester) async {
      await _pump(tester, LossImpactSimulatorView(block, onComplete: (_) {}));
      await tester.tap(find.text('₱5,000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 percent'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not a forecast'), findsOneWidget);
      expect(find.textContaining('never saved'), findsOneWidget);
    });
  });

  group('RiskReviewChecklistView (widget)', () {
    const block = RiskReviewChecklistBlock(
      blockId: 'rrc-widget',
      checklistPrompt: 'Review before any money moves',
      foundationCount: 1,
      items: [
        ChecklistItemDef(id: 'foundation-1', label: 'Foundation reviewed'),
        ChecklistItemDef(id: 'risk-1', label: 'Understands total loss'),
      ],
      foundationSummary: 'Review your financial foundation first',
      partialSummary: 'Several risks still need checking',
      completeSummary: 'You have completed a risk review',
    );

    testWidgets('starts on the foundation summary', (tester) async {
      await _pump(tester, RiskReviewChecklistView(block, onComplete: (_) {}));
      expect(
        find.text('Review your financial foundation first'),
        findsOneWidget,
      );
    });

    testWidgets('checking only the risk item, not the foundation item, '
        'stays on the foundation summary', (tester) async {
      await _pump(tester, RiskReviewChecklistView(block, onComplete: (_) {}));
      await tester.tap(find.text('Understands total loss'));
      await tester.pumpAndSettle();
      expect(
        find.text('Review your financial foundation first'),
        findsOneWidget,
      );
    });

    testWidgets('checking the foundation item alone moves to the partial '
        'summary', (tester) async {
      await _pump(tester, RiskReviewChecklistView(block, onComplete: (_) {}));
      await tester.tap(find.text('Foundation reviewed'));
      await tester.pumpAndSettle();
      expect(find.text('Several risks still need checking'), findsOneWidget);
    });

    testWidgets('checking every item completes the review and fires '
        'onComplete exactly once', (tester) async {
      final completed = <String>[];
      await _pump(
        tester,
        RiskReviewChecklistView(block, onComplete: completed.add),
      );
      await tester.tap(find.text('Foundation reviewed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Understands total loss'));
      await tester.pumpAndSettle();

      expect(find.text('You have completed a risk review'), findsOneWidget);
      expect(completed, ['rrc-widget']);
    });

    testWidgets('reset clears every checked item back to the foundation '
        'summary and fires onReset', (tester) async {
      final reset = <String>[];
      await _pump(
        tester,
        RiskReviewChecklistView(block, onComplete: (_) {}, onReset: reset.add),
      );
      await tester.tap(find.text('Foundation reviewed'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Understands total loss'));
      await tester.pumpAndSettle();
      expect(reset, isEmpty);

      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(
        find.text('Review your financial foundation first'),
        findsOneWidget,
      );
      expect(reset, ['rrc-widget']);
    });

    testWidgets('the summary card never uses a banned eligibility word', (
      tester,
    ) async {
      await _pump(tester, RiskReviewChecklistView(block, onComplete: (_) {}));
      for (final w in ['Ready', 'Approved', 'Qualified', 'Suitable']) {
        expect(find.textContaining(w), findsNothing);
      }
    });
  });
}
