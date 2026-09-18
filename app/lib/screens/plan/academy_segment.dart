import 'package:flutter/material.dart';

import '../../data/academy_data.dart';
import '../../design/salapify_icon.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/info/info_dot.dart';
import '../../features/info/info_sheet.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../models/academy.dart';

/// Salapify Academy, from src/components/AcademyView.tsx.
///
/// It is called ACADEMY, not Learn. An earlier pass renamed it, which was not
/// mine to do: "Salapify Academy" is the product's own name for this, it is
/// on the screen in the prototype, and a rename nobody asked for is a change
/// to the brand dressed up as tidying.
///
/// The curriculum is the prototype's 32 courses, extracted from
/// src/data/academyData.ts rather than written here. The same earlier pass
/// invented six courses of its own instead of looking for the real data,
/// which is exactly the failure the "src/ is the source of truth" rule
/// exists to prevent. The generator is app/tool/gen_academy_dart.py.
class AcademySegment extends StatefulWidget {
  const AcademySegment({super.key, required this.palette});

  final Palette palette;

  @override
  State<AcademySegment> createState() => _AcademySegmentState();
}

class _AcademySegmentState extends State<AcademySegment> {
  final TextEditingController _search = TextEditingController();

  String _category = 'All';
  CourseModule? _open;

  /// Completion lives in memory, like every other write in app/ today. The
  /// screen says so rather than letting somebody build a streak and lose it.
  final Set<String> _done = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Derived from the courses rather than typed out, so a new category cannot
  /// leave a filter nobody can reach or a chip that matches nothing.
  List<String> get _categories => <String>[
    'All',
    ...<String>{for (final CourseModule c in academyCourses) c.category},
  ];

  List<CourseModule> get _shown {
    final String q = _search.text.trim().toLowerCase();
    return academyCourses.where((CourseModule c) {
      if (_category != 'All' && c.category != _category) return false;
      if (q.isEmpty) return true;
      // Title, description AND category, because somebody searching "MP2"
      // is looking for the lesson that mentions it, not only one titled it.
      return c.title.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;

    if (_open != null) {
      return _CourseDetail(
        palette: p,
        course: _open!,
        isDone: _done.contains(_open!.id),
        onToggleDone: () => setState(() {
          _done.contains(_open!.id)
              ? _done.remove(_open!.id)
              : _done.add(_open!.id);
        }),
        onBack: () => setState(() => _open = null),
      );
    }

    final List<CourseModule> shown = _shown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ProgressCard(
          palette: p,
          done: _done.length,
          total: academyCourses.length,
        ),
        const SizedBox(height: Spacing.md),
        _Disclaimer(palette: p),
        const SizedBox(height: Spacing.md),
        _StartupGuideCard(palette: p),
        const SizedBox(height: Spacing.md),

        SheetField(
          key: const Key('academy-search'),
          palette: p,
          label: 'Search',
          controller: _search,
          hint: 'Try MP2, credit cards, sweldo',
          keyboardType: TextInputType.text,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: Spacing.sm),

        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: <Widget>[
            for (final String c in _categories)
              _CategoryChip(
                palette: p,
                label: c,
                selected: c == _category,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
        const SizedBox(height: Spacing.md),

        if (shown.isEmpty)
          Text(
            'No lesson matches that. Try a shorter word, or clear the filter.',
            style: AppType.caption(p),
          )
        else
          for (final CourseModule c in shown) ...<Widget>[
            _CourseRow(
              palette: p,
              course: c,
              isDone: _done.contains(c.id),
              onTap: () => setState(() => _open = c),
            ),
            const SizedBox(height: Spacing.sm),
          ],
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.palette,
    required this.done,
    required this.total,
  });

  final Palette palette;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final double fraction = total == 0 ? 0 : done / total;

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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'FINANCIAL LITERACY TRACK',
                  style: AppType.kicker(palette),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
                child: Text(
                  '$done / $total done',
                  style: AppType.button(palette, color: palette.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Salapify Academy', style: AppType.title(palette)),
          const SizedBox(height: Spacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: palette.trackSoft,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(fraction * 100).round()}% complete · progress is not saved to '
            'the phone yet',
            style: AppType.caption(palette),
          ),
        ],
      ),
    );
  }
}

