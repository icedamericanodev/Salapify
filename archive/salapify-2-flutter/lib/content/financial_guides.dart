// The Financial Guides catalog and the small API the screens read.
//
// Parallel to lessons.dart for the Money Courses: the model types live in
// financial_guide.dart, and this file holds the actual set plus the lookups the
// hub and reader use. A new guide is a single entry in [financialGuidesCatalog];
// the screens iterate these helpers and never hardcode a guide.
//
// Facts here are distilled from the already-verified Money Courses lessons
// (lib/content/lessons*.dart), never invented: every peso figure and rule
// (the 90,000 tax free bonus ceiling, the 250,000 freelancer exemption, the
// 3,000,000 VAT and 8 percent thresholds, the quarterly BIR dates, the
// 1,000,000 per depositor per bank PDIC limit, the 3 percent per month credit
// card cap) is lifted from those files. Guides carry no official-source URLs of
// their own. Where a fuller lesson exists in the CORE catalog, the guide links
// to it via [FinancialGuide.deepDiveLessonId] and that lesson carries the
// verified citation; guides distilled from the expansion courses, whose lessons
// the core deep-link cannot resolve yet, offer the general Explore Money
// Courses link instead.

import 'financial_guide.dart';

export 'financial_guide.dart';

/// The catalog, grouped by category in display order. Popular ordering is set
/// per guide via [FinancialGuide.popularRank], not by position here.
const List<FinancialGuide> financialGuidesCatalog = <FinancialGuide>[
  // ---------------------------------------------------------------------------
  // MONEY BASICS
  // ---------------------------------------------------------------------------
  FinancialGuide(
    id: 'what-is-an-emergency-fund',
    category: GuideCategory.moneyBasics,
    title: 'What is an emergency fund?',
    summary:
        'Why a small cash buffer changes everything, and how to start one you can actually reach.',
    minutes: 2,
    icon: 'emergency',
    popularRank: 3,
    deepDiveLessonId: 'emergency-fund',
    keyTakeaway:
        'The first cushion is not about being rich, it is about not borrowing when life happens.',
    sections: [
      GuideSection(
        heading: 'What it is for',
        paragraphs: [
          "An emergency fund is money set aside for the surprises: a medical visit, a phone that dies, an urgent trip to family. Its whole job is to keep one bad week from turning into debt.",
        ],
      ),
      GuideSection(
        heading: 'Start smaller than you think',
        paragraphs: [
          "A common target is three to six months of expenses, which feels impossible at the start, so do not aim there yet. Aim for one week of expenses first, then one month. In the Philippines, 10,000 pesos is a classic first milestone.",
        ],
      ),
      GuideSection(
        heading: 'Order of operations',
        paragraphs: [
          "If you carry high interest debt, build only a small starter cushion first, then send everything extra at the debt. The full cushion comes later, and cheaper.",
        ],
      ),
      GuideSection(
        heading: 'Keep it out of reach',
        paragraphs: [
          "Keep the fund separate from your spending money, ideally in an account you do not touch daily, so it is not accidentally spent.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'the-50-30-20-rule',
    category: GuideCategory.moneyBasics,
    title: 'What is the 50-30-20 rule?',
    summary:
        'A starting frame for splitting your pay, adjusted for real Manila rent.',
    minutes: 2,
    icon: 'essentials',
    popularRank: 4,
    deepDiveLessonId: 'fifty-thirty-twenty',
    keyTakeaway: 'A budget is a plan you keep, not a score you are graded on.',
    sections: [
      GuideSection(
        heading: 'The split',
        paragraphs: [
          "Divide your take home pay roughly 50 percent to needs, 30 percent to wants, and 20 percent to savings and paying down debt. It is a starting frame, not a rule carved in stone.",
        ],
      ),
      GuideSection(
        heading: 'What goes where',
        paragraphs: [
          "Needs are rent, food, bills, transport. Wants are eating out, subscriptions, shopping, nights out. The last 20 percent is you paying your future self first.",
        ],
      ),
      GuideSection(
        heading: 'When rent eats everything',
        paragraphs: [
          "If rent alone takes most of your pay, which is real for many people, do not force the numbers. Shrink wants first, protect even a small savings slice, and treat the split as a direction to move toward, not a test you failed.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'needs-vs-wants-24-hour-rule',
    category: GuideCategory.moneyBasics,
    title: 'Needs, wants, and the 24 hour rule',
    summary: 'A simple pause that saves real money on impulse buys.',
    minutes: 1,
    icon: 'mind',
    deepDiveLessonId: 'needs-wants',
    keyTakeaway:
        'Skipping a want is not being stingy, it is choosing where your money goes on purpose.',
    sections: [
      GuideSection(
        heading: 'The difference',
        paragraphs: [
          "A need keeps your life running: food, rent, transport, a working phone. A want is nice but optional. Most money leaks are wants dressed up as needs in the moment.",
        ],
      ),
      GuideSection(
        heading: 'The pause',
        paragraphs: [
          "For anything that is not urgent, wait 24 hours. If you still want it tomorrow, and it fits your plan, buy it with a clear head. Most of the time the urge is gone by morning.",
        ],
      ),
      GuideSection(
        heading: 'Why it works',
        paragraphs: [
          "The urge is usually the moment, not the thing. Waiting costs nothing, and the buys that survive a day are usually the ones worth making.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'pay-yourself-first',
    category: GuideCategory.moneyBasics,
    title: 'What does pay yourself first mean?',
    summary: 'Why saving on payday beats saving whatever is left.',
    minutes: 2,
    icon: 'savings',
    deepDiveLessonId: 'pay-yourself-first',
    keyTakeaway: 'Savings is a bill you pay yourself, and it goes first.',
    sections: [
      GuideSection(
        heading: 'The flip',
        paragraphs: [
          "Most people plan to save whatever is left at month end, but there is rarely anything left. On payday, before the spending starts, move your savings out first, even a small fixed amount.",
        ],
      ),
      GuideSection(
        heading: 'Why it sticks',
        paragraphs: [
          "It works because you never see the saved money as spendable. What is left is what you live on, guilt free.",
        ],
      ),
      GuideSection(
        heading: 'Make it boring',
        paragraphs: [
          "Same amount, every payday, moved the same day. Willpower runs out, habits do not. Starting small and never skipping beats a big amount you cannot keep up.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'understanding-your-payslip',
    category: GuideCategory.moneyBasics,
    title: 'Understanding your payslip',
    summary:
        'What every deduction between gross pay and take home actually is.',
    minutes: 3,
    icon: 'wallet',
    popularRank: 2,
    keyTakeaway:
        'Your take home is gross pay minus SSS, PhilHealth, Pag-IBIG, and withholding tax, so those deductions are not lost, they are working.',
    sections: [
      GuideSection(
        heading: 'Gross is not take home',
        paragraphs: [
          "Your take home pay is your gross pay minus four things: SSS, PhilHealth, Pag-IBIG, and withholding tax. Seeing them as the deductions they are makes a payslip stop being a mystery.",
        ],
      ),
      GuideSection(
        heading: 'The three contributions',
        paragraphs: [
          "SSS, PhilHealth, and Pag-IBIG are mandatory contributions, not taxes. They fund your pension and sickness benefits, your hospital coverage, and your savings and housing eligibility, all in your name.",
        ],
      ),
      GuideSection(
        heading: 'The tax line',
        paragraphs: [
          "Withholding tax is an estimate of your yearly income tax, collected every payday. If too much was taken over the year, part of it can come back as a refund at year end.",
        ],
      ),
      GuideSection(
        heading: 'Check it against a calculator',
        paragraphs: [
          "Running your payslip through the Take home pay calculator shows the same flow, gross minus SSS, PhilHealth, Pag-IBIG, and tax, so you can spot a deduction that looks off.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'what-is-a-paluwagan',
    deepDiveLessonId: 'savings-circles',
    category: GuideCategory.moneyBasics,
    title: 'What is a paluwagan (savings circle)?',
    summary:
        'How a rotating savings circle works, and the one risk to weigh before you join.',
    minutes: 2,
    icon: 'group',
    keyTakeaway:
        'A savings circle is only as strong as the record everyone can check.',
    sections: [
      GuideSection(
        heading: 'How it works',
        paragraphs: [
          "Everyone contributes a fixed amount each cycle, and each cycle one member takes the whole pot, in turns. Over a full round everyone pays in and receives the same total. It is forced discipline at zero interest, powered by not wanting to let your group down.",
        ],
      ),
      GuideSection(
        heading: 'Two honest truths',
        paragraphs: [
          "An early turn is an interest free advance, and a late turn is forced saving, so know which you have. The entire risk is the organizer and the group; there is no bank and no guarantee, only trust.",
        ],
      ),
      GuideSection(
        heading: 'Join carefully',
        paragraphs: [
          "Know who is in it, what each person pays, and when your turn comes, before the first contribution. Treat your payout as a planned windfall and decide its split before your turn arrives.",
        ],
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // GOVERNMENT
  // ---------------------------------------------------------------------------
  FinancialGuide(
    id: 'sss-and-philhealth-two-safety-nets',
    category: GuideCategory.government,
    title: 'What do SSS and PhilHealth actually cover?',
    summary:
        'Two government safety nets, two different jobs. Neither replaces your own emergency fund.',
    minutes: 3,
    icon: 'protected',
    keyTakeaway:
        'SSS answers what happens to your income, PhilHealth answers what happens to your medical bill, and they rarely answer the same question.',
    sections: [
      GuideSection(
        heading: 'Two different questions',
        paragraphs: [
          "SSS generally provides cash or income related benefits tied to a qualifying event, like being unable to work, reaching retirement age, or losing a job. PhilHealth provides health benefit packages, mainly for care at an accredited hospital or clinic.",
        ],
      ),
      GuideSection(
        heading: 'Where to start',
        paragraphs: [
          "When something happens, match the event to the program first. A hospital admission points to PhilHealth. Being unable to work, retirement, or involuntary job loss points to SSS. Some events, like a death that leaves both dependents and a hospital bill, touch both.",
        ],
      ),
      GuideSection(
        heading: 'Neither is the whole net',
        paragraphs: [
          "Each responds to a specific, defined kind of event under its own current rules. An everyday shock, like a sudden car repair, is what your own emergency fund is for, not SSS or PhilHealth.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'what-does-sss-cover',
    category: GuideCategory.government,
    title: 'What does SSS help with?',
    summary:
        'Eight benefit categories at a glance, so you know where to look first.',
    minutes: 3,
    icon: 'cushion',
    keyTakeaway:
        'A category match means worth checking, never automatically approved.',
    sections: [
      GuideSection(
        heading: 'The eight categories',
        paragraphs: [
          "SSS organizes its benefits into named categories: Sickness, Maternity, Disability, Retirement, Death, Funeral, Unemployment, and Employees Compensation. Recognizing which one a life event falls under is the useful first step.",
        ],
      ),
      GuideSection(
        heading: 'A match is a starting point',
        paragraphs: [
          "Whether a specific claim is paid still depends on your membership category, your posted contribution record, and the current rules for that benefit, not on the category name alone.",
        ],
      ),
      GuideSection(
        heading: 'One event can touch two',
        paragraphs: [
          "A work related accident that also leaves you unable to work can touch more than one category. Check each one through the official channel rather than stopping at the first guess.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'how-philhealth-coverage-works',
    category: GuideCategory.government,
    title: 'How does PhilHealth coverage work?',
    summary:
        'What a case rate really promises, and what to confirm before a planned procedure.',
    minutes: 3,
    icon: 'health',
    keyTakeaway:
        'A case rate is a reference figure, not a promise that your whole bill is covered.',
    sections: [
      GuideSection(
        heading: 'What a case rate is',
        paragraphs: [
          "A published case rate or benefit package is a reference figure tied to that package under current rules. It is not a guarantee that every part of a specific hospital bill will be covered.",
        ],
      ),
      GuideSection(
        heading: 'Where the rest comes from',
        paragraphs: [
          "Any remaining amount, and what it actually is, comes from that provider own billing, not from the case rate. Coverage also depends on whether the provider is accredited and the setting of care.",
        ],
      ),
      GuideSection(
        heading: 'Confirm before you commit',
        paragraphs: [
          "When practical, confirm a provider current accreditation and ask directly what is covered before a planned procedure. Accreditation can change, so a current check beats a remembered one.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'what-is-pag-ibig',
    category: GuideCategory.government,
    title: 'What is Pag-IBIG, really?',
    summary:
        'Three separate tools, Regular Savings, MP2, and a housing loan, that solve three different problems.',
    minutes: 3,
    icon: 'house',
    keyTakeaway:
        'Membership alone does not mean every Pag-IBIG tool fits you; match the tool to the need first.',
    sections: [
      GuideSection(
        heading: 'Three tools, not one',
        paragraphs: [
          "Regular Savings is the program almost every covered member already has, built from posted contributions over time. MP2 Savings is a separate, voluntary program you can open on top of it. Housing finance is a loan you may apply for to buy, build, or improve a home.",
        ],
      ),
      GuideSection(
        heading: 'Each answers a different question',
        paragraphs: [
          "Regular Savings answers what have I already set aside. MP2 answers do I want to set aside more, separately, for later. Housing finance answers can I borrow to buy a home.",
        ],
      ),
      GuideSection(
        heading: 'Sometimes none of them fit',
        paragraphs: [
          "An emergency that needs cash right away is usually better handled with money that is already liquid, not through any of these three. Being a member never means a housing loan will be approved.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'what-is-mp2',
    category: GuideCategory.government,
    title: 'What is MP2?',
    summary: "Pag-IBIG's voluntary savings program, without the hype.",
    minutes: 3,
    icon: 'savings',
    popularRank: 5,
    keyTakeaway:
        'MP2 is voluntary, separate from Regular Savings, and never a stand in for an emergency fund.',
    sections: [
      GuideSection(
        heading: 'What it is',
        paragraphs: [
          "MP2 Savings is a voluntary Pag-IBIG savings program for eligible members, separate from Regular Savings. Opening one is a choice, and it sits alongside Regular Savings rather than replacing it.",
        ],
      ),
      GuideSection(
        heading: 'The dividend is not fixed',
        paragraphs: [
          "MP2 dividend rates are declared for specific periods under Pag-IBIG own current rules, and they can change from one period to the next. A past high rate is information, never a promise about the next one.",
        ],
      ),
      GuideSection(
        heading: 'Not for emergency money',
        paragraphs: [
          "MP2 has its own maturity and withdrawal rules, so money you might need on short notice usually needs somewhere more liquid. Review the current official terms before contributing anything.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'restart-your-benefits-when-you-freelance',
    deepDiveLessonId: 'own-your-benefits',
    category: GuideCategory.government,
    title: 'Who pays your benefits when you go freelance?',
    summary:
        'The day you leave employment, your contributions stop unless you restart them.',
    minutes: 3,
    icon: 'foundation',
    keyTakeaway:
        'Nobody pays your benefits but you, so put SSS, PhilHealth, and Pag-IBIG in the plan as a bill.',
    sections: [
      GuideSection(
        heading: 'What quietly stopped',
        paragraphs: [
          "With an employer, three things were paid for you every month: SSS toward your pension and sickness benefits, PhilHealth toward hospital bills, and Pag-IBIG toward savings and housing. The day you went freelance, all three stopped unless you restarted them as a voluntary member.",
        ],
      ),
      GuideSection(
        heading: 'Why the timing is cruel',
        paragraphs: [
          "Contributions matter exactly when you are sick, giving birth, or old, which is precisely when a gap cannot be filled retroactively on the same terms. A missing year of SSS can lower a pension decades from now; a PhilHealth lapse shows up at the hospital cashier.",
        ],
      ),
      GuideSection(
        heading: 'The fix is mechanical',
        paragraphs: [
          "Register as a voluntary or self employed member, know your monthly amounts, and pay them like a bill, not a choice. Logging them as a recurring expense keeps a slow month from turning into a permanent stop.",
        ],
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // TAX
  // ---------------------------------------------------------------------------
  FinancialGuide(
    id: 'what-is-withholding-tax',
    deepDiveLessonId: 'year-end-refund',
    category: GuideCategory.tax,
    title: 'What is withholding tax?',
    summary:
        'Why your employer takes tax before you ever see your pay, and why December sometimes gives some back.',
    minutes: 3,
    icon: 'percent',
    keyTakeaway:
        'Withholding is an estimate collected every payday, and year end is when that estimate gets corrected.',
    sections: [
      GuideSection(
        heading: 'Tax you never touch',
        paragraphs: [
          "Every payday your employer takes a slice of your pay for income tax and sends it to the government for you. The amount is based on a guess of what you will earn for the whole year, spread across every payday.",
        ],
      ),
      GuideSection(
        heading: 'Why a refund can appear',
        paragraphs: [
          "At year end your employer adds up what you actually earned and compares it to what they already took. If they took too much, the extra comes back to you as a refund, usually in your December or January pay. A refund is your own money returning late, not a prize.",
        ],
      ),
      GuideSection(
        heading: 'When it happens to you',
        paragraphs: [
          "You started partway through the year, your pay changed, or a bonus was taxed along the way. Any of these can mean money is owed back to you.",
        ],
      ),
      GuideSection(
        heading: 'The one job change trap',
        paragraphs: [
          "With one employer all year and correct withholding, your employer settles everything for you. This shortcut is called substituted filing. Two employers in one year, even one after the other, turns it off, and you file your own annual return, BIR Form 1700, by April 15.",
        ],
      ),
      GuideSection(
        heading: 'Confirm before you file',
        paragraphs: [
          "These are Philippine rules, and a deadline shifts when it lands on a weekend or holiday. This is awareness, not tax advice, so confirm with the BIR or a licensed accountant before you file.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'how-13th-month-pay-works',
    deepDiveLessonId: 'thirteenth-month',
    category: GuideCategory.tax,
    title: 'How does 13th month pay work?',
    summary:
        'The once a year money, who gets it, and the part that is tax free.',
    minutes: 2,
    icon: 'gift',
    popularRank: 1,
    keyTakeaway:
        'Your 13th month plus other bonuses are tax free up to 90,000 pesos combined, so decide the split before December.',
    sections: [
      GuideSection(
        heading: 'What it is',
        paragraphs: [
          "In the Philippines, rank and file employees get an extra month of pay in December, the 13th month. It feels like free money, which is exactly why it disappears the fastest.",
        ],
      ),
      GuideSection(
        heading: 'The tax free ceiling',
        paragraphs: [
          "Your 13th month plus your other bonuses are tax free up to 90,000 pesos combined. Anything above that combined ceiling is taxed like ordinary income.",
        ],
      ),
      GuideSection(
        heading: 'Make it do real work',
        paragraphs: [
          "One simple split: a slice to your emergency fund or savings, a slice to clear the highest interest debt you carry, and a slice, guilt free, for the holidays. Deciding the split before the money lands is the whole trick.",
        ],
      ),
      GuideSection(
        heading: 'Debt is the best use',
        paragraphs: [
          "Clearing a high interest debt with part of it is one of the strongest moves, because every peso of interest you stop paying is a peso kept.",
        ],
      ),
      GuideSection(
        heading: 'One honest note',
        paragraphs: [
          "The 90,000 peso tax free ceiling is a Philippine rule that can change. This is awareness, not tax advice, so confirm the current figure with the BIR or a licensed professional.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'which-bir-forms-do-i-file',
    deepDiveLessonId: 'tax-forms',
    category: GuideCategory.tax,
    title: 'Which BIR forms do I actually file?',
    summary:
        'A plain map of returns for employees, freelancers, and the self employed.',
    minutes: 4,
    icon: 'document',
    keyTakeaway:
        'Most people file fewer returns than they fear, and knowing which ones are yours removes most of the anxiety.',
    sections: [
      GuideSection(
        heading: 'If you are an employee',
        paragraphs: [
          "With one job, you usually file nothing yourself. Your employer takes the tax, remits it, and hands you Form 2316 every January. You only file your own return, Form 1700, if you had two or more employers in the year or your tax was not withheld correctly.",
        ],
      ),
      GuideSection(
        heading: 'If you run a sideline',
        paragraphs: [
          "A sideline makes you a mixed income earner, and you file Form 1701. You register once with Form 1901. There is no more 500 peso yearly registration fee; it was removed in 2024 by the Ease of Paying Taxes law, so ignore older guides that still mention it.",
        ],
      ),
      GuideSection(
        heading: 'The quarterly rhythm',
        paragraphs: [
          "As self employed you pay income tax quarterly on Form 1701Q, due May 15, August 15, and November 15, then once a year on Form 1701 or 1701A by April 15. The first quarter is due in May, not April, and a quarter with zero income still means you file.",
        ],
      ),
      GuideSection(
        heading: 'Keep every certificate',
        paragraphs: [
          "If clients withhold tax from your fees, they hand you Form 2307. Keep every one; it is tax you already paid and it lowers your bill at year end. Cross 3,000,000 pesos in sales in any 12 months and you move into VAT at 12 percent, so get an accountant before that line.",
        ],
      ),
      GuideSection(
        heading: 'This is awareness, not tax advice',
        paragraphs: [
          "Deadlines shift when they land on a weekend or holiday. Confirm with the BIR or a licensed accountant before you file.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'percentage-tax-and-the-8-percent-option',
    deepDiveLessonId: 'freelancer-setaside',
    category: GuideCategory.tax,
    title: 'What is the 8 percent tax option?',
    summary:
        'The simple set aside habit that keeps a sideline or small business out of tax trouble.',
    minutes: 3,
    icon: 'receipt',
    keyTakeaway:
        'Money set aside for tax was never yours to spend, so split it on the day you get paid.',
    sections: [
      GuideSection(
        heading: 'Nobody withholds it for you',
        paragraphs: [
          "When no employer sets your tax aside, that discipline is yours. The freelancers who never panic at deadline treat a slice of every payment as not theirs, moving it aside the same day a client pays.",
        ],
      ),
      GuideSection(
        heading: 'How big a slice',
        paragraphs: [
          "On the flat 8 percent option, available if your sales stay within 3,000,000 a year and you are not VAT registered, set aside 8 percent from the start. If freelancing is your only income, your first 250,000 for the year is tax free. If you also earn a salary, the whole sideline is taxed at 8 percent with no 250,000 deduction.",
        ],
      ),
      GuideSection(
        heading: 'Percentage tax, or not',
        paragraphs: [
          "Percentage tax is a separate 3 percent tax on your sales, filed each quarter on Form 2551Q. If you chose the 8 percent flat rate, you skip it, because the 8 percent already covers both your income tax and this.",
        ],
      ),
      GuideSection(
        heading: 'The timing trap',
        paragraphs: [
          "The 8 percent is not automatic. You choose it on time, at registration or on your first quarter return, and it is locked for the whole year. Confirm with the BIR or a licensed accountant.",
        ],
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // INVESTING
  // ---------------------------------------------------------------------------
  FinancialGuide(
    id: 'saving-vs-investing',
    category: GuideCategory.investing,
    title: 'What is the difference between saving and investing?',
    summary:
        'They solve different problems, so start with what the money is for.',
    minutes: 3,
    icon: 'growth',
    keyTakeaway:
        'Start with what the money is for and when you will need it; the product comes second.',
    sections: [
      GuideSection(
        heading: 'Two different jobs',
        paragraphs: [
          "Saving keeps money safe and ready for something you expect to need soon. Investing puts it to work over a longer stretch, and that work comes with real uncertainty.",
        ],
      ),
      GuideSection(
        heading: 'What investing really means',
        paragraphs: [
          "Investing means accepting that the amount could go down before it goes up, including the chance of ending up with less than you started with. Money you need soon, like next month rent, belongs somewhere stable and easy to reach.",
        ],
      ),
      GuideSection(
        heading: 'The other side of the trade',
        paragraphs: [
          "For a goal years away, cash is not automatically the safe choice, because prices tend to rise and money sitting still can quietly lose buying power. This is not a push to invest, only the honest trade to weigh.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'are-you-ready-to-invest',
    category: GuideCategory.investing,
    title: 'Are you ready to invest?',
    summary:
        'The foundation that sits under any investment, recommended first, never required.',
    minutes: 3,
    icon: 'checklist',
    keyTakeaway: 'Investing sits on top of a foundation, not instead of one.',
    sections: [
      GuideSection(
        heading: 'The month that decides it',
        paragraphs: [
          "Rent is due, a parent needs medicine, and payday is days out. If essential bills are not reliably covered, a market drop can force you to sell at the worst time just to cover an ordinary month.",
        ],
      ),
      GuideSection(
        heading: 'A short readiness check',
        paragraphs: [
          "Recommended first, not a lock: essential bills are covered, an emergency buffer has been started, expensive debt has been reviewed, the amount is genuinely affordable, and the money will not be needed soon.",
        ],
      ),
      GuideSection(
        heading: 'Why debt often comes first',
        paragraphs: [
          "Paying down high interest debt is a certain saving, because you definitely stop paying that interest. Investment growth is never guaranteed, so a certain saving often wins over an uncertain gain.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'what-is-pdic-deposit-insurance',
    category: GuideCategory.investing,
    title: 'What is PDIC deposit insurance?',
    summary:
        'What is protected if a bank fails, and what is not, even at the same counter.',
    minutes: 3,
    icon: 'bank',
    keyTakeaway:
        'Deposit insurance protects deposits, not every product a bank happens to sell.',
    sections: [
      GuideSection(
        heading: 'What is covered',
        paragraphs: [
          "A savings account or a time deposit is a bank deposit, money the bank owes you. PDIC insures deposits up to 1,000,000 pesos per depositor, per bank, a limit effective March 15, 2025.",
        ],
      ),
      GuideSection(
        heading: 'What is not',
        paragraphs: [
          "A UITF, a mutual fund, a bond, or shares of stock is an investment product, even when sold at the same bank counter by the same staff. Its value can rise or fall, and deposit insurance does not automatically reach it.",
        ],
      ),
      GuideSection(
        heading: 'Two things to remember',
        paragraphs: [
          "An amount above the current limit is not automatically protected for the excess, and how an account is owned, solely, jointly, or in trust, can change coverage. The PDIC Board can revise the limit, so check the current figure rather than assume it is fixed.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'uitf-vs-mutual-fund-vs-etf',
    category: GuideCategory.investing,
    title: 'UITF, mutual fund, or ETF?',
    summary: 'Three pooled funds, compared plainly, with none called the best.',
    minutes: 4,
    icon: 'chart',
    keyTakeaway:
        'All three are pooled funds built, supervised, and traded differently, and none of them is a deposit.',
    sections: [
      GuideSection(
        heading: 'What a pooled fund is',
        paragraphs: [
          "Many investors money is gathered into one shared portfolio, and you hold units representing your slice. The per unit price, NAVPU, moves as the value of what the fund holds moves. Professional management can inform choices, but it never removes the risk of loss.",
        ],
      ),
      GuideSection(
        heading: 'How the three differ',
        paragraphs: [
          "A UITF is offered through a bank trust department and supervised by the Bangko Sentral ng Pilipinas. A mutual fund is an investment company registered with the SEC. An ETF trades on the Philippine Stock Exchange through a broker, so its price can move during the day.",
        ],
      ),
      GuideSection(
        heading: 'The shared truth',
        paragraphs: [
          "All three can lose value, none is covered by deposit insurance, and a fund name is a marketing label, not a full description of what it holds. Read the fund own fact sheet, not its name.",
        ],
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // DEBT AND CREDIT
  // ---------------------------------------------------------------------------
  FinancialGuide(
    id: 'the-minimum-payment-trap',
    deepDiveLessonId: 'card-interest',
    category: GuideCategory.debtCredit,
    title: 'What is the minimum payment trap?',
    summary: 'How paying only the minimum quietly grows what you owe.',
    minutes: 2,
    icon: 'card',
    popularRank: 6,
    keyTakeaway:
        'The minimum keeps the account open; anything above it is what actually pays the debt.',
    sections: [
      GuideSection(
        heading: 'The deal that works for you',
        paragraphs: [
          "Pay your full statement balance by the due date and you pay zero interest. That grace period is the card working in your favor.",
        ],
      ),
      GuideSection(
        heading: 'The trap',
        paragraphs: [
          "The minimum payment is a small slice, often 3 to 5 percent of your balance. Pay only that and you lose the interest free period, so interest, often 2 to 4 percent per month, applies to your whole balance. In the Philippines the cap is 3 percent per month, a central bank rule.",
        ],
      ),
      GuideSection(
        heading: 'Why extra payments work so hard',
        paragraphs: [
          "Interest is taken first, then what is left reduces the balance, and next month interest is charged on the new balance. A small fixed extra lands straight on the principal, so it shrinks the balance faster than it looks.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'is-bnpl-really-free',
    deepDiveLessonId: 'bnpl',
    category: GuideCategory.debtCredit,
    title: 'Is buy now pay later really free?',
    summary:
        'Buy now pay later can help or hurt, so count the cost before you tap install.',
    minutes: 2,
    icon: 'cart',
    keyTakeaway:
        'Convenient is not the same as free, so count it before you sign.',
    sections: [
      GuideSection(
        heading: 'What it does',
        paragraphs: [
          "Buy now pay later splits a purchase into installments. Used on something you were already going to buy and can afford, it can spread a cost without pain.",
        ],
      ),
      GuideSection(
        heading: 'The real risk',
        paragraphs: [
          "It makes spending feel smaller than it is. Three or four small plans across different apps all land in the same month, and together they can take a big share of one payday. Zero interest is not always zero cost; watch for the fees.",
        ],
      ),
      GuideSection(
        heading: 'Two tests before you install',
        paragraphs: [
          "One: would you still buy this if you had to pay full price today? Two: would all your installments together still fit inside one paycheck? Treat every plan as a bill and keep the total in front of you.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'snowball-vs-avalanche',
    deepDiveLessonId: 'snowball-avalanche',
    category: GuideCategory.debtCredit,
    title: 'Snowball or avalanche, which pays off debt faster?',
    summary: 'Two proven payoff orders, and how to choose with real numbers.',
    minutes: 2,
    icon: 'mountain',
    keyTakeaway:
        'The best payoff method is the one you can follow until the balance reaches zero.',
    sections: [
      GuideSection(
        heading: 'Same engine, different order',
        paragraphs: [
          "Both methods pay minimums on everything, then throw every spare peso at one debt until it clears, then roll that payment into the next. Only the order differs.",
        ],
      ),
      GuideSection(
        heading: 'The two orders',
        paragraphs: [
          "Snowball attacks the smallest balance first, so each debt cleared is a win you can feel; it wins on motivation. Avalanche attacks the highest interest rate first, which always costs less in total interest; it wins on money.",
        ],
      ),
      GuideSection(
        heading: 'How to choose',
        paragraphs: [
          "If you need visible wins to keep going, snowball. If the interest number motivates you, avalanche. A slightly cheaper plan you abandon costs more than a slightly dearer one you finish.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'emergency-fund-or-debt-first',
    category: GuideCategory.debtCredit,
    title: 'Emergency fund or pay off debt first?',
    summary: 'The ordering rule that saves the most money of any in this app.',
    minutes: 2,
    icon: 'balance',
    deepDiveLessonId: 'cushion-or-debt',
    keyTakeaway:
        'A starter cushion is what stops one bad week from undoing months of payments.',
    sections: [
      GuideSection(
        heading: 'The trap for careful people',
        paragraphs: [
          "Parking a full month of savings while a card charges 3 percent a month means the fund earns nothing while the debt compounds. Every month that money sits still, the debt eats more than the cushion protects.",
        ],
      ),
      GuideSection(
        heading: 'But all in on debt fails too',
        paragraphs: [
          "With zero cushion, the first surprise, a medicine or a repair, forces you to borrow again, and the cycle restarts. You need both, in the right order.",
        ],
      ),
      GuideSection(
        heading: 'The order that works',
        paragraphs: [
          "First, a small starter cushion, one or two weeks of expenses. Second, every spare peso at the highest interest debt until it is gone. Third, grow the fund to one month, then three, in peace.",
        ],
      ),
    ],
  ),

  // ---------------------------------------------------------------------------
  // BUSINESS
  // ---------------------------------------------------------------------------
  FinancialGuide(
    id: 'choosing-a-business-structure',
    category: GuideCategory.business,
    title: 'Which business structure should I choose?',
    summary: 'A plain look at five structures, with none called the best.',
    minutes: 4,
    icon: 'work',
    keyTakeaway:
        'No structure is universally best; what fits depends on owners, activity, and how liability works.',
    sections: [
      GuideSection(
        heading: 'The five options',
        paragraphs: [
          "A sole proprietorship, a partnership, a One Person Corporation, a corporation with multiple owners, and a cooperative are five ways to structure a business in the Philippines. They differ in ownership, liability, governance, continuity, recordkeeping, funding, and which agency registers them.",
        ],
      ),
      GuideSection(
        heading: 'The key split',
        paragraphs: [
          "A sole proprietorship has no legal identity separate from its owner, so the owner is generally personally liable. A One Person Corporation also fits one owner but is a corporation, with a different liability and governance shape. A partnership and a corporation both fit more than one owner but differ in how liability is shared.",
        ],
      ),
      GuideSection(
        heading: 'No ranking here',
        paragraphs: [
          "Every structure trades one thing for another, and the right one depends on circumstances only the owners know. Professional legal, accounting, or tax advice may be useful before deciding.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'dti-sec-or-cda',
    category: GuideCategory.business,
    title: 'DTI, SEC, or CDA, who registers my business?',
    summary: 'Each agency registers a different kind of structure.',
    minutes: 3,
    icon: 'bank',
    keyTakeaway:
        'One agency registration does not, by itself, complete every legal requirement to operate.',
    sections: [
      GuideSection(
        heading: 'Who registers what',
        paragraphs: [
          "A sole proprietor registers a business name with the Department of Trade and Industry. A partnership, a One Person Corporation, or a corporation with multiple owners registers with the Securities and Exchange Commission. A cooperative registers with the Cooperative Development Authority.",
        ],
      ),
      GuideSection(
        heading: 'The gateway',
        paragraphs: [
          "The Philippine Business Hub is a government gateway that can route an application to the matching agency where it supports that path. It is not a fourth registering body, and it does not yet support every business type.",
        ],
      ),
      GuideSection(
        heading: 'Not the finish line',
        paragraphs: [
          "Matching a structure to its agency is one step. BIR registration, barangay and local government requirements, and any industry license generally still apply on top of it.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'registration-is-not-permission-to-operate',
    category: GuideCategory.business,
    title: 'Is my business name enough to operate?',
    summary:
        'A registered name is one step in a longer sequence, not full authority.',
    minutes: 4,
    icon: 'flow',
    keyTakeaway:
        'Registering a business name is one step; BIR, local, employer, and industry requirements generally still apply.',
    sections: [
      GuideSection(
        heading: 'A certificate is a step',
        paragraphs: [
          "A DTI business name certificate, on its own, is not complete legal authority to operate. What applies on top depends on your structure, location, ownership, whether you hire workers, and your industry.",
        ],
      ),
      GuideSection(
        heading: 'The BIR piece',
        paragraphs: [
          "BIR registration is a separate system from DTI, SEC, or CDA registration. A person is only ever meant to hold one TIN, so an existing taxpayer generally updates their registration for a new activity rather than applying for a second one.",
        ],
      ),
      GuideSection(
        heading: 'Watch the shortcuts',
        paragraphs: [
          "Start from the real site, bir.gov.ph, and be cautious of unofficial agents who offer to create or verify a TIN for a fee, or a look alike site with a similar name. The BIR own channels are free to use directly.",
        ],
      ),
      GuideSection(
        heading: 'Online is not exempt',
        paragraphs: [
          "Selling only through a website or a social media page does not, by itself, remove the registration and compliance obligations that would otherwise apply.",
        ],
      ),
    ],
  ),
  FinancialGuide(
    id: 'business-name-vs-trademark',
    category: GuideCategory.business,
    title: 'Is my business name the same as a trademark?',
    summary:
        'Registering a name and protecting it as a trademark are two different systems.',
    minutes: 3,
    icon: 'sparkle',
    keyTakeaway:
        'An approved business name is not, by itself, trademark ownership.',
    sections: [
      GuideSection(
        heading: 'Two different systems',
        paragraphs: [
          "Registering a business or entity name and protecting that name as a trademark are run by different agencies, and finishing one does not finish the other.",
        ],
      ),
      GuideSection(
        heading: 'What a name registration does',
        paragraphs: [
          "A business name registered with DTI, SEC, or CDA gives you a legal identity to operate under. It only checks whether the exact name is already taken in that agency own records; it is not a trademark search.",
        ],
      ),
      GuideSection(
        heading: 'Where trademarks live',
        paragraphs: [
          "Trademark protection is handled separately, through the Intellectual Property Office of the Philippines. Investigating the trademark resources there before committing to a name avoids discovering a conflict only after the name is already in use.",
        ],
      ),
    ],
  ),
];

/// Every guide. Screens and tests read this, so the catalog is the single
/// source of the real set.
List<FinancialGuide> get allFinancialGuides => financialGuidesCatalog;

/// Look up one guide by id, or null. Fails safe like lessonById.
FinancialGuide? guideById(String id) {
  for (final g in allFinancialGuides) {
    if (g.id == id) return g;
  }
  return null;
}

/// Guides in one category, in catalog order.
List<FinancialGuide> guidesInCategory(GuideCategory category) => [
  for (final g in allFinancialGuides)
    if (g.category == category) g,
];

/// How many guides a category holds, for the Browse by Topic count.
int guideCountFor(GuideCategory category) => guidesInCategory(category).length;

/// The Popular set, ordered by popularRank ascending. Ties keep catalog order.
List<FinancialGuide> popularGuides() {
  final featured = [
    for (final g in allFinancialGuides)
      if (g.isPopular) g,
  ]..sort((a, b) => a.popularRank!.compareTo(b.popularRank!));
  return featured;
}
