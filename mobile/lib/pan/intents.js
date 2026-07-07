// Pan's intent registry and matcher. Data, not logic: adding a capability is
// appending one object here plus one resolver. The matcher, the help menu,
// and the suggested-question chips all read from this one source, so they can
// never drift out of sync.
//
// Two layers, checked in order:
//   GUARDRAILS  out-of-scope, liability-sensitive topics (investment, loans,
//               tax, legal, insurance). Matched FIRST so they can never leak
//               into a data answer, each with a safe redirect line.
//   INTENTS     the money questions Pan actually answers from on-device data.

// A short substring hit in the normalized message is enough for a guardrail:
// we would rather safely decline a borderline message than risk giving
// investment or loan guidance.
export const GUARDRAILS = [
  {
    id: 'no_invest',
    keywords: ['invest', 'stocks', 'stock market', 'crypto', 'bitcoin', 'forex', 'mutual fund', 'uitf', 'mp2', 'trading', 'shares', 'good return', 'grow my money', 'where to invest', 'good investment'],
    reply:
      'I do not give investment advice, that needs a licensed professional. What I can do is show you exactly how much you can set aside, so you decide with clear numbers. Want your safe to spend, or how a goal is pacing?',
  },
  {
    id: 'no_loan',
    keywords: ['apply for a loan', 'get a loan', 'cash loan', 'borrow money', 'lend me', 'loan app', 'where to borrow', 'sangla'],
    reply:
      'I cannot help you find or apply for a loan. But if you are weighing one, the Loan calculator in Tools shows its real monthly payment and true interest rate, so you go in with clear eyes. I can also track debts you already have.',
    cta: { label: 'Open Loan calculator', route: '/loan-calculator' },
  },
  {
    id: 'no_tax',
    keywords: ['tax', 'bir', 'income tax', 'vat', 'withholding'],
    reply:
      'I cannot give tax advice, please check the BIR or a tax professional for your actual filing. What I can do is point you to the Income tax calculator in Tools, which estimates the 8% versus graduated tax and lists the BIR forms you file.',
    cta: { label: 'Open Income tax calculator', route: '/tax-calculator' },
  },
  {
    id: 'no_legal',
    keywords: ['sue', 'small claims', 'estafa', 'legal', 'lawyer', 'demand letter', 'contract'],
    reply:
      'I cannot give legal advice. For utang, what I can do is help you write a polite reminder and track what is owed. Want to see who owes you?',
  },
  {
    id: 'no_insurance',
    keywords: ['insurance', 'vul', 'life plan', 'health card', 'hmo'],
    reply:
      'I do not recommend insurance products. A good first shield is an emergency fund sized to your monthly expenses, and I can help you build toward that as a goal.',
  },
];

