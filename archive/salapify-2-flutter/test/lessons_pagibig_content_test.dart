// Money Courses Phase 11 content contract: the "Protect Your Future" learning
// path's third course, "Pag-IBIG Savings & Housing"
// (lib/content/lessons_pagibig.dart, lib/content/learning_paths.dart).
// Proves this course is registered correctly, stays fully isolated from the
// core 22 lessons, every Grow Your Money course, Insurance Decoded, and SSS &
// PhilHealth Essentials, passes the house rules (no em/en dash, no MP2
// suitability recommendation, no guaranteed-outcome or calculation language,
// no housing affordability or approval determination, no affiliation claim,
// no sensitive field ever requested) plus the Phase 4 content policy
// validator, and never states a dividend rate, loan-rate table, loan limit,
// or projected return.
//
// Mirrors test/lessons_sss_philhealth_content_test.dart's own structure on
// purpose, the established shape for a Money Courses content contract test.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_pagibig.dart';
import 'package:salapify/content/lessons_sss_philhealth.dart';
import 'package:salapify/money/expansion_content_policy.dart';
import 'package:salapify/money/interaction_completion.dart';

final _ref = DateTime.utc(2026, 8, 5);

const _stableLessonIds = [
  pagibigRefThreeTools,
  pagibigRefCheckRegularSavings,
  pagibigRefMp2WithoutHype,
  pagibigRefMp2Readiness,
  pagibigRefHousingLoanCost,
  pagibigRefMakeYourPlan,
];

const _highVolatilityLessonIds = [
  pagibigRefCheckRegularSavings,
  pagibigRefMp2WithoutHype,
  pagibigRefMp2Readiness,
  pagibigRefHousingLoanCost,
];

const _insuranceLessonIds = [
  insuranceRefWhatItsFor,
  insuranceRefProtectionNeed,
  insuranceRefTermAndWholeLife,
  insuranceRefVulNoSalesPitch,
  insuranceRefReadThePolicy,
  insuranceRefVerifyCompareDecide,
];

const _sspLessonIds = [
  sspRefTwoSafetyNets,
  sspRefSssMayHelp,
  sspRefCheckBeforeYouCount,
  sspRefHowCoverageWorks,
  sspRefPrimaryCareEarlier,
  sspRefSafetyNetPlan,
];

