// Money Courses Phase 8: the "Grow Your Money" learning path's fourth
// course, "Crypto Without the Hype" (course id 'crypto_without_hype').
// Builds on the completed Investing Readiness pilot, "Stocks and Bonds
// Without the Hype", and "Deposits and Pooled Funds" without modifying any
// of them: separate content file, separate lesson ids, same architecture
// already shipped (governance metadata, official-source and risk-warning
// blocks, Phase 5 and Phase 8 interaction blocks).
//
// This course teaches risk awareness, custody, scam detection, and decision
// discipline. It never promotes crypto ownership: no lesson recommends
// buying anything, no interaction outcome labels a learner ready, suitable,
// approved, qualified, or safe to invest, and every Salapify action offered
// at the end is a safe, existing, non-crypto-specific screen (Goals, Debts,
// Budget, Money Mindset, Accounts) opened manually, never a wallet, an
// exchange, or an automatic write.
//
// House rules, same as the other three courses in this path: plain
// English, Philippine peso examples, no em or en dash, no named coin,
// token, platform, founder, or provider anywhere in this file, no
// guaranteed-outcome or risk-free language, no personalized recommendation,
// no live price, no return forecast, no allocation recommendation, and
// every fictional company or platform used as an example is invented for
// this course and never a real one.
//
// Content topics are set (ContentTopic.cryptocurrency) on every lesson
// here, the same discipline lessons_stocks_bonds.dart and
// lessons_deposits_pooled_funds.dart already follow: this course actually
// teaches about a specific regulated asset category, so it is honestly
// "regulated" under money/expansion_content_policy.dart's own definition,
// which activates the Phase 4 validator's mandatory official-source,
// risk-warning, and educational-boundary checks rather than relying only on
// this file's own content test to enforce them by hand. Classified as
// high-volatility content (ContentVolatility.high, not annual): provider
// directories, regulatory terminology, and consumer advisories in this
// space change faster than a typical course topic, so this course carries
// a shorter review cycle than the other three.
//
// Sources: the Bangko Sentral ng Pilipinas' own Virtual Assets resources
// page and its BSP Verifier, and the Securities and Exchange Commission
// Philippines' own site and its Investment 101 investor-education page.
// Both agencies' sites and the BSP VASP provider directory PDF were
// verified for current terminology, current responsibilities, and whether
// the directory link itself is still live by the investment-literacy-
// reviewer agent before this course shipped (see governance.reviewerId
// below); the directory PDF is deliberately never embedded or linked
// directly in this course's own content per Lesson 5's own rule (link the
// live verifier and current SEC resources, never a static provider list
// that can go stale).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

// Plain string constants, not fields on a shared object: see
// lessons_grow.dart's own comment on why a const OfficialSourceBlock call
// needs these as top-level identifiers rather than reading them off a
// const LessonSourceInfo instance's field.
const _bspVirtualAssetsAgency = 'Bangko Sentral ng Pilipinas (BSP)';
const _bspVirtualAssetsTitle = 'Virtual Assets';
const _bspVirtualAssetsUrl =
    'https://www.bsp.gov.ph/SitePages/MediaAndResearch/Multimedia_VirtualAssets.aspx';
const _bspVirtualAssetsVerified = '2026-08';