// Each intent: strong keywords (worth more) and any keywords (worth less),
// plus example phrases used for the fuzzy pass, the chips, and the help menu.
// `resolve` names the resolver function; `title` labels its card and chip.
export const INTENTS = [
  {
    id: 'safe_to_spend',
    title: 'Safe to spend',
    resolve: 'safeToSpend',
    keywords: {
      strong: ['safe to spend', 'how much can i spend', 'spend today', 'until payday', 'spend until'],
      any: ['spend', 'afford', 'left to spend', 'howmuch left', 'baon', 'budget left'],
    },
    examples: ['How much can I safely spend?', 'Magkano pa pwede kong gastusin?'],
  },
  {
    id: 'can_afford',
    title: 'Can I afford this',
    resolve: 'canAfford',
    keywords: {
      strong: ['can i afford', 'can i buy', 'should i buy', 'afford this'],
      any: ['afford', 'buy', 'bili'],
    },
    examples: ['Can I afford 2000 shoes?', 'Kaya ko ba bumili ng 1500?'],
  },
  {
    id: 'utang',
    title: 'Who owes me',
    resolve: 'utang',
    keywords: {
      strong: ['who owe me', 'who owes me', 'who owe', 'follow up', 'utang list', 'collect'],
      any: ['owe', 'owes', 'receivable', 'niningil', 'pautang'],
    },
    examples: ['Who owes me money?', 'Sino may utang sa akin?'],
  },
  {
    id: 'upcoming_bills',
    title: 'What is due',
    resolve: 'upcomingBills',
    keywords: {
      strong: ['what is due', 'whats due', 'upcoming bills', 'bills due', 'anong bills'],
      any: ['bills', 'due', 'bayarin', 'payables'],
    },
    examples: ["What's due before my sweldo?", 'Anong babayaran ko?'],
  },
  {
    id: 'debt_due',
    title: 'Card and debt due dates',
    resolve: 'debtDue',
    keywords: {
      strong: ['card due', 'when is my card', 'debt due', 'when to pay', 'pay in full'],
      any: ['card', 'debt', 'credit', 'minimum', 'statement'],
    },
    examples: ['When is my credit card due?', 'Magkano babayaran sa card?'],
  },
  {
    id: 'debt_free',
    title: 'Debt-free date',
    resolve: 'debtFree',
    keywords: {
      strong: ['debt free', 'pay off', 'payoff', 'when will i be debt', 'finish debt', 'finish my debt', 'if i add', 'how long to pay'],
      any: ['payoff', 'clear debt', 'matatapos utang', 'add extra', 'a month to my'],
    },
    examples: ['When will I be debt-free?', 'If I add 1000 a month?'],
  },
  {
    id: 'month_recap',
    title: 'My month',
    resolve: 'recap',
    keywords: {
      strong: ['my month', 'recap', 'how was my month', 'how am i doing', 'how spending', 'summary'],
      any: ['month', 'kumusta', 'buod'],
    },
    examples: ['How was my month?', 'Kumusta gastos ko this month?'],
  },
  {
    id: 'top_spending',
    title: 'Where my money goes',
    resolve: 'topSpending',
    keywords: {
      strong: ['am i overspending', 'where does my money go', 'biggest spending', 'top spending', 'saan napupunta', 'overspending'],
      any: ['category', 'spending', 'gastos', 'napupunta'],
    },
    examples: ['Am I overspending on food?', 'Saan napupunta pera ko?'],
  },
  {
    id: 'forecast',
    title: 'Month-end forecast',
    resolve: 'forecast',
    keywords: {
      strong: ['will i go over', 'over budget', 'end of month', 'forecast', 'lalagpas'],
      any: ['budget', 'projected', 'reach'],
    },
    examples: ['Will I go over budget?', 'Lalagpas ba ako this month?'],
  },
  {
    id: 'savings_rate',
    title: 'Am I saving enough',
    resolve: 'savingsRate',
    keywords: {
      strong: ['am i saving', 'savings rate', 'how much did i save', 'saving enough'],
      any: ['save', 'savings', 'ipon'],
    },
    examples: ['Am I saving enough?', 'Nakakaipon ba ako?'],
  },
  {
    id: 'goal_pace',
    title: 'My goals',
    resolve: 'goalPace',
    keywords: {
      strong: ['my goal', 'will i hit my goal', 'on track', 'goal pace', 'save for'],
      any: ['goal', 'target', 'fund'],
    },
    examples: ['Will I hit my goal?', 'On track ba ako sa goal ko?'],
  },
  {
    id: 'health',
    title: 'Money health score',
    resolve: 'health',
    keywords: {
      strong: ['health score', 'how healthy', 'financial health', 'money health', 'overall'],
      any: ['score', 'healthy'],
    },
    examples: ['How healthy is my money?', "What's my money score?"],
  },
  {
    id: 'balances',
    title: 'My balances',
    resolve: 'balances',
    keywords: {
      strong: ['how much do i have', 'my balance', 'total money', 'net worth', 'howmuch i have', 'howmuch money', 'how much do i owe', 'howmuch i owe', 'total debt', 'how much i owe', 'how much debt'],
      any: ['balance', 'money', 'cash', 'total'],
    },
    examples: ['How much do I have?', 'Magkano pera ko?'],
  },
  {
    id: 'payday',
    title: 'Next sweldo',
    resolve: 'payday',
    keywords: {
      strong: ['when is payday', 'when payday', 'next sweldo', 'when sweldo', 'payday countdown'],
      any: ['payday', 'sweldo', 'sahod'],
    },
    examples: ['When is my next sweldo?', 'Ilang araw bago sweldo?'],
  },

  // Tool pointers. These do not read your data, they open the right calculator
  // in Tools. `pointer` short-circuits the resolver in ask(), so Pan explains
  // in one line and offers a button, never inventing a number.
  {
    id: 'tool_take_home',
    title: 'Take-home pay',
    pointer: {
      route: '/salary-calculator',
      label: 'Open Take-home pay',
      text: 'To turn a gross salary into net, the Take-home pay calculator in Tools does it properly, with SSS, PhilHealth, Pag-IBIG, tax, and allowances, and can show it per cutoff, monthly, or yearly.',
    },
    keywords: {
      strong: ['take home', 'take home pay', 'net pay', 'net salary', 'gross to net'],
      any: ['takehome', 'deductions from salary'],
    },
    examples: ['What is my take-home pay?', 'Gross to net salary'],
  },
  {
    id: 'tool_thirteenth',
    title: '13th month pay',
    pointer: {
      route: '/thirteenth-calculator',
      label: 'Open 13th month pay',
      text: 'For 13th month pay, the calculator in Tools figures what you should get, prorated for months worked, and shows the tax-free part up to the 90,000 ceiling.',
    },
    keywords: {
      strong: ['13th month', '13 month', 'thirteenth month', '13th month pay'],
      any: ['13th', 'bonus'],
    },
    examples: ['How much is my 13th month?', 'Compute 13th month pay'],
  },
  {
    id: 'tool_contributions',
    title: 'SSS, PhilHealth, Pag-IBIG',
    pointer: {
      route: '/contribution-calculator',
      label: 'Open Contribution checker',
      text: 'For your monthly SSS, PhilHealth, and Pag-IBIG, the Contribution checker in Tools shows what comes out of your pay, what your employer adds, and the total, for any salary.',
    },
    keywords: {
      strong: ['sss', 'philhealth', 'phil health', 'pag ibig', 'pagibig', 'contribution', 'contributions'],
      any: ['hdmf', 'sss contribution', 'monthly contribution'],
    },
    examples: ['How much is my SSS?', 'PhilHealth and Pag-IBIG for 25000'],
  },
  {
    id: 'tool_loan_cost',
    title: 'Loan cost',
    pointer: {
      route: '/loan-calculator',
      label: 'Open Loan calculator',
      text: 'To see the real cost of a loan, the Loan calculator in Tools shows the monthly payment, total interest, and the true effective rate, so an add-on quote cannot hide how much it really costs.',
    },
    keywords: {
      strong: ['amortization', 'monthly amortization', 'loan calculator', 'effective rate', 'true cost of a loan'],
      any: ['amortize', 'add on rate', 'interest rate'],
    },
    examples: ['Monthly amortization of a loan', 'True cost of a loan'],
  },
];

