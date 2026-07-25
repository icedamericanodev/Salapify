// The Salapify money courses: 22 short lessons in four tracks, each track
// ending in a real outcome and each lesson ending in one concrete action IN
// the app. Content is Flutter-owned since the 2026-07-24 course upgrade (the
// original 12 were ported from RN, then corrected and expanded after a
// financial-coach and CPA review; the lessons golden regenerates from THIS
// file via tool/regen_copy_goldens.dart).
//
// House rules, enforced by content tests: plain English sentences (identity
// nouns only in titles with a gloss beside them), no em or en dashes, no
// product, investment, loan, or stock recommendations, and every factual tax
// claim scoped with a visible PHILIPPINES tag (region: 'PH') plus an opening
// line so a global reader is never misled. Every lesson body follows one
// professional shape: why it matters, the idea in plain words, exactly how,
// then the one in-app action.
//
// Maintenance note: re-verify the three PH tax lessons every January (rates
// and deadlines drift); they were last verified for 2026 by the CPA review.

/// The four course tracks, in learning order. Each promises one outcome.
const List<Map<String, dynamic>> courseTracks = [
  {
    'key': 'cushion',
    'emoji': '🛟',
    'title': 'Your first cushion',
    'outcome': 'A payday saving habit and a funded starter emergency fund.',
  },
  {
    'key': 'debt',
    'emoji': '⛰️',
    'title': 'Debt zero',
    'outcome': 'Every debt logged and a payoff plan with a real finish date.',
  },
  {
    'key': 'swing',
    'emoji': '🌊',
    'title': 'Swing income survival',
    'outcome': 'A steady salary you pay yourself, and tax set aside on time.',
  },
  {
    'key': 'moments',
    'emoji': '🎁',
    'title': 'Big money moments',
    'outcome': 'A pre-decided plan for every bonus, raise, and lump sum.',
  },
];

