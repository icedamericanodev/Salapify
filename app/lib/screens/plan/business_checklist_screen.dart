import 'package:flutter/material.dart';

import '../../data/business_guide_data.dart';
import '../../design/salapify_icon.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../state/financial_state.dart';

/// Registering a business in the Philippines, as a checklist you can tick.
///
/// Ported from `src/components/PHBusinessStartupGuide.tsx`, the `checklist`
/// tab, on founder direction 2026-09-22. The card on the Academy tab had been
/// promising this ("Being ported next, with the two guides behind it").
///
/// ## The tick is the feature
///
/// Twenty three government steps take weeks of real life to work through.
/// Somebody opens this on a Tuesday, gets their barangay clearance on the
/// Thursday, and comes back the following month. A checklist that forgets
/// what they did is a worse version of a printed list, because at least paper
/// keeps a pencil mark.
///
/// So the ticks are STORED, and stored in the backup, on founder direction.
/// The mechanism is [FinancialState.toggleGuideStep] and the round trip is
/// held by `test/data/guide_steps_test.dart`. This screen owns no state of
/// its own except which filter chip is selected, which is deliberately NOT
/// stored: a filter is where you are looking right now, not something you did.
class BusinessChecklistScreen extends StatefulWidget {
  const BusinessChecklistScreen({super.key, required this.state, this.onBack});

  final FinancialState state;
  final VoidCallback? onBack;

  @override
  State<BusinessChecklistScreen> createState() =>
      _BusinessChecklistScreenState();
}

