// Money Courses Phase 7B: the "Grow Your Money" learning path's third
// course, "Deposits and Pooled Funds" (course id
// 'deposits_and_pooled_funds'). Builds on the completed Investing Readiness
// pilot (lessons_grow.dart) and Phase 7A's "Stocks and Bonds Without the
// Hype" (lessons_stocks_bonds.dart) without modifying either or the core 22
// lessons in lessons.dart: separate content file, separate lesson ids, same
// architecture already shipped by Phases 2 to 7A (governance metadata,
// official-source and risk-warning blocks, Phase 5 interaction blocks).
//
// This course's own job, stated once here because every lesson below is
// built to serve it: help a reader tell a protected bank deposit apart from
// an investment that can gain or lose value, even when the same bank counter
// sells both. Same house rules as lessons_stocks_bonds.dart: plain English,
// Philippine peso examples, no em or en dashes, no named bank, UITF, mutual
// fund, ETF, or provider anywhere in this file, no guaranteed-outcome or
// risk-free language, no personalized recommendation. Every fictional
// product name is invented for this course and never reused as a real one.
//
// The one figure in this course that is not evergreen, the PDIC maximum
// deposit insurance coverage, is deliberately NOT typed into this file as a
// bare string. It lives in money/deposit_insurance_fact.dart as a small,
// dated, independently testable fact, per the task's own instruction not to
// encode it as a permanent business rule; Lesson 2 below only reads it.
//
// Sources: the Philippine Deposit Insurance Corporation's own maximum
// deposit insurance coverage page and its deposit-insurance calculator, the
// Bangko Sentral ng Pilipinas' regulations index and its BSP Verifier tool,
// the Securities and Exchange Commission Philippines' Investment 101 and its
// capital-market participants directory, and the Philippine Stock Exchange's
// PSE Academy. PDIC, BSP, and SEC pages block automated fetches, the same
// limitation lessons_stocks_bonds.dart's own header notes; the current
// PDIC maximum deposit insurance coverage figure used here (one million
// pesos, effective 2025-03-15, up from the prior five hundred thousand peso
// limit) was cross-checked across multiple independent secondary sources
// citing PDIC's own published figure and was reviewed by the
// investment-literacy-reviewer agent before this course shipped (see
// governance.reviewerId below).

import '../money/deposit_insurance_fact.dart';
import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

// Plain string constants, not fields on a shared object: see
// lessons_stocks_bonds.dart's own comment on why a const OfficialSourceBlock
// call needs these as top-level identifiers rather than reading them off a
// const LessonSourceInfo instance's field.
const _pdicMdicAgency = 'Philippine Deposit Insurance Corporation (PDIC)';
const _pdicMdicTitle = 'Maximum Deposit Insurance Coverage';
const _pdicMdicUrl = 'https://www.pdic.gov.ph/MDIC';
const _pdicMdicVerified = '2026-08';

const _pdicMdic = LessonSourceInfo(
  agency: _pdicMdicAgency,
  title: _pdicMdicTitle,
  canonicalUrl: _pdicMdicUrl,
  effectiveDate: '2025-03-15',
  lastVerifiedDate: _pdicMdicVerified,
);

const _pdicCalculatorAgency = 'Philippine Deposit Insurance Corporation (PDIC)';
const _pdicCalculatorTitle = 'Deposit Insurance Calculator';
const _pdicCalculatorUrl = 'https://www.pdic.gov.ph/di_ecalculator';
const _pdicCalculatorVerified = '2026-08';

const _pdicCalculator = LessonSourceInfo(
  agency: _pdicCalculatorAgency,
  title: _pdicCalculatorTitle,
  canonicalUrl: _pdicCalculatorUrl,
  lastVerifiedDate: _pdicCalculatorVerified,
);

// The investment-literacy-reviewer agent flagged the task's own suggested
// URL (bsp.gov.ph/Pages/Regulations/Regulations.aspx) as unindexed and
// unconfirmable (bsp.gov.ph 403s on automated fetch, same as every other
// regulator cited in this course), and a WebSearch specifically for BSP's
// own regulations index turned up this URL instead, matching real,
// currently indexed BSP content (a searchable repository of circulars,
// circular letters, and memoranda). Used here instead of the task's
// suggested path for that reason.
const _bspRegulationsAgency = 'Bangko Sentral ng Pilipinas (BSP)';
const _bspRegulationsTitle = 'Regulations List';
const _bspRegulationsUrl =
    'https://www.bsp.gov.ph/SitePages/Regulations/RegulationsList.aspx';
const _bspRegulationsVerified = '2026-08';

const _bspRegulations = LessonSourceInfo(
  agency: _bspRegulationsAgency,
  title: _bspRegulationsTitle,
  canonicalUrl: _bspRegulationsUrl,
  lastVerifiedDate: _bspRegulationsVerified,
);

const _bspVerifierAgency = 'Bangko Sentral ng Pilipinas (BSP)';
const _bspVerifierTitle = 'BSP Verifier';
const _bspVerifierUrl =
    'https://www.bsp.gov.ph/SitePages/FinancialStability/BSPVerifier.aspx';
const _bspVerifierVerified = '2026-08';

const _bspVerifier = LessonSourceInfo(
  agency: _bspVerifierAgency,
  title: _bspVerifierTitle,
  canonicalUrl: _bspVerifierUrl,
  lastVerifiedDate: _bspVerifierVerified,
);

const _secAgency = 'Securities and Exchange Commission Philippines';
const _secTitle = 'Investment 101';
const _secUrl =
    'https://appointment.sec.gov.ph/investors-education-and-information/investment-101/';
const _secVerified = '2026-08';

const _secInvestment101 = LessonSourceInfo(
  agency: _secAgency,
  title: _secTitle,
  canonicalUrl: _secUrl,
  lastVerifiedDate: _secVerified,
);

const _secDirectoryAgency = 'Securities and Exchange Commission Philippines';
const _secDirectoryTitle = 'Capital Market Participants';
const _secDirectoryUrl = 'https://eramp.sec.gov.ph/capital-market-participants';
const _secDirectoryVerified = '2026-08';

const _secDirectory = LessonSourceInfo(
  agency: _secDirectoryAgency,
  title: _secDirectoryTitle,
  canonicalUrl: _secDirectoryUrl,
  lastVerifiedDate: _secDirectoryVerified,
);

const _pseAcademyAgency = 'Philippine Stock Exchange (PSE Academy)';
const _pseAcademyTitle = 'PSE Academy, Market Education for Investors';
const _pseAcademyUrl = 'https://www.pseacademy.com.ph/';
const _pseAcademyVerified = '2026-08';

const _pseAcademy = LessonSourceInfo(
  agency: _pseAcademyAgency,
  title: _pseAcademyTitle,
  canonicalUrl: _pseAcademyUrl,
  lastVerifiedDate: _pseAcademyVerified,
);

/// The versioned PDIC limit fact Lesson 2 renders. Kept as data, not a
/// string typed into prose: see money/deposit_insurance_fact.dart's own
/// header for why. test/deposit_insurance_fact_test.dart proves the
/// validator this type carries rejects a missing or stale version of this
/// same fact; this is the real, current one.
const currentDepositInsuranceLimit = DepositInsuranceFact(
  maxCoveragePhp: 1000000,
  effectiveDate: '2025-03-15',
  lastVerifiedDate: _pdicMdicVerified,
  reviewDueDate: '2027-02',
  sourceUrl: _pdicMdicUrl,
  calculatorUrl: _pdicCalculatorUrl,
);

const _governance = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'ILR',
);

/// Lesson 2 carries the one figure in this course that can move on its own
/// schedule (PDIC's Board can revise it without a new law), so its own
/// review cadence is shorter than the rest of the course's annual default.
const _governanceHighVolatility = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-02',
  reviewerId: 'ILR',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel:
      'PDIC, the Bangko Sentral ng Pilipinas, and the Securities and '
      'Exchange Commission',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form, same convention as
