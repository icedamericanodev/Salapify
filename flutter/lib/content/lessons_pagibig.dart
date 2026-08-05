// Money Courses Phase 11: "Protect Your Future" learning path's third course,
// "Pag-IBIG Savings & Housing" (course id 'pagibig_savings_mp2_housing').
// Built the same way Phase 9's "Insurance Decoded" and Phase 10's "SSS &
// PhilHealth Essentials" were: the already shipped architecture only
// (governance metadata, official-source and risk-warning blocks, Phase 5
// interaction blocks), nothing new added to the core model.
//
// This course teaches the high-level shape of three separate Pag-IBIG
// tools (Regular Savings, MP2 Savings, and housing finance), what to verify
// before counting on any of them, and a short, safe next step. It never
// recommends MP2 as suitable for a specific reader, never determines
// housing-loan eligibility or approval chances, never calculates official
// returns, contributions, or loan payments, and never claims Salapify is
// affiliated with or represents Pag-IBIG Fund. Every Salapify action offered
// at the end opens an existing, unrelated screen manually (Goals, Budget,
// Debts, Notifications and security); nothing here creates a government
// account, opens a Pag-IBIG account, applies for a loan, or calculates a
// benefit.
//
// House rules, same as the other Protect Your Future and Grow Your Money
// courses: plain English, no em or en dash, no guaranteed-outcome or
// eligibility-verdict language, no personalized recommendation, no
// affiliation claim, and no sensitive field ever requested or stored
// (Pag-IBIG MID number, Virtual Pag-IBIG credentials, passwords or OTPs,
// exact income, employer identity, property address, government IDs, loan
// application documents, title documents, bank details, or beneficiary
// information).
//
// Content topic: ContentTopic.governmentBenefitEligibility on every lesson,
// which activates the Phase 4 validator's mandatory official-source,
// risk-warning, and educational-boundary checks. Lessons 2, 3, 4, and 5 are
// classified ContentVolatility.high with a shorter review cycle, per this
// phase's own instruction to treat contribution amounts, eligibility rules,
// MP2 maturity and withdrawal rules, dividend rates, housing-loan limits,
// interest and repricing rates, loan terms, required contribution periods,
// documentary requirements, and application procedures as time-sensitive.
// Lessons 1 and 6 are classified ContentVolatility.annual: general structure
// that changes slowly.
//
// No contribution amount, dividend rate, loan-rate table, loan limit, case
// rate, or projected return is hardcoded anywhere in this file. Every such
// figure is time sensitive and controlled by Pag-IBIG Fund's own current
// rules, so this content always points at the official current source
// instead, per this phase's own instruction and per the Phase 4 validator's
// own "as of" figure check.
//
// Sources: the six official pages this phase's task named as the starting
// set (Pag-IBIG Fund, the Pag-IBIG Transparency Portal, Virtual Pag-IBIG,
// the Affordable Housing Loan page, the Official Amortization Calculator,
// and the Official Housing Forms page). The live pagibigfund.gov.ph site
// returned HTTP 403 to this session's automated fetch (a bot-protection
// wall, not a missing page); each URL above was confirmed to exist and to
// belong to the official pagibigfund.gov.ph or open.gov.ph domain through a
// search of that same domain, per this phase's own contingency instruction
// to fall back to a confirmed official page rather than an unofficial
// source when direct automated access is blocked. No blog, news summary,
// influencer post, forum, social media post, property website, bank,
// broker, or unofficial calculator was used as a factual source. Every
// structural claim in this file (that Regular Savings, MP2 Savings, and
// housing finance are three separate Pag-IBIG tools; that MP2 is voluntary
// and separate from Regular Savings; that a housing loan carries interest,
// repricing, and a term; and so on) is a well established, slow-changing
// fact about how Pag-IBIG Fund is structured, not a volatile figure; every
// volatile figure (a rate, a limit, a period, a requirement) is deliberately
// left out and pointed at the official source instead. This course's
// regulatory framing was reviewed by the legal-compliance-counsel agent
// before shipping (see governance.reviewerId below).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

const _pagibigAgency = 'Pag-IBIG Fund';

const _pagibigMainTitle = 'Pag-IBIG Fund';
const _pagibigMainUrl = 'https://www.pagibigfund.gov.ph/';
const _pagibigMainVerified = '2026-08';
const _pagibigMain = LessonSourceInfo(
  agency: _pagibigAgency,
  title: _pagibigMainTitle,
  canonicalUrl: _pagibigMainUrl,
  lastVerifiedDate: _pagibigMainVerified,
);

const _pagibigTransparencyTitle = 'Pag-IBIG Transparency Portal';
const _pagibigTransparencyUrl = 'https://open.gov.ph/pagibig';
const _pagibigTransparencyVerified = '2026-08';
const _pagibigTransparency = LessonSourceInfo(
  agency: _pagibigAgency,
  title: _pagibigTransparencyTitle,
  canonicalUrl: _pagibigTransparencyUrl,
  lastVerifiedDate: _pagibigTransparencyVerified,
);

const _virtualPagibigTitle = 'Virtual Pag-IBIG';
const _virtualPagibigUrl = 'https://yourvirtualpagibig.pagibigfund.gov.ph/';
const _virtualPagibigVerified = '2026-08';
const _virtualPagibig = LessonSourceInfo(
  agency: _pagibigAgency,
  title: _virtualPagibigTitle,
  canonicalUrl: _virtualPagibigUrl,
  lastVerifiedDate: _virtualPagibigVerified,
);

const _affordableHousingLoanTitle = 'Affordable Housing Loan';
const _affordableHousingLoanUrl =
    'https://pagibigfund.gov.ph/AffordableHousingLoan.html';
const _affordableHousingLoanVerified = '2026-08';
const _affordableHousingLoan = LessonSourceInfo(
  agency: _pagibigAgency,
  title: _affordableHousingLoanTitle,
  canonicalUrl: _affordableHousingLoanUrl,
  lastVerifiedDate: _affordableHousingLoanVerified,
);

