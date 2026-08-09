// Money Courses Phase 10: "Protect Your Future" learning path's second
// course, "SSS & PhilHealth Essentials" (course id
// 'sss_philhealth_benefits'). Built the same way Phase 9's "Insurance
// Decoded" was: the already shipped architecture only (governance metadata,
// official-source and risk-warning blocks, Phase 5 interaction blocks),
// nothing new added to the core model.
//
// This course teaches the high-level shape of SSS and PhilHealth, what to
// verify before counting on either one, and a short, safe next step. It
// never decides eligibility, never estimates a benefit, contribution,
// pension, case rate, or reimbursement, never promises approval or a
// processing time, never tells anyone to stop contributing, never presents
// either program as an investment, and never claims Salapify is affiliated
// with SSS, PhilHealth, or the Philippine government. Every Salapify action
// offered at the end opens an existing, unrelated screen manually (Goals,
// Budget, Recurring, Notifications and security); nothing here creates a
// government account, files a claim, stores a document, or calculates a
// benefit.
//
// House rules, same as the other Protect Your Future and Grow Your Money
// courses: plain English, no em or en dash, no guaranteed-outcome or
// eligibility-verdict language, no personalized recommendation, no
// affiliation claim, and no sensitive field ever requested or stored (SSS
// number, PhilHealth Identification Number, government login credentials,
// passwords or OTPs, exact income or salary, employer name, medical
// condition or diagnosis, beneficiary identity, claim documents, hospital
// bills, or government ID images).
//
// Content topic: ContentTopic.governmentBenefitEligibility on every lesson,
// which activates the Phase 4 validator's mandatory official-source,
// risk-warning, and educational-boundary checks. Lessons 1, 2, and 6 are
// classified ContentVolatility.annual: general structure that changes
// slowly. Lessons 3, 4, and 5 are classified ContentVolatility.high with a
// shorter review cycle, per the task's own instruction to treat
// contribution rules, eligibility requirements, benefit amounts, filing
// periods, case rates, and provider lists as time-sensitive; those three
// lessons are exactly where that kind of content lives (a contribution and
// filing readiness check, case rates and provider accreditation, and a
// clinic-registration program).
//
// No contribution amount, premium percentage, case-rate amount, medicine
// allowance, claim deadline, or minimum contribution count is hardcoded
// anywhere in this file. Every such figure is time sensitive and controlled
// by SSS's or PhilHealth's own current rules, so this content always points
// at the official current source instead, per this phase's own instruction
// and per the Phase 4 validator's own "as of" figure check.
//
// Sources: the eight official SSS and PhilHealth pages this phase's task
// named as the starting set (SSS Benefits, the Social Security Act of 2018,
// the SSS Contribution Table, PhilHealth Universal Health Care, PhilHealth
// YAKAP, the PhilHealth Case Rates Search, PhilHealth's own 2026 circular
// archive, and PhilHealth Accredited Facilities). No blog, news summary,
// influencer post, forum, social media post, or unofficial calculator was
// used as a factual source. This course's regulatory framing was reviewed
// by the legal-compliance-counsel agent before shipping (see
// governance.reviewerId below).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

const _sssAgency = 'Social Security System';
const _philhealthAgency = 'Philippine Health Insurance Corporation';

const _sssBenefitsTitle = 'SSS Benefits';
const _sssBenefitsUrl = 'https://www.sss.gov.ph/benefits/';
const _sssBenefitsVerified = '2026-08';
const _sssBenefits = LessonSourceInfo(
  agency: _sssAgency,
  title: _sssBenefitsTitle,
  canonicalUrl: _sssBenefitsUrl,
  lastVerifiedDate: _sssBenefitsVerified,
);

const _sssActTitle = 'Republic Act No. 11199, The Social Security Act of 2018';
const _sssActUrl =
    'https://www.sss.gov.ph/wp-content/uploads/2022/04/Booklet_SS-ACT-OF-2018_05172019_2.pdf';
const _sssActVerified = '2026-08';
const _sssAct = LessonSourceInfo(
  agency: _sssAgency,
  title: _sssActTitle,
  canonicalUrl: _sssActUrl,
  lastVerifiedDate: _sssActVerified,
);

const _sssContributionTableTitle = 'SSS Contribution Table';
const _sssContributionTableUrl =
    'https://www.sss.gov.ph/sss-contribution-table/';
const _sssContributionTableVerified = '2026-08';
const _sssContributionTable = LessonSourceInfo(
  agency: _sssAgency,
  title: _sssContributionTableTitle,
  canonicalUrl: _sssContributionTableUrl,
  lastVerifiedDate: _sssContributionTableVerified,
);

const _philhealthUhcTitle = 'PhilHealth Universal Health Care';
const _philhealthUhcUrl = 'https://www.philhealth.gov.ph/uhc/';
const _philhealthUhcVerified = '2026-08';
const _philhealthUhc = LessonSourceInfo(
  agency: _philhealthAgency,
  title: _philhealthUhcTitle,
  canonicalUrl: _philhealthUhcUrl,
  lastVerifiedDate: _philhealthUhcVerified,
);

const _philhealthYakapTitle = 'PhilHealth YAKAP';
const _philhealthYakapUrl = 'https://www.philhealth.gov.ph/yakap/';
const _philhealthYakapVerified = '2026-08';
const _philhealthYakap = LessonSourceInfo(
  agency: _philhealthAgency,
  title: _philhealthYakapTitle,
  canonicalUrl: _philhealthYakapUrl,
  lastVerifiedDate: _philhealthYakapVerified,
);

