import 'package:flutter/material.dart';

import '../../data/business_guide_data.dart';
import '../../design/salapify_icon.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../features/shared/sheet_scaffold.dart';
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
class BusinessGuideScreen extends StatefulWidget {
  const BusinessGuideScreen({super.key, required this.state, this.onBack});

  final FinancialState state;
  final VoidCallback? onBack;

  @override
  State<BusinessGuideScreen> createState() => _BusinessGuideScreenState();
}

/// The three things this guide holds, in the order somebody needs them.
///
/// Structure LAST, which is the opposite of the prototype's tab order, and it
/// is deliberate. Choosing a structure is the first decision in real life,
/// but it is not the first thing somebody opens this for: they open it asking
/// what they have to DO. The checklist answers that in one screen, so it is
/// the door, and the other two are there when the checklist raises a question
/// it cannot answer on a row.
enum _GuideView { checklist, roadmap, structure }

class _BusinessGuideScreenState extends State<BusinessGuideScreen> {
  _GuideView _view = _GuideView.checklist;

  /// null means "everything". Not stored: see the class comment.
  StepCategory? _filter;

  /// Which roadmap phase is open. One at a time, the prototype's behaviour,
  /// and phase one is open on arrival so the screen is never a column of
  /// closed drawers with nothing to read.
  int _openPhase = 1;

