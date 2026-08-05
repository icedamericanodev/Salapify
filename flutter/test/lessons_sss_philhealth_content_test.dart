// Money Courses Phase 10 content contract: the "Protect Your Future" learning
// path's second course, "SSS & PhilHealth Essentials"
// (lib/content/lessons_sss_philhealth.dart, lib/content/learning_paths.dart).
// Proves this course is registered correctly, stays fully isolated from the
// core 22 lessons, every Grow Your Money course, and Phase 9's own Insurance
// Decoded course, passes the house rules (no em/en dash, no eligibility
// verdict, no guaranteed-outcome or calculation language, no affiliation
// claim, no sensitive field ever requested) plus the Phase 4 content policy
// validator, and never estimates a benefit, contribution, pension, case
// rate, or reimbursement.
//
// Mirrors test/lessons_insurance_content_test.dart's own structure on
// purpose, the established shape for a Money Courses content contract test.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_sss_philhealth.dart';
import 'package:salapify/money/expansion_content_policy.dart';
import 'package:salapify/money/interaction_completion.dart';

final _ref = DateTime.utc(2026, 8, 4);

const _stableLessonIds = [
  sspRefTwoSafetyNets,
  sspRefSssMayHelp,
  sspRefCheckBeforeYouCount,
  sspRefHowCoverageWorks,
  sspRefPrimaryCareEarlier,
  sspRefSafetyNetPlan,
];

const _highVolatilityLessonIds = [
  sspRefCheckBeforeYouCount,
  sspRefHowCoverageWorks,
  sspRefPrimaryCareEarlier,
];

const _insuranceLessonIds = [
  insuranceRefWhatItsFor,
  insuranceRefProtectionNeed,
  insuranceRefTermAndWholeLife,
  insuranceRefVulNoSalesPitch,
  insuranceRefReadThePolicy,
  insuranceRefVerifyCompareDecide,
];

