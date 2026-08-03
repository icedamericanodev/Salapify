// One widget per Phase 5 interaction block (content/interaction_blocks.dart),
// plus the one shared feedback presentation every block reuses instead of
// inventing its own "Correct / Wrong" styling.
//
// Design rule carried over from lesson_block_views.dart: a block should look
// like WHAT IT IS at a glance. Here that also means every block looks like
// something you DO, not something you read: a bordered card, a kicker naming
// the interaction, and a control that takes a real tap, keystroke, or screen
// reader action before anything is marked complete.
//
// No block ever completes itself on build. Every onComplete(blockId) call in
// this file happens inside a user gesture handler, never in build() or
// initState(), so opening or scrolling past a block can never satisfy
// InteractionBlock.requiredForCompletion (see money/interaction_completion.dart).
//
// Reuse over duplication, per this phase's own instruction: cautions reuse
// RiskWarningView, citations reuse OfficialSourceView, and the entrance
// animation reuses RiseIn, all from lesson_block_views.dart, rather than
// three near-identical copies.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../content/interaction_blocks.dart';
import '../content/lesson_blocks.dart'
    show OfficialSourceBlock, RiskWarningBlock;
import '../content/lesson_model.dart' show LessonSourceInfo;
import '../theme.dart';
import '../typography.dart';
import 'lesson_block_views.dart'
    show RiseIn, RiskWarningView, OfficialSourceView;
import 'pressable_scale.dart';
import 'salapify_icon.dart';

// ---------------------------------------------------------------------------
// 7. Shared feedback presentation.
// ---------------------------------------------------------------------------

/// What kind of response a block is giving, so the presentation (kicker,
/// icon, and wording) always matches without every block re-deciding it.
enum InteractionFeedbackKind {
  /// A well-supported response for this scenario or statement.
  wellSupported,

  /// A factual answer that was not quite right (myth/fact, sorting).
  needsAnotherLook,

  /// Neither "right" nor "wrong": the trade-offs differ and both options can
  /// be reasonable.
  tradeoff,

  /// A caution worth carrying forward, distinct from an error.
  riskWarning,
}

/// The one feedback card every interactive block reuses. Meaning is carried
/// by the kicker text and the icon shape together, never by color alone, and
/// the wording never says "Wrong", "Bad financial decision", or "You
/// failed": see the kicker and explanation strings below.
class InteractionFeedbackCard extends StatelessWidget {
  final InteractionFeedbackKind kind;
  final String explanation;

  /// Present whenever the block offers a retry; absent for a one-shot result.
  final VoidCallback? onRetry;

  const InteractionFeedbackCard({
    super.key,
    required this.kind,
    required this.explanation,
    this.onRetry,
  });

  String get _kicker => switch (kind) {
    InteractionFeedbackKind.wellSupported => 'THAT WORKS',
    InteractionFeedbackKind.needsAnotherLook => 'TAKE ANOTHER LOOK',
    InteractionFeedbackKind.tradeoff => 'TRADE-OFF',
    InteractionFeedbackKind.riskWarning => 'WORTH KNOWING',
  };

  IconData get _icon => switch (kind) {
    InteractionFeedbackKind.wellSupported => salapifyIcon('check'),
    InteractionFeedbackKind.needsAnotherLook => salapifyIcon('help'),
    InteractionFeedbackKind.tradeoff => salapifyIcon('balance'),
    InteractionFeedbackKind.riskWarning => salapifyIcon('warning'),
  };

