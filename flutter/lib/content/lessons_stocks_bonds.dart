// Money Courses Phase 7A: the "Grow Your Money" learning path's second
// course, "Stocks and Bonds Without the Hype" (course id
// 'stocks_and_bonds'). Builds on the completed Investing Readiness pilot
// (lessons_grow.dart) without modifying it or the core 22 lessons in
// lessons.dart: separate content file, separate lesson ids, same
// architecture already shipped by Phase 2 to 6 (governance metadata,
// official-source and risk-warning blocks, Phase 5 interaction blocks).
//
// House rules, same as lessons_grow.dart: plain English, Philippine peso
// examples, no em or en dashes, no named stock, bond, fund, broker, or
// provider anywhere in this file, no guaranteed-outcome or risk-free
// language, no personalized recommendation, no active broker list or
// government-bond offering (only links to the current official directory
// or notice). Every fictional company is invented for this course and
// never reused as a real product name.
//
// Content topics are set (ContentTopic.stocks and/or ContentTopic.bonds)
// on every lesson here, unlike the pilot's deliberate choice to leave
// topics empty. This course actually teaches stock and bond mechanics, so
// treating it as "regulated" under money/expansion_content_policy.dart's
// own definition is the more honest classification: it activates the
// Phase 4 validator's mandatory official-source, risk-warning, and
// educational-boundary checks instead of relying only on this file's own
// content test to enforce them by hand.
//
// Sources: the Philippine Stock Exchange (PSE Academy and pse.com.ph's own
// Investing at PSE and trading-participant directory pages), the
// Securities and Exchange Commission Philippines' Investment 101, and the
// Bureau of the Treasury (its FiLi investor-education page and its own
// site), plus the Philippine Deposit Insurance Corporation's maximum
// deposit insurance coverage page for the deposit-insurance boundary in
// lessons 1 and 5. Several of these sites block automated fetches, the
// same limitation lessons_grow.dart's own header notes; the general,
// evergreen facts cited here (the ownership/lending distinction, that a
// fixed coupon does not fix a bond's resale price, that deposit insurance
// does not extend to a bond merely because a bank distributes it, and the
// standard verify-before-you-invest checks) were confirmed through the
// task's own official-source list and each agency's published description
// rather than invented, and were reviewed by the investment-literacy-
// reviewer agent before this course shipped (see governance.reviewerId
// below).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

// Plain string constants, not fields on a shared object: see
// lessons_grow.dart's own comment on why a const OfficialSourceBlock call
// needs these as top-level identifiers rather than reading them off a
// const LessonSourceInfo instance's field.
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

const _pseInvestingAgency = 'Philippine Stock Exchange (PSE)';
const _pseInvestingTitle = 'Investing at PSE';
const _pseInvestingUrl = 'https://www.pse.com.ph/investing-at-pse/';
const _pseInvestingVerified = '2026-08';

const _pseInvesting = LessonSourceInfo(
  agency: _pseInvestingAgency,
  title: _pseInvestingTitle,
  canonicalUrl: _pseInvestingUrl,
  lastVerifiedDate: _pseInvestingVerified,
);

const _pseDirectoryAgency = 'Philippine Stock Exchange (PSE)';
const _pseDirectoryTitle = 'Trading Participant Directory';
const _pseDirectoryUrl = 'https://www.pse.com.ph/directory/';
const _pseDirectoryVerified = '2026-08';

const _pseDirectory = LessonSourceInfo(
  agency: _pseDirectoryAgency,
  title: _pseDirectoryTitle,
  canonicalUrl: _pseDirectoryUrl,
  lastVerifiedDate: _pseDirectoryVerified,
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

const _btrFiliAgency = 'Bureau of the Treasury';
const _btrFiliTitle = 'FiLi, Investor Education';
const _btrFiliUrl = 'https://filiapp.treasury.gov.ph/investor_education.html';
const _btrFiliVerified = '2026-08';

const _btrFili = LessonSourceInfo(
  agency: _btrFiliAgency,
  title: _btrFiliTitle,
  canonicalUrl: _btrFiliUrl,
  lastVerifiedDate: _btrFiliVerified,
);

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

const _pdicAgency = 'Philippine Deposit Insurance Corporation (PDIC)';
const _pdicTitle = 'Maximum Deposit Insurance Coverage';
const _pdicUrl = 'https://www.pdic.gov.ph/MDIC';
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
      'PSE, the Securities and Exchange Commission, and the Bureau of the '
      'Treasury',
  examplesAreFictional: true,
);

/// Lesson ids, stable and free-form, same convention as lessons_grow.dart's
/// own ids. Never reused for a different lesson once a learner has real
/// progress recorded against one (see money/expansion_progress.dart).
const sbOwnerOrLender = 'sb-owner-or-lender';
const sbStockReturnsAndLosses = 'sb-stock-returns-losses';
const sbPriceIsNotValue = 'sb-price-is-not-value';
const sbDiversificationAndConcentration = 'sb-diversification-concentration';
const sbHowBondsWork = 'sb-how-bonds-work';
const sbVerifyBeforeYouInvest = 'sb-verify-before-you-invest';

/// The six lessons, in reading order. Never added to lessons.dart's flat
/// `lessons` list, and never merged into growYourMoneyLessons: see
/// test/lessons_stocks_bonds_content_test.dart's own isolation checks.
const List<MoneyLesson> stocksAndBondsLessons = [
  _ownerOrLender,
  _stockReturnsAndLosses,
  _priceIsNotValue,
  _diversificationAndConcentration,
  _howBondsWork,
  _verifyBeforeYouInvest,
];

// ---------------------------------------------------------------------------
// Lesson 1: Owner or Lender?
// ---------------------------------------------------------------------------

