/// Pan, the money assistant. See the class docs below for the full contract.
library;

import '../../data/pan_knowledge.dart';
import '../../models/models.dart';
import 'format.dart';
import 'pan_facts.dart';
import 'pan_matchers.dart';

/// Pan, the money assistant, ported in intent from `src/utils/panAiEngine.ts`
/// and rewritten rather than copied.
///
/// ## It is NOT AI, and is never called that
///
/// The prototype names its file `panAiEngine.ts`, badges Pan an "Offline
/// Financial Copilot", and puts a 240ms delay with three bouncing dots in
/// front of every answer to make it feel like something is thinking. There is
/// no model anywhere in it: `processPanQuery` is a chain of `q.includes(...)`
/// returning hardcoded strings, with no fetch, no key and no inference.
///
/// This is the same kind of thing, which is why it is called a money
/// assistant and the file is `pan.dart`. Claiming AI would be a
/// characteristic claim about a product that does not have it, which is a
/// deceptive-behaviour problem on Play and a misrepresentation under
/// consumer law, and it would make the answers feel more authoritative than
/// they have earned. What it IS, is a good line: every answer is worked out
/// on this phone, from figures the person typed, with nothing leaving the
/// device and no signal needed.
///
/// ## What it may and may not say
///
/// Founder direction, 2026-09-19: Pan must know the person's own figures and
/// every feature in the app, and how an entry flows through it. It does. The
/// boundary, which a securities review of the prototype's own strings made
/// concrete, is that Pan may do ARITHMETIC on somebody's figures, compare
/// them to a stated general rule of thumb, and name the CONSEQUENCE. It may
/// not tell them what to do about it.
///
/// Concretely, and enforced by `pan_content_test.dart` over every literal in
/// this file and in pan_knowledge.dart:
///
///   - no bank, e-wallet, fund or product named in Salapify's own words. A
///     name that came from the user's own account list is fine and necessary,
///     because refusing to say "your BPI Savings holds X" would make the
///     assistant useless;
///   - no imperative about their money: no "you should", "we recommend",
///     "put your", "invest in";
///   - no yield, return, dividend or forward-looking figure;
///   - no professional standing: no CPA, adviser, expert, audit, coach.
///
/// The prototype breaks all four. Its emergency fund answer prescribes a
/// split of the reader's money across four named products with quoted annual
/// yields, under a badge reading "Financial Coach". None of that is ported.

/// One answer, plus anything the screen should offer after it.
class PanAnswer {
  const PanAnswer({
    required this.topic,
    required this.text,
    this.figures = const <PanFigure>[],
    this.followUps = const <String>[],
    this.aboutMoney = false,
  });

  /// Which rule matched, for tests and for the screen's own label.
  final String topic;

  final String text;

  /// Figures pulled out of the sentence so the screen can show them large.
  /// A number in a paragraph is read; a number in a row is seen.
  final List<PanFigure> figures;

  /// Questions that follow naturally from this answer.
  final List<String> followUps;

  /// True when the answer touches saving, investing, tax, insurance or a
  /// product. Those, and only those, carry the trailer.
  ///
  /// NOT every answer. A disclaimer on every single message is wallpaper
  /// within two days, and then it is not there for the one that matters.
  final bool aboutMoney;

  static const String trailer =
      'This is general information, not advice about your own money.';

  /// The body as it is shown, trailer included where it belongs.
  String get display => aboutMoney ? '$text\n\n$trailer' : text;
}

class PanFigure {
  const PanFigure({required this.label, required this.value});
  final String label;
  final String value;
}

