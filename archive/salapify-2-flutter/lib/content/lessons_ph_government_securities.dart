// Money Courses Phase 12: the "Grow Your Money" learning path's fifth
// course, "Philippine Government Securities" (course id
// 'ph_government_securities'). Builds on the completed Owner or Lender?
// distinction from Phase 7A ("Stocks and Bonds Without the Hype",
// lib/content/lessons_stocks_bonds.dart) and the deposit-versus-investment
// boundary from Phase 7B ("Deposits and Pooled Funds"), without modifying
// either course or the core 22 lessons: separate content file, separate
// lesson ids, same architecture already shipped by Phase 2 to 11
// (governance metadata, official-source and risk-warning blocks, Phase 5
// interaction blocks).
//
// This course teaches DECISION MAKING, never a purchase. It never
// recommends a specific Treasury bill, Treasury bond, or Retail Treasury
// Bond, never calculates an expected return, and never offers a way to buy
// one inside the app. House rules, same as lessons_stocks_bonds.dart: plain
// English, Philippine peso examples only where fictional, no em or en
// dashes, no risk-free or guaranteed-profit language, no personalized
// recommendation, no active auction schedule, current rate, or selling
// agent named anywhere in this file. Every fictional saver or scenario is
// invented for this course.
//
// Content topics are set (ContentTopic.bonds) on every lesson here, the
// same choice lessons_stocks_bonds.dart made for its own bond lesson: a
// Philippine government security is, structurally, a bond the national
// government issues, and treating this course as "regulated" under
// money/expansion_content_policy.dart's own definition activates the
// Phase 4 validator's mandatory official-source, risk-warning, and
// educational-boundary checks instead of relying only on this file's own
// content test to enforce them by hand.
//
// Sources: the Bureau of the Treasury (its own site, its FiLi investor
// education, Retail Treasury Bonds, and Investing 101 pages, and its
// Outstanding Government Securities page), the Securities and Exchange
// Commission Philippines' Investment 101, the Bangko Sentral ng Pilipinas'
// BSP Verifier, and the Philippine Deposit Insurance Corporation's deposit
// coverage FAQ. Every one of these eight official pages was independently
// confirmed to exist and to cover the topic cited, through WebSearch
// against its own domain (gov.ph fetches return a uniform 403 in this
// environment, the same limitation lessons_stocks_bonds.dart's own header
// notes), per this repository's rule that a Money Courses official-source
// URL needs a real search, not just a cite. No current offering, auction
// schedule, rate, yield, minimum placement, selling agent, or maturity
// table is embedded anywhere in this file: those are named in this
// course's own copy as exactly the things a reader must verify against the
// Bureau of the Treasury's current notice before acting. Reviewed by the
// investment-literacy-reviewer agent before this course shipped (see
// governance.reviewerId below).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

// Plain string constants, not fields on a shared object: see
// lessons_stocks_bonds.dart's own comment on why a const OfficialSourceBlock
// call needs these as top-level identifiers rather than reading them off a
// const LessonSourceInfo instance's field.
const _btrAgency = 'Bureau of the Treasury';
const _btrTitle = 'Bureau of the Treasury of the Philippines';
const _btrUrl = 'https://www.treasury.gov.ph/';
const _btrVerified = '2026-08';

const _btr = LessonSourceInfo(
  agency: _btrAgency,
  title: _btrTitle,
  canonicalUrl: _btrUrl,
  lastVerifiedDate: _btrVerified,
);

const _btrFiliInvestorEdAgency = 'Bureau of the Treasury';
const _btrFiliInvestorEdTitle = 'FiLi, Investor Education';
const _btrFiliInvestorEdUrl =
    'https://filiapp.treasury.gov.ph/investor_education.html';
const _btrFiliInvestorEdVerified = '2026-08';

const _btrFiliInvestorEd = LessonSourceInfo(
  agency: _btrFiliInvestorEdAgency,
  title: _btrFiliInvestorEdTitle,
  canonicalUrl: _btrFiliInvestorEdUrl,
  lastVerifiedDate: _btrFiliInvestorEdVerified,
);

const _btrFiliRtbAgency = 'Bureau of the Treasury';
const _btrFiliRtbTitle = 'FiLi, Retail Treasury Bonds';
const _btrFiliRtbUrl =
    'https://filiapp.treasury.gov.ph/retail_treasury_bonds.html';
const _btrFiliRtbVerified = '2026-08';

const _btrFiliRtb = LessonSourceInfo(
  agency: _btrFiliRtbAgency,
  title: _btrFiliRtbTitle,
  canonicalUrl: _btrFiliRtbUrl,
  lastVerifiedDate: _btrFiliRtbVerified,
);

const _btrFiliInvesting101Agency = 'Bureau of the Treasury';
const _btrFiliInvesting101Title = 'FiLi, Investing 101';
const _btrFiliInvesting101Url =
    'https://filiapp.treasury.gov.ph/investing.html';
const _btrFiliInvesting101Verified = '2026-08';

const _btrFiliInvesting101 = LessonSourceInfo(
  agency: _btrFiliInvesting101Agency,
  title: _btrFiliInvesting101Title,
  canonicalUrl: _btrFiliInvesting101Url,
  lastVerifiedDate: _btrFiliInvesting101Verified,
);

const _btrOutstandingAgency = 'Bureau of the Treasury';
const _btrOutstandingTitle = 'Outstanding Government Securities';
const _btrOutstandingUrl = 'https://www.treasury.gov.ph/?page_id=44424';
const _btrOutstandingVerified = '2026-08';

