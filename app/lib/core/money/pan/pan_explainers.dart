/// Salapify's OWN plain answer to "what is X", written to be said out loud.
///
/// ## Why this file exists
///
/// Founder direction, 2026-09-20, on seeing Pan decline to explain MP2: "what
/// if the user has no time to navigate to the academy and they need answer in
/// 2 sec, how we will resolve that?"
///
/// That is the right question and the previous answer was wrong. Pan had two
/// options and both were bad. It could QUOTE the Academy, and the Academy's
/// MP2 lesson quotes a dividend range and its emergency fund lesson names
/// three private banks, neither of which Salapify may say in its own voice.
/// Or it could REFUSE and point at the course, which is a dead end dressed as
/// an answer, and exactly the "Pan did not recognise that one" problem in a
/// politer sentence.
///
/// The third option is the obvious one and it took two rounds to see: WRITE
/// THE ANSWER OURSELVES. A passage that has to be filtered was written for a
/// different surface. A passage written for this surface needs no filter,
/// because the constraint goes in at the start instead of being applied at
/// the end.
///
/// ## The line these are written on
///
/// Every explainer says what a thing IS and how it WORKS. None says what to
/// do with money, names a private company, or quotes a return. That is not a
/// compromise, it is the more useful answer: a rate quoted in an app with no
/// network is stale the day it ships, and "the rate is declared once a year
/// and is not fixed in advance" is the thing somebody actually needs to know
/// about how a programme works.
///
/// A government programme is named and described. That is education, and
/// refusing to say the words Pag-IBIG MP2 to somebody who typed them would be
/// the same uselessness in a different coat.
///
/// `pan_test.dart` runs every string in here through `bannedPhraseIn`, so the
/// rule is enforced rather than remembered.
library;

class PanExplainer {
  const PanExplainer({
    required this.id,
    required this.asks,
    required this.title,
    required this.lead,
    required this.points,
    this.more,
    this.courseId,
    this.salapifyCanDo,
  });

  final String id;

  /// What somebody types to reach it, longest match wins. Lower case.
  final List<String> asks;

  final String title;

  /// ONE sentence. The answer itself, before any detail.
  ///
  /// Founder direction, 2026-09-20, on the first version of these: too wordy
  /// next to the prototype. The first version was four paragraphs of prose,
  /// and somebody who asked what MP2 is had to read all of it to find out.
  /// The answer now comes first and the rest supports it.
  final String lead;

  /// Short lines, one idea each, scanned rather than read.
  final List<String> points;

  /// The part worth knowing that is not worth reading twice. Behind a tap.
  final String? more;

  /// The Academy course that goes deeper, when one exists.
  final String? courseId;

  /// One line on what Salapify itself can do about this, because an
  /// explanation that ends in thin air wastes the fact that the person is
  /// already holding a tool.
  final String? salapifyCanDo;
}