const List<Map<String, dynamic>> lessons = [
  // ===================== TRACK 1: YOUR FIRST CUSHION =====================
  {
    'id': 'see-it-first',
    'track': 'cushion',
    'title': 'See it before you fix it',
    'emoji': '🔦',
    'minutes': 2,
    'summary': 'One week of honest logging changes more than any budget.',
    'objective': 'Find out where your daily spending actually goes.',
    'action': {'label': 'Log what you spent today', 'route': 'log'},
    'sections': [
      {
        'kind': 'context',
        'body': [
          'Most people can name their rent and their biggest bill, and still '
              'have no idea where the rest went. That is not carelessness. '
              'Small amounts do not feel like spending while they happen.',
          'A budget built on a guess fails in week two, because the guess was '
              'wrong. So start with the truth instead.',
        ],
      },
      {
        'kind': 'concept',
        'body': [
          'For seven days, write down everything, and change nothing. No '
              'cutting, no rules, no judgment. You are collecting facts, not '
              'grading yourself.',
          'Two things happen. Spending you watch shrinks on its own, because '
              'attention alone changes behavior. And at the end of the week '
              'you have a real daily number, which makes every lesson after '
              'this one work on your life instead of a template.',
        ],
      },
      {
        'kind': 'steps',
        'body': [
          'Log every expense for seven days, the day it happens.',
          'Change nothing about your spending yet.',
          'At the end of the week, look at your daily average.',
          'Pick the one pattern you would actually be glad to change.',
        ],
      },
      {
        'kind': 'example',
        'body': [
          'An office worker guessed they spent about 200 a day. After a week '
              'of logging it was closer to 340, and most of the gap was '
              'delivery fees and a daily coffee, neither of which felt like '
              'spending at the time.',
          'They did not quit either one. They moved coffee to three days a '
              'week and kept the rest, which is a change they could live with.',
        ],
      },
    ],
    'commonMistake':
        'Trying to fix your spending in the same week you start watching it. '
        'You end up doing neither properly, and one hard week tells you '
        'nothing about a normal one.',
    'check': {
      'question':
          'You are three days into logging and you notice you have spent more '
          'on food delivery than you expected. What is the most useful thing '
          'to do right now?',
      'choices': [
        'Stop ordering delivery immediately and restart the week.',
        'Keep logging normally and decide at the end of the week.',
        'Stop logging, since the answer is already obvious.',
      ],
      'answer': 1,
      'explanation':
          'The week is for measuring, not fixing. A full picture tells you '
          'how big the pattern really is, and a change you choose with the '
          'whole week in front of you is the one that sticks.',
      'whyWrong':
          'Cutting immediately feels productive, but it turns the week into '
          'an unusual one and hides your real normal.',
    },
    'takeaway':
        'You do not need a perfect budget. You need an honest starting point.',
    'body': [
      'You cannot steer money you cannot see. Most people guess their spending low, not because they lie, but because small amounts do not feel like spending while they happen.',
      'The fix is simple and short: log everything for seven days, with zero judgment. Not to cut anything yet. Just to see. Coffee, fare, load, the delivery fee, all of it, the day it happens.',
      'Two things follow. First, the log itself changes behavior; spending you watch shrinks on its own. Second, at the end of the week you will know your real daily number, and every lesson after this one works better when it starts from the truth.',
      'Start now, not Monday. The best first log is whatever you spent today.',
    ],
  },
  {
    'id': 'needs-wants',
    'track': 'cushion',
    'title': 'Needs, wants, and the 24-hour rule',
    'emoji': '🧠',
    'minutes': 1,
    'summary': 'A simple pause that saves real money on impulse buys.',
    'action': {
      'label': 'Run the impulse check in Money mindset',
      'route': 'mindset',
    },
    'body': [
      'A need keeps your life running: food, rent, transport, a working phone. A want is nice but optional. Most money leaks are wants dressed up as needs in the moment.',
      'The fix is not guilt, it is a pause. For anything that is not urgent, wait 24 hours. If you still want it tomorrow, and it fits your plan, buy it with a clear head. Most of the time the urge is gone by morning.',
      'Skipping a want is not being stingy. It is choosing where your money goes on purpose, so more of it lands on what you actually care about.',
      'The Money mindset screen has a three-question impulse check for exactly this moment. Use it on your next non-urgent buy.',
    ],
  },
  {
    'id': 'fifty-thirty-twenty',
    'track': 'cushion',
    'title': '50/30/20, adjusted for real life',
    'emoji': '🍚',
    'minutes': 2,
    'summary': 'A starting frame for splitting your pay.',
    'action': {
      'label': 'Set your monthly limit in Budget',
      'route': 'budget-tab',
    },
    'body': [
      'A simple way to divide your take-home pay: about 50 percent to needs, 30 percent to wants, and 20 percent to savings and paying down debt. It is a starting frame, not a rule carved in stone.',
      'Needs are rent, food, bills, transport. Wants are eating out, subscriptions, shopping, nights out. The last 20 percent is you paying your future self first: savings and clearing debt.',
      'If rent alone eats most of your pay, which is real for many people, do not force the numbers. Shrink wants first, protect even a small savings slice, and treat the split as a direction to move toward, not a test you failed.',
      'Salapify already sets aside your bills before it shows your safe to spend, so your daily number is closer to real life than a flat percentage.',
    ],
  },
  {
    'id': 'pay-yourself-first',
    'track': 'cushion',
    'title': 'Savings that actually stick',
    'emoji': '🐷',
    'minutes': 2,
    'summary': 'Why saving first beats saving whatever is left.',
    'action': {
      'label': 'Add a payday savings entry in Recurring',
      'route': 'recurring',
    },
    'body': [
      'Most people plan to save whatever is left at the end of the month. The problem is there is rarely anything left. The month always finds a way to spend it.',
      'Flip it. On payday, before the spending starts, move your savings out first, even a small fixed amount. This is pay yourself first. What is left is what you live on, and it works because you never see the saved money as spendable.',
      'Make it automatic and boring. Same amount, every payday, moved the same day. Willpower runs out, habits do not. Starting small and never skipping beats a big amount you cannot keep up.',
      'Set it up once as a recurring entry dated on your payday, and the habit runs itself.',
    ],
  },
  {
    'id': 'emergency-fund',
    'track': 'cushion',
    'title': 'Your first shield: the emergency fund',
    'emoji': '🛟',
    'minutes': 2,
    'summary':
        'Why a small cash buffer changes everything, and how to start one.',
    'action': {'label': 'Create your Emergency fund goal', 'route': 'goals'},
    'body': [
      'An emergency fund is money set aside for the surprises: a medical visit, a phone that dies, an urgent trip to family. It is not for a sale or a new gadget. Its whole job is to keep one bad week from turning into debt.',
      'A common target is three to six months of your expenses. That can feel impossible when you are starting, so do not aim there yet. Aim for your first week of expenses, then your first month. In the Philippines, 10,000 pesos is a classic first milestone; wherever you live, one week of your real expenses is the honest version of the same target.',
      'One important order-of-operations rule: if you carry high-interest debt, build only a small starter cushion first, then send everything extra at the debt. The "Cushion or debt: which comes first?" lesson in the Debt zero track walks through exactly why.',
      'Keep the fund separate from your spending money, ideally in an account you do not touch daily, so it is not accidentally spent. Make it a goal in Salapify and watch it grow. The point is not to get rich. It is to sleep better, because the next surprise is already handled.',
    ],
  },
  {
    'id': 'health-is-wealth',
    'track': 'cushion',
    'title': 'Health is wealth, literally',
    'emoji': '🩺',
    'minutes': 2,
    'summary': 'Why taking care of your body protects your money too.',
    'action': {'label': 'Add a Health fund goal', 'route': 'goals'},
    'body': [
      'The fastest way to lose years of savings is one serious illness. A hospital stay, a maintenance medicine, an emergency operation, these can wipe out savings that took a long time to build. Looking after your health is not separate from your money, it is part of it.',
      'The cheapest health money you will ever spend is the amount that prevents a big bill later. A checkup that catches something early, staying active, sleeping enough, eating a little better. The payoff is invisible on purpose: it is the crisis that never happened.',
      'Two shields work together. The first is your emergency fund, money ready for the surprise. The second is your health itself, which decides how often the surprise comes. Salapify tracks the money shield for you on Insights, as your emergency fund runway.',
      'Check what cover you already have. In the Philippines, PhilHealth shoulders part of a hospital bill and an HMO from your job covers more. Wherever you live, learn what your public health insurance and your employer plan already pay for, then set a small Health fund goal for the rest, so a checkup or a medicine is a planned cost, not a panic.',
      'Spending on your health is nothing to feel guilty about. A doctor, decent food, real rest, these are among the smartest money you spend, because they lower the odds of the one bill big enough to hurt.',
    ],
  },

  // ========================= TRACK 2: DEBT ZERO ==========================
  {
    'id': 'card-interest',
    'track': 'debt',
    'title': 'The minimum payment trap',
    'emoji': '💳',
    'minutes': 2,
    'summary': 'How paying only the minimum quietly grows what you owe.',
    'action': {
      'label': 'Log your cards in Debts, with rates and due dates',
      'route': 'debts',
    },
    'body': [
      'A credit card gives you a grace period. Pay the full statement balance by the due date and you pay zero interest. That is the deal working in your favor.',
      'The trap is the minimum payment. It is usually a small slice of your balance, often around 3 to 5 percent. Pay only that and you lose the interest-free grace period, so interest, often 2 to 4 percent PER MONTH (in the Philippines the cap is 3 percent, a central bank rule), applies to your balance including new purchases. Next month you owe interest on the interest. This is how a small balance quietly becomes a big one.',
      'The rule: pay in full whenever you can. If a month is tight, pay as much above the minimum as possible. Even a little extra shrinks the balance faster than you think, because it all lands on the principal.',
      'Log each card in Salapify with its rate and due date. The app reminds you before the due date so you can pay in full and stay in the interest-free zone.',
    ],
  },
  {
    'id': 'bnpl',
    'track': 'debt',
    'title': 'BNPL: convenient, but count the cost',
    'emoji': '🛒',
    'minutes': 2,
    'summary': 'Buy now pay later can help or hurt. Know which.',
    'action': {
      'label': "Check an installment's true cost",
      'route': 'tools-bnpl',
    },
    'body': [
      'Buy now pay later splits a purchase into installments. Used carefully on something you were already going to buy, and can afford, it can spread a cost without pain.',
      'The risk is that it makes spending feel smaller than it is. Three or four small installments across different apps add up, and you can lose track of the total you owe. Miss a due date and fees or interest appear fast.',
      'Two tests before you tap install. One: would you still buy this if you had to pay the full price today? If not, the installments are talking you into it. Two: would all your installments together still fit inside one paycheck? Never let them pile past that line.',
      'Run the Installment true cost tool on your current plan to see what it really costs, then log every BNPL as a debt in Salapify so the real total and every due date stay in front of you instead of scattered across apps.',
    ],
  },
  {
    'id': 'snowball-avalanche',
    'track': 'debt',
    'title': 'Snowball or avalanche: pick your path',
    'emoji': '🏔️',
    'minutes': 2,
    'summary': 'Two proven payoff orders, and how to choose with real numbers.',
    'action': {'label': 'Compare both plans in Debts', 'route': 'debts'},
    'body': [
      'When you owe on more than one thing, the order you attack them in matters. There are two proven orders, and either one beats drifting.',
      'The snowball: pay minimums on everything, then throw every spare peso at the SMALLEST balance first. Each debt you finish is a win you can feel, and the freed-up payment rolls into the next one like a snowball. It wins on motivation.',
      'The avalanche: same idea, but attack the HIGHEST interest rate first. Mathematically this always costs less in total interest. It wins on money.',
      'Which is right? The one you will actually stick with. If you need visible wins to keep going, snowball. If the interest number motivates you, avalanche. Salapify computes both orders from your real debts; flip between them in Debts to compare the finish date and total interest, so you choose with numbers instead of vibes.',
    ],
  },
  {
    'id': 'cushion-or-debt',
    'track': 'debt',
    'title': 'Cushion or debt: which comes first?',
    'emoji': '⚖️',
    'minutes': 2,
    'summary':
        'The ordering rule that saves the most money of any in this app.',
    'action': {
      'label': 'Check your Emergency fund goal target',
      'route': 'goals',
    },
    'body': [
      'Here is a trap that catches careful people: parking a full month of savings in an emergency fund while a credit card charges 3 percent A MONTH. The fund earns nothing; the card compounds. Every month that money sits still, the debt eats more than the cushion protects.',
      'But going all-in on debt with zero cushion fails too. The first surprise, a medicine, a repair, forces you to borrow again, and the cycle restarts. You need both, in the right order.',
      'The order that works: first, a small STARTER cushion, one or two weeks of expenses, just enough that a normal surprise does not create new debt. Second, every spare peso at the highest-interest debt until it is gone. Third, now grow the fund to one month, then three, in peace.',
      'Check your Emergency fund goal: if you carry high-interest debt and the goal target is set at months of expenses, shrink the target to the starter size for now, and point the difference at the debt. The full cushion comes later, and cheaper.',
    ],
  },
  {
    'id': 'extra-payment',
    'track': 'debt',
    'title': 'Find your extra payment',
    'emoji': '🔎',
    'minutes': 2,
    'summary': 'One small fixed extra moves the finish date by months.',
    'action': {
      'label': 'Try an extra payment in Insights',
      'route': 'insights-tab',
    },
    'body': [
      'Debt payoff is not linear, and that is good news. Because interest compounds, a small extra payment early is worth much more than the same amount later. The math is on your side once you push past the minimums.',
      'Find one fixed amount you can add every single month. One cancelled subscription. One downgraded plan. One want from the 24-hour-rule lesson that did not survive the night. It does not need to be big; it needs to be permanent.',
      'Then watch what it does. On a typical card balance, even a modest fixed extra can pull the finish date months closer and cut the total interest by more than the extra itself. That is the compounding working for you instead of against you.',
      'Open Insights and find the debt what-if card. It shows what a fixed extra, like 200, 500, or 1000 a month, does to your finish date and total interest. Seeing those two numbers move is the best motivation there is.',
    ],
  },
  {
    'id': 'utang-friends',
    'track': 'debt',
    'title': 'Utang without losing the friendship',
    'emoji': '🤝',
    'minutes': 2,
    'summary': 'Lending to people you care about, the healthy way.',
    'action': {'label': 'Log who owes you in Utang', 'route': 'utang-tab'},
    'body': [
      'Lending inside the family and the barkada, the friend group, is part of Filipino life, and informal lending exists everywhere in the world. It goes wrong the same way everywhere too: the amount, and the memory of it, gets fuzzy. Then both the money and the relationship get awkward.',
      'Two habits keep it clean. First, only lend what you would be okay never getting back. Not "not getting back soon". Never. If losing it would put you in a bind, the honest answer is a smaller amount or a kind no. Second, write it down, the amount and the date, the moment it happens, so nobody has to rely on memory.',
      'Following up is not being stingy. A calm, friendly reminder is normal and fair, and it actually protects the friendship, because unspoken debt is what breeds resentment.',
      'Salapify tracks who owes you and how long it has been, and Ask Pan can draft a gentle reminder you can copy and send, so collecting stays kind.',
    ],
  },

  // ==================== TRACK 3: SWING INCOME SURVIVAL ====================
  {
    'id': 'steady-salary',
    'track': 'swing',
    'title': 'Pay yourself a salary',
    'emoji': '🌊',
    'minutes': 2,
    'summary': 'The one move that makes a swing income livable.',
    'action': {'label': 'Set Steady Pay in Insights', 'route': 'insights-tab'},
    'body': [
      'When your income swings, the danger is not the lean months. It is the good ones. A big month quietly raises your lifestyle, and then the next lean month cannot carry it.',
      'The move that fixes this: stop spending your income and start paying yourself a salary from it. Look at your three LEANEST months out of the last six, and pay yourself that, a fixed weekly amount, whatever the month brings.',
      'Good months then do their real job: they fill a buffer that carries the lean ones. Your lifestyle rides the floor, not the ceiling, so it never has to fall. That is the whole secret of surviving on a swing income, and salaried people get it for free without noticing.',
      'Salapify computes this from your own logged income. Open Insights and set Steady Pay; the app suggests the lean-month weekly amount and then tracks each week against it. The suggestion appears once about three months of income are logged, so if it is not there yet, keep logging; it is worth the wait.',
    ],
  },
  {
    'id': 'lean-month-plan',
    'track': 'swing',
    'title': 'The lean month plan',
    'emoji': '🗓️',
    'minutes': 2,
    'summary': 'Every swing income has a famine month. Make yours boring.',
    'action': {'label': 'See your months in Cash flow', 'route': 'cashflow'},
    'body': [
      'Every seasonal or gig income has a famine month. Drivers know the slow season, sellers know the month after the holidays, freelancers know the client drought. The month is not the problem. Being surprised by it is.',
      'Find yours. Look back over your last six months and name the worst one, and by how much it fell short of your normal spending. That gap is a number, and a number can be planned for.',
      'Pre-fund the gap. Set aside a slice of every good month into a lean-month buffer sized to that gap, separate from your emergency fund (that one is for surprises; this one is for a certainty with a fuzzy date).',
      'When the famine month arrives and the buffer quietly covers it, something changes: the month becomes boring. Boring is the goal. Open Cash flow to see your months side by side and put a number on your gap.',
    ],
  },
  {
    'id': 'freelancer-setaside',
    'track': 'swing',
    'region': 'PH',
    'title': 'Selling online or freelancing? Set aside for tax',
    'emoji': '💼',
    'minutes': 2,
    'summary':
        'The simple habit that keeps a sideline or small business out of tax trouble.',
    'action': {
      'label': 'Compare 8 percent vs graduated in Tools',
      'route': 'tools-tax',
    },
    'body': [
      'The set-aside habit in this lesson works in every country; the rates and forms are Philippine (BIR, 2026 rules). If you pay tax elsewhere, keep the habit and swap in your own numbers.',
      'When no employer withholds tax for you, the discipline is yours. The freelancers and sellers who never panic at deadline are the ones who treat a slice of every payment as not theirs. When a client pays, move a small part aside the same day, before it starts to feel like spending money.',
      'How big a slice? On the flat 8 percent option, available if your sales stay within 3,000,000 a year and you are not VAT registered, set aside 8 percent of every peso from the start. One rule matters here: if freelancing is your ONLY income, your first 250,000 for the year is tax free, so the early set aside builds a buffer. If you ALSO earn a salary, the whole sideline amount is taxed at 8 percent, no 250,000 deduction, so the set aside is not a buffer, it is the bill. On the graduated option it depends on your income and real expenses. The Income tax calculator in Tools shows both estimates side by side for your own numbers.',
      'The rhythm is quarterly, not just once a year: income tax every quarter and again at year end, plus percentage tax each quarter unless you are on the 8 percent. Miss a deadline and the BIR adds a surcharge and interest. Write your next deadline where you will see it, in Notes, so nothing sneaks up.',
      'One timing trap: the 8 percent rate is not automatic. You choose it on time, at registration or on your first quarter return, and it is locked for the whole year. This is awareness, not tax advice, and Salapify does not file anything for you. Confirm with the BIR or a licensed accountant.',
    ],
  },
  {
    'id': 'tax-forms',
    'track': 'swing',
    'region': 'PH',
    'title': 'Which tax forms do I actually file?',
    'emoji': '🧾',
    'minutes': 3,
    'summary':
        'A plain map of BIR returns for employees, freelancers, and the self-employed.',
    'action': {'label': 'Write your next deadline in Notes', 'route': 'notes'},
    'body': [
      'These are Philippine tax forms (BIR, 2026 rules). If you file elsewhere, skip the form names but keep the habit: know which returns are yours, keep every proof of tax already paid, and never miss a quarter.',
      'If you are an employee with just one job, good news, you usually file nothing yourself. Your employer takes the tax from your salary, remits it, and gives you Form 2316 every January. That shortcut is called substituted filing.',
      'You do need to file your own return, Form 1700, if you had two or more employers during the year, if your tax was not withheld correctly, or if you also run a sideline. A sideline makes you a mixed income earner, and then you file Form 1701 instead.',
      'If you are a freelancer, online seller, or professional, you register once with Form 1901. There is no more 500 peso yearly registration fee, it was removed in 2024 by the Ease of Paying Taxes law, so ignore old guides that still mention it.',
      'As self-employed you pay income tax quarterly on Form 1701Q, due May 15, August 15, and November 15, then once a year on Form 1701 or 1701A by April 15. Take note, the first quarter is due in May, not April. A quarter with zero income still means you file, just with nothing to pay.',
      'Percentage tax is a separate 3 percent tax on your sales, filed each quarter on Form 2551Q. If you chose the 8 percent flat rate, you skip this one, because the 8 percent already covers both your income tax and this. But the 8 percent is not automatic, you must choose it on time and it is locked for the whole year.',
      'If clients withhold tax from your fees, they hand you Form 2307. Keep every single one. It is tax you already paid, and it lowers your bill at year end. Throwing them away means paying twice.',
      'Cross 3,000,000 pesos in sales in any 12 month period and you move into VAT at 12 percent, filed on Form 2550Q each quarter. That is a bigger topic, so get an accountant before you reach that line.',
      'This is awareness, not tax advice, and Salapify does not file anything for you. Deadlines can shift when they land on a weekend or holiday, so confirm with the BIR or a licensed accountant before you file.',
    ],
  },
  {
    'id': 'own-your-benefits',
    'track': 'swing',
    'region': 'PH',
    'title': 'Nobody pays your benefits but you',
    'emoji': '🧱',
    'minutes': 2,
    'summary':
        'Freelance means your future contributions stopped, unless you restart them.',
    'action': {
      'label': 'Run the Contribution checker',
      'route': 'tools-contrib',
    },
    'body': [
      'This lesson covers Philippine contributions (SSS, PhilHealth, Pag-IBIG). If you live elsewhere, the principle still holds: when you leave employment, find out which social protections stopped, and restart the ones that matter.',
      'When you had an employer, three things were quietly being paid for you every month: SSS toward your pension and sickness benefits, PhilHealth toward hospital bills, and Pag-IBIG toward savings and housing. The day you went freelance, all three stopped, unless you restarted them yourself as a voluntary member.',
      'The cruel part of a lapse is the timing: contributions matter exactly when you are sick, giving birth, or old, which is precisely when you cannot fix a gap retroactively. A missing year of SSS contributions can lower a pension decades from now; a PhilHealth lapse shows up at the hospital cashier.',
      'The fix is mechanical, not hard: register as a voluntary or self-employed member, know your monthly amounts, and pay them like a bill, not a choice. Run the Contribution checker in Tools to see the current amounts for your income level, then log them as a recurring expense so they leave with every payday, automatically.',
    ],
  },

  // ===================== TRACK 4: BIG MONEY MOMENTS ======================
  {
    'id': 'windfall-rule',
    'track': 'moments',
    'title': 'Decide before it lands',
    'emoji': '🎯',
    'minutes': 2,
    'summary': 'The universal rule for bonuses, refunds, and lump sums.',
    'action': {'label': 'Plan a windfall in Insights', 'route': 'insights-tab'},
    'body': [
      'A lump sum, a bonus, a refund, a gift, a payout, has a strange property: it disappears faster than the same amount earned slowly. It feels like extra, so it gets spent like extra, and a month later there is nothing to point at.',
      'The fix is one rule: decide the split BEFORE the money arrives. After it lands, the mall decides for you.',
      'The proven split has three slices. One slice to the highest-interest debt you carry, because every peso of interest you stop paying is a peso kept. One slice to a goal, your cushion or whatever you are building. And one slice, guilt free, for something you enjoy, because a plan with zero joy in it gets abandoned.',
      'The exact percentages matter less than deciding them in advance. When you know money is coming, open Insights and plan the split in the windfall planner, then the day it lands, log it and point each slice where it already belongs.',
    ],
  },
  {
    'id': 'thirteenth-month',
    'track': 'moments',
    'region': 'PH',
    'title': 'Make your 13th month count',
    'emoji': '🎁',
    'minutes': 2,
    'summary': 'A plan for the once-a-year money so it does not vanish.',
    'action': {
      'label': 'Run the 13th month calculator',
      'route': 'tools-thirteenth',
    },
    'body': [
      'In the Philippines, rank-and-file employees get an extra month of pay in December, the 13th month. If your country pays a year-end bonus or holiday pay instead, the exact same plan works.',
      'The 13th month feels like free money, so it disappears the fastest. A little planning before it lands makes it do real work for you.',
      'One simple split: a slice to your emergency fund or savings, a slice to clear the highest-interest debt you carry, and a slice, guilt free, for the holidays and the people you love. Deciding the split before the money arrives is the whole trick.',
      'Clearing a high-interest debt with part of it is one of the best uses of the money, because every peso of interest you stop paying is a peso kept. And a nice-to-know: in the Philippines the 13th month plus other bonuses are tax free up to 90,000 combined, which the calculator already accounts for.',
      'Run the 13th month pay calculator to see your amount, then point each slice at a goal or a debt in the app, so future you gets a share too.',
    ],
  },
  {
    'id': 'year-end-refund',
    'track': 'moments',
    'region': 'PH',
    'title': 'Getting your year-end tax refund',
    'emoji': '💵',
    'minutes': 2,
    'summary':
        'Why many employees get money back in December, and how to make sure you do.',
    'action': {
      'label': 'Sanity-check your take-home pay in Tools',
      'route': 'tools-salary',
    },
    'body': [
      'This lesson covers Philippine employer withholding (BIR, 2026 rules). Elsewhere the mechanics differ, but the idea travels: withheld tax is an estimate, and year end is when the estimate gets corrected.',
      'Every payday your employer takes a slice of your pay for income tax, based on a guess of what you will earn for the whole year. At year end they add up what you really earned and compare it to what they already took. If they took too much, the extra comes back to you as a refund, usually in your December or January pay.',
      'Why would they take too much? You started partway through the year, so the monthly guess assumed twelve months you did not work. Your pay changed during the year. Your bonuses stayed within the tax-free ceiling but a little was still withheld along the way. Any of these can mean money is owed back to you.',
      'You usually do not file anything for this yourself. One employer all year with correct withholding means your employer settles it, a shortcut called substituted filing, and the refund arrives in your pay.',
      'Changing jobs is where it gets tricky. Two employers in one year, even one after the other, means substituted filing is off and you file your own annual return, BIR Form 1700, by April 15. Give your new employer the Form 2316 from your old job so they add up your year correctly, and keep both 2316s. Skip these and you can end up under withheld, owing a little plus a penalty instead of getting a refund.',
      'This is awareness, not tax advice, and not everyone gets money back. To see roughly where you stand, run the Take-home pay calculator in Tools against your payslip, then confirm with your HR or the BIR.',
    ],
  },
  {
    'id': 'raise-rule',
    'track': 'moments',
    'title': 'When your pay goes up',
    'emoji': '📈',
    'minutes': 1,
    'summary':
        'Beat lifestyle creep with one decision on the first new payday.',
    'action': {
      'label': 'Raise your payday savings in Recurring',
      'route': 'recurring',
    },
    'body': [
      'Lifestyle creep is silent. A raise arrives, spending drifts up to meet it, and six months later the bigger salary feels exactly as tight as the old one. Nothing was decided; it just happened.',
      'The countermove takes one decision, made once: commit half of every raise to savings or debt, starting on the FIRST payday at the new rate, before the bigger number starts to feel normal. You still get the other half, so life visibly improves, and your future quietly improves twice as fast.',
      'This works because you are splitting money you have never lived on. Cutting spending you are used to feels like loss; directing money you never touched feels free. Same pesos, completely different fight.',
      'The day a raise lands, open Recurring and increase your payday savings entry by half the difference. One edit, and the creep never starts.',
    ],
  },
  {
    'id': 'savings-circles',
    'track': 'moments',
    'title': 'Savings circles, without the heartbreak',
    'emoji': '🔄',
    'minutes': 2,
    'summary':
        'Paluwagan, susu, tanda, chit funds: what they are and the one risk.',
    'action': {'label': 'Track your circle in Paluwagan', 'route': 'paluwagan'},
    'body': [
      'A rotating savings circle, called paluwagan in the Philippines, susu in the Caribbean, tanda in Mexico, a chit fund in India, exists in nearly every culture, because it solves a real problem: saving alone is easy to quit, and saving with your group is not.',
      'The mechanics are simple. Everyone contributes a fixed amount each cycle, and each cycle one member takes the whole pot, in turns. Over a full round everyone pays in and receives exactly the same total. It is forced discipline at zero interest, powered by not wanting to let your people down.',
      'Two honest truths. First, an early turn is an interest-free advance, and a late turn is forced saving; know which you have and treat it accordingly. Second, the entire risk is the organizer and the group. There is no bank, no guarantee, only trust, so join circles run by people you would lend to anyway, and treat your payout as a planned windfall: decide its split before your turn arrives.',
      'Track every contribution and your payout date in the Paluwagan tracker, so your turn and your standing are always numbers, never a guess.',
    ],
  },
];

/// The lesson to feature today, rotating by day of year so it is stable for a
/// whole day and cycles over time.
Map<String, dynamic> lessonOfTheDay(DateTime ref) {
  final start = DateTime(ref.year, 1, 0);
  final dayOfYear = (ref.difference(start).inMilliseconds / 86400000).floor();
  return lessons[dayOfYear % lessons.length];
}

/// The lesson with this id, or null.
Map<String, dynamic>? lessonById(String id) {
  for (final l in lessons) {
    if (l['id'] == id) return l;
  }
  return null;
}

/// The lessons of one track, in file (learning) order.
List<Map<String, dynamic>> lessonsForTrack(String key) => [
  for (final l in lessons)
    if (l['track'] == key) l,
];