const _btrOutstanding = LessonSourceInfo(
  agency: _btrOutstandingAgency,
  title: _btrOutstandingTitle,
  canonicalUrl: _btrOutstandingUrl,
  lastVerifiedDate: _btrOutstandingVerified,
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

const _pdicAgency = 'Philippine Deposit Insurance Corporation (PDIC)';
const _pdicTitle = 'Deposit Insurance Coverage, Frequently Asked Questions';
const _pdicUrl = 'https://www.pdic.gov.ph/faqs-11';
const _pdicVerified = '2026-08';

const _pdic = LessonSourceInfo(
  agency: _pdicAgency,
  title: _pdicTitle,
  canonicalUrl: _pdicUrl,
  lastVerifiedDate: _pdicVerified,
);

const _governance = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'ILR',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel:
      'the Bureau of the Treasury, the Securities and Exchange Commission, '
      'and the Bangko Sentral ng Pilipinas',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form, same convention as
/// lessons_stocks_bonds.dart's own ids. Never reused for a different lesson
/// once a learner has real progress recorded against one (see
/// money/expansion_progress.dart).
const gsLendingToGovernment = 'gs-lending-to-government';
const gsTypesOfSecurities = 'gs-types-of-securities';
const gsCouponYieldPriceMaturity = 'gs-coupon-yield-price-maturity';
const gsHowSecuritiesReachInvestors = 'gs-how-securities-reach-investors';
const gsRisksAndScamChecks = 'gs-risks-and-scam-checks';
const gsDecisionPlan = 'gs-decision-plan';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// `lessons` list, and never merged into growYourMoneyLessons or any other
/// course's own list: see test/lessons_ph_government_securities_content_test.dart's
/// own isolation checks.
const List<MoneyLesson> phGovernmentSecuritiesLessons = [
  _lendingToGovernment,
  _typesOfSecurities,
  _couponYieldPriceMaturity,
  _howSecuritiesReachInvestors,
  _risksAndScamChecks,
  _decisionPlan,
];

// ---------------------------------------------------------------------------
// Lesson 1: You Are Lending to the Government
// ---------------------------------------------------------------------------

const _lendingToGovernment = MoneyLesson(
  id: gsLendingToGovernment,
  trackId: 'ph_government_securities',
  title: 'You Are Lending to the Government',
  icon: 'handshake',
  minutes: 5,
  summary:
      'A government security is money lent to the government that issued '
      'it. Government issued does not mean free of risk or certain to '
      'profit.',
  objective:
      'Tell a government security apart from a bank deposit before looking '
      'at any specific offering.',
  sections: [],
  governance: _governance,
  sources: [_btr, _btrFiliInvestorEd, _pdic],
  topics: [ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Who is borrowing here',
      paragraphs: [
        'You hear the words government security and assume it works '
            'like putting money in a bank. A government security represents '
            'money lent to the government that issued it. Buying one '
            'generally means you are lending to the Republic of the '
            'Philippines, which promises to pay it back later. That usually '
            'comes with a return set by the security\'s own terms.',
        'A government security is an investment security, not a bank '
            'savings account, even though opening either one can feel '
            'similarly simple. The Republic raises funds this way through '
            'securities issued through the Bureau of the Treasury, mainly '
            'Treasury bills, Treasury bonds, and Retail Treasury Bonds.',
        'A government security can generate income under its own stated '
            'terms. Being issued by the government does not remove every '
            'risk, and it does not promise a profit. The two ideas, '
            'government issued and free of risk, are not the same thing, '
            'and this course treats them as separate on purpose.',
      ],
    ),
    NuggetsBlock([
      'Lending to the government is still lending. It depends on the '
          'issuer being able and willing to pay, the same as any other '
          'loan.',
      'A bank deposit and a government security are different '
          'relationships with different protections. A regular deposit '
          'account is a claim against the bank itself, and eligible '
          'deposits are covered by deposit insurance up to a set limit. A '
          'government security is not a deposit, and that same deposit '
          'insurance does not automatically extend to it.',
      'Emergency cash kept for immediate use is a different tool again, '
          'meant to stay accessible rather than to generate a return.',
    ]),
    RiskWarningBlock(
      title: 'Government issued does not mean free of risk',
      text:
          'A government security can still lose value before maturity, '
          'and its return depends on terms that are specific to each '
          'offering. Nothing in this course promises a fixed outcome, and '
          'nothing here is a personal recommendation to buy anything.',
    ),
    OfficialSourceBlock(
      agency: _btrAgency,
      sourceTitle: _btrTitle,
      canonicalUrl: _btrUrl,
      lastVerifiedDate: _btrVerified,
    ),
    OfficialSourceBlock(
      agency: _btrFiliInvestorEdAgency,
      sourceTitle: _btrFiliInvestorEdTitle,
      canonicalUrl: _btrFiliInvestorEdUrl,
      lastVerifiedDate: _btrFiliInvestorEdVerified,
    ),
    OfficialSourceBlock(
      agency: _pdicAgency,
      sourceTitle: _pdicTitle,
      canonicalUrl: _pdicUrl,
      lastVerifiedDate: _pdicVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'lending-or-depositing-sort',
      categorizePrompt:
          'Sort each fictional example into the group it represents.',
      buckets: [
        CategorizeBucket(id: 'bank-deposit', label: 'Bank deposit'),
        CategorizeBucket(id: 'gov-security', label: 'Government security'),
        CategorizeBucket(id: 'corp-stock', label: 'Corporate stock'),
        CategorizeBucket(id: 'emergency-cash', label: 'Emergency cash'),
      ],
      items: [
        CategorizeItemDef(
          id: 'passbook',
          label:
              'Money sitting in a fictional regular savings passbook '
              'account',
          explanation:
              'A regular savings account is a claim against the bank '
              'itself, a bank deposit relationship with its own separate '
              'protections.',
        ),
        CategorizeItemDef(
          id: 'gov-bond',
          label:
              'A fictional bond issued by the national government, held '
              'in a brokerage account',
          explanation:
              'A government bond is generally a loan to the government, '
              'an investment security rather than a deposit.',
        ),
        CategorizeItemDef(
          id: 'listed-shares',
          label: 'Shares bought in a fictional listed company',
          explanation:
              'Shares in a company are generally an ownership stake, a '
              'different relationship from lending to the government.',
        ),
        CategorizeItemDef(
          id: 'home-cash',
          label:
              'Cash set aside at home for a fictional sudden emergency, '
              'meant to be spent immediately if needed',
          explanation:
              'Money meant to stay immediately accessible for an '
              'emergency is a different tool from an investment security, '
              'even a government one.',
        ),
      ],
      correctBucketByItemId: {
        'passbook': 'bank-deposit',
        'gov-bond': 'gov-security',
        'listed-shares': 'corp-stock',
        'home-cash': 'emergency-cash',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'gov-bond-is-a-deposit-myth',
      statement:
          'A government bond is covered by the same deposit insurance '
          'that protects a bank savings account, since both are commonly '
          'seen as safe.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'They are different relationships. Deposit insurance is '
          'specific to eligible deposit accounts at a bank. A government '
          'bond is a lending relationship with the government, a '
          'different kind of instrument with its own separate risks and '
          'protections.',
      requiredForCompletion: true,
      officialSource: _pdic,
    ),
    ScenarioChoiceBlock(
      blockId: 'friend-calls-it-risk-free',
      scenarioTitle: 'A friend calls it free of risk',
      situation:
          'A fictional friend says, "A government bond cannot lose money, '
          'since the government backs it." What is the clearest way to '
          'respond, based on this lesson?',
      options: [
        ScenarioChoiceOption(
          id: 'explain-not-risk-free',
          label:
              'Explain that a government security can still lose value or '
              'carry risk, and that government issued is not the same as '
              'free of risk',
          explanation:
              'This names the real distinction this lesson teaches. A '
              'security being issued by the government changes who the '
              'borrower is, not whether risk exists at all.',
        ),
        ScenarioChoiceOption(
          id: 'agree',
          label:
              'Agree, since the government is the safest possible '
              'borrower there is',
          explanation:
              'A national government is often seen as a comparatively low '
              'credit risk, but that is a different statement from '
              'saying nothing can go wrong. Treating the two as the same '
              'thing skips a real distinction.',
        ),
      ],
      preferredOptionId: 'explain-not-risk-free',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional saver buys a government security. What does that '
        'generally make them?',
    choices: [
      'A depositor at the government',
      'A lender to the government',
      'An owner of part of the government',
    ],
    correctIndex: 1,
    explanation:
        'Buying a government security is generally a loan to the '
        'government that issued it, repaid later under that security\'s '
        'own terms.',
    whyWrong:
        'A government security is not a deposit account and it does not '
        'grant ownership of anything. It is a lending relationship.',
  ),
  keyTakeaway:
      'A government security is money lent to the government, an '
      'investment security and not a bank deposit, and government issued '
      'is never the same statement as free of risk or a certain outcome.',
);

// ---------------------------------------------------------------------------
// Lesson 2: T-Bills, Treasury Bonds, and RTBs
// ---------------------------------------------------------------------------

const _typesOfSecurities = MoneyLesson(
  id: gsTypesOfSecurities,
  trackId: 'ph_government_securities',
  title: 'T-Bills, Treasury Bonds, and RTBs',
  icon: 'table',
  minutes: 6,
  summary:
      'Treasury bills, Treasury bonds, and Retail Treasury Bonds are built '
      'differently. Telling them apart starts with maturity and how the '
      'return is structured.',
  objective:
      'Tell apart a Treasury bill, a Treasury bond, and a Retail Treasury '
      'Bond well enough to know which one is worth investigating further '
      'for a given goal.',
  sections: [],
  governance: _governance,
  sources: [_btrFiliInvestorEd, _btrFiliInvesting101, _btrFiliRtb],
  topics: [ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Two questions tell them apart',
      paragraphs: [
        'You see three names on an offering and cannot tell what '
            'actually separates them. The Bureau of the Treasury issues a '
            'few different Philippine government securities. Telling them '
            'apart starts with two questions: how long until the money is '
            'scheduled to come back, and how the return is built into it.',
        'A Treasury bill is generally a shorter term security, maturing '
            'in a year or less. It is generally sold on a discount basis, '
            'bought below its face value and paying the full face value '
            'at maturity, rather than paying a separate periodic interest '
            'payment along the way.',
        'A Treasury bond is generally a longer term security, maturing in '
            'more than a year. It generally pays a coupon, a periodic '
            'interest payment, in addition to returning its face value at '
            'maturity.',
        'A Retail Treasury Bond, or RTB, is a Treasury bond structured '
            'for individual, retail investors rather than institutions, '
            'generally offered through channels aimed at individual '
            'savers. An RTB still follows the same basic bond structure, '
            'a coupon paid periodically and a face value returned at '
            'maturity. Face value is the amount printed on the security '
            'and scheduled to be paid back; maturity value is what is '
            'actually received when it matures.',
      ],
    ),
    NuggetsBlock([
      'Shorter maturity generally points toward a Treasury bill; longer '
          'maturity generally points toward a Treasury bond or an RTB.',
      'A Treasury bill\'s return generally comes from the discount, not '
          'a separate interest payment. A Treasury bond\'s and an RTB\'s '
          'return generally comes from the coupon, paid periodically.',
      'An RTB is a Treasury bond built with individual investors in '
          'mind. Its specific terms, like the terms of any government '
          'security, are set by that particular offering, so the current '
          'official notice is always worth checking directly rather than '
          'relying on what an earlier offering looked like.',
    ]),
    RiskWarningBlock(
      title: 'Structure is not a promise',
      text:
          'Knowing whether a security is a Treasury bill, a Treasury '
          'bond, or an RTB describes how it is built. It does not '
          'promise a specific return, and it is never a personal '
          'recommendation to choose one over another.',
    ),
    OfficialSourceBlock(
      agency: _btrFiliInvestorEdAgency,
      sourceTitle: _btrFiliInvestorEdTitle,
      canonicalUrl: _btrFiliInvestorEdUrl,
      lastVerifiedDate: _btrFiliInvestorEdVerified,
    ),
    OfficialSourceBlock(
      agency: _btrFiliInvesting101Agency,
      sourceTitle: _btrFiliInvesting101Title,
      canonicalUrl: _btrFiliInvesting101Url,
      lastVerifiedDate: _btrFiliInvesting101Verified,
    ),
    OfficialSourceBlock(
      agency: _btrFiliRtbAgency,
      sourceTitle: _btrFiliRtbTitle,
      canonicalUrl: _btrFiliRtbUrl,
      lastVerifiedDate: _btrFiliRtbVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ScenarioChoiceBlock(
      blockId: 'near-term-goal-match',
      scenarioTitle: 'A fictional near-term goal',
      situation:
          'A fictional saver wants to set money aside for a goal they '
          'expect to need in about eight months. Which type is worth '
          'looking into first?',
      options: [
        ScenarioChoiceOption(
          id: 'tbill-near',
          label: 'A Treasury bill',
          explanation:
              'Learn more about this type. A Treasury bill is generally '
              'shorter term, closer to an eight month goal than a longer '
              'security would be. Check the current offering before '
              'deciding anything, since exact terms vary by offering.',
        ),
        ScenarioChoiceOption(
          id: 'tbond-near',
          label: 'A Treasury bond',
          explanation:
              'The maturity may not match this goal. A Treasury bond is '
              'generally longer term, which may run well past when this '
              'fictional saver expects to need the money.',
        ),
        ScenarioChoiceOption(
          id: 'rtb-near',
          label: 'A Retail Treasury Bond',
          explanation:
              'The maturity may not match this goal. An RTB is a '
              'Treasury bond built for individual investors, but it is '
              'still generally a longer term security than an eight '
              'month goal calls for.',
        ),
      ],
      preferredOptionId: 'tbill-near',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'long-term-goal-match',
      scenarioTitle: 'A fictional long-term goal',
      situation:
          'A different fictional saver is thinking about a goal roughly '
          'ten years away. Which type is worth looking into first?',
      options: [
        ScenarioChoiceOption(
          id: 'tbond-long',
          label: 'A Treasury bond',
          explanation:
              'Learn more about this type. A Treasury bond is generally '
              'longer term, closer to a ten year goal. Check the current '
              'offering to see what is actually available right now.',
        ),
        ScenarioChoiceOption(
          id: 'rtb-long',
          label: 'A Retail Treasury Bond',
          explanation:
              'Learn more about this type. An RTB is a Treasury bond '
              'aimed at individual investors and is also generally longer '
              'term. Check the current offering, since specific RTB terms '
              'change from one offering to the next.',
        ),
        ScenarioChoiceOption(
          id: 'tbill-long',
          label: 'A Treasury bill',
          explanation:
              'The maturity may not match this goal. A Treasury bill is '
              'generally shorter term, which does not fit a goal roughly '
              'ten years away.',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'tbill-pays-a-coupon-myth',
      statement:
          'A Treasury bill generally pays the holder a separate periodic '
          'interest payment, the same way a Treasury bond does.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A Treasury bill is generally sold on a discount basis instead: '
          'bought below its face value, with the full face value paid at '
          'maturity, rather than a separate periodic interest payment.',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Based on this lesson, what generally tells a Treasury bill and '
        'a Treasury bond apart?',
    choices: [
      'A Treasury bill is generally shorter term and sold at a discount; '
          'a Treasury bond is generally longer term and pays a coupon',
      'A Treasury bill is only available to institutions, while a '
          'Treasury bond is only available to individuals',
      'There is no real difference between them',
    ],
    correctIndex: 0,
    explanation:
        'Maturity and return structure are the two things that generally '
        'separate a Treasury bill from a Treasury bond: shorter term and '
        'discount based, versus longer term and coupon paying.',
    whyWrong:
        'Neither security is restricted to one kind of buyer by that '
        'label alone, and the two are built differently enough that '
        'treating them as the same skips the distinction this lesson '
        'teaches.',
  ),
  keyTakeaway:
      'A Treasury bill is generally shorter term and discount based, a '
      'Treasury bond is generally longer term and coupon paying, and an '
      'RTB is a Treasury bond built for individual investors. None of '
      'that tells anyone which one to choose, only what to look into '
      'further.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Coupon, Yield, Price, and Maturity
// ---------------------------------------------------------------------------

const _couponYieldPriceMaturity = MoneyLesson(
  id: gsCouponYieldPriceMaturity,
  trackId: 'ph_government_securities',
  title: 'Coupon, Yield, Price, and Maturity',
  icon: 'chart',
  minutes: 6,
  summary:
      'Face value, price, coupon, yield, and maturity are related but not '
      'identical. Holding to maturity is a different experience from '
      'selling early.',
  objective:
      'Explain how coupon, yield, price, and maturity relate to each '
      'other, without calculating any of them.',
  sections: [],
  governance: _governance,
  sources: [_btrFiliInvestorEd, _secInvestment101],
  topics: [ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Five words, one security',
      paragraphs: [
        'You keep meeting five words that all sound like the same '
            'thing. Face value is the amount printed on the security, '
            'scheduled to be paid back at maturity, its own end date. '
            'Coupon is the periodic interest some securities pay, stated as '
            'a rate on face value. Purchase price is what was paid, above, '
            'at, or below face value, and yield, the return available at '
            'that price, can differ from the coupon.',
        'The primary market is where a security is first issued, bought '
            'directly through the offering itself. The secondary market '
            'is where an already issued security can be bought or sold '
            'between investors before maturity.',
        'Coupon and yield are related but not identical, and price is '
            'what connects them. The market price of a security can move '
            'after it is issued, even though its coupon rate does not '
            'change. Selling before maturity can produce a gain or a '
            'loss, depending on the price at that moment.',
        'Holding to maturity does not remove every consideration. '
            'Inflation, liquidity, opportunity cost, reinvestment, tax, '
            'and sovereign credit still matter, whether a security is '
            'sold early or held all the way through. Fees and taxes may '
            'reduce the amount actually received.',
      ],
    ),
    NuggetsBlock([
      'Buying above face value generally pulls the actual yield below '
          'the coupon rate printed on the security. Buying below face '
          'value generally pushes the actual yield above that printed '
          'rate. The price paid is what makes the two numbers diverge.',
      'A primary offering\'s price is set by the Bureau of the Treasury '
          'itself. A secondary market price is whatever the current '
          'buyer and seller agree to at that moment, which can drift '
          'away from face value as conditions change.',
      'Held to maturity, face value is what is scheduled to come back, '
          'whatever the market price did along the way. Sold earlier, '
          'the market price at that moment is what actually changes '
          'hands, not the printed face value.',
    ]),
    RiskWarningBlock(
      title: 'Several considerations remain even held to maturity',
      text:
          'Inflation can quietly reduce what a fixed payment is actually '
          'worth. Fees and taxes may reduce the amount received. Holding '
          'to maturity changes some of these considerations, but it does '
          'not remove every one of them.',
    ),
    OfficialSourceBlock(
      agency: _btrFiliInvestorEdAgency,
      sourceTitle: _btrFiliInvestorEdTitle,
      canonicalUrl: _btrFiliInvestorEdUrl,
      lastVerifiedDate: _btrFiliInvestorEdVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ScenarioChoiceBlock(
      blockId: 'rtb-bought-above-face-value',
      scenarioTitle: 'A fictional RTB bought above face value',
      situation:
          'A fictional Retail Treasury Bond is already trading in the '
          'secondary market. Its printed coupon rate is attractive '
          'enough, compared to what new securities are currently '
          'offering, that a buyer pays a price above its face value to '
          'get it. Based on this lesson, what does that generally mean '
          'for the yield that buyer actually ends up with, compared to '
          'the coupon rate printed on the RTB?',
      options: [
        ScenarioChoiceOption(
          id: 'yield-below-coupon',
          label:
              'The actual yield generally ends up below the printed '
              'coupon rate',
          explanation:
              'Paying more than face value to receive the same fixed '
              'coupon payments generally pulls the actual yield below the '
              'printed coupon rate. This describes the general '
              'relationship between price and yield, not a prediction for '
              'any specific security.',
        ),
        ScenarioChoiceOption(
          id: 'yield-above-coupon',
          label:
              'The actual yield generally ends up above the printed '
              'coupon rate',
          explanation:
              'This is the opposite of what generally happens when a '
              'security is bought above face value. Paying more for the '
              'same fixed coupon payments generally pulls yield down, not '
              'up.',
        ),
        ScenarioChoiceOption(
          id: 'yield-equals-coupon',
          label:
              'The actual yield always equals the printed coupon rate, '
              'whatever price was paid',
          explanation:
              'Coupon and yield are related but not identical. The price '
              'actually paid is exactly what makes them diverge, so '
              'paying above or below face value generally changes the '
              'yield away from the printed coupon rate.',
        ),
      ],
      preferredOptionId: 'yield-below-coupon',
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'maturity-removes-every-consideration-myth',
      statement:
          'Holding a government security all the way to maturity removes '
          'every consideration, including inflation, tax, and fees.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Holding to maturity changes some considerations, particularly '
          'around resale price, but inflation, tax, fees, and sovereign '
          'credit still apply whether a security is sold early or held '
          'all the way through.',
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'coupon-yield-reflect',
      question:
          'Before this lesson, would you have expected a fixed coupon '
          'security to have a fixed resale price too? What changed in '
          'how you would look at that now?',
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fixed-coupon government security was bought, then market '
        'rates on comparable new securities fell. Based on this lesson, '
        'what generally happens to the price it could fetch before '
        'maturity?',
    choices: [
      'The price it could fetch generally rises, since the fixed coupon '
          'is now relatively more attractive',
      'The price it could fetch generally falls',
      'Nothing changes, since the coupon rate is fixed',
    ],
    correctIndex: 0,
    explanation:
        'When comparable new securities offer a lower rate, an older '
        'fixed-coupon security generally becomes relatively more '
        'attractive, which generally pushes its resale price up. This '
        'describes the general mechanism, not a prediction for any '
        'specific security.',
    whyWrong:
        'A fixed coupon rate does not mean a fixed resale price. The '
        'price before maturity generally still moves with market rates.',
  ),
  keyTakeaway:
      'Face value, price, coupon, yield, and maturity describe different '
      'parts of the same security, and holding to maturity changes some '
      'considerations without removing inflation, liquidity, opportunity '
      'cost, reinvestment, tax, or sovereign credit entirely.',
);

// ---------------------------------------------------------------------------
// Lesson 4: How Government Securities Reach Investors
// ---------------------------------------------------------------------------

const _howSecuritiesReachInvestors = MoneyLesson(
  id: gsHowSecuritiesReachInvestors,
  trackId: 'ph_government_securities',
  title: 'How Government Securities Reach Investors',
  icon: 'flow',
  minutes: 6,
  summary:
      'A new offering and buying in the secondary market are different '
      'paths. An old advertisement never proves the same terms are still '
      'available today.',
  objective:
      'Run through the official checks worth doing before acting on any '
      'government security offering.',
  sections: [],
  governance: _governance,
  sources: [_btr, _btrOutstanding, _secInvestment101],
  topics: [ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Two ways in',
      paragraphs: [
        'You saw a poster for an offering months ago, and you are not '
            'sure it still exists. A new, or primary, offering is where a '
            'government security is first issued and bought directly '
            'through that offering. The secondary market means buying an '
            'already issued security from another investor, at whatever '
            'price the market sets that moment. Both are real paths, and '
            'they are not the same transaction.',
        'Offering schedules and the specific securities available change '
            'over time. An old advertisement or a previous offering page '
            'does not prove that the same terms remain available today, '
            'even if the security type is the same.',
        'Retail channels for a government security depend on the '
            'specific official offering behind it. The one reliable way '
            'to know what is actually current is to read the Bureau of '
            'the Treasury\'s own current notice or offering document '
            'directly, not to rely on a memory of an older one.',
      ],
    ),
    NuggetsBlock([
      'The Bureau of the Treasury\'s own site is the starting point for '
          'checking what is currently being offered, not a bank, broker, '
          'or app\'s own marketing page.',
      'A rate, minimum amount, or maturity mentioned in an old post or '
          'screenshot may no longer describe anything currently '
          'available.',
      'Keeping the official confirmation of any transaction is part of '
          'the same discipline as checking the offering before it '
          'happens.',
    ]),
    RiskWarningBlock(
      title: 'An old notice is not a current one',
      text:
          'Terms shown in an old advertisement, a screenshot, or a '
          'previous offering page may no longer apply to what is '
          'currently available. Always check the Bureau of the '
          'Treasury\'s current notice before acting on anything.',
    ),
    OfficialSourceBlock(
      agency: _btrAgency,
      sourceTitle: _btrTitle,
      canonicalUrl: _btrUrl,
      lastVerifiedDate: _btrVerified,
    ),
    OfficialSourceBlock(
      agency: _btrOutstandingAgency,
      sourceTitle: _btrOutstandingTitle,
      canonicalUrl: _btrOutstandingUrl,
      lastVerifiedDate: _btrOutstandingVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    SortingBlock(
      blockId: 'official-offer-check-sequence',
      sortingPrompt:
          'Put this official offer check in the order it should '
          'happen.',
      items: [
        SortingItemDef(
          id: 'start-at-btr',
          label: 'Start at the Bureau of the Treasury',
        ),
        SortingItemDef(
          id: 'locate-notice',
          label: 'Locate the current official notice',
        ),
        SortingItemDef(
          id: 'check-type-maturity',
          label: 'Check the security type and maturity',
        ),
        SortingItemDef(
          id: 'review-rate-terms',
          label: 'Review the current rate or yield terms',
        ),
        SortingItemDef(
          id: 'review-fees-liquidity',
          label: 'Review fees, taxes, liquidity, and early-sale conditions',
        ),
        SortingItemDef(
          id: 'verify-channel',
          label:
              'Verify the named selling channel through the proper '
              'regulator',
        ),
        SortingItemDef(
          id: 'keep-confirmation',
          label: 'Keep the official transaction confirmation',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'old-ad-still-valid-myth',
      statement:
          'An advertisement from a previous government security offering '
          'proves the same rate and terms are still available today.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Offering schedules and terms change. An old advertisement or a '
          'previous offering page only describes what was true when it '
          'was published, never what is currently open.',
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'secondary-market-price-differs',
      scenarioTitle: 'Buying in the secondary market',
      situation:
          'A fictional saver wants to buy a government security that '
          'was issued a while ago, rather than wait for a new offering. '
          'What should they expect about the price?',
      options: [
        ScenarioChoiceOption(
          id: 'market-price-may-differ',
          label:
              'The price may differ from the security\'s face value, set '
              'by the secondary market at that moment',
          explanation:
              'Buying in the secondary market means buying at whatever '
              'price the market sets then, which can be above or below '
              'face value.',
        ),
        ScenarioChoiceOption(
          id: 'always-face-value',
          label: 'The price will always equal the security\'s face value',
          explanation:
              'That is only true at issuance or at maturity. A secondary '
              'market price can move away from face value in between.',
        ),
      ],
      preferredOptionId: 'market-price-may-differ',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional post from last year advertises a government '
        'security offering with a specific rate. Based on this lesson, '
        'what should happen before acting on it?',
    choices: [
      'Treat the rate as still valid, since it came from an official '
          'looking source at the time',
      'Check the Bureau of the Treasury\'s current notice directly, '
          'since offering terms change over time',
      'Assume the rate improved, since rates generally rise over time',
    ],
    correctIndex: 1,
    explanation:
        'Offering schedules and terms change, so an old advertisement '
        'never proves current availability. The current official notice '
        'is the only reliable source for what is actually being offered '
        'now.',
    whyWrong:
        'Neither assuming the old terms still apply, nor assuming they '
        'changed in a specific direction, replaces actually checking the '
        'current notice.',
  ),
  keyTakeaway:
      'A new offering and the secondary market are different paths to '
      'the same kind of security, and only the Bureau of the Treasury\'s '
      'own current notice, checked directly, tells you what is actually '
      'available right now.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Risks and Scam Checks
// ---------------------------------------------------------------------------

const _risksAndScamChecks = MoneyLesson(
  id: gsRisksAndScamChecks,
  trackId: 'ph_government_securities',
  title: 'Risks and Scam Checks',
  icon: 'protected',
  minutes: 6,
  summary:
      'Several separate risks run underneath any government security, '
      'and a fake offering can imitate the real thing closely enough to '
      'fool a fast decision.',
  objective:
      'Name the risks that come with a government security, and '
      'recognize the signs of a fake offering before acting on one.',
  sections: [],
  governance: _governance,
  sources: [_btr, _secInvestment101, _bspVerifier],
  topics: [ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'What still goes wrong',
      paragraphs: [
        'Government issued sounds like nothing can go wrong, and that '
            'is the belief worth testing before your money moves. Several '
            'separate risks run underneath a government security: interest '
            'rate and price risk, inflation risk, liquidity risk, and '
            'reinvestment risk. Then opportunity cost, tax and fee impact, '
            'and sovereign credit risk, the chance even a national '
            'government faces difficulty meeting its own obligations. None '
            'of these disappear simply because the issuer is the '
            'government.',
        'A separate kind of risk sits alongside all of these: a fake '
            'offering built to imitate a real one. Warning signs include '
            'a guaranteed unusually high return, pressure to transfer '
            'money immediately, a request for a one time PIN or a '
            'password, a request to pay into a personal account, a link '
            'that imitates an official government page, a "special '
            'government bond" that does not appear in the Bureau of the '
            'Treasury\'s own current notices, and a seller whose '
            'authority cannot actually be verified.',
        'Not appearing in one regulator\'s own database does not, by '
            'itself, prove something is a scam. Different kinds of '
            'entities are supervised by different regulators, so the '
            'more useful first step is identifying which regulator '
            'actually covers whatever is being offered, then checking '
            'there directly.',
      ],
    ),
    NuggetsBlock([
      'A national government is often seen as a comparatively lower '
          'credit risk than many other borrowers, though lower risk is '
          'never the same as no risk.',
      'Genuine urgency is rare in a legitimate offering. Pressure to '
          'decide immediately is far more often a sign that something is '
          'wrong than a sign of real opportunity.',
      'An OTP or a password is never something a legitimate offering '
          'needs from a message or a call. Sharing either can hand over '
          'access that is very hard to undo.',
    ]),
    RiskWarningBlock(
      title: 'Several risks, plus a separate scam risk',
      text:
          'A government security can lose value before maturity, and its '
          'issuer could face difficulty paying as promised, however '
          'unlikely that may seem. A fake offering built to look '
          'official can cost everything sent to it. Verifying first is '
          'the single most protective habit in this lesson.',
    ),
    OfficialSourceBlock(
      agency: _btrAgency,
      sourceTitle: _btrTitle,
      canonicalUrl: _btrUrl,
      lastVerifiedDate: _btrVerified,
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
    CategorizeBlock(
      blockId: 'risk-type-match',
      categorizePrompt: 'Match each situation to the risk it describes.',
      buckets: [
        CategorizeBucket(
          id: 'interest-rate',
          label:
              'Interest rate and '
              'price risk',
        ),
        CategorizeBucket(id: 'inflation', label: 'Inflation risk'),
        CategorizeBucket(id: 'liquidity', label: 'Liquidity risk'),
        CategorizeBucket(id: 'reinvestment', label: 'Reinvestment risk'),
        CategorizeBucket(id: 'opportunity-cost', label: 'Opportunity cost'),
        CategorizeBucket(id: 'tax-fee', label: 'Tax and fee impact'),
        CategorizeBucket(
          id: 'sovereign-credit',
          label:
              'Sovereign credit '
              'risk',
        ),
        CategorizeBucket(
          id: 'phishing',
          label:
              'Phishing and fake '
              'offering pages',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'rate-rise',
          label:
              'A newer Treasury bond offering pays a noticeably higher '
              'rate than an older security someone is already holding',
          explanation:
              'This is interest rate and price risk. Once comparable new '
              'securities pay more, an older fixed-coupon security '
              'generally becomes less attractive at its original price, '
              'and whatever it could fetch on the secondary market moves '
              'accordingly.',
        ),
        CategorizeItemDef(
          id: 'prices-rise',
          label:
              'A few years into holding a Retail Treasury Bond, the peso '
              'buys noticeably less at the market than it used to',
          explanation:
              'This is inflation risk. The coupon and face value stay '
              'fixed in peso terms, so general price increases quietly '
              'erode what those fixed payments can actually cover.',
        ),
        CategorizeItemDef(
          id: 'hard-to-sell',
          label:
              'A holder tries to sell a government security in the '
              'secondary market and finds very few buyers willing to '
              'trade at a fair price',
          explanation:
              'This is liquidity risk. Not every government security '
              'trades actively in the secondary market, so exiting a '
              'position before maturity is not always quick, or possible '
              'at a fair price.',
        ),
        CategorizeItemDef(
          id: 'lower-rate-later',
          label:
              'A Treasury bill matures, and the next batch the Bureau of '
              'the Treasury offers pays less than the one that just '
              'matured',
          explanation:
              'This is reinvestment risk. Whatever comes back at '
              'maturity still has to be placed somewhere, and the next '
              'available rate is never guaranteed to match the one just '
              'received.',
        ),
        CategorizeItemDef(
          id: 'money-tied-up',
          label:
              'Money placed in a longer maturity security could have '
              'covered a different goal that came up sooner',
          explanation:
              'This is opportunity cost: what was given up by tying '
              'money up in this security instead of something else.',
        ),
        CategorizeItemDef(
          id: 'fees-reduce',
          label:
              'Fees and taxes reduce the amount actually received at '
              'the end',
          explanation:
              'This is tax and fee impact: the stated return is never '
              'automatically the amount that ends up in hand.',
        ),
        CategorizeItemDef(
          id: 'issuer-trouble',
          label:
              'The issuing government faces difficulty meeting its own '
              'obligations',
          explanation:
              'This is sovereign credit risk: the chance that even a '
              'national government fails to pay as promised, however '
              'unlikely that may seem for a given issuer.',
        ),
        CategorizeItemDef(
          id: 'fake-page',
          label:
              'A message links to a page that looks like an official '
              'Treasury page but is not',
          explanation:
              'This is a phishing attempt: a fake offering page built to '
              'imitate a real one.',
        ),
      ],
      correctBucketByItemId: {
        'rate-rise': 'interest-rate',
        'prices-rise': 'inflation',
        'hard-to-sell': 'liquidity',
        'lower-rate-later': 'reinvestment',
        'money-tied-up': 'opportunity-cost',
        'fees-reduce': 'tax-fee',
        'issuer-trouble': 'sovereign-credit',
        'fake-page': 'phishing',
      },
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'scam-red-flags',
      categorizePrompt:
          'Sort each fictional statement into Red flag or Reasonable '
          'sign.',
      buckets: [
        CategorizeBucket(id: 'red-flag', label: 'Red flag'),
        CategorizeBucket(id: 'reasonable', label: 'Reasonable sign'),
      ],
      items: [
        CategorizeItemDef(
          id: 'guaranteed-high-return',
          label: 'A guaranteed unusually high return, no risk at all',
          explanation:
              'A fixed high payout with no risk mentioned at all is not '
              'how a real government security works. This phrasing on '
              'its own is a strong warning sign.',
        ),
        CategorizeItemDef(
          id: 'transfer-now',
          label:
              'You need to transfer money within the hour to secure '
              'the rate',
          explanation:
              'Pressure to transfer money immediately, with no real '
              'reason for the rush, is a common pressure tactic.',
        ),
        CategorizeItemDef(
          id: 'listed-in-notice',
          label:
              'The offering appears in the Bureau of the Treasury\'s own '
              'current notice',
          explanation:
              'Appearing in the official current notice is exactly the '
              'kind of check this lesson recommends doing.',
        ),
        CategorizeItemDef(
          id: 'personal-account',
          label:
              'Payment is requested into a personal bank account, not '
              'an official channel',
          explanation:
              'A request to pay into a personal account rather than a '
              'verified official channel is a common pattern in scams.',
        ),
        CategorizeItemDef(
          id: 'clear-disclosure',
          label:
              'Fees, taxes, and how early sale works are explained '
              'clearly in writing',
          explanation:
              'Clear, written disclosure of fees, taxes, and early-sale '
              'conditions is what a legitimate offering looks like.',
        ),
        CategorizeItemDef(
          id: 'otp-request',
          label:
              'A message asks for a one time PIN to confirm '
              'eligibility',
          explanation:
              'A legitimate offering never needs a one time PIN sent '
              'through a message. This is a strong warning sign.',
        ),
      ],
      correctBucketByItemId: {
        'guaranteed-high-return': 'red-flag',
        'transfer-now': 'red-flag',
        'listed-in-notice': 'reasonable',
        'personal-account': 'red-flag',
        'clear-disclosure': 'reasonable',
        'otp-request': 'red-flag',
      },
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'fake-offering-scenario',
      scenarioTitle: 'A fictional message about a special bond',
      situation:
          'A fictional message claims to be a special government bond '
          'offer with an unusually high return, links to a page that '
          'looks like an official Treasury page, and asks for a one '
          'time PIN to "confirm eligibility." What is the most '
          'protective response?',
      options: [
        ScenarioChoiceOption(
          id: 'verify-before-acting',
          label: 'Verify before acting',
          explanation:
              'Checking the offer against the Bureau of the Treasury\'s '
              'own current notices, before doing anything else, is the '
              'safest first move whenever an offer is described as '
              'special or urgent.',
        ),
        ScenarioChoiceOption(
          id: 'stop-and-check-official',
          label: 'Stop and check the official offering',
          explanation:
              'A "special" government bond that does not appear in the '
              'Bureau of the Treasury\'s own current notices is a reason '
              'to stop and check the official offering directly, never a '
              'reason to act on the message itself.',
        ),
        ScenarioChoiceOption(
          id: 'do-not-share-credentials',
          label: 'Do not share credentials',
          explanation:
              'A one time PIN or a password is never something a '
              'legitimate offering needs from a message like this. '
              'Sharing it can hand over access that is very hard to '
              'undo.',
        ),
        ScenarioChoiceOption(
          id: 'report-official-channel',
          label: 'Report through the appropriate official channel',
          explanation:
              'Once something looks like a fake offering, reporting it '
              'through whichever regulator actually covers what is being '
              'impersonated, the Bureau of the Treasury, the SEC, or the '
              'BSP, is a useful next step.',
        ),
      ],
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional message advertises a "special government bond" '
        'that does not appear anywhere in the Bureau of the Treasury\'s '
        'own current notices, and asks for a one time PIN. What does '
        'this lesson say to do?',
    choices: [
      'Share the PIN, since the message claims to be from the '
          'government',
      'Treat both the unlisted offering and the PIN request as serious '
          'warning signs, and verify before doing anything',
      'Send a small amount first to test whether it is real',
    ],
    correctIndex: 1,
    explanation:
        'An offering absent from official notices and a request for a '
        'one time PIN are both named directly in this lesson as serious '
        'warning signs. The protective move is to verify first, not to '
        'act on either signal.',
    whyWrong:
        'Sharing a PIN, or sending any amount, still puts money or '
        'access at risk before the offering has been checked against '
        'official records.',
  ),
  keyTakeaway:
      'A government security carries several real risks even when '
      'legitimate, and a fake offering adds a separate risk on top: '
      'verify the offering, the channel, and any request for a PIN or '
      'password, every time, before anything moves.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Build Your Government-Securities Decision Plan
// ---------------------------------------------------------------------------

const _decisionPlan = MoneyLesson(
  id: gsDecisionPlan,
  trackId: 'ph_government_securities',
  title: 'Build Your Government-Securities Decision Plan',
  icon: 'target',
  minutes: 6,
  summary:
      'A short set of questions worth answering before acting on any '
      'government security, and a few real next steps in Salapify if any '
      'of them fit.',
  objective:
      'Work through the questions worth answering before acting on a '
      'government security, without landing on a specific amount or '
      'security.',
  sections: [],
  governance: _governance,
  sources: [_btr, _secInvestment101],
  topics: [ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Eight honest questions',
      paragraphs: [
        'You have gone through six lessons, and the last work is the '
            'questions you ask yourself. A few are worth answering honestly '
            'before acting on any government security: what financial goal '
            'would this money serve, and when might it be needed? Is an '
            'emergency buffer already in place, could the money stay until '
            'the stated maturity, and what happens if it is needed early? '
            'Has the current official offering been reviewed, are the '
            'channel, fees, taxes, and risks understood, and how would this '
            'fit alongside existing savings and investments?',
        'None of these questions has one correct answer. The point is '
            'reviewing them honestly, not producing a score, a suitable '
            'label, or a recommended amount.',
      ],
    ),
    NuggetsBlock([
      'Build liquidity first, if there is no emergency buffer in place '
          'yet. Money set aside for a longer maturity security is money '
          'that is harder to reach quickly if something urgent comes up.',
      'Clarify the goal and timeline, if either one is still vague. A '
          'maturity that does not match a goal is a mismatch worth '
          'catching early, as Lesson 2 in this course covered.',
      'Review the official terms, if the current offering has not '
          'actually been checked yet. An old ad, a past rate, or a '
          'remembered minimum does not describe what is available today.',
      'Ready for independent comparison, once the goal, the timeline, '
          'and the current terms are all clear. This course stops there: '
          'it never names which security to choose or how much to put '
          'into it.',
    ]),
    RiskWarningBlock(
      title: 'This plan is a set of questions, not a decision',
      text:
          'This lesson never tells anyone how much to invest, which '
          'security to choose, or what return to expect. It only sets '
          'out what is worth reviewing before deciding anything.',
    ),
    OfficialSourceBlock(
      agency: _btrAgency,
      sourceTitle: _btrTitle,
      canonicalUrl: _btrUrl,
      lastVerifiedDate: _btrVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    MythOrFactBlock(
      blockId: 'safer-fits-any-timeline-myth',
      statement:
          'Since a government security is often seen as comparatively '
          'safer than many other investments, it will fit any financial '
          'goal regardless of when the money is needed.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Comparative safety and maturity are two different questions. '
          'A security whose maturity runs past when the money is needed '
          'does not fit that goal, however the issuer\'s credit is '
          'generally regarded.',
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'decision-plan-checklist',
      checklistPrompt:
          'A personal checklist to run before acting on any government '
          'security. Offline, and yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'goal-named',
          label: 'The financial goal this money would serve is named',
        ),
        ChecklistItemDef(
          id: 'timeline-known',
          label: 'When the money might be needed is roughly known',
        ),
        ChecklistItemDef(
          id: 'emergency-buffer',
          label: 'An emergency buffer is already in place',
        ),
        ChecklistItemDef(
          id: 'can-hold-to-maturity',
          label:
              'Holding until the stated maturity looks realistic for '
              'this goal',
        ),
        ChecklistItemDef(
          id: 'early-access-understood',
          label: 'What happens if the money is needed early is understood',
        ),
        ChecklistItemDef(
          id: 'official-offering-reviewed',
          label:
              'The current official offering has actually been '
              'reviewed',
        ),
        ChecklistItemDef(
          id: 'terms-understood',
          label: 'The channel, fees, taxes, and risks are understood',
        ),
        ChecklistItemDef(
          id: 'fits-other-savings',
          label:
              'How this fits with other savings and investments is '
              'considered',
        ),
      ],
      requiredForCompletion: false,
    ),
    SalapifyActionsBlock(
      blockId: 'decision-plan-actions',
      menuPrompt: 'A few real next steps, if any of them fit.',
      actions: [
        SalapifyActionDef(
          id: 'strengthen-emergency-fund',
          label: 'Strengthen your emergency fund',
          description:
              'Opens Goals to check or start an emergency fund goal '
              'before setting money aside for something longer term. '
              'Nothing is created or changed until something is saved '
              'there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-budget-before-setting-aside',
          label: 'Review Budget for an affordable amount',
          description:
              'Opens Budget to check what is already spoken for this '
              'period before setting any amount aside. Nothing changes '
              'automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'review-accounts-holdings',
          label: 'Review your Accounts',
          description:
              'Opens Accounts, where a Bonds asset type is already '
              'supported if you choose to track one. Nothing is created '
              'automatically, and no security is purchased or '
              'recommended here.',
          route: 'accounts',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Based on this lesson, what should a decision plan like this '
        'one never produce?',
    choices: [
      'A specific peso amount to invest or a single recommended '
          'security',
      'A list of questions worth reviewing honestly before acting',
      'A reminder to check the current official offering first',
    ],
    correctIndex: 0,
    explanation:
        'This lesson is a set of questions and real next steps, never a '
        'suitability decision, a peso amount, or a named security. That '
        'boundary is deliberate.',
    whyWrong:
        'Both a review list and a reminder to check the current offering '
        'are exactly what this lesson is meant to produce.',
  ),
  keyTakeaway:
      'A short honest review of the goal, the timeline, the emergency '
      'buffer, and the current official terms comes before any decision '
      'about a government security, and this course stops there on '
      'purpose.',
);