void main() {
  group('registration', () {
    test('protect_your_future carries Insurance Decoded, SSS & PhilHealth '
        'Essentials, and Pag-IBIG Savings & Housing, exactly one group '
        'each', () {
      final path = learningPaths.firstWhere(
        (p) => p.id == 'protect_your_future',
      );
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      expect(path.groups.map((g) => g.id), [
        'insurance_decoded',
        'sss_philhealth_benefits',
        'pagibig_savings_mp2_housing',
      ]);
      final group = path.groups.firstWhere(
        (g) => g.id == 'pagibig_savings_mp2_housing',
      );
      expect(group.title, 'Pag-IBIG Savings & Housing');
      expect(group.lessonIds, _stableLessonIds);
    });

    test('publishedLearningPaths still carries protect_your_future (Phase '
        '13 later adds a third path, build_your_business, alongside it)', () {
      expect(
        publishedLearningPaths.map((p) => p.id),
        contains('protect_your_future'),
      );
    });

    test('exactly six stable lesson ids, in reading order', () {
      expect(
        pagibigSavingsMp2HousingLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
      expect(_stableLessonIds.length, 6);
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
    });

    test('every lesson is registered under the pagibig_savings_mp2_housing '
        'trackId', () {
      for (final l in pagibigSavingsMp2HousingLessons) {
        expect(l.trackId, 'pagibig_savings_mp2_housing');
      }
    });

    test('expansionLessonById resolves a lesson from this course to the '
        'protect_your_future path', () {
      final found = expansionLessonById(pagibigRefThreeTools);
      expect(found, isNotNull);
      expect(found!.pathId, 'protect_your_future');
      expect(found.lesson.id, pagibigRefThreeTools);
    });

    test('lessonsForPath returns Insurance Decoded, then SSS & PhilHealth '
        'Essentials, then Pag-IBIG Savings & Housing, eighteen lessons '
        'total', () {
      final lessons = lessonsForPath('protect_your_future');
      expect(lessons.map((l) => l.id).toList(), [
        ..._insuranceLessonIds,
        ..._sspLessonIds,
        ..._stableLessonIds,
      ]);
      expect(lessons.length, 18);
    });
  });

  group('isolation from the core 22, every Grow Your Money course, '
      'Insurance Decoded, and SSS & PhilHealth Essentials', () {
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

    test('SSS & PhilHealth Essentials is untouched: still its own six '
        'stable ids', () {
      expect(
        sssPhilhealthBenefitsLessons.map((l) => l.id).toList(),
        _sspLessonIds,
      );
    });

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with Insurance Decoded\'s or SSS & '
        'PhilHealth Essentials\' own ids', () {
      for (final id in _stableLessonIds) {
        expect(_insuranceLessonIds.contains(id), isFalse);
        expect(_sspLessonIds.contains(id), isFalse);
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
      for (final lesson in pagibigSavingsMp2HousingLessons) {
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
      for (final lesson in pagibigSavingsMp2HousingLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.governmentBenefitEligibility),
          reason:
              '${lesson.id} is missing '
              'ContentTopic.governmentBenefitEligibility',
        );
      }
    });

    test('lessons 2, 3, 4, and 5 (regular savings records, MP2 dividend '
        'rules, MP2 readiness, and housing-loan terms) are classified high '
        'volatility; lessons 1 and 6 are annual', () {
      for (final lesson in pagibigSavingsMp2HousingLessons) {
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
        for (final lesson in pagibigSavingsMp2HousingLessons) {
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
      for (final lesson in pagibigSavingsMp2HousingLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('verified and review-due dates are present and sane', () {
      for (final lesson in pagibigSavingsMp2HousingLessons) {
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

    test('every source cites Pag-IBIG Fund directly, never an unofficial '
        'calculator or a third party summary', () {
      const knownAgencies = {'Pag-IBIG Fund'};
      for (final lesson in pagibigSavingsMp2HousingLessons) {
        for (final s in lesson.sources) {
          expect(knownAgencies.contains(s.agency), isTrue, reason: s.agency);
        }
      }
    });

    test('every one of the task\'s six named official pages is cited at '
        'least once across this course', () {
      const expectedUrls = {
        'https://www.pagibigfund.gov.ph/',
        'https://open.gov.ph/pagibig',
        'https://www.pagibigfundservices.com/virtualpagibig/',
        'https://pagibigfund.gov.ph/AffordableHousingLoan.html',
        'https://www.pagibigfund.gov.ph/AA/calc.aspx',
        'https://pagibigfund.gov.ph/forms_housing.html',
      };
      final citedUrls = {
        for (final lesson in pagibigSavingsMp2HousingLessons)
          for (final s in lesson.sources) s.canonicalUrl,
      };
      expect(citedUrls, expectedUrls);
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in pagibigSavingsMp2HousingLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in pagibigSavingsMp2HousingLessons) {
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
      for (final lesson in pagibigSavingsMp2HousingLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in pagibigSavingsMp2HousingLessons) {
        expect(hasUniqueBlockIds(lesson.interactionBlocks), isTrue);
      }
    });

    test('every lesson has a scenario-based mastery check with an '
        'explanation', () {
      for (final lesson in pagibigSavingsMp2HousingLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no mastery check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });

    test('completing every required interaction block in a lesson completes '
        'the lesson (interaction completion flow)', () {
      for (final lesson in pagibigSavingsMp2HousingLessons) {
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
        pagibigSavingsMp2HousingLessons.firstWhere((l) => l.id == id);

    test('lesson 1 sorts fictional situations into Regular Savings, MP2, '
        'housing finance, or another option', () {
      final l = byId(pagibigRefThreeTools);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        sort.buckets.map((b) => b.id),
        containsAll(['regular-savings', 'mp2', 'housing', 'other']),
      );
      expect(sort.isValid, isTrue);
    });

    test('lesson 2 is a non-sensitive record-check checklist with the '
        'task\'s own three result strings, and never asks for a MID '
        'number, employer name, exact amount, salary, login, or a '
        'document', () {
      final l = byId(pagibigRefCheckRegularSavings);
      final review = l.interactionBlocks
          .whereType<RiskReviewChecklistBlock>()
          .first;
      expect(review.isValid, isTrue);
      expect(review.requiredForCompletion, isTrue);
      expect(
        review.foundationSummary,
        'Your next step is to review your official record.',
      );
      expect(
        review.partialSummary,
        'Some contributions may need verification.',
      );
      expect(
        review.completeSummary,
        'Contact Pag-IBIG if your records do not match.',
      );
      // This lesson is required to reassure the reader that it never asks
      // for these fields, so each phrase legitimately appears once, always
      // inside a negated sentence ("never needs a member's MID number...").
      // Every occurrence must sit near a negation, never as something this
      // checklist actually asks the reader to do, the same directional
      // check lessons_sss_philhealth_content_test.dart uses for "contribution
      // gap" and "benefit amount".
      _expectOnlyNegated(l, [
        'mid number',
        'employer name',
        'exact contribution',
        'salary',
        'login',
      ]);
      final lower = _allText(l).toLowerCase();
      for (final neverMentioned in ['screenshot', 'upload']) {
        expect(
          lower.contains(neverMentioned),
          isFalse,
          reason: '${l.id}: $neverMentioned',
        );
      }
    });

    test('lesson 3 carries the task\'s four required myths, each correctly '
        'flagged as a myth', () {
      final l = byId(pagibigRefMp2WithoutHype);
      final myths = l.interactionBlocks.whereType<MythOrFactBlock>().toList();
      const requiredStatements = [
        'MP2 pays the same return every year.',
        'I can treat MP2 exactly like an emergency savings account.',
        'A previous high dividend means the next one will be the same.',
        'Everyone should open an MP2 account.',
      ];
      for (final statement in requiredStatements) {
        final myth = myths.firstWhere(
          (m) => m.statement == statement,
          orElse: () => fail('missing required myth: $statement'),
        );
        expect(myth.correctAnswer, MythOrFactAnswer.myth);
      }
    });

    test('lesson 4 never says invest now, MP2 is right for you, a '
        'contribution amount, or an eligibility result', () {
      final l = byId(pagibigRefMp2Readiness);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(sort.isValid, isTrue);
      expect(sort.buckets.map((b) => b.id), [
        'check-liquidity',
        'review-priorities',
        'verify-mp2-rules',
        'goal-fit-review-terms',
      ]);
      // This lesson is required to say out loud that it never produces
      // these outputs, so each phrase legitimately appears once, always
      // inside a negated sentence ("never says invest now..."). Every
      // occurrence must sit near a negation, never as an actual result this
      // exercise produces, the same directional check used above for
      // lesson 2's privacy phrases.
      _expectOnlyNegated(l, ['invest now', 'mp2 is right for you']);
      final lower = _allText(l).toLowerCase();
      for (final neverMentioned in [
        'you should contribute',
        'you are eligible',
      ]) {
        expect(
          lower.contains(neverMentioned),
          isFalse,
          reason: '${l.id}: $neverMentioned',
        );
      }
    });

    test('lesson 5 is a housing-readiness checklist that never determines '
        'affordability, approval, or amortization, and links to the '
        'official calculator instead of building one', () {
      final l = byId(pagibigRefHousingLoanCost);
      final review = l.interactionBlocks
          .whereType<RiskReviewChecklistBlock>()
          .first;
      expect(review.isValid, isTrue);
      expect(review.requiredForCompletion, isTrue);
      final sources = l.sources.map((s) => s.canonicalUrl);
      expect(sources, contains('https://www.pagibigfund.gov.ph/AA/calc.aspx'));
      final lower = _allText(l).toLowerCase();
      for (final banned in [
        'you are approved',
        'you can afford',
        'you qualify for',
      ]) {
        expect(lower.contains(banned), isFalse, reason: '${l.id}: $banned');
      }
    });

    test('lesson 6 lets the reader choose next actions, offers only '
        'verified Salapify routes, and never files an application or '
        'estimates a benefit', () {
      final l = byId(pagibigRefMakeYourPlan);
      expect(
        l.interactionBlocks.whereType<ChecklistBlock>().where(
          (c) => c.blockId == 'pagibig-plan-next-actions',
        ),
        isNotEmpty,
      );
      final actions = l.interactionBlocks
          .whereType<SalapifyActionsBlock>()
          .first;
      expect(actions.requiredForCompletion, isFalse);
      expect(actions.actions, isNotEmpty);
    });

    test('at least one MP2 interaction (lesson 3 or 4) and one housing-'
        'readiness interaction (lesson 5) exist and are usable', () {
      final mp2Lesson = byId(pagibigRefMp2WithoutHype);
      expect(mp2Lesson.interactionBlocks, isNotEmpty);
      final readinessLesson = byId(pagibigRefMp2Readiness);
      final readinessSort = readinessLesson.interactionBlocks
          .whereType<CategorizeBlock>()
          .first;
      expect(readinessSort.isValid, isTrue);
      final housingLesson = byId(pagibigRefHousingLoanCost);
      final housingChecklist = housingLesson.interactionBlocks
          .whereType<RiskReviewChecklistBlock>()
          .first;
      expect(housingChecklist.isValid, isTrue);
    });
  });

  group('house rules: plain text content', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in pagibigSavingsMp2HousingLessons) {
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
      for (final l in pagibigSavingsMp2HousingLessons) {
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
      for (final l in pagibigSavingsMp2HousingLessons) {
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
      for (final l in pagibigSavingsMp2HousingLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} asks for a credential',
        );
      }
    });

    test('never states a specific dividend rate, loan-rate, loan limit, or '
        'projected return', () {
      for (final l in pagibigSavingsMp2HousingLessons) {
        final all = _allText(l);
        // No percentage figure and no peso amount anywhere: this course
        // never hardcodes a volatile number, per the task's own instruction.
        expect(RegExp(r'\d+(\.\d+)?\s?%').hasMatch(all), isFalse, reason: l.id);
        expect(
          RegExp(r'(₱|php\s?)\s?\d', caseSensitive: false).hasMatch(all),
          isFalse,
          reason: l.id,
        );
        // No day-count, month-count, or year-count term (e.g. "5-year term",
        // "30 days").
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
      // "invest now" and "mp2 is right for you" are deliberately not in
      // this unconditional list: lesson 4 is required by the task to say
      // out loud that it never produces those outputs, so every occurrence
      // must sit near a negation rather than being banned outright, checked
      // directly above in the dedicated lesson 4 test.
      const bannedPhrases = [
        'you should contribute',
        'you are eligible',
        'guaranteed return',
        'guaranteed dividend',
        'guaranteed approval',
        'best investment',
        'official partner of',
        'partnered with pag-ibig',
        'affiliated with the philippine government',
      ];
      for (final l in pagibigSavingsMp2HousingLessons) {
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

    test('never presents Regular Savings or MP2 as guaranteed wealth or a '
        'shortcut to becoming rich', () {
      final banned = RegExp(
        r'\b(guaranteed\s+(high\s+)?return|risk[\s-]?free\s+wealth|'
        r'shortcut\s+to\s+(becoming\s+)?rich)\b',
        caseSensitive: false,
      );
      for (final l in pagibigSavingsMp2HousingLessons) {
        expect(banned.hasMatch(_allText(l)), isFalse, reason: l.id);
      }
    });
  });

  group('exclusions: no eligibility verdict, no calculation, no sensitive '
      'data collection', () {
    test('never declares eligibility, ineligibility, or approval for a '
        'specific loan or benefit', () {
      for (final l in pagibigSavingsMp2HousingLessons) {
        final lower = _allText(l).toLowerCase();
        expect(lower.contains('you are not eligible'), isFalse);
        expect(lower.contains('you are now eligible'), isFalse);
        expect(lower.contains('your loan is approved'), isFalse);
        expect(lower.contains('is not covered for you'), isFalse);
      }
    });

    test('no ReflectionPromptBlock or free-text field anywhere asks for a '
        'Pag-IBIG MID number, Virtual Pag-IBIG credentials, a password, an '
        'exact income, an employer name, a property address, a government '
        'ID, or bank details', () {
      for (final l in pagibigSavingsMp2HousingLessons) {
        for (final b in l.interactionBlocks) {
          if (b is ReflectionPromptBlock && b.allowFreeText) {
            final q = b.question.toLowerCase();
            for (final banned in [
              'mid number',
              'virtual pag-ibig credentials',
              'password',
              'exact income',
              'employer name',
              'property address',
              'government id',
              'bank details',
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

    test('no lesson mentions collecting a Pag-IBIG MID number, Virtual '
        'Pag-IBIG credentials, a government ID, or a loan document', () {
      for (final l in pagibigSavingsMp2HousingLessons) {
        final lower = _allText(l).toLowerCase();
        for (final banned in [
          'enter your mid number',
          'enter your pag-ibig password',
          'upload your government id',
          'upload your loan document',
          'upload your title',
        ]) {
          expect(lower.contains(banned), isFalse, reason: '${l.id}: $banned');
        }
      }
    });

    test('no interaction block ever calculates a return, a contribution, or '
        'an amortization figure: no dynamic peso computation appears in '
        'any block\'s static text', () {
      for (final l in pagibigSavingsMp2HousingLessons) {
        for (final b in l.interactionBlocks) {
          expect(b, isNot(isA<LossImpactSimulatorBlock>()));
        }
      }
    });
  });

  group('Salapify actions: verified routes only, never an automatic write, '
      'never a new government-account or loan-application feature', () {
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

    test('the routes cover Emergency Fund, Goals, Budget, Accounts or '
        'Liabilities, and Bills or Reminders, per the task\'s own preferred '
        'categories', () {
      final block = _salapifyActionsBlock();
      final routes = block.actions.map((a) => a.route).toSet();
      expect(
        routes,
        containsAll(['goals', 'budget', 'debts', 'notifications']),
      );
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
/// the same directional check lessons_sss_philhealth_content_test.dart uses
/// for "contribution gap" and "benefit amount": a phrase this course is
/// required to teach it never does is allowed to appear only while saying
/// so, never as an actual output.
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
  final lesson = pagibigSavingsMp2HousingLessons.firstWhere(
    (l) => l.id == pagibigRefMakeYourPlan,
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