class _BusinessChecklistScreenState extends State<BusinessChecklistScreen> {
  /// null means "everything". Not stored: see the class comment.
  StepCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);

    // The whole list drives PROGRESS, the filtered list drives what is drawn.
    // Counting the filtered list instead would make the bar jump to 100% the
    // moment somebody filters to a category they happen to have finished,
    // which reads as "you are done" on a screen where that is very wrong.
    final int done = widget.state.guideStepsDoneAmong(businessChecklistIds);
    final int total = businessChecklist.length;

    final List<BusinessStep> shown = _filter == null
        ? businessChecklist
        : businessChecklist
              .where((BusinessStep s) => s.category == _filter)
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Header(palette: p, onBack: widget.onBack, done: done, total: total),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.xxl,
            ),
            children: <Widget>[
              const _ConfirmBeforeFiling(),
              const SizedBox(height: Spacing.md),
              _Filters(
                palette: p,
                current: _filter,
                onSelect: (StepCategory? c) => setState(() => _filter = c),
              ),
              const SizedBox(height: Spacing.md),
              for (final BusinessStep step in shown) ...<Widget>[
                _StepRow(
                  palette: p,
                  step: step,
                  done: widget.state.isGuideStepDone(step.id),
                  // setState as well as the store's own notify, because this
                  // screen is pushed over the shell rather than built by it,
                  // so it is not inside the ListenableBuilder that redraws the
                  // tabs. Without it the box stays unticked until you leave
                  // and come back, which reads exactly like a tap that did
                  // not save.
                  onTap: () =>
                      setState(() => widget.state.toggleGuideStep(step.id)),
                ),
                const SizedBox(height: Spacing.sm),
              ],
              if (shown.isEmpty)
                Text('No steps in this group.', style: AppType.caption(p)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.onBack,
    required this.done,
    required this.total,
  });

  final Palette palette;
  final VoidCallback? onBack;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (onBack != null)
                IconButton(
                  // 44dp of tappable area, not just the glyph.
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  icon: Icon(Icons.arrow_back, color: palette.textPrimary),
                  onPressed: onBack,
                  tooltip: 'Back',
                ),
              Expanded(
                child: Text(
                  'Registering a business',
                  style: AppType.title(palette),
                ),
              ),
              InfoDot(
                color: palette.textMuted,
                semanticLabel: 'What this checklist is and is not',
                onTap: () => InfoSheet.show(
                  context,
                  palette,
                  InfoTopic.businessChecklist,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 6,
              backgroundColor: palette.trackSoft,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // A COUNT, not a percentage, and the count is the honest one.
            // "30% complete" on a list where one step is a trademark filing
            // and another is a barangay visit implies the steps are the same
            // size, and they are nothing like it.
            //
            // "saved on this phone" is here because the Academy card two taps
            // away says progress is NOT saved, and a person who read that
            // sentence has no reason to believe these ticks will last.
            '$done of $total done · saved on this phone',
            style: AppType.caption(palette),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.palette,
    required this.current,
    required this.onSelect,
  });

  final Palette palette;
  final StepCategory? current;
  final ValueChanged<StepCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    // WRAPS rather than scrolls sideways. Six chips do not fit on one line of
    // a 390dp phone and they fit on even less of one at a large font size, and
    // a horizontal scroller hides the chips off the right edge with nothing
    // to say they are there.
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: <Widget>[
        _Chip(
          palette: palette,
          label: 'All ${businessChecklist.length}',
          selected: current == null,
          onTap: () => onSelect(null),
        ),
        for (final StepCategory c in StepCategory.values)
          _Chip(
            palette: palette,
            label: c.label,
            selected: current == c,
            onTap: () => onSelect(c),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          // NO `alignment:` here, and this is not a style preference. A
          // Container given an alignment and no width EXPANDS TO FILL, so
          // every chip became full width and the six of them ran down the
          // screen as a column instead of wrapping into two lines.
          //
          // _CategoryChip in academy_segment.dart carries a comment saying
          // exactly this, about the Reports period pills doing it once
          // already. It was read during this port and the alignment was added
          // anyway. The render is what caught it; no test in the suite calls
          // a column of chips a failure, because nothing overflows and
          // nothing is truncated. It just looks broken.
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.card,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: AppType.button(
                  palette,
                  color: selected ? palette.onAccent : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.palette,
    required this.step,
    required this.done,
    required this.onTap,
  });

  final Palette palette;
  final BusinessStep step;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // A checkbox, announced as one. Without this it reads as a button and a
      // screen reader user has no way to hear which steps are already done.
      checked: done,
      button: true,
      label: '${step.title}. ${step.agency}. ${step.importance.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: done ? palette.accent : palette.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Hidden from the screen reader, because the Semantics above
              // already announces the checked state. Without this it is
              // announced twice.
              ExcludeSemantics(
                child: Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: done ? palette.accent : palette.textMuted,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      step.title,
                      style: AppType.rowTitle(palette).copyWith(
                        // NOT struck through. A line through twenty three
                        // rows of government steps makes the finished half of
                        // the list unreadable, and this is a reference people
                        // come back to, not a shopping list they throw away.
                        color: done ? palette.textMuted : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        SalapifyIcon(
                          name: step.category.icon,
                          palette: palette,
                          size: 13,
                          color: palette.textMuted,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Expanded(
                          child: Text(
                            step.agency,
                            style: AppType.rowMeta(palette),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(step.description, style: AppType.caption(palette)),
                    if (step.importance !=
                        StepImportance.mandatory) ...<Widget>[
                      const SizedBox(height: Spacing.sm),
                      _ImportanceTag(
                        palette: palette,
                        importance: step.importance,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tag on a step that is NOT simply required.
///
/// Only the exceptions are tagged. Nineteen of the twenty three steps are
/// mandatory, so a tag on every row would be twenty three copies of the same
/// word and the four that actually differ would disappear into them.
class _ImportanceTag extends StatelessWidget {
  const _ImportanceTag({required this.palette, required this.importance});

  final Palette palette;
  final StepImportance importance;

  @override
  Widget build(BuildContext context) {
    final Color tint = importance == StepImportance.conditional
        ? palette.warning
        : palette.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: importance == StepImportance.conditional
            ? palette.warningSoft
            : palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(
        importance.label,
        style: AppType.rowMeta(
          palette,
        ).copyWith(color: tint, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// ON THE SCREEN, not behind the dot, and that is the founder's own rule
/// applied rather than bent.
///
/// The rule says a figure and the one line needed to READ it stay on screen,
/// and everything that TEACHES goes behind the dot. It has one exception:
/// anything somebody needs in order to avoid a WRONG CONCLUSION stays put,
/// however long, because the test is not length, it is whether silence would
/// mislead.
///
/// This is that exception. Twenty three steps written in confident, specific
/// language, naming forms and agencies, read as a definitive list of what the
/// law requires today. Some of it WILL be out of date, the prototype's own
/// header said so ("Laws, municipal ordinances, BIR tax regulations ... and
/// agency filing procedures change frequently"), and the cost of a reader
/// believing a stale requirement is a rejected filing or a penalty, which is
/// not a cost a tap can undo.
///
/// The first version of this port put exactly this warning behind the info
/// dot, which is where it does the least good: a dot is read once by the
/// curious and never by the person in a hurry with a form in front of them.
class _ConfirmBeforeFiling extends StatelessWidget {
  const _ConfirmBeforeFiling();

  @override
  Widget build(BuildContext context) {
    // Reads the palette rather than taking it, so the banner cannot be pasted
    // somewhere that hands it the wrong theme.
    final Palette palette = Palette.of(
      Theme.of(context).brightness == Brightness.dark
          ? ThemeMode2.gabi
          : ThemeMode2.hapon,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 16, color: palette.warning),
          const SizedBox(width: Spacing.sm),
          // Two plain Texts rather than one RichText, the same reason
          // _Disclaimer in academy_segment.dart gives: a RichText is not
          // findable by find.text, so a notice built that way cannot be
          // asserted, and a notice nothing can assert can quietly vanish.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Confirm before you file',
                  style: AppType.caption(palette).copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  // The DATE earns its place here and is not decoration.
                  // Everything on this screen is live-law content that rots,
                  // and the 2026-09-22 review found one line already stale
                  // from a 2024 Act. Without a date a reader in 2028 has no
                  // way to tell how old any of it is, and the rest of this
                  // sentence would be reassuring them about a list nobody had
                  // looked at in two years.
                  'Fees, forms and requirements change, and differ by city and '
                  'by industry. Checked against BIR and agency rules in '
                  'September 2026. Use this to know what to ask about, then '
                  'check with the agency or an accountant.',
                  style: AppType.caption(palette),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