const _philhealthCaseRatesTitle = 'PhilHealth Case Rates Search';
const _philhealthCaseRatesUrl = 'https://www.philhealth.gov.ph/services/acr/';
const _philhealthCaseRatesVerified = '2026-08';
const _philhealthCaseRates = LessonSourceInfo(
  agency: _philhealthAgency,
  title: _philhealthCaseRatesTitle,
  canonicalUrl: _philhealthCaseRatesUrl,
  lastVerifiedDate: _philhealthCaseRatesVerified,
);

const _philhealthCircularsTitle = 'PhilHealth 2026 Circulars';
const _philhealthCircularsUrl =
    'https://www.philhealth.gov.ph/circulars/2026/archives.php';
const _philhealthCircularsVerified = '2026-08';
const _philhealthCirculars = LessonSourceInfo(
  agency: _philhealthAgency,
  title: _philhealthCircularsTitle,
  canonicalUrl: _philhealthCircularsUrl,
  lastVerifiedDate: _philhealthCircularsVerified,
);

const _philhealthAccreditedFacilitiesTitle = 'PhilHealth Accredited Facilities';
const _philhealthAccreditedFacilitiesUrl =
    'https://www.philhealth.gov.ph/partners/providers/facilities/accredited/';
const _philhealthAccreditedFacilitiesVerified = '2026-08';
const _philhealthAccreditedFacilities = LessonSourceInfo(
  agency: _philhealthAgency,
  title: _philhealthAccreditedFacilitiesTitle,
  canonicalUrl: _philhealthAccreditedFacilitiesUrl,
  lastVerifiedDate: _philhealthAccreditedFacilitiesVerified,
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

// Contribution, filing, case-rate, and provider-accreditation content: a
// shorter review window, per this phase's own instruction to treat that
// category of fact as time-sensitive.
const _governanceHigh = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-02',
  reviewerId: 'LCC',
);

// Same high-volatility classification as _governanceHigh, but with a review
// due date pulled in to before the calendar year rolls over. This lesson
// cites PhilHealth's own year-scoped circular archive URL
// (.../circulars/2026/archives.php), so the ordinary six-month cadence
// would leave January 2027 with a "current circulars" citation already
// pointing at the wrong year's archive. Flagged by the legal-compliance-
// counsel review before this course shipped.
const _governanceHighYearScoped = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2026-12',
  reviewerId: 'LCC',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel: 'SSS and PhilHealth',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form by the same convention every other
/// Money Courses lesson id uses. Never reused for a different lesson once a
/// learner has real progress recorded against one.
const sspRefTwoSafetyNets = 'sss-philhealth-two-safety-nets';
const sspRefSssMayHelp = 'sss-philhealth-sss-may-help';
const sspRefCheckBeforeYouCount = 'sss-philhealth-check-before-you-count';
const sspRefHowCoverageWorks = 'sss-philhealth-how-coverage-works';
const sspRefPrimaryCareEarlier = 'sss-philhealth-primary-care-earlier';
const sspRefSafetyNetPlan = 'sss-philhealth-safety-net-plan';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// list: the "X of 22" figure on the core Learn screen must never move
/// because of this file (see test/lessons_sss_philhealth_content_test.dart).
const List<MoneyLesson> sssPhilhealthBenefitsLessons = [
  _meetYourTwoSafetyNets,
  _whatSssMayHelpWith,
  _checkBeforeYouCountOnIt,
  _howPhilhealthCoverageWorks,
  _usePrimaryCareEarlier,
  _buildYourSafetyNetPlan,
];

// ---------------------------------------------------------------------------
// Lesson 1: Meet Your Two Safety Nets
// ---------------------------------------------------------------------------

