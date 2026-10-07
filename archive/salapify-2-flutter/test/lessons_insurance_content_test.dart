// Money Courses Phase 9 content contract: the "Protect Your Future" learning
// path's first course, "Insurance Decoded" (lib/content/lessons_insurance.dart,
// lib/content/learning_paths.dart). Proves this course is registered
// correctly, stays fully isolated from the core 22 lessons and every Grow
// Your Money course, passes the house rules (no em/en dash, no named
// insurer/agent/policy, no guaranteed-outcome language, no personalized
// recommendation, no health/beneficiary/credential collection) plus the
// Phase 4 content policy validator, and never recommends a specific policy
// or product.
//
// Mirrors test/lessons_crypto_content_test.dart's own structure on purpose,
// the established shape for a Money Courses content contract test.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/content/interaction_blocks.dart';
import 'package:salapify/content/learning_path.dart';
import 'package:salapify/content/learning_paths.dart';
import 'package:salapify/content/lesson_blocks.dart';
import 'package:salapify/content/lesson_model.dart';
import 'package:salapify/content/lessons.dart' as core;
import 'package:salapify/content/lessons_crypto.dart';
import 'package:salapify/content/lessons_deposits_pooled_funds.dart';
import 'package:salapify/content/lessons_grow.dart';
import 'package:salapify/content/lessons_insurance.dart';
import 'package:salapify/content/lessons_ph_government_securities.dart';
import 'package:salapify/content/lessons_stocks_bonds.dart';
import 'package:salapify/money/expansion_content_policy.dart';
import 'package:salapify/money/interaction_completion.dart';

final _ref = DateTime.utc(2026, 8, 4);

const _stableLessonIds = [
  insuranceRefWhatItsFor,
  insuranceRefProtectionNeed,
  insuranceRefTermAndWholeLife,
  insuranceRefVulNoSalesPitch,
  insuranceRefReadThePolicy,
  insuranceRefVerifyCompareDecide,
];

const _timeSensitiveLessonIds = [
  insuranceRefReadThePolicy,
  insuranceRefVerifyCompareDecide,
];

const _pilotLessonIds = [
  investRefMoneyJob,
  investRefProtectBase,
  investRefGoalTimeAccess,
  investRefRiskComfortCapacity,
  investRefCard,
];

const _stocksBondsLessonIds = [
  sbOwnerOrLender,
  sbStockReturnsAndLosses,
  sbPriceIsNotValue,
  sbDiversificationAndConcentration,
  sbHowBondsWork,
  sbVerifyBeforeYouInvest,
];

const _depositsLessonIds = [
  dpDepositOrInvestment,
  dpTimeDepositsAndPdic,
  dpHowPooledFundsWork,
  dpUitfMutualFundEtf,
  dpReadAFactSheet,
  dpMatchProductToGoal,
];

const _cryptoLessonIds = [
  cryptoRefWhatCryptoIs,
  cryptoRefVolatilityTotalLoss,
  cryptoRefCustodyIrreversibleMistakes,
  cryptoRefStablecoinsYieldLeverage,
  cryptoRefScamsProviderVerification,
  cryptoRefDecisionLab,
];

// Phase 12 added a fifth grow_your_money course, "Philippine Government
// Securities" (see test/lessons_ph_government_securities_content_test.dart
// for its own registration contract).
const _govSecuritiesLessonIds = [
  gsLendingToGovernment,
  gsTypesOfSecurities,
  gsCouponYieldPriceMaturity,
  gsHowSecuritiesReachInvestors,
  gsRisksAndScamChecks,
  gsDecisionPlan,
];

