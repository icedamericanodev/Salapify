// A learning path, and one of its courses, each on its own screen.
//
// This replaces the expand-in-place accordion on the Learn hub. Tapping
// "All lessons" on Grow Your Money used to inject about thirty two-line rows
// into the middle of the hub's scroll: the collapse control scrolled away
// from under the reader, the scroll position jumped when it closed, and
// there was no way to reach one course at all. A learner could not open
// "Crypto Without the Hype"; they could only open the whole path blob and
// hunt. The experience audit filed it as H3, noting the pattern was fine at
// six rows and broken at thirty.
//
// So the catalog now nests the way a learner already thinks about it: path,
// then course, then lesson. Each screen shows at most a handful of things.
//
// The core four tracks deliberately keep their inline expansion on the hub.
// Six lessons in a card is exactly the size that pattern was right for, and
// pushing a screen for six rows would be ceremony.

import 'package:flutter/material.dart';

import '../content/course_sequences.dart';
import '../content/expansion_display.dart';
import '../content/learning_path.dart';
import '../content/learning_paths.dart';
import '../content/lesson_model.dart';
import '../data/store.dart';
import '../money/lesson_flow.dart';
import '../money/lesson_progress.dart';
import '../money/reading_time.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/progress_bar.dart';
import '../widgets/salapify_icon.dart';

const TextStyle _actionTextStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
);

/// One path's courses.
class PathScreen extends StatelessWidget {
  final LearningPath path;
  final SalapifyStore store;

  /// Opens a lesson. Supplied by the hub so this screen never has to know
  /// which reader is current, which is what kept the paged-reader switch in
  /// Phase 3 to a single call site.
  final void Function(BuildContext, String pathId, MoneyLesson) onOpenLesson;