const _meetYourTwoSafetyNets = MoneyLesson(
  id: sspRefTwoSafetyNets,
  trackId: 'sss_philhealth_benefits',
  title: 'Meet Your Two Safety Nets',
  icon: 'balance',
  minutes: 3,
  summary:
      'SSS and PhilHealth cover different kinds of events. Neither replaces '
      'an emergency fund, an employer benefit, or your own protection.',
  objective:
      'Tell SSS and PhilHealth apart, and know which one to check first for '
      'a given situation.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_sssBenefits, _philhealthUhc],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'SSS generally provides social security cash or income related '
            'benefits, tied to specific qualifying events such as being '
            'unable to work, reaching retirement age, or losing a job '
            'involuntarily.',
        'PhilHealth provides national health insurance benefit packages, '
            'under its own current rules and through its accredited health '
            'care providers, mainly for care received at a hospital or '
            'clinic.',
        'Neither program is a complete replacement for an emergency fund, '
            'for benefits an employer already provides, or for whatever '
            'private protection a household chooses on its own. Each '
            'responds to a specific, defined kind of event, not to every '
            'financial shock a household can face.',
      ],
    ),
    NuggetsBlock([
      'SSS generally answers "what happens to my income". PhilHealth '
          'generally answers "what happens to my medical bill". They rarely '
          'answer the same question.',
      'An emergency fund, an employer benefit, or a household\'s own '
          'private protection still has its own place alongside both of '
          'these.',
    ]),
    RiskWarningBlock(
      title: 'Neither program is a full safety net on its own',
      text:
          'SSS and PhilHealth each respond to a specific, defined kind of '
          'event, set by their own current rules. This lesson never says a '
          'household needs no other protection.',
    ),
    OfficialSourceBlock(
      agency: _sssAgency,
      sourceTitle: _sssBenefitsTitle,
      canonicalUrl: _sssBenefitsUrl,
      lastVerifiedDate: _sssBenefitsVerified,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthUhcTitle,
      canonicalUrl: _philhealthUhcUrl,
      lastVerifiedDate: _philhealthUhcVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'sss-philhealth-two-nets-sorting',
      categorizePrompt:
          'Sort each fictional situation into where to check first.',
      buckets: [
        CategorizeBucket(id: 'sss', label: 'Check SSS first'),
        CategorizeBucket(id: 'philhealth', label: 'Check PhilHealth first'),
        CategorizeBucket(id: 'both', label: 'Check both'),
        CategorizeBucket(id: 'other', label: 'Check another resource first'),
      ],
      items: [
        CategorizeItemDef(
          id: 'planned-hospital-admission',
          label:
              'A fictional worker is admitted to a hospital for a planned '
              'procedure',
          explanation:
              'A hospital stay is the kind of event PhilHealth\'s benefit '
              'packages and accredited providers are built to respond to.',
        ),
        CategorizeItemDef(
          id: 'temporarily-unable-to-work',
          label:
              'A fictional employed member is temporarily unable to work '
              'because of a non work illness',
          explanation:
              'Being unable to work for a period is the kind of event '
              'SSS\'s own sickness related benefit category is built to '
              'respond to.',
        ),
        CategorizeItemDef(
          id: 'reaching-retirement-age',
          label:
              'A fictional member reaches the qualifying retirement age '
              'after years of contributions',
          explanation:
              'Retirement is a core SSS benefit category, worth checking '
              'through SSS directly.',
        ),
        CategorizeItemDef(
          id: 'lost-job-involuntarily',
          label: 'A fictional member loses a job involuntarily',
          explanation:
              'Involuntary job loss is the kind of event SSS\'s own '
              'unemployment related benefit category is built to respond '
              'to.',
        ),
        CategorizeItemDef(
          id: 'routine-checkup',
          label:
              'A fictional member wants a routine checkup with no hospital '
              'admission',
          explanation:
              'Routine and preventive care runs through PhilHealth\'s '
              'accredited primary care providers, not through SSS.',
        ),
        CategorizeItemDef(
          id: 'death-with-hospital-bill',
          label:
              'A fictional income earner has died, leaving both dependents '
              'and an outstanding hospital bill',
          explanation:
              'This touches both: SSS has death and funeral related '
              'benefit categories, and PhilHealth may apply to part of the '
              'hospital bill, so both are worth checking.',
        ),
        CategorizeItemDef(
          id: 'sudden-car-repair',
          label:
              'A fictional household wants money kept ready for a sudden '
              'car repair next month',
          explanation:
              'This is what an emergency fund is for. Neither SSS nor '
              'PhilHealth is built to respond to an everyday, undefined '
              'shock like this one.',
        ),
      ],
      correctBucketByItemId: {
        'planned-hospital-admission': 'philhealth',
        'temporarily-unable-to-work': 'sss',
        'reaching-retirement-age': 'sss',
        'lost-job-involuntarily': 'sss',
        'routine-checkup': 'philhealth',
        'death-with-hospital-bill': 'both',
        'sudden-car-repair': 'other',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'sss-philhealth-two-nets-myth-no-other-protection',
      statement:
          'Being covered by SSS and PhilHealth means a household never '
          'needs an emergency fund or any other protection.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'SSS and PhilHealth each respond to a specific, defined kind of '
          'event under their own current rules. An emergency fund, an '
          'employer benefit, or a household\'s own private protection '
          'still has its own place alongside both.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'sss-philhealth-two-nets-where-to-start',
      scenarioTitle: 'A fictional starting point',
      situation:
          'A fictional worker is not sure where to even start looking, SSS '
          'or PhilHealth, for a situation they are facing. What does this '
          'lesson suggest?',
      options: [
        ScenarioChoiceOption(
          id: 'guess-and-file',
          label: 'Guess which one applies and file directly with that one',
          explanation:
              'Guessing skips the one useful step this lesson teaches: '
              'matching the situation to the kind of event each program '
              'actually covers.',
        ),
        ScenarioChoiceOption(
          id: 'match-the-event-first',
          label:
              'Match the situation to the kind of event each program '
              'covers first',
          explanation:
              'This is the useful step: naming what kind of event this is '
              'before assuming either program, or neither, applies.',
        ),
      ],
      preferredOptionId: 'match-the-event-first',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional reader wants to know if SSS and PhilHealth are '
        'basically the same program, just under two names. Based on this '
        'lesson, what is the accurate answer?',
    choices: [
      'Yes, they cover the same events, so only one ever needs to be '
          'checked',
      'No, they respond to different kinds of events, income related for '
          'SSS and health benefit packages for PhilHealth, and often need '
          'to be checked separately',
      'It depends only on how much someone has already contributed',
    ],
    correctIndex: 1,
    explanation:
        'SSS and PhilHealth are separate programs built around different '
        'kinds of events. A situation can point at one, the other, both, or '
        'neither, and matching it correctly is the useful first step.',
    whyWrong:
        'How much someone has contributed does not change what kind of '
        'event each program is built to respond to.',
  ),
  keyTakeaway:
      'SSS and PhilHealth cover different kinds of events. Match the '
      'situation to the program before assuming either one, or neither, '
      'applies.',
);

// ---------------------------------------------------------------------------
// Lesson 2: What SSS May Help With
// ---------------------------------------------------------------------------

