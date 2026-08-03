// Money Courses Phase 6: the "Grow Your Money" learning path's first course,
// "Are You Ready to Invest?" (course id 'investing_readiness'). This is the
// pilot expansion course docs/money_courses_expansion_audit.md was written
// to prepare for: separate from the core 22 lessons in lessons.dart, on its
// own progress system (money/expansion_progress.dart), and built entirely
// from the Phase 2 to 5 architecture already shipped (governance metadata,
// official-source and risk-warning blocks, and the Phase 5 interaction
// blocks) rather than adding anything new to the core model.
//
// House rules, same as lessons.dart plus the additive investing-specific
// ones from money/expansion_content_policy.dart: plain English, Philippine
// peso examples, no em or en dashes, no named stock, fund, coin, broker, or
// product anywhere in this file, no guaranteed-outcome or return-forecast
// language, no personalized recommendation, and never a claim that
// regulation guarantees safety. Every lesson stays product-neutral by
// design: it teaches how to think about readiness, never which product to
// choose.
//
// Content topics: deliberately left empty (MoneyLesson.topics = const []).
// The Phase 4 ContentTopic enum names specific regulated product categories
// (stocks, bonds, funds and ETFs, crypto, insurance, loans, and so on); this
// course never discusses a specific category, only the general readiness
// question, so tagging it with any of those would overstate what it covers.
// That means validateExpansionLesson does not treat these lessons as
// "regulated" and does not itself force official sources, a risk-warning
// block, or an educational-boundary block. This file carries all three on
// every lesson anyway, because the pilot's own task explicitly requires
// them regardless of what the enum-based validator would strictly demand;
// see test/lessons_grow_content_test.dart, which checks that directly
// rather than relying on the validator's conditional gate.
//
// Sources: the Philippine Stock Exchange's PSE Academy
// (https://www.pseacademy.com.ph/), the Exchange's own investor-education
// platform, and the Securities and Exchange Commission Philippines'
// Investment 101
// (https://appointment.sec.gov.ph/investors-education-and-information/investment-101/).
// Both sites block automated fetches; the general, evergreen facts cited
// here (the saving/investing distinction, verifying legitimacy before
// committing money, risk and return moving together, no guaranteed return)
// were confirmed through each site's own published description rather than
// invented, and were reviewed by the investment-literacy-reviewer agent
// before this course shipped (see governance.reviewerId below).

import 'interaction_blocks.dart';
import 'lesson_blocks.dart';
import 'lesson_model.dart';

// Plain string constants, not just fields on a shared LessonSourceInfo
// object: an OfficialSourceBlock below needs these same values, and Dart's
// constant-expression grammar does not allow reading a field off a const
// object instance (e.g. `_pseAcademy.agency`) inside another const
// constructor call. A const top-level IDENTIFIER is fine; a const object's
// FIELD is not. Keeping the values as their own named constants avoids
// restating each string, and still points source and block at one place.
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

const _governance = LessonGovernance(
  volatility: ContentVolatility.annual,
  reviewStatus: ReviewStatus.verified,
  lastVerifiedDate: '2026-08',
  reviewDueDate: '2027-08',
  reviewerId: 'ILR',
);

const _boundary = EducationalBoundaryBlock(
  sourceLabel: 'PSE Academy and the Securities and Exchange Commission',
);

/// Lesson ids, stable and free-form by the same convention lessons.dart's
/// own ids use. Never reused for a different lesson once a learner has real
/// progress recorded against one (see money/expansion_progress.dart).
const investRefMoneyJob = 'invest-ready-money-job';
const investRefProtectBase = 'invest-ready-protect-base';
const investRefGoalTimeAccess = 'invest-ready-goal-time-access';
const investRefRiskComfortCapacity = 'invest-ready-risk-comfort-capacity';
const investRefCard = 'invest-ready-card';

/// The five pilot lessons, in reading order. Never added to lessons.dart's
/// flat `lessons` list: the "X of 22" figure on the core Learn screen must
/// never move because of this file (see test/lessons_grow_content_test.dart
/// and test/lessons_content_test.dart's own 22/4 guard).
const List<MoneyLesson> growYourMoneyLessons = [
  _giveYourMoneyAJob,
  _protectTheBaseFirst,
  _goalTimeAndAccess,
  _riskComfortVsCapacity,
  _investmentReadinessCard,
];

// ---------------------------------------------------------------------------
// Lesson 1: Give Your Money a Job
// ---------------------------------------------------------------------------