const _ownerOrLender = MoneyLesson(
  id: sbOwnerOrLender,
  trackId: 'stocks_and_bonds',
  title: 'Owner or Lender?',
  icon: 'balance',
  minutes: 5,
  summary:
      'A stock generally makes you a part owner. A bond generally makes you '
      'a lender. A bank deposit is a different thing again.',
  objective:
      'Tell apart owning, lending, and depositing before looking at any '
      'product.',
  sections: [],
  governance: _governance,
  sources: [_pseAcademy, _secInvestment101, _pdic],
  topics: [ContentTopic.stocks, ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Owning, lending, or depositing',
      paragraphs: [
        'An officemate says they put money in the market, and you nod '
            'without knowing what they actually hold. A share of common '
            'stock generally makes you a part owner of a company. As an '
            'owner, you may benefit if the company does well, and you share '
            'in the risk if it does not. Nothing about owning a share '
            'promises a fixed payment.',
        'A bond generally works differently. Buying a bond generally means '
            'lending money to whoever issued it, a government or a '
            'company, in exchange for a promise to pay the money back '
            'later, usually with regular interest payments along the way. '
            'A bond is a loan you made, not a piece of the business you '
            'own.',
        'A bank deposit is different from both. Money in a regular deposit '
            'account is a claim against the bank itself, and many deposit '
            'accounts in the Philippines are covered by deposit insurance '
            'up to a set limit. A stock and a bond are not deposits, and '
            'that same deposit insurance does not automatically extend to '
            'them.',
      ],
    ),
    NuggetsBlock([
      'Owner, a stock: shares in the ups and downs of a company, with no '
          'fixed payment promised.',
      'Lender, a bond: generally has a defined repayment and interest '
          'schedule, but still depends on the issuer being able to pay.',
      'Depositor, a bank account: a different legal relationship again, '
          'with its own separate protections that do not extend to stocks '
          'or bonds.',
    ]),
    RiskWarningBlock(
      title: 'Ownership and lending carry different risks',
      text:
          'A stock can lose part or all of its value, with no promise of '
          'getting the money back. A bond depends on the issuer being able '
          'and willing to pay, so it can lose value too, especially if the '
          'issuer runs into trouble. Neither is the same as a bank '
          'deposit.',
    ),
    OfficialSourceBlock(
      agency: _pseAcademyAgency,
      sourceTitle: _pseAcademyTitle,
      canonicalUrl: _pseAcademyUrl,
      lastVerifiedDate: _pseAcademyVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
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
      blockId: 'owner-lender-depositor-sort',
      categorizePrompt:
          'Sort each fictional example into the group it '
          'belongs in.',
      buckets: [
        CategorizeBucket(id: 'owner', label: 'Owner'),
        CategorizeBucket(id: 'lender', label: 'Lender'),
        CategorizeBucket(id: 'depositor', label: 'Depositor'),
      ],
      items: [
        CategorizeItemDef(
          id: 'shares',
          label:
              'Buying shares in a fictional company we will call Example '
              'Snack Co.',
          explanation:
              'Buying shares generally makes you a part owner of the '
              'company, sharing in its ups and downs.',
        ),
        CategorizeItemDef(
          id: 'gov-bond',
          label: 'Buying a 5-year government bond',
          explanation:
              'A government bond is generally a loan to the government, '
              'repaid with interest over time.',
        ),
        CategorizeItemDef(
          id: 'savings-account',
          label: 'Putting money into a bank\'s regular savings account',
          explanation:
              'A savings account is a deposit relationship with the bank, '
              'with its own separate protections.',
        ),
        CategorizeItemDef(
          id: 'corp-bond',
          label: 'Buying a corporate bond issued by a delivery company',
          explanation:
              'A corporate bond is generally a loan to that company, not a '
              'share of its ownership.',
        ),
      ],
      correctBucketByItemId: {
        'shares': 'owner',
        'gov-bond': 'lender',
        'savings-account': 'depositor',
        'corp-bond': 'lender',
      },
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'deposit-vs-bond-myth',
      statement:
          'A bank deposit and a government bond are basically the same '
          'thing, since both are generally seen as safe.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'They are different relationships. A deposit account and its '
          'protections are specific to banks. A government bond is a loan '
          'to the government, and while it may carry lower credit risk '
          'than many other borrowers, it is a different structure with its '
          'own risks, including that its market value before maturity can '
          'move up or down.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'friend-mixes-it-up',
      scenarioTitle: 'A friend mixes it up',
      situation:
          'A fictional friend says, "Stocks and bonds are basically the '
          'same thing, they are both just investments." What is the '
          'clearest way to respond, based on this lesson?',
      options: [
        ScenarioChoiceOption(
          id: 'explain-difference',
          label:
              'Explain that a stock generally makes you an owner, while a '
              'bond generally makes you a lender, and those come with '
              'different risks',
          explanation:
              'This names the real distinction. Ownership and lending are '
              'different relationships with different risks, even though '
              'both are commonly grouped under the word investing.',
        ),
        ScenarioChoiceOption(
          id: 'agree',
          label: 'Agree, since they are both ways to try to grow money',
          explanation:
              'They can both be part of growing money over time, but '
              'treating them as interchangeable skips over a real '
              'difference in what each one actually is and what risk it '
              'carries.',
        ),
      ],
      preferredOptionId: 'explain-difference',
      requiredForCompletion: false,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional company issues a bond. What does buying that bond '
        'generally make you?',
    choices: [
      'An owner of part of the company',
      'A lender to the company',
      'A depositor at the company',
    ],
    correctIndex: 1,
    explanation:
        'Buying a bond is generally a loan to whoever issued it. The '
        'company promises to pay the money back, usually with interest, '
        'rather than giving up a share of ownership.',
    whyWrong:
        'Ownership generally comes from buying shares, not from buying a '
        'bond. A bond is a loan, not a piece of the company.',
  ),
  keyTakeaway:
      'Before anything else, know whether you would be becoming an owner, '
      'a lender, or a depositor, since each is a different relationship '
      'with different risks.',
);

// ---------------------------------------------------------------------------
// Lesson 2: How Stock Returns and Losses Happen
// ---------------------------------------------------------------------------

