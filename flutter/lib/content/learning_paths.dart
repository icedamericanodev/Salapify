// The concrete learning-path registry: real LearningPath instances
// (content/learning_path.dart's types), as distinct from that file's own
// type definitions. Money Courses Phase 6 was the first path to carry real
// content, "Grow Your Money" with its pilot course "Are You Ready to
// Invest?" (lib/content/lessons_grow.dart). Phase 7A added this same path's
// second course, "Stocks and Bonds Without the Hype"
// (lib/content/lessons_stocks_bonds.dart). Phase 7B added a third course,
// "Deposits and Pooled Funds" (lib/content/lessons_deposits_pooled_funds.dart).
// Phase 8 adds a fourth course, "Crypto Without the Hype"
// (lib/content/lessons_crypto.dart), never modifying the pilot or any
// earlier course's own lesson ids.
//
// Phase 9 added a second path, "Protect Your Future", carrying its first
// real course, "Insurance Decoded" (lib/content/lessons_insurance.dart).
// Phase 10 added this path's second course, "SSS & PhilHealth Essentials"
// (lib/content/lessons_sss_philhealth.dart). Phase 11 adds this path's third
// course, "Pag-IBIG Savings & Housing" (lib/content/lessons_pagibig.dart),
// never modifying Insurance Decoded's or SSS & PhilHealth Essentials' own
// lesson ids. "Build Your Business" is still deliberately ABSENT here, not
// present as a comingSoon stub or an empty group. This phase's own catalog
// rule is "do not display empty government-benefit courses", and the
// smallest way to guarantee that, for this path and any future one, is to
// never construct an empty group at all: publishedLearningPaths below only
// has to filter on status.
//
// Phase 12 adds "Grow Your Money"'s fifth course, "Philippine Government
// Securities" (lib/content/lessons_ph_government_securities.dart), never
// modifying any earlier course in this path's own lesson ids.

import 'learning_path.dart';
import 'lesson_model.dart' show MoneyLesson;
import 'lessons_crypto.dart';
import 'lessons_deposits_pooled_funds.dart';
import 'lessons_grow.dart';
import 'lessons_insurance.dart';
import 'lessons_pagibig.dart';
import 'lessons_ph_government_securities.dart';
import 'lessons_sss_philhealth.dart';
import 'lessons_stocks_bonds.dart';