const _bspVirtualAssets = LessonSourceInfo(
  agency: _bspVirtualAssetsAgency,
  title: _bspVirtualAssetsTitle,
  canonicalUrl: _bspVirtualAssetsUrl,
  lastVerifiedDate: _bspVirtualAssetsVerified,
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

const _secPhAgency = 'Securities and Exchange Commission Philippines';
const _secPhTitle = 'Securities and Exchange Commission Philippines';
const _secPhUrl = 'https://www.sec.gov.ph/';
const _secPhVerified = '2026-08';

const _secPh = LessonSourceInfo(
  agency: _secPhAgency,
  title: _secPhTitle,
  canonicalUrl: _secPhUrl,
  lastVerifiedDate: _secPhVerified,
);

const _secInvestment101Agency =
    'Securities and Exchange Commission Philippines';
const _secInvestment101Title = 'Investment 101';
const _secInvestment101Url =
    'https://appointment.sec.gov.ph/investors-education-and-information/investment-101/';
const _secInvestment101Verified = '2026-08';

const _secInvestment101 = LessonSourceInfo(
  agency: _secInvestment101Agency,
  title: _secInvestment101Title,
  canonicalUrl: _secInvestment101Url,
  lastVerifiedDate: _secInvestment101Verified,
);

// High volatility, per this course's own classification: a shorter review
// window than the other three courses' annual cycle, since provider
// directories, regulatory terminology, and consumer advisories in this
// space move faster than a typical course topic.
const _governance = LessonGovernance(
  volatility: ContentVolatility.high,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-02',
  reviewerId: 'ILR',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel:
      'the Bangko Sentral ng Pilipinas and the Securities and '
      'Exchange Commission',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form by the same convention every other
/// Grow Your Money course's ids use. Never reused for a different lesson
/// once a learner has real progress recorded against one.
const cryptoRefWhatCryptoIs = 'crypto-what-it-is-and-is-not';
const cryptoRefVolatilityTotalLoss = 'crypto-volatility-total-loss';
const cryptoRefCustodyIrreversibleMistakes = 'crypto-custody-irreversible';
const cryptoRefStablecoinsYieldLeverage = 'crypto-stablecoins-yield-leverage';
const cryptoRefScamsProviderVerification = 'crypto-scams-provider-verification';
const cryptoRefDecisionLab = 'crypto-decision-lab';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// list: the "X of 22" figure on the core Learn screen must never move
/// because of this file (see test/lessons_crypto_content_test.dart).
const List<MoneyLesson> cryptoWithoutHypeLessons = [
  _whatCryptoIsAndIsNot,
  _volatilityAndPossibleTotalLoss,
  _custodyAndIrreversibleMistakes,
  _stablecoinsYieldAndLeverage,
  _scamsAndProviderVerification,
  _theCryptoDecisionLab,
];

// ---------------------------------------------------------------------------
// Lesson 1: What Crypto Is and Is Not
// ---------------------------------------------------------------------------

const _whatCryptoIsAndIsNot = MoneyLesson(
  id: cryptoRefWhatCryptoIs,
  trackId: 'crypto_without_hype',
  title: 'What Crypto Is and Is Not',
  icon: 'inspect',
  minutes: 5,
  summary:
      'A crypto asset is not a company share, not a bank deposit, and not '
      'automatically money. A familiar app does not remove the risk.',
  objective:
      'Tell a crypto asset apart from a share, a deposit, and a '
      'digital payment balance.',
  sections: [],
  governance: _governance,
  sources: [_bspVirtualAssets],
  topics: [ContentTopic.cryptocurrency],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A crypto asset is a digitally represented asset that uses '
            'distributed-ledger or related technology to record who holds '
            'it. That description covers a wide range of things, and '
            'different crypto assets are built to claim different '
            'purposes: some are meant as a way to pay, some are meant to '
            'represent a stake in a project, and some exist mainly to be '
            'traded.',
        'Owning a crypto asset is not the same as owning a share of a '
            'company. A shareholder owns a legal claim on a business, its '
            'profits, and its assets. A crypto asset generally carries no '
            'such claim on any company at all.',
        'A crypto asset is also not automatically the same as money sitting '
            'in a bank account. A peso in a bank account is legal tender '
            'backed by the banking system and, up to a limit, deposit '
            'insurance. A crypto asset is neither of those things unless a '
            'specific law or regulator says otherwise for that specific '
            'case.',
      ],
    ),
    NuggetsBlock([
      'A polished, familiar-looking app interface does not remove '
          'investment risk, custody risk, operational risk, or fraud risk. '
          'The interface is a coat of paint, not a guarantee.',
      'Whether an activity is regulated, and by whom, does not by itself '
          'guarantee anyone a profit or prevent a loss. Regulation can '
          'cover conduct and disclosure without removing the fact that a '
          'crypto asset can lose value.',
    ]),
    RiskWarningBlock(
      title: 'Regulatory status is not a guarantee of profit or safety',
      text:
          'Even where an activity is regulated in some way, that alone does '
          'not guarantee profitability, and it does not prevent the value '
          'of a crypto asset from falling. This lesson is general '
          'education, not a signal to acquire, hold, or avoid anything.',
    ),
    OfficialSourceBlock(
      agency: _bspVirtualAssetsAgency,
      sourceTitle: _bspVirtualAssetsTitle,
      canonicalUrl: _bspVirtualAssetsUrl,
      lastVerifiedDate: _bspVirtualAssetsVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'crypto-what-is-classification',
      categorizePrompt:
          'Sort each fictional description into what it actually is.',
      buckets: [
        CategorizeBucket(id: 'crypto', label: 'Crypto asset'),
        CategorizeBucket(id: 'stock', label: 'Company share'),
        CategorizeBucket(id: 'deposit', label: 'Bank deposit'),
        CategorizeBucket(id: 'payment', label: 'Digital payment balance'),
      ],
      items: [
        CategorizeItemDef(
          id: 'ledger-asset',
          label:
              'A digitally represented asset recorded on a distributed '
              'ledger, with no company behind it and no dividend',
          explanation:
              'This is the general shape of a crypto asset: a '
              'digitally-recorded holding, not a claim on a business.',
        ),
        CategorizeItemDef(
          id: 'listed-share',
          label:
              'A share of ownership in a listed company, carrying a legal '
              'claim on that company\'s profits and assets',
          explanation:
              'This is a company share. It carries ownership rights a '
              'crypto asset generally does not.',
        ),
        CategorizeItemDef(
          id: 'insured-deposit',
          label:
              'Money placed in a bank account, covered by deposit '
              'insurance up to a legal limit',
          explanation:
              'This is a bank deposit, protected by deposit insurance in a '
              'way a crypto asset is not.',
        ),
        CategorizeItemDef(
          id: 'ewallet-balance',
          label:
              'A stored balance in a digital-payment app, used to pay '
              'merchants and send money directly',
          explanation:
              'This is a digital payment balance: built for spending and '
              'transferring, a different purpose than holding a crypto '
              'asset.',
        ),
      ],
      correctBucketByItemId: {
        'ledger-asset': 'crypto',
        'listed-share': 'stock',
        'insured-deposit': 'deposit',
        'ewallet-balance': 'payment',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'crypto-what-is-myth-familiar-app',
      statement:
          'Because a crypto platform\'s app looks and feels as polished as '
          'a banking app, it carries roughly the same risk as a bank '
          'account.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A familiar interface does not remove investment, custody, '
          'operational, or fraud risk. What backs the balance on screen, '
          'and who is accountable if something goes wrong, matters far '
          'more than how the app looks.',
      requiredForCompletion: true,
    ),
    ComparisonBlock(
      blockId: 'crypto-what-is-comparison',
      title: 'Three different things, side by side',
      criteria: [
        ComparisonCriterion(id: 'backing', label: 'What backs it'),
        ComparisonCriterion(id: 'protection', label: 'Loss protection'),
        ComparisonCriterion(id: 'value', label: 'Can the value fall'),
      ],
      items: [
        ComparisonItem(
          id: 'crypto',
          name: 'A crypto asset',
          valuesByCriterionId: {
            'backing':
                'Varies by the specific asset; often no company or '
                'government stands behind it.',
            'protection':
                'Generally none of the deposit insurance a bank account '
                'carries.',
            'value': 'Yes, including the possibility of a total loss.',
          },
        ),
        ComparisonItem(
          id: 'stock',
          name: 'A company share',
          valuesByCriterionId: {
            'backing': 'A real company\'s profits and assets.',
            'protection':
                'No deposit insurance; value still moves with the '
                'company and the market.',
            'value': 'Yes, a share can also lose value.',
          },
        ),
        ComparisonItem(
          id: 'deposit',
          name: 'A bank deposit',
          valuesByCriterionId: {
            'backing': 'The bank, and the banking system around it.',
            'protection': 'Deposit insurance, up to a legal limit.',
            'value': 'The peso amount itself does not fall on its own.',
          },
        ),
      ],
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional app shows a crypto asset balance styled exactly like a '
        'peso savings balance. What does this lesson say that tells you?',
    choices: [
      'That the balance carries the same protection as a bank deposit, '
          'since it looks the same',
      'Nothing about protection or risk on its own; the interface is not '
          'what backs the balance',
      'That the app must be registered with a regulator, since it looks '
          'professional',
    ],
    correctIndex: 1,
    explanation:
        'A polished, familiar interface tells you about the app\'s design, '
        'not about what actually backs the balance, who is accountable, or '
        'whether the value can fall. Those questions need their own answer, '
        'not an assumption based on how the screen looks.',
    whyWrong:
        'Looking similar to a savings balance is not the same as carrying '
        'deposit insurance or any other protection; those come from what '
        'the asset actually is, not from its styling.',
  ),
  keyTakeaway:
      'Ask what backs it, not how it looks. A crypto asset is its own '
      'thing, not a share, not a deposit, and not automatically money.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Volatility and Possible Total Loss
// ---------------------------------------------------------------------------

const _volatilityAndPossibleTotalLoss = MoneyLesson(
  id: cryptoRefVolatilityTotalLoss,
  trackId: 'crypto_without_hype',
  title: 'Volatility and Possible Total Loss',
  icon: 'chart',
  minutes: 6,
  summary:
      'Crypto prices can move sharply in either direction, including all '
      'the way to zero. A past increase never predicts another one.',
  objective:
      'Work through what a sharp loss on a fictional amount would actually '
      'look like, in pesos.',
  sections: [],
  governance: _governance,
  sources: [_bspVirtualAssets, _secInvestment101],
  topics: [ContentTopic.cryptocurrency],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Crypto asset prices can change sharply, in either direction, over '
            'a short period of time. That includes the possibility of '
            'losing all of what was put in.',
        'Liquidity, how easily an asset can be turned back into cash at the '
            'price expected, can weaken during a period of market stress. '
            'That is often exactly when someone most wants to sell.',
        'Speculation, putting a large share of money into one thing hoping '
            'for a quick gain, concentration, holding only one kind of '
            'asset, and leverage, using borrowed money to increase the size '
            'of a position, can all make a loss larger than the price move '
            'alone would suggest.',
      ],
    ),
    NuggetsBlock([
      'A previous price increase does not predict another one. Whatever '
          'moved the price up before has no obligation to happen again.',
      'The real question before putting any money toward something this '
          'volatile is whether the amount could be financially absorbed in '
          'full, without disrupting bills, a buffer, or anything else '
          'already relied on.',
    ]),
    RiskWarningBlock(
      title: 'A total loss is a real possibility',
      text:
          'Unlike a savings account, a crypto asset can lose all of its '
          'value. The illustration below is basic arithmetic on a '
          'fictional amount, never a forecast or a claim that any '
          'particular loss is likely.',
    ),
    OfficialSourceBlock(
      agency: _bspVirtualAssetsAgency,
      sourceTitle: _bspVirtualAssetsTitle,
      canonicalUrl: _bspVirtualAssetsUrl,
      lastVerifiedDate: _bspVirtualAssetsVerified,
    ),
    // The worked example this course states in full, matching
    // money/portfolio_shock_illustration.dart's portfolioShockImpact output
    // for 5,000 pesos at a 30 percent loss scenario exactly.
    // test/portfolio_shock_illustration_test.dart proves the function
    // produces these same figures, so this paragraph and that function can
    // never quietly drift apart without a test failing.
    ProseBlock(
      heading: 'How the illustration below works (basic arithmetic only)',
      paragraphs: [
        'Take a fictional amount of 5,000 pesos in a fictional 30 percent '
            'loss scenario, purely as an illustration. The amount lost is '
            '5,000 pesos times 30 percent, which is 1,500 pesos. What '
            'remains is 5,000 pesos minus 1,500 pesos, which is 3,500 '
            'pesos.',
        'The simulator below lets you try this with a different fictional '
            'amount and a different loss scenario. Nothing about it '
            'forecasts what any real asset will do, and none of the three '
            'scenarios offered, 30, 60, or 100 percent, is presented as the '
            'likely outcome.',
      ],
    ),
    _boundary,
  ],
  interactionBlocks: [
    LossImpactSimulatorBlock(
      blockId: 'crypto-loss-impact-simulator',
      simulatorTitle: 'See a sharp loss in pesos',
      introduction:
          'Choose a fictional starting amount and a loss scenario. This is '
          'transparent arithmetic on a made-up number, not a prediction '
          'that any of these scenarios will happen.',
      amountOptions: [
        LossImpactAmountOption(
          id: 'amount-5000',
          amountPhp: 5000,
          label: '₱5,000',
        ),
        LossImpactAmountOption(
          id: 'amount-20000',
          amountPhp: 20000,
          label: '₱20,000',
        ),
        LossImpactAmountOption(
          id: 'amount-50000',
          amountPhp: 50000,
          label: '₱50,000',
        ),
      ],
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-liquidity-stress-scenario',
      scenarioTitle: 'Trying to sell during market stress',
      situation:
          'Say the price of a fictional crypto asset drops sharply, and a '
          'lot of people try to sell at the same time. What is most likely '
          'to happen to someone trying to sell right then?',
      options: [
        ScenarioChoiceOption(
          id: 'quick-expected',
          label: 'The sale happens quickly, at the price expected',
          explanation:
              'Liquidity often weakens exactly during a period of stress, '
              'so this is the less likely outcome, not a safe assumption '
              'to plan around.',
        ),
        ScenarioChoiceOption(
          id: 'delayed-worse-price',
          label:
              'The sale may take longer, or happen at a worse price than '
              'expected',
          explanation:
              'This is the pattern to expect. When many people want out at '
              'once, liquidity can weaken right when it matters most.',
        ),
      ],
      preferredOptionId: 'delayed-worse-price',
      requiredForCompletion: false,
    ),
    MythOrFactBlock(
      blockId: 'crypto-myth-past-increase',
      statement:
          'If a crypto asset\'s price went up a lot last year, it is '
          'likely to go up again this year.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A previous price increase does not predict another one. '
          'Whatever drove the earlier move has no obligation to repeat, '
          'and prices can just as easily move sharply the other way.',
      requiredForCompletion: false,
    ),
    ReflectionPromptBlock(
      blockId: 'crypto-loss-reflect',
      question:
          'If a fictional amount you set aside lost most of its value '
          'overnight, would that disrupt your bills, your buffer, or '
          'anything else you rely on?',
      choices: [
        ReflectionChoice(id: 'yes-disrupt', label: 'Yes, it would'),
        ReflectionChoice(id: 'no-absorb', label: 'No, I could absorb it'),
        ReflectionChoice(id: 'not-sure', label: 'Not sure yet'),
      ],
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional crypto asset rose sharply in value last month. Based '
        'on this lesson, what does that tell you about next month?',
    choices: [
      'It makes another increase next month more likely',
      'It tells you nothing reliable about what happens next',
      'It guarantees the price will keep rising as long as demand stays '
          'high',
    ],
    correctIndex: 1,
    explanation:
        'A previous price move, in either direction, does not predict the '
        'next one. Treating a recent rise as a signal of what is coming is '
        'exactly the assumption this lesson warns against.',
    whyWrong:
        'A past increase is a fact about the past. It carries no built-in '
        'promise about what happens next, however strong the recent move '
        'looked.',
  ),
  keyTakeaway:
      'Before any amount goes toward something this volatile, ask whether '
      'losing all of it could genuinely be absorbed.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Custody and Irreversible Mistakes
// ---------------------------------------------------------------------------

const _custodyAndIrreversibleMistakes = MoneyLesson(
  id: cryptoRefCustodyIrreversibleMistakes,
  trackId: 'crypto_without_hype',
  title: 'Custody and Irreversible Mistakes',
  icon: 'locked',
  minutes: 6,
  summary:
      'A private key or seed phrase can control access to a crypto asset. '
      'Salapify never asks for one, and neither should anyone else.',
  objective:
      'Recognize the difference between custodial and self-custody, and '
      'what makes some mistakes here impossible to undo.',
  sections: [],
  governance: _governance,
  sources: [_bspVirtualAssets],
  topics: [ContentTopic.cryptocurrency],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'On a custodial platform, the platform generally holds and '
            'controls access to the crypto asset on the user\'s behalf, '
            'similar in feel to a bank holding a deposit. With '
            'self-custody, the person holding the asset controls access '
            'directly, and takes on more of the security responsibility '
            'that a platform would otherwise carry.',
        'A private key or a seed phrase, a specific sequence of words, can '
            'control access to a self-custodied crypto asset. Whoever has '
            'that information can generally move the asset, whether or not '
            'they are the rightful owner.',
        'Some crypto transfers are difficult or impossible to reverse once '
            'sent. Sending to the wrong address, or the wrong network, can '
            'result in a permanent loss, with no equivalent of a bank\'s '
            'dispute process to fall back on.',
      ],
    ),
    NuggetsBlock([
      'A lost seed phrase or private key can mean permanent loss of access '
          'to a self-custodied asset. There is often no password reset for '
          'this.',
      'A platform becoming unavailable, an account being compromised, and '
          'a device being lost are three separate risks, not one. Each one '
          'is worth thinking through on its own.',
    ]),
    RiskWarningBlock(
      title: 'Some mistakes here cannot be undone',
      text:
          'A transfer sent to the wrong address, a shared seed phrase, or '
          'a lost private key can each result in a permanent loss with no '
          'way to reverse it. This is different from most everyday banking '
          'mistakes, which usually have some path to a fix.',
      severity: RiskSeverity.caution,
    ),
    OfficialSourceBlock(
      agency: _bspVirtualAssetsAgency,
      sourceTitle: _bspVirtualAssetsTitle,
      canonicalUrl: _bspVirtualAssetsUrl,
      lastVerifiedDate: _bspVirtualAssetsVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    ComparisonBlock(
      blockId: 'crypto-custody-comparison',
      title: 'Custodial versus self-custody',
      criteria: [
        ComparisonCriterion(id: 'holds', label: 'Who holds access'),
        ComparisonCriterion(
          id: 'responsibility',
          label: 'Security responsibility',
        ),
        ComparisonCriterion(id: 'recovery', label: 'If access is lost'),
      ],
      items: [
        ComparisonItem(
          id: 'custodial',
          name: 'Custodial',
          valuesByCriterionId: {
            'holds': 'The platform, on the user\'s behalf.',
            'responsibility':
                'Shared with the platform, similar in feel to a bank '
                'holding a deposit.',
            'recovery':
                'May depend on the platform\'s own account-recovery '
                'process, and on the platform remaining available.',
          },
        ),
        ComparisonItem(
          id: 'self-custody',
          name: 'Self-custody',
          valuesByCriterionId: {
            'holds': 'The individual, directly.',
            'responsibility':
                'Falls mostly on the individual holding the private key '
                'or seed phrase.',
            'recovery':
                'Often has no reset at all; losing the key or seed phrase '
                'can mean permanent loss of access.',
          },
        ),
      ],
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-custody-platform-unavailable',
      scenarioTitle: 'Branching scenario: the platform becomes unavailable',
      situation:
          'A fictional custodial platform suddenly stops responding, with '
          'no notice. What does that mean for a fictional balance held '
          'there?',
      options: [
        ScenarioChoiceOption(
          id: 'always-safe',
          label:
              'The balance is always safe regardless, since it is '
              'recorded on a ledger somewhere',
          explanation:
              'Access to a custodial balance runs through the platform. '
              'If the platform is unavailable, reaching that balance can '
              'be delayed or, in a worst case, may not be possible at all.',
        ),
        ScenarioChoiceOption(
          id: 'access-depends-on-platform',
          label:
              'Access to that balance depends on the platform, so this '
              'is a real risk worth planning for',
          explanation:
              'This is the honest read. Custodial access depends on the '
              'platform staying available and acting correctly, which is '
              'exactly why platform failure is its own separate risk from '
              'a price drop.',
        ),
      ],
      preferredOptionId: 'access-depends-on-platform',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-custody-seed-lost',
      scenarioTitle: 'Branching scenario: the seed phrase is lost',
      situation:
          'A self-custodied fictional asset\'s seed phrase is misplaced, '
          'with no other backup written down anywhere. What happens next?',
      options: [
        ScenarioChoiceOption(
          id: 'support-can-reset',
          label: 'A support team can look it up and reset access',
          explanation:
              'With true self-custody there is usually no company holding '
              'a copy to reset. A lost seed phrase with no backup often '
              'means access is gone for good.',
        ),
        ScenarioChoiceOption(
          id: 'permanent-loss-likely',
          label: 'Access to that asset is very likely permanently lost',
          explanation:
              'This is the realistic outcome. Self-custody trades a '
              'platform\'s reset process for full personal responsibility, '
              'and a lost seed phrase with no backup usually cannot be '
              'undone.',
        ),
      ],
      preferredOptionId: 'permanent-loss-likely',
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-custody-seed-shared',
      scenarioTitle: 'Branching scenario: the seed phrase is shared',
      situation:
          'Someone types their seed phrase into a website that promised to '
          '"verify" their fictional wallet. What is the likely result?',
      options: [
        ScenarioChoiceOption(
          id: 'nothing-happens',
          label:
              'Nothing happens, since the website only checks the '
              'phrase',
          explanation:
              'Never assume this. Whoever receives a seed phrase generally '
              'gains the same access the rightful owner has, and can move '
              'the asset without needing anything else.',
        ),
        ScenarioChoiceOption(
          id: 'access-compromised',
          label:
              'Whoever now has that seed phrase can likely move the '
              'asset',
          explanation:
              'This is the real risk. A seed phrase is not a password '
              'that gets checked and discarded; it is the access itself. '
              'No legitimate verification process needs it.',
        ),
      ],
      preferredOptionId: 'access-compromised',
      requiredForCompletion: false,
      riskNote: RiskWarningBlock(
        title: 'No legitimate process ever asks for this',
        text:
            'Never type, share, provide, or send a seed phrase or private '
            'key to any app, website, message, or person, including '
            'anyone claiming to offer support or verification.',
      ),
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-custody-wrong-address',
      scenarioTitle:
          'Branching scenario: a transfer goes to the wrong '
          'address',
      situation:
          'A fictional transfer is sent to an address with one character '
          'mistyped, or on the wrong network. What is the likely outcome?',
      options: [
        ScenarioChoiceOption(
          id: 'auto-returned',
          label:
              'The transfer is automatically returned once the mistake '
              'is noticed',
          explanation:
              'Many crypto transfers have no automatic return path. Once '
              'sent, a transfer to the wrong address or network can be '
              'difficult or impossible to recover.',
        ),
        ScenarioChoiceOption(
          id: 'may-be-unrecoverable',
          label: 'The transfer may be difficult or impossible to recover',
          explanation:
              'This is the realistic outcome, and exactly why double '
              'checking an address and network before sending matters so '
              'much more here than in most everyday transfers.',
        ),
      ],
      preferredOptionId: 'may-be-unrecoverable',
      requiredForCompletion: false,
    ),
    ChecklistBlock(
      blockId: 'crypto-security-checklist',
      checklistPrompt:
          'A security checklist worth knowing, whichever '
          'custody choice someone makes',
      items: [
        ChecklistItemDef(
          id: 'never-share-secret',
          label:
              'Never type, share, provide, or send a seed phrase, private '
              'key, or password to any app, message, form, or website',
          explanation:
              'No legitimate platform, support agent, or verification '
              'process ever needs this. Salapify never asks for it either.',
        ),
        ChecklistItemDef(
          id: 'verify-address',
          label:
              'Double check the exact address and network before '
              'sending anything',
          explanation:
              'Many transfers cannot be reversed once sent, so this check '
              'happens before, not after.',
        ),
        ChecklistItemDef(
          id: 'know-custody',
          label:
              'Know whether a holding is custodial or self-custody, and '
              'what that means for who is responsible',
          explanation:
              'The two carry very different recovery paths if something '
              'goes wrong.',
        ),
        ChecklistItemDef(
          id: 'separate-risks',
          label:
              'Treat platform failure, account compromise, and device '
              'loss as three separate risks worth thinking through',
          explanation:
              'Each one has a different cause and a different way '
              'to reduce it.',
        ),
      ],
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A message asks someone to type their seed phrase into a form to '
        '"verify" their fictional wallet before a withdrawal. What does '
        'this lesson say about that request?',
    choices: [
      'It is a normal, safe step many legitimate platforms use',
      'No legitimate process needs a seed phrase, and sharing it can hand '
          'over access to the asset',
      'It is only risky if the form is on an unfamiliar-looking website',
    ],
    correctIndex: 1,
    explanation:
        'A seed phrase is not a password that gets checked and thrown '
        'away, it is the access itself. No legitimate verification, '
        'support, or withdrawal process needs it, on any website, familiar '
        'looking or not.',
    whyWrong:
        'The risk is not about how professional the website looks. The '
        'request itself, for a seed phrase, is the warning sign, '
        'regardless of how the page is designed.',
  ),
  keyTakeaway:
      'A seed phrase or private key is access itself. Nothing legitimate '
      'ever needs it typed in anywhere, including here.',
);