const _amortCalculatorTitle = 'Official Amortization Calculator';
const _amortCalculatorUrl = 'https://pagibigfund.gov.ph/amort/';
const _amortCalculatorVerified = '2026-08';
const _amortCalculator = LessonSourceInfo(
  agency: _pagibigAgency,
  title: _amortCalculatorTitle,
  canonicalUrl: _amortCalculatorUrl,
  lastVerifiedDate: _amortCalculatorVerified,
);

const _housingFormsTitle = 'Official Housing Forms';
const _housingFormsUrl = 'https://pagibigfund.gov.ph/forms_housing.html';
const _housingFormsVerified = '2026-08';
const _housingForms = LessonSourceInfo(
  agency: _pagibigAgency,
  title: _housingFormsTitle,
  canonicalUrl: _housingFormsUrl,
  lastVerifiedDate: _housingFormsVerified,
);

// General, structural governance: annual review, matching the general
// product-education default the rest of the expansion content uses.
const _governanceAnnual = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'LCC',
);

// Contribution, MP2, and housing-loan content: a shorter review window, per
// this phase's own instruction to treat that category of fact as
// time-sensitive.
const _governanceHigh = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-02',
  reviewerId: 'LCC',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel: 'Pag-IBIG Fund',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form by the same convention every other Money
/// Courses lesson id uses. Never reused for a different lesson once a
/// learner has real progress recorded against one.
const pagibigRefThreeTools = 'pagibig-three-tools';
const pagibigRefCheckRegularSavings = 'pagibig-check-regular-savings';
const pagibigRefMp2WithoutHype = 'pagibig-mp2-without-hype';
const pagibigRefMp2Readiness = 'pagibig-mp2-readiness';
const pagibigRefHousingLoanCost = 'pagibig-housing-loan-cost';
const pagibigRefMakeYourPlan = 'pagibig-make-your-plan';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// list: the "X of 22" figure on the core Learn screen must never move
/// because of this file (see test/lessons_pagibig_content_test.dart).
const List<MoneyLesson> pagibigSavingsMp2HousingLessons = [
  _threePagibigTools,
  _checkYourRegularSavings,
  _mp2WithoutTheHype,
  _isYourMoneyReadyForMp2,
  _theRealCostOfAHousingLoan,
  _makeYourPagibigPlan,
];

// ---------------------------------------------------------------------------
// Lesson 1: Three Pag-IBIG Tools
// ---------------------------------------------------------------------------