// The help intent is special: no resolver, its reply is built from the
// registry so it always lists exactly what Pan can do.
export const HELP_ID = 'help';

const within1Edit = (a, b) => {
  // True when a and b differ by at most one edit: a substitution, one
  // adjacent transposition (the most common real typo), or one insert or
  // delete. Cheap, bounded, no library.
  if (a === b) return true;
  const la = a.length, lb = b.length;
  if (Math.abs(la - lb) > 1) return false;
  if (la === lb) {
    const diff = [];
    for (let i = 0; i < la; i++) if (a[i] !== b[i]) diff.push(i);
    if (diff.length === 1) return true; // one substitution
    // one adjacent transposition, e.g. "spned" vs "spend"
    return (
      diff.length === 2 &&
      diff[1] === diff[0] + 1 &&
      a[diff[0]] === b[diff[1]] &&
      a[diff[1]] === b[diff[0]]
    );
  }
  // Lengths differ by one: a single insertion or deletion.
  const s = la < lb ? a : b;
  const l = la < lb ? b : a;
  let i = 0, j = 0, skips = 0;
  while (i < s.length && j < l.length) {
    if (s[i] === l[j]) { i++; j++; }
    else if (++skips > 1) return false;
    else j++;
  }
  return true;
};

function scoreIntent(norm, tokens, intent) {
  let score = 0;
  for (const kw of intent.keywords.strong) if (norm.includes(kw)) score += 3;
  for (const kw of intent.keywords.any) if (norm.includes(kw)) score += 1;
  // Fuzzy single-token pass for typos on longer words.
  const kwTokens = new Set();
  for (const kw of [...intent.keywords.strong, ...intent.keywords.any]) {
    for (const t of kw.split(' ')) if (t.length >= 4) kwTokens.add(t);
  }
  for (const t of tokens) {
    if (t.length < 4) continue;
    for (const kt of kwTokens) {
      if (within1Edit(t, kt)) { score += 1; break; }
    }
  }
  return score;
}

// A guardrail keyword must hit on a whole-word boundary, never as a substring,
// or innocent words trip it: "taxi" would fire the tax rail, "birthday" the
// BIR rail, "private" the VAT rail, "tissue" the legal rail. norm is already
// lowercased to letters, digits, and single spaces, so simple boundaries work.
const wordHit = (norm, kw) => {
  const esc = kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Allow a trailing plural or common inflection on the keyword itself, so
  // tax also catches taxes, invest catches investing and investment, bitcoin
  // catches bitcoins. It still refuses a different word that merely contains
  // the keyword (taxi, birthday, private, tissue), because the leading
  // boundary and the limited suffix set never line up for those.
  return new RegExp('(?:^|[^a-z0-9])' + esc + '(?:s|es|ing|ment|ments)?(?![a-z0-9])').test(norm);
};

// detectIntent(normalized) -> { id, guardrail?, score, alternatives:[id...] }
export function detectIntent(norm) {
  for (const g of GUARDRAILS) {
    if (g.keywords.some((k) => wordHit(norm, k))) {
      return { id: g.id, guardrail: g, score: 99, alternatives: [] };
    }
  }
  const tokens = norm.split(' ').filter(Boolean);
  const scored = INTENTS.map((it) => ({ id: it.id, score: scoreIntent(norm, tokens, it) }))
    .filter((s) => s.score > 0)
    .sort((a, b) => b.score - a.score);
  if (scored.length === 0) return { id: HELP_ID, score: 0, alternatives: [] };
  const top = scored[0];
  // Ambiguous: the top two are tied. Ask rather than guess wrong.
  if (scored[1] && scored[1].score === top.score) {
    return { id: HELP_ID, score: top.score, alternatives: [top.id, scored[1].id] };
  }
  return { id: top.id, score: top.score, alternatives: scored.slice(1, 3).map((s) => s.id) };
}