const _whatSssMayHelpWith = MoneyLesson(
  id: sspRefSssMayHelp,
  trackId: 'sss_philhealth_benefits',
  title: 'What SSS May Help With',
  icon: 'cushion',
  minutes: 4,
  summary:
      'Eight named benefit categories, at a glance. Feedback here always '
      'says "may apply" or "check this benefit", never "you qualify".',
  objective:
      'Match a fictional life event to the SSS benefit category worth '
      'investigating.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_sssBenefits, _sssAct],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'SSS organizes its own benefits into named categories: Sickness, '
            'Maternity, Disability, Retirement, Death, Funeral, '
            'Unemployment, and Employees\' Compensation.',
        'Recognizing which category a life event falls under is a useful '
            'first step. Whether a specific claim is paid still depends on '
            'membership category, the posted contribution record, and the '
            'current rules for that benefit, not on the category name '
            'alone.',
        'This lesson never says a fictional situation qualifies for a '
            'benefit. It only points at which category is worth '
            'investigating through the official channel.',
      ],
    ),
    NuggetsBlock([
      'A category name points at where to look. It is never, on its own, a '
          'statement that a specific claim will be paid.',
      'The full, current list of categories and their own requirements '
          'lives on the official SSS benefits page, not in this lesson.',
    ]),
    RiskWarningBlock(
      title: 'A category match is a starting point, not an approval',
      text:
          'Matching a life event to a benefit category only means it is '
          'worth investigating further through the official channel. It is '
          'never a statement that a specific claim will be approved.',
    ),
    OfficialSourceBlock(
      agency: _sssAgency,
      sourceTitle: _sssBenefitsTitle,
      canonicalUrl: _sssBenefitsUrl,
      lastVerifiedDate: _sssBenefitsVerified,
    ),
    OfficialSourceBlock(
      agency: _sssAgency,
      sourceTitle: _sssActTitle,
      canonicalUrl: _sssActUrl,
      lastVerifiedDate: _sssActVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'sss-may-help-life-event-matching',
      categorizePrompt:
          'Match each fictional life event to the benefit category worth '
          'checking.',
      buckets: [
        CategorizeBucket(id: 'sickness', label: 'Sickness'),
        CategorizeBucket(id: 'maternity', label: 'Maternity'),
        CategorizeBucket(id: 'disability', label: 'Disability'),
        CategorizeBucket(id: 'retirement', label: 'Retirement'),
        CategorizeBucket(id: 'death', label: 'Death'),
        CategorizeBucket(id: 'funeral', label: 'Funeral'),
        CategorizeBucket(id: 'unemployment', label: 'Unemployment'),
        CategorizeBucket(
          id: 'employees-compensation',
          label: 'Employees\' Compensation',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'unable-to-work-non-work-illness',
          label:
              'A fictional employed member is temporarily unable to work '
              'because of a non work related illness',
          explanation: 'The Sickness category may apply here, worth checking.',
        ),
        CategorizeItemDef(
          id: 'expecting-a-child',
          label: 'A fictional covered member is expecting a child',
          explanation: 'The Maternity category may apply here, worth checking.',
        ),
        CategorizeItemDef(
          id: 'permanent-loss-of-function',
          label:
              'A fictional member experiences a permanent loss of function '
              'after an accident or illness',
          explanation:
              'The Disability category may apply here, worth checking.',
        ),
        CategorizeItemDef(
          id: 'reaches-qualifying-age',
          label:
              'A fictional member reaches the qualifying retirement age '
              'after years of contributions',
          explanation:
              'The Retirement category may apply here, worth checking.',
        ),
        CategorizeItemDef(
          id: 'covered-member-dies',
          label: 'A fictional covered member dies, leaving dependents behind',
          explanation: 'The Death category may apply here, worth checking.',
        ),
        CategorizeItemDef(
          id: 'immediate-family-dies',
          label:
              'A fictional covered member or an immediate family member '
              'dies',
          explanation: 'The Funeral category may apply here, worth checking.',
        ),
        CategorizeItemDef(
          id: 'loses-job-involuntarily',
          label: 'A fictional member loses a job involuntarily',
          explanation:
              'The Unemployment category may apply here, worth checking.',
        ),
        CategorizeItemDef(
          id: 'work-related-accident',
          label:
              'A fictional member is affected by a work related accident '
              'or illness',
          explanation:
              'The Employees\' Compensation category may apply here, worth '
              'checking.',
        ),
      ],
      correctBucketByItemId: {
        'unable-to-work-non-work-illness': 'sickness',
        'expecting-a-child': 'maternity',
        'permanent-loss-of-function': 'disability',
        'reaches-qualifying-age': 'retirement',
        'covered-member-dies': 'death',
        'immediate-family-dies': 'funeral',
        'loses-job-involuntarily': 'unemployment',
        'work-related-accident': 'employees-compensation',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'sss-may-help-myth-category-guarantees-approval',
      statement:
          'Once a life event matches a benefit category, the claim is '
          'automatically approved.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A category match only means the category is worth investigating '
          'further. Approval still depends on membership category, the '
          'posted contribution record, and the current rules for that '
          'specific benefit.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'sss-may-help-two-categories-scenario',
      scenarioTitle: 'A fictional situation that touches two categories',
      situation:
          'A fictional member has a work related accident that also leaves '
          'them unable to work for a period. What is the useful next step?',
      options: [
        ScenarioChoiceOption(
          id: 'pick-one-category',
          label: 'Pick whichever category sounds closest and stop there',
          explanation:
              'A real situation can touch more than one category at once. '
              'Stopping at the first guess can miss a category worth '
              'checking.',
        ),
        ScenarioChoiceOption(
          id: 'check-both-categories',
          label: 'Check both categories through the official channel',
          explanation:
              'This is the useful step: a situation touching more than one '
              'category is worth checking against each one, not just the '
              'first that comes to mind.',
        ),
      ],
      preferredOptionId: 'check-both-categories',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Feedback in this lesson\'s matching activity says a benefit '
        'category "may apply" for a fictional life event. What does that '
        'mean?',
    choices: [
      'That the claim has already been approved',
      'That the category is worth investigating further through the '
          'official channel, nothing more',
      'That no further check is ever needed once a category is matched',
    ],
    correctIndex: 1,
    explanation:
        'Matching a category is the start of a check, not the end of one. '
        'What actually happens still depends on membership, contributions, '
        'and the current rules for that benefit.',
    whyWrong:
        'A category match narrows down where to look; it does not skip the '
        'verification this course teaches in the next lesson.',
  ),
  keyTakeaway:
      'Eight categories, one starting point each. A match means "worth '
      'checking", never "approved".',
);