const List<LearningPath> learningPaths = [
  LearningPath(
    id: 'grow_your_money',
    title: 'Grow Your Money',
    shortDescription:
        'Start with whether your foundation, and your money, are ready for '
        'investing.',
    icon: 'growth',
    groups: [
      LearningPathGroup(
        id: 'investing_readiness',
        title: 'Are You Ready to Invest?',
        lessonIds: [
          investRefMoneyJob,
          investRefProtectBase,
          investRefGoalTimeAccess,
          investRefRiskComfortCapacity,
          investRefCard,
        ],
      ),
      LearningPathGroup(
        id: 'stocks_and_bonds',
        title: 'Stocks and Bonds Without the Hype',
        lessonIds: [
          sbOwnerOrLender,
          sbStockReturnsAndLosses,
          sbPriceIsNotValue,
          sbDiversificationAndConcentration,
          sbHowBondsWork,
          sbVerifyBeforeYouInvest,
        ],
        // Advisory only, the same "recommended, never a lock" contract
        // LearningPath.prerequisiteLessonIds already carries: nothing reads
        // this to gate opening a lesson here, a catalog screen decides what
        // to do with it. investing_readiness covers the readiness questions
        // (goal, timing, risk comfort vs capacity) this course builds on
        // without repeating.
        recommendedPriorGroupIds: ['investing_readiness'],
      ),
      LearningPathGroup(
        id: 'deposits_and_pooled_funds',
        title: 'Deposits and Pooled Funds',
        lessonIds: [
          dpDepositOrInvestment,
          dpTimeDepositsAndPdic,
          dpHowPooledFundsWork,
          dpUitfMutualFundEtf,
          dpReadAFactSheet,
          dpMatchProductToGoal,
        ],
        // Same advisory-only contract as stocks_and_bonds's own
        // recommendedPriorGroupIds above: investing_readiness is this
        // course's recommended prerequisite (the readiness questions this
        // course assumes), and stocks_and_bonds is optional recommended
        // preparation (this course stands on its own without it, but the
        // two courses share the ownership/lending-versus-depositing
        // distinction). Neither is a lock; lessonsForPath returns every
        // lesson regardless of any other group's progress.
        recommendedPriorGroupIds: ['investing_readiness', 'stocks_and_bonds'],
      ),
      LearningPathGroup(
        id: 'crypto_without_hype',
        title: 'Crypto Without the Hype',
        lessonIds: [
          cryptoRefWhatCryptoIs,
          cryptoRefVolatilityTotalLoss,
          cryptoRefCustodyIrreversibleMistakes,
          cryptoRefStablecoinsYieldLeverage,
          cryptoRefScamsProviderVerification,
          cryptoRefDecisionLab,
        ],
        // Same advisory-only contract as stocks_and_bonds's and
        // deposits_and_pooled_funds's own recommendedPriorGroupIds above:
        // investing_readiness is this course's recommended prerequisite
        // (the readiness questions this course assumes), and
        // stocks_and_bonds is optional recommended preparation (the
        // ownership/lending distinction this course builds on when
        // contrasting a crypto asset against a share). Neither is a lock;
        // lessonsForPath returns every lesson regardless of any other
        // group's progress. This course never promotes crypto ownership,
        // so it deliberately never recommends deposits_and_pooled_funds:
        // that course is about choosing a product, this one is about
        // recognizing risk, and the two are not a natural sequence.
        recommendedPriorGroupIds: ['investing_readiness', 'stocks_and_bonds'],
      ),
      LearningPathGroup(
        id: 'ph_government_securities',
        title: 'Philippine Government Securities',
        lessonIds: [
          gsLendingToGovernment,
          gsTypesOfSecurities,
          gsCouponYieldPriceMaturity,
          gsHowSecuritiesReachInvestors,
          gsRisksAndScamChecks,
          gsDecisionPlan,
        ],
        // Same advisory-only contract as every other group's own
        // recommendedPriorGroupIds above: investing_readiness covers the
        // readiness questions this course assumes, stocks_and_bonds covers
        // the owner-versus-lender distinction lesson 1 here builds on
        // without repeating, and deposits_and_pooled_funds covers the same
        // deposit-insurance boundary lesson 1 here also draws. Neither is a
        // lock; lessonsForPath returns every lesson regardless of any other
        // group's progress.
        recommendedPriorGroupIds: [
          'investing_readiness',
          'stocks_and_bonds',
          'deposits_and_pooled_funds',
        ],
      ),
    ],
    // Advisory only, per LearningPath.prerequisiteLessonIds's own contract:
    // nothing here blocks the path, a catalog screen just shows these as
    // "Recommended first". Both point at core lessons this course directly
    // builds on (the emergency-fund lesson and the card-interest lesson).
    prerequisiteLessonIds: ['emergency-fund', 'card-interest'],
    status: LearningPathStatus.published,
  ),
  LearningPath(
    id: 'protect_your_future',
    title: 'Protect Your Future',
    shortDescription:
        'Understand your protection needs and compare policy types before '
        'you talk to an insurer or agent.',
    icon: 'protected',
    groups: [
      LearningPathGroup(
        id: 'insurance_decoded',
        title: 'Insurance Decoded',
        lessonIds: [
          insuranceRefWhatItsFor,
          insuranceRefProtectionNeed,
          insuranceRefTermAndWholeLife,
          insuranceRefVulNoSalesPitch,
          insuranceRefReadThePolicy,
          insuranceRefVerifyCompareDecide,
        ],
      ),
      LearningPathGroup(
        id: 'sss_philhealth_benefits',
        title: 'SSS & PhilHealth Essentials',
        lessonIds: [
          sspRefTwoSafetyNets,
          sspRefSssMayHelp,
          sspRefCheckBeforeYouCount,
          sspRefHowCoverageWorks,
          sspRefPrimaryCareEarlier,
          sspRefSafetyNetPlan,
        ],
        // Advisory only, same contract as stocks_and_bonds's own
        // recommendedPriorGroupIds in grow_your_money above: insurance_decoded
        // is not a prerequisite this course depends on, but it is the same
        // path's first course, so a reader who has not seen it yet is
        // pointed there first. Nothing here blocks opening this course
        // directly.
        recommendedPriorGroupIds: ['insurance_decoded'],
      ),
      LearningPathGroup(
        id: 'pagibig_savings_mp2_housing',
        title: 'Pag-IBIG Savings & Housing',
        lessonIds: [
          pagibigRefThreeTools,
          pagibigRefCheckRegularSavings,
          pagibigRefMp2WithoutHype,
          pagibigRefMp2Readiness,
          pagibigRefHousingLoanCost,
          pagibigRefMakeYourPlan,
        ],
        // Advisory only, same contract as sss_philhealth_benefits's own
        // recommendedPriorGroupIds above: neither prior course is a
        // prerequisite this course depends on, but both are this same
        // path's earlier courses, so a reader who has not seen them yet is
        // pointed there first. Nothing here blocks opening this course
        // directly.
        recommendedPriorGroupIds: [
          'insurance_decoded',
          'sss_philhealth_benefits',
        ],
      ),
    ],
    // Advisory only, same contract as grow_your_money's own
    // prerequisiteLessonIds above: nothing here blocks the path, a catalog
    // screen just shows this as "Recommended first". Lesson 1 of this
    // course directly contrasts insurance against an emergency fund, so
    // the core emergency-fund lesson is the one natural prerequisite.
    prerequisiteLessonIds: ['emergency-fund'],
    status: LearningPathStatus.published,
  ),
];