  const PathScreen({
    super.key,
    required this.path,
    required this.store,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          path.title,
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final progress = store.expansionProgressFor(path.id);
            final sequence = expansionFlowSequence(path);
            final courses = courseProgress(sequence, progress);
            final lessonsById = {
              for (final l in lessonsForPath(path.id)) l.id: l,
            };
            final doneCourses = courses.where((c) => c.isComplete).length;
            final focus = focusCourseId(courses);
            // Grow leads with the mainstream three and tucks the two technical
            // courses (government securities, crypto) behind a "Go deeper"
            // disclosure, so the five never sit at equal priority (C1B). Every
            // other path shows its courses in order, unchanged.
            final mainstream = [
              for (final c in courses)
                if (!isAdvancedGrowGroup(c.groupId)) c,
            ];
            final advanced = [
              for (final c in courses)
                if (isAdvancedGrowGroup(c.groupId)) c,
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  path.shortDescription,
                  style: AppText.body.tint(Barako.muted).copyWith(height: 1.45),
                ),
                const SizedBox(height: 14),
                Text(
                  '$doneCourses of ${courses.length} courses done',
                  style: AppText.smallStrong,
                ),
                const SizedBox(height: 18),
                for (final c in mainstream) ...[
                  _courseCard(
                    context,
                    c,
                    lessonsById,
                    isFocus: c.groupId == focus,
                  ),
                  const SizedBox(height: 10),
                ],
                if (advanced.isNotEmpty)
                  _GoDeeperSection(
                    courses: advanced,
                    focus: focus,
                    buildCard: (c) => _courseCard(
                      context,
                      c,
                      lessonsById,
                      isFocus: c.groupId == focus,
                      note: advancedGrowNote(c.groupId),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// [isFocus] marks the one course carrying the filled accent button. Every
  /// other card gets an outlined one: still a real tap target, still labelled
  /// with what it does, just not competing for the eye.
  Widget _courseCard(
    BuildContext context,
    CourseProgress c,
    Map<String, MoneyLesson> lessonsById, {
    required bool isFocus,
    // A one-line difficulty note for the advanced Grow courses, deliberately
    // different per course so crypto and government securities never read as
    // sharing a risk profile (C1B, STEP 5). Null for every ordinary course.
    String? note,
  }) {
    final next = c.nextLessonId;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Barako.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CourseScreen(
              path: path,
              groupId: c.groupId,
              store: store,
              onOpenLesson: onOpenLesson,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(c.groupTitle, style: AppText.subtitle)),
                  if (c.isComplete)
                    Icon(
                      salapifyIcon('selected'),
                      size: 18,
                      color: Barako.primary,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SalapifyProgressBar(
                value: c.total == 0 ? 0 : c.done / c.total,
                size: ProgressBarSize.micro,
                semanticsLabel: '${c.groupTitle} progress',
                color: c.isComplete ? Barako.celebrate : Barako.primary,
              ),
              const SizedBox(height: 8),
              Text(
                '${c.done} of ${c.total} lessons',
                style: AppText.caption.w7.tint(
                  c.isComplete ? Barako.primaryText : Barako.muted,
                ),
              ),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(
                  note,
                  style: AppText.caption.tint(Barako.faint).copyWith(
                    height: 1.35,
                  ),
                ),
              ],
              if (next != null && lessonsById[next] != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: isFocus
                      ? FilledButton(
                          onPressed: () => onOpenLesson(
                            context,
                            path.id,
                            lessonsById[next]!,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Barako.primary,
                            foregroundColor: Barako.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(c.actionLabel, style: _actionTextStyle),
                        )
                      : OutlinedButton(
                          onPressed: () => onOpenLesson(
                            context,
                            path.id,
                            lessonsById[next]!,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Barako.primaryText,
                            side: BorderSide(color: Barako.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(c.actionLabel, style: _actionTextStyle),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The "Go deeper" disclosure inside Grow, holding the advanced courses
/// (government securities, crypto) below the mainstream three.
///
/// Collapsed by default, so the default Grow view is the three mainstream
/// courses and the two technical ones are exposed on a tap. That is the
/// progressive disclosure the C1B brief asks for: the hierarchy carries the
/// difficulty, no separate top-level category does, and both courses stay
/// inside Grow. It is stateful only for the open/closed toggle; it holds no
/// progress or content of its own.
class _GoDeeperSection extends StatefulWidget {
  final List<CourseProgress> courses;
  final String? focus;
  final Widget Function(CourseProgress) buildCard;

  const _GoDeeperSection({
    required this.courses,
    required this.focus,
    required this.buildCard,
  });

  @override
  State<_GoDeeperSection> createState() => _GoDeeperSectionState();
}

class _GoDeeperSectionState extends State<_GoDeeperSection> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    // If the learner is already mid-way through one of the advanced courses,
    // open the section so their in-progress course is not hidden behind a
    // tap. A fresh visitor still meets it collapsed.
    _open = widget.courses.any((c) => c.groupId == widget.focus && c.isStarted);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Semantics(
          button: true,
          expanded: _open,
          label:
              'Go deeper. Advanced topics, optional. '
              '${widget.courses.length} more courses. '
              '${_open ? "Expanded" : "Collapsed"}',
          child: ExcludeSemantics(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('GO DEEPER', style: Barako.kickerStyle),
                          const SizedBox(height: 2),
                          Text(
                            'Advanced topics, optional',
                            style: AppText.caption.tint(Barako.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _open ? salapifyIcon('collapse') : salapifyIcon('expand'),
                      size: 22,
                      color: Barako.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_open)
          for (final c in widget.courses) ...[
            const SizedBox(height: 10),
            widget.buildCard(c),
          ],
      ],
    );
  }
}

/// One course's lessons.
class CourseScreen extends StatelessWidget {
  final LearningPath path;
  final String groupId;
  final SalapifyStore store;
  final void Function(BuildContext, String pathId, MoneyLesson) onOpenLesson;

  const CourseScreen({
    super.key,
    required this.path,
    required this.groupId,
    required this.store,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    final group = path.groups.firstWhere(
      (g) => g.id == groupId,
      orElse: () => const LearningPathGroup(id: '', title: ''),
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          group.title,
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final progress = store.expansionProgressFor(path.id);
            final lessonsById = {
              for (final l in lessonsForPath(path.id)) l.id: l,
            };
            final lessons = [
              for (final id in group.lessonIds) ?lessonsById[id],
            ];
            // The same orientation line the courses screen carries. Without
            // it this screen was the only one in the path, course, lesson
            // chain that never said where the learner stood, so walking one
            // level in lost the progress figure entirely.
            final doneCount = lessons
                .where((l) => isDone(progress[l.id] ?? LessonState.notStarted))
                .length;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                if (lessons.isNotEmpty) ...[
                  SalapifyProgressBar(
                    value: doneCount / lessons.length,
                    size: ProgressBarSize.micro,
                    semanticsLabel: '${group.title} progress',
                    color: doneCount == lessons.length
                        ? Barako.celebrate
                        : Barako.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$doneCount of ${lessons.length} lessons done',
                    style: AppText.smallStrong,
                  ),
                  const SizedBox(height: 16),
                ],
                for (var i = 0; i < lessons.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _lessonRow(
                      context,
                      lessons[i],
                      i + 1,
                      lessons.length,
                      progress[lessons[i].id] ?? LessonState.notStarted,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lessonRow(
    BuildContext context,
    MoneyLesson l,
    int position,
    int outOf,
    LessonState state,
  ) {
    final done = isDone(state);
    final started = state != LessonState.notStarted && !done;
    // One announcement per row with the state as a WORD, the same rule the
    // hub's own rows follow since the accessibility pass: three icon shapes
    // carrying the whole meaning made every lesson sound identical.
    return Semantics(
      button: true,
      label: [
        l.title,
        done
            ? 'Completed'
            : started
            ? 'In progress'
            : 'Not started',
        l.summary,
        '$position of $outOf',
        '${displayMinutes(l)} min',
      ].join(', '),
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onOpenLesson(context, path.id, l),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  done
                      ? salapifyIcon('selected')
                      : started
                      ? salapifyIcon('paused')
                      : salapifyIcon('unselected'),
                  size: 18,
                  color: done
                      ? Barako.primary
                      : started
                      ? Barako.primaryText
                      : Barako.faint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title, style: AppText.label),
                      const SizedBox(height: 2),
                      Text(
                        l.summary,
                        style: AppText.caption.copyWith(height: 1.35),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          Text(
                            '$position of $outOf',
                            style: AppText.micro.w4.tint(Barako.faint),
                          ),
                          Text(
                            '${displayMinutes(l)} min',
                            style: AppText.micro.w4.tint(Barako.faint),
                          ),
                          if (started)
                            Text(
                              'Continue',
                              style: AppText.micro.w7.tint(Barako.primaryText),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