/// Ordered by nothing; matching is by longest ask, not by position.
const List<PanExplainer> panExplainers = <PanExplainer>[
  // --- Philippine programmes -------------------------------------------
  PanExplainer(
    id: 'mp2',
    asks: <String>[
      'mp2',
      // Longer than the 'pag ibig' ask on the entry below, because longest
      // match decides and "what is PAG-IBIG MP2" matches both. Without this
      // the more specific question gets the more general answer.
      'pag ibig mp2',
      'pagibig mp2',
      'modified pag ibig',
      'modified pagibig',
    ],
    title: 'Pag-IBIG MP2',
    courseId: 'pagibig-mp2',
    lead:
        'A voluntary savings programme run by the Pag-IBIG Fund, a government '
        'agency, where your money is locked in for five years.',
    points: <String>[
      'Open to active members, former members with at least 24 months of '
          'contributions, and pensioners.',
      'Save from 500 pesos at a time, as often as you like.',
      'It pays a dividend, not interest. The rate is declared once a year '
          'out of the Fund\'s income, so it is not fixed when you join.',
      'Earnings are exempt from tax.',
      'You can hold more than one MP2 account at once.',
    ],
    more:
        'You choose at the start whether the dividend is paid out each year '
        'or left in to build on itself.\n\n'
        'Taking money out before five years is allowed only on limited '
        'grounds, and when it is allowed you receive a reduced share of the '
        'accumulated earnings rather than the full one.\n\n'
        'MP2 sits on top of your regular Pag-IBIG savings rather than '
        'replacing them.',
    salapifyCanDo:
        'Set a goal with the date you would need the money, and Salapify '
        'shows what to set aside each payday.',
  ),
  PanExplainer(
    id: 'sss',
    asks: <String>['sss', 'social security system'],
    title: 'SSS',
    courseId: 'retirement',
    lead:
        'The government social insurance programme for private sector '
        'workers. Mandatory if you are employed.',
    points: <String>[
      'You and your employer both pay in monthly, worked out from a monthly '
          'salary credit: your salary placed into a band.',
      'It covers retirement, sickness, maternity, disability, unemployment, '
          'death and funeral costs.',
      'What you receive depends on how long you paid in and at what salary '
          'credit, so a gap in contributions is not only a gap in time.',
      'Land based overseas workers and kasambahay are inside the mandatory '
          'scheme, not outside it.',
    ],
    more:
        'The self employed and voluntary members pay the whole contribution '
        'themselves rather than splitting it with an employer.',
  ),
  PanExplainer(
    id: 'philhealth',
    asks: <String>['philhealth', 'phil health'],
    title: 'PhilHealth',
    lead:
        'The national health insurance programme. Under the Universal Health '
        'Care Act every Filipino is a member.',
    points: <String>[
      'Everybody is covered. What differs is who pays: direct contributors '
          'pay their own premium, indirect ones are subsidised by government.',
      'So somebody between jobs is still a member.',
      'For an employee the premium is a percentage of basic salary between a '
          'floor and a ceiling, split with the employer.',
      'It does not pay a hospital bill in full. It covers a defined part '
          'under case rates, and the rest is yours to find.',
    ],
    more:
        'That last gap is the reason most people are surprised by a bill they '
        'thought was insured. It is worth asking what a procedure\'s case '
        'rate is before the day, not after it.',
  ),
  PanExplainer(
    id: 'pagibig',
    asks: <String>['pag ibig', 'pagibig', 'hdmf'],
    title: 'Pag-IBIG',
    lead:
        'The government savings programme aimed at housing, and the HDMF on '
        'your payslip. Mandatory if you are employed.',
    points: <String>[
      'The money stays yours. The pooled fund is what finances members\' '
          'housing loans.',
      'Your balance earns an annual share of the Fund\'s income.',
      'Membership matures at 20 years, or 240 monthly contributions.',
      'It is also what makes you eligible for the Fund\'s housing loans.',
    ],
    more:
        'One thing the payslip hides: the employee share is tiered, a lower '
        'rate at or below a set salary step and a higher one above it, while '
        'the employer share is flat. "We each pay the same" is not quite '
        'true at lower salaries.\n\n'
        'MP2 is a separate, voluntary programme on top of this one.',
  ),
  PanExplainer(
    id: 'thirteenth',
    asks: <String>['13th month', 'thirteenth month', '13 month'],
    title: '13th month pay',
    courseId: 'taxes',
    lead:
        'One twelfth of the total basic salary you EARNED during the calendar '
        'year, required by law, paid on or before 24 December.',
    points: <String>[
      'Earned, not your current monthly rate. Unpaid leave or a raise '
          'partway through changes the figure.',
      'For rank and file employees who worked at least one month in the year.',
      'Managerial employees are outside the rule, though many employers pay '
          'it anyway.',
      'Overtime, holiday premiums and most allowances are left out of the '
          'computation.',
      'Tax free up to a ceiling that covers your other benefits too, not the '
          '13th month alone.',
    ],
    salapifyCanDo:
        'The salary tools on the Plan tab work it out from what you actually '
        'earned.',
  ),
  PanExplainer(
    id: 'pdic',
    asks: <String>['pdic', 'deposit insurance', 'is my deposit insured'],
    title: 'PDIC deposit insurance',
    lead:
        'A government agency that insures deposits in its member banks. If a '
        'member bank closes, it pays insured depositors up to a legal maximum.',
    points: <String>[
      'The cap is per depositor per BANK, not per account.',
      'All your accounts in one bank are added together first, across '
          'branches and account types, then the cap applies to the total.',
      'Five accounts in one bank do not give you five times the cover.',
      'It covers deposits. It does not cover investment products sold '
          'through a bank.',
    ],
    more:
        'That last line is the one that catches people. The paperwork for an '
        'investment product sold at a bank counter can look very like the '
        'paperwork for a deposit, and only one of them is insured. Asking '
        'directly whether a product is a deposit is a fair question and has '
        'a definite answer.',
  ),
  PanExplainer(
    id: 'paluwagan',
    asks: <String>['paluwagan', 'rotating savings', 'ambulant savings'],
    title: 'Paluwagan',
    lead:
        'An informal savings arrangement between people who know each other. '
        'Everybody puts in the same amount each round, and each round one '
        'member takes the pot.',
    points: <String>[
      'It pays nothing. You take out what you put in.',
      'What it does well is force the saving, because a group expecting you '
          'is harder to ignore than a reminder.',
      'Your position in the rotation is the whole economics: going early is '
          'borrowing from the group at no cost, going late is lending to it.',
      'Not regulated and not insured.',
    ],
    more:
        'The risk is more concentrated than it looks. Members usually share '
        'one workplace or one family, so a single closure or layoff can stop '
        'several contributors at the same time rather than one.\n\n'
        'The same word is also used for arrangements that pay early members '
        'out of money from later members, which is a different thing from a '
        'closed group of people who know each other. If new members are being '
        'recruited to keep it going, it is not the thing described above.',
    salapifyCanDo:
        'Record your rounds as debts owed to you, so the total stays visible '
        'while it is out of your hands.',
  ),
  PanExplainer(
    id: 'timedeposit',
    asks: <String>['time deposit', 'term deposit', 'certificate of deposit'],
    title: 'A time deposit',
    lead:
        'Money left with a bank for a fixed length of time, at a rate agreed '
        'when you open it. Both the rate and the date you get it back are '
        'known at the start.',
    points: <String>[
      'Taking it out early is usually possible and usually costs you some or '
          'all of the interest.',
      'The bank\'s early withdrawal penalty is CONTRACTUAL, set by the bank '
          'and written in your agreement.',
      'The tax is STATUTORY and separate: a final tax on peso deposit '
          'interest is withheld by the bank before the money reaches you.',
      'So what lands in your account is already net of tax.',
    ],
    more:
        'There is a tax exemption for genuinely long term deposits and it is '
        'narrower than it sounds. It applies to a specific kind of long term '
        'instrument held by an individual for at least five years, not to any '
        'five year deposit, and it is lost entirely if you take the money out '
        'early. Ask the bank which one you are being sold.',
  ),

  // --- Concepts ---------------------------------------------------------
  PanExplainer(
    id: 'emergencyfund',
    asks: <String>[
      'emergency fund',
      'rainy day fund',
      'pondong pang emergency',
    ],
    title: 'An emergency fund',
    courseId: 'emergency-funds',
    lead:
        'Money set aside for things that are unexpected, necessary and urgent '
        'all at once.',
    points: <String>[
      'A hospital visit or a broken motorbike you use for work is an '
          'emergency. A sale is not, however good it is.',
      'The usual rule of thumb is three to six months of your BARE '
          'essentials: rent, food, utilities, minimum payments.',
      'Not three to six months of your normal spending. That is a much '
          'bigger and much slower target.',
      'It has to be reachable the same day. Money locked away for a fixed '
          'term is doing a different job.',
    ],
    more:
        'People with uneven income, or a single income in the household, '
        'often aim higher than six months, because the thing being insured '
        'against is a longer gap rather than a bigger bill.',
    salapifyCanDo:
        'Reports shows how many months your cash would cover, so you can see '
        'where you are rather than guess.',
  ),
  PanExplainer(
    id: 'inflation',
    asks: <String>[
      'inflation',
      'purchasing power',
      'why is everything expensive',
    ],
    title: 'Inflation',
    courseId: 'inflation',
    lead:
        'The rate at which prices rise, which makes it a statement about your '
        'money rather than about the shops. The same hundred pesos buys less.',
    points: <String>[
      'It matters most to money sitting still.',
      'If prices rise faster than what your savings earn, the number in the '
          'account grows while what it can buy shrinks.',
      'Which is how a balance can go up while you get poorer.',
      'It quietly helps anyone repaying a fixed amount, because the peso they '
          'repay is worth less than the one they borrowed.',
    ],
  ),
  PanExplainer(
    id: 'compound',
    asks: <String>['compound interest', 'compounding', 'compound'],
    title: 'Compounding',
    lead:
        'What happens when the earnings on your money start earning as well. '
        'Year two you earn on what you put in PLUS year one.',
    points: <String>[
      'The effect is slow and then sudden.',
      'For the first few years it looks barely different from simple '
          'interest, and the gap widens the longer it runs.',
      'Which is why time in it matters more than the amount you start with.',
      'It works exactly as hard against you on a debt that rolls over.',
    ],
    more:
        'A credit card balance carried month to month compounds in the same '
        'direction, which is why a small balance can grow while you are '
        'paying it.',
  ),
  PanExplainer(
    id: 'cardinterest',
    asks: <String>[
      'credit card interest',
      'how does credit card interest work',
      'minimum payment',
      'credit utilisation',
      'credit utilization',
    ],
    title: 'How credit card interest works',
    courseId: 'credit-cards',
    lead:
        'A card charges nothing if you pay the full statement amount by the '
        'due date. That is the whole trick.',
    points: <String>[
      'Pay a peso less than the full statement and the finance charge '
          'usually applies to the WHOLE balance, not the unpaid part.',
      'And often from the transaction date rather than from the due date.',
      'New purchases can stop being interest free while a balance is carried.',
      'The minimum payment is designed to keep the account current, not to '
          'clear it.',
      'Separately: using under about 30 percent of your limit is the level '
          'lenders commonly treat as comfortable. A rule of thumb, not a rule.',
    ],
    salapifyCanDo:
        'Add a card with its limit and its statement and due dates, and '
        'Salapify tracks the cutoff, the due date and how much is in use.',
  ),
  PanExplainer(
    id: 'bnpl',
    asks: <String>[
      'bnpl',
      'buy now pay later',
      'installment',
      'instalment',
      'hulugan',
      '0 interest installment',
    ],
    title: 'Instalments and buy now pay later',
    courseId: 'installments',
    lead:
        'An instalment plan turns one price into a monthly figure, and the '
        'monthly figure is what your brain compares against. That is the '
        'design.',
    points: <String>[
      'A thing you would not buy at its price often feels affordable at a '
          'twelfth of it.',
      'Zero interest is usually real and is rarely the whole cost.',
      'Look for a processing fee, a higher sticker price than the cash '
          'price, and whether the amount is blocked against your limit from '
          'day one.',
      'The risk that actually bites is stacking: each plan is small and they '
          'all run at once.',
    ],
    more:
        'So the question is never whether you can afford this one. It is what '
        'your committed monthly total becomes once it is added to the others, '
        'and for how many months they overlap.',
    salapifyCanDo:
        'Record a plan and Salapify carries the remaining payments into what '
        'is already committed, so the total is a figure rather than a feeling.',
  ),
  PanExplainer(
    id: 'networth',
    asks: <String>['net worth', 'net asset'],
    title: 'Net worth',
    courseId: 'net-worth',
    lead:
        'Everything you hold minus everything you owe. One number, and the '
        'only one that cannot be improved by moving money around.',
    points: <String>[
      'Moving money from a bank to a wallet changes two balances and changes '
          'this not at all.',
      'Neither does paying a debt: an asset falls and a liability falls with '
          'it.',
      'What moves it is earning, spending, and interest.',
      'A negative figure is common and is not automatically a problem. One '
          'housing loan can do it, against a house that is also yours.',
    ],
    salapifyCanDo: 'Reports shows yours, and what is on each side of it.',
  ),
  PanExplainer(
    id: 'cashflow',
    asks: <String>['cash flow', 'cashflow'],
    title: 'Cash flow',
    courseId: 'cash-flow',
    lead:
        'What actually arrives and what actually leaves, in the order it '
        'happens. A different question from whether you earn enough.',
    points: <String>[
      'It is the one that causes the trouble.',
      'Paid on the 15th and 30th, rent due on the 1st, a card due on the '
          '5th: comfortable on paper, short in the last week of every month.',
      'Nothing is wrong with the total. The timing is wrong.',
      'Which is why the fix is usually about dates rather than about earning '
          'more.',
    ],
    salapifyCanDo:
        'Safe to Spend holds back what is committed before your next payday, '
        'so the figure left is the one you can actually use.',
  ),
  PanExplainer(
    id: 'zerobased',
    asks: <String>['zero based budget', 'zero based budgeting', 'budgeting'],
    title: 'Budgeting',
    courseId: 'budgeting',
    lead:
        'A decision made in advance, so that the decision is not made at the '
        'till.',
    points: <String>[
      'Most of what people call failing at budgeting is really never having '
          'decided.',
      'Zero-based means every peso that comes in is given a job before the '
          'month starts.',
      'Including the jobs called savings and fun, until nothing is left '
          'unassigned.',
      'Leftover money is the money that disappears.',
      'It is not about spending less on everything. It is about the spending '
          'being chosen rather than discovered.',
    ],
    salapifyCanDo:
        'Set a limit per category and Salapify shows how much of each is used '
        'as the month runs, not after it.',
  ),
  PanExplainer(
    id: 'snowball',
    asks: <String>[
      'snowball',
      'avalanche',
      'debt snowball',
      'debt avalanche',
      'how do i get out of debt',
      'pay off debt',
    ],
    title: 'Snowball and avalanche',
    courseId: 'debt-strategy',
    lead:
        'Two orders for paying off several debts at once. Pay the minimum on '
        'everything, put whatever is spare against ONE debt, then roll that '
        'payment onto the next.',
    points: <String>[
      'Avalanche picks the highest rate first. It costs the least in total, '
          'by arithmetic, every time.',
      'Snowball picks the smallest balance first. It costs more and clears a '
          'whole debt sooner.',
      'The cheaper method is only cheaper if you stay on it.',
      'The difference between them is usually smaller than the difference '
          'between doing one and doing neither.',
    ],
    salapifyCanDo:
        'The debt tools on the Plan tab run both against your own debts and '
        'show the months and the cost side by side.',
  ),
  PanExplainer(
    id: 'diversification',
    asks: <String>['diversification', 'diversify', 'dont put all your eggs'],
    title: 'Diversification',
    courseId: 'risk-return',
    lead: 'Not having everything depend on the same thing going well.',
    points: <String>[
      'Spread across enough different things and one going badly stops being '
          'the whole story.',
      'It reduces the risk specific to one company, one industry or one '
          'country.',
      'It cannot reduce the risk that affects everything at once, which is '
          'why a diversified holding still falls in a general downturn.',
      'The test is not how many holdings there are. It is whether they would '
          'fall together.',
    ],
  ),
  PanExplainer(
    id: 'riskreturn',
    asks: <String>[
      'risk and return',
      'risk tolerance',
      'risk capacity',
      'why is it risky',
    ],
    title: 'Risk and return',
    courseId: 'risk-return',
    lead:
        'The reason anything pays more than a savings account is that '
        'something about it can go wrong.',
    points: <String>[
      'Higher possible gain and higher possible loss are two descriptions of '
          'the same feature.',
      'Anything offering the first without the second is either '
          'misunderstood or misrepresented.',
      'Two different things get called risk tolerance: how you FEEL when a '
          'balance falls, and whether you could ABSORB the fall.',
      'The second one is measurable and decides what is sensible. The first '
          'is a mood that changes with the news.',
    ],
  ),
  PanExplainer(
    id: 'dca',
    asks: <String>[
      'dollar cost averaging',
      'peso cost averaging',
      'cost averaging',
      'dca',
    ],
    title: 'Cost averaging',
    courseId: 'investing-basics',
    lead:
        'Putting in a fixed amount on a fixed schedule rather than deciding '
        'each time.',
    points: <String>[
      'The same money buys more units when prices are low and fewer when '
          'they are high.',
      'What it is really for is removing the decision.',
      'Trying to pick the moment requires being right twice, and the cost of '
          'being wrong is paid in the years spent waiting.',
      'It does not protect you from a long decline. It averages your entry '
          'price; it does not change what you bought.',
    ],
  ),
  PanExplainer(
    id: 'insurance',
    asks: <String>[
      'term insurance',
      'life insurance',
      'vul',
      'term vs vul',
      'do i need insurance',
    ],
    title: 'Insurance, and what it is for',
    courseId: 'insurance',
    lead:
        'Moving a loss you could not absorb onto somebody who can. That is '
        'also the test for whether you need a particular policy.',
    points: <String>[
      'Ask what happens to the people who depend on you, or to you, if the '
          'thing happens and nobody pays.',
      'Somebody with nobody depending on their income needs life cover far '
          'less than they are usually told.',
      'Somebody with children and a mortgage needs it far more.',
      'Term policies cover a period and pay only if the event happens in it.',
    ],
    more:
        'Policies that combine cover with an investment component do two jobs '
        'in one product, which makes the cost of each job harder to see and '
        'harder to compare against anything else. Neither kind is wrong. '
        'Knowing which you are buying is the part that matters.',
  ),
  PanExplainer(
    id: 'utangnaloob',
    asks: <String>['utang na loob', 'family obligation', 'dampa'],
    title: 'Lending to family',
    courseId: 'family-obligations',
    lead:
        'Money lent inside a family is rarely only money. It carries an '
        'expectation on both sides that neither says out loud.',
    points: <String>[
      'Which is why it goes wrong far more often than a bank loan does.',
      'Two things cause the damage, and both are vagueness: no date was '
          'agreed, and nobody wrote down the amount.',
      'Six months later two people remember two different numbers and both '
          'are sincere.',
      'Writing it down is not distrust. It removes the argument before there '
          'is one.',
    ],
    salapifyCanDo:
        'Record it as a debt owed to you, with the amount and the date, and '
        'both of you can see the same figure.',
  ),
];