  Color get _accent => switch (kind) {
    InteractionFeedbackKind.wellSupported => Barako.primary,
    InteractionFeedbackKind.needsAnotherLook => Barako.caramel,
    InteractionFeedbackKind.tradeoff => Barako.muted,
    InteractionFeedbackKind.riskWarning => Barako.caramel,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Semantics(
      // Announced to a screen reader the moment this card appears, since it
      // is the direct result of an action the learner just took.
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: accent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, size: 16, color: accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _kicker,
                    // Barako.kickerStyle alone hardcodes the neutral muted
                    // ink; without the accent override here the kicker
                    // stays grey while the icon and border it sits next to
                    // go caramel, reading as a missed style rather than
                    // intent.
                    style: Barako.kickerStyle.copyWith(color: accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              explanation,
              style: AppText.small.copyWith(height: 1.5, color: Barako.text),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: Icon(salapifyIcon('startOver'), size: 16),
                  label: const Text('Try again'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared shell and row widgets every block builds on.
// ---------------------------------------------------------------------------

/// The bordered card shell every interaction block shares: a kicker naming
/// the kind of interaction, the prompt as an accessible heading, the spoken
/// instructions, then the block's own controls.
class _InteractionCard extends StatelessWidget {
  final String kicker;
  final String prompt;
  final String instructions;
  final Widget child;

  const _InteractionCard({
    required this.kicker,
    required this.prompt,
    required this.instructions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Barako.border),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kicker, style: Barako.kickerStyle),
        const SizedBox(height: 8),
        Semantics(
          header: true,
          child: Text(prompt, style: AppText.bodyLg.w7.copyWith(height: 1.4)),
        ),
        const SizedBox(height: 4),
        Text(instructions, style: AppText.small.copyWith(height: 1.4)),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

/// A tappable option row used by scenario choices, myth/fact, and reflection
/// choices. Selection is carried by icon shape, border, and tint together,
/// never by color alone, and the whole row (not just the icon) is the tap
/// target, cleared to at least [kMinInteractiveDimension].
class _SelectableRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  /// Icon pair drawn for the selected/unselected state. Defaults to the
  /// choose-one radio glyphs (used by scenario, myth/fact, and reflection
  /// choices); the comparison block's single "mark as reviewed" toggle
  /// passes the checked/unchecked pair instead, since that row is an
  /// acknowledgment, not one option among alternatives, and the two
  /// meanings should never share a glyph (see salapify_icon.dart's own
  /// "selected vs checked" convention).
  final String selectedIconName;
  final String unselectedIconName;

  const _SelectableRow({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
    this.selectedIconName = 'selected',
    this.unselectedIconName = 'unselected',
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    enabled: !disabled,
    label: label,
    // The label above already carries this row's full meaning to a screen
    // reader; without this, the descendant Text below repeats the same
    // string as a second, unrelated announcement right after it.
    child: ExcludeSemantics(
      child: PressableScale(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: disabled ? null : onTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected ? Barako.primary : Barako.border,
                    width: selected ? 1.4 : 1,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: selected
                      ? Barako.primary.withValues(alpha: 0.08)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? salapifyIcon(selectedIconName)
                          : salapifyIcon(unselectedIconName),
                      size: 18,
                      color: selected ? Barako.primary : Barako.faint,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: AppText.label.copyWith(
                          height: 1.4,
                          color: disabled && !selected
                              ? Barako.faint
                              : Barako.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// [LessonSourceInfo] to [OfficialSourceBlock], reusing the exact card Phase
/// 2's OfficialSourceView already draws rather than a second citation shape.
/// A source missing any of the three required fields is dropped instead of
/// rendered half blank, the same convention blockFromMap already follows.
OfficialSourceBlock? _officialSourceBlockFrom(LessonSourceInfo? source) {
  if (source == null) return null;
  if (source.agency.trim().isEmpty ||
      source.title.trim().isEmpty ||
      source.canonicalUrl.trim().isEmpty) {
    return null;
  }
  return OfficialSourceBlock(
    agency: source.agency,
    sourceTitle: source.title,
    canonicalUrl: source.canonicalUrl,
    lastVerifiedDate: source.lastVerifiedDate,
    effectiveDate: source.effectiveDate,
    issuanceOrCircularNumber: source.issuanceOrCircularNumber,
  );
}

bool _sameOrder(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// 1. Scenario choice
// ---------------------------------------------------------------------------

class ScenarioChoiceView extends StatefulWidget {
  final ScenarioChoiceBlock block;
  final void Function(String blockId) onComplete;
  final void Function(String blockId)? onReset;

  const ScenarioChoiceView(
    this.block, {
    super.key,
    required this.onComplete,
    this.onReset,
  });

  @override
  State<ScenarioChoiceView> createState() => _ScenarioChoiceViewState();
}

class _ScenarioChoiceViewState extends State<ScenarioChoiceView> {
  String? _pickedId;

  void _pick(String id) {
    // Locks in the first tap: a second tap on a different option is a
    // change of mind after Retry, never a duplicate submission.
    if (_pickedId != null) return;
    setState(() => _pickedId = id);
    widget.onComplete(widget.block.blockId);
  }

  void _retry() {
    setState(() => _pickedId = null);
    widget.onReset?.call(widget.block.blockId);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final picked = _pickedId == null
        ? null
        : block.options.firstWhere((o) => o.id == _pickedId);
    return _InteractionCard(
      kicker: 'SCENARIO',
      prompt: block.scenarioTitle,
      instructions: block.instructions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.situation, style: AppText.body.copyWith(height: 1.5)),
          const SizedBox(height: 14),
          for (final option in block.options) ...[
            _SelectableRow(
              label: option.label,
              selected: _pickedId == option.id,
              disabled: _pickedId != null,
              onTap: () => _pick(option.id),
            ),
            const SizedBox(height: 8),
          ],
          if (picked != null) ...[
            const SizedBox(height: 6),
            RiseIn(
              child: InteractionFeedbackCard(
                kind:
                    block.preferredOptionId != null &&
                        picked.id == block.preferredOptionId
                    ? InteractionFeedbackKind.wellSupported
                    : InteractionFeedbackKind.tradeoff,
                explanation: picked.explanation,
                onRetry: _retry,
              ),
            ),
            if (block.riskNote != null) ...[
              const SizedBox(height: 10),
              RiskWarningView(block.riskNote!),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Myth or fact
// ---------------------------------------------------------------------------

class MythOrFactView extends StatefulWidget {
  final MythOrFactBlock block;
  final void Function(String blockId) onComplete;
  final void Function(String blockId)? onReset;

  const MythOrFactView(
    this.block, {
    super.key,
    required this.onComplete,
    this.onReset,
  });

  @override
  State<MythOrFactView> createState() => _MythOrFactViewState();
}

class _MythOrFactViewState extends State<MythOrFactView> {
  MythOrFactAnswer? _picked;

  void _answer(MythOrFactAnswer answer) {
    if (_picked != null) return;
    setState(() => _picked = answer);
    widget.onComplete(widget.block.blockId);
  }

  void _retry() {
    setState(() => _picked = null);
    widget.onReset?.call(widget.block.blockId);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final correct = _picked != null && _picked == block.correctAnswer;
    final source = _officialSourceBlockFrom(block.officialSource);
    return _InteractionCard(
      kicker: 'MYTH OR FACT',
      prompt: block.statement,
      instructions: block.instructions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SelectableRow(
                  label: 'Myth',
                  selected: _picked == MythOrFactAnswer.myth,
                  disabled: _picked != null,
                  onTap: () => _answer(MythOrFactAnswer.myth),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SelectableRow(
                  label: 'Fact',
                  selected: _picked == MythOrFactAnswer.fact,
                  disabled: _picked != null,
                  onTap: () => _answer(MythOrFactAnswer.fact),
                ),
              ),
            ],
          ),
          if (_picked != null) ...[
            const SizedBox(height: 12),
            RiseIn(
              child: InteractionFeedbackCard(
                kind: correct
                    ? InteractionFeedbackKind.wellSupported
                    : InteractionFeedbackKind.needsAnotherLook,
                // Always shown, whichever way the guess went.
                explanation: block.explanation,
                onRetry: _retry,
              ),
            ),
            if (source != null) ...[
              const SizedBox(height: 10),
              OfficialSourceView(source),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Comparison
// ---------------------------------------------------------------------------

class ComparisonView extends StatefulWidget {
  final ComparisonBlock block;
  final void Function(String blockId) onComplete;
  final void Function(String blockId)? onReset;

  const ComparisonView(
    this.block, {
    super.key,
    required this.onComplete,
    this.onReset,
  });

  @override
  State<ComparisonView> createState() => _ComparisonViewState();
}

class _ComparisonViewState extends State<ComparisonView> {
  bool _reviewed = false;

  void _toggleReviewed() {
    setState(() => _reviewed = !_reviewed);
    if (_reviewed) {
      widget.onComplete(widget.block.blockId);
    } else {
      widget.onReset?.call(widget.block.blockId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    return _InteractionCard(
      kicker: 'COMPARE',
      prompt: block.title,
      instructions: block.instructions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // Wrap, not a fixed grid: on a narrow phone every card is full
              // width and stacks (one column), on a wider one two columns fit
              // side by side, and neither case ever needs horizontal scroll.
              const spacing = 12.0;
              final columns = constraints.maxWidth >= 560 ? 2 : 1;
              final cardWidth = columns == 1
                  ? constraints.maxWidth
                  : (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in block.items)
                    SizedBox(
                      width: cardWidth,
                      child: _comparisonCard(block, item),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          _SelectableRow(
            label: _reviewed ? 'Marked as reviewed' : 'Mark as reviewed',
            selected: _reviewed,
            disabled: false,
            onTap: _toggleReviewed,
            // A single acknowledgment, not one option among alternatives:
            // the checked/unchecked glyph pair reads as "tick this off",
            // never as "pick me instead of the row below".
            selectedIconName: 'checked',
            unselectedIconName: 'unchecked',
          ),
        ],
      ),
    );
  }

  Widget _comparisonCard(ComparisonBlock block, ComparisonItem item) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Barako.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(item.name, style: AppText.subtitle),
            ),
            const SizedBox(height: 8),
            for (final criterion in block.criteria)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                // One merged label so a screen reader hears "Fees: Not
                // provided" rather than two separate, unrelated announcements.
                child: Semantics(
                  label: '${criterion.label}: ${item.valueFor(criterion.id)}',
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          criterion.label.toUpperCase(),
                          style: Barako.kickerStyle,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.valueFor(criterion.id),
                          style: AppText.small
                              .tint(Barako.text)
                              .copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (item.caution != null && item.caution!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              RiskWarningView(
                RiskWarningBlock(title: 'Worth knowing', text: item.caution!),
              ),
            ],
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// 4. Checklist
// ---------------------------------------------------------------------------

class ChecklistView extends StatefulWidget {
  final ChecklistBlock block;
  final void Function(String blockId) onComplete;
  final void Function(String blockId)? onReset;

  const ChecklistView(
    this.block, {
    super.key,
    required this.onComplete,
    this.onReset,
  });

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<ChecklistView> {
  final Set<String> _checked = {};
  bool _fired = false;

  bool get _isDone {
    final block = widget.block;
    final requiredIds = block.items
        .where((i) => i.required)
        .map((i) => i.id)
        .toSet();
    if (block.allRequiredMustBeChecked && requiredIds.isNotEmpty) {
      return requiredIds.every(_checked.contains);
    }
    return _checked.isNotEmpty;
  }

  void _evaluate() {
    final done = _isDone;
    if (done && !_fired) {
      _fired = true;
      widget.onComplete(widget.block.blockId);
    } else if (!done && _fired) {
      _fired = false;
      widget.onReset?.call(widget.block.blockId);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (!_checked.remove(id)) _checked.add(id);
    });
    _evaluate();
  }

  void _reset() {
    setState(() => _checked.clear());
    if (_fired) {
      _fired = false;
      widget.onReset?.call(widget.block.blockId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final requiredCount = block.items.where((i) => i.required).length;
    final checkedRequired = block.items
        .where((i) => i.required && _checked.contains(i.id))
        .length;
    final progressLabel = requiredCount > 0
        ? '$checkedRequired of $requiredCount required checked'
        : '${_checked.length} of ${block.items.length} checked';
    return _InteractionCard(
      kicker: 'CHECKLIST',
      prompt: block.checklistPrompt,
      instructions: block.instructions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in block.items) ...[
            _checklistRow(item),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(progressLabel, style: AppText.caption),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: Icon(salapifyIcon('startOver'), size: 16),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _checklistRow(ChecklistItemDef item) {
    final checked = _checked.contains(item.id);
    final explanation = (item.explanation ?? '').trim();
    // Everything the row's descendant Text widgets say, merged into one
    // label: without this, ExcludeSemantics below would silence the
    // explanation entirely rather than just de-duplicating it.
    final semanticLabel = [
      item.label,
      if (item.required) 'required',
      if (explanation.isNotEmpty) explanation,
    ].join(', ');
    return Semantics(
      checked: checked,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: PressableScale(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _toggle(item.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        checked
                            ? salapifyIcon('checked')
                            : salapifyIcon('unchecked'),
                        size: 20,
                        color: checked ? Barako.primary : Barako.faint,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Text(
                                  item.label,
                                  style: AppText.label.copyWith(height: 1.4),
                                ),
                                if (item.required)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Barako.border),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'REQUIRED',
                                      style: AppText.micro,
                                    ),
                                  ),
                              ],
                            ),
                            if (explanation.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(explanation, style: AppText.small),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Sorting / sequencing
// ---------------------------------------------------------------------------

class SortingView extends StatefulWidget {
  final SortingBlock block;
  final void Function(String blockId) onComplete;
  final void Function(String blockId)? onReset;

  const SortingView(
    this.block, {
    super.key,
    required this.onComplete,
    this.onReset,
  });

  @override
  State<SortingView> createState() => _SortingViewState();
}

class _SortingViewState extends State<SortingView> {
  late List<String> _order = widget.block.initialOrderIds;
  bool _submitted = false;
  bool _correct = false;

  SortingItemDef _itemFor(String id) =>
      widget.block.items.firstWhere((i) => i.id == id);

  void _move(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _order.length) return;
    setState(() {
      final moved = _order.removeAt(index);
      _order.insert(newIndex, moved);
      // A wrong submission left the move controls visible on purpose (see
      // _sortRow) so one bad swap can be nudged and rechecked without
      // discarding an otherwise-correct attempt back to the scrambled
      // start; moving again means the previous feedback no longer matches
      // the order on screen, so it clears until Submit is pressed again.
      if (_submitted && !_correct) {
        _submitted = false;
      }
    });
    // Reordering a list has no natural "focus followed the item" semantics,
    // so the new position is announced explicitly instead.
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${_itemFor(_order[newIndex]).label} moved to position ${newIndex + 1} of ${_order.length}',
      TextDirection.ltr,
    );
  }

  void _submit() {
    final target = widget.block.items.map((i) => i.id).toList();
    setState(() {
      _submitted = true;
      _correct = _sameOrder(_order, target);
    });
    // Completion is submitting and engaging with the exercise, not getting
    // every position right; a wrong first attempt still counts.
    widget.onComplete(widget.block.blockId);
  }

  void _retry() {
    setState(() {
      _order = widget.block.initialOrderIds;
      _submitted = false;
      _correct = false;
    });
    widget.onReset?.call(widget.block.blockId);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    final target = block.items.map((i) => i.id).toList();
    return _InteractionCard(
      kicker: 'PUT IN ORDER',
      prompt: block.sortingPrompt,
      instructions: block.instructions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < _order.length; i++) ...[
            _sortRow(i, target),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          if (!_submitted)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                ),
                child: const Text('Submit order'),
              ),
            )
          else
            RiseIn(
              child: InteractionFeedbackCard(
                kind: _correct
                    ? InteractionFeedbackKind.wellSupported
                    : InteractionFeedbackKind.needsAnotherLook,
                explanation: _correct
                    ? 'That is the order this lesson describes.'
                    : 'Not quite in order yet. Check each step against the one before it.',
                onRetry: _retry,
              ),
            ),
        ],
      ),
    );
  }

  Widget _sortRow(int index, List<String> target) {
    final id = _order[index];
    final item = _itemFor(id);
    final inRightSpot = _submitted && target[index] == id;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: !_submitted
              ? Barako.border
              : (inRightSpot ? Barako.positiveBorder : Barako.caramel),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 22),
            child: Text('${index + 1}', style: AppText.label.w7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: AppText.label.copyWith(height: 1.4)),
                if (_submitted) ...[
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        inRightSpot
                            ? salapifyIcon('done')
                            : salapifyIcon('help'),
                        size: 14,
                        color: inRightSpot ? Barako.primary : Barako.caramel,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          inRightSpot
                              ? 'In the right spot'
                              : 'Not quite, check the order again',
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                  if ((item.explanation ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.explanation!, style: AppText.small),
                  ],
                ],
              ],
            ),
          ),
          // Hidden only once the order is fully correct: there is nothing
          // left to fix. A wrong submission keeps these live so one bad
          // swap can be nudged and rechecked instead of forcing a full
          // restart back to the scrambled order (see _move and _retry).
          if (!(_submitted && _correct)) ...[
            _moveButton(
              icon: 'moveUp',
              enabled: index > 0,
              onTap: () => _move(index, -1),
              label: 'Move ${item.label} up',
            ),
            _moveButton(
              icon: 'moveDown',
              enabled: index < _order.length - 1,
              onTap: () => _move(index, 1),
              label: 'Move ${item.label} down',
            ),
          ],
        ],
      ),
    );
  }

  Widget _moveButton({
    required String icon,
    required bool enabled,
    required VoidCallback onTap,
    required String label,
  }) => Semantics(
    label: label,
    button: true,
    enabled: enabled,
    child: IconButton(
      onPressed: enabled ? onTap : null,
      icon: Icon(salapifyIcon(icon), size: 20),
      constraints: const BoxConstraints(
        minWidth: kMinInteractiveDimension,
        minHeight: kMinInteractiveDimension,
      ),
      color: Barako.text,
    ),
  );
}

// ---------------------------------------------------------------------------
// 6. Reflection
// ---------------------------------------------------------------------------

class ReflectionPromptView extends StatefulWidget {
  final ReflectionPromptBlock block;
  final void Function(String blockId) onComplete;
  final void Function(String blockId)? onReset;

  const ReflectionPromptView(
    this.block, {
    super.key,
    required this.onComplete,
    this.onReset,
  });

  @override
  State<ReflectionPromptView> createState() => _ReflectionPromptViewState();
}

class _ReflectionPromptViewState extends State<ReflectionPromptView> {
  String? _pickedChoiceId;
  bool _engaged = false;
  bool _skipped = false;
  final _controller = TextEditingController();

  @override
  void dispose() {
    // The typed text dies here. Nothing in this file ever reads
    // _controller.text outside this widget, and no callback here carries it
    // out: onComplete only ever passes the block's id.
    _controller.dispose();
    super.dispose();
  }

  void _engage() {
    if (_engaged) return;
    _engaged = true;
    widget.onComplete(widget.block.blockId);
  }

  void _pickChoice(String id) {
    setState(() => _pickedChoiceId = id);
    _engage();
  }

  void _submitFreeText() => _engage();

  void _skip() => setState(() => _skipped = true);

  void _reset() {
    setState(() {
      _pickedChoiceId = null;
      _engaged = false;
      _skipped = false;
      _controller.clear();
    });
    widget.onReset?.call(widget.block.blockId);
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    if (_skipped) {
      return _InteractionCard(
        kicker: 'REFLECT',
        prompt: block.question,
        instructions: block.instructions,
        child: Row(
          children: [
            Icon(salapifyIcon('done'), size: 16, color: Barako.faint),
            const SizedBox(width: 8),
            Expanded(child: Text('Skipped for now.', style: AppText.small)),
            TextButton(onPressed: _reset, child: const Text('Undo')),
          ],
        ),
      );
    }
    return _InteractionCard(
      kicker: 'REFLECT',
      prompt: block.question,
      instructions: block.instructions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final choice in block.choices) ...[
            _SelectableRow(
              label: choice.label,
              selected: _pickedChoiceId == choice.id,
              disabled: false,
              onTap: () => _pickChoice(choice.id),
            ),
            const SizedBox(height: 8),
          ],
          if (block.allowFreeText) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Write a thought, or leave this blank',
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(salapifyIcon('protected'), size: 14, color: Barako.faint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(block.privacyNote, style: AppText.caption),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _submitFreeText,
                child: const Text('Done'),
              ),
            ),
          ],
          if (block.choices.isEmpty && !block.allowFreeText)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _engage,
                child: const Text("I've thought about this"),
              ),
            ),
          if (_engaged) ...[
            const SizedBox(height: 10),
            // Every other block shows a result the moment it registers;
            // without this, picking a choice or submitting free text here
            // left no visible sign anything had happened at all.
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(salapifyIcon('check'), size: 16, color: Barako.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Thanks, noted.',
                      style: AppText.small.copyWith(color: Barako.text),
                    ),
                  ),
                  TextButton(onPressed: _reset, child: const Text('Reset')),
                ],
              ),
            ),
          ] else if (block.isSkippable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _skip, child: const Text('Skip')),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dispatcher.
// ---------------------------------------------------------------------------

/// The one dispatcher for interaction blocks, the equivalent of
/// lesson_block_views.dart's viewForBlock. Sealed blocks mean a new kind is a
/// compile error here until it has a view.
///
/// [onComplete] fires exactly once per completed interaction, from inside a
/// real user gesture; [onReset] (optional) fires when a block that had
/// completed is put back to its start state, so a caller tracking a
/// completed-block-id set (see money/interaction_completion.dart) can remove
/// it again.
Widget viewForInteractionBlock(
  InteractionBlock block, {
  required void Function(String blockId) onComplete,
  void Function(String blockId)? onReset,
}) => switch (block) {
  ScenarioChoiceBlock() => ScenarioChoiceView(
    block,
    onComplete: onComplete,
    onReset: onReset,
  ),
  MythOrFactBlock() => MythOrFactView(
    block,
    onComplete: onComplete,
    onReset: onReset,
  ),
  ComparisonBlock() => ComparisonView(
    block,
    onComplete: onComplete,
    onReset: onReset,
  ),
  ChecklistBlock() => ChecklistView(
    block,
    onComplete: onComplete,
    onReset: onReset,
  ),
  SortingBlock() => SortingView(
    block,
    onComplete: onComplete,
    onReset: onReset,
  ),
  ReflectionPromptBlock() => ReflectionPromptView(
    block,
    onComplete: onComplete,
    onReset: onReset,
  ),
};