const _giveYourMoneyAJob = MoneyLesson(
  id: investRefMoneyJob,
  trackId: 'investing_readiness',
  title: 'Give Your Money a Job',
  icon: 'growth',
  minutes: 4,
  summary:
      'Saving and investing solve different problems. Start with what '
      'the money is for, not a product.',
  objective:
      'Decide whether a goal needs to stay accessible or has room to grow.',
  sections: [],
  governance: _governance,
  sources: [_pseAcademy],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Saving and investing solve different problems. Saving keeps money '
            'safe and ready for something you expect to need soon. '
            'Investing puts money to work over a longer stretch of time, '
            'and that work comes with real uncertainty.',
        'Money you need soon, like rent due next month or a bill due in a '
            'few weeks, generally belongs somewhere stable and easy to '
            'reach. A sudden drop in value at the wrong moment could leave '
            'you short exactly when you need the money most.',
      ],
    ),
    NuggetsBlock([
      'The starting question is never which product to pick. It is what '
          'the money is for and when you will need it.',
      'Investing means accepting that the amount could go down before it '
          'goes up, including the chance of ending up with less than you '
          'started with.',
      'Keeping money in cash or savings for a goal that is close is the '
          'stable, accessible choice doing exactly its job.',
    ]),
    RiskWarningBlock(
      title: 'Investing can lose value',
      text:
          'Unlike a savings account, an investment can be worth less than '
          'what you put in, especially over a short period. This lesson is '
          'general education, not a signal to move any specific amount of '
          'money.',
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
    MythOrFactBlock(
      blockId: 'money-job-myth-fact',
      statement:
          'Saving and investing are really the same habit, just two '
          'different names for it.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'Saving protects money you will need soon by keeping it stable '
          'and easy to reach. Investing takes on uncertainty, including the '
          'chance of loss, in exchange for the possibility of growing '
          'money you will not need for a while. They serve different jobs.',
      requiredForCompletion: true,
    ),
    CategorizeBlock(
      blockId: 'money-job-sort-goals',
      categorizePrompt: 'Sort each fictional goal into the group it fits.',
      buckets: [
        CategorizeBucket(id: 'keep-accessible', label: 'Keep accessible'),
        CategorizeBucket(id: 'prepare-first', label: 'Prepare first'),
        CategorizeBucket(
          id: 'long-term',
          label: 'Consider for long-term investing',
        ),
      ],
      items: [
        CategorizeItemDef(
          id: 'rent',
          label: 'Next month\'s rent',
          explanation:
              'This is needed very soon and the amount has to be exact, so '
              'it stays in something stable and easy to reach.',
        ),
        CategorizeItemDef(
          id: 'medical-buffer',
          label: 'An emergency medical buffer you have not started yet',
          explanation:
              'This is exactly the kind of goal to build first, before '
              'adding investing on top. A funded buffer is what keeps a '
              'bad month from becoming a bad year.',
        ),
        CategorizeItemDef(
          id: 'holiday-fund',
          label: 'A holiday fund for next year',
          explanation:
              'About a year away is still soon enough that a sudden drop '
              'in value could leave you short when the trip comes, so it '
              'stays accessible too.',
        ),
        CategorizeItemDef(
          id: 'retirement',
          label: 'Retirement, still decades away',
          explanation:
              'With decades of time before the money is needed, there is '
              'room to ride out ups and downs, which is the situation '
              'long-term investing is meant for.',
        ),
      ],
      correctBucketByItemId: {
        'rent': 'keep-accessible',
        'medical-buffer': 'prepare-first',
        'holiday-fund': 'keep-accessible',
        'retirement': 'long-term',
      },
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'money-job-reflect',
      question:
          'Think of one goal you are currently working toward. Would you '
          'keep it accessible, prepare it first, or consider it for '
          'long-term investing?',
      choices: [
        ReflectionChoice(id: 'keep', label: 'Keep accessible'),
        ReflectionChoice(id: 'prepare', label: 'Prepare first'),
        ReflectionChoice(id: 'grow', label: 'Consider for long-term investing'),
      ],
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'You have ₱15,000 you will need for rent in three weeks. Based on '
        'this lesson, what job does that money have right now?',
    choices: [
      'Keep it accessible and stable, since it is needed soon',
      'Put it into a long-term investment to try to grow it before rent is due',
      'Split it evenly between an investment and cash, just in case',
    ],
    correctIndex: 0,
    explanation:
        'Money needed within weeks has one job: being there, in full, when '
        'the bill is due. That calls for something stable and accessible, '
        'not something that could be worth less right when you need it.',
    whyWrong:
        'A window of a few weeks is not enough time to recover from a drop '
        'in value if it happens right before the money is needed.',
  ),
  keyTakeaway:
      'Start with what the money is for and when you will need it. The '
      'product comes second.',
);