void main() {
  group('registration', () {
    test('protect_your_future carries Insurance Decoded followed by SSS & '
        'PhilHealth Essentials, exactly one group each, before whatever '
        'later course this path grows next (Phase 11 added a third, '
        'Pag-IBIG Savings & Housing, without reordering these two)', () {
      final path = learningPaths.firstWhere(
        (p) => p.id == 'protect_your_future',
      );
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      expect(path.groups.map((g) => g.id).take(2), [
        'insurance_decoded',
        'sss_philhealth_benefits',
      ]);
      final group = path.groups.firstWhere(
        (g) => g.id == 'sss_philhealth_benefits',
      );
      expect(group.title, 'SSS & PhilHealth Essentials');
      expect(group.lessonIds, _stableLessonIds);
    });

    test('publishedLearningPaths still carries protect_your_future (Phase '
        '13 later adds a third path, build_your_business, alongside it)', () {
      expect(
        publishedLearningPaths.map((p) => p.id),
        contains('protect_your_future'),
      );
    });

    test('six stable lesson ids, in reading order', () {
      expect(
        sssPhilhealthBenefitsLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
    });

    test('every lesson is registered under the sss_philhealth_benefits '
        'trackId', () {
      for (final l in sssPhilhealthBenefitsLessons) {
        expect(l.trackId, 'sss_philhealth_benefits');
      }
    });

    test('expansionLessonById resolves a lesson from this course to the '
        'protect_your_future path', () {
      final found = expansionLessonById(sspRefTwoSafetyNets);
      expect(found, isNotNull);
      expect(found!.pathId, 'protect_your_future');
      expect(found.lesson.id, sspRefTwoSafetyNets);
    });

    test('lessonsForPath starts with Insurance Decoded followed by SSS & '
        'PhilHealth Essentials, twelve lessons before whatever this path '
        'grows next (Phase 11 appended a third course after these two, '
        'never reordering or touching them)', () {
      final lessons = lessonsForPath('protect_your_future');
      expect(lessons.map((l) => l.id).toList().take(12), [
        ..._insuranceLessonIds,
        ..._stableLessonIds,
      ]);
      expect(lessons.length, greaterThanOrEqualTo(12));
    });
  });

  group('isolation from the core 22, every Grow Your Money course, and '
      'Insurance Decoded', () {
    test('core lesson list is untouched: still 22 lessons, four courses', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('Insurance Decoded is untouched: still its own six stable ids', () {
      expect(
        insuranceDecodedLessons.map((l) => l.id).toList(),
        _insuranceLessonIds,
      );
    });

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with Insurance Decoded\'s own ids', () {
      for (final id in _stableLessonIds) {
        expect(_insuranceLessonIds.contains(id), isFalse);
      }
    });

    test('lessonsForPath("grow_your_money") is unaffected', () {
      final lessons = lessonsForPath('grow_your_money');
      for (final id in _stableLessonIds) {
        expect(lessons.map((l) => l.id), isNot(contains(id)));
      }
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries ContentTopic.governmentBenefitEligibility, '
        'making it regulated content', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.governmentBenefitEligibility),
          reason:
              '${lesson.id} is missing '
              'ContentTopic.governmentBenefitEligibility',
        );
      }
    });

    test('lessons 3, 4, and 5 (contribution readiness, case rates and '
        'provider accreditation, and clinic registration) are classified '
        'high volatility; lessons 1, 2, and 6 are annual', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        final expected = _highVolatilityLessonIds.contains(lesson.id)
            ? ContentVolatility.high
            : ContentVolatility.annual;
        expect(
          lesson.governance.volatility,
          expected,
          reason: '${lesson.id} has the wrong volatility classification',
        );
      }
    });
  });

  group('official-source metadata', () {
    test(
      'every lesson cites at least one structured, HTTPS official source',
      () {
        for (final lesson in sssPhilhealthBenefitsLessons) {
          expect(
            lesson.sources,
            isNotEmpty,
            reason: '${lesson.id} has no sources',
          );
          for (final s in lesson.sources) {
            final uri = Uri.tryParse(s.canonicalUrl);
            expect(uri != null && uri.scheme == 'https', isTrue);
            expect(s.agency, isNotEmpty);
            expect(s.title, isNotEmpty);
          }
        }
      },
    );

    test('every lesson renders an OfficialSourceBlock', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('verified and review-due dates are present and sane', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        final g = lesson.governance;
        expect(g.lastVerifiedDate, isNotNull);
        expect(g.reviewDueDate, isNotNull);
        final verified = parseGovernanceDate(g.lastVerifiedDate!);
        final due = parseGovernanceDate(g.reviewDueDate!);
        expect(verified, isNotNull);
        expect(due, isNotNull);
        expect(due!.isAfter(verified!), isTrue);
      }
    });

    test('every source cites SSS or PhilHealth directly, never an '
        'unofficial calculator or a third party summary', () {
      const knownAgencies = {
        'Social Security System',
        'Philippine Health Insurance Corporation',
      };
      for (final lesson in sssPhilhealthBenefitsLessons) {
        for (final s in lesson.sources) {
          expect(knownAgencies.contains(s.agency), isTrue, reason: s.agency);
        }
      }
    });

    test('every one of the task\'s eight named official pages is cited at '
        'least once across this course', () {
      const expectedUrls = {
        'https://www.sss.gov.ph/benefits/',
        'https://www.sss.gov.ph/wp-content/uploads/2022/04/Booklet_SS-ACT-OF-2018_05172019_2.pdf',
        'https://www.sss.gov.ph/sss-contribution-table/',
        'https://www.philhealth.gov.ph/uhc/',
        'https://www.philhealth.gov.ph/yakap/',
        'https://www.philhealth.gov.ph/services/acr/',
        'https://www.philhealth.gov.ph/circulars/2026/archives.php',
        'https://www.philhealth.gov.ph/partners/providers/facilities/accredited/',
      };
      final citedUrls = {
        for (final lesson in sssPhilhealthBenefitsLessons)
          for (final s in lesson.sources) s.canonicalUrl,
      };
      expect(citedUrls, expectedUrls);
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        expect(
          lesson.blocks.whereType<EducationalBoundaryBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no EducationalBoundaryBlock',
        );
      }
    });
  });

  group('required interactions', () {
    test('every lesson has at least one required interaction block', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        expect(hasUniqueBlockIds(lesson.interactionBlocks), isTrue);
      }
    });

    test('every lesson has a scenario-based mastery check with an '
        'explanation', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no mastery check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });

    test('completing every required interaction block in a lesson, plus '
        'finishing every lesson, completes the course (interaction '
        'completion + course-completion flow)', () {
      for (final lesson in sssPhilhealthBenefitsLessons) {
        final required = requiredInteractionBlocks(lesson.interactionBlocks);
        expect(required, isNotEmpty);
        final completed = required.map((b) => b.blockId).toSet();
        expect(
          allRequiredInteractionsComplete(lesson.interactionBlocks, completed),
          isTrue,
        );
        expect(
          outstandingRequiredInteractions(lesson.interactionBlocks, completed),
          isEmpty,
        );
      }
    });
  });

  group('course-specific interaction coverage (the task\'s own list)', () {
    MoneyLesson byId(String id) =>
        sssPhilhealthBenefitsLessons.firstWhere((l) => l.id == id);

    test('lesson 1 sorts fictional situations into SSS, PhilHealth, both, '
        'or another resource, and carries the required no-other-protection '
        'myth', () {
      final l = byId(sspRefTwoSafetyNets);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        sort.buckets.map((b) => b.id),
        containsAll(['sss', 'philhealth', 'both', 'other']),
      );
      expect(sort.isValid, isTrue);
      final myth = l.interactionBlocks.whereType<MythOrFactBlock>().firstWhere(
        (m) => m.blockId == 'sss-philhealth-two-nets-myth-no-other-protection',
      );
      expect(myth.correctAnswer, MythOrFactAnswer.myth);
    });

    test('lesson 2 matches life events to all eight SSS benefit categories, '
        'with feedback that never says "you qualify"', () {
      final l = byId(sspRefSssMayHelp);
      final matching = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'sss-may-help-life-event-matching');
      expect(matching.buckets.map((b) => b.id), [
        'sickness',
        'maternity',
        'disability',
        'retirement',
        'death',
        'funeral',
        'unemployment',
        'employees-compensation',
      ]);
      expect(matching.items.length, 8);
      for (final item in matching.items) {
        expect(item.explanation.toLowerCase(), isNot(contains('qualify')));
        expect(
          item.explanation.toLowerCase().contains('may apply') ||
              item.explanation.toLowerCase().contains('worth checking'),
          isTrue,
          reason: '${item.id} feedback: ${item.explanation}',
        );
      }
    });

    test('lesson 3 is a non-sensitive readiness checklist with the task\'s '
        'own three result strings, and never calculates eligibility, a '
        'contribution gap, or a benefit amount', () {
      final l = byId(sspRefCheckBeforeYouCount);
      final review = l.interactionBlocks
          .whereType<RiskReviewChecklistBlock>()
          .first;
      expect(review.isValid, isTrue);
      expect(review.requiredForCompletion, isTrue);
      expect(
        review.foundationSummary,
        'Start with your official account or '
        'an SSS office',
      );
      expect(review.partialSummary, 'Some records to check');
      expect(review.completeSummary, 'Ready to verify');
      // "contribution gap" and "benefit amount" are allowed to appear only
      // as part of teaching that this lesson never calculates them (the
      // task requires Lesson 3 to say exactly that), so every occurrence
      // must sit near a negation rather than being banned outright, the
      // same directional check lessons_insurance_content_test.dart uses
      // for "underinsured".
      _expectOnlyNegated(l, ['contribution gap', 'benefit amount']);
    });

    test('lesson 4 never presents a case rate as a full-bill guarantee, and '
        'carries a before/during/after care checklist', () {
      final l = byId(sspRefHowCoverageWorks);
      final checklist = l.interactionBlocks
          .whereType<ChecklistBlock>()
          .firstWhere(
            (c) => c.blockId == 'philhealth-before-during-after-care',
          );
      expect(checklist.items.length, greaterThanOrEqualTo(6));
      final myth = l.interactionBlocks.whereType<MythOrFactBlock>().first;
      expect(myth.correctAnswer, MythOrFactAnswer.myth);
      expect(myth.statement.toLowerCase(), contains('entire hospital bill'));
      // Never asks for a diagnosis, a procedure, or a hospital bill amount.
      for (final b in l.interactionBlocks) {
        if (b is ReflectionPromptBlock) {
          fail('lesson 4 should not need a free-text reflection prompt');
        }
      }
    });

    test('lesson 5 is administrative education, never medical advice, and '
        'lets the reader build a next health admin step checklist', () {
      final l = byId(sspRefPrimaryCareEarlier);
      final checklist = l.interactionBlocks
          .whereType<ChecklistBlock>()
          .firstWhere((c) => c.blockId == 'primary-care-next-steps');
      expect(checklist.requiredForCompletion, isTrue);
      final symptomScenario = l.interactionBlocks
          .whereType<ScenarioChoiceBlock>()
          .firstWhere(
            (s) => s.blockId == 'primary-care-symptom-question-scenario',
          );
      expect(symptomScenario.preferredOptionId, 'ask-a-provider');
      // "diagnos" and "treatment plan" are allowed to appear only as part
      // of teaching that this lesson never diagnoses or prescribes
      // anything (the task requires Lesson 5 to say exactly that), so
      // every occurrence must sit near a negation.
      _expectOnlyNegated(l, ['diagnos', 'treatment plan']);
      expect(_allText(l).toLowerCase().contains('prescri'), isFalse);
    });

    test('lesson 6 reuses a checklist for the action plan, offers only '
        'verified Salapify routes, and never files a claim or estimates a '
        'benefit', () {
      final l = byId(sspRefSafetyNetPlan);
      expect(
        l.interactionBlocks.whereType<ChecklistBlock>().where(
          (c) => c.blockId == 'safety-net-plan-checklist',
        ),
        isNotEmpty,
      );
      final actions = l.interactionBlocks
          .whereType<SalapifyActionsBlock>()
          .first;
      expect(actions.requiredForCompletion, isFalse);
      expect(actions.actions, isNotEmpty);
    });
  });

  group('house rules: plain text content', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in sssPhilhealthBenefitsLessons) {
        final all = _allText(l);
        expect(all.contains('—'), isFalse, reason: '${l.id} em dash');
        expect(all.contains('–'), isFalse, reason: '${l.id} en dash');
      }
    });

    test('no guaranteed-outcome or risk-free language', () {
      final banned = RegExp(
        r'\bguarantee[ds]?\s+(a\s+|an\s+)?(profit|return|income|growth)\b|'
        r'\brisk[\s-]?free\b',
        caseSensitive: false,
      );
      for (final l in sssPhilhealthBenefitsLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guaranteed-outcome claim',
        );
      }
    });

    test('never declares the reader officially approved, covered, or '
        'eligible', () {
      final banned = RegExp(
        r"\byou(?:'re| are)\b[^.]{0,20}\b(officially\s+)?(approved|covered|"
        r'eligible|qualified)\b',
        caseSensitive: false,
      );
      for (final l in sssPhilhealthBenefitsLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason:
              '${l.id} declares the reader officially approved or '
              'eligible',
        );
      }
    });

    test('never asks the reader to enter, type, share, provide, or send a '
        'password, PIN, OTP, or government-account credential', () {
      final banned = RegExp(
        r'\b(enter|type|share|provide|send)\s+your\s+(password|pin|otp|'
        r'government[\s-]?(id|account)\s*credentials?)\b',
        caseSensitive: false,
      );
      for (final l in sssPhilhealthBenefitsLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} asks for a credential',
        );
      }
    });

    test('never states a specific contribution rate, benefit amount, case '
        'rate, medicine allowance, claim deadline, or minimum-contribution '
        'count', () {
      for (final l in sssPhilhealthBenefitsLessons) {
        final all = _allText(l);
        // No percentage figure and no peso amount anywhere: this course
        // never hardcodes a volatile number, per the task's own instruction.
        expect(RegExp(r'\d+(\.\d+)?\s?%').hasMatch(all), isFalse, reason: l.id);
        expect(
          RegExp(r'(₱|php\s?)\s?\d', caseSensitive: false).hasMatch(all),
          isFalse,
          reason: l.id,
        );
        // No day-count or month-count deadline (e.g. "30 days", "6 months").
        expect(
          RegExp(
            r'\d+[\s-](day|days|month|months|year|years)\b',
            caseSensitive: false,
          ).hasMatch(all),
          isFalse,
          reason: l.id,
        );
      }
    });

    test('the task\'s own never-output phrases never appear anywhere in '
        'this course\'s rendered text', () {
      // "you qualify" is deliberately not in the unconditional list: Lesson
      // 2 and Lesson 3 are required by the task to say their own feedback
      // never says it, so every occurrence must sit near a negation (see
      // the dedicated directional test below).
      const bannedPhrases = [
        'you are eligible',
        'guaranteed coverage',
        'guaranteed benefit',
        'guaranteed approval',
        'stop contributing',
        'stop paying your contribution',
        'best investment',
        'official partner of',
        'partnered with sss',
        'partnered with philhealth',
        'affiliated with the philippine government',
      ];
      for (final l in sssPhilhealthBenefitsLessons) {
        final lower = _allText(l).toLowerCase();
        for (final phrase in bannedPhrases) {
          expect(
            lower.contains(phrase),
            isFalse,
            reason: '${l.id} contains banned phrase "$phrase"',
          );
        }
      }
    });

    test('every occurrence of "you qualify" sits near a negation, never as '
        'an output this course actually produces', () {
      for (final l in sssPhilhealthBenefitsLessons) {
        _expectOnlyNegated(l, ['you qualify']);
      }
    });

    test('never presents SSS or PhilHealth as an investment', () {
      final banned = RegExp(
        r'\b(sss|philhealth)\b[^.]{0,40}\b(is an investment|as an '
        r'investment|invest in)\b',
        caseSensitive: false,
      );
      for (final l in sssPhilhealthBenefitsLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  group('exclusions: no eligibility verdict, no calculation, no sensitive '
      'data collection', () {
    test('never declares eligibility or ineligibility for a specific '
        'benefit', () {
      for (final l in sssPhilhealthBenefitsLessons) {
        final lower = _allText(l).toLowerCase();
        expect(lower.contains('you are not eligible'), isFalse);
        expect(lower.contains('you are now eligible'), isFalse);
        expect(lower.contains('is not covered for you'), isFalse);
      }
    });

    test('no ReflectionPromptBlock or free-text field anywhere asks for a '
        'government id number, a password, a diagnosis, an exact salary, '
        'or an employer name', () {
      for (final l in sssPhilhealthBenefitsLessons) {
        for (final b in l.interactionBlocks) {
          if (b is ReflectionPromptBlock && b.allowFreeText) {
            final q = b.question.toLowerCase();
            for (final banned in [
              'sss number',
              'philhealth identification number',
              'password',
              'government id',
              'diagnosis',
              'exact salary',
              'employer name',
              'beneficiary',
            ]) {
              expect(
                q.contains(banned),
                isFalse,
                reason: '${b.blockId} free-text prompt asks about $banned',
              );
            }
          }
        }
      }
    });

    test('no lesson mentions collecting an SSS number, a PhilHealth '
        'Identification Number, a government login, or a claim document', () {
      for (final l in sssPhilhealthBenefitsLessons) {
        final lower = _allText(l).toLowerCase();
        for (final banned in [
          'enter your sss number',
          'enter your philhealth number',
          'upload your government id',
          'upload a claim document',
          'upload your hospital bill',
        ]) {
          expect(lower.contains(banned), isFalse, reason: '${l.id}: $banned');
        }
      }
    });
  });

  group('Salapify actions: verified routes only, never an automatic write, '
      'never a new government-account or claim-filing feature', () {
    test('every action route is a known, pushable Salapify screen', () {
      const knownRoutes = {
        'goals',
        'debts',
        'budget',
        'mindset',
        'accounts',
        'recurring',
        'notifications',
      };
      final block = _salapifyActionsBlock();
      for (final action in block.actions) {
        expect(
          knownRoutes.contains(action.route),
          isTrue,
          reason: 'unknown route "${action.route}"',
        );
        expect(action.description, isNotEmpty);
      }
    });

    test('every action explains it only opens a screen and changes nothing '
        'by itself', () {
      final block = _salapifyActionsBlock();
      for (final action in block.actions) {
        final lower = action.description.toLowerCase();
        expect(
          lower.contains('nothing') || lower.contains('never'),
          isTrue,
          reason: '${action.id} description does not say what it will not do',
        );
      }
    });

    test('the block is never required to finish the lesson', () {
      final block = _salapifyActionsBlock();
      expect(block.requiredForCompletion, isFalse);
    });
  });
}

/// Asserts every occurrence of each phrase in [l]'s rendered text sits near
/// a negation word ("never", "not", "no", "nothing", "cannot", "without"),
/// the same directional check lessons_insurance_content_test.dart uses for
/// "underinsured": a phrase this course is required to teach it never does
/// is allowed to appear only while saying so, never as an actual output.
void _expectOnlyNegated(MoneyLesson l, List<String> phrases) {
  final all = _allText(l).toLowerCase();
  final negation = RegExp(
    r"\b(never|not|no|nothing|cannot|can't|without)\b",
    caseSensitive: false,
  );
  for (final phrase in phrases) {
    for (final m in RegExp(RegExp.escape(phrase)).allMatches(all)) {
      final windowStart = (m.start - 45).clamp(0, all.length);
      final before = all.substring(windowStart, m.start);
      expect(
        negation.hasMatch(before),
        isTrue,
        reason:
            '${l.id} uses "$phrase" without a nearby negation: '
            '"${all.substring(windowStart, (m.end + 20).clamp(0, all.length))}"',
      );
    }
  }
}

SalapifyActionsBlock _salapifyActionsBlock() {
  final lesson = sssPhilhealthBenefitsLessons.firstWhere(
    (l) => l.id == sspRefSafetyNetPlan,
  );
  return lesson.interactionBlocks.whereType<SalapifyActionsBlock>().first;
}

String _allText(MoneyLesson l) {
  final buf = StringBuffer()
    ..write(l.title)
    ..write(' ')
    ..write(l.summary)
    ..write(' ')
    ..write(l.objective)
    ..write(' ')
    ..write(l.keyTakeaway);
  for (final b in l.blocks) {
    switch (b) {
      case ProseBlock(:final heading, :final paragraphs):
        buf.writeAll([heading, ...paragraphs], ' ');
      case NuggetsBlock(:final items):
        buf.writeAll(items, ' ');
      case RiskWarningBlock(:final title, :final text):
        buf.writeAll([title, text], ' ');
      case OfficialSourceBlock(:final agency, :final sourceTitle):
        buf.writeAll([agency, sourceTitle], ' ');
      case EducationalBoundaryBlock():
        break;
      case RulesBlock(:final passages):
        buf.writeAll(passages, ' ');
      case DiscoveryBlock(:final question, :final reveal):
        buf.writeAll([question, reveal], ' ');
      case StoryBlock(:final who, :final text):
        buf.writeAll([who, text], ' ');
      case DiagramBlock(:final steps, :final caption):
        buf.writeAll([...steps, caption], ' ');
      case TrapBlock(:final mostPeople, :final worksBetter):
        buf.writeAll([mostPeople, worksBetter], ' ');
      case ChallengeBlock(:final prompt, :final compare):
        buf.writeAll([prompt, compare], ' ');
      case ReflectionBlock(:final line):
        buf.write(line);
    }
  }
  final check = l.check;
  if (check != null) {
    buf.writeAll([
      check.question,
      ...check.choices,
      check.explanation,
      check.whyWrong ?? '',
    ], ' ');
  }
  for (final b in l.interactionBlocks) {
    buf.write(' ${b.prompt} ${b.instructions}');
    switch (b) {
      case ScenarioChoiceBlock(:final situation, :final options):
        buf.write(' $situation');
        for (final o in options) {
          buf.write(' ${o.label} ${o.explanation}');
        }
      case MythOrFactBlock(:final statement, :final explanation):
        buf.write(' $statement $explanation');
      case ComparisonBlock(:final items):
        for (final i in items) {
          buf.write(' ${i.name}');
          for (final v in i.valuesByCriterionId.values) {
            buf.write(' $v');
          }
          if (i.caution != null) buf.write(' ${i.caution}');
        }
      case ChecklistBlock(:final items):
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation ?? ''}');
        }
      case SortingBlock(:final items):
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation ?? ''}');
        }
      case ReflectionPromptBlock(:final choices):
        for (final c in choices) {
          buf.write(' ${c.label}');
        }
      case CategorizeBlock(:final buckets, :final items):
        for (final bkt in buckets) {
          buf.write(' ${bkt.label}');
        }
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation}');
        }
      case ReadinessCardBlock(:final fields):
        for (final f in fields) {
          buf.write(' ${f.label}');
          for (final o in f.options) {
            buf.write(' ${o.label}');
          }
        }
      case SalapifyActionsBlock(:final actions):
        for (final a in actions) {
          buf.write(' ${a.label} ${a.description}');
        }
      case LossImpactSimulatorBlock(:final introduction, :final amountOptions):
        buf.write(' $introduction');
        for (final a in amountOptions) {
          buf.write(' ${a.label}');
        }
      case RiskReviewChecklistBlock(
        :final items,
        :final foundationSummary,
        :final partialSummary,
        :final completeSummary,
      ):
        for (final i in items) {
          buf.write(' ${i.label} ${i.explanation ?? ''}');
        }
        buf.write(' $foundationSummary $partialSummary $completeSummary');
    }
  }
  return buf.toString();
}