/// The prototype's own disclaimer, kept word for word in substance.
///
/// It is NOT behind the info dot, and that is the exception the dot rule
/// names: somebody who reads a lesson on investing and takes it for licensed
/// advice has drawn a wrong conclusion, and a wrong conclusion never goes one
/// tap away.
class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.palette});

  final Palette palette;

  @override
  Widget build(BuildContext context) {
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
          // Two plain Text widgets rather than one RichText. A RichText is not
          // findable by find.text, so the test that proves this notice is on
          // the screen could not see it, and a notice nothing can assert is a
          // notice that can quietly disappear.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Educational only',
                  style: AppType.caption(palette).copyWith(
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  'These lessons are general knowledge. They are not '
                  'regulated tax, legal or investment advice.',
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

class _StartupGuideCard extends StatelessWidget {
  const _StartupGuideCard({required this.palette});

  final Palette palette;

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
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'INTERACTIVE ROADMAP · PHILIPPINES',
                  style: AppType.kicker(palette),
                ),
              ),
              InfoDot(
                color: palette.textMuted,
                semanticLabel: 'What the startup guide will cover',
                onTap: () =>
                    InfoSheet.show(context, palette, InfoTopic.academy),
              ),
            ],
          ),
          Text(
            'Building a business or startup in the Philippines?',
            style: AppType.rowTitle(palette),
          ),
          const SizedBox(height: 2),
          Text(
            'Sole prop, OPC or corporation, DTI and SEC, trademarks, mayor\'s '
            'permit, BIR Form 2303, and digital compliance.',
            style: AppType.caption(palette),
          ),
          const SizedBox(height: Spacing.sm),
          // Honest rather than a dead button. The guide is about 3,200 lines
          // of written content across three files in the prototype, and a
          // button that opens nothing is worse than a line that says when.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.schedule, size: 15, color: palette.textMuted),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    'Being ported next, with the two guides behind it',
                    style: AppType.caption(palette),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.card,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: selected ? palette.accent : palette.border,
            ),
          ),
          // Row with mainAxisSize.min rather than a Container alignment: a
          // Container given an alignment and no width expands to fill, which
          // stacked the Reports period pills into a column once already.
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

class _CourseRow extends StatelessWidget {
  const _CourseRow({
    required this.palette,
    required this.course,
    required this.isDone,
    required this.onTap,
  });

  final Palette palette;
  final CourseModule course;
  final bool isDone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: course.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(
              color: isDone ? palette.positive : palette.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: palette.iconTile,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: SalapifyIcon(name: course.icon, palette: palette),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            course.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.rowTitle(palette),
                          ),
                        ),
                        if (isDone)
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: palette.positive,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption(palette),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${course.category} · ${course.durationMinutes} min',
                      style: AppType.caption(
                        palette,
                      ).copyWith(color: palette.accent),
                    ),
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

/// One lesson, opened.
class _CourseDetail extends StatefulWidget {
  const _CourseDetail({
    required this.palette,
    required this.course,
    required this.isDone,
    required this.onToggleDone,
    required this.onBack,
  });

  final Palette palette;
  final CourseModule course;
  final bool isDone;
  final VoidCallback onToggleDone;
  final VoidCallback onBack;

  @override
  State<_CourseDetail> createState() => _CourseDetailState();
}

class _CourseDetailState extends State<_CourseDetail> {
  int? _answered;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final CourseModule c = widget.course;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          button: true,
          label: 'Back to the course list',
          child: InkWell(
            onTap: widget.onBack,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.arrow_back, size: 18, color: p.accent),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    'All lessons',
                    style: AppType.button(p, color: p.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xs),

        Text(c.title, style: AppType.title(p)),
        const SizedBox(height: 2),
        Text(
          '${c.category} · ${c.durationMinutes} min read',
          style: AppType.caption(p).copyWith(color: p.accent),
        ),
        const SizedBox(height: Spacing.md),

        if (c.objectives.isNotEmpty) ...<Widget>[
          PlanCardLite(
            palette: p,
            title: 'What you will get out of this',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String o in c.objectives)
                  _Bullet(palette: p, text: o),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],