// ---------------------------------------------------------------------------
// Lesson 2: Protect the Base First
// ---------------------------------------------------------------------------

const _protectTheBaseFirst = MoneyLesson(
  id: investRefProtectBase,
  trackId: 'investing_readiness',
  title: 'Protect the Base First',
  icon: 'foundation',
  minutes: 4,
  summary:
      'Investing sits on top of a foundation, not instead of one. Recommended '
      'first, never required.',
  objective:
      'Check whether bills, a buffer, and expensive debt are handled before '
      'investing.',
  sections: [],
  governance: _governance,
  sources: [_secInvestment101],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Investing sits on top of a foundation, not instead of one. If '
            'essential bills are not reliably covered, a market drop can '
            'force a sale at the worst possible time just to cover an '
            'ordinary month.',
        'An emergency buffer exists so a surprise, a medical bill, a job '
            'gap, a broken appliance, becomes a bad week instead of a '
            'reason to sell an investment early and lock in a loss.',
      ],
    ),
    NuggetsBlock([
      'Expensive debt, the kind with a high interest rate, can cost more '
          'for certain than an investment is likely to earn. Paying it '
          'down is itself a guaranteed reduction in what you owe.',
      'Readiness is not one bar everyone clears at the same time. Two '
          'people with the same income can be in very different positions '
          'depending on their bills, buffer, and debt.',
    ]),
    RiskWarningBlock(
      title: 'Selling under pressure can lock in a loss',
      text:
          'If an investment has to be sold during a market drop just to '
          'cover a bill, the loss becomes real and permanent instead of '
          'temporary. A funded buffer is what usually prevents that.',
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
      blockId: 'protect-base-scenario',
      scenarioTitle: 'A bill comes due at the wrong time',
      situation:
          'Say investing had started before an emergency buffer was built. '
          'The market has just dropped, and a ₱9,000 appliance repair bill '
          'is due this week with no other cash on hand. What happens next?',
      options: [
        ScenarioChoiceOption(
          id: 'sell',
          label: 'The investment likely has to be sold to cover the repair',
          explanation:
              'This is exactly the forced-selling problem an emergency '
              'buffer is meant to prevent. Selling while the value is down '
              'turns a temporary drop into a real, locked-in loss.',
        ),
        ScenarioChoiceOption(
          id: 'buffer',
          label: 'The repair is covered from a separate emergency buffer',
          explanation:
              'This is what a funded buffer makes possible. The '
              'investment stays untouched and has time to recover, because '
              'the bill was already handled elsewhere.',
        ),
      ],
      preferredOptionId: 'buffer',
      riskNote: RiskWarningBlock(
        title: 'This is a general example',
        text:
            'Real timing and amounts vary. The point is the order: build '
            'the buffer, then invest what is left over.',
      ),
      requiredForCompletion: true,
    ),
    ChecklistBlock(
      blockId: 'protect-base-checklist',
      checklistPrompt:
          'Investment-readiness checklist. Recommended first, not a lock on '
          'this course, a starting point to think through.',
      items: [
        ChecklistItemDef(
          id: 'bills',
          label: 'Essential bills are covered',
          explanation:
              'Rent, utilities, food, and any minimum debt payments are '
              'reliably paid.',
        ),
        ChecklistItemDef(
          id: 'buffer',
          label: 'An emergency buffer has been started',
          explanation: 'It does not need to be finished. Started counts.',
        ),
        ChecklistItemDef(
          id: 'debt',
          label: 'Expensive debt has been reviewed',
          explanation:
              'You know what it is costing you and whether paying it down '
              'comes first.',
        ),
        ChecklistItemDef(
          id: 'affordable',
          label: 'The planned contribution is genuinely affordable',
          explanation:
              'An amount you will not feel pressured to withdraw early.',
        ),
        ChecklistItemDef(
          id: 'timing',
          label: 'This money will not be needed soon',
          explanation: 'No bill or goal in the next few months depends on it.',
        ),
      ],
    ),
    ReflectionPromptBlock(
      blockId: 'protect-base-reflect',
      question: 'Which of those areas feels least ready right now, if any?',
      choices: [
        ReflectionChoice(id: 'bills', label: 'Essential bills'),
        ReflectionChoice(id: 'buffer', label: 'Emergency buffer'),
        ReflectionChoice(id: 'debt', label: 'Expensive debt'),
        ReflectionChoice(id: 'none', label: 'None, this feels solid'),
      ],
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Which best describes why paying down high-interest debt is often '
        'prioritized before investing?',
    choices: [
      'Because investing is against the rules until debt is paid off',
      'Because the interest saved is certain, while investment growth is not',
      'Because debt always grows faster than any investment could',
    ],
    correctIndex: 1,
    explanation:
        'Paying off expensive debt guarantees you stop paying that '
        'interest. Investment returns are never guaranteed. Comparing a '
        'certain saving against an uncertain gain is why debt often comes '
        'first, not any rule against investing.',
    whyWrong:
        'Nothing in this lesson says investing is against the rules. '
        'Readiness is about the numbers working in your favor, not a rule '
        'blocking you.',
  ),
  keyTakeaway:
      'Recommended first, never required: bills, a starting buffer, and a '
      'look at expensive debt, before or alongside anything else.',
);