const _stockReturnsAndLosses = MoneyLesson(
  id: sbStockReturnsAndLosses,
  trackId: 'stocks_and_bonds',
  title: 'How Stock Returns and Losses Happen',
  icon: 'chart',
  minutes: 5,
  summary:
      'Share prices move up and down, dividends are never guaranteed, and a '
      'low peso price does not automatically mean a stock is cheap.',
  objective:
      'Explain how a stock can gain or lose value, and why price alone '
      'does not tell the whole story.',
  sections: [],
  governance: _governance,
  sources: [_pseAcademy, _pseInvesting],
  topics: [ContentTopic.stocks, ContentTopic.productReturns],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why the number moves',
      paragraphs: [
        'You open an app, see red, and feel your stomach drop before '
            'you know why. A share of stock can rise or fall in price, '
            'sometimes by a lot, over a short period. That movement '
            'reflects many things at once. It reflects how the company is '
            'doing, what investors expect for the future, and broader '
            'conditions in the market.',
        'Some companies pay a dividend, a portion of profit shared with '
            'shareholders. A dividend is never guaranteed. A company can '
            'reduce it, skip it, or stop paying it, especially if '
            'conditions change.',
        'It is possible for a company to be performing well by its own '
            'numbers, revenue growing, a solid product, and still see its '
            'share price fall, because the price also reflects what '
            'investors already expected and what they expect next, not '
            'only how the company did in the past.',
      ],
    ),
    NuggetsBlock([
      'A lower peso price per share, on its own, does not mean a stock is '
          'cheaper or a better deal. Two companies can be priced very '
          'differently for reasons that have nothing to do with which one '
          'is the better investment, including simply how many shares '
          'each one has issued.',
      'Investing in stocks means accepting the chance of losing part, or '
          'in some cases all, of the money invested.',
      'Nothing here says what a stock\'s price will do next. The only '
          'honest statement about the future is that it is uncertain.',
    ]),
    RiskWarningBlock(
      title: 'You can lose part or all of what you put in',
      text:
          'A stock\'s price can fall below what was paid for it, and there '
          'is no promise that it will recover. This lesson explains how '
          'gains and losses can happen. It does not predict what will '
          'happen to any specific investment.',
    ),
    OfficialSourceBlock(
      agency: _pseAcademyAgency,
      sourceTitle: _pseAcademyTitle,
      canonicalUrl: _pseAcademyUrl,
      lastVerifiedDate: _pseAcademyVerified,
    ),
    OfficialSourceBlock(
      agency: _pseInvestingAgency,
      sourceTitle: _pseInvestingTitle,
      canonicalUrl: _pseInvestingUrl,
      lastVerifiedDate: _pseInvestingVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
    MythOrFactBlock(
      blockId: 'low-price-cheap-myth',
      statement:
          'A share priced at two pesos is automatically a cheaper, better '
          'deal than a share priced at two thousand pesos.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Price alone does not say much. What matters is the price '
          'relative to the company behind it, not the peso number by '
          'itself. A low price can reflect a large number of shares '
          'outstanding, or other reasons that have nothing to do with '
          'value.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'earlier-period-example',
      scenarioTitle: 'A fictional example from an earlier period',
      situation:
          'In an earlier period, a snack company\'s revenue grew for two '
          'years in a row. Over that same stretch, its share price fell. '
          'What is the most likely explanation, based on this lesson?',
      options: [
        ScenarioChoiceOption(
          id: 'expectations-shifted',
          label:
              'Investors had already expected strong results, and '
              'something about the outlook changed their expectations for '
              'what comes next',
          explanation:
              'A price reflects expectations, not only the latest '
              'results. Even solid performance can come with a falling '
              'price if it falls short of what was already expected, or '
              'if the outlook for the future shifts.',
        ),
        ScenarioChoiceOption(
          id: 'lying',
          label: 'The company must have been lying about its revenue',
          explanation:
              'Nothing in this example suggests that. A falling price '
              'alongside real revenue growth is a normal, explainable '
              'pattern, not evidence of dishonesty.',
        ),
        ScenarioChoiceOption(
          id: 'must-rise',
          label:
              'Revenue growth always means the share price should have '
              'risen too',
          explanation:
              'Revenue is only one piece of what a price reflects. Price '
              'also carries expectations for the future, market mood, and '
              'other factors, so revenue growth does not automatically '
              'mean a rising price.',
        ),
      ],
      preferredOptionId: 'expectations-shifted',
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'stock-returns-reflect',
      question:
          'Before this lesson, would you have guessed that a company '
          'doing well could still see its share price fall? What changed '
          'in how you would look at a stock\'s price now?',
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional company\'s dividend was cut in half last quarter. '
        'What does this lesson say about that?',
    choices: [
      'This should never happen, since dividends are guaranteed once a '
          'company starts paying them',
      'A dividend can be reduced or stopped, since it was never guaranteed '
          'in the first place',
      'It means the share price will definitely recover soon',
    ],
    correctIndex: 1,
    explanation:
        'A dividend is never guaranteed. A company can reduce it, skip it, '
        'or stop paying it, especially if conditions change, and that is '
        'a normal part of owning shares, not a rule being broken.',
    whyWrong:
        'Nothing in this lesson promises that dividends stay fixed, and a '
        'dividend cut says nothing certain about what the share price '
        'will do next.',
  ),
  keyTakeaway:
      'A share\'s price can rise or fall for many reasons, dividends are '
      'never guaranteed, and a low peso price alone never tells you '
      'whether something is a good deal.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Price Is Not the Same as Value
// ---------------------------------------------------------------------------

const _priceIsNotValue = MoneyLesson(
  id: sbPriceIsNotValue,
  trackId: 'stocks_and_bonds',
  title: 'Price Is Not the Same as Value',
  icon: 'inspect',
  minutes: 6,
  summary:
      'A share price is one number. Understanding what stands behind it '
      'takes more than one metric.',
  objective:
      'Read a few basic business numbers well enough to know what still '
      'needs investigating.',
  sections: [],
  governance: _governance,
  sources: [_pseAcademy, _secInvestment101],
  topics: [ContentTopic.stocks],
  authoredBlocks: [
    ProseBlock(
      heading: 'One number, whole business',
      paragraphs: [
        'You see one stock at four pesos and another at four hundred, '
            'and the cheap one looks like the bargain. A company\'s share '
            'price is just one number. Behind it sits a real business with '
            'revenue, money coming in, profit, what is left after costs, '
            'and debt, what the company owes. It also has cash flow, actual '
            'cash moving in and out, and a share count, how many pieces the '
            'company is divided into.',
        'No single one of these numbers tells the full story on its own. '
            'A company can have strong revenue and weak cash flow. A '
            'company can look inexpensive on price alone and still carry '
            'a large amount of debt. Reading only one number is how an '
            'incomplete picture gets mistaken for a full one.',
        'This lesson is about building the habit of looking further, not '
            'about arriving at a decision. There is no correct company to '
            'pick here, only a comparison exercise.',
      ],
    ),
    NuggetsBlock([
      'Revenue is money coming in. It says nothing on its own about '
          'whether the company is actually profitable.',
      'Profit and cash flow can tell different stories. A company can '
          'report a profit on paper while still struggling with the '
          'actual cash moving through the business.',
      'Debt matters alongside everything else. A company carrying heavy '
          'debt can be pressured very differently in a downturn than one '
          'carrying little debt.',
    ]),
    RiskWarningBlock(
      title: 'One metric is never the full picture',
      text:
          'Judging a company by price, or by any single number, skips the '
          'deeper look this lesson is meant to build the habit of doing.',
    ),
    OfficialSourceBlock(
      agency: _pseAcademyAgency,
      sourceTitle: _pseAcademyTitle,
      canonicalUrl: _pseAcademyUrl,
      lastVerifiedDate: _pseAcademyVerified,
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
    ComparisonBlock(
      blockId: 'company-comparison',
      title: 'Two fictional companies, side by side',
      criteria: [
        ComparisonCriterion(id: 'revenue', label: 'Revenue'),
        ComparisonCriterion(id: 'profit', label: 'Profit'),
        ComparisonCriterion(id: 'cash-flow', label: 'Cash flow'),
        ComparisonCriterion(id: 'debt', label: 'Debt'),
        ComparisonCriterion(id: 'shares', label: 'Shares outstanding'),
      ],
      items: [
        ComparisonItem(
          id: 'company-a',
          name: 'Example Snack Co. (fictional)',
          valuesByCriterionId: {
            'revenue': '₱850 million last year',
            'profit': '₱40 million last year',
            'cash-flow': '₱65 million last year',
            'debt': '₱120 million',
            'shares': '200 million shares',
          },
        ),
        ComparisonItem(
          id: 'company-b',
          name: 'Example Delivery Co. (fictional)',
          valuesByCriterionId: {
            'revenue': '₱1.2 billion last year',
            'profit': '₱15 million last year',
            // Deliberately left blank: ComparisonItem.valueFor renders this
            // as "Not provided" rather than a number, standing in for the
            // real gap the lesson wants a learner to notice and name.
            'cash-flow': '',
            'debt': '₱900 million',
            'shares': '500 million shares',
          },
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'higher-revenue-myth',
      statement:
          'Since Example Delivery Co. has higher revenue, it must be the '
          'better investment of the two, fictional companies above.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Higher revenue alone does not settle anything. Example '
          'Delivery Co. also carries much more debt, and its cash flow '
          'was not even provided here, which is itself a reason to '
          'investigate further before drawing any conclusion.',
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'company-comparison-reflect',
      question:
          'Looking at the comparison above, which company would need '
          'more investigation before anyone could reasonably judge it, '
          'and what specific information is still missing?',
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'In the comparison above, the fictional Example Delivery Co. has '
        'no cash flow figure listed. What should that missing figure mean '
        'to you?',
    choices: [
      'It can be safely assumed to be similar to its profit figure',
      'It is a real gap that is worth investigating before drawing any '
          'conclusion',
      'It does not matter, since revenue is the only number that counts',
    ],
    correctIndex: 1,
    explanation:
        'A missing number is not the same as a known, safe number. A gap '
        'like this is exactly what the habit of looking further is for, '
        'not something to fill in with a guess.',
    whyWrong:
        'Profit and cash flow can differ quite a bit for the same '
        'company, and revenue alone never says whether a business is '
        'actually generating cash.',
  ),
  keyTakeaway:
      'A share price is one number standing in front of a business made '
      'of many others. Revenue, profit, cash flow, debt, and share count '
      'each add part of the picture, and a gap in any of them is a reason '
      'to look closer, not a detail to skip.',
);

// ---------------------------------------------------------------------------
// Lesson 4: Diversification and Concentration
// ---------------------------------------------------------------------------

const _diversificationAndConcentration = MoneyLesson(
  id: sbDiversificationAndConcentration,
  trackId: 'stocks_and_bonds',
  title: 'Diversification and Concentration',
  icon: 'split',
  minutes: 5,
  summary:
      'Spreading money across more than one holding can reduce '
      'concentration risk. It cannot remove every risk, and it is easy to '
      'feel diversified while actually staying concentrated.',
  objective:
      'Spot when a portfolio is genuinely spread out and when it only '
      'looks that way.',
  sections: [],
  governance: _governance,
  sources: [_pseAcademy, _secInvestment101],
  topics: [ContentTopic.stocks],
  authoredBlocks: [
    ProseBlock(
      heading: 'When everything moves together',
      paragraphs: [
        'Your barkada group chat is all in on the same one thing, and '
            'it feels safer because everyone agrees. Owning shares in only '
            'one company means everything depends on that one company. If '
            'something goes wrong there, the whole holding can be affected '
            'at once. That concentrated position is exactly the kind of '
            'risk diversification is meant to reduce.',
        'Diversification generally means spreading money across a number '
            'of different holdings, so a problem with any single one has '
            'a smaller effect on the whole. It does not remove risk '
            'altogether. A broad downturn can still affect a diversified '
            'portfolio, and diversification never turns a losing period '
            'into a guaranteed gain.',
        'It is possible to hold many different names and still be '
            'concentrated in practice, if they are all exposed to the '
            'same thing, the same industry, the same region, or the same '
            'handful of underlying risks moving together.',
      ],
    ),
    NuggetsBlock([
      'The number of holdings is not the same question as how spread out '
          'the risk actually is.',
      'How much time is available before the money is needed, and how '
          'much of a drop could actually be handled financially, both '
          'still matter even inside a diversified portfolio.',
    ]),
    RiskWarningBlock(
      title: 'Diversification reduces risk, it does not remove it',
      text:
          'A diversified portfolio can still lose value, especially in a '
          'downturn that affects many holdings at once. Diversification '
          'is a way to manage concentration risk, not a guarantee against '
          'loss.',
    ),
    OfficialSourceBlock(
      agency: _pseAcademyAgency,
      sourceTitle: _pseAcademyTitle,
      canonicalUrl: _pseAcademyUrl,
      lastVerifiedDate: _pseAcademyVerified,
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
    ComparisonBlock(
      blockId: 'portfolio-comparison',
      title: 'Three fictional portfolios',
      criteria: [
        ComparisonCriterion(id: 'holdings', label: 'Number of holdings'),
        ComparisonCriterion(
          id: 'in-common',
          label:
              'What they have in '
              'common',
        ),
        ComparisonCriterion(id: 'concentration', label: 'Concentration risk'),
      ],
      items: [
        ComparisonItem(
          id: 'portfolio-a',
          name: 'Portfolio A (fictional)',
          valuesByCriterionId: {
            'holdings': '1 company',
            'in-common': 'A single company',
            'concentration': 'Everything depends on that one company.',
          },
        ),
        ComparisonItem(
          id: 'portfolio-b',
          name: 'Portfolio B (fictional)',
          valuesByCriterionId: {
            'holdings': '12 companies',
            'in-common':
                'All twelve in the same shipping and logistics industry',
            'concentration':
                'More names, but still exposed to the same industry '
                'conditions all at once.',
          },
        ),
        ComparisonItem(
          id: 'portfolio-c',
          name: 'Portfolio C (fictional)',
          valuesByCriterionId: {
            'holdings': '10 companies',
            'in-common': 'Ten companies across different industries',
            'concentration':
                'Spread across different industries, so a problem in any '
                'one is less likely to affect all ten at once.',
          },
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'twelve-holdings-myth',
      statement:
          'Owning twelve different companies always means a portfolio is '
          'well diversified.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'The number of holdings is not the same as how spread out the '
          'risk really is. Portfolio B in this lesson owns twelve '
          'companies that are all in the same industry, so it is more '
          'concentrated than it looks.',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'one-holding-drops',
      scenarioTitle: 'One holding drops sharply',
      situation:
          'Say one company in Portfolio C above drops sharply in value. '
          'What is the more likely effect on the rest of the portfolio, '
          'based on this lesson?',
      options: [
        ScenarioChoiceOption(
          id: 'less-affected',
          label:
              'The other nine holdings, spread across different '
              'industries, are less likely to be affected by that one '
              'company\'s specific problem',
          explanation:
              'That is the point of spreading across different '
              'industries: a problem specific to one holding is less '
              'likely to spread to holdings with little in common with '
              'it.',
        ),
        ScenarioChoiceOption(
          id: 'whole-falls',
          label:
              'The whole portfolio will definitely fall by the same '
              'amount',
          explanation:
              'That would only be likely if every holding shared the '
              'same underlying exposure. Spreading across different '
              'industries is specifically meant to reduce that kind of '
              'shared effect.',
        ),
      ],
      preferredOptionId: 'less-affected',
      requiredForCompletion: false,
    ),
    ReflectionPromptBlock(
      blockId: 'possible-loss-reflect',
      question:
          'If a portfolio like this dropped in value during a bad '
          'period, what could realistically be lost, and how would that '
          'affect other financial plans?',
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Portfolio B owns twelve companies, all in the same industry. '
        'What does this lesson say about that?',
    choices: [
      'It is automatically well diversified because of the number of '
          'holdings',
      'It may still be concentrated, since all twelve share the same '
          'industry risk',
      'It cannot lose value since it holds so many companies',
    ],
    correctIndex: 1,
    explanation:
        'Diversification is about how spread out the underlying risk is, '
        'not just the count of names on a list. Twelve holdings in one '
        'industry can still move together in a downturn.',
    whyWrong:
        'A larger number of holdings does not, by itself, spread out '
        'risk if those holdings all share the same underlying exposure.',
  ),
  keyTakeaway:
      'Diversification is about how spread out the underlying risk '
      'really is, not just how many names appear on a list, and it '
      'reduces risk without ever removing it.',
);

// ---------------------------------------------------------------------------
// Lesson 5: How Bonds Work
// ---------------------------------------------------------------------------

const _howBondsWork = MoneyLesson(
  id: sbHowBondsWork,
  trackId: 'stocks_and_bonds',
  title: 'How Bonds Work',
  icon: 'calendar',
  minutes: 6,
  summary:
      'A bond has a principal, a coupon, and a maturity date. Holding it '
      'to maturity is a different experience from selling it early.',
  objective:
      'Explain the parts of a bond and name the main risks that come with '
      'holding one.',
  sections: [],
  governance: _governance,
  sources: [_secInvestment101, _btrFili, _pdic],
  topics: [ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Lending on a schedule',
      paragraphs: [
        'Someone at work calls bonds the boring, sensible option, and '
            'you are the one lending the money. The principal is the amount '
            'originally lent, and the issuer is whoever borrowed it, a '
            'government or a company. The coupon is the regular interest '
            'the issuer promises, and maturity is the date the principal is '
            'scheduled to be repaid. Yield is the return a buyer can expect '
            'for the price paid, above or below face value, which can '
            'differ from the coupon.',
        'A government bond and a corporate bond both work through the '
            'same basic structure, principal, coupon, maturity, but the '
            'issuer is different, and that difference affects the risk. A '
            'national government is generally seen as a lower credit '
            'risk than many corporate borrowers, though lower risk never '
            'means no risk.',
        'Holding a bond to maturity is a different experience from '
            'selling it before maturity. Held to maturity, a bond is '
            'generally expected to return its principal, assuming the '
            'issuer pays as promised. Sold earlier, the price received '
            'depends on market conditions at that moment, which can be '
            'higher or lower than what was originally paid.',
      ],
    ),
    NuggetsBlock([
      'A fixed coupon does not mean a fixed market price. The coupon '
          'payment stays the same, but the price the bond could be sold '
          'for before maturity can still move up or down.',
      'A corporate bond is not a bank deposit, even if a bank is the one '
          'distributing it. A bond sold through a bank is not covered by '
          'deposit insurance simply because of where it was purchased.',
      'Several separate risks run underneath a bond, including interest '
          'rate risk, credit risk, inflation risk, liquidity risk, and '
          'reinvestment risk, and each can affect a bond in a different '
          'way.',
    ]),
    RiskWarningBlock(
      title: 'Several risks, not just one',
      text:
          'A bond can lose value before maturity, the issuer could fail '
          'to pay as promised, and inflation can quietly reduce what a '
          'fixed payment is actually worth. Government bonds may carry '
          'lower credit risk than many corporate issuers, but lower risk '
          'is never the same as no risk.',
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _btrFiliAgency,
      sourceTitle: _btrFiliTitle,
      canonicalUrl: _btrFiliUrl,
      lastVerifiedDate: _btrFiliVerified,
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
    SortingBlock(
      blockId: 'bond-timeline',
      sortingPrompt:
          'Put this fictional bond\'s timeline in the correct '
          'order.',
      items: [
        SortingItemDef(
          id: 'issue',
          label:
              'Issue date: the bond is bought and the principal is '
              'lent',
        ),
        SortingItemDef(
          id: 'first-coupon',
          label:
              'First coupon payment: the issuer pays the first round of '
              'interest',
        ),
        SortingItemDef(
          id: 'later-coupons',
          label: 'Later coupon payments: interest continues on schedule',
        ),
        SortingItemDef(
          id: 'maturity',
          label: 'Maturity date: the principal is scheduled to be paid back',
        ),
      ],
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'bond-owner-lender',
      categorizePrompt:
          'Sort each fictional instrument into Owner or '
          'Lender.',
      buckets: [
        CategorizeBucket(id: 'owner', label: 'Owner'),
        CategorizeBucket(id: 'lender', label: 'Lender'),
      ],
      items: [
        CategorizeItemDef(
          id: 'gov-bond-10y',
          label: 'A 10-year government bond',
          explanation:
              'A government bond is generally a loan to the government, '
              'making the buyer a lender, not an owner.',
        ),
        CategorizeItemDef(
          id: 'telecom-bond',
          label: 'A corporate bond from a telecom company',
          explanation:
              'A corporate bond is generally a loan to that company, '
              'making the buyer a lender, not an owner.',
        ),
        CategorizeItemDef(
          id: 'common-shares',
          label: 'A company\'s common shares',
          explanation:
              'Common shares generally make the buyer a part owner of '
              'the company, not a lender.',
        ),
      ],
      correctBucketByItemId: {
        'gov-bond-10y': 'lender',
        'telecom-bond': 'lender',
        'common-shares': 'owner',
      },
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'bond-rate-direction',
      scenarioTitle: 'Market rates move after the purchase',
      situation:
          'Say a fixed-coupon bond was bought, and afterward, market '
          'interest rates on comparable new bonds rose. If that bond '
          'needed to be sold before maturity, what generally happens to '
          'the price it could fetch?',
      options: [
        ScenarioChoiceOption(
          id: 'price-falls',
          label:
              'The price it could fetch generally falls, since new bonds '
              'now offer a more attractive rate',
          explanation:
              'When newer bonds pay a higher rate, an older fixed-coupon '
              'bond generally becomes less attractive at its original '
              'price, so its resale price generally falls. This '
              'describes the general mechanism, not a prediction for any '
              'specific bond.',
        ),
        ScenarioChoiceOption(
          id: 'price-rises',
          label: 'The price it could fetch generally rises',
          explanation:
              'This is the opposite of what generally happens. When '
              'comparable new bonds offer a higher rate, an older '
              'fixed-coupon bond generally becomes relatively less '
              'attractive, which pulls its resale price down, not up.',
        ),
        ScenarioChoiceOption(
          id: 'price-same',
          label:
              'The price stays exactly the same no matter what rates '
              'do',
          explanation:
              'A bond\'s resale price before maturity generally does '
              'move with market interest rates. Held to maturity, none '
              'of this applies the same way, since it is expected to '
              'return its principal as promised.',
        ),
      ],
      preferredOptionId: 'price-falls',
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'bond-risk-match',
      categorizePrompt: 'Match each situation to the risk it describes.',
      buckets: [
        CategorizeBucket(id: 'interest-rate', label: 'Interest rate risk'),
        CategorizeBucket(id: 'credit', label: 'Credit risk'),
        CategorizeBucket(id: 'inflation', label: 'Inflation risk'),
        CategorizeBucket(id: 'liquidity', label: 'Liquidity risk'),
        CategorizeBucket(id: 'reinvestment', label: 'Reinvestment risk'),
      ],
      items: [
        CategorizeItemDef(
          id: 'rate-rise',
          label:
              'Market rates rise after the bond was bought, so its '
              'resale price falls',
          explanation:
              'This is interest rate risk: a bond\'s resale price before '
              'maturity generally moves opposite to market rates.',
        ),
        CategorizeItemDef(
          id: 'issuer-trouble',
          label:
              'The issuer runs into trouble and cannot pay as '
              'promised',
          explanation:
              'This is credit risk: the chance that the issuer fails to '
              'pay as promised.',
        ),
        CategorizeItemDef(
          id: 'rising-prices',
          label:
              'Rising prices in general erode what a fixed coupon '
              'payment can actually buy',
          explanation:
              'This is inflation risk: a fixed payment is worth less '
              'when general prices rise.',
        ),
        CategorizeItemDef(
          id: 'few-buyers',
          label:
              'There are few buyers when the bond needs to be sold, '
              'making it hard to sell quickly at a fair price',
          explanation:
              'This is liquidity risk: how easily the bond can be sold '
              'at a fair price when needed.',
        ),
        CategorizeItemDef(
          id: 'lower-coupon-later',
          label:
              'When the bond matures, new bonds available at that time '
              'pay a lower coupon than before',
          explanation:
              'This is reinvestment risk: the return available when '
              'reinvesting the principal later may be lower than before.',
        ),
      ],
      correctBucketByItemId: {
        'rate-rise': 'interest-rate',
        'issuer-trouble': 'credit',
        'rising-prices': 'inflation',
        'few-buyers': 'liquidity',
        'lower-coupon-later': 'reinvestment',
      },
      requiredForCompletion: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A bond bought through a bank turns out to be a corporate bond, '
        'not a deposit account. Is it covered by PDIC deposit insurance?',
    choices: [
      'Yes, since it was purchased at a bank',
      'No, deposit insurance does not automatically cover a bond simply '
          'because a bank distributed it',
      'Only if the coupon rate is fixed',
    ],
    correctIndex: 1,
    explanation:
        'Deposit insurance is specific to deposit accounts. A bond, even '
        'one sold through a bank, is a different kind of instrument and '
        'is not automatically covered.',
    whyWrong:
        'Where a bond was purchased, or whether its coupon is fixed, '
        'does not change what kind of instrument it is or whether '
        'deposit insurance applies.',
  ),
  keyTakeaway:
      'A bond is built from a principal, a coupon, and a maturity date, '
      'and holding it to maturity is a different experience from selling '
      'it early, with several distinct risks running underneath either '
      'path.',
);

// ---------------------------------------------------------------------------
// Lesson 6: Verify Before You Invest
// ---------------------------------------------------------------------------

const _verifyBeforeYouInvest = MoneyLesson(
  id: sbVerifyBeforeYouInvest,
  trackId: 'stocks_and_bonds',
  title: 'Verify Before You Invest',
  icon: 'protected',
  minutes: 6,
  summary:
      'A short habit, checked every time: verify the intermediary, the '
      'offer, and the pressure, before any money moves.',
  objective:
      'Recognize the signs of an unverified offer before acting on '
      'it.',
  sections: [],
  governance: _governance,
  sources: [_pseDirectory, _secInvestment101, _btr],
  topics: [ContentTopic.stocks, ContentTopic.bonds],
  authoredBlocks: [
    ProseBlock(
      heading: 'Check before the money moves',
      paragraphs: [
        'A cousin sends you a screenshot of daily payouts and says the '
            'slots close tonight. Before acting on any investment offer, a '
            'few checks are worth doing every time. Is the person or '
            'platform authorized to offer it, and does the offer appear in '
            'official records? Is a return described as guaranteed, is '
            'there pressure to act immediately, and is recruiting other '
            'people emphasized over the investment itself?',
        'Fees, risks, and how withdrawals work should be clearly '
            'disclosed before money moves. A legitimate offer can '
            'explain these plainly. An offer that avoids the question, '
            'or waves it away, is a signal worth taking seriously.',
        'A tip described as secret, or based on inside information '
            'nobody else has, is a warning sign on its own, whatever '
            'else is said about it.',
      ],
    ),
    NuggetsBlock([
      'Verifying an intermediary and an offer takes a few minutes '
          'against official sources. That is a small cost next to what '
          'an unverified offer can cost.',
      'Genuine urgency is rare in investing. Pressure to decide '
          'immediately is far more often a sign that something is wrong '
          'than a sign of real opportunity.',
    ]),
    RiskWarningBlock(
      title: 'An unverified offer can cost everything put into it',
      text:
          'Money sent to an unauthorized intermediary, or to an offer '
          'that does not appear in official records, may not be '
          'recoverable. Verifying first is the single most protective '
          'habit in this lesson.',
    ),
    OfficialSourceBlock(
      agency: _pseDirectoryAgency,
      sourceTitle: _pseDirectoryTitle,
      canonicalUrl: _pseDirectoryUrl,
      lastVerifiedDate: _pseDirectoryVerified,
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
    ),
    OfficialSourceBlock(
      agency: _btrAgency,
      sourceTitle: _btrTitle,
      canonicalUrl: _btrUrl,
      lastVerifiedDate: _btrVerified,
    ),
    _boundary,
  ],
  interactionBlocks: [
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
          id: 'guaranteed-monthly',
          label: 'A guaranteed 20 percent every month, no risk at all',
          explanation:
              'A fixed high payout promised with no risk at all is not how '
              'legitimate investing works. This phrasing on its own is a '
              'strong warning sign.',
        ),
        CategorizeItemDef(
          id: 'take-your-time',
          label:
              'You can review the offer for as long as you need '
              'before deciding',
          explanation:
              'Room to think it over, without pressure, is a reasonable '
              'sign, not a red flag.',
        ),
        CategorizeItemDef(
          id: 'recruit-friends',
          label: 'You need to recruit three friends before you can join',
          explanation:
              'Emphasis on recruiting other people, rather than the '
              'investment itself, is a common pattern in schemes that '
              'are not legitimate investing.',
        ),
        CategorizeItemDef(
          id: 'directory-listed',
          label:
              'The intermediary is listed in the official '
              'trading-participant directory',
          explanation:
              'Appearing in the official directory is exactly the kind '
              'of check this lesson recommends doing.',
        ),
        CategorizeItemDef(
          id: 'closes-in-hour',
          label: 'This offer closes in one hour, so decide now',
          explanation:
              'Pressure to decide immediately, with no real reason for '
              'the rush, is a common pressure tactic.',
        ),
        CategorizeItemDef(
          id: 'disclosed-in-writing',
          label:
              'Fees, risks, and how withdrawals work are explained '
              'clearly in writing',
          explanation:
              'Clear, written disclosure of fees, risks, and withdrawal '
              'terms is what a legitimate offer looks like.',
        ),
      ],
      correctBucketByItemId: {
        'guaranteed-monthly': 'red-flag',
        'take-your-time': 'reasonable',
        'recruit-friends': 'red-flag',
        'directory-listed': 'reasonable',
        'closes-in-hour': 'red-flag',
        'disclosed-in-writing': 'reasonable',
      },
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'fake-broker-scenario',
      scenarioTitle: 'A broker who cannot be found',
      situation:
          'A fictional person claims to be an authorized broker but does '
          'not appear in the official trading-participant directory when '
          'checked. What is the most protective next step?',
      options: [
        ScenarioChoiceOption(
          id: 'stop-and-verify',
          label:
              'Do not send any money, and treat the mismatch with the '
              'official directory as a serious warning sign',
          explanation:
              'If someone cannot be verified against the official '
              'directory, that alone is reason enough to stop before any '
              'money moves.',
        ),
        ScenarioChoiceOption(
          id: 'test-small',
          label: 'Send a small amount first to test whether it works',
          explanation:
              'Sending any amount to an unverified source still puts '
              'that money at risk. The directory check comes first, '
              'before any money moves, not after.',
        ),
      ],
      preferredOptionId: 'stop-and-verify',
      requiredForCompletion: true,
    ),
    ScenarioChoiceBlock(
      blockId: 'hot-tip-scenario',
      scenarioTitle: 'A secret tip from a fictional contact',
      situation:
          'A fictional friend shares what they call a secret tip from an '
          'inside contact, saying it is a sure thing. What does this '
          'lesson say to do?',
      options: [
        ScenarioChoiceOption(
          id: 'treat-with-caution',
          label:
              'Treat it with real caution, a tip described as secret or '
              'based on inside information is a warning sign, not a '
              'reason to act quickly',
          explanation:
              'This lesson is specific about this: reliance on secret '
              'tips or inside information is one of the checks worth '
              'doing before acting on anything.',
        ),
        ScenarioChoiceOption(
          id: 'act-quickly',
          label:
              'Act quickly, since a sure thing from an inside contact is '
              'a rare opportunity',
          explanation:
              'Nothing described as a secret, sure thing based on inside '
              'information should be treated as reliable. This is '
              'exactly the kind of claim worth stopping on.',
        ),
      ],
      preferredOptionId: 'treat-with-caution',
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'personal-investment-checklist',
      checklistPrompt:
          'A personal checklist to run before acting on any investment '
          'offer. Offline, and yours to keep.',
      items: [
        ChecklistItemDef(
          id: 'directory-check',
          label:
              'The intermediary is checked against the official '
              'directory',
        ),
        ChecklistItemDef(
          id: 'official-records',
          label: 'The offer appears in official records',
        ),
        ChecklistItemDef(
          id: 'no-guarantee',
          label: 'No return is described as guaranteed',
        ),
        ChecklistItemDef(
          id: 'no-pressure',
          label: 'There is no pressure to decide immediately',
        ),
        ChecklistItemDef(
          id: 'fees-disclosed',
          label:
              'Fees, risks, and withdrawal conditions are disclosed '
              'clearly',
        ),
        ChecklistItemDef(
          id: 'no-secret-tip',
          label:
              'The offer does not rely on a secret tip or inside '
              'information',
        ),
      ],
      requiredForCompletion: false,
    ),
    SalapifyActionsBlock(
      blockId: 'stocks-bonds-actions',
      menuPrompt: 'A few real next steps, if any of them fit.',
      actions: [
        SalapifyActionDef(
          id: 'review-goal',
          label: 'Create or review a long-term Goal',
          description:
              'Opens Goals to check a long-term goal, or start one from '
              'a template. Nothing is created or changed until something '
              'is saved there.',
          route: 'goals',
        ),
        SalapifyActionDef(
          id: 'review-budget',
          label: 'Review Budget for an affordable contribution',
          description:
              'Opens Budget to check what is already spoken for this '
              'period before setting any amount aside. Nothing changes '
              'automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'open-mindset',
          label: 'Open Money Mindset before acting on a tip',
          description:
              'Opens Money Mindset, a short pause-and-reflect tool, '
              'useful before acting on any investment tip or pressure to '
              'decide quickly. Nothing is recorded as a transaction.',
          route: 'mindset',
        ),
        SalapifyActionDef(
          id: 'review-investment-account',
          label: 'Review your Accounts',
          description:
              'Opens Accounts, where a Stocks asset type is already '
              'supported if you choose to add one. Nothing is created '
              'automatically, and no security is purchased or '
              'recommended here.',
          route: 'accounts',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A fictional offer promises a guaranteed 15 percent every month '
        'and asks for a decision within the hour. Based on this lesson, '
        'what should happen next?',
    choices: [
      'Decide quickly, since guaranteed high returns are rare '
          'opportunities worth acting on fast',
      'Treat both the guaranteed-return claim and the time pressure as '
          'red flags, and verify before doing anything',
      'Send a small amount first, then decide based on what happens',
    ],
    correctIndex: 1,
    explanation:
        'A guaranteed high return and pressure to decide immediately are '
        'both named directly in this lesson as red flags. The protective '
        'move is to verify first, not to act on either signal.',
    whyWrong:
        'Sending any amount, small or not, to an unverified offer still '
        'puts that money at risk before the intermediary or the offer '
        'has been checked against official records.',
  ),
  keyTakeaway:
      'Verify the intermediary, the offer, and the pressure, every time, '
      'before any money moves. A few minutes of checking is a small cost '
      'next to what an unverified offer can take.',
);