const _threePagibigTools = MoneyLesson(
  id: pagibigRefThreeTools,
  trackId: 'pagibig_savings_mp2_housing',
  title: 'Three Pag-IBIG Tools',
  icon: 'balance',
  minutes: 3,
  summary:
      'Regular Savings, MP2 Savings, and housing finance solve different '
      'problems. Membership alone never means every one of them fits you.',
  objective:
      'Tell Regular Savings, MP2 Savings, and housing finance apart, and '
      'know which is worth starting with for a given situation.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_pagibigMain, _pagibigTransparency, _affordableHousingLoan],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Pag-IBIG Fund runs three separate tools. Regular Savings is the '
            'savings program almost every covered member already has, built '
            'from posted contributions over time. MP2 Savings is a '
            'separate, voluntary savings program a member may choose to '
            'open on top of Regular Savings. Housing finance is a '
            'different tool again, a loan a member may apply for to buy, '
            'build, or improve a home, under Pag-IBIG\'s own current rules.',
        'Being a Pag-IBIG member does not automatically mean every one of '
            'these three tools fits a given situation, and it does not '
            'mean a housing loan will be approved. Each tool answers a '
            'different question, and matching a situation to the right one '
            'is the useful first step.',
        'Sometimes none of the three is the right fit. An emergency that '
            'needs cash right away is usually better handled with money '
            'that is already liquid, not through any of these three.',
      ],
    ),
    NuggetsBlock([
      'Regular Savings answers "what have I already set aside". MP2 '
          'Savings answers "do I want to set aside more, separately, for '
          'later". Housing finance answers "can I borrow to buy, build, or '
          'improve a home".',
      'Another option may fit better than any of these three, especially '
          'for money that needs to stay liquid.',
    ]),
    RiskWarningBlock(
      title: 'Membership alone does not mean every option fits',
      text:
          'Being a Pag-IBIG member never means every one of these three '
          'tools fits a given situation, and it never means a housing loan '
          'will be approved. Each tool has its own current rules.',
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _pagibigMainTitle,
      canonicalUrl: _pagibigMainUrl,
      lastVerifiedDate: _pagibigMainVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _pagibigTransparencyTitle,
      canonicalUrl: _pagibigTransparencyUrl,
      lastVerifiedDate: _pagibigTransparencyVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _affordableHousingLoanTitle,
      canonicalUrl: _affordableHousingLoanUrl,
      lastVerifiedDate: _affordableHousingLoanVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'pagibig-three-tools-sorting',
      categorizePrompt: 'Sort each fictional situation into where to start.',
      buckets: [
        CategorizeBucket(
          id: 'regular-savings',
          label: 'Start with Regular Savings',
        ),
        CategorizeBucket(id: 'mp2', label: 'Start with MP2 Savings'),
        CategorizeBucket(id: 'housing', label: 'Start with housing finance'),
        CategorizeBucket(id: 'other', label: 'Another option may fit better'),
      ],
      items: [
        CategorizeItemDef(
          id: 'review-employer-contributions',
          label:
              'A fictional employee wants to review the contributions their '
              'employer has posted so far',
          explanation:
              'Reviewing what has already been posted is a Regular '
              'Savings question.',
        ),
        CategorizeItemDef(
          id: 'longer-term-goal',
          label:
              'A fictional saver wants to set aside money separately for a '
              'longer-term goal',
          explanation:
              'A separate, longer-term savings goal is the kind of '
              'question MP2 Savings is built to answer, worth reviewing '
              'the current terms for.',
        ),
        CategorizeItemDef(
          id: 'exploring-home-financing',
          label: 'A fictional household is exploring financing to buy a home',
          explanation:
              'Financing a home purchase is a housing finance question.',
        ),
        CategorizeItemDef(
          id: 'sudden-emergency',
          label:
              'A fictional household faces a sudden emergency that needs '
              'cash right away',
          explanation:
              'An emergency that needs cash right away usually needs money '
              'that is already liquid. Another option may fit better than '
              'any of these three.',
        ),
      ],
      correctBucketByItemId: {
        'review-employer-contributions': 'regular-savings',
        'longer-term-goal': 'mp2',
        'exploring-home-financing': 'housing',
        'sudden-emergency': 'other',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pagibig-three-tools-myth-membership-guarantees-fit',
      statement:
          'Being a Pag-IBIG member means all three of these tools '
          'automatically fit your situation.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Membership alone does not mean every option fits. Each tool '
          'answers a different question, and another option may fit '
          'better than any of the three.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'pagibig-three-tools-unsure-scenario',
      scenarioTitle: 'A fictional starting point',
      situation:
          'A fictional member is not sure which of the three tools fits a '
          'situation they are facing. What does this lesson suggest?',
      options: [
        ScenarioChoiceOption(
          id: 'pick-the-most-familiar',
          label: 'Pick whichever tool sounds most familiar and start there',
          explanation:
              'Familiarity is not the same as fit. Picking the most '
              'familiar name skips the useful step of matching the '
              'situation to what each tool actually does.',
        ),
        ScenarioChoiceOption(
          id: 'match-the-need-first',
          label:
              'Match the situation to what each tool is actually built to '
              'do first',
          explanation:
              'This is the useful step: naming the need before assuming '
              'Regular Savings, MP2, housing finance, or none of the '
              'three applies.',
        ),
      ],
      preferredOptionId: 'match-the-need-first',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional reader wants to know if Regular Savings, MP2 Savings, '
        'and housing finance are basically interchangeable. Based on this '
        'lesson, what is the accurate answer?',
    choices: [
      'Yes, since they all come from Pag-IBIG Fund, any one of them works '
          'for any situation',
      'No, each answers a different question, and another option may fit '
          'better than any of the three for some situations',
      'It depends only on how long someone has been a member',
    ],
    correctIndex: 1,
    explanation:
        'Regular Savings, MP2 Savings, and housing finance are separate '
        'tools built around different questions. Matching a situation to '
        'the right one, or recognizing that another option may fit better, '
        'is the useful first step.',
    whyWrong:
        'How long someone has been a member does not by itself decide '
        'whether one of these three tools fits a given situation.',
  ),
  keyTakeaway:
      'Regular Savings, MP2 Savings, and housing finance answer different '
      'questions. Membership alone does not mean every option fits, and '
      'another option may fit better.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Check Your Regular Savings
// ---------------------------------------------------------------------------

const _checkYourRegularSavings = MoneyLesson(
  id: pagibigRefCheckRegularSavings,
  trackId: 'pagibig_savings_mp2_housing',
  title: 'Check Your Regular Savings',
  icon: 'checklist',
  minutes: 3,
  summary:
      'A private, non-sensitive record-check habit for Regular Savings. It '
      'never asks for a sensitive identifier of any kind.',
  objective:
      'Build the habit of reviewing your posted Regular Savings record and '
      'knowing where to raise a mismatch.',
  sections: [],
  governance: _governanceHigh,
  sources: [_pagibigMain, _virtualPagibig],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Regular Savings is built from contributions posted to a member\'s '
            'own account over time. What is posted can differ from what was '
            'actually remitted, especially around a job change or for a '
            'self employed or voluntary member, so checking the posted '
            'record directly is worth doing.',
        'Comparing the posted record with what a member expects their own '
            'or their employer\'s remittances to show is the useful check. '
            'A missing or incorrect entry is not automatically proof that a '
            'contribution was never paid; it is a reason to verify through '
            'the official channel, not to assume either way.',
        'Keeping membership details current, such as contact information, '
            'also matters: it is what makes an official record reachable '
            'and correctable in the first place.',
      ],
    ),
    NuggetsBlock([
      'A posted record and an actual remittance are not always the same '
          'thing until they are compared directly.',
      'This habit never needs a MID number. It never needs an employer '
          'name. It never needs an exact contribution amount. It never '
          'needs a salary figure. It never needs login details entered '
          'into Salapify.',
    ]),
    RiskWarningBlock(
      title: 'This never calculates or approves anything',
      text:
          'This checklist never states a contribution amount, never '
          'calculates a gap, and never approves or denies anything. Only '
          'Pag-IBIG\'s own official channel can confirm what is actually '
          'posted to a specific account.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _pagibigMainTitle,
      canonicalUrl: _pagibigMainUrl,
      lastVerifiedDate: _pagibigMainVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _virtualPagibigTitle,
      canonicalUrl: _virtualPagibigUrl,
      lastVerifiedDate: _virtualPagibigVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    RiskReviewChecklistBlock(
      blockId: 'pagibig-check-savings-readiness',
      checklistPrompt: 'A private, non-sensitive record-check habit',
      foundationCount: 2,
      items: [
        ChecklistItemDef(
          id: 'know-where-to-check',
          label: 'Know where to check your official Regular Savings record',
          explanation:
              'Confirming the official place to look is the starting '
              'point, before comparing anything.',
        ),
        ChecklistItemDef(
          id: 'confirm-membership-current',
          label: 'Confirm your membership details are current',
          explanation:
              'Current contact details are what keep an official record '
              'reachable and correctable.',
        ),
        ChecklistItemDef(
          id: 'compare-expected-remittances',
          label:
              'Compare your record with what you expect your remittances '
              'to show',
          explanation:
              'A posted record and an actual remittance are not always the '
              'same until they are compared directly.',
        ),
        ChecklistItemDef(
          id: 'note-missing-or-incorrect',
          label: 'Note any missing or incorrect entries',
          explanation:
              'A missing entry is a reason to verify, not a confirmed '
              'problem on its own.',
        ),
        ChecklistItemDef(
          id: 'know-official-channel',
          label: 'Know the official Pag-IBIG channel for raising a mismatch',
          explanation:
              'Knowing where to raise a mismatch is what turns a noticed '
              'problem into a resolved one.',
        ),
        ChecklistItemDef(
          id: 'plan-follow-up',
          label: 'Plan a follow up if something looks off',
          explanation:
              'A planned follow up is the difference between noticing an '
              'issue and actually resolving it.',
        ),
      ],
      foundationSummary: 'Your next step is to review your official record.',
      partialSummary: 'Some contributions may need verification.',
      completeSummary: 'Contact Pag-IBIG if your records do not match.',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pagibig-check-savings-myth-missing-means-unpaid',
      statement:
          'A missing entry in your posted record always means a '
          'contribution was never paid.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A missing entry can also reflect a posting delay or a record '
          'issue. Verifying directly through the official channel, rather '
          'than assuming either way, is the reliable next step.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'pagibig-check-savings-unsure-record-scenario',
      scenarioTitle: 'A fictional record that might not match',
      situation:
          'A fictional member is not sure whether their posted Regular '
          'Savings record matches what they actually remitted. What is the '
          'useful next step?',
      options: [
        ScenarioChoiceOption(
          id: 'assume-it-is-fine',
          label: 'Assume it is fine, since they remember paying on time',
          explanation:
              'A memory of paying on time is not the same as a posted '
              'record. Assuming skips the one check that would actually '
              'confirm it.',
        ),
        ScenarioChoiceOption(
          id: 'verify-directly',
          label:
              'Verify the posted record directly through the official '
              'channel',
          explanation:
              'This is the useful step: checking the actual posted record, '
              'rather than relying on memory.',
        ),
      ],
      preferredOptionId: 'verify-directly',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional member finishes this checklist with every item '
        'checked, but one entry still looks wrong. What does this lesson '
        'say to do?',
    choices: [
      'Nothing further; a completed checklist means the record is already '
          'correct',
      'Contact Pag-IBIG directly if a record does not match, since this '
          'checklist only organizes what to review, never confirms or '
          'corrects a record itself',
      'Assume the record will correct itself over time',
    ],
    correctIndex: 1,
    explanation:
        'This checklist only organizes what is worth reviewing. Whether a '
        'specific entry is correct, and getting it corrected if it is not, '
        'still happens through Pag-IBIG\'s own official channel.',
    whyWrong:
        'A completed checklist means the readiness items were reviewed, '
        'not that every entry has been confirmed accurate.',
  ),
  keyTakeaway:
      'Review your posted Regular Savings record, compare it with what you '
      'expect, and contact Pag-IBIG directly if something does not match. '
      'This never asks for or stores a sensitive identifier.',
);