// ---------------------------------------------------------------------------
// Lesson 3: Goal, Time and Access
// ---------------------------------------------------------------------------

const _goalTimeAndAccess = MoneyLesson(
  id: investRefGoalTimeAccess,
  trackId: 'investing_readiness',
  title: 'Goal, Time and Access',
  icon: 'target',
  minutes: 4,
  summary:
      'Every investment needs a purpose and a timeline. A better return '
      'does not fix a mismatched date.',
  objective: 'Match how much uncertainty fits a goal to its time horizon.',
  sections: [],
  governance: _governance,
  // Both sources, not just PSE Academy: the investment-literacy-reviewer
  // agent's pass on this lesson could confirm the general time-horizon and
  // liquidity concepts against PSE Academy's own material, but not the
  // specific short/medium/long-term year cutoffs as PSE-specific language.
  // Citing both general investor-education sources here is more honest
  // than pinning illustrative buckets to one source that does not
  // specifically publish them.
  sources: [_pseAcademy, _secInvestment101],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Every investment should be able to answer one question: what is '
            'this money for, and when will it be needed? Without an '
            'answer, there is no way to judge whether the amount of '
            'uncertainty involved makes sense.',
        'Liquidity is how quickly, and how predictably, money can be '
            'turned back into cash at the value expected. Cash in a '
            'savings account is highly liquid. Some investments are not, '
            'and converting them back to cash can take time or happen at a '
            'lower value than hoped.',
      ],
    ),
    NuggetsBlock([
      'A longer time horizon generally allows more room to ride out a '
          'drop in value before the money is needed.',
      'A higher potential return does not fix a mismatch between a '
          'product and when a goal is needed. Uncertainty close to a '
          'fixed date is a real risk, whatever the potential upside.',
    ]),
    RiskWarningBlock(
      title: 'A mismatched time horizon is its own risk',
      text:
          'Choosing an investment for how well it could perform, without '
          'checking whether its usual ups and downs fit when the goal is '
          'actually needed, is a common and avoidable mistake.',
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
    CategorizeBlock(
      blockId: 'goal-time-match',
      categorizePrompt: 'Match each fictional goal to its time horizon.',
      buckets: [
        CategorizeBucket(id: 'short', label: 'Short term, under 2 years'),
        CategorizeBucket(id: 'medium', label: 'Medium term, 2 to 5 years'),
        CategorizeBucket(id: 'long', label: 'Long term, 5 years or more'),
      ],
      items: [
        CategorizeItemDef(
          id: 'phone',
          label: 'Replacing a phone next year',
          explanation:
              'Under two years away is short term. The money should stay '
              'somewhere stable and easy to reach.',
        ),
        CategorizeItemDef(
          id: 'wedding',
          label: 'A wedding planned in about three years',
          explanation:
              'A few years out is medium term, enough time for some '
              'flexibility, but still too close for a lot of uncertainty '
              'right before the date.',
        ),
        CategorizeItemDef(
          id: 'house',
          label: 'A house down payment in about seven years',
          explanation:
              'Several years away is long term, with more room to ride '
              'out ups and downs along the way.',
        ),
        CategorizeItemDef(
          id: 'retirement3',
          label: 'Retirement, roughly twenty five years away',
          explanation:
              'Decades away is the clearest long-term case, with the most '
              'room for the value to move up and down over time.',
        ),
      ],
      correctBucketByItemId: {
        'phone': 'short',
        'wedding': 'medium',
        'house': 'long',
        'retirement3': 'long',
      },
      requiredForCompletion: true,
    ),
    ComparisonBlock(
      blockId: 'goal-time-comparison',
      title: 'What each time horizon usually needs',
      criteria: [
        ComparisonCriterion(id: 'need', label: 'Typical need'),
        ComparisonCriterion(id: 'liquidity', label: 'Liquidity needed'),
        ComparisonCriterion(id: 'swings', label: 'Room to ride out swings'),
      ],
      items: [
        ComparisonItem(
          id: 'short',
          name: 'Short term, under 2 years',
          valuesByCriterionId: {
            'need': 'Stability. The amount has to be there on time.',
            'liquidity':
                'High. Needs to convert to cash quickly and predictably.',
            'swings':
                'Little to none. A drop close to the date is hard to recover from.',
          },
        ),
        ComparisonItem(
          id: 'medium',
          name: 'Medium term, 2 to 5 years',
          valuesByCriterionId: {
            'need': 'A balance between stability and growth.',
            'liquidity':
                'Moderate. Some notice or delay is usually acceptable.',
            'swings': 'Some, as long as it can settle before the goal date.',
          },
        ),
        ComparisonItem(
          id: 'long',
          name: 'Long term, 5 years or more',
          valuesByCriterionId: {
            'need': 'Growth over time matters more than short-term stability.',
            'liquidity': 'Lower. The money is not needed on short notice.',
            'swings': 'More room. There is time to recover from a downturn.',
          },
        ),
      ],
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'goal-time-reflect',
      question:
          'Think about a real goal of yours. What is its rough time '
          'horizon, and does that change how you would treat uncertainty '
          'around it?',
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A goal is 8 months away with a fixed date. What matters most in '
        'choosing where that money sits?',
    choices: [
      'Whichever option has performed best overall in the past',
      'How much room there is to ride out a drop in value before the date arrives',
      'The size of the amount being set aside',
    ],
    correctIndex: 1,
    explanation:
        'With only 8 months and a fixed date, there is very little room to '
        'recover from a drop in value. That mismatch between the time '
        'horizon and the uncertainty involved matters more than potential '
        'performance.',
    whyWrong:
        'Past results do not guarantee what happens next, and they say '
        'nothing about whether the timing fits a goal only 8 months away.',
  ),
  keyTakeaway:
      'Name the goal, name the date, then ask how much uncertainty that '
      'timeline can actually absorb.',
);