/// Paths safe to list in a catalog: published only. A comingSoon or
/// retired path (neither exists yet in [learningPaths]) would never reach
/// here even if one were added later without checking this first.
List<LearningPath> get publishedLearningPaths => [
  for (final p in learningPaths)
    if (p.isAvailable) p,
];

/// A lesson paired with the path id that owns it, since expansion progress
/// is written per path (settings.expansionProgress) and a bare lesson id is
/// not enough to know which path's progress to touch.
class MoneyLessonWithPath {
  final String pathId;
  final MoneyLesson lesson;
  const MoneyLessonWithPath({required this.pathId, required this.lesson});
}

/// This path's lessons, in reading order, or an empty list for a path id
/// this file does not know content for yet. The one closed switch a second
/// path's content file adds a branch to, the same pattern
/// screens/learn.dart's own `_resolveAction` and
/// widgets/expansion_lesson_reader.dart's `_resolveGrowAction` already use
/// for "a small, explicit, growable set of known cases".
List<MoneyLesson> lessonsForPath(String pathId) => switch (pathId) {
  'grow_your_money' => [
    ...growYourMoneyLessons,
    ...stocksAndBondsLessons,
    ...depositsAndPooledFundsLessons,
    ...cryptoWithoutHypeLessons,
    ...phGovernmentSecuritiesLessons,
  ],
  'protect_your_future' => [
    ...insuranceDecodedLessons,
    ...sssPhilhealthBenefitsLessons,
    ...pagibigSavingsMp2HousingLessons,
  ],
  _ => const [],
};

/// Finds an expansion lesson (and its owning path id) by lesson id, across
/// every published path's own content. Null when not found, the same
/// fails-safe convention lessons.dart's own `lessonById` follows: an
/// unknown id is a safe no-op, never a crash. 'grow_your_money' and
/// 'protect_your_future' have content today; a third path's content file
/// gets a matching branch here when it ships.
MoneyLessonWithPath? expansionLessonById(String id) {
  for (final lesson in [
    ...growYourMoneyLessons,
    ...stocksAndBondsLessons,
    ...depositsAndPooledFundsLessons,
    ...cryptoWithoutHypeLessons,
    ...phGovernmentSecuritiesLessons,
  ]) {
    if (lesson.id == id) {
      return MoneyLessonWithPath(pathId: 'grow_your_money', lesson: lesson);
    }
  }
  for (final lesson in [
    ...insuranceDecodedLessons,
    ...sssPhilhealthBenefitsLessons,
    ...pagibigSavingsMp2HousingLessons,
  ]) {
    if (lesson.id == id) {
      return MoneyLessonWithPath(pathId: 'protect_your_future', lesson: lesson);
    }
  }
  return null;
}