/// lessons_stocks_bonds.dart's own ids. Never reused for a different lesson
/// once a learner has real progress recorded against one (see
/// money/expansion_progress.dart).
const dpDepositOrInvestment = 'dp-deposit-or-investment';
const dpTimeDepositsAndPdic = 'dp-time-deposits-and-pdic';
const dpHowPooledFundsWork = 'dp-how-pooled-funds-work';
const dpUitfMutualFundEtf = 'dp-uitf-mutual-fund-etf';
const dpReadAFactSheet = 'dp-read-a-fact-sheet';
const dpMatchProductToGoal = 'dp-match-product-to-goal';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// `lessons` list, and never merged into growYourMoneyLessons or
/// stocksAndBondsLessons: see
/// test/lessons_deposits_pooled_funds_content_test.dart's own isolation
/// checks.
const List<MoneyLesson> depositsAndPooledFundsLessons = [
  _depositOrInvestment,
  _timeDepositsAndPdic,
  _howPooledFundsWork,
  _uitfMutualFundEtf,
  _readAFactSheet,
  _matchProductToGoal,
];

// ---------------------------------------------------------------------------
// Lesson 1: Deposit or Investment?
// ---------------------------------------------------------------------------

const _depositOrInvestment = MoneyLesson(
  id: dpDepositOrInvestment,
  trackId: 'deposits_and_pooled_funds',
  title: 'Deposit or Investment?',
  icon: 'inspect',
  minutes: 5,
  summary:
      'A bank deposit and an investment product are different things, even '
      'when the same bank sells both.',
  objective:
      'Sort common bank-counter products into deposits and investments '
      'before looking at what any one of them promises.',
  sections: [],
  governance: _governance,
  sources: [_pdicMdic, _secInvestment101, _bspRegulations],
  topics: [
    ContentTopic.bankDeposits,
    ContentTopic.fundsAndEtfs,
    ContentTopic.stocks,
    ContentTopic.bonds,
  ],
  authoredBlocks: [
    ProseBlock(
      heading: 'Same counter, different thing',
      paragraphs: [
        'A teller slides a brochure across the counter while you are '
            'only there to open a savings account. A savings account or a '
            'time deposit is a bank deposit, money the bank owes you, '
            'protected up to a set limit by deposit insurance. A government '
            'or corporate bond, a UITF, a mutual fund, an ETF, or a share '
            'of stock is an investment product. Its value can rise or fall, '
            'and deposit insurance does not automatically reach it.',
        'The confusing part is where these are sold. Many Philippine banks '
            'sell both kinds of product at the very same counter, '
            'sometimes through the very same staff member. That does not '
            'make an investment product into a deposit, and it does not '
            'give it the deposit\'s own protection.',
        'What decides which one something is, is its own structure and '
            'legal nature, not which company\'s logo is printed on the '
            'brochure or the branch you signed the paperwork in.',
      ],
    ),
    NuggetsBlock([
      'A deposit is a debt the bank owes you, covered by deposit insurance '
          'up to a set limit.',
      'An investment product, however it is sold, can lose value, and '
          'that risk sits with you, not with a deposit-insurance scheme.',
      'The bank on the receipt tells you who sold it. It never tells you '
          'what kind of thing was actually sold.',
    ]),
    RiskWarningBlock(
      title: 'A familiar bank does not change what a product is',
      text:
          'An investment product bought through a bank can still lose '
          'value, the same as if it were bought anywhere else. Deposit '
          'insurance protects deposits, not every product a bank happens '
          'to sell.',
    ),
    OfficialSourceBlock(
      agency: _pdicMdicAgency,
      sourceTitle: _pdicMdicTitle,
      canonicalUrl: _pdicMdicUrl,
      lastVerifiedDate: _pdicMdicVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _bspRegulationsAgency,
      sourceTitle: _bspRegulationsTitle,
      canonicalUrl: _bspRegulationsUrl,
      lastVerifiedDate: _bspRegulationsVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'deposit-or-investment-sort',
      categorizePrompt:
          'Sort each fictional product into Bank deposit or Investment '
          'product.',
      buckets: [
        CategorizeBucket(id: 'deposit', label: 'Bank deposit'),
        CategorizeBucket(id: 'investment', label: 'Investment product'),
      ],
      items: [
        CategorizeItemDef(
          id: 'savings-account',
          label: 'An ordinary savings account',
          explanation:
              'A savings account is a deposit: a debt the bank owes you, '
              'covered by deposit insurance up to its current limit.',
        ),
        CategorizeItemDef(
          id: 'time-deposit',
          label: 'A time deposit',
          explanation:
              'A time deposit is still a deposit, just locked in for a '
              'term. It is covered the same way an ordinary deposit is.',
        ),
        CategorizeItemDef(
          id: 'gov-bond',
          label: 'A government bond',
          explanation:
              'A government bond is a loan to the government, an '
              'investment product, not a deposit.',
        ),
        CategorizeItemDef(
          id: 'corp-bond',
          label: 'A corporate bond',
          explanation:
              'A corporate bond is a loan to that company, an investment '
              'product, not a deposit.',
        ),
        CategorizeItemDef(
          id: 'uitf',
          label: 'A UITF offered by a bank\'s trust department',
          explanation:
              'A UITF is a pooled investment vehicle. Being offered by a '
              'bank does not make it a deposit.',
        ),
        CategorizeItemDef(
          id: 'mutual-fund',
          label: 'A mutual fund',
          explanation:
              'A mutual fund is an investment company you buy shares in, '
              'an investment product, not a deposit.',
        ),
        CategorizeItemDef(
          id: 'etf',
          label: 'An ETF traded on the stock exchange',
          explanation:
              'An ETF trades like a stock and its value moves with what '
              'it holds, an investment product, not a deposit.',
        ),
        CategorizeItemDef(
          id: 'direct-stock',
          label: 'Direct ownership of a company\'s shares',
          explanation:
              'Owning shares directly makes you a part owner of a '
              'company, an investment product, not a deposit.',
        ),
      ],
      correctBucketByItemId: {
        'savings-account': 'deposit',
        'time-deposit': 'deposit',
        'gov-bond': 'investment',
        'corp-bond': 'investment',
        'uitf': 'investment',
        'mutual-fund': 'investment',
        'etf': 'investment',
        'direct-stock': 'investment',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'bank-offers-it-myth',
      statement: 'If a bank offers it, PDIC automatically covers it.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'PDIC insures deposits, not every product a bank happens to '
          'distribute. A UITF, a mutual fund, a bond, or shares sold '
          'through a bank counter are investment products, and deposit '
          'insurance does not automatically extend to them just because a '
          'bank was involved in the sale.',
      officialSource: _pdicMdic,
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'trust-officer-scenario',
      scenarioTitle: 'A trust officer at a familiar bank',
      situation:
          'A fictional trust officer, at the same bank a person already '
          'keeps a savings account with, offers a UITF and says "it is '
          'from the same bank you already trust." What is the clearest '
          'way to think about that offer, based on this lesson?',
      options: [
        ScenarioChoiceOption(
          id: 'still-investigate',
          label:
              'Recognize that the UITF is a different kind of product from '
              'the savings account, and look into its own structure and '
              'risks before deciding, regardless of which bank offers it',
          explanation:
              'The bank being familiar says nothing about whether the '
              'UITF itself is a good fit. Its own structure, fees, and '
              'risk still need to be understood on their own terms.',
        ),
        ScenarioChoiceOption(
          id: 'trust-the-bank',
          label:
              'Trust it the same way as the savings account, since it '
              'comes from the same bank',
          explanation:
              'A UITF and a savings account are different products with '
              'different protections. The bank being the same for both '
              'does not make their risks the same.',
        ),
      ],
      preferredOptionId: 'still-investigate',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional bank sells both a time deposit and a UITF at the same '
        'counter. What tells you which one is a deposit and which one is '
        'an investment product?',
    choices: [
      'Whichever the bank calls safer in its brochure',
      'The product\'s own structure and legal nature, not the bank selling '
          'it',
      'Whichever one has a higher advertised return',
    ],
    correctIndex: 1,
    explanation:
        'A product\'s own structure decides whether it is a deposit or an '
        'investment. The bank selling it, and how it is marketed, does not '
        'change that.',
    whyWrong:
        'A brochure\'s wording and an advertised return are marketing, not '
        'a reliable way to tell a protected deposit apart from a product '
        'that can lose value.',
  ),
  keyTakeaway:
      'A bank deposit and an investment product are different things, and '
      'only the product\'s own structure decides which one it is, never '
      'which bank\'s logo is on the paperwork.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Time Deposits and PDIC Protection
// ---------------------------------------------------------------------------

const _timeDepositsAndPdic = MoneyLesson(
  id: dpTimeDepositsAndPdic,
  trackId: 'deposits_and_pooled_funds',
  title: 'Time Deposits and PDIC Protection',
  icon: 'protected',
  minutes: 6,
  summary:
      'A time deposit locks money in for a term in exchange for interest. '
      'Deposit insurance is its own separate protection, with its own '
      'current limit and its own rules.',
  objective:
      'Explain how a time deposit differs from an ordinary savings '
      'account, and what deposit insurance does and does not cover.',
  sections: [],
  governance: _governanceHighVolatility,
  sources: [_pdicMdic, _pdicCalculator, _bspRegulations],
  topics: [ContentTopic.bankDeposits],
  authoredBlocks: [
    ProseBlock(
      heading: 'Locked in, and why',
      paragraphs: [
        'You have money you will not touch for a year, and it is '
            'sitting in a savings account doing nothing. A time deposit is '
            'a bank deposit locked in for a set term, or maturity, in '
            'exchange for a fixed interest rate. That rate is usually '
            'higher than an ordinary savings account\'s. Taking the money '
            'out before the term ends generally means an early-withdrawal '
            'consequence, a reduced rate or a fee set by the bank\'s own '
            'terms.',
        'A depositor is whoever the account legally belongs to, and how an '
            'account is owned, solely, jointly, or in trust for someone '
            'else, can affect how deposit insurance applies to it. This '
            'lesson explains the general idea; it does not work out every '
            'depositor\'s own coverage, since that depends on details only '
            'PDIC\'s own calculator and rules can resolve.',
        'Deposit insurance and investment protection are not the same '
            'thing. Deposit insurance protects an ordinary deposit up to a '
            'set peso limit if the bank itself fails. An investment '
            'product\'s protection, where it exists at all, works '
            'completely differently, and never through PDIC.',
      ],
    ),
    // The peso figure and dates below (1,000,000 pesos; effective
    // 2025-03-15; last checked August 2026) are literal text, not an
    // interpolated field read off currentDepositInsuranceLimit: Dart cannot
    // access a const object's field inside a const string, since this
    // whole lesson is authored as a compile-time const. They are the exact
    // values currentDepositInsuranceLimit carries; the "the lesson states
    // the same figure the versioned fact carries" test in
    // test/lessons_deposits_pooled_funds_content_test.dart proves the two
    // can never quietly drift apart.
    NuggetsBlock([
      'A time deposit trades flexibility for a fixed rate: the money is '
          'locked in, and taking it out early usually costs something.',
      'PDIC\'s maximum deposit insurance coverage is currently 1,000,000 '
          'pesos per depositor, per bank, effective 2025-03-15, as of '
          'PDIC\'s own page (last checked 2026-08). PDIC\'s Board can '
          'revise this limit under its own charter, so this figure is '
          'always worth checking again on PDIC\'s own page rather than '
          'assumed to stay fixed.',
      'Account ownership, solely held, joint, or in trust for someone '
          'else, can change how coverage is worked out for a specific '
          'depositor. PDIC\'s own calculator is built for exactly that '
          'kind of case.',
    ]),
    RiskWarningBlock(
      title: 'Deposit insurance has a limit, and account ownership matters',
      text:
          'A deposit above the current maximum deposit insurance coverage '
          'is not automatically protected for the excess. How an account '
          'is owned can also change what is covered. This lesson explains '
          'the general idea; it does not settle any specific depositor\'s '
          'own coverage, which depends on PDIC\'s own rules.',
    ),
    OfficialSourceBlock(
      agency: _pdicMdicAgency,
      sourceTitle: _pdicMdicTitle,
      canonicalUrl: _pdicMdicUrl,
      effectiveDate: '2025-03-15',
      lastVerifiedDate: _pdicMdicVerified,
    ),
    OfficialSourceBlock(
      agency: _pdicCalculatorAgency,
      sourceTitle: _pdicCalculatorTitle,
      canonicalUrl: _pdicCalculatorUrl,
      lastVerifiedDate: _pdicCalculatorVerified,
    ),
    OfficialSourceBlock(
      agency: _bspRegulationsAgency,
      sourceTitle: _bspRegulationsTitle,
      canonicalUrl: _bspRegulationsUrl,
      lastVerifiedDate: _bspRegulationsVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ScenarioChoiceBlock(
      blockId: 'account-classification-scenario',
      scenarioTitle: 'A fictional depositor\'s account',
      situation:
          'A depositor holds a time deposit at one bank, in their own '
          'name only, with a balance above PDIC\'s '
          'current maximum deposit insurance coverage. What is the most '
          'accurate way to describe their situation, based on this '
          'lesson?',
      options: [
        ScenarioChoiceOption(
          id: 'excess-not-automatic',
          label:
              'The amount above the current maximum deposit insurance '
              'coverage is not automatically covered, and PDIC\'s own '
              'calculator and rules would need to be checked for the '
              'specifics',
          explanation:
              'Deposit insurance covers up to the current limit per '
              'depositor, per bank. An amount above that is not '
              'automatically protected, and the exact outcome depends on '
              'PDIC\'s own rules, not a guess made here.',
        ),
        ScenarioChoiceOption(
          id: 'fully-covered-regardless',
          label:
              'The entire balance is covered regardless of size, since it '
              'is a time deposit at a real bank',
          explanation:
              'Coverage is not unlimited. PDIC insures deposits only up to '
              'its current maximum, per depositor, per bank, and a balance '
              'above that limit is not automatically covered in full.',
        ),
      ],
      preferredOptionId: 'excess-not-automatic',
      requiredForCompletion: true,
    ),
    ComparisonBlock(
      blockId: 'basic-coverage-illustration',
      title: 'A basic coverage illustration (fictional, simplified)',
      criteria: [
        ComparisonCriterion(id: 'balance', label: 'Balance'),
        ComparisonCriterion(
          id: 'likely-treatment',
          label: 'Likely treatment (simplified)',
        ),
      ],
      items: [
        ComparisonItem(
          id: 'below-limit',
          name: 'Depositor A, sole account',
          valuesByCriterionId: {
            'balance': '600,000 pesos',
            'likely-treatment':
                'At or below the current maximum deposit insurance '
                'coverage, so the balance would generally fall within it.',
          },
        ),
        ComparisonItem(
          id: 'above-limit',
          name: 'Depositor B, sole account',
          valuesByCriterionId: {
            'balance': '1,500,000 pesos',
            'likely-treatment':
                'Above the current maximum deposit insurance coverage, so '
                'the amount above the limit would not be automatically '
                'covered.',
          },
          caution:
              'A joint account, a trust account, or more than one deposit '
              'at the same bank can change this. This is a simplified '
              'illustration, not a coverage determination; use PDIC\'s own '
              'calculator for an actual case.',
        ),
      ],
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'maturity-checklist',
      checklistPrompt:
          'A checklist to run through before locking money into a time '
          'deposit. Offline, and yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'term-length',
          label: 'The term, or maturity date, is clear',
        ),
        ChecklistItemDef(
          id: 'early-withdrawal',
          label:
              'The early-withdrawal terms, and what they cost, are '
              'understood',
        ),
        ChecklistItemDef(
          id: 'rate-confirmed',
          label: 'The interest rate, and whether it can change, is confirmed',
        ),
        ChecklistItemDef(
          id: 'bank-supervised',
          label:
              'The bank is a BSP-supervised institution, checked against an '
              'official source',
        ),
        ChecklistItemDef(
          id: 'coverage-checked',
          label:
              'If the balance is large, PDIC\'s own calculator has been '
              'checked for how coverage applies',
          required: false,
        ),
      ],
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional depositor asks whether their money in a time deposit '
        'is "officially insured." What does this lesson say is the most '
        'accurate answer?',
    choices: [
      'Yes, without exception, since it is a bank deposit',
      'It may be covered up to PDIC\'s current maximum deposit insurance '
          'coverage, depending on account ownership and PDIC\'s own rules',
      'No, deposit insurance never applies to a time deposit',
    ],
    correctIndex: 1,
    explanation:
        'Deposit insurance can apply to a time deposit, but only up to the '
        'current limit, and the exact outcome depends on how the account '
        'is owned. This lesson explains the idea; it never declares a '
        'specific depositor\'s coverage settled.',
    whyWrong:
        'Coverage is not automatic and unlimited, and a time deposit is '
        'exactly the kind of ordinary deposit deposit insurance is built '
        'for, so neither extreme answer is accurate.',
  ),
  keyTakeaway:
      'A time deposit trades flexibility for a fixed rate, and deposit '
      'insurance protects it only up to PDIC\'s current, versioned limit, '
      'never as a permanent, unchanging number.',
);

// ---------------------------------------------------------------------------
// Lesson 3: How Pooled Funds Work
// ---------------------------------------------------------------------------

const _howPooledFundsWork = MoneyLesson(
  id: dpHowPooledFundsWork,
  trackId: 'deposits_and_pooled_funds',
  title: 'How Pooled Funds Work',
  icon: 'group',
  minutes: 6,
  summary:
      'Many investors\' money is pooled into one portfolio. Its value '
      'moves with what it holds, and professional management never '
      'removes that risk.',
  objective:
      'Explain how a pooled fund turns many investors\' money into shared '
      'units, and name the basic terms on its own fact sheet.',
  sections: [],
  governance: _governance,
  sources: [_secInvestment101, _bspRegulations],
  topics: [ContentTopic.fundsAndEtfs],
  authoredBlocks: [
    ProseBlock(
      heading: 'Your slice, not your account',
      paragraphs: [
        'You have heard the word fund thrown around and pictured '
            'someone smart in an office handling your money. A pooled fund '
            'gathers money from many investors into one shared portfolio. '
            'That pooled money goes into a mix of underlying assets, which '
            'might include stocks, bonds, or short-term instruments, '
            'depending on the fund. You hold units or shares representing '
            'your slice of that shared portfolio, not a separate account of '
            'your own.',
        'A fund\'s value changes as the value of what it holds changes. '
            'Professional management, a fund manager actively choosing '
            'what to hold, can inform those choices, but it never removes '
            'the underlying risk: a professionally managed fund can still '
            'lose value, and past performance never guarantees future '
            'results.',
        'A fund\'s name is a marketing label, not a full description of '
            'what it actually holds. Two funds with similar-sounding names '
            'can hold very different things, which is exactly why a fact '
            'sheet\'s own details, not its name, are what matter.',
      ],
    ),
    NuggetsBlock([
      'NAV, or net asset value, is the value of everything a fund holds '
          'minus what it owes, including accrued fees. NAVPU is that value '
          'divided by the number of units outstanding, the per-unit price '
          'you actually see.',
      'A fund\'s investment objective, portfolio holdings, benchmark, and '
          'risk classification describe what it actually does, and are '
          'worth reading before its name is taken at face value.',
      'Redemption rules, how and when units can be sold back, vary by '
          'fund and are part of what decides how quickly money can '
          'actually be accessed.',
    ]),
    RiskWarningBlock(
      title: 'Management reduces guesswork, not risk',
      text:
          'A pooled fund can still lose value, and a fund\'s value can go '
          'down as well as up. Past performance does not guarantee future '
          'results, and no fund manager can remove that.',
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _bspRegulationsAgency,
      sourceTitle: _bspRegulationsTitle,
      canonicalUrl: _bspRegulationsUrl,
      lastVerifiedDate: _bspRegulationsVerified,
    ),
    _boundary,
    DiagramBlock(
      steps: [
        'Many investors each contribute money',
        'Their money is pooled into one shared portfolio',
        'The pooled portfolio buys underlying assets, which vary by fund',
        'NAVPU reflects the value of those underlying assets, divided '
            'across all units outstanding',
        'Each investor holds units representing their own share of the '
            'pooled portfolio',
      ],
      caption: 'A simplified pooled-fund diagram (fictional labels)',
    ),
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'pooled-fund-diagram-labels',
      categorizePrompt:
          'Match each description to the stage of the pooled-fund diagram '
          'above it belongs to.',
      buckets: [
        CategorizeBucket(id: 'contribution', label: 'Investor contribution'),
        CategorizeBucket(id: 'pooling', label: 'Pooled portfolio'),
        CategorizeBucket(id: 'underlying-assets', label: 'Underlying assets'),
        CategorizeBucket(id: 'navpu', label: 'NAVPU'),
        CategorizeBucket(id: 'units', label: 'Units'),
      ],
      items: [
        CategorizeItemDef(
          id: 'money-in',
          label: 'Money each investor puts in individually',
          explanation:
              'This is the investor contribution, the starting point '
              'before anything is pooled.',
        ),
        CategorizeItemDef(
          id: 'shared-pot',
          label: 'Where all contributions come together as one',
          explanation:
              'This is the pooled portfolio, the single shared pot every '
              'contribution joins.',
        ),
        CategorizeItemDef(
          id: 'what-its-bought',
          label: 'What the fund actually buys with that pooled money',
          explanation:
              'These are the underlying assets, the actual holdings that '
              'drive the fund\'s value.',
        ),
        CategorizeItemDef(
          id: 'per-unit-price',
          label:
              'The per-unit price, tracking the value of the underlying '
              'assets',
          explanation:
              'This is NAVPU, net asset value per unit, the number that '
              'moves as the underlying assets\' value moves.',
        ),
        CategorizeItemDef(
          id: 'what-you-hold',
          label: 'What each investor actually owns a number of',
          explanation:
              'These are units, an investor\'s own slice of the pooled '
              'portfolio.',
        ),
      ],
      correctBucketByItemId: {
        'money-in': 'contribution',
        'shared-pot': 'pooling',
        'what-its-bought': 'underlying-assets',
        'per-unit-price': 'navpu',
        'what-you-hold': 'units',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'fund-name-myth',
      statement:
          'A fund\'s name always fully describes what it actually invests '
          'in.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A name is a marketing label. What a fund actually holds is '
          'described in its investment objective, portfolio holdings, and '
          'risk classification, not in its name alone.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'professional-management-scenario',
      scenarioTitle: 'A professionally managed fictional fund loses value',
      situation:
          'A pooled fund, actively managed by a professional fund '
          'manager, loses value over a year. An investor says "that '
          'should not happen, it is professionally managed." What does '
          'this lesson say about that?',
      options: [
        ScenarioChoiceOption(
          id: 'management-does-not-remove-risk',
          label:
              'Professional management can inform decisions, but it never '
              'removes the underlying risk that a fund can lose value',
          explanation:
              'This is exactly this lesson\'s own point: management '
              'reduces guesswork, not risk. A professionally managed fund '
              'can still lose value.',
        ),
        ScenarioChoiceOption(
          id: 'management-guarantees-gains',
          label: 'Professional management should have prevented any loss',
          explanation:
              'No level of management removes a pooled fund\'s underlying '
              'risk. A loss in a professionally managed fund is not, by '
              'itself, evidence that something went wrong.',
        ),
      ],
      preferredOptionId: 'management-does-not-remove-risk',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question: 'What does NAVPU represent in a fictional pooled fund?',
    choices: [
      'A guaranteed minimum price the fund will always be worth',
      'The value of the fund\'s underlying assets divided by its units '
          'outstanding',
      'The total amount of money originally contributed by all investors',
    ],
    correctIndex: 1,
    explanation:
        'NAVPU is net asset value per unit: the pooled portfolio\'s total '
        'value divided by the number of units outstanding, and it moves as '
        'that underlying value moves.',
    whyWrong:
        'NAVPU is not fixed or guaranteed, and it is not simply the '
        'original amount contributed; it reflects the current value of '
        'what the fund actually holds.',
  ),
  keyTakeaway:
      'A pooled fund turns many investors\' money into shared units whose '
      'value tracks the underlying assets, and professional management '
      'never removes that risk.',
);

// ---------------------------------------------------------------------------
// Lesson 4: UITF, Mutual Fund or ETF?
// ---------------------------------------------------------------------------

const _uitfMutualFundEtf = MoneyLesson(
  id: dpUitfMutualFundEtf,
  trackId: 'deposits_and_pooled_funds',
  title: 'UITF, Mutual Fund or ETF?',
  icon: 'split',
  minutes: 6,
  summary:
      'Three pooled-fund structures, compared plainly: how each is '
      'supervised, priced, traded, and redeemed, with no product called '
      'the best.',
  objective:
      'Compare a UITF, a mutual fund, and an ETF across the same criteria '
      'without ranking or recommending any one of them.',
  sections: [],
  governance: _governance,
  sources: [_bspRegulations, _secDirectory, _pseAcademy],
  topics: [ContentTopic.fundsAndEtfs],
  authoredBlocks: [
    ProseBlock(
      heading: 'Three names, three structures',
      paragraphs: [
        'Three names get thrown at you, and they all sound like the '
            'same product with different letters. A UITF, a mutual fund, '
            'and an ETF are all pooled funds. They are built differently, '
            'supervised by different regulators, and bought and sold in '
            'different ways. None of them is a deposit merely because a '
            'bank or trust entity distributes it.',
        'A UITF is generally offered through a bank\'s trust department or '
            'a trust corporation and is supervised by the Bangko Sentral '
            'ng Pilipinas. A mutual fund is an investment company, '
            'registered with and supervised by the Securities and Exchange '
            'Commission. An ETF trades on the Philippine Stock Exchange, '
            'the same way a stock does, and is also under SEC supervision.',
        'None of the three is automatically the right fit for every '
            'investor. Specific terms, fees, and minimums vary by fund, '
            'and this comparison covers the general structure only, not '
            'any specific product.',
      ],
    ),
    NuggetsBlock([
      'How a fund is priced and traded follows directly from its '
          'structure: a UITF and a mutual fund are bought and redeemed '
          'directly with the entity that runs them, while an ETF trades '
          'through a broker on the stock exchange.',
      'Fees and how they are charged differ by structure too, and reading '
          'a specific fund\'s own disclosure is the only way to know its '
          'actual cost.',
      'The regulator supervising a fund follows from what kind of fund it '
          'is, not from which company happens to distribute it.',
    ]),
    RiskWarningBlock(
      title: 'All three can lose value',
      text:
          'A UITF, a mutual fund, and an ETF can each lose value, whatever '
          'their structure. None of them is a deposit, and deposit '
          'insurance does not extend to any of them.',
    ),
    OfficialSourceBlock(
      agency: _bspRegulationsAgency,
      sourceTitle: _bspRegulationsTitle,
      canonicalUrl: _bspRegulationsUrl,
      lastVerifiedDate: _bspRegulationsVerified,
    ),
    OfficialSourceBlock(
      agency: _secDirectoryAgency,
      sourceTitle: _secDirectoryTitle,
      canonicalUrl: _secDirectoryUrl,
      lastVerifiedDate: _secDirectoryVerified,
    ),
    OfficialSourceBlock(
      agency: _pseAcademyAgency,
      sourceTitle: _pseAcademyTitle,
      canonicalUrl: _pseAcademyUrl,
      lastVerifiedDate: _pseAcademyVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ComparisonBlock(
      blockId: 'uitf-mutual-fund-etf-comparison',
      title: 'A neutral comparison (general structure, not any one fund)',
      criteria: [
        ComparisonCriterion(id: 'structure', label: 'General structure'),
        ComparisonCriterion(id: 'participate', label: 'How you participate'),
        ComparisonCriterion(id: 'pricing', label: 'Pricing or valuation'),
        ComparisonCriterion(id: 'traded', label: 'Where it is traded'),
        ComparisonCriterion(id: 'liquidity', label: 'Liquidity and redemption'),
        ComparisonCriterion(id: 'fees', label: 'Fees and expenses'),
        ComparisonCriterion(id: 'authority', label: 'Supervising authority'),
        ComparisonCriterion(id: 'risks', label: 'Main risks'),
      ],
      items: [
        ComparisonItem(
          id: 'uitf',
          name: 'UITF (general structure)',
          valuesByCriterionId: {
            'structure':
                'A pooled trust fund offered by a bank\'s trust department '
                'or a trust corporation.',
            'participate': 'Units are bought directly from the trust entity.',
            'pricing': 'Priced by NAVPU, published regularly.',
            'traded':
                'Not traded on an exchange; bought and redeemed directly '
                'with the trust entity.',
            'liquidity':
                'Redemption terms vary by fund; some allow frequent '
                'redemption, others hold a minimum holding period.',
            'fees':
                'A trust or management fee is typically built into the '
                'NAVPU rather than charged as a separate line item.',
            'authority':
                'Supervised by the Bangko Sentral ng Pilipinas, since it '
                'is a bank trust product.',
            'risks':
                'Value moves with the underlying portfolio; a UITF is not '
                'a deposit and is not covered by deposit insurance.',
          },
          caution: 'Being offered by a bank does not make a UITF a deposit.',
        ),
        ComparisonItem(
          id: 'mutual-fund',
          name: 'Mutual fund (general structure)',
          valuesByCriterionId: {
            'structure':
                'An investment company that pools investor money and is '
                'itself a registered company.',
            'participate':
                'Shares are bought through the fund or an authorized '
                'distributor.',
            'pricing':
                'Priced by net asset value per share, published '
                'regularly.',
            'traded':
                'Not traded on an exchange; bought and redeemed directly '
                'with the fund company or its distributor.',
            'liquidity':
                'Redeemable on request, subject to the fund\'s own '
                'redemption rules and settlement timing.',
            'fees':
                'May charge a sales load (a one-time charge when you buy '
                'in), a management fee, and other expenses, disclosed in '
                'its prospectus.',
            'authority':
                'Registered with and supervised by the Securities and '
                'Exchange Commission, since a mutual fund is an investment '
                'company.',
            'risks':
                'Value moves with the underlying portfolio and can fall '
                'below the amount originally invested.',
          },
          caution:
              'A mutual fund is a company you buy shares in, not a '
              'deposit account.',
        ),
        ComparisonItem(
          id: 'etf',
          name: 'ETF (general structure)',
          valuesByCriterionId: {
            'structure':
                'A fund whose shares trade on a stock exchange, generally '
                'built to track an index or a basket of assets.',
            'participate':
                'Shares are bought and sold through a stockbroker, the '
                'same way a stock is traded.',
            'pricing':
                'Its market price can move throughout the trading day, '
                'alongside its own net asset value.',
            'traded':
                'Traded on the Philippine Stock Exchange, through an '
                'authorized broker.',
            'liquidity':
                'As liquid as trading a stock: buying or selling generally '
                'happens whenever the market is open, subject to '
                'available buyers and sellers.',
            'fees':
                'Brokerage fees apply when buying or selling, in addition '
                'to the fund\'s own built-in management fee.',
            'authority':
                'Supervised by the Securities and Exchange Commission, and '
                'it trades through the Philippine Stock Exchange.',
            'risks':
                'Its market price can move away from its underlying net '
                'asset value, and, like other pooled funds, its value can '
                'fall.',
          },
          caution:
              'An ETF trades like a stock; its price can also differ from '
              'the value of what it actually holds.',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'uitf-deposit-myth',
      statement:
          'A UITF counts as a deposit product since a bank\'s trust '
          'department offers it.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A UITF is a pooled investment vehicle, supervised as a trust '
          'product, not a deposit. Its value can rise or fall, and it is '
          'not covered by deposit insurance.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'etf-trades-like-stock-scenario',
      scenarioTitle: 'An ETF\'s price during the trading day',
      situation:
          'A fictional investor is surprised that an ETF\'s price moved '
          'several times over one trading day. What does this lesson say '
          'about that?',
      options: [
        ScenarioChoiceOption(
          id: 'trades-like-a-stock',
          label:
              'That is expected: an ETF trades on the exchange like a '
              'stock, so its market price can move throughout the day',
          explanation:
              'This matches how an ETF is structured. Unlike a UITF or a '
              'mutual fund, which are priced once per valuation, an ETF\'s '
              'market price can move continuously while the exchange is '
              'open.',
        ),
        ScenarioChoiceOption(
          id: 'should-be-fixed',
          label:
              'That should not happen; a fund\'s price should stay fixed '
              'during the day',
          explanation:
              'An ETF is specifically built to trade on an exchange, so '
              'its price moving during the day is normal for this '
              'structure, unlike a UITF or a mutual fund priced once per '
              'valuation.',
        ),
      ],
      preferredOptionId: 'trades-like-a-stock',
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Which of these is generally true about an ETF, based on this '
        'lesson?',
    choices: [
      'It is bought and redeemed only directly with a trust entity, like '
          'a UITF',
      'It trades through a broker on the stock exchange, and its market '
          'price can move during the trading day',
      'It is a type of bank deposit, since it is often sold near bank '
          'products',
    ],
    correctIndex: 1,
    explanation:
        'An ETF trades on the exchange like a stock, bought and sold '
        'through a broker, with a market price that can move throughout '
        'the trading day.',
    whyWrong:
        'Being bought only directly from a trust entity describes a UITF, '
        'not an ETF, and an ETF is an investment product, never a deposit.',
  ),
  keyTakeaway:
      'A UITF, a mutual fund, and an ETF are all pooled funds built '
      'differently, supervised differently, and traded differently, and '
      'none of them is automatically the right fit for every investor.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Read a Fund Fact Sheet
// ---------------------------------------------------------------------------

const _readAFactSheet = MoneyLesson(
  id: dpReadAFactSheet,
  trackId: 'deposits_and_pooled_funds',
  title: 'Read a Fund Fact Sheet',
  icon: 'receipt',
  minutes: 7,
  summary:
      'A fictional fact sheet, read line by line: what it tells you, what '
      'it does not, and what fees quietly take off the top.',
  objective:
      'Read a fund fact sheet well enough to name what it discloses and '
      'what still needs investigating.',
  sections: [],
  governance: _governance,
  sources: [_secInvestment101, _bspRegulations],
  topics: [ContentTopic.fundsAndEtfs],
  authoredBlocks: [
    ProseBlock(
      heading: 'What the name hides',
      paragraphs: [
        'A fund\'s name told you it was balanced, and the person '
            'selling it told you the rest. A fund fact sheet is the '
            'clearest place to check what a pooled fund actually does. It '
            'beats relying on the name, or on how someone described it in a '
            'conversation. The fictional fact sheet below invents every '
            'figure for this lesson only, and is not modeled on any real '
            'fund.',
        'Reading a fact sheet is a skill: knowing where to look for the '
            'objective, the holdings, the risk classification, and the '
            'fees, and noticing what a fact sheet does not actually '
            'answer, is worth more than any single number on the page.',
      ],
    ),
    NuggetsBlock([
      'Fund name: Example Balanced Growth Fund (fictional), invented for '
          'this lesson only.',
      'Investment objective: to grow capital over the medium term by '
          'holding a mix of equities and fixed income.',
      'Asset allocation: about 60 percent equities, 40 percent fixed '
          'income, rebalanced periodically.',
      'Benchmark: a blended index, used only for comparison, never a '
          'promise of matching it.',
      'Risk classification: labeled aggressive, this fund\'s own highest '
          'risk band.',
      'Historical performance (clearly historical): this fund\'s stated '
          'NAVPU rose in some past years and fell in others; past '
          'performance does not guarantee future results, and a fund\'s '
          'value can go down as well as up.',
      'Management and trust fee: 1.5 percent per year, built into NAVPU.',
      'Other charges: an early-redemption charge if units are sold within '
          '30 days of purchase.',
      'Minimum holding and redemption: a 30-day minimum holding period.',
      'Settlement timing: 3 business days between a redemption request '
          'and payout.',
      'Important warnings: this fund is not a deposit, is not insured by '
          'PDIC, and its value can fall below what was invested.',
    ]),
    RiskWarningBlock(
      title: 'Fees quietly reduce what you keep',
      text:
          'Every fee disclosed on a fact sheet reduces what an investor '
          'actually retains, whether or not the fund gains value. A high '
          'historical return, clearly marked as historical, still says '
          'nothing certain about the future, and a fund\'s value can go '
          'down as well as up.',
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _bspRegulationsAgency,
      sourceTitle: _bspRegulationsTitle,
      canonicalUrl: _bspRegulationsUrl,
      lastVerifiedDate: _bspRegulationsVerified,
    ),
    _boundary,
    ProseBlock(
      heading: 'A fee-impact illustration (fictional, basic arithmetic only)',
      paragraphs: [
        // Every figure below (100,000 starting pesos, 5 years, 1,500 /
        // 7,500 / 92,500 pesos) is literal text, matching
        // feeImpactIllustrationAssumptions (startingAmountPhp: 100000,
        // annualFeeRate: 0.015, years: 5) and money/fee_impact_illustration
        // .dart's feeImpact output for it. Written as literals, not an
        // interpolated field read or function call, because a MoneyLesson
        // is authored as a compile-time const and Dart cannot access an
        // object's field or call a user function inside a const string.
        // test/fee_impact_illustration_test.dart proves the function
        // produces these same numbers for these same assumptions, and
        // test/lessons_deposits_pooled_funds_content_test.dart proves this
        // paragraph still states them, so the two can never quietly drift
        // apart without a test failing.
        'Take a fictional starting amount of 100,000 pesos, an annual fee '
            'of 1.5 percent charged only against that original starting '
            'amount every year, for 5 years. No growth or return is '
            'assumed at all; this only shows what the fee alone takes.',
        'Fee per year: 1,500 pesos. Total fees over 5 years: 7,500 pesos. '
            'Amount retained after fees alone: 92,500 pesos.',
        'This is not a forecast of what any fund would actually return. '
            'It only shows, with basic transparent arithmetic and every '
            'assumption disclosed above, that a fee reduces what remains, '
            'independently of whatever the fund\'s investments do.',
      ],
    ),
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'fact-sheet-scavenger',
      categorizePrompt:
          'For each question, decide whether this fictional fact sheet '
          'answers it, or whether it is missing and worth investigating '
          'further.',
      buckets: [
        CategorizeBucket(id: 'answered', label: 'Answered in the fact sheet'),
        CategorizeBucket(id: 'investigate', label: 'Missing, investigate'),
      ],
      items: [
        CategorizeItemDef(
          id: 'what-it-invests-in',
          label: 'What the fund invests in',
          explanation:
              'Answered: the asset allocation states a mix of equities '
              'and fixed income.',
        ),
        CategorizeItemDef(
          id: 'main-risks',
          label: 'The fund\'s main risks',
          explanation:
              'Partly answered: the risk classification signals the '
              'overall risk level, but a one-word band is not the list of '
              'specific risks. The named risk factors, market, credit, '
              'liquidity, still need reading in full.',
        ),
        CategorizeItemDef(
          id: 'fees-that-apply',
          label: 'The fees that apply',
          explanation:
              'Answered: the management and trust fee and the '
              'early-redemption charge are both stated.',
        ),
        CategorizeItemDef(
          id: 'liquidity-limits',
          label: 'How liquid the fund is',
          explanation:
              'Answered: the minimum holding period and settlement timing '
              'both speak to this.',
        ),
        CategorizeItemDef(
          id: 'benchmark',
          label: 'The benchmark used for comparison',
          explanation: 'Answered: a blended index is named as the benchmark.',
        ),
        CategorizeItemDef(
          id: 'manager-track-record',
          label:
              'Who manages the fund day to day, and their track record on '
              'other funds',
          explanation:
              'Missing: this fact sheet says nothing about the manager\'s '
              'identity or their record elsewhere, worth asking about '
              'before deciding.',
        ),
        CategorizeItemDef(
          id: 'volatile-market-handling',
          label:
              'What happens to redemption requests during a volatile or '
              'closed market',
          explanation:
              'Missing: settlement timing is stated for an ordinary '
              'request, but not what changes during unusual market '
              'conditions, worth asking about before deciding.',
        ),
      ],
      correctBucketByItemId: {
        'what-it-invests-in': 'answered',
        'main-risks': 'answered',
        'fees-that-apply': 'answered',
        'liquidity-limits': 'answered',
        'benchmark': 'answered',
        'manager-track-record': 'investigate',
        'volatile-market-handling': 'investigate',
      },
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'fact-sheet-reflect',
      question:
          'Looking at this fact sheet, what would you still want to ask '
          'before deciding anything, beyond what is written on it?',
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'This fictional fund\'s historical NAVPU rose in some past years '
        'and fell in others. What does this lesson say that tells you '
        'about the future?',
    choices: [
      'It guarantees the fund will keep rising overall',
      'Nothing certain; past performance does not guarantee future '
          'results',
      'It means the fund is now guaranteed to be safer than before',
    ],
    correctIndex: 1,
    explanation:
        'Historical performance is exactly that, historical. It never '
        'guarantees what a fund will do next, and a fund\'s value can go '
        'down as well as up regardless of its past record.',
    whyWrong:
        'Neither a rising history nor a mixed one settles anything about '
        'the future; this lesson is explicit that past performance never '
        'guarantees future results.',
  ),
  keyTakeaway:
      'A fact sheet tells you what a fund discloses, fees reduce what you '
      'keep no matter what the fund earns, and what it does not say is '
      'exactly what is worth asking about next.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Match the Product to the Goal
// ---------------------------------------------------------------------------

const _matchProductToGoal = MoneyLesson(
  id: dpMatchProductToGoal,
  trackId: 'deposits_and_pooled_funds',
  title: 'Match the Product to the Goal',
  icon: 'target',
  minutes: 7,
  summary:
      'The right product follows the goal, the time horizon, and how much '
      'loss can really be absorbed, not a friend\'s tip or a bank\'s '
      'cross-sell.',
  objective:
      'Match a fictional situation to a sensible next step, including '
      'when the sensible step is to wait or stay in a deposit.',
  sections: [],
  governance: _governance,
  sources: [_secInvestment101, _bspVerifier],
  topics: [ContentTopic.fundsAndEtfs, ContentTopic.bankDeposits],
  authoredBlocks: [
    ProseBlock(
      heading: 'Same amount, different answer',
      paragraphs: [
        'Your officemate and you have the same amount saved, and the '
            'same answer will not fit both of you. The same peso amount can '
            'call for very different next steps, depending on the goal '
            'behind it. It comes down to how soon the money is needed and '
            'how much flexibility it must keep. Then how much of a drop, if '
            'any, could actually be handled without real harm.',
        'A pooled fund or any other investment product is never '
            'automatically the right next step. Sometimes the more useful '
            'answer is to keep the money accessible in a deposit, to '
            'review the financial foundation first, or simply not to '
            'invest that particular money yet.',
        'Pressure to decide quickly, from a friend\'s tip or a seller\'s '
            'pitch, is worth treating as a signal to slow down, not speed '
            'up, whatever the product being offered.',
      ],
    ),
    NuggetsBlock([
      'A short time horizon and a high need for accessible money generally '
          'point toward keeping the money in a deposit, not toward an '
          'investment product.',
      'A longer time horizon and a real ability to absorb a temporary '
          'drop are what make investigating a pooled fund category '
          'worth doing, never a tip or a pitch on its own.',
      'Checking whether a person or offer appears in an official record, '
          'through the BSP Verifier or a similar official source, is a '
          'reasonable step before acting on any pitch.',
    ]),
    RiskWarningBlock(
      title: 'A pressured pitch is a reason to pause, not to act',
      text:
          'A guaranteed high return or urgency to decide immediately is a '
          'warning sign, whatever the product. Verifying first protects '
          'money that a rushed decision could put at real risk.',
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _bspVerifierAgency,
      sourceTitle: _bspVerifierTitle,
      canonicalUrl: _bspVerifierUrl,
      lastVerifiedDate: _bspVerifierVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ComparisonBlock(
      blockId: 'fictional-users-comparison',
      title: 'Four fictional situations, side by side',
      criteria: [
        ComparisonCriterion(id: 'goal', label: 'Goal'),
        ComparisonCriterion(id: 'horizon', label: 'Time horizon'),
        ComparisonCriterion(id: 'liquidity', label: 'Liquidity need'),
        ComparisonCriterion(
          id: 'loss-capacity',
          label:
              'Ability to absorb '
              'loss',
        ),
      ],
      items: [
        ComparisonItem(
          id: 'user-a',
          name: 'User A',
          valuesByCriterionId: {
            'goal': 'Top up an emergency fund',
            'horizon': 'About 3 months',
            'liquidity': 'High, the money may be needed at any time',
            'loss-capacity': 'None, this money cannot be allowed to shrink',
          },
        ),
        ComparisonItem(
          id: 'user-b',
          name: 'User B',
          valuesByCriterionId: {
            'goal': 'A home down payment',
            'horizon': 'About 5 years',
            'liquidity': 'Low for now, but no emergency fund exists yet',
            'loss-capacity': 'Unclear until the foundation is reviewed',
          },
        ),
        ComparisonItem(
          id: 'user-c',
          name: 'User C',
          valuesByCriterionId: {
            'goal': 'A long-term retirement supplement',
            'horizon': 'About 15 years',
            'liquidity': 'Low, this money is not needed soon',
            'loss-capacity':
                'Some temporary drop could be absorbed without changing '
                'other plans',
          },
        ),
        ComparisonItem(
          id: 'user-d',
          name: 'User D',
          valuesByCriterionId: {
            'goal': 'Undecided, feeling pressured by a friend\'s tip',
            'horizon': 'Unclear',
            'liquidity': 'Unclear',
            'loss-capacity': 'Unclear',
          },
          caution:
              'An unclear goal under pressure is itself a reason to pause '
              'before acting.',
        ),
      ],
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'product-to-goal-match',
      categorizePrompt:
          'Match each fictional situation above to the most sensible next '
          'step.',
      buckets: [
        CategorizeBucket(
          id: 'keep-accessible',
          label:
              'Keep the money '
              'accessible',
        ),
        CategorizeBucket(
          id: 'review-foundation',
          label: 'Review the financial foundation first',
        ),
        CategorizeBucket(
          id: 'investigate-category',
          label: 'Investigate an appropriate product category',
        ),
        CategorizeBucket(
          id: 'do-not-invest-yet',
          label: 'Do not invest this money yet',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'user-a-situation',
          label: 'User A: emergency-fund top-up, 3-month horizon',
          explanation:
              'A short horizon and high liquidity need point toward '
              'keeping this money accessible, not toward any investment '
              'product.',
        ),
        CategorizeItemDef(
          id: 'user-b-situation',
          label: 'User B: a 5-year goal, but no emergency fund yet',
          explanation:
              'Reviewing the financial foundation, an emergency fund '
              'first, makes more sense than moving toward an investment '
              'before that foundation exists.',
        ),
        CategorizeItemDef(
          id: 'user-c-situation',
          label: 'User C: a 15-year goal, foundation already in place',
          explanation:
              'A long horizon and a real ability to absorb a temporary '
              'drop are what make investigating a pooled fund category '
              'worth doing.',
        ),
        CategorizeItemDef(
          id: 'user-d-situation',
          label: 'User D: undecided, feeling pressured by a friend\'s tip',
          explanation:
              'An unclear goal under pressure is a reason to pause, not '
              'act. Not investing this money yet is the sensible step.',
        ),
      ],
      correctBucketByItemId: {
        'user-a-situation': 'keep-accessible',
        'user-b-situation': 'review-foundation',
        'user-c-situation': 'investigate-category',
        'user-d-situation': 'do-not-invest-yet',
      },
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'mastery-scenario',
      scenarioTitle: 'A pressured pitch on emergency-fund money',
      situation:
          'A fictional friend, under time pressure, urges putting '
          'emergency-fund money into a fund with a claimed 10 percent '
          'every month, no matter what happens in the market. What is the '
          'most sensible response, based on this lesson?',
      options: [
        ScenarioChoiceOption(
          id: 'pause-and-decline',
          label:
              'Pause, treat both the pressure and the fixed-return claim '
              'as warning signs, and do not move emergency-fund money into '
              'this at all',
          explanation:
              'Emergency-fund money is exactly the kind of money that '
              'needs to stay accessible, and a fixed return claimed no '
              'matter what the market does is a warning sign on its own.',
        ),
        ScenarioChoiceOption(
          id: 'move-it-now',
          label:
              'Move the money now, since a friend recommended it and time '
              'is short',
          explanation:
              'A friend\'s recommendation and time pressure are not '
              'verification. Emergency-fund money should stay accessible, '
              'and a claimed fixed return regardless of market conditions '
              'is a signal to stop, not to act quickly.',
        ),
      ],
      preferredOptionId: 'pause-and-decline',
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'scam-pressure-signs',
      categorizePrompt:
          'Sort each fictional statement into Red flag or Reasonable sign.',
      buckets: [
        CategorizeBucket(id: 'red-flag', label: 'Red flag'),
        CategorizeBucket(id: 'reasonable', label: 'Reasonable sign'),
      ],
      items: [
        CategorizeItemDef(
          id: 'fixed-monthly-claim',
          label:
              'A fixed 10 percent every month, no matter what happens in '
              'the market',
          explanation:
              'A fixed payout claimed regardless of market conditions is '
              'not how a pooled fund works, and is a strong warning sign.',
        ),
        CategorizeItemDef(
          id: 'trust-officer-writing',
          label:
              'A fictional trust officer offers to explain the fact sheet '
              'in writing before any decision is made',
          explanation:
              'Clear, written explanation before deciding is a reasonable '
              'sign, not a red flag.',
        ),
        CategorizeItemDef(
          id: 'decide-before-reading',
          label: 'Being told to decide before the fact sheet can be read',
          explanation:
              'Being pushed to decide before reviewing the fact sheet is a '
              'pressure tactic and a warning sign.',
        ),
        CategorizeItemDef(
          id: 'verifier-check',
          label:
              'The entity offering the product can be checked against an '
              'official BSP or SEC record',
          explanation:
              'Being checkable against an official record is exactly the '
              'kind of reasonable sign this course recommends looking for.',
        ),
      ],
      correctBucketByItemId: {
        'fixed-monthly-claim': 'red-flag',
        'trust-officer-writing': 'reasonable',
        'decide-before-reading': 'red-flag',
        'verifier-check': 'reasonable',
      },
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'readiness-checklist',
      checklistPrompt:
          'A personal checklist before choosing between a deposit and a '
          'pooled fund category. Offline, and yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'foundation-reviewed',
          label:
              'The financial foundation, including an emergency fund, has '
              'been reviewed',
        ),
        ChecklistItemDef(
          id: 'goal-and-horizon-clear',
          label: 'The goal and time horizon for this money are clear',
        ),
        ChecklistItemDef(
          id: 'loss-capacity-known',
          label:
              'How much could be lost without harming other plans is '
              'known',
        ),
        ChecklistItemDef(
          id: 'product-type-understood',
          label:
              'Whether this is a deposit or an investment product, and its '
              'own protection, is understood',
        ),
        ChecklistItemDef(
          id: 'no-pressure',
          label: 'No decision is being made under pressure or a deadline',
        ),
      ],
      requiredForCompletion: false,
    ),
    SalapifyActionsBlock(
      blockId: 'deposits-pooled-funds-actions',
      menuPrompt: 'A few real next steps, if any of them fit.',
      actions: [
        SalapifyActionDef(
          id: 'review-goal',
          label: 'Create or review a Goal',
          description:
              'Opens Goals to check a goal\'s time horizon, or start one '
              'from a template. Nothing is created or changed until '
              'something is saved there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-budget',
          label: 'Review Budget before setting money aside',
          description:
              'Opens Budget to check what is already spoken for this '
              'period before setting any amount aside. Nothing changes '
              'automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'open-mindset',
          label: 'Open Money Mindset before acting on a pressured pitch',
          description:
              'Opens Money Mindset, a short pause-and-reflect tool, '
              'useful before acting on any tip or pressure to decide '
              'quickly. Nothing is recorded as a transaction.',
          route: 'mindset',
        ),
        SalapifyActionDef(
          id: 'review-investment-account',
          label: 'Review your Accounts',
          description:
              'Opens Accounts, where a time deposit and a pooled-fund '
              'asset type, like a mutual fund or UITF, are already '
              'supported as separate kinds if you choose to add one. '
              'Nothing is created automatically, and no product is '
              'purchased or recommended here.',
          route: 'accounts',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'User A needs money accessible for an emergency within a few '
        'months. What does this lesson say is the sensible next step for '
        'that money?',
    choices: [
      'Move it into a pooled fund for a better return',
      'Keep it accessible, since the short horizon and high liquidity '
          'need point away from an investment product',
      'Wait for a friend\'s recommendation before deciding',
    ],
    correctIndex: 1,
    explanation:
        'A short time horizon and a high need for accessible money point '
        'toward keeping money accessible, not toward an investment '
        'product, whatever return it claims.',
    whyWrong:
        'Moving emergency-fund money into a pooled fund ignores its short '
        'horizon and liquidity need, and a friend\'s recommendation is '
        'never a substitute for matching the product to the goal.',
  ),
  keyTakeaway:
      'The right next step follows the goal, the time horizon, and how '
      'much loss can really be absorbed, and sometimes the sensible answer '
      'is to keep the money accessible or wait, not to invest it.',
);