        for (final LessonSection s in c.sections) ...<Widget>[
          Text(s.title, style: AppType.section(p)),
          const SizedBox(height: Spacing.xs),
          Text(s.content, style: AppType.body(p)),
          const SizedBox(height: Spacing.md),
        ],

        if (c.keyTakeaways.isNotEmpty) ...<Widget>[
          PlanCardLite(
            palette: p,
            title: 'Worth remembering',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final String t in c.keyTakeaways)
                  _Bullet(palette: p, text: t),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],

        if (c.knowledgeCheck != null) ...<Widget>[
          _Quiz(
            palette: p,
            check: c.knowledgeCheck!,
            answered: _answered,
            onAnswer: (int i) => setState(() => _answered = i),
          ),
          const SizedBox(height: Spacing.md),
        ],

        if (c.reflectionPrompt != null) ...<Widget>[
          PlanCardLite(
            palette: p,
            title: 'Something to sit with',
            child: Text(c.reflectionPrompt!, style: AppType.body(p)),
          ),
          const SizedBox(height: Spacing.md),
        ],

        PrimaryButton(
          palette: p,
          label: widget.isDone ? 'Mark as not done' : 'Mark as done',
          icon: widget.isDone ? Icons.undo : Icons.check,
          onTap: widget.onToggleDone,
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.palette, required this.text});

  final Palette palette;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(text, style: AppType.body(palette))),
        ],
      ),
    );
  }
}

class _Quiz extends StatelessWidget {
  const _Quiz({
    required this.palette,
    required this.check,
    required this.answered,
    required this.onAnswer,
  });

  final Palette palette;
  final KnowledgeCheck check;
  final int? answered;
  final ValueChanged<int> onAnswer;

  @override
  Widget build(BuildContext context) {
    final bool done = answered != null;
    final bool right = answered == check.correctAnswerIndex;

    return PlanCardLite(
      palette: palette,
      title: 'Knowledge check',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(check.question, style: AppType.rowTitle(palette)),
          const SizedBox(height: Spacing.sm),
          for (int i = 0; i < check.options.length; i++) ...<Widget>[
            _Option(
              palette: palette,
              label: check.options[i],
              // After answering, the CORRECT one is marked whichever was
              // picked. A quiz that only says "wrong" teaches nothing.
              state: !done
                  ? _OptionState.idle
                  : i == check.correctAnswerIndex
                  ? _OptionState.correct
                  : i == answered
                  ? _OptionState.wrong
                  : _OptionState.idle,
              onTap: done ? null : () => onAnswer(i),
            ),
            const SizedBox(height: Spacing.xs),
          ],
          if (done) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(
              right ? 'That is right.' : 'Not quite.',
              style: AppType.rowTitle(
                palette,
              ).copyWith(color: right ? palette.positive : palette.warning),
            ),
            const SizedBox(height: 2),
            // Shown either way. The explanation is the point of the question.
            Text(check.explanation, style: AppType.body(palette)),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _Option extends StatelessWidget {
  const _Option({
    required this.palette,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color border = switch (state) {
      _OptionState.correct => palette.positive,
      _OptionState.wrong => palette.negative,
      _OptionState.idle => palette.border,
    };

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(color: border),
          ),
          child: Row(
            children: <Widget>[
              // An ICON as well as a colour, because a right and a wrong
              // answer separated only by red and green is indistinguishable
              // for about one man in twelve.
              if (state != _OptionState.idle)
                Padding(
                  padding: const EdgeInsets.only(right: Spacing.xs),
                  child: Icon(
                    state == _OptionState.correct ? Icons.check : Icons.close,
                    size: 15,
                    color: border,
                  ),
                ),
              Expanded(child: Text(label, style: AppType.body(palette))),
            ],
          ),
        ),
      ),
    );
  }
}

/// A plain card with a kicker. Same shape as PlanCard without the info dot,
/// which a lesson never needs.
class PlanCardLite extends StatelessWidget {
  const PlanCardLite({
    super.key,
    required this.palette,
    required this.title,
    required this.child,
  });

  final Palette palette;
  final String title;
  final Widget child;

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
          Text(title.toUpperCase(), style: AppType.kicker(palette)),
          const SizedBox(height: Spacing.sm),
          child,
        ],
      ),
    );
  }
}