// ---------------------------------------------------------------------------
// Lesson 3: MP2 Without the Hype
// ---------------------------------------------------------------------------

const _mp2WithoutTheHype = MoneyLesson(
  id: pagibigRefMp2WithoutHype,
  trackId: 'pagibig_savings_mp2_housing',
  title: 'MP2 Without the Hype',
  icon: 'savings',
  minutes: 4,
  summary:
      'Four common MP2 claims, checked. MP2 is voluntary, separate from '
      'Regular Savings, and never a stand-in for an emergency fund.',
  objective:
      'Tell an accurate MP2 claim apart from an exaggerated one, before '
      'reviewing the current official rules.',
  sections: [],
  governance: _governanceHigh,
  sources: [_pagibigMain, _virtualPagibig],
  topics: [
    ContentTopic.governmentBenefitEligibility,
    ContentTopic.productReturns,
  ],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'MP2 Savings is a voluntary Pag-IBIG savings program for eligible '
            'participants, separate from Regular Savings. Opening one is a '
            'choice, never a requirement, and it sits alongside Regular '
            'Savings rather than replacing it.',
        'MP2 dividend rates are declared for specific periods under Pag-'
            'IBIG\'s own current rules, and they can change from one period '
            'to the next. A past dividend rate, however it compared to '
            'other options, does not promise what a future one will be.',
        'Before contributing anything, the current maturity, withdrawal, '
            'eligibility, and dividend-payment rules are worth reviewing '
            'directly, since they are set by Pag-IBIG Fund and can change. '
            'Money that might be needed for an emergency or a near-term '
            'expense usually needs more liquidity than this kind of '
            'savings program is built to offer.',
      ],
    ),
    NuggetsBlock([
      'Voluntary and separate from Regular Savings: opening MP2 is a '
          'choice, not a requirement, and it does not replace an existing '
          'Regular Savings account.',
      'A dividend rate is declared for a specific period and can change; a '
          'past rate is information, never a promise.',
    ]),
    RiskWarningBlock(
      title: 'MP2 is not a stand-in for an emergency fund',
      text:
          'Money that might be needed for an emergency or a near-term '
          'expense usually needs more liquidity than a savings program '
          'with its own current maturity and withdrawal rules can offer. '
          'This lesson never recommends MP2 as suitable for a specific '
          'reader.',
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _pagibigMainTitle,
      canonicalUrl: _pagibigMainUrl,
      lastVerifiedDate: _pagibigMainVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _virtualPagibigTitle,
      canonicalUrl: _virtualPagibigUrl,
      lastVerifiedDate: _virtualPagibigVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    MythOrFactBlock(
      blockId: 'pagibig-mp2-myth-same-return-every-year',
      statement: 'MP2 pays the same return every year.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'MP2 dividend rates are declared for specific periods under Pag-'
          'IBIG\'s own current rules, and they can change from one period '
          'to the next.',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pagibig-mp2-myth-treat-like-emergency-account',
      statement: 'I can treat MP2 exactly like an emergency savings account.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Money intended for emergencies or near-term expenses usually '
          'needs more liquidity than MP2\'s own current maturity and '
          'withdrawal rules are built to offer.',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pagibig-mp2-myth-past-dividend-promises-next',
      statement:
          'A previous high dividend means the next one will be the same.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A dividend rate is declared for a specific period. A previous '
          'rate, high or otherwise, does not promise what the next '
          'declared rate will be.',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pagibig-mp2-myth-everyone-should-open',
      statement: 'Everyone should open an MP2 account.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'MP2 is voluntary and does not fit every situation. Whether it '
          'fits a given saver depends on liquidity needs, competing '
          'priorities, and the current official rules, none of which this '
          'lesson decides for the reader.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'pagibig-mp2-liquidity-scenario',
      scenarioTitle: 'A fictional liquidity question',
      situation:
          'A fictional saver wants money available for a possible near-'
          'term emergency, and is considering putting it into MP2 instead '
          'of somewhere more liquid. What is the useful next step?',
      options: [
        ScenarioChoiceOption(
          id: 'treat-mp2-as-instantly-available',
          label:
              'Treat the MP2 balance as instantly available whenever it '
              'is needed',
          explanation:
              'MP2 has its own current maturity and withdrawal rules, so '
              'treating it as instantly available is not a safe '
              'assumption for money that may be needed on short notice.',
        ),
        ScenarioChoiceOption(
          id: 'keep-emergency-money-liquid',
          label:
              'Keep emergency money somewhere liquid, and review MP2\'s '
              'current terms separately for money that does not need to '
              'be',
          explanation:
              'This is the useful step: matching liquidity needs to the '
              'right kind of savings, rather than assuming one product '
              'covers both.',
        ),
      ],
      preferredOptionId: 'keep-emergency-money-liquid',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional reader hears that MP2 paid a high dividend last '
        'period and assumes the next one will match it. What does this '
        'lesson say?',
    choices: [
      'A past high dividend guarantees the next one will be the same',
      'A dividend rate is declared for a specific period and can change; a '
          'past rate does not promise a future one',
      'MP2 dividend rates never change once declared',
    ],
    correctIndex: 1,
    explanation:
        'Dividend rates are declared for specific periods under Pag-IBIG\'s '
        'own current rules and can change. A past rate is information, '
        'never a promise about what comes next.',
    whyWrong:
        'Dividend rates are not fixed for life; they are declared period '
        'by period under the current rules in effect.',
  ),
  keyTakeaway:
      'MP2 is voluntary, separate from Regular Savings, and never a stand-'
      'in for an emergency fund. A past dividend rate never promises a '
      'future one.',
);

