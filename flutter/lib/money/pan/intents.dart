// Pan's intent registry and matcher, ported 1:1 from
// mobile/lib/pan/intents.js. Data, not logic: guardrails first (they can
// never leak into a data answer), then keyword-scored intents with a cheap
// one-edit fuzzy pass for typos. Golden-verified against the real RN
// module.

class Guardrail {
  final String id;
  final List<String> keywords;
  final String reply;
  final Map<String, String>? cta;
  const Guardrail(this.id, this.keywords, this.reply, [this.cta]);
}

const List<Guardrail> guardrails = [
  Guardrail(
    'no_invest',
    [
      'invest',
      'stocks',
      'stock market',
      'crypto',
      'bitcoin',
      'forex',
      'mutual fund',
      'uitf',
      'mp2',
      'trading',
      'shares',
      'good return',
      'grow my money',
      'where to invest',
      'good investment',
    ],
    'I do not give investment advice, that needs a licensed professional. What I can do is show you exactly how much you can set aside, so you decide with clear numbers. Want your safe to spend, or how a goal is pacing?',
  ),
  Guardrail(
    'no_loan',
    [
      'apply for a loan',
      'get a loan',
      'cash loan',
      'borrow money',
      'lend me',
      'loan app',
      'where to borrow',
      'sangla',
    ],
    'I cannot help you find or apply for a loan. But if you are weighing one, the Loan calculator in Tools shows its real monthly payment and true interest rate, so you go in with clear eyes. I can also track debts you already have.',
    {'label': 'Open Loan calculator', 'route': '/loan-calculator'},
  ),
  Guardrail(
    'no_tax',
    ['tax', 'bir', 'income tax', 'vat', 'withholding'],
    'I cannot give tax advice, please check the BIR or a tax professional for your actual filing. What I can do is point you to the Income tax calculator in Tools, which estimates the 8% versus graduated tax and lists the BIR forms you file.',
    {'label': 'Open Income tax calculator', 'route': '/tax-calculator'},
  ),
  Guardrail(
    'no_legal',
    [
      'sue',
      'small claims',
      'estafa',
      'legal',
      'lawyer',
      'demand letter',
      'contract',
    ],
    'I cannot give legal advice. For money owed to you, what I can do is help you write a polite reminder and track what is owed. Want to see who owes you?',
  ),
  Guardrail(
    'no_insurance',
    ['insurance', 'vul', 'life plan', 'health card', 'hmo'],
    'I do not recommend insurance products. A good first shield is an emergency fund sized to your monthly expenses, and I can help you build toward that as a goal.',
  ),
];

class Intent {
  final String id;
  final String title;
  final String? resolve;
  final Map<String, String>? pointer; // {route, label, text}
  final List<String> strong;
  final List<String> any;
  final List<String> examples;
  const Intent({
    required this.id,
    required this.title,
    this.resolve,
    this.pointer,
    required this.strong,
    required this.any,
    required this.examples,
  });
}

