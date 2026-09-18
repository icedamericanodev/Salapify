// Phase 16 final integration and QA: registry integrity across the whole
// Money Courses catalog (the core 22 plus every published expansion path).
// Each individual course already has its own content test that checks IDs
// are unique WITHIN that course; this file is the one place that checks
// uniqueness and scoping ACROSS every course and path at once, the seam a
// per-course test can never see by construction.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_bir_local_permits.dart';
import 'package:salapify/content/lessons_bir_tax_setup.dart';
import 'package:salapify/content/lessons_business_permits_compliance.dart';
import 'package:salapify/content/lessons_business_registration.dart';
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_pagibig.dart';
import 'package:salapify/content/lessons_ph_government_securities.dart';
import 'package:salapify/content/lessons_sss_philhealth.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';

/// Every registered expansion course's own lesson list, keyed
/// 'pathId.groupId' to match learning_paths.dart. Shared across groups
/// in this file so the deep-link check below walks the exact same catalog
/// the uniqueness checks do.
final Map<String, List<MoneyLesson>> _lessonsByCourse = {
  'grow_your_money.investing_readiness': growYourMoneyLessons,
  'grow_your_money.stocks_and_bonds': stocksAndBondsLessons,
  'grow_your_money.deposits_and_pooled_funds': depositsAndPooledFundsLessons,
  'grow_your_money.crypto_without_hype': cryptoWithoutHypeLessons,
  'grow_your_money.ph_government_securities': phGovernmentSecuritiesLessons,
  'protect_your_future.insurance_decoded': insuranceDecodedLessons,
  'protect_your_future.sss_philhealth_benefits': sssPhilhealthBenefitsLessons,
  'protect_your_future.pagibig_savings_mp2_housing':
      pagibigSavingsMp2HousingLessons,
  'build_your_business.start_a_business_legally': startABusinessLegallyLessons,
  'build_your_business.bir_registration_and_local_permits':
      birRegistrationAndLocalPermitsLessons,
  'build_your_business.bir_registration_tax_setup':
      birRegistrationTaxSetupLessons,
  'build_your_business.business_permits_and_compliance':
      businessPermitsAndComplianceLessons,
};

// Every route widgets/expansion_lesson_reader.dart's private
// _resolveGrowAction actually knows how to run. Kept as its own duplicated
// list, the same convention test/lessons_content_test.dart's _knownRoutes
// already uses for the core 22: a route added to content without a matching
// case there fails HERE, loudly, in a plain string-set diff, rather than
// silently rendering "Not available right now" on a real phone.
const _knownGrowActionRoutes = {
  'goals',
  'debts',
  'budget',
  'mindset',
  'accounts',
  'recurring',
  'notifications',
  // Batch C1B: the take-home-pay calculator, linked from the SSS & PhilHealth
  // course so contributions read as the gross-to-net deductions they are.
  'salary',
};