// ---------------------------------------------------------------------------
// Lesson 4: Is Your Money Ready for MP2?
// ---------------------------------------------------------------------------

const _isYourMoneyReadyForMp2 = MoneyLesson(
  id: pagibigRefMp2Readiness,
  trackId: 'pagibig_savings_mp2_housing',
  title: 'Is Your Money Ready for MP2?',
  icon: 'search',
  minutes: 3,
  summary:
      'A neutral readiness exercise. It never says invest now, never says '
      'MP2 is right for you, and never suggests a contribution amount.',
  objective:
      'Sort a fictional saver\'s situation into what is worth reviewing '
      'first, before any MP2 decision.',
  sections: [],
  governance: _governanceHigh,
  sources: [_pagibigMain, _virtualPagibig],
  topics: [
    ContentTopic.governmentBenefitEligibility,
    ContentTopic.productReturns,
  ],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Before setting money aside in MP2, a few things are usually worth '
            'reviewing first: whether an emergency buffer already exists, '
            'whether high-interest debt is still unresolved, whether a '
            'near-term expense is coming up, whether income has been '
            'stable, whether the money could realistically stay untouched '
            'for MP2\'s current term, and whether the current official MP2 '
            'rules have actually been reviewed yet.',
        'This exercise never tells a reader to invest now, never says MP2 '
            'is right for them, never suggests a contribution amount, and '
            'never states that a reader is eligible. It only sorts a '
            'fictional situation into what is worth reviewing first.',
      ],
    ),
    NuggetsBlock([
      'A readiness area worth reviewing is not a verdict. It is a pointer '
          'to what to look at next.',
      'This exercise never calculates a return and never recommends a '
          'contribution amount.',
    ]),
    RiskWarningBlock(
      title: 'This never recommends MP2 or a contribution amount',
      text:
          'This exercise never says a reader is ready to invest, never '
          'says MP2 is right for them, never states an eligibility '
          'result, and never suggests how much to contribute. It only '
          'names what is worth reviewing first.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _pagibigMainTitle,
      canonicalUrl: _pagibigMainUrl,
      lastVerifiedDate: _pagibigMainVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _virtualPagibigTitle,
      canonicalUrl: _virtualPagibigUrl,
      lastVerifiedDate: _virtualPagibigVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'pagibig-mp2-readiness-sorting',
      categorizePrompt:
          'Sort each fictional situation into the most useful next step.',
      buckets: [
        CategorizeBucket(id: 'check-liquidity', label: 'Check liquidity first'),
        CategorizeBucket(
          id: 'review-priorities',
          label: 'Review competing priorities',
        ),
        CategorizeBucket(
          id: 'verify-mp2-rules',
          label: 'Verify the current MP2 rules',
        ),
        CategorizeBucket(
          id: 'goal-fit-review-terms',
          label:
              'This money may match a longer-term goal, but review the '
              'official terms first',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'no-emergency-buffer',
          label: 'A fictional saver has no emergency buffer set aside yet',
          explanation:
              'An unfunded emergency buffer is worth checking on before '
              'setting money aside somewhere less liquid.',
        ),
        CategorizeItemDef(
          id: 'high-interest-debt',
          label: 'A fictional saver is still carrying high-interest debt',
          explanation:
              'High-interest debt is a competing priority worth reviewing '
              'before setting more money aside elsewhere.',
        ),
        CategorizeItemDef(
          id: 'near-term-expense',
          label: 'A fictional saver has a near-term expense coming up soon',
          explanation:
              'A near-term expense is a liquidity question worth checking first.',
        ),
        CategorizeItemDef(
          id: 'unstable-income',
          label: 'A fictional saver\'s income has been unstable recently',
          explanation:
              'Unstable income is a competing priority worth reviewing '
              'before committing money elsewhere.',
        ),
        CategorizeItemDef(
          id: 'money-untouched-for-term',
          label:
              'A fictional saver has money that could realistically stay '
              'untouched for MP2\'s current term',
          explanation:
              'This money may match a longer-term goal, but the official '
              'terms are still worth reviewing first.',
        ),
        CategorizeItemDef(
          id: 'has-not-reviewed-rules',
          label:
              'A fictional saver has not yet reviewed the current official '
              'MP2 rules',
          explanation:
              'The current official MP2 rules are worth verifying before '
              'deciding anything.',
        ),
      ],
      correctBucketByItemId: {
        'no-emergency-buffer': 'check-liquidity',
        'high-interest-debt': 'review-priorities',
        'near-term-expense': 'check-liquidity',
        'unstable-income': 'review-priorities',
        'money-untouched-for-term': 'goal-fit-review-terms',
        'has-not-reviewed-rules': 'verify-mp2-rules',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pagibig-mp2-readiness-myth-exercise-confirms-fit',
      statement:
          'Finishing this exercise means MP2 is confirmed to be right for '
          'you.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'This exercise never confirms that MP2 is right for anyone. It '
          'only sorts a fictional situation into what is worth reviewing '
          'first; the current official rules and a reader\'s own '
          'situation decide the rest.',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional saver finishes this readiness exercise. What has it '
        'actually told them?',
    choices: [
      'That MP2 is confirmed to be right for them',
      'Which areas are worth reviewing first, such as liquidity, '
          'competing priorities, or the current official rules, never a '
          'recommendation to contribute',
      'The exact amount they should contribute to MP2',
    ],
    correctIndex: 1,
    explanation:
        'This exercise sorts a fictional situation into what is worth '
        'reviewing first. It never recommends MP2, never states '
        'eligibility, and never suggests a contribution amount.',
    whyWrong:
        'This exercise has no contribution calculator and makes no '
        'personal recommendation of any kind.',
  ),
  keyTakeaway:
      'Check liquidity, review competing priorities, and verify the '
      'current official MP2 rules first. This exercise never says invest '
      'now and never recommends a contribution amount.',
);