const List<Intent> intents = [
  Intent(
    id: 'safe_to_spend',
    title: 'Safe to spend',
    resolve: 'safeToSpend',
    strong: [
      'safe to spend',
      'how much can i spend',
      'spend today',
      'until payday',
      'spend until',
    ],
    any: [
      'spend',
      'afford',
      'left to spend',
      'howmuch left',
      'baon',
      'budget left',
    ],
    examples: ['How much can I safely spend?', 'What is safe to spend today?'],
  ),
  Intent(
    id: 'can_afford',
    title: 'Can I afford this',
    resolve: 'canAfford',
    strong: ['can i afford', 'can i buy', 'should i buy', 'afford this'],
    any: ['afford', 'buy', 'bili'],
    // One English example only: chips surface examples.first, and a dormant
    // Tagalog example here could resurface if a future consumer read more.
    // Pan still UNDERSTANDS Tagalog questions through the matchers.
    examples: ['Can I afford 2000 shoes?'],
  ),
  Intent(
    id: 'utang',
    title: 'Who owes me',
    resolve: 'utang',
    strong: [
      'who owe me',
      'who owes me',
      'who owe',
      'follow up',
      'utang list',
      'collect',
    ],
    any: ['owe', 'owes', 'receivable', 'niningil', 'pautang'],
    examples: ['Who owes me money?', 'Who should I follow up first?'],
  ),
  Intent(
    id: 'upcoming_bills',
    title: 'What is due',
    resolve: 'upcomingBills',
    strong: [
      'what is due',
      'whats due',
      'upcoming bills',
      'bills due',
      'anong bills',
    ],
    any: ['bills', 'due', 'bayarin', 'payables'],
    examples: ["What's due before payday?", 'What bills are due soon?'],
  ),
  Intent(
    id: 'debt_due',
    title: 'Card and debt due dates',
    resolve: 'debtDue',
    strong: [
      'card due',
      'when is my card',
      'debt due',
      'when to pay',
      'pay in full',
    ],
    any: ['card', 'debt', 'credit', 'minimum', 'statement'],
    examples: ['When is my credit card due?', 'How much is due on my card?'],
  ),
  Intent(
    id: 'debt_free',
    title: 'Debt-free date',
    resolve: 'debtFree',
    strong: [
      'debt free',
      'pay off',
      'payoff',
      'when will i be debt',
      'finish debt',
      'finish my debt',
      'if i add',
      'how long to pay',
    ],
    any: [
      'payoff',
      'clear debt',
      'matatapos utang',
      'add extra',
      'a month to my',
    ],
    examples: ['When will I be debt-free?', 'If I add 1000 a month?'],
  ),
  Intent(
    id: 'month_recap',
    title: 'My month',
    resolve: 'recap',
    strong: [
      'my month',
      'recap',
      'how was my month',
      'how am i doing',
      'how spending',
      'summary',
    ],
    any: ['month', 'kumusta', 'buod'],
    examples: ['How was my month?', 'How did I do this month?'],
  ),
  Intent(
    id: 'top_spending',
    title: 'Where my money goes',
    resolve: 'topSpending',
    strong: [
      'am i overspending',
      'where does my money go',
      'biggest spending',
      'top spending',
      'saan napupunta',
      'overspending',
    ],
    any: ['category', 'spending', 'gastos', 'napupunta'],
    examples: ['Am I overspending on food?', 'Where does my money go?'],
  ),
  Intent(
    id: 'forecast',
    title: 'Month-end forecast',
    resolve: 'forecast',
    strong: [
      'will i go over',
      'over budget',
      'end of month',
      'forecast',
      'lalagpas',
    ],
    any: ['budget', 'projected', 'reach'],
    examples: ['Will I go over budget?', 'Lalagpas ba ako this month?'],
  ),
  Intent(
    id: 'savings_rate',
    title: 'Am I saving enough',
    resolve: 'savingsRate',
    strong: [
      'am i saving',
      'savings rate',
      'how much did i save',
      'saving enough',
    ],
    any: ['save', 'savings', 'ipon'],
    examples: ['Am I saving enough?', 'Nakakaipon ba ako?'],
  ),
  Intent(
    id: 'goal_pace',
    title: 'My goals',
    resolve: 'goalPace',
    strong: [
      'my goal',
      'will i hit my goal',
      'on track',
      'goal pace',
      'save for',
    ],
    any: ['goal', 'target', 'fund'],
    examples: ['Will I hit my goal?', 'On track ba ako sa goal ko?'],
  ),
  Intent(
    id: 'health',
    title: 'Money health score',
    resolve: 'health',
    strong: [
      'health score',
      'how healthy',
      'financial health',
      'money health',
      'overall',
    ],
    any: ['score', 'healthy'],
    examples: ['How healthy is my money?', "What's my money score?"],
  ),
  Intent(
    id: 'balances',
    title: 'My balances',
    resolve: 'balances',
    strong: [
      'how much do i have',
      'my balance',
      'total money',
      'net worth',
      'howmuch i have',
      'howmuch money',
      'how much do i owe',
      'howmuch i owe',
      'total debt',
      'how much i owe',
      'how much debt',
    ],
    any: ['balance', 'money', 'cash', 'total'],
    examples: ['How much do I have?', 'What is my total balance?'],
  ),
  Intent(
    id: 'payday',
    title: 'Next payday',
    resolve: 'payday',
    strong: [
      'when is payday',
      'when payday',
      'next sweldo',
      'when sweldo',
      'payday countdown',
    ],
    any: ['payday', 'sweldo', 'sahod'],
    examples: ['When is my next payday?', 'How many days until payday?'],
  ),
  Intent(
    id: 'tool_take_home',
    title: 'Take-home pay',
    pointer: {
      'route': '/salary-calculator',
      'label': 'Open Take-home pay',
      'text':
          'To turn a gross salary into net, the Take-home pay calculator in Tools does it properly, with SSS, PhilHealth, Pag-IBIG, tax, and allowances, and can show it per cutoff, monthly, or yearly.',
    },
    strong: [
      'take home',
      'take home pay',
      'net pay',
      'net salary',
      'gross to net',
    ],
    any: ['takehome', 'deductions from salary'],
    examples: ['What is my take-home pay?', 'Gross to net salary'],
  ),
  Intent(
    id: 'tool_thirteenth',
    title: '13th month pay',
    pointer: {
      'route': '/thirteenth-calculator',
      'label': 'Open 13th month pay',
      'text':
          'For 13th month pay, the calculator in Tools figures what you should get, prorated for months worked, and shows the tax-free part up to the 90,000 ceiling.',
    },
    strong: ['13th month', '13 month', 'thirteenth month', '13th month pay'],
    any: ['13th', 'bonus'],
    examples: ['How much is my 13th month?', 'Compute 13th month pay'],
  ),
  Intent(
    id: 'tool_contributions',
    title: 'SSS, PhilHealth, Pag-IBIG',
    pointer: {
      'route': '/contribution-calculator',
      'label': 'Open Contribution checker',
      'text':
          'For your monthly SSS, PhilHealth, and Pag-IBIG, the Contribution checker in Tools shows what comes out of your pay, what your employer adds, and the total, for any salary.',
    },
    strong: [
      'sss',
      'philhealth',
      'phil health',
      'pag ibig',
      'pagibig',
      'contribution',
      'contributions',
    ],
    any: ['hdmf', 'sss contribution', 'monthly contribution'],
    examples: ['How much is my SSS?', 'PhilHealth and Pag-IBIG for 25000'],
  ),
  Intent(
    id: 'tool_loan_cost',
    title: 'Loan cost',
    pointer: {
      'route': '/loan-calculator',
      'label': 'Open Loan calculator',
      'text':
          'To see the real cost of a loan, the Loan calculator in Tools shows the monthly payment, total interest, and the true effective rate, so an add-on quote cannot hide how much it really costs.',
    },
    strong: [
      'amortization',
      'monthly amortization',
      'loan calculator',
      'effective rate',
      'true cost of a loan',
    ],
    any: ['amortize', 'add on rate'],
    examples: ['Monthly amortization of a loan', 'True cost of a loan'],
  ),
];