// ---------------------------------------------------------------------------
// Lesson 4: Stablecoins, Yield and Leverage
// ---------------------------------------------------------------------------

const _stablecoinsYieldAndLeverage = MoneyLesson(
  id: cryptoRefStablecoinsYieldLeverage,
  trackId: 'crypto_without_hype',
  title: 'Stablecoins, Yield and Leverage',
  icon: 'percent',
  minutes: 6,
  summary:
      'A stablecoin can still fail. Advertised yield is not bank interest. '
      'Leverage can turn a normal-sized loss into a much bigger one.',
  objective:
      'Explain why a stablecoin, an advertised yield, and leverage each '
      'carry risks a savings account does not.',
  sections: [],
  governance: _governance,
  sources: [_bspVirtualAssets, _secInvestment101],
  topics: [ContentTopic.cryptocurrency],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'A stablecoin is a type of crypto asset that attempts to hold a '
            'steady reference value, often tied to a currency. Attempting '
            'to hold a steady value is not the same as always succeeding: '
            'a stablecoin can still lose its peg or fail outright, and it '
            'is not automatically covered by the deposit insurance a bank '
            'account carries.',
        'An advertised yield on a crypto product is not the same thing as '
            'guaranteed bank interest. It can carry counterparty risk (the '
            'other party fails to pay), liquidity risk (money cannot be '
            'accessed when needed), smart-contract risk (the underlying '
            'code behaves unexpectedly), market risk, and platform risk, '
            'all at once.',
        'Leverage means using borrowed money to make a position bigger '
            'than the cash put in. It can magnify a gain, and it can just '
            'as easily magnify a loss, including triggering a forced sale, '
            'often called liquidation, if the value moves too far against '
            'the position.',
      ],
    ),
    NuggetsBlock([
      'A higher advertised return is a reason to investigate more closely, '
          'not less. Extra reward almost always comes with extra risk '
          'sitting somewhere.',
      'Being unable to withdraw quickly, or a platform pausing '
          'withdrawals, is itself a form of risk, separate from whatever '
          'the price is doing.',
    ]),
    RiskWarningBlock(
      title: 'A stablecoin is not automatically insured',
      text:
          'A stablecoin attempting to hold a steady value is not the same '
          'as a bank deposit protected by deposit insurance. It can still '
          'lose its peg or fail.',
    ),
    // Both sources rendered inline, not just SEC's general Investment 101
    // page: an investment-literacy-reviewer pass flagged that Investment
    // 101 alone is general investor education, not a confirmed match for
    // this lesson's specific claims (stablecoin de-pegging, the five-part
    // counterparty/liquidity/smart-contract/market/platform risk taxonomy,
    // leverage and liquidation). BSP's Virtual Assets page is the more
    // plausible source for crypto-specific risk content and was already
    // listed in this lesson's `sources` metadata but not rendered before
    // this fix.
    OfficialSourceBlock(
      agency: _bspVirtualAssetsAgency,
      sourceTitle: _bspVirtualAssetsTitle,
      canonicalUrl: _bspVirtualAssetsUrl,
      lastVerifiedDate: _bspVirtualAssetsVerified,
    ),
    OfficialSourceBlock(
      agency: _secInvestment101Agency,
      sourceTitle: _secInvestment101Title,
      canonicalUrl: _secInvestment101Url,
      lastVerifiedDate: _secInvestment101Verified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    MythOrFactBlock(
      blockId: 'crypto-stablecoin-myth',
      statement:
          'A stablecoin is covered by the same deposit insurance as a peso '
          'savings account, since it is designed to hold a steady value.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Attempting to hold a steady value is a design goal, not a '
          'guarantee, and it is not the same as deposit insurance. A '
          'stablecoin can still lose its peg or fail.',
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'crypto-yield-risk-matching',
      categorizePrompt:
          'Match each short description to the kind of risk it describes.',
      buckets: [
        CategorizeBucket(id: 'counterparty', label: 'Counterparty risk'),
        CategorizeBucket(id: 'liquidity', label: 'Liquidity risk'),
        CategorizeBucket(id: 'smart-contract', label: 'Smart-contract risk'),
        CategorizeBucket(id: 'platform', label: 'Platform risk'),
      ],
      items: [
        CategorizeItemDef(
          id: 'counterparty-fails',
          label:
              'The party on the other side of a yield arrangement is '
              'unable to pay what was promised',
          explanation:
              'This is counterparty risk: the other side of the '
              'arrangement failing to deliver.',
        ),
        CategorizeItemDef(
          id: 'cannot-withdraw',
          label:
              'Money cannot be withdrawn when needed, even though the '
              'balance still shows on screen',
          explanation:
              'This is liquidity risk: the balance existing on screen is '
              'not the same as being able to access it.',
        ),
        CategorizeItemDef(
          id: 'code-behaves-unexpectedly',
          label:
              'The automated code running a yield product behaves in a '
              'way nobody anticipated',
          explanation:
              'This is smart-contract risk: the code itself, not '
              'the market, is the source of the problem.',
        ),
        CategorizeItemDef(
          id: 'platform-pauses',
          label:
              'The platform offering the yield pauses operations or '
              'shuts down',
          explanation:
              'This is platform risk: the business running the '
              'product itself failing or stopping.',
        ),
      ],
      correctBucketByItemId: {
        'counterparty-fails': 'counterparty',
        'cannot-withdraw': 'liquidity',
        'code-behaves-unexpectedly': 'smart-contract',
        'platform-pauses': 'platform',
      },
      requiredForCompletion: true,
    ),
    ComparisonBlock(
      blockId: 'crypto-yield-offer-comparison',
      title: 'A fictional yield offer, next to a bank savings account',
      criteria: [
        ComparisonCriterion(id: 'protection', label: 'Protection if it fails'),
        ComparisonCriterion(id: 'return-basis', label: 'What backs the return'),
        ComparisonCriterion(id: 'access', label: 'Access to the money'),
      ],
      items: [
        ComparisonItem(
          id: 'bank-savings',
          name: 'A bank savings account',
          valuesByCriterionId: {
            'protection': 'Deposit insurance, up to a legal limit.',
            'return-basis': 'A published, modest interest rate.',
            'access': 'Generally available on demand.',
          },
        ),
        ComparisonItem(
          id: 'fictional-yield-offer',
          name: 'A fictional crypto yield offer',
          valuesByCriterionId: {
            'protection':
                'Generally none of the deposit insurance a bank '
                'account carries.',
            'return-basis':
                'An advertised rate that depends on the '
                'platform, counterparty, and market conditions holding up.',
            'access':
                'May be restricted, delayed, or paused depending on '
                'the platform\'s own terms.',
          },
        ),
      ],
      requiredForCompletion: false,
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-leverage-scenario',
      scenarioTitle: 'A leveraged position moves the wrong way',
      situation:
          'Someone uses borrowed money to make a fictional crypto position '
          'larger than the cash they put in. The price then moves against '
          'them. What can happen?',
      options: [
        ScenarioChoiceOption(
          id: 'loss-capped',
          label:
              'The loss stays capped at the cash originally put in, no '
              'matter what',
          explanation:
              'Leverage can make a loss larger than the amount put in, and '
              'can trigger a forced sale, often called liquidation, before '
              'the position has any chance to recover.',
        ),
        ScenarioChoiceOption(
          id: 'forced-liquidation-possible',
          label:
              'A forced sale of the position, a liquidation, becomes '
              'possible',
          explanation:
              'This is the real risk leverage adds. A price move that '
              'would be manageable without borrowed money can trigger a '
              'forced sale with leverage involved.',
        ),
      ],
      preferredOptionId: 'forced-liquidation-possible',
      requiredForCompletion: false,
      riskNote: RiskWarningBlock(
        title: 'Leverage magnifies losses, not only gains',
        text:
            'This is a concept, not a how-to. This course does not teach '
            'how to open a leveraged position.',
      ),
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional platform advertises a much higher yield than a bank '
        'savings account pays. What does this lesson say that should '
        'prompt?',
    choices: [
      'Less scrutiny, since a higher number is simply a better deal',
      'More investigation into what backs that return and what could go '
          'wrong',
      'Nothing extra, since any published rate can be trusted the same way',
    ],
    correctIndex: 1,
    explanation:
        'A higher advertised return is a reason to look closer, not less '
        'closely. The extra reward is coming from somewhere, and that '
        'somewhere is usually extra risk: counterparty, liquidity, '
        'smart-contract, market, or platform.',
    whyWrong:
        'An advertised rate and a bank\'s published interest rate are not '
        'backed the same way, so they do not deserve the same level of '
        'trust by default.',
  ),
  keyTakeaway:
      'A steady-looking value, an attractive yield, and borrowed money can '
      'each hide risk a plain savings account does not carry.',
);