  /// The matcher's answers, by question key. In memory on purpose: this is a
  /// question somebody answers once while deciding, not a record of anything
  /// they did, so it has no business in the backup file.
  final Map<String, String> _answers = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);

    final int done = widget.state.guideStepsDoneAmong(businessChecklistIds);
    final int total = businessChecklist.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Header(
          palette: p,
          onBack: widget.onBack,
          done: done,
          total: total,
          // The progress bar belongs to the CHECKLIST and is hidden on the
          // other two. A bar reading "4 of 23 done" over a roadmap somebody
          // is reading rather than working through implies the roadmap has
          // steps to tick, and it does not.
          showProgress: _view == _GuideView.checklist,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            0,
            Spacing.lg,
            Spacing.md,
          ),
          child: SegmentedChoice<_GuideView>(
            palette: p,
            selected: _view,
            onSelect: (_GuideView v) => setState(() => _view = v),
            options: const <(_GuideView, String)>[
              (_GuideView.checklist, 'Checklist'),
              (_GuideView.roadmap, 'Order'),
              (_GuideView.structure, 'Structure'),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            // A key per view, so switching segments starts at the top rather
            // than keeping the scroll offset of the list you just left. Three
            // lists of very different lengths share this one ListView, and
            // without it the Structure tab opens halfway down.
            key: ValueKey<_GuideView>(_view),
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.xxl,
            ),
            children: <Widget>[
              // ON EVERY VIEW, not just the checklist. The roadmap carries
              // more dated claims than the checklist does, so the view with
              // the most to go stale is the one that must not lose the
              // warning.
              const _ConfirmBeforeFiling(),
              const SizedBox(height: Spacing.md),
              ...switch (_view) {
                _GuideView.checklist => _checklist(p),
                _GuideView.roadmap => _roadmap(p),
                _GuideView.structure => _structure(p),
              },
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _checklist(Palette p) {
    // The whole list drives PROGRESS, the filtered list drives what is drawn.
    // Counting the filtered list instead would make the bar jump to 100% the
    // moment somebody filters to a category they happen to have finished,
    // which reads as "you are done" on a screen where that is very wrong.
    final List<BusinessStep> shown = _filter == null
        ? businessChecklist
        : businessChecklist
              .where((BusinessStep s) => s.category == _filter)
              .toList(growable: false);

    return <Widget>[
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
          onTap: () => setState(() => widget.state.toggleGuideStep(step.id)),
        ),
        const SizedBox(height: Spacing.sm),
      ],
      if (shown.isEmpty)
        Text('No steps in this group.', style: AppType.caption(p)),
    ];
  }

  List<Widget> _roadmap(Palette p) => <Widget>[
    Text(
      'Several of these will not accept you without the paper from an '
      'earlier one, so the order is the point.',
      style: AppType.caption(p),
    ),
    const SizedBox(height: Spacing.md),
    for (final RoadmapPhase phase in businessRoadmap) ...<Widget>[
      _PhaseCard(
        palette: p,
        phase: phase,
        open: _openPhase == phase.number,
        onTap: () => setState(
          () => _openPhase = _openPhase == phase.number ? 0 : phase.number,
        ),
      ),
      const SizedBox(height: Spacing.sm),
    ],
  ];

  List<Widget> _structure(Palette p) {
    final EntityMatch? match = matchEntity(
      owners: _answers['owners'],
      liability: _answers['liability'],
      funding: _answers['funding'],
    );

    return <Widget>[
      _Matcher(
        palette: p,
        answers: _answers,
        onAnswer: (String key, String value) =>
            setState(() => _answers[key] = value),
      ),
      // NOTHING at all until question one is answered, which is the
      // prototype's own guard and worth keeping. A default recommendation
      // shown before anybody has said anything is a recommendation somebody
      // might act on.
      if (match != null) ...<Widget>[
        const SizedBox(height: Spacing.md),
        _MatchCard(palette: p, match: match),
      ],
      const SizedBox(height: Spacing.lg),
      Text('Compared side by side', style: AppType.section(p)),
      const SizedBox(height: Spacing.sm),
      for (final EntityCard card in businessEntities) ...<Widget>[
        _EntityPanel(palette: p, card: card),
        const SizedBox(height: Spacing.sm),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.onBack,
    required this.done,
    required this.total,
    required this.showProgress,
  });

  final Palette palette;
  final VoidCallback? onBack;
  final int done;
  final int total;

  /// The bar and its count belong to the checklist. See the call site.
  final bool showProgress;

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
          if (!showProgress) const SizedBox(height: Spacing.sm),
          if (showProgress) ...<Widget>[
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

/// One collapsible phase of the roadmap.
class _PhaseCard extends StatelessWidget {
  const _PhaseCard({
    required this.palette,
    required this.phase,
    required this.open,
    required this.onTap,
  });

  final Palette palette;
  final RoadmapPhase phase;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: open ? palette.accent : palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: <Widget>[
                    // The number, in a tile. It is the one part of a phase
                    // that has to be readable while every card is closed,
                    // because the whole point of this view is the sequence.
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.accentSoft,
                        borderRadius: BorderRadius.circular(Radii.tile),
                      ),
                      child: Text(
                        '${phase.number}',
                        style: AppType.rowTitle(
                          palette,
                        ).copyWith(color: palette.accent),
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${phase.kicker} · ${phase.agency}',
                            style: AppType.rowMeta(palette),
                          ),
                          const SizedBox(height: 2),
                          Text(phase.title, style: AppType.rowTitle(palette)),
                        ],
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    // ExcludeSemantics because the Semantics above already
                    // announces expanded state; the chevron would say it
                    // again as a meaningless icon.
                    ExcludeSemantics(
                      child: Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                0,
                Spacing.md,
                Spacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final PhaseBlock block in phase.blocks) ...<Widget>[
                    _Block(palette: palette, block: block),
                    const SizedBox(height: Spacing.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One block inside an open phase.
class _Block extends StatelessWidget {
  const _Block({required this.palette, required this.block});

  final Palette palette;
  final PhaseBlock block;

  @override
  Widget build(BuildContext context) {
    final bool tinted = block.tone != BlockTone.plain;
    final Color tint = switch (block.tone) {
      BlockTone.plain => palette.textPrimary,
      BlockTone.tip => palette.accent,
      BlockTone.caution => palette.warning,
    };

    // A TINTED panel gets the primary ink, not the muted caption colour, and
    // this is measured rather than chosen. textMuted on warningSoft comes out
    // at 4.29 to 1 in Gabi and 3.15 in Hapon, against the 4.5 floor for body
    // text; textPrimary on the same panel is 10.3 and 11.18.
    //
    // The pair is new: nothing in the app drew caption text on a warning
    // panel until this roadmap did, which is why palette_contrast_test.dart
    // did not already catch it. Both pairs are added to that sweep in the
    // same change, so the next tinted panel cannot repeat it.
    final TextStyle bodyStyle = tinted
        ? AppType.caption(palette).copyWith(color: palette.textPrimary)
        : AppType.caption(palette);

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (block.heading != null)
          Text(
            block.heading!,
            style: AppType.rowTitle(palette).copyWith(
              fontSize: 13,
              color: tinted ? tint : palette.textPrimary,
            ),
          ),
        if (block.heading != null && block.body != null)
          const SizedBox(height: 2),
        if (block.body != null) Text(block.body!, style: bodyStyle),
        for (final String bullet in block.bullets) ...<Widget>[
          const SizedBox(height: Spacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // A dot rather than a bullet glyph, because the list markers a
              // phone font ships vary and this one is drawn by us.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(bullet, style: bodyStyle)),
            ],
          ),
        ],
      ],
    );

    if (!tinted) return body;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: block.tone == BlockTone.caution
            ? palette.warningSoft
            : palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: body,
    );
  }
}