// ---------------------------------------------------------------------------
// Lesson 4: Risk Comfort vs Risk Capacity
// ---------------------------------------------------------------------------

const _riskComfortVsCapacity = MoneyLesson(
  id: investRefRiskComfortCapacity,
  trackId: 'investing_readiness',
  title: 'Risk Comfort vs Risk Capacity',
  icon: 'balance',
  minutes: 4,
  summary:
      'Feeling ready and being financially able to absorb a loss are two '
      'different questions.',
  objective:
      'Tell apart how comfortable you feel with risk from what you can '
      'actually afford to lose.',
  sections: [],
  governance: _governance,
  // Both sources: the investment-literacy-reviewer agent's pass could not
  // confirm the exact "risk tolerance vs risk capacity" terminology as
  // SEC-PH-specific language, only as standard investor-education content
  // broadly consistent with both sources' general risk framing. Citing
  // both, rather than pinning the split to SEC Investment 101 alone, is
  // the more honest attribution.
  sources: [_secInvestment101, _pseAcademy],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'Risk tolerance is how comfortable you feel, emotionally, '
            'watching an investment go up and down in value. Risk '
            'capacity is different: it is whether your actual finances '
            'can absorb a loss without disrupting your life.',
        'It is possible to feel adventurous and still not be able to '
            'afford a loss right now, for example if bills, an unstarted '
            'emergency buffer, or upcoming expenses leave little room to '
            'absorb a drop.',
      ],
    ),
    NuggetsBlock([
      'A short quiz inside an app, including this one, cannot tell you '
          'which specific investment is suitable for your situation. It '
          'can only help you think through your own comfort and capacity.',
      'Comfort can change after a single hard week. Capacity depends on '
          'the numbers: your bills, your buffer, and how soon you would '
          'need the money back.',
    ]),
    RiskWarningBlock(
      title: 'Comfort is not the same as capacity',
      text:
          'Feeling ready is not the same as being financially able to '
          'absorb a loss. Both matter, and they can point in different '
          'directions.',
    ),
    OfficialSourceBlock(
      agency: _secAgency,
      sourceTitle: _secTitle,
      canonicalUrl: _secUrl,
      lastVerifiedDate: _secVerified,
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
    ScenarioChoiceBlock(
      blockId: 'risk-scenario-drop',
      scenarioTitle: 'A temporary drop',
      situation:
          'Say ₱10,000 set aside temporarily fell in value to about '
          '₱7,000. Would that money need to be withdrawn soon to cover '
          'bills?',
      options: [
        ScenarioChoiceOption(
          id: 'yes',
          label: 'Yes, it would likely need to be withdrawn for bills',
          explanation:
              'That points to limited risk capacity right now, whatever '
              'the comfort level feels like. Money that might be needed '
              'soon carries a real cost if its value is down exactly when '
              'it is needed.',
        ),
        ScenarioChoiceOption(
          id: 'no',
          label: 'No, it could be left alone to wait it out',
          explanation:
              'That points to more room to absorb a temporary drop, since '
              'the money is not needed on a fixed timeline.',
        ),
        ScenarioChoiceOption(
          id: 'unsure',
          label: 'Not sure',
          explanation:
              'That is a reasonable answer too. It usually means it is '
              'worth looking at bills and buffer more closely before '
              'deciding how much uncertainty to take on.',
        ),
      ],
      requiredForCompletion: true,
    ),
    MythOrFactBlock(
      blockId: 'risk-myth-quiz',
      statement:
          'If a risk quiz says someone is an aggressive investor, that '
          'means any investment product is suitable for them.',
      correctAnswer: MythOrFactAnswer.myth,
      explanation:
          'A quiz can describe general comfort with uncertainty, but '
          'suitability also depends on actual finances, how long until a '
          'goal is needed, and the specific product itself. No short quiz can '
          'guarantee suitability on its own.',
      requiredForCompletion: true,
    ),
    ReflectionPromptBlock(
      blockId: 'risk-reflect',
      question:
          'What would actually happen if a temporary drop in value like '
          'that happened today?',
      allowFreeText: true,
    ),
  ],
  check: KnowledgeCheck(
    question:
        'Someone feels very comfortable with risk, but has no emergency '
        'buffer and an unstable income this month. What does this lesson '
        'suggest?',
    choices: [
      'Comfort with risk means they are ready, so capacity does not matter much',
      'Their comfort and their financial capacity may not match, worth noticing before committing money',
      'They should pick the most aggressive option available, since comfort decides it',
    ],
    correctIndex: 1,
    explanation:
        'Feeling comfortable with ups and downs is not the same as being '
        'able to financially absorb a loss right now. When the two do not '
        'match, it is worth noticing before committing money, not after.',
    whyWrong:
        'Comfort alone does not guarantee the ability to absorb a real '
        'loss without disrupting bills or an unstable income.',
  ),
  keyTakeaway:
      'Ask both questions. How would this feel, and what could this '
      'actually cost me right now.',
);