// ---------------------------------------------------------------------------
// Lesson 5: Scams and Provider Verification
// ---------------------------------------------------------------------------

const _scamsAndProviderVerification = MoneyLesson(
  id: cryptoRefScamsProviderVerification,
  trackId: 'crypto_without_hype',
  title: 'Scams and Provider Verification',
  icon: 'search',
  minutes: 6,
  summary:
      'A claim that returns are guaranteed, urgent pressure, and requests '
      'for a seed phrase are warning signs. Checking a provider takes one '
      'real step.',
  objective:
      'Spot common crypto scam patterns and verify a provider through a '
      'current official source, not a screenshot.',
  sections: [],
  governance: _governance,
  sources: [_bspVerifier, _secPh],
  topics: [ContentTopic.cryptocurrency],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Crypto scams reuse a small set of patterns again and again: a '
            'claim that returns are guaranteed, a giveaway that asks for a '
            'payment first, '
            'someone impersonating a real person or company, a message '
            'trying to steal login details, a stranger building trust '
            'before asking for money, an offer to "recover" money already '
            'lost, pressure to act immediately, a request for credentials '
            'or a seed phrase, fake customer support, recruitment that '
            'pays for bringing in more people, and screenshots offered as '
            'proof of profit.',
        'Checking whether a provider is registered is one real, verifiable '
            'step, and it should be done through a current official '
            'source, never through a screenshot, a link in a message, or '
            'the app\'s own claims about itself.',
        'Registration does not guarantee investment safety or '
            'profitability, and a provider\'s status can change over '
            'time. Checking the exact legal entity name, not only the app '
            'or brand name, matters because a scam can borrow a real '
            'brand\'s look without being that brand at all.',
      ],
    ),
    NuggetsBlock([
      'Urgency is a tactic. A legitimate opportunity does not usually '
          'disappear if someone takes a day to check it first.',
      'Suspicious activity can be reported through official channels; a '
          'private message or a comment thread is not that channel.',
    ]),
    RiskWarningBlock(
      title: 'Registration is not a safety guarantee',
      text:
          'A provider being registered somewhere does not guarantee '
          'investment safety or profitability, and a provider\'s status '
          'can change. Checking is still worthwhile, it just is not the '
          'end of the thinking.',
    ),
    OfficialSourceBlock(
      agency: _bspVerifierAgency,
      sourceTitle: _bspVerifierTitle,
      canonicalUrl: _bspVerifierUrl,
      lastVerifiedDate: _bspVerifierVerified,
    ),
    OfficialSourceBlock(
      agency: _secPhAgency,
      sourceTitle: _secPhTitle,
      canonicalUrl: _secPhUrl,
      lastVerifiedDate: _secPhVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    CategorizeBlock(
      blockId: 'crypto-scam-red-flag-challenge',
      categorizePrompt:
          'Sort each fictional message or situation into where it belongs.',
      buckets: [
        CategorizeBucket(id: 'red-flag', label: 'Red flag'),
        CategorizeBucket(id: 'reasonable', label: 'Reasonable'),
      ],
      items: [
        CategorizeItemDef(
          id: 'guaranteed-double',
          label: 'A message promises your money will double within a week',
          explanation:
              'A claim that returns are guaranteed, especially a fast and '
              'specific one, is one of the clearest warning signs there '
              'is.',
        ),
        CategorizeItemDef(
          id: 'urgent-today-only',
          label:
              'A message says the offer disappears if you do not act '
              'today',
          explanation:
              'Manufactured urgency is a pressure tactic, meant to stop '
              'someone from checking before acting.',
        ),
        CategorizeItemDef(
          id: 'pin-over-phone',
          label:
              'Someone claiming to be support asks you to read your '
              'one-time PIN over the phone',
          explanation:
              'No legitimate support process needs a one-time PIN read '
              'aloud. This is a credential-theft attempt.',
        ),
        CategorizeItemDef(
          id: 'stranger-trust-building',
          label:
              'A new online contact spends weeks building a friendship '
              'before mentioning an investment opportunity',
          explanation:
              'This is the pattern behind a trust-building or romance '
              'scam: the relationship exists to set up the ask.',
        ),
        CategorizeItemDef(
          id: 'checked-official-source',
          label:
              'Before sending any money, someone checks a provider\'s '
              'registration through a current official source',
          explanation:
              'This is exactly the reasonable, verifiable step this '
              'lesson recommends.',
        ),
        CategorizeItemDef(
          id: 'takes-a-day-to-decide',
          label:
              'Someone takes a day to think an offer over before '
              'responding',
          explanation:
              'Taking time to think is reasonable. A legitimate '
              'opportunity does not usually need to be decided in minutes.',
        ),
      ],
      correctBucketByItemId: {
        'guaranteed-double': 'red-flag',
        'urgent-today-only': 'red-flag',
        'pin-over-phone': 'red-flag',
        'stranger-trust-building': 'red-flag',
        'checked-official-source': 'reasonable',
        'takes-a-day-to-decide': 'reasonable',
      },
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-fake-support-scenario',
      scenarioTitle: 'A fake-support message',
      situation:
          'Someone claiming to be from a crypto platform\'s support team '
          'messages directly, saying your fictional account needs to be '
          '"verified" by confirming your seed phrase. What is the correct '
          'response?',
      options: [
        ScenarioChoiceOption(
          id: 'send-seed-phrase',
          label:
              'Send the seed phrase, since it is only used to verify '
              'the account',
          explanation:
              'Never do this. A seed phrase is access itself. No '
              'legitimate support process anywhere needs it, over chat, '
              'phone, or any other channel.',
        ),
        ScenarioChoiceOption(
          id: 'refuse-and-verify-through-app',
          label:
              'Refuse, and if there is a real concern, check it through '
              'the platform\'s own official app or website directly',
          explanation:
              'This is the safe response. Legitimate support never needs a '
              'seed phrase, and going through the platform\'s own official '
              'channel, not the messenger\'s link, is how a real concern '
              'gets checked safely.',
        ),
      ],
      preferredOptionId: 'refuse-and-verify-through-app',
      requiredForCompletion: true,
      riskNote: RiskWarningBlock(
        title: 'This request alone is the warning sign',
        text:
            'No legitimate support, verification, or recovery process ever '
            'needs a seed phrase, a private key, a password, or a '
            'one-time code read aloud.',
      ),
    ),
    ScenarioChoiceBlock(
      blockId: 'crypto-recovery-scam-scenario',
      scenarioTitle: '"What would you do?": a recovery offer',
      situation:
          'After losing money to a fictional scam, someone messages '
          'offering to "recover" it for an upfront fee. What is the '
          'likely situation?',
      options: [
        ScenarioChoiceOption(
          id: 'pay-the-fee',
          label: 'Pay the fee, since recovery services do exist',
          explanation:
              'An unsolicited offer to recover lost funds for an upfront '
              'fee is itself a common follow-on scam, targeting someone '
              'already hurt and hoping to make it right quickly.',
        ),
        ScenarioChoiceOption(
          id: 'treat-as-second-scam',
          label:
              'Treat it as a likely second scam, and report it through '
              'official channels instead',
          explanation:
              'This is the safer read. An unsolicited "recovery" offer '
              'that asks for money upfront reuses the exact same pressure '
              'tactics as the original scam.',
        ),
      ],
      preferredOptionId: 'treat-as-second-scam',
      requiredForCompletion: false,
    ),
    ChecklistBlock(
      blockId: 'crypto-provider-verification-checklist',
      checklistPrompt: 'Provider-verification checklist',
      items: [
        ChecklistItemDef(
          id: 'checked-current-official-source',
          label:
              'Checked the provider\'s registration through a current '
              'official source, not a screenshot or a link in a message',
          explanation:
              'This is the one verifiable step available. The BSP '
              'Verifier and current SEC resources are the places to check.',
        ),
        ChecklistItemDef(
          id: 'checked-legal-entity',
          label:
              'Confirmed the exact legal entity name, not only the app or '
              'brand name shown on screen',
          explanation:
              'A scam can copy a real brand\'s look without being '
              'registered as that entity at all.',
        ),
        ChecklistItemDef(
          id: 'noted-not-a-guarantee',
          label:
              'Noted that registration does not guarantee investment '
              'safety or profitability',
          explanation:
              'Registration is a real check worth doing, but it is not '
              'the whole answer to whether something is safe.',
        ),
        ChecklistItemDef(
          id: 'checked-status-current',
          label:
              'Checked that the registration status is current, since it '
              'can change over time',
          explanation:
              'A status checked months ago may no longer be accurate '
              'today.',
        ),
      ],
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A message shows a screenshot claiming a provider is officially '
        'registered. Based on this lesson, what is the correct next step?',
    choices: [
      'Trust the screenshot, since it clearly shows a registration notice',
      'Check the provider\'s exact legal entity name through a current '
          'official source directly',
      'Ask the sender for a second screenshot to confirm the first one',
    ],
    correctIndex: 1,
    explanation:
        'A screenshot can be faked or outdated in a way a live official '
        'source cannot. Checking the exact legal entity name through a '
        'current official source is the one step that actually verifies '
        'anything.',
    whyWrong:
        'A second screenshot has exactly the same weakness as the first '
        'one: it comes from the sender, not from an official source.',
  ),
  keyTakeaway:
      'A claim that returns are guaranteed, urgency, and a request for a '
      'seed phrase are warning signs. Checking a provider through an '
      'official source is the one real step that helps.',
);