void main() {
  group('registration', () {
    test('protect_your_future is published, with Insurance Decoded as its '
        'first course', () {
      final path = learningPaths.firstWhere(
        (p) => p.id == 'protect_your_future',
      );
      expect(path.status, LearningPathStatus.published);
      expect(path.isAvailable, isTrue);
      // Phase 10 added a second course, "SSS & PhilHealth Essentials"
      // (see test/lessons_sss_philhealth_content_test.dart for its own
      // registration contract); Insurance Decoded stays this path's first
      // group, unmoved and unmodified.
      expect(path.groups.first.id, 'insurance_decoded');
      final group = path.groups.first;
      expect(group.title, 'Insurance Decoded');
      expect(group.lessonIds, _stableLessonIds);
      expect(path.lessonIds, containsAllInOrder(_stableLessonIds));
    });

    test('publishedLearningPaths shows protect_your_future (Phase 13 later '
        'adds a third path, build_your_business, alongside it)', () {
      expect(
        publishedLearningPaths.map((p) => p.id),
        contains('protect_your_future'),
      );
    });

    test('six stable lesson ids, in reading order', () {
      expect(
        insuranceDecodedLessons.map((l) => l.id).toList(),
        _stableLessonIds,
      );
    });

    test('lesson ids are unique', () {
      expect(_stableLessonIds.toSet().length, 6);
    });

    test('every lesson is registered under the insurance_decoded trackId', () {
      for (final l in insuranceDecodedLessons) {
        expect(l.trackId, 'insurance_decoded');
      }
    });

    test('expansionLessonById resolves a lesson from this course to the '
        'protect_your_future path', () {
      final found = expansionLessonById(insuranceRefWhatItsFor);
      expect(found, isNotNull);
      expect(found!.pathId, 'protect_your_future');
      expect(found.lesson.id, insuranceRefWhatItsFor);
    });

    test('lessonsForPath includes every Insurance Decoded lesson, in order, '
        'for protect_your_future', () {
      final lessons = lessonsForPath('protect_your_future');
      expect(
        lessons.map((l) => l.id).toList(),
        containsAllInOrder(_stableLessonIds),
      );
    });
  });

  group('isolation from the core 22 and every Grow Your Money course', () {
    test('core lesson list is untouched: still 22 lessons, four courses', () {
      expect(core.lessons.length, 22);
      expect(core.courseTracks.length, 4);
    });

    test('grow_your_money is untouched: still all five of its own courses '
        '(Phase 12 added Philippine Government Securities as a fifth, none '
        'of these earlier four moved or changed)', () {
      final growPath = learningPaths.firstWhere(
        (p) => p.id == 'grow_your_money',
      );
      expect(growPath.groups.length, 5);
      expect(growYourMoneyLessons.map((l) => l.id).toList(), _pilotLessonIds);
      expect(
        stocksAndBondsLessons.map((l) => l.id).toList(),
        _stocksBondsLessonIds,
      );
      expect(
        depositsAndPooledFundsLessons.map((l) => l.id).toList(),
        _depositsLessonIds,
      );
      expect(
        cryptoWithoutHypeLessons.map((l) => l.id).toList(),
        _cryptoLessonIds,
      );
      expect(
        phGovernmentSecuritiesLessons.map((l) => l.id).toList(),
        _govSecuritiesLessonIds,
      );
    });

    test('none of the new ids appear in the core flat lesson list', () {
      final coreIds = core.lessons.map((l) => l['id']).toSet();
      for (final id in _stableLessonIds) {
        expect(coreIds.contains(id), isFalse, reason: '$id leaked into core');
      }
    });

    test('none of the new ids collide with any Grow Your Money course\'s '
        'ids', () {
      final growIds = {
        ..._pilotLessonIds,
        ..._stocksBondsLessonIds,
        ..._depositsLessonIds,
        ..._cryptoLessonIds,
        ..._govSecuritiesLessonIds,
      };
      for (final id in _stableLessonIds) {
        expect(growIds.contains(id), isFalse);
      }
    });

    test('lessonsForPath("grow_your_money") is unaffected', () {
      final lessons = lessonsForPath('grow_your_money');
      expect(
        lessons.length,
        _pilotLessonIds.length +
            _stocksBondsLessonIds.length +
            _depositsLessonIds.length +
            _cryptoLessonIds.length +
            _govSecuritiesLessonIds.length,
      );
      for (final id in _stableLessonIds) {
        expect(lessons.map((l) => l.id), isNot(contains(id)));
      }
    });
  });

  group('content policy validator (Phase 4)', () {
    test('every lesson has zero validation errors', () {
      for (final lesson in insuranceDecodedLessons) {
        final result = validateExpansionLesson(lesson, referenceDate: _ref);
        expect(
          isPublishable(result),
          isTrue,
          reason: '${lesson.id}: ${result.errors.join('; ')}',
        );
      }
    });

    test('every lesson carries ContentTopic.insuranceOrVul, making it '
        'regulated content', () {
      for (final lesson in insuranceDecodedLessons) {
        expect(
          lesson.topics,
          contains(ContentTopic.insuranceOrVul),
          reason: '${lesson.id} is missing ContentTopic.insuranceOrVul',
        );
      }
    });

    test('lessons 5 and 6 (regulatory, licensed-agent, consumer-rights, and '
        'cooling-off content) are classified high volatility; lessons 1 to '
        '4 are annual', () {
      for (final lesson in insuranceDecodedLessons) {
        final expected = _timeSensitiveLessonIds.contains(lesson.id)
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
        for (final lesson in insuranceDecodedLessons) {
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
      for (final lesson in insuranceDecodedLessons) {
        expect(
          lesson.blocks.whereType<OfficialSourceBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no OfficialSourceBlock',
        );
      }
    });

    test('verified and review-due dates are present and sane', () {
      for (final lesson in insuranceDecodedLessons) {
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

    test('every source cites the Insurance Commission, never insurer '
        'marketing or an agent presentation', () {
      for (final lesson in insuranceDecodedLessons) {
        for (final s in lesson.sources) {
          expect(s.agency, 'Insurance Commission');
        }
      }
    });

    test('Lesson 5 and Lesson 6 cite consumer-protection or verification '
        'sources, never a static licensed-agent list embedded directly', () {
      for (final id in _timeSensitiveLessonIds) {
        final l = insuranceDecodedLessons.firstWhere((l) => l.id == id);
        final urls = l.blocks
            .whereType<OfficialSourceBlock>()
            .map((b) => b.canonicalUrl)
            .toList();
        expect(urls, isNotEmpty);
      }
    });
  });

  group('risk warnings and educational boundary', () {
    test('every lesson carries a risk-warning block', () {
      for (final lesson in insuranceDecodedLessons) {
        expect(
          lesson.blocks.whereType<RiskWarningBlock>(),
          isNotEmpty,
          reason: '${lesson.id} has no RiskWarningBlock',
        );
      }
    });

    test('every lesson carries the educational-boundary block', () {
      for (final lesson in insuranceDecodedLessons) {
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
      for (final lesson in insuranceDecodedLessons) {
        expect(
          lesson.interactionBlocks.where((b) => b.requiredForCompletion),
          isNotEmpty,
          reason: '${lesson.id} has no required interaction',
        );
      }
    });

    test('every lesson has unique interaction block ids', () {
      for (final lesson in insuranceDecodedLessons) {
        expect(hasUniqueBlockIds(lesson.interactionBlocks), isTrue);
      }
    });

    test('every lesson has a scenario-based mastery check with an '
        'explanation', () {
      for (final lesson in insuranceDecodedLessons) {
        final check = lesson.check;
        expect(check, isNotNull, reason: '${lesson.id} has no mastery check');
        expect(check!.isValid, isTrue);
        expect(check.explanation, isNotEmpty);
      }
    });
  });

  group('course-specific interaction coverage (the task\'s own list)', () {
    MoneyLesson byId(String id) =>
        insuranceDecodedLessons.firstWhere((l) => l.id == id);

    test('lesson 1 sorts insurance/savings/emergency fund, carries the '
        'required myth, scenario choices, and a risk warning', () {
      final l = byId(insuranceRefWhatItsFor);
      final sort = l.interactionBlocks.whereType<CategorizeBlock>().first;
      expect(
        sort.buckets.map((b) => b.label),
        containsAll(['Insurance', 'Savings', 'Emergency fund']),
      );
      final myth = l.interactionBlocks.whereType<MythOrFactBlock>().firstWhere(
        (m) =>
            m.blockId ==
            'insurance-what-its-for-myth-premiums-cover-everything',
      );
      expect(
        myth.statement,
        'Paying premiums means every future claim will be covered.',
      );
      expect(myth.correctAnswer, MythOrFactAnswer.myth);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
      expect(l.blocks.whereType<RiskWarningBlock>(), isNotEmpty);
    });

    test('lesson 2 is a reflection worksheet: household scenarios, a needs '
        'checklist, and a reflection, never a coverage number', () {
      final l = byId(insuranceRefProtectionNeed);
      expect(l.interactionBlocks.whereType<ScenarioChoiceBlock>(), isNotEmpty);
      expect(l.interactionBlocks.whereType<ChecklistBlock>(), isNotEmpty);
      expect(
        l.interactionBlocks.whereType<ReflectionPromptBlock>(),
        isNotEmpty,
      );
      // Never a recommended coverage amount. "Underinsured" is allowed to
      // appear only as part of teaching the rule against using it (the task
      // requires Lesson 2 to say it never labels anyone that way), so this
      // checks every occurrence sits near a negation rather than banning
      // the word outright.
      final all = _allText(l).toLowerCase();
      final negation = RegExp(
        r"\b(never|not|no|nothing|cannot|can't|without)\b",
        caseSensitive: false,
      );
      for (final phrase in [
        'underinsured',
        'recommended coverage',
        'recommended amount',
      ]) {
        for (final m in RegExp(phrase).allMatches(all)) {
          final windowStart = (m.start - 45).clamp(0, all.length);
          final before = all.substring(windowStart, m.start);
          expect(
            negation.hasMatch(before),
            isTrue,
            reason:
                'lesson 2 uses "$phrase" without a nearby negation: '
                '"${all.substring(windowStart, (m.end + 20).clamp(0, all.length))}"',
          );
        }
      }
      // Never asks for a beneficiary's name, a health record, a diagnosis,
      // or a government id.
      for (final banned in [
        'beneficiary\'s name',
        'beneficiary name',
        'diagnosis',
        'medical record',
        'government id number',
      ]) {
        expect(all.contains(banned), isFalse, reason: 'asks for $banned');
      }
    });

    test('lesson 3 compares term and whole life neutrally, matches needs to '
        'questions, and never ends a scenario with a product '
        'recommendation', () {
      final l = byId(insuranceRefTermAndWholeLife);
      final comparison = l.interactionBlocks
          .whereType<ComparisonBlock>()
          .firstWhere((c) => c.blockId == 'insurance-term-whole-comparison');
      expect(comparison.items.map((i) => i.id), ['term', 'whole-life']);
      final match = l.interactionBlocks.whereType<CategorizeBlock>().firstWhere(
        (c) => c.blockId == 'insurance-term-whole-question-matching',
      );
      expect(match.buckets.length, 4);
      expect(l.interactionBlocks.whereType<MythOrFactBlock>().length, 2);
      final scenarios = l.interactionBlocks.whereType<ScenarioChoiceBlock>();
      expect(scenarios, isNotEmpty);
      for (final s in scenarios) {
        for (final o in s.options) {
          expect(
            o.label.toLowerCase().contains('is the better choice'),
            isFalse,
          );
        }
      }
    });

    test('lesson 4 follows a fictional premium through allocations, sorts '
        'guaranteed versus illustrated, and carries a fictional VUL policy '
        'summary', () {
      final l = byId(insuranceRefVulNoSalesPitch);
      expect(l.blocks.whereType<DiagramBlock>(), isNotEmpty);
      final charges = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere((c) => c.blockId == 'insurance-vul-charge-categories');
      expect(
        charges.buckets.map((b) => b.label),
        containsAll([
          'Insurance charges',
          'Administrative charges',
          'Fund-management charges',
          'Surrender or withdrawal charges',
          'Rider charges',
        ]),
      );
      final guaranteedVsIllustrated = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere(
            (c) => c.blockId == 'insurance-vul-guaranteed-vs-illustrated',
          );
      expect(
        guaranteedVsIllustrated.buckets.map((b) => b.id),
        containsAll(['guaranteed', 'illustrated']),
      );
      expect(
        l.interactionBlocks.whereType<ChecklistBlock>().where(
          (c) => c.blockId == 'insurance-vul-policy-summary-checklist',
        ),
        isNotEmpty,
      );
      expect(l.interactionBlocks.whereType<MythOrFactBlock>(), isNotEmpty);
      // No named insurer, fund, or current charge rate anywhere.
      final all = _allText(l).toLowerCase();
      expect(RegExp(r'\d+(\.\d+)?\s?%').hasMatch(all), isFalse);
    });

    test('lesson 5 highlights guaranteed sections, finds the exclusion, '
        'compares two fictional summaries, and offers a questions '
        'checklist, with no specific cooling-off day count asserted', () {
      final l = byId(insuranceRefReadThePolicy);
      expect(
        l.interactionBlocks.whereType<CategorizeBlock>().where(
          (c) => c.blockId == 'insurance-read-policy-guaranteed-highlight',
        ),
        isNotEmpty,
      );
      final exclusionActivity = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere(
            (c) => c.blockId == 'insurance-read-policy-find-exclusion',
          );
      expect(exclusionActivity.buckets.map((b) => b.id), contains('exclusion'));
      final comparison = l.interactionBlocks
          .whereType<ComparisonBlock>()
          .firstWhere(
            (c) => c.blockId == 'insurance-read-policy-compare-two-summaries',
          );
      expect(comparison.items.length, 2);
      expect(l.interactionBlocks.whereType<ChecklistBlock>(), isNotEmpty);
      // No specific number of days stated for a cooling-off or free-look
      // period anywhere in this lesson.
      final all = _allText(l).toLowerCase();
      expect(RegExp(r'\d+[\s-]day').hasMatch(all), isFalse);
      expect(l.governance.volatility, ContentVolatility.high);
    });

    test('lesson 6 has the agent-verification checklist, a pressure red-flag '
        'challenge, a fictional comparison lab, "what would you ask next" '
        'scenarios, and the final review with the task\'s own three result '
        'strings', () {
      final l = byId(insuranceRefVerifyCompareDecide);
      final agentChecklist = l.interactionBlocks
          .whereType<ChecklistBlock>()
          .firstWhere((c) => c.blockId == 'insurance-verify-agent-checklist');
      expect(agentChecklist.requiredForCompletion, isTrue);
      final redFlags = l.interactionBlocks
          .whereType<CategorizeBlock>()
          .firstWhere(
            (c) => c.blockId == 'insurance-verify-pressure-red-flags',
          );
      expect(
        redFlags.buckets.map((b) => b.label),
        containsAll(['Red flag', 'Reasonable']),
      );
      expect(l.interactionBlocks.whereType<ComparisonBlock>(), isNotEmpty);
      final whatWouldYouAsk = l.interactionBlocks
          .whereType<ScenarioChoiceBlock>()
          .where((s) => s.scenarioTitle.contains('What would you ask next'));
      expect(whatWouldYouAsk.length, 3);
      final review = l.interactionBlocks
          .whereType<RiskReviewChecklistBlock>()
          .first;
      expect(review.isValid, isTrue);
      expect(review.requiredForCompletion, isTrue);
      expect(review.foundationSummary, 'More information is needed');
      expect(review.partialSummary, 'Review the policy details');
      expect(review.completeSummary, 'You have completed a protection review');
      expect(l.interactionBlocks.whereType<SalapifyActionsBlock>(), isNotEmpty);
    });
  });

  group('house rules: plain text content', () {
    test('no em or en dashes anywhere, content blocks or interactions', () {
      for (final l in insuranceDecodedLessons) {
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
      for (final l in insuranceDecodedLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} reads as a guaranteed-outcome claim',
        );
      }
    });

    test('no named real insurer, agent, or policy anywhere', () {
      const bannedNames = [
        'Sun Life',
        'Manulife',
        'AXA',
        'Pru Life',
        'FWD',
        'Philam Life',
        'Insular Life',
        'BPI-AIA',
        'Cocolife',
      ];
      for (final l in insuranceDecodedLessons) {
        final all = _allText(l);
        for (final name in bannedNames) {
          expect(
            all.contains(name),
            isFalse,
            reason: '${l.id} names a real insurer: $name',
          );
        }
      }
    });

    test('never declares the reader officially approved, covered, or '
        'eligible', () {
      final banned = RegExp(
        r"\byou(?:'re| are)\b[^.]{0,20}\b(officially\s+)?(approved|covered|"
        r'eligible|qualified)\b',
        caseSensitive: false,
      );
      for (final l in insuranceDecodedLessons) {
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
        'password, PIN, OTP, seed phrase, or government-account '
        'credential', () {
      final banned = RegExp(
        r'\b(enter|type|share|provide|send)\s+your\s+(password|pin|otp|'
        r'government[\s-]?(id|account)\s*credentials?)\b',
        caseSensitive: false,
      );
      for (final l in insuranceDecodedLessons) {
        expect(
          banned.hasMatch(_allText(l)),
          isFalse,
          reason: '${l.id} asks for a credential',
        );
      }
    });

    test('the task\'s own never-output product-recommendation phrases never '
        'appear anywhere in this course\'s rendered text', () {
      // "Approved" and "Suitable" are deliberately not in this list: the
      // task requires Lesson 1 to teach that a premium does not guarantee
      // a claim will be "approved" (a myth to reject, not an output this
      // course produces) and Lesson 4 to teach that a license does not
      // make a recommendation "suitable" (also a myth to reject). The
      // task's own "Never output" list sits directly under Lesson 6's
      // result styles, scoping it to the checklist's own verdict labels;
      // see the dedicated result-string test below for that narrower rule.
      const bannedPhrases = [
        'best policy',
        'recommended insurer',
        'buy term',
        'buy vul',
        'avoid vul',
      ];
      for (final l in insuranceDecodedLessons) {
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

    test('the final review\'s three result strings never say Approved or '
        'Suitable, or any other verdict word this course never outputs', () {
      final review = insuranceDecodedLessons
          .firstWhere((l) => l.id == insuranceRefVerifyCompareDecide)
          .interactionBlocks
          .whereType<RiskReviewChecklistBlock>()
          .first;
      for (final s in [
        review.foundationSummary,
        review.partialSummary,
        review.completeSummary,
      ]) {
        final lower = s.toLowerCase();
        for (final banned in [
          'best policy',
          'recommended insurer',
          'approved',
          'suitable',
        ]) {
          expect(
            lower.contains(banned),
            isFalse,
            reason: '"$s" uses "$banned"',
          );
        }
      }
    });
  });

  group('exclusions: no recommendation, no sensitive data collection', () {
    test('never recommends a specific policy type as the checklist '
        'outcome', () {
      for (final l in insuranceDecodedLessons) {
        final lower = _allText(l).toLowerCase();
        expect(lower.contains('you should buy'), isFalse);
        expect(lower.contains('go with term'), isFalse);
        expect(lower.contains('go with whole life'), isFalse);
        expect(lower.contains('go with vul'), isFalse);
      }
    });

    test('never mentions medical underwriting, health records, or a '
        'diagnosis', () {
      for (final l in insuranceDecodedLessons) {
        final lower = _allText(l).toLowerCase();
        for (final banned in [
          'medical underwriting',
          'medical exam result',
          'diagnosis',
        ]) {
          expect(lower.contains(banned), isFalse, reason: '${l.id}: $banned');
        }
      }
    });

    test('no ReflectionPromptBlock anywhere asks for a beneficiary name, a '
        'health detail, a policy credential, or a government id', () {
      for (final l in insuranceDecodedLessons) {
        for (final b in l.interactionBlocks) {
          if (b is ReflectionPromptBlock && b.allowFreeText) {
            final q = b.question.toLowerCase();
            for (final banned in [
              'beneficiary',
              'health',
              'diagnosis',
              'password',
              'government id',
              'policy number',
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
  });

  group('Salapify actions: verified routes only, never an automatic write', () {
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

    test('never contacts an agent or purchases insurance automatically', () {
      // "purchase" and "buy a policy" are allowed to appear only negated
      // (e.g. "never purchases any policy"), the same directional check the
      // credential-request house rule above uses, since Lesson 6's own
      // action descriptions are required to say explicitly that nothing is
      // purchased automatically.
      final negation = RegExp(
        r"\b(never|not|no|nothing|cannot|can't|without)\b",
        caseSensitive: false,
      );
      final block = _salapifyActionsBlock();
      for (final action in block.actions) {
        final lower = '${action.label} ${action.description}'.toLowerCase();
        expect(
          lower.contains('contact an agent'),
          isFalse,
          reason: '${action.id} mentions contacting an agent',
        );
        for (final phrase in ['purchase', 'buy a policy']) {
          for (final m in RegExp(phrase).allMatches(lower)) {
            final windowStart = (m.start - 45).clamp(0, lower.length);
            final before = lower.substring(windowStart, m.start);
            expect(
              negation.hasMatch(before),
              isTrue,
              reason:
                  '${action.id} mentions "$phrase" without a nearby '
                  'negation',
            );
          }
        }
      }
    });

    test('the block is never required to finish the lesson', () {
      final block = _salapifyActionsBlock();
      expect(block.requiredForCompletion, isFalse);
    });
  });
}

SalapifyActionsBlock _salapifyActionsBlock() {
  final lesson = insuranceDecodedLessons.firstWhere(
    (l) => l.id == insuranceRefVerifyCompareDecide,
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