// ---------------------------------------------------------------------------
// Lesson 5: My Investment Readiness Card
// ---------------------------------------------------------------------------

const _investmentReadinessCard = MoneyLesson(
  id: investRefCard,
  trackId: 'investing_readiness',
  title: 'My Investment Readiness Card',
  icon: 'checklist',
  minutes: 6,
  summary:
      'Build a short private summary from what this course covered. A '
      'reflection, never a result.',
  objective:
      'Put purpose, timing, and the areas worth reviewing into one summary.',
  sections: [],
  governance: _governance,
  sources: [_pseAcademy, _secInvestment101],
  authoredBlocks: [
    ProseBlock(
      heading: 'Why it matters',
      paragraphs: [
        'This is a short summary built from the last four lessons: '
            'purpose, timing, and the areas most worth protecting first. '
            'It stays on this screen. It is a reflection, not a result or '
            'a green light.',
      ],
    ),
    RiskWarningBlock(
      title: 'This is not advice or an eligibility result',
      text:
          'The card built here only reflects what is entered right now. It '
          'is not personalized financial advice, and it does not mean any '
          'product is or is not suitable for anyone.',
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
    ReadinessCardBlock(
      blockId: 'readiness-card',
      cardTitle: 'Build your card',
      fields: [
        ReadinessCardField(
          id: 'purpose',
          label: 'What is this money for?',
          options: [
            ReadinessCardOption(
              id: 'long-term-goal',
              label:
                  'A long-term goal, like retirement or a future big purchase',
            ),
            ReadinessCardOption(
              id: 'general-growth',
              label: 'General long-term growth, no specific goal yet',
            ),
            ReadinessCardOption(
              id: 'not-sure',
              label: 'Not sure yet',
              needsReview: true,
            ),
          ],
        ),
        ReadinessCardField(
          id: 'target-date',
          label: 'Roughly when would this money be needed?',
          options: [
            ReadinessCardOption(
              id: 'under-2',
              label: 'Under 2 years',
              needsReview: true,
            ),
            ReadinessCardOption(id: '2-5', label: '2 to 5 years'),
            ReadinessCardOption(id: '5-plus', label: '5 years or more'),
          ],
        ),
        ReadinessCardField(
          id: 'contribution',
          label:
              'Is the amount being considered something that could be set '
              'aside without feeling it?',
          options: [
            ReadinessCardOption(
              id: 'yes-affordable',
              label: 'Yes, genuinely affordable',
            ),
            ReadinessCardOption(
              id: 'tight',
              label: 'It would be tight some months',
              needsReview: true,
            ),
            ReadinessCardOption(
              id: 'not-sure-contribution',
              label: 'Not worked out yet',
              needsReview: true,
            ),
          ],
        ),
        ReadinessCardField(
          id: 'buffer',
          label: 'Where does the emergency buffer stand right now?',
          options: [
            ReadinessCardOption(
              id: 'buffer-started',
              label: 'Started, or fully funded',
            ),
            ReadinessCardOption(
              id: 'buffer-none',
              label: 'Not started yet',
              needsReview: true,
            ),
          ],
        ),
        ReadinessCardField(
          id: 'debt',
          label: 'Where does any expensive debt stand?',
          options: [
            ReadinessCardOption(
              id: 'debt-none',
              label: 'None, or already reviewed and being paid down',
            ),
            ReadinessCardOption(
              id: 'debt-unreviewed',
              label: 'Not reviewed yet',
              needsReview: true,
            ),
          ],
        ),
        ReadinessCardField(
          id: 'max-loss',
          label:
              'What is the most that could be afforded to lose, '
              'financially, without disrupting daily life?',
          options: [
            ReadinessCardOption(
              id: 'small',
              label: 'A small amount, keeping uncertainty low matters most',
            ),
            ReadinessCardOption(
              id: 'moderate',
              label: 'A moderate amount, there is some room',
            ),
            ReadinessCardOption(
              id: 'none',
              label: 'None right now',
              needsReview: true,
            ),
          ],
        ),
      ],
      requiredForCompletion: true,
    ),
    SalapifyActionsBlock(
      blockId: 'salapify-actions',
      menuPrompt: 'A few real things to do next, if any of them fit.',
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
              'period before setting anything aside. Nothing changes '
              'automatically.',
          route: 'budget',
        ),
        SalapifyActionDef(
          id: 'create-investment-goal',
          label: 'Create a goal for the purpose named above',
          description:
              'Opens Goals to set up a goal for that purpose, if wanted. '
              'Nothing is created automatically, every detail is chosen '
              'there.',
          route: 'goals',
        ),
      ],
    ),
  ],
  check: KnowledgeCheck(
    question:
        'A finished card shows an unstarted emergency buffer and '
        'unreviewed expensive debt. Based on this course, what does that '
        'suggest?',
    choices: [
      'That investing is not allowed at all',
      'That those two areas are worth reviewing first, before or alongside anything else',
      'That the card has made a final decision',
    ],
    correctIndex: 1,
    explanation:
        'This course never blocks anything, and the card is not a '
        'gatekeeper. It points at what is worth looking at first so any '
        'money set aside has a steadier foundation under it.',
    whyWrong:
        'Nothing here is a rule or a lock. Naming an area gives something '
        'concrete to act on, not a reason to forbid anything.',
  ),
  keyTakeaway:
      'A readiness card is a mirror, not a gate. Use it to see clearly, '
      'then decide for yourself what comes next.',
);
