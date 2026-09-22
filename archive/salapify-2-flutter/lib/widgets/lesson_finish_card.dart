// The moment a lesson ends, in one place.
//
// This was written twice, once in each reader, when Batch 1 replaced the
// dead-end "Done. One useful thing." row. A third reader (the paged one)
// made that duplication a real liability rather than a tidiness complaint:
// the two existing readers had already drifted once before, ending up with
// different quiz retry rules for the same-looking card, and that is exactly
// the failure this extraction prevents.

import 'package:flutter/material.dart';

import '../money/lesson_flow.dart';
import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

class LessonFinishCard extends StatelessWidget {
  /// What finishing just completed, and what to read next. Null while the
  /// outcome has not been computed, which renders the plain done state.
  final FinishOutcome? outcome;

  /// The lesson's own sentence worth keeping, or empty.
  final String keyTakeaway;

  /// Opens the next lesson. Null when this reader cannot navigate onward, in
  /// which case the button is simply absent rather than dead.
  final void Function(String lessonId)? onOpenLesson;

  const LessonFinishCard({
    super.key,
    required this.outcome,
    required this.keyTakeaway,
    this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    final headline = switch (outcome?.scope) {
      FinishScope.path => 'Path finished. Every lesson done.',
      FinishScope.course =>
        'Course finished: ${outcome?.completedCourseTitle ?? ''}'.trim(),
      _ => 'Done. One useful thing.',
    };
    final next = outcome?.next;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Announced, because the payoff moment used to be silent to a
          // screen reader and the button that had focus disappeared on tap.
          Semantics(
            liveRegion: true,
            header: true,
            child: Row(
              children: [
                Icon(salapifyIcon('selected'), size: 18, color: Barako.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    headline,
                    style: AppText.label.w7.tint(Barako.primary),
                  ),
                ),
              ],
            ),
          ),
          if (keyTakeaway.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              keyTakeaway,
              style: AppText.label.w4
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.5),
            ),
          ],
          if (outcome != null && outcome!.totalInCourse > 0) ...[
            const SizedBox(height: 10),
            Text(
              '${outcome!.doneInCourse} of ${outcome!.totalInCourse} done in '
              'this course',
              style: AppText.caption.tint(Barako.muted),
            ),
          ],
          if (next != null && onOpenLesson != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => onOpenLesson!(next.id),
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                // Two lines by design. As one run the minutes wrapped and
                // stranded "min" on a line of its own.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${outcome?.nextStartsNewCourse == true ? 'Next course' : 'Next'}: '
                      '${next.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${next.minutes} min',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Always as reachable as the next lesson. Momentum is an offer,
            // never a corridor.
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back to courses'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
