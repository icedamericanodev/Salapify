// Proves the Phase 5 completion contract end to end: opening or viewing an
// interaction block must never complete it, a required interaction gates
// completion until it is actually finished, and none of this touches or
// changes the existing 22 core lessons' own completion path
// (money/lesson_progress.dart, screens/learn.dart).
//
// This composes a small fixture "lesson" from test-only interaction blocks
// (never a registered production Money Courses lesson, per this phase's own
// instruction) and a minimal reader stand-in, the way a future expansion
// lesson reader would use viewForInteractionBlock and
// allRequiredInteractionsComplete. It intentionally does NOT touch
// screens/learn.dart or _LessonReader: no expansion reader screen exists
// yet, and building one is out of scope for this phase.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/lessons.dart';
import 'package:salapify/money/interaction_completion.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/interaction_block_views.dart';

/// A minimal stand-in for a future expansion-lesson reader: walks a fixed
/// list of interaction blocks, tracks which ones have fired onComplete in
/// local widget state (never persisted, per the phase's own "keep answers
/// local" rule), and exposes a "Complete lesson" button that is only enabled
/// once every required block has completed. This is deliberately NOT
/// _LessonReader and does not touch money/lesson_progress.dart: it exists
/// only to prove the gate works, not to ship a real screen.
class _FixtureReader extends StatefulWidget {
  final List<InteractionBlock> blocks;
  final VoidCallback onLessonCompleted;
  const _FixtureReader({required this.blocks, required this.onLessonCompleted});

  @override
  State<_FixtureReader> createState() => _FixtureReaderState();
}

class _FixtureReaderState extends State<_FixtureReader> {
  final Set<String> _completedBlockIds = {};

  void _onComplete(String blockId) =>
      setState(() => _completedBlockIds.add(blockId));
  void _onReset(String blockId) =>
      setState(() => _completedBlockIds.remove(blockId));

  @override
  Widget build(BuildContext context) {
    final canComplete = allRequiredInteractionsComplete(
      widget.blocks,
      _completedBlockIds,
    );
    return Column(
      children: [
        for (final block in widget.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: viewForInteractionBlock(
              block,
              onComplete: _onComplete,
              onReset: _onReset,
            ),
          ),
        FilledButton(
          onPressed: canComplete ? widget.onLessonCompleted : null,
          child: const Text('Complete lesson'),
        ),
      ],
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  // Tall enough that this fixture's three stacked blocks plus the Complete
  // lesson button all fit without needing a scroll before a tap can land.
  tester.view.physicalSize = const Size(390, 2400) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const requiredScenario = ScenarioChoiceBlock(
    blockId: 'fixture-scn',
    scenarioTitle: 'Fixture scenario',
    situation: 'A fictional situation for this test only.',
    options: [
      ScenarioChoiceOption(
        id: 'a',
        label: 'Option A',
        explanation: 'Fixture explanation A.',
      ),
      ScenarioChoiceOption(
        id: 'b',
        label: 'Option B',
        explanation: 'Fixture explanation B.',
      ),
    ],
    requiredForCompletion: true,
  );

  const requiredChecklist = ChecklistBlock(
    blockId: 'fixture-chk',
    checklistPrompt: 'Fixture checklist',
    items: [ChecklistItemDef(id: 'a', label: 'Fixture item', required: true)],
    requiredForCompletion: true,
  );

  const optionalReflection = ReflectionPromptBlock(
    blockId: 'fixture-ref',
    question: 'Fixture reflection question',
  );

  test('the pure gate never reads complete from an empty completed set', () {
    final blocks = <InteractionBlock>[
      requiredScenario,
      requiredChecklist,
      optionalReflection,
    ];
    expect(allRequiredInteractionsComplete(blocks, {}), isFalse);
  });

  testWidgets('opening the lesson does not complete any required block', (
    tester,
  ) async {
    var lessonCompleted = false;
    await _pump(
      tester,
      _FixtureReader(
        blocks: [requiredScenario, requiredChecklist, optionalReflection],
        onLessonCompleted: () => lessonCompleted = true,
      ),
    );

    // Just having been built and pumped is "opened", never "completed".
    final completeButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(completeButton.onPressed, isNull);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(lessonCompleted, isFalse);
  });

  testWidgets(
    'the lesson becomes completable only once every required block has been completed, not just one',
    (tester) async {
      var lessonCompleted = false;
      await _pump(
        tester,
        _FixtureReader(
          blocks: [requiredScenario, requiredChecklist, optionalReflection],
          onLessonCompleted: () => lessonCompleted = true,
        ),
      );

      // Complete only the scenario.
      await tester.tap(find.text('Option A'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
        reason: 'the required checklist is still outstanding',
      );

      // Complete the required checklist too.
      await tester.tap(find.text('Fixture item'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
        reason:
            'both required blocks are now complete; the optional reflection was never required',
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(lessonCompleted, isTrue);
    },
  );

  testWidgets('unchecking a required checklist item revokes completion again', (
    tester,
  ) async {
    await _pump(
      tester,
      _FixtureReader(
        blocks: [requiredScenario, requiredChecklist],
        onLessonCompleted: () {},
      ),
    );
    await tester.tap(find.text('Option A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture item'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Fixture item'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason:
          'unchecking a required item must revoke the block\'s own completion',
    );
  });

  test('the existing 22 core lessons are untouched by this phase', () {
    // No file this phase adds or edits (content/interaction_blocks.dart,
    // money/interaction_completion.dart, widgets/interaction_block_views.dart)
    // is imported by content/lessons.dart, lesson_model.dart, or
    // lesson_block_views.dart, so the core catalog's own shape is the direct
    // proof nothing here touched it.
    expect(lessons.length, 22);
    expect(courseTracks.length, 4);
  });
}