// ---------------------------------------------------------------------------
// Lesson 3: Check Before You Count on It
// ---------------------------------------------------------------------------

const _checkBeforeYouCountOnIt = MoneyLesson(
  id: sspRefCheckBeforeYouCount,
  trackId: 'sss_philhealth_benefits',
  title: 'Check Before You Count on It',
  icon: 'checklist',
  minutes: 3,
  summary:
      'A private readiness checklist. It sorts what is worth verifying, '
      'never what you qualify for.',
  objective:
      'Identify which of your own records and rules are worth checking '
      'before counting on an SSS benefit.',
  sections: [],
  governance: _governanceHigh,
  sources: [_sssContributionTable, _sssBenefits],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Before counting on any SSS benefit, a few things are worth '
            'verifying directly: membership category, the posted '
            'contribution record, the qualifying period that applies, the '
            'required notification or filing process, the documentary '
            'requirements, and the current official rules for that '
            'benefit.',
        'This checklist never calculates a contribution gap or a benefit '
            'amount. It never estimates eligibility, a pension value, or a '
            'claim outcome. It only names what is worth checking, and '
            'points at where to check it.',
      ],
    ),
    NuggetsBlock([
      'A posted contribution record can differ from what was actually '
          'paid, especially for a self employed or voluntary member, so '
          'checking it directly matters.',
      'The current official rules, not a remembered figure, decide a '
          'qualifying period or a documentary requirement.',
    ]),
    RiskWarningBlock(
      title: 'This never calculates eligibility or an amount',
      text:
          'This never states a contribution gap. This never states a '
          'benefit amount. This never calculates eligibility, a pension '
          'value, or a claim outcome. Only the official channel can '
          'confirm any of those.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _sssAgency,
      sourceTitle: _sssContributionTableTitle,
      canonicalUrl: _sssContributionTableUrl,
      lastVerifiedDate: _sssContributionTableVerified,
    ),
    OfficialSourceBlock(
      agency: _sssAgency,
      sourceTitle: _sssBenefitsTitle,
      canonicalUrl: _sssBenefitsUrl,
      lastVerifiedDate: _sssBenefitsVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    RiskReviewChecklistBlock(
      blockId: 'sss-check-before-readiness',
      checklistPrompt:
          'A private readiness check, before counting on a '
          'benefit',
      foundationCount: 2,
      items: [
        ChecklistItemDef(
          id: 'membership-category',
          label: 'Membership category confirmed',
          explanation:
              'Employed, self employed, voluntary, and other categories '
              'carry their own rules.',
        ),
        ChecklistItemDef(
          id: 'posted-contribution-record',
          label: 'Posted contribution record checked directly',
          explanation:
              'What is posted can differ from what was actually paid, '
              'especially for a self employed or voluntary member.',
        ),
        ChecklistItemDef(
          id: 'qualifying-period',
          label: 'Applicable qualifying period reviewed',
          explanation:
              'Confirmed against the current official rules for that '
              'specific benefit.',
        ),
        ChecklistItemDef(
          id: 'filing-process',
          label: 'Required notification or filing process reviewed',
          explanation:
              'What has to be reported, and by when, comes from the '
              'current official process.',
        ),
        ChecklistItemDef(
          id: 'documentary-requirements',
          label: 'Documentary requirements reviewed',
          explanation:
              'What has to be submitted for that specific benefit, '
              'confirmed directly.',
        ),
        ChecklistItemDef(
          id: 'current-official-rules',
          label: 'Current official rules for this benefit checked',
          explanation:
              'Rules can change, so a current check matters more than a '
              'remembered one.',
        ),
      ],
      foundationSummary: 'Start with your official account or an SSS office',
      partialSummary: 'Some records to check',
      completeSummary: 'Ready to verify',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'sss-check-before-myth-checklist-guarantees-approval',
      statement:
          'Checking every item on this list guarantees a future claim '
          'will be approved.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'This checklist only names what is worth verifying beforehand. '
          'Whether a specific claim is approved still depends on the '
          'current official rules and the details of that specific claim.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'sss-check-before-unsure-record-scenario',
      scenarioTitle: 'A fictional record that might not match',
      situation:
          'A fictional member is not sure whether their posted '
          'contribution record matches what they actually paid. What is '
          'the useful next step?',
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
        'checked. What does that mean, according to this lesson?',
    choices: [
      'That a specific future claim is now guaranteed to be approved',
      'That every item worth checking beforehand has been reviewed, '
          'nothing more',
      'That no further contact with SSS is ever needed again',
    ],
    correctIndex: 1,
    explanation:
        'A completed checklist means the readiness items this lesson names '
        'have been reviewed. It never approves anything and never removes '
        'the need to check current rules later.',
    whyWrong:
        'Reviewing what to check is not the same as an approval, and rules '
        'or records can still change later.',
  ),
  keyTakeaway:
      'Verify membership, contributions, timing, and process before '
      'counting on a benefit. This checklist never calculates or approves '
      'anything.',
);

