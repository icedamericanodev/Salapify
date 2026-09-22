// Pure-function unit tests for lib/money/interaction_completion.dart,
// separate from interaction_completion_integration_test.dart's widget-level
// end-to-end proof. This file exists to pin hasUniqueBlockIds, the guard a
// qa-tester pass found missing: without it, two different required blocks
// accidentally authored with the same blockId let completing one silently
// satisfy both, since allRequiredInteractionsComplete only ever checks a
// Set<String> of ids.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/money/interaction_completion.dart';

const _scenario = ScenarioChoiceBlock(
  blockId: 'dup-id',
  scenarioTitle: 'A scenario',
  situation: 'A situation.',
  options: [
    ScenarioChoiceOption(id: 'o1', label: 'One', explanation: 'One works.'),
    ScenarioChoiceOption(id: 'o2', label: 'Two', explanation: 'Two works.'),
  ],
  requiredForCompletion: true,
);

const _checklist = ChecklistBlock(
  blockId: 'dup-id',
  checklistPrompt: 'A checklist',
  items: [ChecklistItemDef(id: 'c1', label: 'Check this')],
  requiredForCompletion: true,
);

void main() {
  group('hasUniqueBlockIds', () {
    test('true for blocks with distinct ids', () {
      const other = ChecklistBlock(
        blockId: 'checklist-1',
        checklistPrompt: 'A checklist',
        items: [ChecklistItemDef(id: 'c1', label: 'Check this')],
      );
      expect(hasUniqueBlockIds([_scenario, other]), isTrue);
    });

    test('false when two different blocks share a blockId', () {
      expect(hasUniqueBlockIds([_scenario, _checklist]), isFalse);
    });

    test('true for an empty or single-block list', () {
      expect(hasUniqueBlockIds([]), isTrue);
      expect(hasUniqueBlockIds([_scenario]), isTrue);
    });
  });

  group('a duplicate blockId across two different required blocks silently '
      'satisfies both (the exact failure hasUniqueBlockIds exists to catch '
      'before this ever ships)', () {
    test('completing only the scenario reports the checklist complete too', () {
      expect(hasUniqueBlockIds([_scenario, _checklist]), isFalse);
      final complete = allRequiredInteractionsComplete(
        [_scenario, _checklist],
        {'dup-id'},
      );
      // This is the bug: with a shared id, one onComplete call satisfies
      // both required blocks even though the checklist was never
      // touched. allRequiredInteractionsComplete cannot see this on its
      // own; a caller must check hasUniqueBlockIds first.
      expect(complete, isTrue);
    });
  });
}
