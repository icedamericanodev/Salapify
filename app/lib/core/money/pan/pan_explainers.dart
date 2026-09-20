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
    required this.body,
    this.courseId,
    this.salapifyCanDo,
  });

  final String id;

  /// What somebody types to reach it, longest match wins. Lower case.
  final List<String> asks;

  final String title;

  /// Two to four short paragraphs. Long enough to actually answer, short
  /// enough to read on a phone in the time the founder asked for.
  final String body;

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
    body:
        'MP2 is a voluntary savings programme run by the Pag-IBIG Fund, a '
        'government agency. It sits beside the regular Pag-IBIG membership '
        'savings rather than replacing them, and it is open to active '
        'members, former members who contributed for at least 24 months, and '
        'pensioners.\n\n'
        'Money you put in is locked for five years. You can save any amount '
        'from 500 pesos at a time, as often as you like, and you can hold '
        'more than one MP2 account at once.\n\n'
        'It pays a dividend rather than interest, and this is the part worth '
        'understanding: the rate is declared once a year out of the Fund\'s '
        'net income for that year. It is not fixed when you join and it is '
        'not promised in advance, so past years tell you about the past. '
        'Earnings are exempt from tax. You choose at the start whether the '
        'dividend is paid out each year or left in to build on itself.\n\n'
        'Taking money out before five years is allowed only on limited '
        'grounds, and when it is allowed you receive a reduced share of the '
        'accumulated earnings rather than the full one.',
    salapifyCanDo:
        'If you are saving toward something five years out, a goal with that '
        'date shows what you would have to set aside each payday to reach it.',
  ),
  PanExplainer(
    id: 'sss',
    asks: <String>['sss', 'social security system'],
    title: 'SSS',
    courseId: 'retirement',
    body:
        'The Social Security System is the government social insurance '
        'programme for private sector employees, the self employed, and '
        'voluntary members. Membership is mandatory for employees.\n\n'
        'You and your employer both pay in each month, worked out from a '
        'monthly salary credit, which is your salary placed into a band with '
        'a floor and a ceiling. The self employed pay the whole contribution '
        'themselves.\n\n'
        'What it buys is not one thing but several: a retirement pension or '
        'lump sum, and cover for sickness, maternity, disability, '
        'unemployment, death and funeral costs. How much you receive depends '
        'on how long you paid in and on the salary credits you paid at, so a '
        'gap in contributions is not only a gap in time.\n\n'
        'Cover reaches further than most people assume. Land based overseas '
        'workers and kasambahay are inside the mandatory scheme, not outside '
        'it.',
  ),
  PanExplainer(
    id: 'philhealth',
    asks: <String>['philhealth', 'phil health'],
    title: 'PhilHealth',
    body:
        'PhilHealth is the national health insurance programme. Under the '
        'Universal Health Care Act every Filipino is a member, whether you '
        'contribute directly or the government pays on your behalf.\n\n'
        'Everybody is covered; what differs is who pays. Direct contributors '
        'pay their own premiums, and for an employee that is a percentage of '
        'monthly basic salary between a floor and a ceiling, split with the '
        'employer. Indirect contributors are subsidised by government, which '
        'is the part most people do not know: somebody between jobs is still '
        'a member.\n\n'
        'It does not pay a hospital bill in full. It covers a defined part of '
        'the cost under case rates and benefit packages, and the remainder is '
        'yours or your other cover\'s to find. That gap is the reason most '
        'people are surprised by a bill they thought was insured.',
  ),
  PanExplainer(
    id: 'pagibig',
    asks: <String>['pag ibig', 'pagibig', 'hdmf'],
    title: 'Pag-IBIG',
    body:
        'Pag-IBIG, the HDMF on your payslip, is the government savings '
        'programme aimed at housing. Membership is '
        'mandatory for employees, and you and your employer each pay in '
        'monthly, worked out from your salary up to a maximum the Fund sets.\n\n'
        'The money stays yours. The pooled fund is what finances members\' '
        'housing loans, which is a different thing from your own savings '
        'being earmarked for a house you have not bought.\n\n'
        'Your balance earns an annual share of the Fund\'s income and can be '
        'claimed when your membership matures at 20 years, or 240 monthly '
        'contributions, and on retirement or the other qualifying grounds. '
        'Membership is also what makes you eligible for the Fund\'s housing '
        'and other loan programmes.\n\n'
        'One thing the payslip hides: the employee share is tiered, so it is '
        'a lower rate at or below a set salary step and a higher one above '
        'it, while the employer share is flat. "We each pay the same" is not '
        'quite true at lower salaries.\n\n'
        'MP2 is a separate, voluntary programme on top of this one.',
  ),
  PanExplainer(
    id: 'thirteenth',
    asks: <String>['13th month', 'thirteenth month', '13 month'],
    title: '13th month pay',
    courseId: 'taxes',
    body:
        'Thirteenth month pay is required by law for rank and file employees '
        'who worked at least one month in the calendar year, whatever their '
        'job or how they are paid. Managerial employees are outside the '
        'rule, though many employers pay it anyway.\n\n'
        'It is one twelfth of the total basic salary you EARNED during the '
        'calendar year, which is not the same as one month of your current '
        'salary. A year with unpaid leave in it, or a raise partway '
        'through, gives a different figure.\n\n'
        'It has to be paid on or before 24 December.\n\n'
        'Basic salary is the base, so overtime, holiday premiums, night '
        'differential and most allowances are left out of the computation '
        'unless your employer treats them as part of basic pay.\n\n'
        'It is exempt from income tax up to a ceiling that covers your other '
        'benefits as well, not the thirteenth month alone. Anything above '
        'that ceiling is taxable.',
    salapifyCanDo:
        'The salary tools on the Plan tab work the figure out from what you '
        'actually earned rather than from your current monthly rate.',
  ),
  PanExplainer(
    id: 'pdic',
    asks: <String>['pdic', 'deposit insurance', 'is my deposit insured'],
    title: 'PDIC deposit insurance',
    body:
        'The Philippine Deposit Insurance Corporation is a government agency '
        'that insures deposits held in its member banks. If a member bank '
        'closes, PDIC pays insured depositors up to a maximum set by law.\n\n'
        'The maximum is per depositor per BANK, and the wording matters '
        'because most people hear it as per account. All the accounts you '
        'hold in the same bank are added together first, across branches and '
        'across account types, and the cap applies to the total. Five '
        'accounts in one bank do not give you five times the cover.\n\n'
        'It covers deposits. It does not cover investment products sold '
        'through a bank, and the difference between the two is not always '
        'obvious from the name on the paperwork.',
  ),
  PanExplainer(
    id: 'paluwagan',
    asks: <String>['paluwagan', 'rotating savings', 'ambulant savings'],
    title: 'Paluwagan',
    body:
        'A paluwagan is an informal savings arrangement between people who '
        'know each other. Everybody puts in the same amount each round, and '
        'each round one member takes the whole pot, until everyone has had a '
        'turn.\n\n'
        'What it does well is force the saving: a date and a group of people '
        'expecting you is harder to ignore than a reminder. What it does not '
        'do is earn anything. You take out what you put in.\n\n'
        'Your position in the rotation is the whole economics of it. Going '
        'early is borrowing from the group at no cost. Going late is lending '
        'to the group at no cost. That is what people are really negotiating '
        'when they argue about the order.\n\n'
        'It is not regulated and it is not insured, and the risk is more '
        'concentrated than it looks. Members usually share one workplace or '
        'one family, so a single closure or layoff can stop several '
        'contributors at the same time rather than one.\n\n'
        'The same word is also used for arrangements that pay early members '
        'out of money from later members, which is a different thing from a '
        'closed group of people who know each other. If new members are being '
        'recruited to keep it going, it is not the thing described above.',
    salapifyCanDo:
        'Recording your rounds as debts owed to you keeps the total visible '
        'while it is out of your hands.',
  ),
  PanExplainer(
    id: 'timedeposit',
    asks: <String>['time deposit', 'term deposit', 'certificate of deposit'],
    title: 'A time deposit',
    body:
        'A time deposit is money left with a bank for a fixed length of time, '
        'at a rate agreed when you open it. The rate is known at the start, '
        'which is the whole appeal, and so is the date you get it back.\n\n'
        'Taking it out early is usually possible and usually costs you some '
        'or all of the interest, so the term is a real commitment rather than '
        'a suggestion.\n\n'
        'Two separate things reduce what you get, and they are easy to '
        'confuse. The bank\'s early withdrawal penalty is CONTRACTUAL, set by '
        'the bank and written in your agreement. The tax is STATUTORY: '
        'interest on a peso deposit has a final tax withheld by the bank '
        'before the money reaches you, so what lands in your account is '
        'already net of it.\n\n'
        'There is a tax exemption for genuinely long term deposits, and it is '
        'narrower than it sounds. It applies to a specific kind of long term '
        'instrument held by an individual for at least five years, not to any '
        'five year deposit, and it is lost entirely if you pre-terminate. Ask '
        'the bank which one you are being sold.',
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
    body:
        'An emergency fund is money set aside for the things that are '
        'unexpected, necessary and urgent all at once. A hospital visit or a '
        'broken motorbike you use for work is an emergency. A sale is not, '
        'however good it is.\n\n'
        'The usual rule of thumb is three to six months of your BARE '
        'essentials, not three to six months of your normal spending. Rent, '
        'food, utilities and the minimum payments you cannot skip. People '
        'with uneven income or a single income in the household often aim '
        'higher, because the thing being insured against is longer.\n\n'
        'The property that makes it an emergency fund rather than savings is '
        'that you can reach it the same day. Money locked away for a fixed '
        'term is doing a different job.',
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
    body:
        'Inflation is the rate at which prices rise, so it is really a '
        'statement about your money rather than about the shops. The same '
        'hundred pesos buys less than it did.\n\n'
        'It matters most to money that is sitting still. If prices rise '
        'faster than what your savings earn, the number in the account grows '
        'and what it can buy shrinks, which is why a balance can go up while '
        'you get poorer.\n\n'
        'It also quietly helps anyone repaying a fixed amount, because the '
        'peso they repay is worth less than the peso they borrowed. That is '
        'the one place it works in your favour.',
  ),
  PanExplainer(
    id: 'compound',
    asks: <String>['compound interest', 'compounding', 'compound'],
    title: 'Compounding',
    body:
        'Compounding is what happens when the earnings on your money start '
        'earning as well. Year one you earn on what you put in; year two you '
        'earn on what you put in plus year one.\n\n'
        'The reason it gets talked about so much is that the effect is slow '
        'and then sudden. For the first few years it looks barely different '
        'from simple interest, and the gap widens the longer it runs, which '
        'is why time in it matters more than the amount you start with.\n\n'
        'It works exactly as hard against you on a debt that rolls over. A '
        'credit card balance carried month to month compounds in the same '
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
    body:
        'A credit card charges nothing if you pay the full statement amount '
        'by the due date. That is the whole trick, and it is the reason a '
        'card is either free or expensive with very little in between.\n\n'
        'Pay less than the full statement, even a peso less, and the finance '
        'charge usually applies to the whole balance rather than the unpaid '
        'part, and often from the transaction date rather than from the due '
        'date. New purchases can stop being interest free while a balance is '
        'being carried.\n\n'
        'The minimum payment is designed to keep the account current, not to '
        'clear it. Paying exactly the minimum on a balance that is charging '
        'a monthly rate can take years.\n\n'
        'Separately from the cost, how much of your limit you are using is '
        'something lenders look at. Under about 30 percent of the limit is '
        'the level commonly treated as comfortable. That is a rule of thumb '
        'and not a rule.',
    salapifyCanDo:
        'Add a card with its limit and its statement and due dates, and '
        'Salapify tracks the cutoff, the due date and how much of the limit '
        'is in use.',
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
    body:
        'An instalment plan turns one price into a monthly figure, and the '
        'monthly figure is what your brain compares against. That is the '
        'design. A thing you would not buy at its price often feels '
        'affordable at a twelfth of it.\n\n'
        'Zero interest is usually real and is rarely the whole cost. Look for '
        'a processing fee, a higher sticker price than the cash price, and '
        'whether the amount is blocked against your credit limit from day '
        'one.\n\n'
        'The risk that actually bites is stacking. Each plan is small and '
        'they all run at once, so the question is never whether you can '
        'afford this one. It is what your committed monthly total becomes '
        'once it is added to the others.',
    salapifyCanDo:
        'Record a plan and Salapify carries the remaining payments into what '
        'is already committed, so the total is a figure rather than a feeling.',
  ),
  PanExplainer(
    id: 'networth',
    asks: <String>['net worth', 'net asset'],
    title: 'Net worth',
    courseId: 'net-worth',
    body:
        'Net worth is everything you hold minus everything you owe. One '
        'number, and it is the only one that cannot be improved by moving '
        'money around.\n\n'
        'That is its whole value. Moving money from a bank to a wallet '
        'changes two balances and changes this not at all, and neither does '
        'paying a debt: an asset falls and a liability falls with it. What '
        'moves it is earning, spending, and interest.\n\n'
        'A negative figure is common and is not automatically a problem. One '
        'housing loan can do it, against a house that is also yours.',
    salapifyCanDo: 'Reports shows yours, and what is on each side of it.',
  ),
  PanExplainer(
    id: 'cashflow',
    asks: <String>['cash flow', 'cashflow'],
    title: 'Cash flow',
    courseId: 'cash-flow',
    body:
        'Cash flow is what actually arrives and what actually leaves, in the '
        'order it happens. It is a different question from whether you earn '
        'enough, and it is the one that causes the trouble.\n\n'
        'Somebody paid on the 15th and the 30th with rent due on the 1st and '
        'a card due on the 5th can be comfortable on paper and short in the '
        'last week of every month. Nothing is wrong with the total. The '
        'timing is wrong.\n\n'
        'Which is why the fix is usually about dates rather than about '
        'earning more: knowing what lands before the next payday changes what '
        'this fortnight is allowed to look like.',
    salapifyCanDo:
        'Safe to Spend holds back what is committed before your next payday, '
        'so the figure left is the one you can actually use.',
  ),
  PanExplainer(
    id: 'zerobased',
    asks: <String>['zero based budget', 'zero based budgeting', 'budgeting'],
    title: 'Budgeting, and zero-based budgeting',
    courseId: 'budgeting',
    body:
        'A budget is a decision made in advance, so that the decision is not '
        'made at the till. Most of what people call failing at budgeting is '
        'really never having decided.\n\n'
        'Zero-based means every peso that comes in is given a job before the '
        'month starts, including the jobs called savings and fun, until '
        'nothing is left unassigned. Nothing is left over by accident, '
        'because leftover money is the money that disappears.\n\n'
        'It is not about spending less on everything. It is about the '
        'spending being chosen rather than discovered.',
    salapifyCanDo:
        'Set a limit per category and Salapify shows how much of each is '
        'used as the month runs, not after it.',
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
    body:
        'Both are orders for paying off several debts at once. You pay the '
        'minimum on everything, and put whatever is spare against one chosen '
        'debt until it is gone, then roll that payment onto the next.\n\n'
        'Avalanche picks the debt with the highest rate first. It costs the '
        'least in total, by arithmetic, every time.\n\n'
        'Snowball picks the smallest balance first. It costs more, and it '
        'clears a whole debt sooner, which some people need in order to keep '
        'going. The cheaper method is only cheaper if you stay on it.\n\n'
        'The difference between them is usually smaller than the difference '
        'between doing one of them and doing neither.',
    salapifyCanDo:
        'The debt tools on the Plan tab run both against your own debts and '
        'show the months and the cost side by side.',
  ),
  PanExplainer(
    id: 'diversification',
    asks: <String>['diversification', 'diversify', 'dont put all your eggs'],
    title: 'Diversification',
    courseId: 'risk-return',
    body:
        'Diversification means not having everything depend on the same thing '
        'going well. Spread across enough different things and one of them '
        'going badly stops being the whole story.\n\n'
        'What it reduces is the risk specific to one company, one industry or '
        'one country. What it cannot reduce is the risk that affects '
        'everything at once, which is why a diversified holding still falls '
        'in a general downturn.\n\n'
        'It is also possible to own many things that are really the same '
        'thing wearing different names. The test is not how many holdings '
        'there are, it is whether they would fall together.',
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
    body:
        'The reason anything pays more than a savings account is that '
        'something about it can go wrong. Higher possible return and higher '
        'possible loss are two descriptions of the same feature, and anything '
        'offering the first without the second is either misunderstood or '
        'misrepresented.\n\n'
        'Two separate things get called risk tolerance. One is how you feel '
        'when a balance falls. The other is whether you could absorb the fall '
        'without it changing your life, which depends on when you need the '
        'money and what else you owe.\n\n'
        'The second one is the one that decides what is sensible, and it is '
        'measurable, while the first is a mood that changes with the news.',
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
    body:
        'Cost averaging means putting in a fixed amount on a fixed schedule '
        'rather than deciding each time. The same money buys more units when '
        'prices are low and fewer when they are high.\n\n'
        'What it is really for is removing the decision. Trying to pick the '
        'moment requires being right twice, and the cost of being wrong is '
        'paid in the years you spent waiting.\n\n'
        'It does not protect you from a long decline. It averages your entry '
        'price; it does not change what you bought.',
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
    body:
        'Insurance exists to move a loss you could not absorb onto somebody '
        'who can. That is the test for whether you need a particular policy: '
        'what happens to the people who depend on you, or to you, if the '
        'thing happens and nobody pays.\n\n'
        'Which means somebody with nobody depending on their income needs '
        'life cover far less than they are usually told, and somebody with '
        'children and a mortgage needs it far more.\n\n'
        'Term policies cover a period and pay only if the event happens in '
        'it. Policies that combine cover with an investment component do two '
        'jobs in one product, which makes the cost of each job harder to see '
        'and harder to compare. Neither is wrong; knowing which you are '
        'buying is the part that matters.',
  ),
  PanExplainer(
    id: 'utangnaloob',
    asks: <String>['utang na loob', 'family obligation', 'dampa'],
    title: 'Lending to family',
    courseId: 'family-obligations',
    body:
        'Money lent inside a family is rarely only money. It carries an '
        'expectation on both sides that neither says out loud, which is why '
        'it goes wrong so much more often than a bank loan does.\n\n'
        'The two things that cause the damage are both about vagueness: no '
        'date was agreed, and nobody wrote down the amount. Six months later '
        'two people remember two different numbers and both are sincere.\n\n'
        'Writing it down is not distrust. It is the thing that lets the '
        'relationship survive the loan, because it removes the argument '
        'before there is one.',
    salapifyCanDo:
        'Record it as a debt owed to you, with the amount and the date, and '
        'both of you can see the same figure.',
  ),
];
