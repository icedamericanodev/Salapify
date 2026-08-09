// Money Courses Phase 9: the "Protect Your Future" learning path's first
// course, "Insurance Decoded" (course id 'insurance_decoded'). A new path,
// separate from "Grow Your Money": its own path id, its own progress
// namespace key (settings.expansionProgress['protect_your_future']), and
// built entirely from the already-shipped architecture (governance
// metadata, official-source and risk-warning blocks, Phase 5 interaction
// blocks) rather than adding anything new to the core model.
//
// This course teaches how to identify a protection need and how term,
// whole-life, and variable-unit-linked (VUL) policies differ, so a reader
// can ask better questions before speaking with an insurer or agent. It
// never promotes or attacks any product: no lesson recommends a policy
// type, no interaction outcome says "Best policy", "Recommended insurer",
// "Buy term", "Buy VUL", "Avoid VUL", "Approved", or "Suitable", and every
// Salapify action offered at the end is a safe, existing, non-insurance
// specific screen (Budget, Recurring, Notifications and security, Goals)
// opened manually, never an automatic write, a purchase, or contact with an
// agent.
//
// House rules, same as the other Grow Your Money courses: plain English,
// Philippine peso framing only where needed, no em or en dash, no named
// insurer, agent, or policy anywhere in this file, no guaranteed-outcome
// language, no personalized recommendation, no claim that a license or
// registration guarantees suitability, and every fictional policy or
// household used as an example is invented for this course and never a
// real one.
//
// Content topics: ContentTopic.insuranceOrVul on every lesson, the same
// discipline the other regulated Grow Your Money courses follow. That
// makes this course honestly "regulated" under
// money/expansion_content_policy.dart's own definition, which activates the
// Phase 4 validator's mandatory official-source, risk-warning, and
// educational-boundary checks. Lessons 1 to 4 are classified
// ContentVolatility.annual, matching the general product-education content
// in the rest of the Grow Your Money courses. Lessons 5 and 6 are
// classified ContentVolatility.high with a shorter review cycle: the task's
// own instruction is to treat regulatory, licensed-agent, consumer-rights,
// and cooling-off information as time-sensitive, and those two lessons are
// exactly where that information lives (reading a policy's cancellation
// rights, and verifying an insurer's or agent's current status).
//
// Cooling-off periods deliberately carry no specific day count in this
// file. The Insurance Code and the Insurance Commission's own rules set
// that figure, and a course cannot embed it once and stay correct: this
// content instead teaches that a cancellation right exists early in most
// individual life policies and points the reader at the policy document
// itself and the Insurance Commission's current guidance for the exact
// period and conditions that apply right now. Per this phase's own
// instruction ("if official sources conflict or a rule cannot be verified,
// omit the claim and report it"), the exact figure was left out and is
// reported as a deferred risk rather than guessed.
//
// Sources: the Insurance Commission's own site, the Amended Insurance Code
// (Republic Act No. 10607), the Commission's variable-life guidelines
// (Circular Letter No. 2017-34), and the IRR of the Financial Products and
// Services Consumer Protection Act (Republic Act No. 11765). No insurer
// marketing, agent presentation, social-media post, blog, or generated
// claim was used as a factual source, per the task's own instruction. This
// course's regulatory framing was reviewed by the legal-compliance-counsel
// agent before shipping (see governance.reviewerId below).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

// Plain string constants, not fields on a shared object: see
// lessons_grow.dart's own comment on why a const OfficialSourceBlock call
// needs these as top-level identifiers rather than reading them off a
// const LessonSourceInfo instance's field.
const _icAgency = 'Insurance Commission';

const _icCodeTitle =
    'Republic Act No. 10607, The Amended Insurance Code of the Philippines';
const _icCodeUrl =
    'https://www.insurance.gov.ph/wp-content/uploads/2022/04/Republic-Act-No.-10607-2013.pdf';
const _icCodeVerified = '2026-08';

const _icCode = LessonSourceInfo(
  agency: _icAgency,
  title: _icCodeTitle,
  canonicalUrl: _icCodeUrl,
  lastVerifiedDate: _icCodeVerified,
);

const _icVulTitle =
    'Circular Letter No. 2017-34, Revised Guidelines on Variable Life '
    'Insurance Contracts';
const _icVulUrl =
    'https://www.insurance.gov.ph/wp-content/uploads/2022/09/CL2017_34.pdf';
const _icVulVerified = '2026-08';

const _icVul = LessonSourceInfo(
  agency: _icAgency,
  title: _icVulTitle,
  canonicalUrl: _icVulUrl,
  lastVerifiedDate: _icVulVerified,
);

const _icFpscpaTitle =
    'IRR of Republic Act No. 11765, the Financial Products and Services '
    'Consumer Protection Act';
// URL note (Batch C2, 2026-08): the earlier value ended in `_published.pdf`.
// Independent WebSearch verification could confirm only the non-suffixed PDF
// (this value) and the landing page insurance.gov.ph/imc2023-01/; the
// `_published` variant never surfaced in any search result, exactly the
// well-formed-but-unconfirmable shape the source-governance process exists to
// catch. Corrected to the search-confirmed path.
const _icFpscpaUrl =
    'https://www.insurance.gov.ph/wp-content/uploads/2023/03/IMC-2023-01_IRR-of-R.A.-No.-11765-Otherwise-Known-as-the-Financial-Products-and-Services-Consumer-Protection-Act.pdf';
const _icFpscpaVerified = '2026-08';

const _icFpscpa = LessonSourceInfo(
  agency: _icAgency,
  title: _icFpscpaTitle,
  canonicalUrl: _icFpscpaUrl,
  lastVerifiedDate: _icFpscpaVerified,
);

const _icMainTitle = 'Insurance Commission';
const _icMainUrl = 'https://www.insurance.gov.ph/';
const _icMainVerified = '2026-08';

const _icMain = LessonSourceInfo(
  agency: _icAgency,
  title: _icMainTitle,
  canonicalUrl: _icMainUrl,
  lastVerifiedDate: _icMainVerified,
);

// General product-education governance: annual review, matching the rest of
// the Grow Your Money courses' own default cycle.
const _governanceAnnual = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'LCC',
);

// Regulatory, licensed-agent, consumer-rights, and cooling-off content: a
// shorter review window, per this phase's own instruction to treat that
// category of fact as time-sensitive.
const _governanceHigh = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-02',
  reviewerId: 'LCC',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel: 'the Insurance Commission',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form by the same convention every other
/// Money Courses lesson id uses. Never reused for a different lesson once a
/// learner has real progress recorded against one.
const insuranceRefWhatItsFor = 'insurance-what-its-for';
const insuranceRefProtectionNeed = 'insurance-protection-need';
const insuranceRefTermAndWholeLife = 'insurance-term-and-whole-life';
const insuranceRefVulNoSalesPitch = 'insurance-vul-no-sales-pitch';
const insuranceRefReadThePolicy = 'insurance-read-the-policy';
const insuranceRefVerifyCompareDecide = 'insurance-verify-compare-decide';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// list: the "X of 22" figure on the core Learn screen must never move
/// because of this file (see test/lessons_insurance_content_test.dart).
const List<MoneyLesson> insuranceDecodedLessons = [
  _whatInsuranceIsFor,
  _startWithTheProtectionNeed,
  _termAndWholeLifeInsurance,
  _vulWithoutTheSalesPitch,
  _readThePolicyBeforeSigning,
  _verifyCompareAndDecide,
];

// ---------------------------------------------------------------------------
// Lesson 1: What Insurance Is For
// ---------------------------------------------------------------------------