/// The three question matcher.
class _Matcher extends StatelessWidget {
  const _Matcher({
    required this.palette,
    required this.answers,
    required this.onAnswer,
  });

  final Palette palette;
  final Map<String, String> answers;
  final void Function(String key, String value) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Which structure fits?', style: AppType.rowTitle(palette)),
          const SizedBox(height: 2),
          Text(
            'Three questions. Nothing is saved and nothing is filed.',
            style: AppType.caption(palette),
          ),
          for (final EntityQuestion q in entityQuestions) ...<Widget>[
            const SizedBox(height: Spacing.md),
            Text(q.label, style: AppType.body(palette).copyWith(fontSize: 13)),
            const SizedBox(height: Spacing.sm),
            for (final (String label, String value) in q.options) ...<Widget>[
              _Answer(
                palette: palette,
                label: label,
                selected: answers[q.key] == value,
                onTap: () => onAnswer(q.key, value),
              ),
              const SizedBox(height: Spacing.xs),
            ],
          ],
        ],
      ),
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
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
      // inMutuallyExclusiveGroup, because that is what these are: picking one
      // replaces the other, and a screen reader that calls them plain buttons
      // gives no clue that answering again changes the answer.
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.accentSoft : palette.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: AppType.body(palette).copyWith(
                    fontSize: 13,
                    color: selected
                        ? palette.textPrimary
                        : palette.textSecondary,
                  ),
                ),
              ),
              if (selected)
                ExcludeSemantics(
                  child: Icon(
                    Icons.check_circle,
                    size: 18,
                    color: palette.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the matcher landed on.
class _MatchCard extends StatelessWidget {
  const _MatchCard({required this.palette, required this.match});

  final Palette palette;
  final EntityMatch match;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('CLOSEST FIT', style: AppType.kicker(palette)),
          const SizedBox(height: Spacing.xs),
          Text(match.title, style: AppType.section(palette)),
          const SizedBox(height: Spacing.xs),
          Text(match.summary, style: AppType.caption(palette)),
          for (final String reason in match.reasons) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.check, size: 15, color: palette.accent),
                const SizedBox(width: Spacing.sm),
                Expanded(child: Text(reason, style: AppType.caption(palette))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One entity on the comparison list.
class _EntityPanel extends StatelessWidget {
  const _EntityPanel({required this.palette, required this.card});

  final Palette palette;
  final EntityCard card;

  Color _toneColor(EntityTone tone) => switch (tone) {
    EntityTone.plain => palette.textPrimary,
    EntityTone.good => palette.positive,
    EntityTone.bad => palette.negative,
    EntityTone.warn => palette.warning,
    EntityTone.muted => palette.textMuted,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(card.title, style: AppType.rowTitle(palette)),
          const SizedBox(height: 2),
          Text(card.registrar, style: AppType.rowMeta(palette)),
          const SizedBox(height: Spacing.xs),
          Text(card.description, style: AppType.caption(palette)),
          const SizedBox(height: Spacing.sm),
          for (final (String label, String value, EntityTone tone)
              in card.rows) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              // A COLUMN, not a label-left value-right row. The prototype
              // puts these side by side, which works on a laptop and does not
              // here: "20% if income is 5M or less AND assets 100M or less,
              // not counting the land, else 25%" against a label leaves the
              // value about half a phone wide, and that is the single most
              // consequential sentence on the card.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label.toUpperCase(), style: AppType.kicker(palette)),
                  Text(
                    value,
                    style: AppType.caption(
                      palette,
                    ).copyWith(color: _toneColor(tone)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
