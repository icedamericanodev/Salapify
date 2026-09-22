// Completion gating for the Phase 5 interaction blocks
// (content/interaction_blocks.dart). Pure Dart, no Flutter import, no system
// clock read, matching the discipline the rest of lib/money already follows
// (lesson_progress.dart, expansion_progress.dart).
//
// This is deliberately small and does NOT touch lesson_progress.dart or
// expansion_progress.dart: it never reads or writes settings.lessonProgress
// or settings.expansionProgress, and it invents no new LessonState. It only
// answers one question, "have the required blocks in this list each fired
// their own completion", so a future expansion-lesson reader can decide
// whether to allow marking a lesson complete. Whatever that reader does with
// the answer (write a LessonState, gate a button) is its own concern, not
// this file's; folding that in here would be exactly the competing progress
// engine the phase's own rules forbid.
//
// completedBlockIds is supplied by the caller (kept in the reader's own
// widget state, per the phase's "keep answers local to the lesson session"
// rule) rather than owned here, so this file never needs Flutter's
// StatefulWidget machinery to do its job.

import '../content/interaction_blocks.dart';

/// Every block in [blocks] that opts into requiredForCompletion, in order.
List<InteractionBlock> requiredInteractionBlocks(
  List<InteractionBlock> blocks,
) => blocks.where((b) => b.requiredForCompletion).toList();

/// True when every block in [blocks] has a blockId not shared by any other
/// block in the same list. [allRequiredInteractionsComplete] keys its
/// completed set by blockId (see InteractionBlock.blockId's own "unique by
/// convention" contract), so two different required blocks accidentally
/// authored with the same id would let completing one silently satisfy both.
/// A future reader assembling blocks for a lesson should check this once,
/// the same way SortingBlock.isValid checks its own items for duplicate ids.
bool hasUniqueBlockIds(List<InteractionBlock> blocks) =>
    blocks.map((b) => b.blockId).toSet().length == blocks.length;

/// True once every block in [blocks] that requires completion has its id in
/// [completedBlockIds]. A block that is present but not required is ignored.
///
/// Viewing a block never adds it to [completedBlockIds] on its own: only a
/// block's own view calling its onComplete callback does (see
/// widgets/interaction_block_views.dart), so this can never read as complete
/// purely because the lesson was opened or scrolled through.
///
/// Assumes [hasUniqueBlockIds] holds for [blocks]; a duplicate id makes the
/// underlying [completedBlockIds] set unable to tell the two blocks apart,
/// so a caller should validate uniqueness once before relying on this.
bool allRequiredInteractionsComplete(
  List<InteractionBlock> blocks,
  Set<String> completedBlockIds,
) => requiredInteractionBlocks(
  blocks,
).every((b) => completedBlockIds.contains(b.blockId));

/// Required blocks not yet in [completedBlockIds], in order, for a progress
/// indicator ("2 of 3 required interactions completed") or for pointing a
/// learner at what is left.
List<InteractionBlock> outstandingRequiredInteractions(
  List<InteractionBlock> blocks,
  Set<String> completedBlockIds,
) => requiredInteractionBlocks(
  blocks,
).where((b) => !completedBlockIds.contains(b.blockId)).toList();