const _whatInsuranceIsFor = MoneyLesson(
  id: insuranceRefWhatItsFor,
  trackId: 'insurance_decoded',
  title: 'What Insurance Is For',
  icon: 'cushion',
  minutes: 5,
  summary:
      'Insurance transfers a defined financial risk under a contract. It is '
      'not an emergency fund, and it does not cover everything.',
  objective:
      'Tell insurance apart from savings and an emergency fund, and see '
      'what a policy\'s own terms actually decide.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_icCode],
  topics: [ContentTopic.insuranceOrVul],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Insurance is a contract that transfers a defined financial risk '
            'from a person to an insurer, in exchange for a premium. What '
            'counts as a covered event, what is excluded, what limits '
            'apply, and what has to be shown to file a claim all come from '
            'the specific policy, not from the general idea of "having '
            'insurance".',
        'Insurance is not a replacement for an emergency fund. An '
            'emergency fund is money kept ready and easy to reach for a '
            'sudden, everyday shock, a job loss, a car repair, an unplanned '
            'trip. A policy generally responds to the specific events it '
            'defines, not to every financial surprise a household can '
            'have.',
        'Paying a premium keeps a policy active. It does not by itself '
            'guarantee that every future claim will be approved: whether a '
            'claim is paid depends on the coverage, the exclusions, the '
            'limits, and the claim requirements written into that policy.',
        'Protection and investing are separate goals, even when a single '
            'product combines both. This course looks at each goal on its '
            'own terms before looking at any product that tries to do '
            'both at once.',
      ],
    ),
    NuggetsBlock([
      'Insurance answers "what happens if a specific, defined risk shows '
          'up", not "what happens if I run short of cash this month".',
      'The policy document, not a general impression of what insurance '
          'does, decides what is actually covered.',
    ]),
    RiskWarningBlock(
      title: 'A premium keeps a policy active, not every claim approved',
      text:
          'Whether a specific claim is paid depends on that policy\'s own '
          'coverage, exclusions, limits, and claim requirements. This '
          'lesson is general education, not a review of any real policy.',
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icCodeTitle,
      canonicalUrl: _icCodeUrl,
      lastVerifiedDate: _icCodeVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'insurance-what-its-for-sorting',
      categorizePrompt:
          'Sort each fictional need into the tool built to handle it.',
      buckets: [
        CategorizeBucket(id: 'insurance', label: 'Insurance'),
        CategorizeBucket(id: 'savings', label: 'Savings'),
        CategorizeBucket(id: 'emergency-fund', label: 'Emergency fund'),
      ],
      items: [
        CategorizeItemDef(
          id: 'sudden-car-repair',
          label:
              'Money that stays easily reachable for a sudden car repair '
              'next month',
          explanation:
              'This is what an emergency fund is built for: a small, '
              'unpredictable shock that needs cash quickly.',
        ),
        CategorizeItemDef(
          id: 'planned-trip-fund',
          label:
              'A fixed amount set aside every month toward a trip planned '
              'for next year',
          explanation:
              'This is a savings goal: a known amount, for a known '
              'purpose, on a known timeline.',
        ),
        CategorizeItemDef(
          id: 'replace-lost-income',
          label:
              'A way to replace income dependents would lose if an income '
              'earner died unexpectedly',
          explanation:
              'This is what insurance is built for: transferring a '
              'specific, defined risk under a contract, in exchange for a '
              'premium.',
        ),
        CategorizeItemDef(
          id: 'temporary-job-loss',
          label:
              'Money kept ready in case of a temporary job loss lasting a '
              'few months',
          explanation:
              'This is an emergency fund again: accessible money for an '
              'everyday shock, not a specific insured event.',
        ),
        CategorizeItemDef(
          id: 'serious-illness-cost',
          label:
              'The cost of a serious illness, transferred to a contract in '
              'exchange for a premium',
          explanation:
              'This is insurance: a defined risk transferred under a '
              'contract, exactly what this lesson is about.',
        ),
        CategorizeItemDef(
          id: 'downpayment-goal',
          label:
              'Money grown gradually toward a foreseeable large purchase, '
              'like a downpayment',
          explanation:
              'This is a savings goal: expected, planned, and building '
              'toward a known future purchase.',
        ),
      ],
      correctBucketByItemId: {
        'sudden-car-repair': 'emergency-fund',
        'planned-trip-fund': 'savings',
        'replace-lost-income': 'insurance',
        'temporary-job-loss': 'emergency-fund',
        'serious-illness-cost': 'insurance',
        'downpayment-goal': 'savings',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'insurance-what-its-for-myth-premiums-cover-everything',
      statement: 'Paying premiums means every future claim will be covered.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Paying a premium keeps a policy active. Whether a specific '
          'claim is paid still depends on that policy\'s own coverage, '
          'exclusions, limits, and claim requirements, not on the fact '
          'that premiums were paid on time.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-what-its-for-savings-question',
      scenarioTitle: 'Does insurance remove the need for savings?',
      situation:
          'A fictional person wonders whether buying insurance means they '
          'can stop keeping any savings or emergency fund at all. What '
          'does this lesson say?',
      options: [
        ScenarioChoiceOption(
          id: 'insurance-replaces-savings',
          label: 'Yes, insurance replaces the need for any savings',
          explanation:
              'Insurance and savings solve different problems. An '
              'emergency fund covers everyday shocks a policy is not built '
              'to handle, so one does not replace the other.',
        ),
        ScenarioChoiceOption(
          id: 'different-problems',
          label:
              'No, insurance and savings solve different problems and '
              'usually work together',
          explanation:
              'This is the accurate read. Insurance transfers a defined '
              'risk; savings and an emergency fund stay ready for '
              'everyday, undefined shocks. Most households benefit from '
              'having both.',
        ),
      ],
      preferredOptionId: 'different-problems',
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-what-its-for-denied-claim-scenario',
      scenarioTitle: 'A fictional claim is denied',
      situation:
          'A fictional policyholder paid every premium on time, then filed '
          'a claim for an event the policy specifically excludes. What is '
          'the accurate read?',
      options: [
        ScenarioChoiceOption(
          id: 'paying-on-time-guarantees-payout',
          label: 'Paying every premium on time means the claim must be paid',
          explanation:
              'Paying on time keeps a policy active, but it does not '
              'override what the policy itself defines as covered or '
              'excluded. An excluded event stays excluded regardless of '
              'payment history.',
        ),
        ScenarioChoiceOption(
          id: 'exclusions-still-apply',
          label:
              'The policy\'s own exclusions still apply, regardless of '
              'payment history',
          explanation:
              'This is the accurate read. What is covered, and what is '
              'excluded, comes from the policy document itself, not from '
              'how faithfully premiums were paid.',
        ),
      ],
      preferredOptionId: 'exclusions-still-apply',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional household wants to know whether an emergency fund is '
        'still worth keeping once they buy a life insurance policy. Based '
        'on this lesson, what is the accurate answer?',
    choices: [
      'No, a life insurance policy makes an emergency fund unnecessary',
      'Yes, an emergency fund and insurance solve different problems and '
          'generally work together',
      'It depends only on how large the policy\'s coverage amount is',
    ],
    correctIndex: 1,
    explanation:
        'Insurance transfers a specific, defined risk. An emergency fund '
        'stays ready for everyday, undefined shocks a policy is not built '
        'to handle. Most households benefit from having both, not one '
        'instead of the other.',
    whyWrong:
        'The size of a coverage amount does not change what kind of risk a '
        'policy is built to respond to; it is still a defined-risk '
        'contract, not a general-purpose emergency fund.',
  ),
  keyTakeaway:
      'Insurance transfers a defined risk under a contract. It is not an '
      'emergency fund, and the policy\'s own terms, not a premium receipt, '
      'decide what gets paid.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Start With the Protection Need
// ---------------------------------------------------------------------------

const _startWithTheProtectionNeed = MoneyLesson(
  id: insuranceRefProtectionNeed,
  trackId: 'insurance_decoded',
  title: 'Start With the Protection Need',
  icon: 'foundation',
  minutes: 6,
  summary:
      'A reflection worksheet, not a coverage calculator: what to think '
      'through before comparing any policy.',
  objective:
      'Work through the questions a protection need actually depends on, '
      'without landing on a number.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_icMain],
  topics: [ContentTopic.insuranceOrVul],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Before comparing any policy, it helps to think through what a '
            'protection need actually depends on. That includes who relies '
            'on your income, what debts or obligations would remain, and '
            'what a funeral or final expense might realistically cost. It '
            'also includes what coverage already exists through an employer '
            'or a personal policy, how much emergency savings is already '
            'available, and roughly how long that protection might be '
            'needed.',
        'This is a reflection worksheet, not a coverage calculator. It '
            'will not produce a recommended coverage amount, and it will '
            'never label anyone underinsured. Those are judgment calls a '
            'person makes for themselves, usually with more detail than a '
            'short lesson can responsibly ask for.',
      ],
    ),
    NuggetsBlock([
      'A protection need is a question about a household\'s own '
          'circumstances, not a number a lesson can hand out.',
      'What exists already, employer coverage, personal savings, another '
          'policy, is as much a part of the picture as what is missing.',
    ]),
    RiskWarningBlock(
      title: 'This is a reflection, not a coverage calculation',
      text:
          'This lesson never produces a recommended coverage amount and '
          'never labels anyone underinsured. It only names the questions '
          'worth thinking through before that conversation happens with an '
          'insurer or agent.',
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icMainTitle,
      canonicalUrl: _icMainUrl,
      lastVerifiedDate: _icMainVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ScenarioChoiceBlock(
      blockId: 'insurance-protection-need-household-a',
      scenarioTitle: 'A fictional household, thinking this through',
      situation:
          'A fictional household has two dependents, an outstanding home '
          'loan, and no employer-provided life coverage. What is the most '
          'useful next step this lesson would point to?',
      options: [
        ScenarioChoiceOption(
          id: 'pick-a-round-number',
          label: 'Pick a round coverage number that sounds sufficient',
          explanation:
              'A number chosen without working through dependents, debts, '
              'existing coverage, and savings is a guess, not a reviewed '
              'need. This lesson deliberately does not hand out a number.',
        ),
        ScenarioChoiceOption(
          id: 'work-through-the-checklist',
          label:
              'Work through dependents, debts, existing coverage, and '
              'savings first, in their own words',
          explanation:
              'This is the useful step: naming what is actually at stake '
              'before any conversation about a specific policy or amount.',
        ),
      ],
      preferredOptionId: 'work-through-the-checklist',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-protection-need-household-b',
      scenarioTitle: 'A second fictional household, further along',
      situation:
          'A fictional household has grown children who are financially '
          'independent, no debt, and a fully funded emergency fund. How '
          'might their protection need differ from a household still '
          'raising young children?',
      options: [
        ScenarioChoiceOption(
          id: 'need-is-identical',
          label: 'Their protection need is identical to any other household',
          explanation:
              'The questions this lesson asks, dependents, debts, existing '
              'coverage, savings, timeline, can point to a very different '
              'picture from one household to the next. Treating every '
              'household the same skips the reflection entirely.',
        ),
        ScenarioChoiceOption(
          id: 'need-can-differ',
          label:
              'Their protection need can look very different once the '
              'same questions are worked through',
          explanation:
              'This is the point of starting with the need rather than a '
              'product: the same set of questions can lead to very '
              'different answers for different households.',
        ),
      ],
      preferredOptionId: 'need-can-differ',
      requiredForCompletion: false,
    ),
    ChecklistBlock(
      blockId: 'insurance-protection-need-checklist',
      checklistPrompt:
          'A private worksheet: think through each area, in your own '
          'words',
      items: [
        ChecklistItemDef(
          id: 'financial-dependents',
          label: 'Who financially depends on your income, if anyone',
          explanation:
              'This is about who relies on your income, not their names. '
              'Nothing here is saved or backed up.',
        ),
        ChecklistItemDef(
          id: 'income-others-rely-on',
          label: 'What that income actually covers for them day to day',
          explanation:
              'A rough sense of what would be missing, not an exact peso '
              'figure.',
        ),
        ChecklistItemDef(
          id: 'debts-and-obligations',
          label: 'Debts and obligations that would remain',
          explanation:
              'A loan or obligation that would not disappear on its own.',
        ),
        ChecklistItemDef(
          id: 'funeral-final-expenses',
          label: 'A rough sense of funeral or final expenses',
          explanation:
              'A cost that is easy to overlook until it is suddenly '
              'urgent.',
        ),
        ChecklistItemDef(
          id: 'existing-coverage',
          label: 'Existing employer or personal coverage already in place',
          explanation:
              'What already exists is as important as what might be '
              'missing.',
        ),
        ChecklistItemDef(
          id: 'available-emergency-savings',
          label: 'Emergency savings already available',
          explanation:
              'Savings and insurance work together; knowing what already '
              'exists changes the picture.',
        ),
        ChecklistItemDef(
          id: 'how-long-protection-needed',
          label: 'Roughly how long this protection might be needed',
          explanation:
              'A young family\'s timeline and a near-retirement '
              'household\'s timeline are rarely the same.',
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    ReflectionPromptBlock(
      blockId: 'insurance-protection-need-exposed-reflection',
      question:
          'After thinking through the checklist above, what would still '
          'be left financially exposed for your household right now?',
      choices: [
        ReflectionChoice(
          id: 'income-replacement',
          label: 'Replacing lost income for dependents',
        ),
        ReflectionChoice(
          id: 'debt-repayment',
          label: 'Paying off a debt or obligation',
        ),
        ReflectionChoice(
          id: 'final-expenses',
          label: 'Covering funeral or final expenses',
        ),
        ReflectionChoice(id: 'not-sure-yet', label: 'Not sure yet'),
      ],
      allowFreeText: true,
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional reader finishes this lesson\'s worksheet and asks for '
        'the coverage amount it recommends. What should this lesson '
        'answer?',
    choices: [
      'A specific peso amount, based on the checklist answers given',
      'That this lesson never produces a recommended amount; it only '
          'names the questions worth thinking through',
      'That anyone who has not answered every question is underinsured',
    ],
    correctIndex: 1,
    explanation:
        'This lesson is a reflection worksheet, not a coverage calculator. '
        'It deliberately never produces a recommended amount and never '
        'labels anyone underinsured.',
    whyWrong:
        'Leaving a question unanswered here does not amount to a verdict '
        'about anyone\'s coverage; the worksheet is private and optional, '
        'never a graded assessment.',
  ),
  keyTakeaway:
      'Start with dependents, debts, existing coverage, and timeline, in '
      'your own words. A number comes later, from you, never from this '
      'lesson.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Term and Whole-Life Insurance
// ---------------------------------------------------------------------------

const _termAndWholeLifeInsurance = MoneyLesson(
  id: insuranceRefTermAndWholeLife,
  trackId: 'insurance_decoded',
  title: 'Term and Whole-Life Insurance',
  icon: 'balance',
  minutes: 6,
  summary:
      'Two different shapes of life insurance, compared neutrally. The '
      'actual policy terms control, not a general rule about which type '
      'is better.',
  objective:
      'Compare term and whole-life insurance across what each actually '
      'promises, without picking a winner.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_icCode],
  topics: [ContentTopic.insuranceOrVul],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Term insurance provides coverage for a defined period. Premiums '
            'are the obligation that keeps it active, and the policy '
            'carries no automatic assumption of building any investment '
            'value. What happens at the end of the term, whether it can '
            'be renewed or converted, and on what conditions, is set by '
            'that specific policy.',
        'Whole-life insurance is built for longer-duration protection, '
            'subject to the policy\'s own terms. Some whole-life policies '
            'carry a cash or policy value where the contract provides for '
            'one, along with loan, surrender, and lapse considerations '
            'attached to that value. Any such value has guaranteed and '
            'non-guaranteed components, and the two are not the same '
            'thing.',
        'Neither type works identically across every policy. The actual '
            'terms in the contract, not a general description of "term" '
            'or "whole life", decide what a specific policy promises.',
      ],
    ),
    NuggetsBlock([
      'A policy\'s own terms control. A general description of a policy '
          'type is a starting point for questions, never a substitute for '
          'reading the actual contract.',
      'A guaranteed figure and a non-guaranteed, illustrated figure can '
          'sit side by side in the same policy summary; only the contract '
          'says which is which.',
    ]),
    RiskWarningBlock(
      title: 'Actual policy terms control, not a general rule',
      text:
          'Nothing here claims one type of policy works identically for '
          'everyone, or that one type is always the better choice. The '
          'specific contract\'s terms are what actually apply.',
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icCodeTitle,
      canonicalUrl: _icCodeUrl,
      lastVerifiedDate: _icCodeVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ComparisonBlock(
      blockId: 'insurance-term-whole-comparison',
      title: 'Term and whole life, side by side',
      criteria: [
        ComparisonCriterion(id: 'duration', label: 'Coverage duration'),
        ComparisonCriterion(id: 'premiums', label: 'Premium obligation'),
        ComparisonCriterion(id: 'value', label: 'Cash or policy value'),
        ComparisonCriterion(id: 'stop-paying', label: 'If premiums stop'),
      ],
      items: [
        ComparisonItem(
          id: 'term',
          name: 'Term insurance',
          valuesByCriterionId: {
            'duration': 'A defined period, set by the policy.',
            'premiums': 'Required to keep coverage active for that period.',
            'value': 'No automatic assumption of building investment value.',
            'stop-paying':
                'Depends on the specific policy\'s own terms for renewal, '
                'conversion, or lapse.',
          },
        ),
        ComparisonItem(
          id: 'whole-life',
          name: 'Whole-life insurance',
          valuesByCriterionId: {
            'duration':
                'Longer-duration protection, subject to the policy\'s own '
                'terms.',
            'premiums':
                'Duration set by the policy; some structures shorten how '
                'long premiums are payable.',
            'value':
                'May carry a cash or policy value where the contract '
                'provides for one, with guaranteed and non-guaranteed '
                'parts.',
            'stop-paying':
                'Depends on the specific policy\'s own loan, surrender, '
                'and lapse provisions.',
          },
        ),
      ],
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'insurance-term-whole-question-matching',
      categorizePrompt:
          'Match each fictional situation to the question it should raise '
          'with an insurer.',
      buckets: [
        CategorizeBucket(
          id: 'coverage-length',
          label: 'How long does coverage last?',
        ),
        CategorizeBucket(
          id: 'stop-paying-q',
          label: 'What happens if I stop paying?',
        ),
        CategorizeBucket(
          id: 'builds-value-q',
          label: 'Does this policy build any value?',
        ),
        CategorizeBucket(
          id: 'whats-guaranteed-q',
          label: 'What exactly is guaranteed?',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'coverage-until-college',
          label:
              'A fictional parent wants coverage only until their '
              'youngest child finishes school, nothing beyond that',
          explanation:
              'This points straight at coverage duration: exactly how '
              'long the policy protects for, and what happens after that.',
        ),
        CategorizeItemDef(
          id: 'worried-about-a-missed-payment',
          label:
              'A fictional policyholder is worried about missing a '
              'premium payment during a lean month',
          explanation:
              'This points at what happens if premiums stop or are '
              'missed, including any grace period or lapse rule.',
        ),
        CategorizeItemDef(
          id: 'heard-about-surrender',
          label:
              'A fictional policyholder heard a policy can be surrendered '
              'for cash later and wants to know if theirs can',
          explanation:
              'This points at whether the policy builds any cash or '
              'policy value, and on what terms it can be accessed.',
        ),
        CategorizeItemDef(
          id: 'wants-to-know-locked-in',
          label:
              'A fictional policyholder wants to know which numbers in a '
              'proposal are locked in and which can change',
          explanation:
              'This points directly at the guaranteed versus '
              'non-guaranteed distinction, the core question a proposal '
              'should always make clear.',
        ),
      ],
      correctBucketByItemId: {
        'coverage-until-college': 'coverage-length',
        'worried-about-a-missed-payment': 'stop-paying-q',
        'heard-about-surrender': 'builds-value-q',
        'wants-to-know-locked-in': 'whats-guaranteed-q',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'insurance-term-whole-myth-wasted-money',
      statement:
          'Term insurance is money wasted if the term ends and no claim '
          'was ever made.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Paying for term coverage bought protection for that period, '
          'similar to paying for the use of something over time. Nothing '
          'was wasted simply because the protection was never claimed on.',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'insurance-term-whole-myth-always-better',
      statement:
          'Whole-life insurance is always the better choice because it '
          'may build value over time.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Cost, purpose, and how long premiums stay payable differ '
          'between the two, and the actual terms in a specific contract '
          'control. No single type is always the better choice for every '
          'household.',
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-term-whole-price-vs-value-scenario',
      scenarioTitle: 'A fictional trade-off, not a verdict',
      situation:
          'A fictional young parent wants the largest possible coverage '
          'amount for the lowest possible monthly premium while their '
          'children are still small. What does this lesson suggest as the '
          'next step?',
      options: [
        ScenarioChoiceOption(
          id: 'this-decides-it',
          label:
              'That preference on its own settles which type of policy '
              'is right',
          explanation:
              'A preference for lower premiums and larger coverage is '
              'useful information, but the actual answer still depends on '
              'the specific policy terms on offer, not a general rule.',
        ),
        ScenarioChoiceOption(
          id: 'ask-dont-assume',
          label:
              'That trade-off is worth asking about directly with an '
              'insurer, not assumed from a general rule',
          explanation:
              'This is the useful next step: naming the trade-off clearly '
              'and asking specific questions about it, rather than '
              'assuming one type of policy is automatically the answer.',
        ),
      ],
      preferredOptionId: 'ask-dont-assume',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional reader asks this lesson to name whether term or '
        'whole-life insurance is generally the better choice. What does '
        'this lesson say?',
    choices: [
      'Whole-life is always better because it can build value',
      'Term is always better because whole-life costs more',
      'Neither is a universal answer; the actual terms of the specific '
          'policy decide what it promises',
    ],
    correctIndex: 2,
    explanation:
        'This lesson deliberately never ranks the two. What a specific '
        'policy actually promises depends on its own terms, not on a '
        'blanket rule about term versus whole-life.',
    whyWrong:
        'A general claim that one type "always" wins overstates what a '
        'category name can tell you; the same word can describe policies '
        'with very different terms.',
  ),
  keyTakeaway:
      'Term and whole-life solve differently shaped problems. Ask specific '
      'questions about the actual contract, never assume from the '
      'category name alone.',
);

// ---------------------------------------------------------------------------
// Lesson 4: VUL Without the Sales Pitch
// ---------------------------------------------------------------------------

const _vulWithoutTheSalesPitch = MoneyLesson(
  id: insuranceRefVulNoSalesPitch,
  trackId: 'insurance_decoded',
  title: 'VUL Without the Sales Pitch',
  icon: 'percent',
  minutes: 7,
  summary:
      'A variable-unit-linked policy combines protection with '
      'investment-linked value that can rise or fall. Illustrations are '
      'not guarantees.',
  objective:
      'Follow a fictional premium through where it goes, and tell a '
      'guaranteed figure apart from an illustrated one.',
  sections: [],
  governance: _governanceAnnual,
  sources: [_icVul, _icCode],
  topics: [ContentTopic.insuranceOrVul],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A variable-unit-linked, or VUL, policy combines life-insurance '
            'protection with investment-linked policy values. Those '
            'investment-linked values can rise or fall, and investment '
            'risk may be borne by the policyholder according to the '
            'contract.',
        'A premium is not paid straight into a single growing balance. It '
            'may be allocated across insurance costs, charges, and '
            'investment units, and those charges can affect the policy '
            'and fund value over time.',
        'Stopping premiums may affect coverage or value, depending on the '
            'contract. Surrendering a VUL policy early may produce less '
            'than the total premiums paid in, especially in the earlier '
            'years of the policy.',
        'Illustrations shown alongside a VUL policy are not guaranteed '
            'future results. They are projections built on an assumed '
            'rate, not a promise. A licensed agent presenting a policy '
            'does not make every recommendation suitable for the person '
            'receiving it; a license is not a suitability guarantee.',
      ],
    ),
    DiagramBlock(
      steps: [
        'A fictional premium is received',
        'A portion covers the insurance charge for that period',
        'A portion covers administrative charges',
        'What remains is allocated to investment units, subject to any '
            'fund-management charge that applies',
        'The value of those units can rise or fall from there',
      ],
      caption:
          'A simplified flow only, with no rates attached. The exact '
          'order and size of each charge comes from the specific '
          'contract.',
    ),
    NuggetsBlock([
      'An illustration is a projection built on an assumed rate, not a '
          'promise of what will actually happen.',
      'A license lets someone sell or advise on a policy. It does not by '
          'itself make any specific recommendation suitable for the '
          'person receiving it.',
    ]),
    RiskWarningBlock(
      title: 'Illustrated values are not guaranteed',
      text:
          'The projected values shown alongside a VUL policy are built on '
          'an assumed rate and are not guaranteed. Actual fund performance '
          'can be higher or lower, and charges reduce what is actually '
          'available regardless of the illustration shown.',
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icVulTitle,
      canonicalUrl: _icVulUrl,
      lastVerifiedDate: _icVulVerified,
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icCodeTitle,
      canonicalUrl: _icCodeUrl,
      lastVerifiedDate: _icCodeVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'insurance-vul-charge-categories',
      categorizePrompt:
          'Sort each fictional deduction into the charge category it '
          'represents.',
      buckets: [
        CategorizeBucket(id: 'insurance-charge', label: 'Insurance charges'),
        CategorizeBucket(id: 'admin-charge', label: 'Administrative charges'),
        CategorizeBucket(id: 'fund-charge', label: 'Fund-management charges'),
        CategorizeBucket(
          id: 'surrender-charge',
          label: 'Surrender or withdrawal charges',
        ),
        CategorizeBucket(id: 'rider-charge', label: 'Rider charges'),
      ],
      items: [
        CategorizeItemDef(
          id: 'cost-of-coverage',
          label:
              'A deduction covering the cost of the life coverage itself '
              'for that period',
          explanation:
              'This is an insurance charge: the cost of the protection '
              'element of the policy.',
        ),
        CategorizeItemDef(
          id: 'policy-maintenance-fee',
          label: 'A recurring fee for maintaining and servicing the policy',
          explanation:
              'This is an administrative charge: the cost of running the '
              'policy itself.',
        ),
        CategorizeItemDef(
          id: 'fund-manager-fee',
          label:
              'A fee applied to the invested units for managing the '
              'underlying fund',
          explanation:
              'This is a fund-management charge, applied to the '
              'investment-linked portion of the policy.',
        ),
        CategorizeItemDef(
          id: 'early-cash-out-fee',
          label:
              'A charge that applies if the policy is cashed in during '
              'its early years',
          explanation:
              'This is a surrender or withdrawal charge, tied to accessing '
              'value earlier than the policy assumes.',
        ),
        CategorizeItemDef(
          id: 'extra-benefit-fee',
          label:
              'A charge for an optional extra benefit added on top of '
              'the base policy',
          explanation:
              'This is a rider charge: the cost of an optional benefit '
              'attached to the base policy.',
        ),
      ],
      correctBucketByItemId: {
        'cost-of-coverage': 'insurance-charge',
        'policy-maintenance-fee': 'admin-charge',
        'fund-manager-fee': 'fund-charge',
        'early-cash-out-fee': 'surrender-charge',
        'extra-benefit-fee': 'rider-charge',
      },
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'insurance-vul-policy-summary-checklist',
      checklistPrompt: 'A fictional VUL policy summary, reviewed by category',
      items: [
        ChecklistItemDef(
          id: 'summary-insurance-charge',
          label: 'An insurance charge is deducted from each premium',
          explanation: 'Covers the cost of the protection element.',
        ),
        ChecklistItemDef(
          id: 'summary-admin-charge',
          label: 'An administrative charge is deducted from each premium',
          explanation: 'Covers the cost of running the policy.',
        ),
        ChecklistItemDef(
          id: 'summary-fund-charge',
          label: 'A fund-management charge applies to the invested units',
          explanation: 'Covers managing the underlying investment fund.',
        ),
        ChecklistItemDef(
          id: 'summary-guaranteed-benefit',
          label:
              'A guaranteed minimum benefit is stated in the contract '
              'itself',
          explanation:
              'This figure is set by the contract, not by an assumed '
              'rate.',
        ),
        ChecklistItemDef(
          id: 'summary-illustrated-value',
          label:
              'A non-guaranteed, illustrated fund value is shown at an '
              'assumed rate',
          explanation:
              'This figure is a projection, not a promise of the actual '
              'future value.',
        ),
        ChecklistItemDef(
          id: 'summary-surrender-charge',
          label: 'A surrender charge may apply if cashed in early',
          explanation:
              'Access to value in the early years can cost less than the '
              'stated value suggests.',
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
    CategorizeBlock(
      blockId: 'insurance-vul-guaranteed-vs-illustrated',
      categorizePrompt:
          'Sort each fictional figure into guaranteed or illustrated.',
      buckets: [
        CategorizeBucket(id: 'guaranteed', label: 'Guaranteed'),
        CategorizeBucket(
          id: 'illustrated',
          label: 'Illustrated, not guaranteed',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'contract-minimum-benefit',
          label: 'The minimum death benefit stated directly in the contract',
          explanation: 'A figure the contract itself commits to is guaranteed.',
        ),
        CategorizeItemDef(
          id: 'projected-fund-value',
          label:
              'The projected fund value shown at a chosen assumed rate '
              'in a sales proposal',
          explanation:
              'A projection built on an assumed rate is illustrated, not '
              'a promise of the actual outcome.',
        ),
        CategorizeItemDef(
          id: 'actual-future-value',
          label: 'The exact fund value the policy will actually reach',
          explanation:
              'No one can state this in advance; the actual future value '
              'is never guaranteed, only estimated.',
        ),
        CategorizeItemDef(
          id: 'fact-that-charges-reduce-value',
          label:
              'The fact that charges apply and can reduce fund value over '
              'time',
          explanation:
              'That charges exist and affect value is a contractual '
              'reality, not a projection: it is a guaranteed mechanism, '
              'even though the exact peso impact varies.',
        ),
      ],
      correctBucketByItemId: {
        'contract-minimum-benefit': 'guaranteed',
        'projected-fund-value': 'illustrated',
        'actual-future-value': 'illustrated',
        'fact-that-charges-reduce-value': 'guaranteed',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'insurance-vul-myth-illustration-guaranteed',
      statement:
          'The projected values shown in a VUL sales illustration are '
          'guaranteed results.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'An illustration is a projection built on an assumed rate, not '
          'a promise. Actual fund performance can be higher or lower than '
          'what any illustration shows.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-vul-stop-premiums-scenario',
      scenarioTitle: 'A fictional policyholder stops paying early',
      situation:
          'A fictional policyholder stops paying premiums on a VUL policy '
          'earlier than planned. What does this lesson say could happen?',
      options: [
        ScenarioChoiceOption(
          id: 'nothing-changes',
          label:
              'Nothing changes; coverage and fund value continue exactly '
              'as illustrated',
          explanation:
              'Stopping premiums can affect coverage or fund value, '
              'depending on the specific contract. Assuming nothing '
              'changes overstates what an illustration promises.',
        ),
        ScenarioChoiceOption(
          id: 'may-be-affected',
          label:
              'Coverage or fund value may be affected, depending on the '
              'exact contract',
          explanation:
              'This is the accurate read. What actually happens depends '
              'on that specific policy\'s own terms, not on the original '
              'illustration.',
        ),
      ],
      preferredOptionId: 'may-be-affected',
      requiredForCompletion: true,
      riskNote: RiskWarningBlock(
        title: 'Check the specific contract, not the original proposal',
        text:
            'What happens if premiums stop is set by the policy\'s own '
            'terms. The original sales proposal is not a substitute for '
            'reading that provision directly.',
      ),
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-vul-early-surrender-scenario',
      scenarioTitle: 'A fictional early surrender',
      situation:
          'A fictional policyholder surrenders a VUL policy in its early '
          'years. Based on this lesson, what is the realistic '
          'expectation?',
      options: [
        ScenarioChoiceOption(
          id: 'at-least-premiums-paid',
          label:
              'The amount received back will be at least what was paid '
              'in total premiums',
          explanation:
              'Surrendering early may produce less than total premiums '
              'paid, once charges and market movement are accounted for. '
              'Assuming a full return overstates what usually happens.',
        ),
        ScenarioChoiceOption(
          id: 'may-be-less',
          label:
              'The amount received back may be less than total premiums paid',
          explanation:
              'This is the realistic expectation this lesson teaches, '
              'especially in a policy\'s early years, once charges and '
              'fund performance are both accounted for.',
        ),
      ],
      preferredOptionId: 'may-be-less',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional sales illustration shows a VUL policy\'s projected '
        'fund value growing steadily over twenty years. What does this '
        'lesson say about that projection?',
    choices: [
      'It is a guaranteed result, since it comes from a licensed insurer',
      'It is a projection built on an assumed rate, not a promise of the '
          'actual outcome',
      'It becomes guaranteed once a licensed agent signs off on it',
    ],
    correctIndex: 1,
    explanation:
        'An illustration is built on an assumed rate and is not '
        'guaranteed, regardless of who presents it. Actual fund '
        'performance can be higher or lower than any illustration shows.',
    whyWrong:
        'A license lets someone sell or advise on a policy; it does not '
        'convert a projection into a guarantee, and a licensed agent does '
        'not make every recommendation suitable for the person receiving '
        'it.',
  ),
  keyTakeaway:
      'A VUL policy\'s illustrated value is a projection, not a promise. '
      'Ask what is guaranteed, what can change, and what happens if '
      'premiums stop or the policy is surrendered early.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Read the Policy Before Signing
// ---------------------------------------------------------------------------

const _readThePolicyBeforeSigning = MoneyLesson(
  id: insuranceRefReadThePolicy,
  trackId: 'insurance_decoded',
  title: 'Read the Policy Before Signing',
  icon: 'document',
  minutes: 7,
  summary:
      'Where to look in a policy document, and what each part actually '
      'tells you. A fictional summary to practice on, never a real one.',
  objective:
      'Locate the guaranteed benefits, the exclusions, and the '
      'cancellation rights in a fictional policy summary.',
  sections: [],
  governance: _governanceHigh,
  sources: [_icFpscpa, _icCode],
  topics: [ContentTopic.insuranceOrVul],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A policy document holds the actual answers a proposal or a '
            'conversation can only summarize. Reading it before signing '
            'means knowing what to look for and roughly where to find it.',
        'Many individual life insurance policies include a cancellation '
            'right early in the policy, sometimes called a free look or '
            'cooling-off period. It lets a policyholder cancel under the '
            'conditions the policy and current rules set.',
        'The exact length of that period, and the conditions attached to '
            'it, can differ by product type, for example an ordinary life '
            'policy versus a health rider, and can change over time. So it '
            'should always be confirmed on the actual policy document and '
            'through the Insurance Commission\'s current guidance, never '
            'assumed from memory or from a different policy.',
        'Many individual life policies also carry a contestability '
            'period, a defined stretch after the policy starts during '
            'which an insurer can still contest a claim over how the '
            'application was answered. What changes once that period '
            'ends, and what does not, comes from the policy\'s own '
            'wording.',
      ],
    ),
    DiagramBlock(
      steps: [
        'Confirm the policy owner and the insured person',
        'Find the coverage amount and the coverage period',
        'Note the premium amount and how long premiums are payable',
        'Separate the guaranteed benefits from any non-guaranteed or '
            'illustrated values',
        'Read the exclusions, waiting periods, and any riders attached',
        'Check the grace period and the lapse and reinstatement rules',
        'Note the contestability period, and what changes once it ends',
        'Check the withdrawal and surrender provisions, and what filing a '
            'claim actually requires',
        'Find the cancellation or cooling-off right, and the complaint '
            'channel',
      ],
      caption:
          'A rough order to search in, not the only order a real policy '
          'document follows.',
    ),
    NuggetsBlock([
      'A guaranteed benefit and an illustrated, non-guaranteed value can '
          'sit on the same page. Only the wording tells them apart.',
      'A complaint channel exists for a reason. Knowing where it is costs '
          'nothing and matters only if it is ever needed.',
    ]),
    RiskWarningBlock(
      title: 'Cancellation and cooling-off rights can change',
      text:
          'The exact length and conditions of any cancellation or '
          'cooling-off right come from the current policy and current '
          'Insurance Commission rules, not from a general description in '
          'this lesson. Confirm the current period directly before relying '
          'on it.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icFpscpaTitle,
      canonicalUrl: _icFpscpaUrl,
      lastVerifiedDate: _icFpscpaVerified,
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icCodeTitle,
      canonicalUrl: _icCodeUrl,
      lastVerifiedDate: _icCodeVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'insurance-read-policy-guaranteed-highlight',
      categorizePrompt:
          'Sort each line from a fictional policy summary into guaranteed '
          'or non-guaranteed.',
      buckets: [
        CategorizeBucket(id: 'guaranteed', label: 'Guaranteed'),
        CategorizeBucket(
          id: 'non-guaranteed',
          label: 'Non-guaranteed or illustrated',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'stated-death-benefit',
          label: 'The death benefit amount stated in the schedule of benefits',
          explanation:
              'A figure named directly in the policy schedule is a '
              'guaranteed contract term.',
        ),
        CategorizeItemDef(
          id: 'illustrated-dividend',
          label:
              'A projected dividend shown at a current, non-guaranteed '
              'assumed scale',
          explanation:
              'A dividend or bonus shown at an assumed scale is '
              'illustrated, not promised.',
        ),
        CategorizeItemDef(
          id: 'stated-premium',
          label:
              'The premium amount and payment frequency stated in the '
              'schedule',
          explanation: 'A stated premium obligation is a guaranteed term.',
        ),
        CategorizeItemDef(
          id: 'illustrated-cash-value',
          label:
              'A projected cash value shown for a future policy year at '
              'an assumed rate',
          explanation:
              'A future projection built on an assumed rate is '
              'illustrated, not guaranteed.',
        ),
      ],
      correctBucketByItemId: {
        'stated-death-benefit': 'guaranteed',
        'illustrated-dividend': 'non-guaranteed',
        'stated-premium': 'guaranteed',
        'illustrated-cash-value': 'non-guaranteed',
      },
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'insurance-read-policy-find-exclusion',
      categorizePrompt:
          'Sort each fictional clause into what kind of clause it is.',
      buckets: [
        CategorizeBucket(id: 'exclusion', label: 'Exclusion'),
        CategorizeBucket(id: 'covered-benefit', label: 'Covered benefit'),
        CategorizeBucket(id: 'claim-requirement', label: 'Claim requirement'),
      ],
      items: [
        CategorizeItemDef(
          id: 'clause-not-covered-event',
          label:
              'A clause stating a specific named event is not covered '
              'under this policy',
          explanation:
              'A clause that removes an event from coverage is an '
              'exclusion, one of the most important clauses to find '
              'before signing.',
        ),
        CategorizeItemDef(
          id: 'clause-death-benefit',
          label:
              'A clause stating the death benefit payable if the insured '
              'person dies during the policy term',
          explanation: 'This is the core covered benefit of the policy.',
        ),
        CategorizeItemDef(
          id: 'clause-proof-of-claim',
          label:
              'A clause listing the documents that must be submitted to '
              'file a claim',
          explanation:
              'This is a claim requirement: what must be provided for a '
              'claim to be processed.',
        ),
        CategorizeItemDef(
          id: 'clause-waiting-period',
          label:
              'A clause stating a benefit only applies after a defined '
              'waiting period from the policy\'s start',
          explanation:
              'A waiting period is a form of exclusion during that '
              'window: the benefit does not apply until it passes.',
        ),
      ],
      correctBucketByItemId: {
        'clause-not-covered-event': 'exclusion',
        'clause-death-benefit': 'covered-benefit',
        'clause-proof-of-claim': 'claim-requirement',
        'clause-waiting-period': 'exclusion',
      },
      requiredForCompletion: true,
    ),
    ComparisonBlock(
      blockId: 'insurance-read-policy-compare-two-summaries',
      title: 'Two fictional policy summaries, side by side',
      criteria: [
        ComparisonCriterion(id: 'coverage-amount', label: 'Coverage amount'),
        ComparisonCriterion(id: 'coverage-period', label: 'Coverage period'),
        ComparisonCriterion(
          id: 'premium-duration',
          label: 'Premium payment duration',
        ),
        ComparisonCriterion(
          id: 'guaranteed-benefits',
          label: 'Guaranteed benefits',
        ),
        ComparisonCriterion(id: 'exclusions', label: 'Named exclusions'),
        ComparisonCriterion(id: 'grace-period', label: 'Grace period'),
        ComparisonCriterion(
          id: 'cancellation-right',
          label: 'Cancellation right noted',
        ),
      ],
      items: [
        ComparisonItem(
          id: 'fictional-policy-a',
          name: 'Fictional Policy A',
          valuesByCriterionId: {
            'coverage-amount': 'Stated in its own schedule of benefits.',
            'coverage-period': 'A defined term, stated in the contract.',
            'premium-duration': 'Payable for the length of the term.',
            'guaranteed-benefits': 'A stated death benefit amount.',
            'exclusions': 'Named directly in its own exclusions section.',
            'grace-period':
                'Stated as a number of days after a missed '
                'due date.',
            'cancellation-right':
                'Present, with conditions set by the policy and current '
                'rules.',
          },
        ),
        ComparisonItem(
          id: 'fictional-policy-b',
          name: 'Fictional Policy B',
          valuesByCriterionId: {
            'coverage-amount': 'Stated in its own schedule of benefits.',
            'coverage-period': 'Longer duration, subject to its own terms.',
            'premium-duration':
                'A different payable period than Policy A, per its own '
                'schedule.',
            'guaranteed-benefits':
                'A stated minimum benefit, separate from any illustrated '
                'value.',
            'exclusions': 'A different set of named exclusions than Policy A.',
            'grace-period':
                'Also stated as a number of days, per its own '
                'terms.',
            'cancellation-right':
                'Present, with its own conditions set by the policy and '
                'current rules.',
          },
        ),
      ],
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'insurance-read-policy-questions-checklist',
      checklistPrompt: 'Questions worth asking before signing anything',
      items: [
        ChecklistItemDef(
          id: 'q-whats-guaranteed',
          label: 'What exactly is guaranteed, in writing?',
        ),
        ChecklistItemDef(
          id: 'q-whats-excluded',
          label: 'What is specifically excluded from coverage?',
        ),
        ChecklistItemDef(
          id: 'q-grace-and-lapse',
          label:
              'What is the grace period, and what happens if a payment '
              'is missed?',
        ),
        ChecklistItemDef(
          id: 'q-cancellation-right',
          label:
              'What is the current cancellation or cooling-off right, and '
              'how is it used?',
        ),
        ChecklistItemDef(
          id: 'q-contestability',
          label:
              'What is the contestability period, and what changes once '
              'it ends?',
        ),
        ChecklistItemDef(
          id: 'q-claim-process',
          label: 'What has to be submitted to file a claim?',
        ),
        ChecklistItemDef(
          id: 'q-complaint-channel',
          label: 'Where does a complaint go if something feels wrong?',
        ),
      ],
      allRequiredMustBeChecked: false,
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional policy summary lists a benefit, then separately lists '
        'a projected value shown at an assumed rate. What does this '
        'lesson say about telling the two apart?',
    choices: [
      'Both are guaranteed once they appear on the same schedule page',
      'The stated benefit is a contract term; the projected value is an '
          'illustration, and the wording is what tells them apart',
      'Neither is reliable, since both come from the same document',
    ],
    correctIndex: 1,
    explanation:
        'A stated benefit is a contract term the insurer commits to. A '
        'projected value built on an assumed rate is an illustration, not '
        'a promise. The document\'s own wording, not its position on the '
        'page, is what separates the two.',
    whyWrong:
        'Appearing on the same page does not make two very different '
        'kinds of figures equally binding; each keeps the status the '
        'wording actually gives it.',
  ),
  keyTakeaway:
      'A policy document has real answers. Find the guaranteed benefits, '
      'the exclusions, the cancellation right, and the complaint channel '
      'before signing anything.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Verify, Compare and Decide
// ---------------------------------------------------------------------------

const _verifyCompareAndDecide = MoneyLesson(
  id: insuranceRefVerifyCompareDecide,
  trackId: 'insurance_decoded',
  title: 'Verify, Compare and Decide',
  icon: 'checklist',
  minutes: 7,
  summary:
      'A private review pulling this course together. Verify the insurer '
      'and the agent, ask the real questions, and never decide under '
      'pressure.',
  objective:
      'Work through verifying an insurer and an agent, and rehearse the '
      'questions worth asking before signing anything.',
  sections: [],
  governance: _governanceHigh,
  sources: [_icMain, _icFpscpa],
  topics: [ContentTopic.insuranceOrVul],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Before signing anything, a few checks are worth doing every '
            'time: verify the insurer through the Insurance Commission, '
            'verify the agent\'s current license, confirm the exact legal '
            'product and insurer name, and request official policy '
            'documents rather than relying on a summary or a screenshot.',
        'From there, the real questions are the same ones this course '
            'has been building toward: what is guaranteed, what may '
            'change, what every charge actually is, what happens if '
            'premiums stop, and how claims work. None of this needs to be '
            'rushed, and no legitimate offer needs to be decided under '
            'pressure today.',
      ],
    ),
    NuggetsBlock([
      'A registered insurer and a licensed agent are real, useful checks. '
          'Neither one, on its own, means every recommendation that '
          'follows is right for you.',
      'Keeping copies of official documents costs nothing and matters '
          'only later, exactly when it is needed most.',
    ]),
    RiskWarningBlock(
      title: 'Verifying is a real step, not a final answer',
      text:
          'Confirming an insurer\'s registration or an agent\'s license '
          'does not by itself mean any specific policy is right for you, '
          'and status can change over time. It is a real check worth '
          'doing every time, not the end of the thinking.',
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icMainTitle,
      canonicalUrl: _icMainUrl,
      lastVerifiedDate: _icMainVerified,
    ),
    OfficialSourceBlock(
      agency: _icAgency,
      sourceTitle: _icFpscpaTitle,
      canonicalUrl: _icFpscpaUrl,
      lastVerifiedDate: _icFpscpaVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ChecklistBlock(
      blockId: 'insurance-verify-agent-checklist',
      checklistPrompt: 'Insurer and agent verification checklist',
      items: [
        ChecklistItemDef(
          id: 'verify-insurer',
          label: 'Verified the insurer through the Insurance Commission',
          explanation:
              'A current check through the regulator itself, not a '
              'screenshot or a claim in a message.',
        ),
        ChecklistItemDef(
          id: 'verify-agent-license',
          label: 'Verified the agent\'s current license',
          explanation:
              'A license status can change, so a current check matters '
              'more than a remembered one.',
        ),
        ChecklistItemDef(
          id: 'confirm-legal-product-name',
          label: 'Confirmed the exact legal product and insurer name',
          explanation:
              'A marketing or brand name can differ from the exact legal '
              'entity and product name on file.',
        ),
        ChecklistItemDef(
          id: 'request-official-documents',
          label: 'Requested the official policy documents directly',
          explanation:
              'A summary or a verbal description is not the same as the '
              'actual contract.',
        ),
      ],
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'insurance-verify-pressure-red-flags',
      categorizePrompt: 'Sort each fictional situation into where it belongs.',
      buckets: [
        CategorizeBucket(id: 'red-flag', label: 'Red flag'),
        CategorizeBucket(id: 'reasonable', label: 'Reasonable'),
      ],
      items: [
        CategorizeItemDef(
          id: 'sign-today-only',
          label: 'A pitch says a rate or bonus disappears if not signed today',
          explanation:
              'Manufactured urgency is a pressure tactic, meant to stop '
              'someone from checking or comparing before deciding.',
        ),
        CategorizeItemDef(
          id: 'refuses-written-illustration',
          label:
              'A seller refuses to provide a written illustration or '
              'policy summary',
          explanation:
              'A legitimate offer can be put in writing. Refusing to do '
              'so is a clear warning sign.',
        ),
        CategorizeItemDef(
          id: 'discourages-reading-contract',
          label:
              'A seller discourages actually reading the policy contract '
              'before signing',
          explanation:
              'Discouraging the one document that actually controls the '
              'agreement is a serious red flag.',
        ),
        CategorizeItemDef(
          id: 'provides-written-illustration',
          label:
              'A seller provides a written illustration and encourages '
              'questions',
          explanation:
              'Providing documentation and welcoming questions is exactly '
              'what a reasonable process looks like.',
        ),
        CategorizeItemDef(
          id: 'takes-time-to-decide',
          label: 'Someone takes a few days to compare before deciding',
          explanation:
              'Taking time to compare and verify is reasonable. A '
              'legitimate offer does not usually need to be decided in '
              'minutes.',
        ),
      ],
      correctBucketByItemId: {
        'sign-today-only': 'red-flag',
        'refuses-written-illustration': 'red-flag',
        'discourages-reading-contract': 'red-flag',
        'provides-written-illustration': 'reasonable',
        'takes-time-to-decide': 'reasonable',
      },
      requiredForCompletion: true,
    ),
    ComparisonBlock(
      blockId: 'insurance-verify-policy-comparison-lab',
      title: 'A fictional decision lab: the same questions, two proposals',
      criteria: [
        ComparisonCriterion(
          id: 'whats-guaranteed',
          label: 'What is guaranteed',
        ),
        ComparisonCriterion(id: 'whats-charged', label: 'What is charged'),
        ComparisonCriterion(
          id: 'stop-paying-effect',
          label: 'Effect if premiums stop',
        ),
        ComparisonCriterion(id: 'claims-process', label: 'How claims work'),
      ],
      items: [
        ComparisonItem(
          id: 'fictional-proposal-a',
          name: 'Fictional Proposal A',
          valuesByCriterionId: {
            'whats-guaranteed': 'Stated directly in its own schedule.',
            'whats-charged': 'Named by category in its own summary.',
            'stop-paying-effect': 'Set by its own grace and lapse terms.',
            'claims-process': 'Documented in its own claims section.',
          },
        ),
        ComparisonItem(
          id: 'fictional-proposal-b',
          name: 'Fictional Proposal B',
          valuesByCriterionId: {
            'whats-guaranteed':
                'A different guaranteed figure, stated in its own '
                'schedule.',
            'whats-charged': 'A different set of named charges.',
            'stop-paying-effect':
                'Its own grace and lapse terms, not the '
                'same as Proposal A.',
            'claims-process':
                'Its own claims section, worth reading in '
                'full.',
          },
        ),
      ],
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-verify-scenario-sign-today',
      scenarioTitle: '"What would you ask next?": pressure to sign today',
      situation:
          'A fictional seller says a bonus rate expires at the end of the '
          'day and asks for a signature right now. What is the useful '
          'next move?',
      options: [
        ScenarioChoiceOption(
          id: 'sign-to-keep-the-rate',
          label: 'Sign now to keep the bonus rate from expiring',
          explanation:
              'Manufactured urgency is a pressure tactic. A legitimate '
              'offer does not usually disappear because someone asked for '
              'a day to check it.',
        ),
        ScenarioChoiceOption(
          id: 'ask-for-it-in-writing',
          label:
              'Ask for the offer and the illustration in writing, and '
              'take the time needed to verify and compare',
          explanation:
              'This is the useful move. A real offer can survive being '
              'checked; refusing to allow that is itself informative.',
        ),
      ],
      preferredOptionId: 'ask-for-it-in-writing',
      requiredForCompletion: true,
      riskNote: RiskWarningBlock(
        title: 'Urgency is a tactic, not a reason to skip verification',
        text:
            'No legitimate offer needs to be decided in minutes. Taking '
            'time to verify the insurer, the agent, and the actual policy '
            'terms is always a reasonable next step.',
      ),
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-verify-scenario-unclear-charges',
      scenarioTitle: '"What would you ask next?": unclear charges',
      situation:
          'A fictional proposal lists a single combined monthly cost, '
          'with no breakdown of what it actually covers. What is the '
          'useful next move?',
      options: [
        ScenarioChoiceOption(
          id: 'accept-the-total',
          label:
              'Accept the total figure, since a breakdown is not '
              'usually needed',
          explanation:
              'This lesson\'s own checklist asks specifically about every '
              'charge. A single combined figure hides exactly the '
              'question worth asking.',
        ),
        ScenarioChoiceOption(
          id: 'ask-for-the-breakdown',
          label:
              'Ask directly for the charge categories that make up that '
              'total',
          explanation:
              'This is the useful move: asking what the total is actually '
              'made of, category by category, before deciding anything.',
        ),
      ],
      preferredOptionId: 'ask-for-the-breakdown',
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'insurance-verify-scenario-unclear-insurer',
      scenarioTitle: '"What would you ask next?": which company, exactly',
      situation:
          'A fictional proposal shows a friendly brand name, but never '
          'states the exact legal insurer behind it. What is the useful '
          'next move?',
      options: [
        ScenarioChoiceOption(
          id: 'assume-brand-is-the-insurer',
          label: 'Assume the brand name is the licensed insurer itself',
          explanation:
              'A brand name and the exact legal insurer are not always '
              'the same thing. Assuming they match skips the one check '
              'that actually confirms who is on the other side of the '
              'contract.',
        ),
        ScenarioChoiceOption(
          id: 'confirm-the-legal-entity',
          label:
              'Ask for, and verify, the exact legal insurer name through '
              'the Insurance Commission',
          explanation:
              'This is the useful move: confirming the exact legal entity '
              'name directly, rather than assuming it from a brand or a '
              'logo.',
        ),
      ],
      preferredOptionId: 'confirm-the-legal-entity',
      requiredForCompletion: false,
    ),
    RiskReviewChecklistBlock(
      blockId: 'insurance-final-protection-review',
      checklistPrompt: 'A final review before any policy conversation',
      foundationCount: 3,
      items: [
        ChecklistItemDef(
          id: 'protection-need-considered',
          label: 'Protection need considered',
          explanation:
              'Dependents, debts, existing coverage, and timeline have '
              'been thought through.',
        ),
        ChecklistItemDef(
          id: 'emergency-fund-reviewed',
          label: 'Emergency fund reviewed',
          explanation:
              'Whether a buffer exists, and how funded it is, has been '
              'looked at separately from any policy.',
        ),
        ChecklistItemDef(
          id: 'budget-reviewed',
          label: 'Budget reviewed for the premium',
          explanation:
              'What a premium would actually take from the monthly '
              'budget has been looked at honestly.',
        ),
        ChecklistItemDef(
          id: 'insurer-verified',
          label: 'Insurer verified through the Insurance Commission',
          explanation: 'A current check, not a remembered or assumed one.',
        ),
        ChecklistItemDef(
          id: 'agent-license-verified',
          label: 'Agent\'s current license verified',
          explanation: 'License status can change over time.',
        ),
        ChecklistItemDef(
          id: 'guaranteed-vs-illustrated-understood',
          label: 'Guaranteed versus illustrated values understood',
          explanation:
              'Which figures the contract commits to, and which are '
              'projections, has been checked directly.',
        ),
        ChecklistItemDef(
          id: 'every-charge-understood',
          label: 'Every charge category understood',
          explanation:
              'What is actually being paid for, by category, has been '
              'asked about directly.',
        ),
        ChecklistItemDef(
          id: 'cooling-off-right-noted',
          label: 'Cancellation or cooling-off right noted',
          explanation:
              'The current period and conditions have been confirmed '
              'directly, not assumed.',
        ),
        ChecklistItemDef(
          id: 'no-pressure-involved',
          label: 'No pressure to decide immediately',
          explanation:
              'Nobody is rushing this decision, and there was time to '
              'compare and verify.',
        ),
        ChecklistItemDef(
          id: 'claims-process-understood',
          label: 'Claims process understood',
          explanation:
              'What filing a claim would actually require has been asked '
              'about directly.',
        ),
      ],
      foundationSummary: 'More information is needed',
      partialSummary: 'Review the policy details',
      completeSummary: 'You have completed a protection review',
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'insurance-salapify-actions',
      menuPrompt: 'A few real, safe things to do next, if any of them fit',
      actions: [
        SalapifyActionDef(
          id: 'add-premium-to-budget',
          label: 'Add premiums to Budget',
          description:
              'Opens Budget so a premium amount can be planned for '
              'honestly alongside everything else. Nothing is added or '
              'changed until something is entered there.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'add-recurring-premium',
          label: 'Add a recurring premium expense',
          description:
              'Opens Recurring, where a premium can be added by hand '
              'using the existing add flow. Nothing is created '
              'automatically, and no premium is added until it is '
              'confirmed there.',
          route: 'recurring',
        ),
        SalapifyActionDef(
          id: 'open-reminders',
          label: 'Open reminders',
          description:
              'Opens Notifications and security, where reminders can be '
              'turned on. There is no policy-specific reminder type yet, '
              'so nothing is scheduled automatically; this is the closest '
              'real screen for building a periodic check-in habit by hand.',
          route: 'notifications',
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
          id: 'create-protection-goal',
          label: 'Create a general protection goal',
          description:
              'Opens Goals to set up your own goal, in your own words, if '
              'you want one. Nothing is created automatically, and this '
              'never creates or purchases any policy.',
          route: 'goals',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A finished review shows the insurer verified and the agent '
        'license verified, but the cooling-off right and the claims '
        'process are still unchecked. What does that suggest?',
    choices: [
      'That the policy is not allowed to be purchased at all',
      'Those two areas are worth checking before any decision, nothing '
          'more, nothing less',
      'That the review has already approved the policy',
    ],
    correctIndex: 1,
    explanation:
        'This review never blocks anything and never approves anything. '
        'It names specifically what is still unchecked, so the areas '
        'worth looking at before any decision are clear.',
    whyWrong:
        'Nothing here is a rule, a lock, or an approval. Naming what is '
        'unchecked gives something concrete to review, not a verdict.',
  ),
  keyTakeaway:
      'Verify the insurer and the agent, ask the real questions, and take '
      'the time a real decision deserves. This review is a mirror, never '
      'an approval.',
);