// ---------------------------------------------------------------------------
// Lesson 5: The Real Cost of a Housing Loan
// ---------------------------------------------------------------------------

const _theRealCostOfAHousingLoan = MoneyLesson(
  id: pagibigRefHousingLoanCost,
  trackId: 'pagibig_savings_mp2_housing',
  title: 'The Real Cost of a Housing Loan',
  icon: 'home',
  minutes: 4,
  summary:
      'A housing loan is debt, not free assistance. Compare the full cost, '
      'not only the monthly payment.',
  objective:
      'List the real decision factors a housing loan carries, beyond the '
      'scheduled monthly payment.',
  sections: [],
  governance: _governanceHigh,
  sources: [_affordableHousingLoan, _amortCalculator, _housingForms],
  topics: [
    ContentTopic.governmentBenefitEligibility,
    ContentTopic.loansOrCredit,
  ],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A Pag-IBIG housing loan is debt. It has to be repaid, with '
            'interest, under Pag-IBIG\'s own current rules, not free '
            'government assistance. Real decision factors go beyond the '
            'scheduled monthly amortization: interest and repricing over '
            'time, the loan term, the total interest paid over the life of '
            'the loan, upfront cash requirements, insurance and property '
            'related costs, repairs and maintenance, association dues '
            'where applicable, taxes and transaction costs, commuting or '
            'location costs, and keeping an emergency buffer after the '
            'purchase.',
        'A general tradeoff worth understanding: a longer loan term can '
            'reduce the scheduled monthly payment, while increasing the '
            'total interest paid over the full term. Neither a shorter nor '
            'a longer term is automatically better; it depends on the '
            'full cost, not just the monthly figure.',
        'This lesson never determines affordability, never estimates '
            'approval chances, never calculates an amortization schedule, '
            'and never quotes a current interest rate. Pag-IBIG\'s own '
            'official amortization calculator, not a Salapify calculator, '
            'is where those actual numbers are checked.',
      ],
    ),
    NuggetsBlock([
      'A housing loan is debt, not free government assistance. It carries '
          'interest and a repayment obligation.',
      'A longer term can lower the scheduled monthly payment while '
          'raising the total interest paid. Compare the full cost, not '
          'only the monthly payment.',
    ]),
    RiskWarningBlock(
      title: 'This never determines affordability or approval',
      text:
          'This lesson never determines affordability, never estimates '
          'approval chances, never calculates an amortization schedule, '
          'never quotes a current interest rate, and never recommends a '
          'property, developer, broker, or lender. Pag-IBIG\'s own '
          'official amortization calculator is the place to check actual '
          'numbers.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _affordableHousingLoanTitle,
      canonicalUrl: _affordableHousingLoanUrl,
      lastVerifiedDate: _affordableHousingLoanVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _amortCalculatorTitle,
      canonicalUrl: _amortCalculatorUrl,
      lastVerifiedDate: _amortCalculatorVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _housingFormsTitle,
      canonicalUrl: _housingFormsUrl,
      lastVerifiedDate: _housingFormsVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    RiskReviewChecklistBlock(
      blockId: 'pagibig-housing-readiness-checklist',
      checklistPrompt: 'Compare the full cost, not only the monthly payment',
      foundationCount: 3,
      items: [
        ChecklistItemDef(
          id: 'reviewed-budget-honestly',
          label:
              'Reviewed your budget honestly, alongside every other '
              'expense',
          explanation:
              'A housing loan competes with every other expense already in '
              'the budget, not just the ones easiest to remember.',
        ),
        ChecklistItemDef(
          id: 'buffer-planned-after-purchase',
          label:
              'Planned for an emergency buffer to remain after any '
              'upfront cost',
          explanation:
              'An upfront cost that empties a buffer leaves nothing for '
              'the unexpected right after a purchase.',
        ),
        ChecklistItemDef(
          id: 'understand-this-is-debt',
          label:
              'Understand a housing loan is debt, repaid with interest, '
              'not free assistance',
          explanation:
              'Treating a loan as assistance rather than debt is the '
              'starting mistake this lesson exists to correct.',
        ),
        ChecklistItemDef(
          id: 'reviewed-monthly-amortization',
          label:
              'Reviewed what the scheduled monthly amortization would mean '
              'for your budget',
          explanation:
              'The scheduled payment is one line among many, not the '
              'whole picture.',
        ),
        ChecklistItemDef(
          id: 'reviewed-interest-and-repricing',
          label:
              'Reviewed how interest and repricing could change the '
              'payment over time',
          explanation:
              'A rate that reprices later can change the payment after the '
              'loan has already started.',
        ),
        ChecklistItemDef(
          id: 'reviewed-loan-term-tradeoff',
          label:
              'Reviewed how the loan term affects both the monthly payment '
              'and the total interest paid',
          explanation:
              'A longer term and a shorter term trade off differently; '
              'neither is automatically better.',
        ),
        ChecklistItemDef(
          id: 'reviewed-upfront-cash',
          label: 'Reviewed the upfront cash a purchase would require',
          explanation:
              'Upfront cash is separate from the ongoing monthly payment '
              'and is easy to underestimate.',
        ),
        ChecklistItemDef(
          id: 'reviewed-insurance-and-property-costs',
          label: 'Reviewed insurance and property related costs',
          explanation:
              'Insurance and property costs continue for as long as the '
              'property is owned.',
        ),
        ChecklistItemDef(
          id: 'reviewed-repairs-dues-taxes',
          label:
              'Reviewed repairs and maintenance, association dues where '
              'applicable, and taxes or transaction costs',
          explanation:
              'These recurring and one-time costs sit outside the loan '
              'itself but still affect the real cost of owning the home.',
        ),
        ChecklistItemDef(
          id: 'reviewed-commuting-or-location-costs',
          label: 'Reviewed commuting or location costs',
          explanation:
              'A property\'s location can change a household\'s ongoing '
              'costs well beyond the loan payment itself.',
        ),
      ],
      foundationSummary: 'Build a safer buffer first',
      partialSummary: 'More costs to investigate',
      completeSummary: 'Ready to verify official loan terms',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'pagibig-housing-myth-loan-is-free-assistance',
      statement:
          'A Pag-IBIG housing loan is basically free government '
          'assistance, not a loan that has to be repaid.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A Pag-IBIG housing loan is debt. It is repaid with interest, '
          'under Pag-IBIG\'s own current rules, the same as any other '
          'loan.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'pagibig-housing-loan-term-scenario',
      scenarioTitle: 'A fictional loan term choice',
      situation:
          'A fictional buyer is deciding between a longer and a shorter '
          'loan term, and is only looking at which one gives the lower '
          'scheduled monthly payment. What does this lesson say?',
      options: [
        ScenarioChoiceOption(
          id: 'focus-only-on-monthly-payment',
          label:
              'Focus only on which term gives the lower scheduled monthly '
              'payment',
          explanation:
              'The monthly payment is only part of the picture. A longer '
              'term that lowers it can still mean paying more interest in '
              'total.',
        ),
        ScenarioChoiceOption(
          id: 'compare-total-interest-too',
          label:
              'Compare the total interest paid over the full term, not '
              'just the monthly payment',
          explanation:
              'This is the useful step: a longer term can reduce the '
              'scheduled monthly payment while increasing the total '
              'interest paid, so both figures matter.',
        ),
      ],
      preferredOptionId: 'compare-total-interest-too',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional buyer wants to know whether a longer or a shorter '
        'loan term is better. What does this lesson say?',
    choices: [
      'A longer term is always better, since the monthly payment is lower',
      'A longer term can reduce the scheduled monthly payment while '
          'increasing the total interest paid over the full term, so both '
          'matter',
      'Loan term never affects the total interest paid',
    ],
    correctIndex: 1,
    explanation:
        'This lesson\'s own general tradeoff: a longer term can lower the '
        'scheduled monthly payment while raising the total interest paid '
        'over the life of the loan. Neither term is automatically better.',
    whyWrong:
        'The scheduled monthly payment and the total interest paid can '
        'move in opposite directions as the term changes, so looking at '
        'only one of them misses the real cost.',
  ),
  keyTakeaway:
      'A housing loan is debt, not free assistance. Compare the full cost, '
      'not only the monthly payment, and use Pag-IBIG\'s own official '
      'amortization calculator to check actual numbers.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Make Your Pag-IBIG Plan
// ---------------------------------------------------------------------------

const _makeYourPagibigPlan = MoneyLesson(
  id: pagibigRefMakeYourPlan,
  trackId: 'pagibig_savings_mp2_housing',
  title: 'Make Your Pag-IBIG Plan',
  icon: 'target',
  minutes: 3,
  summary:
      'Choose up to three next actions, and open the real Salapify screens '
      'that already fit. Nothing here is created automatically.',
  objective:
      'Turn this course into a short list of next steps, and open the '
      'Salapify screens that already fit.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_pagibigMain, _virtualPagibig],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A short action plan pulls this course together: reviewing '
            'Regular Savings records, reading the current MP2 terms, '
            'checking whether a goal can stay funded for the required '
            'period, reviewing the official housing-loan requirements, '
            'estimating housing costs through the official Pag-IBIG tool, '
            'strengthening an emergency fund, creating or reviewing a '
            'homeownership goal in Salapify, and reviewing a budget before '
            'taking on housing debt.',
        'Choosing up to three of these as a starting point is more useful '
            'than trying to do everything at once. None of this is '
            'calculated or approved by this lesson. Every step here points '
            'at an official source or an existing Salapify screen, never a '
            'new government account, a loan application, or a housing '
            'calculator built by Salapify.',
      ],
    ),
    NuggetsBlock([
      'A short list of specific next steps is more useful than a general '
          'intention to check on this someday.',
      'Strengthening a buffer or reviewing a budget already in Salapify is '
          'a real step available today, independent of anything Pag-IBIG '
          'eventually confirms.',
    ]),
    RiskWarningBlock(
      title: 'This plan never estimates a loan payment or approves anything',
      text:
          'Nothing in this plan calculates a contribution, a dividend, a '
          'loan payment, or an approval outcome, and nothing here opens a '
          'Pag-IBIG account or applies for a loan. Every figure and '
          'outcome still comes from the official channel.',
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _pagibigMainTitle,
      canonicalUrl: _pagibigMainUrl,
      lastVerifiedDate: _pagibigMainVerified,
    ),
    OfficialSourceBlock(
      agency: _pagibigAgency,
      sourceTitle: _virtualPagibigTitle,
      canonicalUrl: _virtualPagibigUrl,
      lastVerifiedDate: _virtualPagibigVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'pagibig-plan-next-actions',
      checklistPrompt: 'Choose up to three next actions',
      items: [
        ChecklistItemDef(
          id: 'review-regular-savings-records',
          label: 'Review Regular Savings records',
        ),
        ChecklistItemDef(
          id: 'read-current-mp2-terms',
          label: 'Read the current MP2 terms',
        ),
        ChecklistItemDef(
          id: 'check-goal-funded-for-required-period',
          label:
              'Check whether a goal can remain funded for the required period',
        ),
        ChecklistItemDef(
          id: 'review-official-housing-requirements',
          label: 'Review the official housing-loan requirements',
        ),
        ChecklistItemDef(
          id: 'estimate-housing-costs-official-tool',
          label: 'Estimate housing costs through the official Pag-IBIG tool',
        ),
        ChecklistItemDef(
          id: 'strengthen-emergency-fund',
          label: 'Strengthen an emergency fund',
        ),
        ChecklistItemDef(
          id: 'create-or-review-homeownership-goal',
          label: 'Create or review a homeownership goal in Salapify',
        ),
        ChecklistItemDef(
          id: 'review-budget-before-housing-debt',
          label: 'Review a budget before taking on housing debt',
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'pagibig-plan-unsure-question-scenario',
      scenarioTitle: 'A fictional unresolved question',
      situation:
          'A fictional reader finishes this course still unsure about one '
          'specific detail of their own Regular Savings, MP2, or housing '
          'situation. What is the useful next step?',
      options: [
        ScenarioChoiceOption(
          id: 'guess-and-move-on',
          label: 'Guess an answer and move on without checking',
          explanation:
              'A guess is not a check. This course\'s own checklists exist '
              'because a specific detail is worth verifying directly.',
        ),
        ScenarioChoiceOption(
          id: 'write-down-the-question',
          label:
              'Write the question down as the one official question to '
              'resolve next',
          explanation:
              'This is the useful step: naming the specific, unresolved '
              'question so it gets checked through the official channel.',
        ),
      ],
      preferredOptionId: 'write-down-the-question',
      requiredForCompletion: false,
    ),
    SalapifyActionsBlock(
      blockId: 'pagibig-salapify-actions',
      menuPrompt: 'A few real, safe things to do next, if any of them fit',
      actions: [
        SalapifyActionDef(
          id: 'review-emergency-fund',
          label: 'Review Emergency Fund',
          description:
              'Opens Goals to check an Emergency Fund goal, or start one '
              'from a template. Nothing is created or changed until '
              'something is saved there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-homeownership-goal',
          label: 'Review a homeownership goal',
          description:
              'Opens Goals to create or review a homeownership goal. '
              'Nothing is created or changed until something is saved '
              'there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-budget-before-housing',
          label: 'Review Budget before housing debt',
          description:
              'Opens Budget so a housing payment can be planned for '
              'honestly alongside everything else. Nothing is added or '
              'changed until something is entered there.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'review-liabilities',
          label: 'Review Accounts and Liabilities',
          description:
              'Opens Debts to see existing obligations before adding a '
              'housing loan. Nothing is created or changed until '
              'something is entered there.',
          route: 'debts',
        ),
        SalapifyActionDef(
          id: 'open-reminders',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where reminders can be '
              'turned on. There is no Pag-IBIG specific reminder type '
              'yet, so nothing is scheduled automatically; this is the '
              'closest real screen for building a periodic check-in '
              'habit by hand.',
          route: 'notifications',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional reader finishes this course\'s action plan with a '
        'reviewed record, a named question, and a strengthened buffer. '
        'What has this plan actually done?',
    choices: [
      'It has approved a specific Pag-IBIG benefit or loan',
      'It has organized real, private next steps; nothing here calculates '
          'or approves anything',
      'It has submitted a housing loan application on the reader\'s '
          'behalf',
    ],
    correctIndex: 1,
    explanation:
        'This plan never calculates a benefit, never approves a loan, and '
        'never submits anything. It only organizes what is worth checking '
        'and doing next, through the official channel or an existing '
        'Salapify screen.',
    whyWrong:
        'Nothing in this course files an application or issues an '
        'approval; those steps only ever happen through Pag-IBIG Fund '
        'directly.',
  ),
  keyTakeaway:
      'Choose up to three next steps, review your official records, and '
      'open the Salapify screens that already fit. This plan organizes '
      'next steps; it never calculates or approves anything.',
);