const String helpId = 'help';

/// True when a and b differ by at most one edit: a substitution, one
/// adjacent transposition, or one insert or delete.
bool within1Edit(String a, String b) {
  if (a == b) return true;
  final la = a.length, lb = b.length;
  if ((la - lb).abs() > 1) return false;
  if (la == lb) {
    final diff = <int>[];
    for (var i = 0; i < la; i++) {
      if (a[i] != b[i]) diff.add(i);
    }
    if (diff.length == 1) return true;
    return diff.length == 2 &&
        diff[1] == diff[0] + 1 &&
        a[diff[0]] == b[diff[1]] &&
        a[diff[1]] == b[diff[0]];
  }
  final s = la < lb ? a : b;
  final l = la < lb ? b : a;
  var i = 0, j = 0, skips = 0;
  while (i < s.length && j < l.length) {
    if (s[i] == l[j]) {
      i++;
      j++;
    } else if (++skips > 1) {
      return false;
    } else {
      j++;
    }
  }
  return true;
}

int _scoreIntent(String norm, List<String> tokens, Intent intent) {
  var score = 0;
  for (final kw in intent.strong) {
    if (norm.contains(kw)) score += 3;
  }
  for (final kw in intent.any) {
    if (norm.contains(kw)) score += 1;
  }
  final kwTokens = <String>{};
  for (final kw in [...intent.strong, ...intent.any]) {
    for (final t in kw.split(' ')) {
      if (t.length >= 4) kwTokens.add(t);
    }
  }
  for (final t in tokens) {
    if (t.length < 4) continue;
    for (final kt in kwTokens) {
      if (within1Edit(t, kt)) {
        score += 1;
        break;
      }
    }
  }
  return score;
}

/// A guardrail keyword must hit on a whole-word boundary, never as a
/// substring, or "taxi" trips the tax rail and "birthday" the BIR rail. A
/// limited suffix set still catches taxes, investing, investments.
bool _wordHit(String norm, String kw) {
  final esc = RegExp.escape(kw);
  return RegExp(
    '(?:^|[^a-z0-9])$esc(?:s|es|ing|ment|ments)?(?![a-z0-9])',
  ).hasMatch(norm);
}

/// detectIntent(normalized) -> { id, guardrail?, score, alternatives }.
Map<String, dynamic> detectIntent(String norm) {
  for (final g in guardrails) {
    if (g.keywords.any((k) => _wordHit(norm, k))) {
      return {
        'id': g.id,
        'guardrail': g,
        'score': 99,
        'alternatives': const [],
      };
    }
  }
  final tokens = norm.split(' ').where((t) => t.isNotEmpty).toList();
  final scored = [
    for (final it in intents)
      {'id': it.id, 'score': _scoreIntent(norm, tokens, it)},
  ].where((s) => (s['score'] as int) > 0).toList();
  // JS sort is stable; Dart's is not, so tiebreak on the registry order,
  // which is the list order scored was built in.
  final indexed = List.generate(scored.length, (i) => (scored[i], i));
  indexed.sort((a, b) {
    final c = (b.$1['score'] as int).compareTo(a.$1['score'] as int);
    return c != 0 ? c : a.$2.compareTo(b.$2);
  });
  final sorted = [for (final e in indexed) e.$1];
  if (sorted.isEmpty) {
    return {'id': helpId, 'score': 0, 'alternatives': const []};
  }
  final top = sorted[0];
  if (sorted.length > 1 && sorted[1]['score'] == top['score']) {
    return {
      'id': helpId,
      'score': top['score'],
      'alternatives': [top['id'], sorted[1]['id']],
    };
  }
  return {
    'id': top['id'],
    'score': top['score'],
    'alternatives': [for (final s in sorted.skip(1).take(2)) s['id']],
  };
}