void main() {
  group('core catalog stays exactly what it was', () {
    // Required test 1: core count remains 22 lessons and four courses. Prove
    // it can fail: temporarily append a 23rd lesson id, watch this go red
    // (23 != 22), then revert. That failure line is what a real accidental
    // append would produce.
    test('exactly 22 core lessons in exactly 4 course tracks', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('no expansion path or group id collides with a core track key', () {
      final coreTrackKeys = core.courseTracks.map((t) => t['key']).toSet();
      for (final path in learningPaths) {
        expect(coreTrackKeys.contains(path.id), isFalse);
        for (final group in path.groups) {
          expect(coreTrackKeys.contains(group.id), isFalse);
        }
      }
    });
  });

  group('every expansion path belongs to exactly one path, once', () {
    // Required test 3: every expansion course (group) has one valid path.
    // "One valid path" is structural here: a group is defined as a member of
    // exactly one path's `groups` list (Dart has no shared/aliased list
    // entries across the const paths below), so the real risk this guards is
    // a COPY-PASTED group id appearing under two different paths by mistake.
    test('no group id is reused across two different paths', () {
      final seenGroupIds = <String, String>{}; // groupId -> pathId
      for (final path in learningPaths) {
        for (final group in path.groups) {
          final existing = seenGroupIds[group.id];
          expect(
            existing,
            isNull,
            reason:
                'group "${group.id}" appears in both "$existing" and '
                '"${path.id}"',
          );
          seenGroupIds[group.id] = path.id;
        }
      }
    });

    test('every published path has at least one group with lessons', () {
      for (final path in publishedLearningPaths) {
        expect(path.groups, isNotEmpty, reason: '${path.id} has no groups');
        for (final group in path.groups) {
          expect(
            group.lessonIds,
            isNotEmpty,
            reason: '${path.id}/${group.id} has no lessons',
          );
        }
      }
    });
  });

  group('globally unique IDs across the entire catalog', () {
    // Required test 2: all expansion IDs are globally unique. This is the
    // cross-course seam no single course's own content test can see.
    final lessonsByCourse = _lessonsByCourse;

    test('every path/course/lesson id combination is registered exactly '
        'once, matching learning_paths.dart', () {
      // Every course file's own lesson list must appear, in the same order,
      // as its matching group's lessonIds in learning_paths.dart. This is
      // the single source of truth check: a course could otherwise drift
      // from its own registration without any test noticing.
      for (final path in learningPaths) {
        for (final group in path.groups) {
          final key = '${path.id}.${group.id}';
          final courseLessons = lessonsByCourse[key];
          expect(
            courseLessons,
            isNotNull,
            reason: '$key has no matching content file list in this test',
          );
          expect(
            courseLessons!.map((l) => l.id).toList(),
            group.lessonIds,
            reason: '$key content order must match its registered group',
          );
        }
      }
    });

    test('no lesson id is used twice across the whole catalog (core plus '
        'every expansion course)', () {
      final seen = <String, String>{}; // id -> where
      void record(String id, String where) {
        final existing = seen[id];
        expect(
          existing,
          isNull,
          reason: 'lesson id "$id" is used by both "$existing" and "$where"',
        );
        seen[id] = where;
      }

      for (final l in core.lessons) {
        record(l['id'] as String, 'core');
      }
      for (final entry in lessonsByCourse.entries) {
        for (final l in entry.value) {
          record(l.id, entry.key);
        }
      }
      // 22 core + one entry per expansion lesson, and nothing collided.
      expect(
        seen.length,
        22 + lessonsByCourse.values.fold(0, (a, l) => a + l.length),
      );
    });

    test('no interaction block id is reused within its own lesson', () {
      // interaction_blocks.dart's own contract: a blockId is "stable within
      // one lesson, unique by convention", the scope
      // money/interaction_completion.dart actually keys by (one lesson's
      // completed set at a time). Checked at that scope, not invented as a
      // stricter global rule the architecture never claimed.
      for (final entry in lessonsByCourse.entries) {
        for (final lesson in entry.value) {
          final ids = [
            for (final InteractionBlock b in lesson.interactionBlocks)
              b.blockId,
          ];
          expect(
            ids.toSet().length,
            ids.length,
            reason:
                '${entry.key}/${lesson.id} has a duplicate interaction '
                'block id',
          );
        }
      }
    });

    test('publishedLearningPaths ordering is deterministic (array order, '
        'not a set or a sort)', () {
      // Calling twice must yield the identical order; nothing here reads a
      // clock, a random seed, or iterates an unordered Set.
      expect(
        publishedLearningPaths.map((p) => p.id).toList(),
        publishedLearningPaths.map((p) => p.id).toList(),
      );
      expect(publishedLearningPaths.map((p) => p.id).toList(), [
        'grow_your_money',
        'protect_your_future',
        'build_your_business',
      ]);
    });
  });

  group('completing one path never marks another path or the core lessons '
      'incomplete', () {
    test('every path has an independent, non-overlapping lesson id set', () {
      final ids = <String, Set<String>>{
        for (final path in learningPaths) path.id: path.lessonIds.toSet(),
      };
      final pathIds = ids.keys.toList();
      for (var i = 0; i < pathIds.length; i++) {
        for (var j = i + 1; j < pathIds.length; j++) {
          final overlap = ids[pathIds[i]]!.intersection(ids[pathIds[j]]!);
          expect(
            overlap,
            isEmpty,
            reason:
                '${pathIds[i]} and ${pathIds[j]} share lesson ids: $overlap',
          );
        }
      }
      final coreIds = core.lessons.map((l) => l['id'] as String).toSet();
      for (final entry in ids.entries) {
        expect(
          coreIds.intersection(entry.value),
          isEmpty,
          reason: '${entry.key} shares a lesson id with the core 22',
        );
      }
    });
  });

  group('deep links: every Salapify action route resolves', () {
    // Required test 10: every deep link resolves to an existing route.
    // Walks every SalapifyActionsBlock across the whole expansion catalog,
    // the same seam the per-course content tests cannot see because each
    // only checks its own course.
    test('every SalapifyActionDef route is one _resolveGrowAction knows how '
        'to run', () {
      for (final entry in _lessonsByCourse.entries) {
        for (final lesson in entry.value) {
          for (final block
              in lesson.interactionBlocks.whereType<SalapifyActionsBlock>()) {
            for (final action in block.actions) {
              expect(
                _knownGrowActionRoutes.contains(action.route),
                isTrue,
                reason:
                    '${entry.key}/${lesson.id} offers unknown route '
                    '"${action.route}"',
              );
            }
          }
        }
      }
    });

    // Required test 11 (structural half, see
    // expansion_lesson_reader_widget_test.dart for the behavioral proof via
    // Cancel/Continue): a SalapifyActionDef itself carries no callback or
    // write capability, only opaque strings the reader resolves through its
    // own verified switch. Nothing here CAN mutate anything.
    test('a Salapify action carries only descriptive strings, never a '
        'callback', () {
      for (final entry in _lessonsByCourse.entries) {
        for (final lesson in entry.value) {
          for (final block
              in lesson.interactionBlocks.whereType<SalapifyActionsBlock>()) {
            for (final action in block.actions) {
              expect(action.id, isA<String>());
              expect(action.label, isNotEmpty);
              expect(action.description, isNotEmpty);
              expect(action.route, isA<String>());
            }
          }
        }
      }
    });
  });
}