/// Strips a question down to something matchable.
String normalise(String raw) => raw
    .toLowerCase()
    .replaceAll(RegExp(r'[^\w\s₱.]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _has(String q, List<String> words) => words.any(q.contains);

/// The answer to a question, worked out entirely from [facts].
///
/// Deterministic and offline by construction: there is no clock read, no
/// randomness, no network and no storage here. The same question against the
/// same facts gives the same answer forever, which is what lets every rule
/// below be pinned by a test.
PanAnswer askPan(String question, PanFacts facts) {
  final String q = normalise(question);

  if (q.isEmpty) return _dontKnow(facts);

  // 1. THE ADVICE BOUNDARY COMES FIRST, before anything else can match.
  //
  // "Where should I put my savings" contains "savings", and a balance answer
  // would be a confident non-answer to a question about what to do. Checking
  // it first is what makes the boundary a boundary rather than a fallback.
  if (_looksLikeAdviceRequest(q)) return _boundary(q, facts);

  // 2. A named account, because it is the most specific thing a person can
  //    ask about and the answer is simply their own figure.
  final Account? named = _accountNamed(q, facts);
  if (named != null) return _oneAccount(named, facts);

  if (_has(q, <String>[
    'safe to spend',
    'can i spend',
    'spendable',
    'pwede ko gastusin',
    'how much left',
  ])) {
    return _safeToSpend(facts);
  }

  if (_has(q, <String>[
    'how much do i have',
    'how much money',
    'my balance',
    'total balance',
    'magkano',
    'pera ko',
    'cash',
    'how much have i got',
  ])) {
    return _cash(facts);
  }

  if (_has(q, <String>['net worth', 'net asset', 'worth', 'overall'])) {
    return _netWorth(facts);
  }

  if (_has(q, <String>[
    'where did my money go',
    'saan napunta',
    'spending',
    'spent this month',
    'biggest',
    'what did i spend',
    'expenses this month',
  ])) {
    return _spending(facts);
  }

  if (_has(q, <String>['budget', 'limit', 'overspend', 'lampas'])) {
    return _budgets(facts);
  }

  // OWED TO ME IS CHECKED FIRST, and the order is the whole rule.
  //
  // "who owes me money" contains "owe". With the other way round it matched
  // the what-you-owe branch and answered a question about a receivable with a
  // list of the person's own debts, which is the single confusion a two way
  // register must never create. A test caught it; reading the two keyword
  // lists side by side did not.
  if (_has(q, <String>[
    'owes me',
    'owed to me',
    'utang sa akin',
    'who owes',
    'receivable',
    'owe me',
  ])) {
    return _owedToMe(facts);
  }

  if (_has(q, <String>[
    'who do i owe',
    'my debt',
    'utang ko',
    'how much do i owe',
    'owe',
  ])) {
    return _owed(facts);
  }

  if (_has(q, <String>[
    'due',
    'bill',
    'bayarin',
    'coming up',
    'upcoming',
    'this week',
  ])) {
    return _due(facts);
  }

  if (_has(q, <String>['goal', 'ipon', 'saving for', 'target'])) {
    return _goals(facts);
  }

  if (_has(q, <String>['payday', 'sweldo', 'next pay', 'when do i get paid'])) {
    return _payday(facts);
  }

  // 3. The app itself. Last, so a question about the person's own money is
  //    never answered with a description of a screen.
  final PanFeature? feature = _featureFor(q);
  if (feature != null) return _feature(feature);

  return _dontKnow(facts);
}

// ---------------------------------------------------------------------------
// The boundary
// ---------------------------------------------------------------------------

/// The trigger words live in pan_matchers.dart, NOT here, and that split is
/// enforcement rather than tidiness. The content guard forbids this file from
/// naming a financial product, and it correctly fired on a product name that
/// was only ever used to RECOGNISE a question. Pan has to know the word to
/// spot the question and must never use it in an answer, so the two sets of
/// words live in two files and only this one is rendered.
bool _looksLikeAdviceRequest(String q) => _has(q, adviceTriggers);

/// Answers the answerable part, names the line once, says WHY in terms of what
/// Pan cannot see, and ends on something to do rather than on a no.
///
/// Refusing flatly is its own harm. A money app that says "I cannot discuss
/// that" to somebody asking where to keep their savings sends a twenty three
/// year old to a Facebook group, which is materially worse for them and is
/// the outcome the scam warnings exist to prevent. So the education always
/// comes first and the last thing on screen is never the refusal.
PanAnswer _boundary(String q, PanFacts facts) {
  final String opener = _has(q, investingWords)
      ? 'Investing means putting money somewhere it can grow and can also '
            'fall. The two things that decide whether any of it fits you are '
            'when you would need the money back, and what it would cost you '
            'to have it locked away on the month something goes wrong.'
      : _has(q, borrowingWords)
      ? 'Borrowing costs more than the amount you borrow, and how much more '
            'depends on the rate, the term, and the fees, which are often '
            'quoted separately. The Debt register and the loan calculators '
            'here will show you the total cost of an arrangement once you '
            'type its actual numbers in.'
      : 'Money you might need within a few days behaves differently from '
            'money you can leave alone for years. That difference, rather '
            'than the name of any particular place to put it, is what '
            'usually decides the answer.';

  return PanAnswer(
    topic: 'boundary',
    aboutMoney: true,
    text:
        '$opener\n\n'
        'Which one suits you is not something Salapify can work out. It turns '
        'on things Pan cannot see: when you would need the money, what else '
        'you owe, and how it would feel to have it tied up at the wrong '
        'moment.\n\n'
        'What Salapify can do is the arithmetic. Set a goal with the date you '
        'would need the money by, and it shows what you would have to set '
        'aside each payday to get there.\n\n'
        'One thing worth knowing whoever you ask: in the Philippines you can '
        'check whether a company is actually licensed to take investment '
        'money on the SEC\'s own website. A certificate of incorporation is '
        'only a business birth certificate, not permission to take your '
        'savings.',
    followUps: <String>[
      'How do goals work?',
      'What is safe to spend?',
      'How much do I have right now?',
    ],
  );
}

// ---------------------------------------------------------------------------
// The person's own figures
// ---------------------------------------------------------------------------

Account? _accountNamed(String q, PanFacts facts) {
  for (final Account a in facts.accounts) {
    final String name = normalise(a.name);
    if (name.isNotEmpty && name.length > 2 && q.contains(name)) return a;
  }
  return null;
}

PanAnswer _oneAccount(Account a, PanFacts facts) {
  final bool owing = a.balance < 0;
  return PanAnswer(
    topic: 'account',
    text: owing
        ? '${a.name} is carrying ${formatPeso(a.balance.abs())} owing. A card '
              'or a loan records what you owe as a negative number, so it '
              'lowers your net worth rather than adding to it.'
        : '${a.name} holds ${formatPeso(a.balance)}.',
    figures: <PanFigure>[
      PanFigure(
        label: owing ? 'Owing' : 'Balance',
        value: formatPeso(a.balance.abs()),
      ),
    ],
    followUps: <String>[
      'How much do I have right now?',
      'What is a reconciliation check?',
    ],
  );
}

PanAnswer _cash(PanFacts facts) {
  if (facts.isEmpty) return _nothingYet('how much you have');
  return PanAnswer(
    topic: 'cash',
    text:
        'You can reach ${formatPeso(facts.liquidCash)} today across '
        '${facts.accounts.length} '
        '${facts.accounts.length == 1 ? 'account' : 'accounts'}. That counts '
        'cash, bank and e-wallet balances. A credit limit is not in there, '
        'because money you can borrow is not money you have.'
        '${facts.hasSampleData ? ' Some of this is still Salapify\'s sample data, which you can remove in Settings.' : ''}',
    figures: <PanFigure>[
      PanFigure(label: 'Reachable today', value: formatPeso(facts.liquidCash)),
    ],
    followUps: <String>[
      'What is safe to spend?',
      'What is my net worth?',
      'What is due soon?',
    ],
  );
}

PanAnswer _safeToSpend(PanFacts facts) {
  if (facts.isEmpty) return _nothingYet('what is safe to spend');
  return PanAnswer(
    topic: 'safeToSpend',
    text:
        'Safe to Spend is ${formatPeso(facts.safeToSpendUntilPayday)}, which '
        'is ${formatPeso(facts.safeToSpendPerDay)} a day until your next '
        'payday.\n\n'
        'It starts from the ${formatPeso(facts.liquidCash)} you can reach and '
        'holds back ${formatPeso(facts.amountReserved)} that is already '
        'spoken for: unpaid bills, payment plan instalments, a minimum '
        'against what you owe, and a buffer. What is left is what is really '
        'yours to spend.',
    figures: <PanFigure>[
      PanFigure(
        label: 'Until payday',
        value: formatPeso(facts.safeToSpendUntilPayday),
      ),
      PanFigure(label: 'A day', value: formatPeso(facts.safeToSpendPerDay)),
      PanFigure(label: 'Held back', value: formatPeso(facts.amountReserved)),
    ],
    followUps: <String>['What is due soon?', 'Where did my money go?'],
  );
}

PanAnswer _netWorth(PanFacts facts) {
  if (facts.isEmpty) return _nothingYet('your net worth');
  final double net = facts.netWorth;
  // The assets and the liabilities stay APART in the sentence, never summed
  // into one figure that hides which half is which.
  final String shape = net < 0
      ? 'That is below zero, which sounds alarming and often is not: a '
            'housing or vehicle loan alone can do it, because the whole '
            'balance sits against you while the thing it bought is not '
            'counted here.'
      : 'Assets and what you owe are kept apart on purpose, because one '
            'number hides which half is moving.';
  return PanAnswer(
    topic: 'netWorth',
    text:
        'Your net worth is ${formatPeso(net)}. That is '
        '${formatPeso(facts.assets)} held, less ${formatPeso(facts.liabilities)} '
        'owed on your accounts.\n\n$shape',
    figures: <PanFigure>[
      PanFigure(label: 'Net worth', value: formatPeso(net)),
      PanFigure(label: 'Held', value: formatPeso(facts.assets)),
      PanFigure(label: 'Owed', value: formatPeso(facts.liabilities)),
    ],
    followUps: <String>['Who do I owe?', 'How much do I have right now?'],
  );
}

PanAnswer _spending(PanFacts facts) {
  if (facts.spendingByCategory.isEmpty) {
    return _nothingYet('where your money went');
  }
  final List<({String category, double amount})> top = facts.spendingByCategory
      .take(3)
      .toList();
  final StringBuffer b = StringBuffer(
    'This month ${formatPeso(facts.monthOut)} went out and '
    '${formatPeso(facts.monthIn)} came in.\n\nThe largest were:',
  );
  for (final ({String category, double amount}) c in top) {
    b.write('\n  ${c.category}: ${formatPeso(c.amount)}');
  }
  if (facts.monthOut > facts.monthIn && facts.monthIn > 0) {
    b.write(
      '\n\nMore left than arrived this month. That is a fact about this '
      'month rather than a verdict: a yearly payment or a one-off can do it.',
    );
  }
  return PanAnswer(
    topic: 'spending',
    text: b.toString(),
    figures: <PanFigure>[
      PanFigure(label: 'Out', value: formatPeso(facts.monthOut)),
      PanFigure(label: 'In', value: formatPeso(facts.monthIn)),
    ],
    followUps: <String>['How are my budgets doing?', 'What is safe to spend?'],
  );
}

PanAnswer _budgets(PanFacts facts) {
  if (facts.budgets.isEmpty) {
    return const PanAnswer(
      topic: 'budgets',
      text:
          'You have no budget limits set yet. A limit is a monthly line you '
          'draw for a category, and logging an expense in that category fills '
          'the bar toward it. Salapify never blocks anything and never moves '
          'money; the bar simply shows where you are.\n\n'
          'They live on the Plan tab.',
      followUps: <String>['Where did my money go?'],
    );
  }
  final Map<String, double> spent = <String, double>{
    for (final ({String category, double amount}) c in facts.spendingByCategory)
      c.category: c.amount,
  };
  final List<String> over = <String>[];
  for (final Budget b in facts.budgets) {
    final double used = spent[b.category] ?? 0;
    if (b.limit > 0 && used > b.limit) over.add(b.category);
  }
  return PanAnswer(
    topic: 'budgets',
    text: over.isEmpty
        ? 'You have ${facts.budgets.length} budget '
              '${facts.budgets.length == 1 ? 'limit' : 'limits'} set, and '
              'nothing is over its line this month.'
        : '${over.length} of your ${facts.budgets.length} limits are over the '
              'line this month: ${over.join(', ')}. Over a limit is not an '
              'error, it is a line you drew and a month that went '
              'differently. The Plan tab shows each bar.',
    followUps: <String>['Where did my money go?', 'What is safe to spend?'],
  );
}

PanAnswer _owed(PanFacts facts) {
  final List<Debt> mine = facts.debts
      .where((Debt d) => d.direction == DebtDirection.iOwe && !d.isSettled)
      .toList();
  if (mine.isEmpty) {
    return const PanAnswer(
      topic: 'owed',
      text: 'Nothing is recorded as owed by you.',
      followUps: <String>['Who owes me money?', 'What is due soon?'],
    );
  }
  final StringBuffer b = StringBuffer(
    'You owe ${formatPeso(facts.owed)} across ${mine.length} '
    '${mine.length == 1 ? 'debt' : 'debts'}:',
  );
  for (final Debt d in mine.take(5)) {
    b.write('\n  ${d.person}: ${formatPeso(d.remaining)}');
  }
  if (mine.length > 5) b.write('\n  and ${mine.length - 5} more.');
  b.write(
    '\n\nRecording a payment lowers the debt and the account it came from '
    'together, so your net worth does not move.',
  );
  return PanAnswer(
    topic: 'owed',
    text: b.toString(),
    figures: <PanFigure>[
      PanFigure(label: 'You owe', value: formatPeso(facts.owed)),
    ],
    followUps: <String>['Who owes me money?', 'What is my net worth?'],
  );
}

PanAnswer _owedToMe(PanFacts facts) {
  final List<Debt> theirs = facts.debts
      .where((Debt d) => d.direction == DebtDirection.owedToMe && !d.isSettled)
      .toList();
  if (theirs.isEmpty) {
    return const PanAnswer(
      topic: 'owedToMe',
      text: 'Nobody is recorded as owing you anything.',
      followUps: <String>['Who do I owe?'],
    );
  }
  final StringBuffer b = StringBuffer(
    '${formatPeso(facts.owedToMe)} is owed to you, across ${theirs.length} '
    '${theirs.length == 1 ? 'person' : 'people'}:',
  );
  for (final Debt d in theirs.take(5)) {
    b.write('\n  ${d.person}: ${formatPeso(d.remaining)}');
  }
  b.write(
    '\n\nSalapify keeps this as a record for you. It never contacts anybody '
    'and never chases a payment on your behalf.',
  );
  return PanAnswer(
    topic: 'owedToMe',
    text: b.toString(),
    figures: <PanFigure>[
      PanFigure(label: 'Owed to you', value: formatPeso(facts.owedToMe)),
    ],
    followUps: <String>['Who do I owe?'],
  );
}

PanAnswer _due(PanFacts facts) {
  final List<BillItem> unpaid = facts.bills
      .where((BillItem b) => !b.isPaid)
      .toList();
  if (unpaid.isEmpty) {
    return const PanAnswer(
      topic: 'due',
      text:
          'Nothing unpaid is recorded. Bills you add are held back from Safe '
          'to Spend until they are paid, so the figure on Home stays money '
          'that is really yours.',
      followUps: <String>['What is safe to spend?'],
    );
  }
  final double total = unpaid.fold<double>(
    0,
    (double s, BillItem b) => s + b.amount,
  );
  final StringBuffer sb = StringBuffer(
    '${formatPeso(total)} is unpaid across ${unpaid.length} '
    '${unpaid.length == 1 ? 'bill' : 'bills'}:',
  );
  for (final BillItem b in unpaid.take(5)) {
    sb.write('\n  ${b.name}: ${formatPeso(b.amount)}, due ${b.dueDate}');
  }
  if (unpaid.length > 5) sb.write('\n  and ${unpaid.length - 5} more.');
  sb.write(
    '\n\nAll of it is already held back from Safe to Spend, so you are not '
    'counting it twice.',
  );
  return PanAnswer(
    topic: 'due',
    text: sb.toString(),
    figures: <PanFigure>[PanFigure(label: 'Unpaid', value: formatPeso(total))],
    followUps: <String>['What is safe to spend?', 'How do reminders work?'],
  );
}

PanAnswer _goals(PanFacts facts) {
  if (facts.goals.isEmpty) {
    return const PanAnswer(
      topic: 'goals',
      aboutMoney: true,
      text:
          'You have no goals set. A goal is an amount and a date, and '
          'Salapify works out what you would need to set aside each payday to '
          'reach it from where you are now. It is arithmetic on your own '
          'figures.\n\nThey live on the targets tab.',
      followUps: <String>['How much do I have right now?'],
    );
  }
  final StringBuffer b = StringBuffer(
    'You have ${facts.goals.length} '
    '${facts.goals.length == 1 ? 'goal' : 'goals'}:',
  );
  for (final Goal g in facts.goals.take(4)) {
    final double left = (g.targetAmount - g.currentAmount).clamp(
      0,
      double.infinity,
    );
    b.write(
      '\n  ${g.name}: ${formatPeso(g.currentAmount)} of '
      '${formatPeso(g.targetAmount)}, ${formatPeso(left)} to go',
    );
  }
  return PanAnswer(
    topic: 'goals',
    aboutMoney: true,
    text: b.toString(),
    followUps: <String>['What is safe to spend?'],
  );
}

PanAnswer _payday(PanFacts facts) {
  if (!facts.payday.isSet) {
    return const PanAnswer(
      topic: 'payday',
      text:
          'Your payday is not set yet, so Salapify is spreading Safe to Spend '
          'over a single day rather than across a pay cycle. Setting it makes '
          'that daily figure mean something.',
      followUps: <String>['What is safe to spend?'],
    );
  }
  return PanAnswer(
    topic: 'payday',
    text:
        'Your next payday is ${facts.payday.nextPayday}, '
        '${facts.payday.daysToPayday} '
        '${facts.payday.daysToPayday == 1 ? 'day' : 'days'} away. That is the '
        'number Safe to Spend divides by, which is why the daily figure moves '
        'as payday gets closer.',
    figures: <PanFigure>[
      PanFigure(label: 'Days to payday', value: '${facts.payday.daysToPayday}'),
    ],
    followUps: <String>['What is safe to spend?'],
  );
}

// ---------------------------------------------------------------------------
// The app itself
// ---------------------------------------------------------------------------

PanFeature? _featureFor(String q) {
  PanFeature? best;
  int bestScore = 0;
  for (final PanFeature f in panFeatures) {
    int score = 0;
    for (final String k in f.keywords) {
      if (q.contains(k)) score += k.split(' ').length;
    }
    if (score > bestScore) {
      bestScore = score;
      best = f;
    }
  }
  return best;
}

PanAnswer _feature(PanFeature f) => PanAnswer(
  topic: 'feature:${f.id}',
  text: '${f.what}\n\nWhere: ${f.where}',
  followUps: const <String>[
    'What happens when I log an expense?',
    'Is my data private?',
  ],
);

PanAnswer _nothingYet(String what) => PanAnswer(
  topic: 'empty',
  text:
      'There is nothing recorded yet, so Pan cannot tell you $what. Add an '
      'account and log one entry, and every figure in Salapify starts working '
      'from there.',
  followUps: const <String>[
    'How do I add an entry?',
    'What happens when I log an expense?',
  ],
);

/// The honest miss.
///
/// It says what Pan IS rather than only what it is not, because "I do not
/// understand" from an assistant reads as a broken app, and because the real
/// answer is usually one of a short list a person has not thought to ask for.
PanAnswer _dontKnow(PanFacts facts) => PanAnswer(
  topic: 'unknown',
  text:
      'Pan did not recognise that one. It works by matching what you ask '
      'against a set of built-in answers and doing arithmetic on the figures '
      'you have typed in. There is no AI model and nothing leaves your phone, '
      'which is also why it can be a bit literal.\n\n'
      'It can tell you what you hold, what is safe to spend, where the month '
      'went, what you owe and what is owed to you, what is due, how your '
      'goals and budgets stand, and how any part of Salapify works.',
  followUps: panStarters.take(4).toList(),
);