// ---------------------------------------------------------------------------
// Lesson 4: How PhilHealth Coverage Works
// ---------------------------------------------------------------------------

const _howPhilhealthCoverageWorks = MoneyLesson(
  id: sspRefHowCoverageWorks,
  trackId: 'sss_philhealth_benefits',
  title: 'How PhilHealth Coverage Works',
  icon: 'health',
  minutes: 4,
  summary:
      'What a case rate or benefit package actually promises, and what to '
      'confirm with a provider before a planned procedure.',
  objective:
      'Separate what a PhilHealth benefit package can cover from what '
      'still depends on the provider and the current rules.',
  sections: [],
  governance: _governanceHighYearScoped,
  sources: [
    _philhealthUhc,
    _philhealthCaseRates,
    _philhealthCirculars,
    _philhealthAccreditedFacilities,
  ],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'What a PhilHealth benefit actually covers depends on the '
            'applicable benefit package, whether the provider is '
            'accredited, the setting of care, and the current rules in '
            'effect.',
        'A published case rate or benefit package is not a guarantee that '
            'every part of a specific hospital bill will be covered. Any '
            'remaining amount, and what it actually is, comes from that '
            'provider\'s own billing, not from the case rate alone.',
        'When practical, confirming a provider\'s current accreditation '
            'and asking directly what is covered before a planned '
            'procedure is worth doing every time.',
      ],
    ),
    NuggetsBlock([
      'A case rate is a reference figure tied to a benefit package, not a '
          'promise that a bill will be fully covered.',
      'Accreditation can change, so a current check matters more than a '
          'remembered one.',
    ]),
    RiskWarningBlock(
      title: 'A case rate is not a full coverage guarantee',
      text:
          'A published case rate or benefit package amount is a reference '
          'figure under current rules, not a promise that a specific '
          'hospital bill will be fully covered. Confirm coverage directly '
          'with the accredited provider.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthUhcTitle,
      canonicalUrl: _philhealthUhcUrl,
      lastVerifiedDate: _philhealthUhcVerified,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthCaseRatesTitle,
      canonicalUrl: _philhealthCaseRatesUrl,
      lastVerifiedDate: _philhealthCaseRatesVerified,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthCircularsTitle,
      canonicalUrl: _philhealthCircularsUrl,
      lastVerifiedDate: _philhealthCircularsVerified,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthAccreditedFacilitiesTitle,
      canonicalUrl: _philhealthAccreditedFacilitiesUrl,
      lastVerifiedDate: _philhealthAccreditedFacilitiesVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    MythOrFactBlock(
      blockId: 'philhealth-coverage-myth-case-rate-guarantee',
      statement:
          'A published case rate means the entire hospital bill will '
          'always be paid by PhilHealth.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A case rate is a reference figure for a benefit package under '
          'current rules. It is not a promise that every part of a '
          'specific hospital bill will be covered.',
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'philhealth-before-during-after-care',
      checklistPrompt: 'Before care, during care, after care',
      items: [
        ChecklistItemDef(
          id: 'confirm-accreditation',
          label: 'Confirm the provider\'s current accreditation',
        ),
        ChecklistItemDef(
          id: 'ask-whats-covered',
          label:
              'Ask directly what is covered under the applicable '
              'package',
        ),
        ChecklistItemDef(
          id: 'ask-about-remaining-costs',
          label: 'Ask whether any amount is likely to remain out of pocket',
        ),
        ChecklistItemDef(
          id: 'keep-documents',
          label: 'Keep copies of the documents the provider asks for',
        ),
        ChecklistItemDef(
          id: 'confirm-facility-files-claim',
          label: 'Confirm how the provider files the claim, and when',
        ),
        ChecklistItemDef(
          id: 'review-final-bill',
          label: 'Review the final bill breakdown line by line',
        ),
        ChecklistItemDef(
          id: 'confirm-case-rate-applied',
          label: 'Confirm which case rate or package was actually applied',
        ),
        ChecklistItemDef(
          id: 'check-remaining-amount',
          label: 'Check whether any remaining amount is still owed',
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'philhealth-coverage-planned-procedure-scenario',
      scenarioTitle: 'A fictional planned procedure',
      situation:
          'A fictional patient is scheduling a planned procedure at a '
          'provider they have not used before. What is the useful step '
          'before the procedure, when practical?',
      options: [
        ScenarioChoiceOption(
          id: 'assume-full-coverage',
          label:
              'Assume the published case rate covers the entire bill and '
              'move ahead',
          explanation:
              'A case rate is a reference figure, not a promise of full '
              'coverage. Assuming it covers everything skips a check worth '
              'doing.',
        ),
        ScenarioChoiceOption(
          id: 'confirm-with-provider',
          label:
              'Confirm accreditation and ask the provider directly what is '
              'covered',
          explanation:
              'This is the useful step: confirming accreditation and '
              'coverage directly with the provider before the procedure, '
              'when practical.',
        ),
      ],
      preferredOptionId: 'confirm-with-provider',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional provider quotes a case rate for a planned procedure. '
        'What does this lesson say about that figure?',
    choices: [
      'It guarantees the entire bill is covered, since it comes from '
          'PhilHealth',
      'It is a reference figure under current rules; confirming '
          'accreditation and asking the provider directly is still worth '
          'doing',
      'It only applies if the patient asks for it in writing beforehand',
    ],
    correctIndex: 1,
    explanation:
        'A case rate reflects a benefit package under current rules, not a '
        'guarantee that a specific bill is fully covered. Confirming '
        'accreditation and coverage directly with the provider is the '
        'useful next step.',
    whyWrong:
        'Asking for something in writing is a reasonable habit, but it is '
        'not what determines whether a case rate applies; the applicable '
        'package and current rules do.',
  ),
  keyTakeaway:
      'A case rate is a reference figure, not a full coverage guarantee. '
      'Confirm accreditation and ask what is covered directly with the '
      'provider.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Use Primary Care Earlier
// ---------------------------------------------------------------------------

const _usePrimaryCareEarlier = MoneyLesson(
  id: sspRefPrimaryCareEarlier,
  trackId: 'sss_philhealth_benefits',
  title: 'Use Primary Care Earlier',
  icon: 'search',
  minutes: 3,
  summary:
      'Administrative next steps for using accredited primary care '
      'earlier, through the current YAKAP program. Never medical advice.',
  objective:
      'Build a short next-step checklist for using accredited primary care '
      'through the current YAKAP program.',
  sections: [],
  governance: _governanceHigh,
  sources: [_philhealthYakap, _philhealthAccreditedFacilities],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'YAKAP is PhilHealth\'s current primary care program. Checking the '
            'current program information, finding an accredited clinic, '
            'and confirming what is actually covered directly with that '
            'clinic are the useful administrative steps here, not a '
            'diagnosis or a treatment plan.',
        'What documents or registration steps are currently required can '
            'differ by clinic and can change over time, so confirming '
            'directly, rather than assuming from a past visit or someone '
            'else\'s experience, is worth doing.',
        'This lesson is administrative education. It never diagnoses a '
            'condition, recommends a treatment, or promises that a service '
            'is free or fully covered.',
      ],
    ),
    NuggetsBlock([
      'A registered primary care provider is a real starting point for '
          'routine and preventive care, worth using earlier rather than '
          'only during an emergency.',
      'What is covered, and what any registration involves, is confirmed '
          'directly with the clinic and the current program information, '
          'never assumed.',
    ]),
    RiskWarningBlock(
      title: 'This is administrative education, not medical advice',
      text:
          'This lesson never diagnoses a condition, recommends a '
          'treatment, or promises that a service is free or fully covered. '
          'A healthcare provider, not this lesson, answers a medical '
          'question.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthYakapTitle,
      canonicalUrl: _philhealthYakapUrl,
      lastVerifiedDate: _philhealthYakapVerified,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthAccreditedFacilitiesTitle,
      canonicalUrl: _philhealthAccreditedFacilitiesUrl,
      lastVerifiedDate: _philhealthAccreditedFacilitiesVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'primary-care-next-steps',
      checklistPrompt: 'Build your next health admin step',
      items: [
        ChecklistItemDef(
          id: 'check-current-yakap-info',
          label: 'Check the current YAKAP program information',
        ),
        ChecklistItemDef(
          id: 'find-accredited-clinic',
          label: 'Find an accredited clinic nearby',
        ),
        ChecklistItemDef(
          id: 'confirm-covered-services',
          label:
              'Confirm available covered services directly with the '
              'clinic',
        ),
        ChecklistItemDef(
          id: 'ask-registration-steps',
          label:
              'Ask what documents or registration steps are currently '
              'required',
        ),
        ChecklistItemDef(
          id: 'decide-next-step',
          label: 'Decide on one next primary care or preventive step',
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'primary-care-symptom-question-scenario',
      scenarioTitle: 'A fictional symptom question',
      situation:
          'A fictional reader asks this lesson whether a specific symptom '
          'needs treatment. What should this lesson answer?',
      options: [
        ScenarioChoiceOption(
          id: 'this-lesson-tells-you',
          label: 'This lesson tells them exactly what treatment to get',
          explanation:
              'This lesson never diagnoses a condition or recommends a '
              'treatment. That is a healthcare provider\'s role, not a '
              'course reading\'s.',
        ),
        ScenarioChoiceOption(
          id: 'ask-a-provider',
          label:
              'Ask a healthcare provider directly; this lesson is not '
              'medical advice',
          explanation:
              'This is the accurate answer. A medical question always goes '
              'to a healthcare provider, never to this lesson.',
        ),
      ],
      preferredOptionId: 'ask-a-provider',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'primary-care-myth-always-free',
      statement:
          'Every service offered through a primary care clinic is '
          'automatically free or fully covered.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'What is covered, and on what terms, depends on the applicable '
          'program and the current rules. Confirming directly with the '
          'clinic is the reliable way to know, not an assumption.',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'This lesson\'s checklist asks a fictional reader to confirm '
        'covered services directly with a clinic. Why not just list what '
        'is covered here instead?',
    choices: [
      'Because covered services and registration steps can differ by '
          'clinic and change over time, so a current, direct check is more '
          'reliable than a fixed list',
      'Because PhilHealth does not allow this information to be shared',
      'Because primary care services are never covered under any '
          'circumstance',
    ],
    correctIndex: 0,
    explanation:
        'Coverage and registration details are set by the current program '
        'rules and can differ by clinic, so a direct, current check is the '
        'reliable way to know, not a list fixed at the time this course was '
        'written.',
    whyWrong:
        'Neither the sharing restriction nor a blanket no coverage claim '
        'reflects how this lesson actually treats the program.',
  ),
  keyTakeaway:
      'Check the current program information, find an accredited clinic, '
      'and confirm coverage directly. This lesson is administrative '
      'education, never medical advice.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Build Your Safety-Net Plan
// ---------------------------------------------------------------------------

const _buildYourSafetyNetPlan = MoneyLesson(
  id: sspRefSafetyNetPlan,
  trackId: 'sss_philhealth_benefits',
  title: 'Build Your Safety-Net Plan',
  icon: 'target',
  minutes: 3,
  summary:
      'A short private action plan pulling this course together, and real '
      'Salapify screens to open if useful.',
  objective:
      'Turn this course into a short list of next steps, and open the '
      'Salapify screens that already fit.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_sssBenefits, _philhealthUhc],
  topics: [ContentTopic.governmentBenefitEligibility],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A short action plan pulls this course together: review the '
            'official SSS contribution record, review PhilHealth '
            'membership information, name one official question still '
            'worth resolving, and strengthen an emergency or medical '
            'buffer in Salapify.',
        'None of this is calculated or approved by this lesson. Every step '
            'here points at an official source or an existing Salapify '
            'screen, never a new government account, a claim filing tool, '
            'or a benefits calculator.',
      ],
    ),
    NuggetsBlock([
      'A short list of specific next steps is more useful than a general '
          'intention to check on this someday.',
      'Strengthening a buffer already in Salapify is a real step available '
          'today, independent of anything SSS or PhilHealth eventually '
          'confirms.',
    ]),
    RiskWarningBlock(
      title: 'This plan never estimates a benefit or approves anything',
      text:
          'Nothing in this plan calculates a contribution, a benefit '
          'amount, a pension, or a reimbursement, and nothing here '
          'approves a claim. Every figure and outcome still comes from the '
          'official channel.',
    ),
    OfficialSourceBlock(
      agency: _sssAgency,
      sourceTitle: _sssBenefitsTitle,
      canonicalUrl: _sssBenefitsUrl,
      lastVerifiedDate: _sssBenefitsVerified,
    ),
    OfficialSourceBlock(
      agency: _philhealthAgency,
      sourceTitle: _philhealthUhcTitle,
      canonicalUrl: _philhealthUhcUrl,
      lastVerifiedDate: _philhealthUhcVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'safety-net-plan-checklist',
      checklistPrompt: 'A short, private action plan',
      items: [
        ChecklistItemDef(
          id: 'review-sss-contribution-record',
          label: 'Review the official SSS contribution record',
        ),
        ChecklistItemDef(
          id: 'review-philhealth-membership',
          label: 'Review PhilHealth membership information',
        ),
        ChecklistItemDef(
          id: 'name-one-official-question',
          label: 'Name one official question still worth resolving',
        ),
        ChecklistItemDef(
          id: 'strengthen-buffer',
          label: 'Strengthen an emergency or medical buffer in Salapify',
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'safety-net-plan-unsure-question-scenario',
      scenarioTitle: 'A fictional unresolved question',
      situation:
          'A fictional reader finishes this course still unsure about one '
          'specific detail of their own coverage. What is the useful next '
          'step?',
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
      blockId: 'sss-philhealth-salapify-actions',
      menuPrompt: 'A few real, safe things to do next, if any of them fit',
      actions: [
        // Batch C1B income-connection: SSS, PhilHealth and Pag-IBIG are the
        // deductions between gross pay and take-home pay, so the course points
        // at the calculator that shows exactly that flow. Concise link, not a
        // rewrite of the course.
        SalapifyActionDef(
          id: 'see-take-home-after-deductions',
          label: 'See your take-home pay',
          description:
              'Opens the Take-home pay calculator, which shows gross pay minus '
              'SSS, PhilHealth, Pag-IBIG and tax, so these contributions show '
              'up as the deductions they are. Nothing is saved; it only '
              'calculates.',
          route: 'salary',
        ),
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
          id: 'add-contribution-reminder',
          label: 'Add a recurring contribution reminder',
          description:
              'Opens Recurring, where a contribution payment can be added '
              'by hand using the existing add flow. Nothing is created '
              'automatically, and nothing is added until it is confirmed '
              'there.',
          route: 'recurring',
        ),
        SalapifyActionDef(
          id: 'review-budget-for-contributions',
          label: 'Review Budget for contributions',
          description:
              'Opens Budget so a contribution amount can be planned for '
              'honestly alongside everything else. Nothing is added or '
              'changed until something is entered there.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'open-reminders',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where reminders can be '
              'turned on. There is no SSS or PhilHealth specific reminder '
              'type yet, so nothing is scheduled automatically; this is '
              'the closest real screen for building a periodic check-in '
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
      'It has approved a specific SSS or PhilHealth benefit',
      'It has organized real, private next steps; nothing here calculates '
          'or approves anything',
      'It has filed a claim on the reader\'s behalf',
    ],
    correctIndex: 1,
    explanation:
        'This plan never calculates a benefit, approves a claim, or files '
        'anything. It only organizes what is worth checking and doing '
        'next, through the official channel or an existing Salapify '
        'screen.',
    whyWrong:
        'Nothing in this course files a claim or issues an approval; those '
        'steps only ever happen through SSS or PhilHealth directly.',
  ),
  keyTakeaway:
      'Review your official records, name one question, and strengthen '
      'your own buffer. This plan organizes next steps; it never '
      'calculates or approves anything.',
);