// ---------------------------------------------------------------------------
// Lesson 6: The Crypto Decision Lab
// ---------------------------------------------------------------------------

const _theCryptoDecisionLab = MoneyLesson(
  id: cryptoRefDecisionLab,
  trackId: 'crypto_without_hype',
  title: 'The Crypto Decision Lab',
  icon: 'checklist',
  minutes: 7,
  summary:
      'A private checklist pulling this course together. A review, never '
      'a result, and never a recommendation to buy anything.',
  objective:
      'Work through every area this course covered, honestly, before any '
      'money moves toward a crypto asset.',
  sections: [],
  governance: _governance,
  sources: [_bspVirtualAssets, _secInvestment101],
  topics: [ContentTopic.cryptocurrency],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'This checklist pulls together everything this course covered, in '
            'one place. It is a private review for your own use, never a '
            'result, a score, or a green light, and it never recommends '
            'buying anything.',
      ],
    ),
    RiskWarningBlock(
      title: 'This is not advice or an approval',
      text:
          'The checklist below only reflects what is checked right now. It '
          'is not personalized financial advice, it does not mean any '
          'crypto asset is or is not suitable, and it never labels anyone '
          'ready, approved, qualified, or safe to invest.',
    ),
    OfficialSourceBlock(
      agency: _bspVirtualAssetsAgency,
      sourceTitle: _bspVirtualAssetsTitle,
      canonicalUrl: _bspVirtualAssetsUrl,
      lastVerifiedDate: _bspVirtualAssetsVerified,
    ),
    OfficialSourceBlock(
      agency: _secInvestment101Agency,
      sourceTitle: _secInvestment101Title,
      canonicalUrl: _secInvestment101Url,
      lastVerifiedDate: _secInvestment101Verified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    RiskReviewChecklistBlock(
      blockId: 'crypto-decision-lab-checklist',
      checklistPrompt: 'Review before any money moves toward a crypto asset',
      foundationCount: 5,
      items: [
        ChecklistItemDef(
          id: 'financial-foundation-reviewed',
          label: 'Financial foundation reviewed',
          explanation:
              'The overall picture, bills, buffer, and debt, has '
              'been looked at as a whole.',
        ),
        ChecklistItemDef(
          id: 'essential-bills-protected',
          label: 'Essential bills protected',
          explanation:
              'Rent, utilities, food, and minimum debt payments '
              'are reliably covered first.',
        ),
        ChecklistItemDef(
          id: 'emergency-buffer-considered',
          label: 'Emergency buffer considered',
          explanation:
              'Whether a buffer exists, and how funded it is, has '
              'been thought through.',
        ),
        ChecklistItemDef(
          id: 'expensive-debt-reviewed',
          label: 'Expensive debt reviewed',
          explanation:
              'Any high-interest debt has been looked at and its cost '
              'understood.',
        ),
        ChecklistItemDef(
          id: 'money-not-borrowed',
          label: 'Money is not borrowed',
          explanation:
              'The amount under consideration is not money taken '
              'on credit or borrowed from someone else.',
        ),
        ChecklistItemDef(
          id: 'understands-total-loss',
          label: 'Understands possible total loss',
          explanation:
              'A crypto asset can lose all of its value, not just some of '
              'it.',
        ),
        ChecklistItemDef(
          id: 'understands-custody-choice',
          label: 'Understands custody choice',
          explanation:
              'Custodial and self-custody carry different responsibilities '
              'and different recovery paths if something goes wrong.',
        ),
        ChecklistItemDef(
          id: 'provider-status-checked',
          label: 'Provider status checked',
          explanation:
              'Any specific provider has been checked through a current '
              'official source, not a screenshot or a claim.',
        ),
        ChecklistItemDef(
          id: 'no-pressure-or-guarantee',
          label: 'No pressure or guaranteed-return claim involved',
          explanation:
              'Nobody is rushing this decision, and nothing promises a '
              'guaranteed outcome.',
        ),
        ChecklistItemDef(
          id: 'amount-within-affordable-loss',
          label:
              'Amount is within what you say you could afford to '
              'financially lose',
          explanation:
              'Only you can answer this. It should be an amount whose '
              'complete loss would not disrupt your life.',
        ),
      ],
      foundationSummary: 'Review your financial foundation first',
      partialSummary: 'Several risks still need checking',
      completeSummary: 'You have completed a risk review',
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'crypto-salapify-actions',
      menuPrompt: 'A few real, safe things to do next, if any of them fit',
      actions: [
        SalapifyActionDef(
          id: 'review-emergency-fund',
          label: 'Review or create an Emergency Fund goal',
          description:
              'Opens Goals to check an Emergency Fund goal, or start one '
              'from a template. Nothing is created or changed until '
              'something is saved there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-debt',
          label: 'Review debt',
          description:
              'Opens Debts to see what is owed and the payoff plan. '
              'Nothing changes automatically.',
          route: 'debts',
        ),
        SalapifyActionDef(
          id: 'review-budget',
          label: 'Review budget',
          description:
              'Opens Budget to check what is already spoken for this '
              'period. Nothing changes automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'open-money-mindset',
          label: 'Open Money Mindset before acting on any crypto offer',
          description:
              'Opens Money Mindset for a moment to think something '
              'through before acting. Nothing is created or changed there '
              'automatically.',
          route: 'mindset',
        ),
        SalapifyActionDef(
          id: 'create-learning-goal',
          label: 'Create a goal for something you are learning about',
          description:
              'Opens Goals to set up your own goal, in your own words, if '
              'you want one. Nothing is created automatically, and this '
              'never creates a crypto holding.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-accounts',
          label: 'Review your accounts',
          description:
              'Opens Accounts to see what you already track. If you '
              'already hold something and want to record it yourself, you '
              'can do that there by hand. Nothing is imported or created '
              'automatically, and no outside app or platform is ever '
              'linked.',
          route: 'accounts',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A finished checklist shows every foundation item checked, but '
        'provider status is still unchecked and the amount has not been '
        'confirmed as affordable to lose. What does that suggest?',
    choices: [
      'That crypto is not allowed at all',
      'Those two areas are worth checking before any money moves, nothing '
          'more, nothing less',
      'That the checklist has already approved the decision',
    ],
    correctIndex: 1,
    explanation:
        'This checklist never blocks anything and never approves anything. '
        'It names specifically what is still unchecked, so the areas worth '
        'looking at before any money moves are clear.',
    whyWrong:
        'Nothing here is a rule, a lock, or an approval. Naming what is '
        'unchecked gives something concrete to review, not a verdict.',
  ),
  keyTakeaway:
      'This checklist is a mirror, not a green light. Use it to see '
      'clearly, then decide for yourself, on your own terms and timeline.',
);
