/// Pan, the money assistant. See the class docs below for the full contract.
library;

import '../../../data/academy_data.dart';
import 'pan_knowledge.dart';
import '../../../models/academy.dart';
import '../../../models/models.dart';
import '../format.dart';
import 'pan_affordability.dart';
import 'pan_amounts.dart';
import 'pan_bans.dart';
import 'pan_context.dart';
import 'pan_explainers.dart';
import 'pan_health.dart';
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
/// Concretely, and enforced by `pan_bans.dart` at RUNTIME over every passage
/// before it is emitted, and by pan_test.dart over Pan's OUTPUT:
///
/// THIS USED TO SAY the bans were enforced over the literals in this file and
/// in pan_knowledge.dart, and that sentence was true when written and false
/// by the time Pan could quote the Academy. The words were still not in
/// either file, so all four bans reported green while "what is an emergency
/// fund" came back naming three banks and quoting four to six percent per
/// annum. A guard scoped to a location is a guard until the content moves. A
/// rule about what a person sees has to be checked where the person sees it.
///
/// The four rules themselves are unchanged:
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
    this.badge,
    this.figures = const <PanFigure>[],
    this.actions = const <PanAction>[],
    this.followUps = const <String>[],
    this.aboutMoney = false,
  });

  /// A short label above the answer, saying what KIND of answer it is.
  ///
  /// Ported from the prototype's badges, with the two that could not come
  /// across left behind. Its "Financial Coach" and "CPA & Tax Advisory" claim
  /// a professional standing Salapify has not got, which is the fourth of the
  /// four bans and is also a registration question in the Philippines. A
  /// badge here says what the answer IS, never who is speaking.
  final String? badge;

  /// Which rule matched, for tests and for the screen's own label.
  final String topic;

  final String text;

  /// Figures pulled out of the sentence so the screen can show them large.
  /// A number in a paragraph is read; a number in a row is seen.
  final List<PanFigure> figures;

  /// Places in the app this answer leads to.
  ///
  /// The engine names a DESTINATION and never a Flutter route, because
  /// pan.dart has no import from lib/screens and adding one would let a
  /// money rule reach for a widget. The sheet maps an id to a screen; if it
  /// does not recognise one, nothing is shown, which is why a stale id can
  /// never crash a chat. `pan_journey_test.dart` walks every id to make sure
  /// none is quietly dead.
  final List<PanAction> actions;

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

/// Somewhere to go next, named by intent rather than by route.
class PanAction {
  const PanAction({required this.label, required this.id});
  final String label;

  /// One of the ids in `panActionIds`, which is the list the sheet switches
  /// on and the test iterates.
  final String id;
}

/// Every destination Pan is allowed to offer.
///
/// A typed list rather than free strings, so a test can walk all of them and
/// a typo cannot ship as a button that does nothing. The prototype has
/// seventeen action ids and no list, and three of them point at screens that
/// were never built.
const List<String> panActionIds = <String>[
  'log',
  'safeToSpend',
  'reports',
  'accounts',
  'debts',
  'bills',
  'academy',
  'privacy',
  'reminders',
];

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

  // 1b. CAN I AFFORD THIS, which is the most useful question a person can
  //     ask a budget app and the one it exists to answer.
  //
  //     Checked here, above the account rule, because the amount is the
  //     subject: "can I afford 2,500" with an account called Cash must not
  //     become a balance lookup. It needs BOTH an asking phrase and a
  //     readable figure, so "can I afford it" with no amount falls through to
  //     Safe to Spend, which is the honest answer to a question with no
  //     number in it.
  if (_has(q, affordTriggers)) {
    // The RAW question, not the normalised one. normalise turns every
    // non-word character into a space, so "₱2,500" reaches it as "₱2 500"
    // and the currency match takes the 2. A confidently formatted answer
    // about a two peso purchase is exactly the failure this whole feature
    // must not have.
    final double? amount = extractAmount(question);
    if (amount != null) return _afford(amount, facts);

    // "Can I afford it" names no figure, so there is nothing to judge. Safe
    // to Spend is the honest answer to that question and it is the same
    // arithmetic without the purchase, so it goes here rather than falling
    // through to "Pan did not recognise that one" on a question Pan
    // understood perfectly well.
    return _safeToSpend(facts);
  }

  // 1c. HOW AM I DOING, the whole picture rather than one figure.
  if (_has(q, healthTriggers)) return _health(facts);

  // 2. A named account, because it is the most specific thing a person can
  //    ask about and the answer is simply their own figure.
  final Account? named = _accountNamed(q, facts);
  if (named != null) return _oneAccount(named, facts);

  // 2b. "What is a budget" is a different question from "what is MY budget",
  //     and the topic rules below cannot tell them apart: both contain the
  //     word budget, so both used to come back as a list of the person's own
  //     limits. That is a confident non-answer to somebody who wanted to be
  //     taught, and the course teaching it ships in the same app.
  //
  //     Two conditions, and both are needed. The question has to ASK to be
  //     taught, and a course title has to carry every word of it, so
  //     "what is cash flow" teaches while "what is safe to spend" still
  //     answers with the figure. Any my, me or I sends it back to the
  //     figures, because "what is my net worth" is about their money.
  // 2a. SALAPIFY'S OWN ANSWER, before the curriculum and before the topics.
  //
  //     Founder direction, 2026-09-20: "what if the user has no time to
  //     navigate to the academy and they need answer in 2 sec". An explainer
  //     is written for this surface, so it needs no filtering and cannot end
  //     in "Pan does not read that lesson out here".
  //
  //     It sits under the advice boundary and the account name, and above
  //     everything else, including the figure topics: somebody typing "what
  //     is cash flow" wants the idea, and `_wantsTheConcept` decides whether
  //     they meant theirs.
  //     GATED BY THE SAME POSSESSIVE TEST as the curriculum below it, and
  //     that gate is why this is not simply first. "What is net worth" wants
  //     the idea and "what is MY net worth" wants a peso figure, and there is
  //     an explainer called Net worth that would have taken both. Questions
  //     with no opener, like "how does credit card interest work", are caught
  //     further down instead, after the figure topics have had their turn.
  if (_wantsTheConcept(q)) {
    final PanExplainer? plain = _explainerFor(q);
    if (plain != null) return _explain(plain);
  }

  if (_wantsTheConcept(q)) {
    final ({
      CourseModule? course,
      List<LessonSection> sections,
      int score,
      bool titleCovered,
    })
    lesson = _academyFor(q);
    if (lesson.course != null && lesson.titleCovered) {
      return _lesson(lesson.course!, lesson.sections);
    }
  }

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

  // 3. The app itself, and the ACADEMY, scored against each other.
  //
  // The Academy is 32 courses the app already ships, and Pan could not reach
  // one of them. "What is MP2" returned "Pan did not recognise that one"
  // while a whole course called "PAG-IBIG MP2: The Wealth Engine" sat in the
  // same build. That is the gap the founder found, and it was mine: I gave
  // Pan the ledger and the feature list and never gave it the curriculum.
  //
  // Which of the two is asked FIRST is decided by the words, not by a score.
  // Comparing the two numbers directly does not work and the attempt is worth
  // recording: a feature match is a handful of authored keywords and scores 1
  // to 3, while a course is scored over a title, a category, objectives and
  // every section, so it reached 9 on "what happens when I log an expense"
  // and buried the answer that was actually right.
  //
  // So the rule is a word list, the same shape as reservedWords one level
  // down. A question carrying an app word is about Salapify and tries the
  // feature answer first. Everything else tries the curriculum first, which
  // is what makes "what is MP2" teach.
  final ({PanFeature? feature, int score}) f = _featureFor(q);
  final ({
    CourseModule? course,
    List<LessonSection> sections,
    int score,
    bool titleCovered,
  })
  a = _academyFor(q);

  // Salapify's own explanation again, for the questions with no opener that
  // the figure topics above did not claim. "How does credit card interest
  // work" arrives here, and it is a better answer than any passage of the
  // curriculum Pan is allowed to read out.
  final PanExplainer? plain = _explainerFor(q);

  if (_has(q, appOwnWords)) {
    if (f.feature != null) return _feature(f.feature!);
    if (plain != null) return _explain(plain);
    if (a.course != null) return _lesson(a.course!, a.sections);
    return _dontKnow(facts);
  }

  if (plain != null) return _explain(plain);
  if (a.course != null) return _lesson(a.course!, a.sections);
  if (f.feature != null) return _feature(f.feature!);

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
/// Two passes, because a list of exact phrases cannot hold this line alone.
///
/// A securities review walked through the questions somebody actually types
/// once Pan will talk about a savings programme at all, and found a dozen
/// that sailed straight past twenty five phrases. "Is MP2 safe" is the
/// shape: the thing being asked about sits in the MIDDLE, so no fixed phrase
/// can contain it. [adviceShapes] holds those as patterns.
///
/// The phrase list stays, and stays first, because it is readable and most
/// questions are in it. This is the second net under it, not a replacement.
bool _looksLikeAdviceRequest(String q) {
  if (_has(q, adviceTriggers)) return true;
  for (final RegExp r in adviceShapes) {
    if (r.hasMatch(q)) return true;
  }
  return false;
}

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

/// The account a question is about, matched on WHOLE WORDS and longest first.
///
/// The first version was `q.contains(name)` with a length guard, and it was
/// wrong in both directions at once.
///
/// It fired when it should not: an account called "One" made "how much MONEY
/// do i have" answer about that account, because "money" contains "one". The
/// same for an account called "Pay" against "when is my payday", and "Due"
/// against "what bills are due". An account literally called "Cash" beat the
/// question about total cash every time, because this runs first.
///
/// And it missed when it should have fired: the WHOLE stored name had to
/// appear in the question, so "how much is in BPI" never matched an account
/// called "BPI Preferred Payroll", which is how people actually name accounts
/// and how they actually ask.
///
/// Whole words fix the first. Matching the first word as well fixes the
/// second. Longest match wins, so "GCash Business" beats "GCash" rather than
/// whichever happens to be earlier in the list.
Account? _accountNamed(String q, PanFacts facts) {
  final List<String> words = q.split(' ');
  Account? best;
  int bestLength = 0;

  bool holdsPhrase(String phrase) {
    final List<String> parts = phrase.split(' ');
    if (parts.isEmpty || parts.length > words.length) return false;
    for (int i = 0; i + parts.length <= words.length; i++) {
      bool all = true;
      for (int j = 0; j < parts.length; j++) {
        if (words[i + j] != parts[j]) {
          all = false;
          break;
        }
      }
      if (all) return true;
    }
    return false;
  }

  for (final Account a in facts.accounts) {
    final String name = normalise(a.name);
    if (name.isEmpty) continue;

    // A one word name that IS a question word loses to the question. An
    // account called "Due" answered "what bills are due", and one called
    // "Cash" beat the question about total cash every time. A longer name
    // containing the same word is unaffected, because "Due Payments Card" is
    // unambiguously a name.
    if (!name.contains(' ') && reservedWords.contains(name)) continue;

    // The full name first. A one word name still has to be a whole word, so
    // "One" no longer matches inside "money".
    if (name.length > bestLength && holdsPhrase(name)) {
      best = a;
      bestLength = name.length;
      continue;
    }

    // Then the first word, for "how much is in BPI" against "BPI Preferred
    // Payroll". Three letters minimum, so a name starting with "My" or "A"
    // cannot swallow an ordinary sentence.
    final String head = name.split(' ').first;
    if (head.length >= 3 && head.length > bestLength && holdsPhrase(head)) {
      best = a;
      bestLength = head.length;
    }
  }
  return best;
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
  // Signed for the same reason as net worth: an overdrawn set of accounts
  // reads as money held if the minus is dropped.
  return PanAnswer(
    topic: 'cash',
    text:
        'You can reach ${formatPesoWithSign(facts.liquidCash)} today across '
        '${facts.accounts.length} '
        '${facts.accounts.length == 1 ? 'account' : 'accounts'}. That counts '
        'cash, bank and e-wallet balances. A credit limit is not in there, '
        'because money you can borrow is not money you have.'
        '${facts.hasSampleData ? ' Some of this is still Salapify\'s sample data, which you can remove in Settings.' : ''}',
    figures: <PanFigure>[
      PanFigure(
        label: 'Reachable today',
        value: formatPesoWithSign(facts.liquidCash),
      ),
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
    // formatPesoWithSign, NOT formatPeso. formatPeso drops the sign, which for
    // a net worth does not understate it, it reverses it: minus 200,000 read
    // as 200,000 while Reports showed the minus for the same store.
    text:
        'Your net worth is ${formatPesoWithSign(net)}. That is '
        '${formatPeso(facts.assets)} held, less ${formatPeso(facts.liabilities)} '
        'owed on your accounts.\n\n$shape',
    figures: <PanFigure>[
      PanFigure(label: 'Net worth', value: formatPesoWithSign(net)),
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

({PanFeature? feature, int score}) _featureFor(String q) {
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
  return (feature: best, score: bestScore);
}

/// Words too common to identify a lesson on their own.
///
/// Without this, "how much money do i have" matches half the curriculum on
/// the word "money" and Pan answers a balance question with a lecture.
const Set<String> _tooCommon = <String>{
  'the',
  'a',
  'an',
  'and',
  'or',
  'of',
  'to',
  'in',
  'is',
  'it',
  'my',
  'me',
  'i',
  'you',
  'your',
  'what',
  'how',
  'why',
  'do',
  'does',
  'can',
  'about',
  'for',
  'money',
  'peso',
  'pesos',
  'much',
  'get',
  'have',
  'this',
  'that',
  'tell',
  'explain',
  'mean',
  'means',
  'work',
  'works',
  // Ordinary English that happens to appear in a lesson heading. "Explain
  // the 50 30 20 rule" reduced to the single word "rule", which matched two
  // headings in the credit card course and taught utilisation to somebody
  // asking about budgeting. A word that could head any chapter identifies
  // none of them.
  'rule',
  'rules',
  'time',
  'way',
  'ways',
  'thing',
  'things',
  'good',
  'bad',
  'best',
  'real',
  'right',
  'need',
  'needs',
  'use',
  'using',
  'one',
  'when',
  'where',
  'who',
  'which',
  'should',
  'would',
  'like',
  'want',
  'know',
  'make',
  'makes',
  'more',
  'from',
  'with',
  'are',
  'was',
  'not',
  'but',
  'over',
  'out',
  'into',
  'per',
};

/// Whether the question is asking what a thing IS, rather than what theirs is.
///
/// The possessive is the whole test. "What is net worth" wants the idea and
/// "what is my net worth" wants a peso figure, and Salapify holds both.
bool _wantsTheConcept(String q) {
  const List<String> openers = <String>[
    'what is',
    'what are',
    'whats',
    'what s',
    'explain',
    'tell me about',
    'define',
    'ano ang',
    'ano ba ang',
  ];
  if (!openers.any(q.startsWith)) return false;
  for (final String mine in <String>[' my ', ' me ', ' i ', ' ko ', ' akin']) {
    if (' $q '.contains(mine)) return false;
  }
  return true;
}

/// Whether a course's own words contain the word somebody asked about.
///
/// A short word has to be the WHOLE word, a long one may sit inside a longer
/// one. Both halves were paid for. "How do I pay my taxes" landed on a course
/// about global app revenue because "pay" is inside "Payouts", and a person
/// asking about compound interest should still reach a section headed
/// "Compounding vs. Annual Payout". Five letters is where a fragment stops
/// being an accident: mp2, sss, dti and bnpl are all short and all have to
/// match exactly.
bool _mentions(String field, String w) {
  if (w.length >= 5) return field.contains(w);
  for (final String fw in field.split(' ')) {
    if (fw == w) return true;
  }
  return false;
}

/// The Academy course a question is about, and the section that answers it.
///
/// Matched on the curriculum's own words, so it needs no keyword list to
/// maintain: adding a course to academy_data.dart makes Pan able to teach it
/// with no further work, which is the only way this stays true of 32 courses.
({
  CourseModule? course,
  List<LessonSection> sections,
  int score,
  bool titleCovered,
})
_academyFor(String q) {
  final List<String> asked = q
      .split(' ')
      .where((String w) => w.length > 2 && !_tooCommon.contains(w))
      .toList();
  if (asked.isEmpty) {
    return (
      course: null,
      sections: const <LessonSection>[],
      score: 0,
      titleCovered: false,
    );
  }

  CourseModule? best;
  List<LessonSection> bestSections = const <LessonSection>[];
  int bestScore = 0;
  bool bestCovered = false;

  for (final CourseModule c in academyCourses) {
    final String title = normalise(c.title);
    final String category = normalise(c.category);

    // NAME fields only. A course NAMES its subject in its title, its
    // category, its objectives and its section headings; its body merely
    // mentions things. Scoring the body is what made a question about
    // compound interest land on whichever lesson happened to use the word
    // most often, so the body decides nothing here and only picks which
    // section to quote, below.
    int nameScore = 0;
    int inTitle = 0;
    for (final String w in asked) {
      if (_mentions(title, w)) {
        nameScore += 6;
        inTitle++;
      }
      if (_mentions(category, w)) nameScore += 2;
      for (final String o in c.objectives) {
        if (_mentions(normalise(o), w)) nameScore += 2;
      }
      for (final LessonSection s in c.sections) {
        if (_mentions(normalise(s.title), w)) nameScore += 3;
      }
    }
    // A title carrying EVERY word asked is the course, not a candidate.
    // "Taming Lifestyle Inflation" and "Inflation: The Silent Wealth Killer"
    // both answer to "inflation"; only one of them answers to "lifestyle
    // inflation".
    final bool covered = inTitle == asked.length;
    if (covered) nameScore += 8;
    if (nameScore == 0) continue;

    // Sections RANKED, not just the winner, because the best answer to the
    // question is not always one Pan is allowed to read out. The best-scoring
    // section for "what is an emergency fund" is the one headed "Where to
    // Store Emergency Money", which names three banks and quotes a rate; the
    // next one down teaches what an emergency is and is perfectly safe. A
    // single winner leaves no second choice and throws the answer away.
    final List<({LessonSection s, int score})> ranked =
        <({LessonSection s, int score})>[];
    for (final LessonSection s in c.sections) {
      int ss = 0;
      for (final String w in asked) {
        if (normalise(s.title).contains(w)) ss += 3;
        if (normalise(s.content).contains(w)) ss += 1;
      }
      ranked.add((s: s, score: ss));
    }
    ranked.sort(
      (({LessonSection s, int score}) x, ({LessonSection s, int score}) y) =>
          y.score.compareTo(x.score),
    );

    if (nameScore > bestScore) {
      bestScore = nameScore;
      best = c;
      bestSections = ranked
          .map((({LessonSection s, int score}) r) => r.s)
          .toList();
      bestCovered = covered;
    }
  }

  // A single glancing mention is not a match. Two is the floor because one
  // objective hit is the weakest thing that still counts as the course
  // naming its own subject.
  if (bestScore < 2) {
    return (
      course: null,
      sections: const <LessonSection>[],
      score: 0,
      titleCovered: false,
    );
  }
  return (
    course: best,
    sections: bestSections,
    score: bestScore,
    titleCovered: bestCovered,
  );
}

/// Teaches from the curriculum the app already ships, in its own words.
/// Teaches from the curriculum, through the filter, with the frame first.
///
/// ## Every passage is checked before it is said, and most of this is why
///
/// The first version of this function wrote `section.content` straight into
/// the bubble. A securities review asked what came back for "what is an
/// emergency fund" and the answer was three named banks, four to six percent
/// per annum, and an instruction to store money there. Every word of it had
/// shipped on the Academy screen for weeks, where it sits under a permanent
/// educational notice, inside a course somebody opened on purpose, as chapter
/// three of three. In a chat bubble it arrives alone, chosen by Salapify,
/// because of what this person asked one second earlier. Same words, and the
/// selection is what changes them.
///
/// So each of the three things this can emit goes through [safeForPan]
/// separately, because they are three separate paths and a filter on one
/// leaves the others open:
///
///   - the SECTION, and if the best one fails, the next best that passes.
///     That is why the caller hands over a ranked list: the passage that
///     best answers the question is often the one naming products, and the
///     one below it usually teaches the concept perfectly well;
///   - each TAKEAWAY on its own, since a takeaway is written as a one-line
///     instruction by design and reads as a command with no lesson behind it;
///   - the DESCRIPTION, which is dropped entirely rather than filtered.
///     Course descriptions are written to sell a course. "One of the safest,
///     highest-yielding government-backed savings programs" is not something
///     Salapify gets to say about anything.
///
/// ## The frame goes FIRST
///
/// A disclaimer under a recommendation does not turn it into education, it
/// only records that we knew. So the line naming this as general knowledge
/// sits above the quoted passage, where it is read before the content and
/// not after it.
///
/// ## It never reads their figures, and that is deliberate
///
/// This function takes no PanFacts and returns no PanFigure. General
/// information about a subject is education; the same information mixed with
/// somebody's own balances starts to look like a recommendation shaped to
/// their situation, which is the thing Salapify is not licensed to give.
/// Keep it that way: no facts parameter, ever.
PanAnswer _lesson(CourseModule course, List<LessonSection> ranked) {
  const String frame =
      'Here is how the Salapify Academy explains it. General knowledge, not '
      'regulated tax, legal or investment advice.';

  final LessonSection? usable = ranked
      .where((LessonSection s) => safeForPan(s.content))
      .firstOrNull;

  final List<String> takeaways = course.keyTakeaways
      .where(safeForPan)
      .take(3)
      .toList();

  final StringBuffer b = StringBuffer(frame);

  if (usable != null) {
    b.write('\n\n${usable.content}');
    if (takeaways.isNotEmpty) {
      b.write('\n\nWorth remembering:');
      for (final String t in takeaways) {
        b.write('\n  $t');
      }
    }
    b.write(
      '\n\nThat is from the course "${course.title}", on the Plan tab. It '
      'runs about ${course.durationMinutes} minutes.',
    );
  } else {
    // Nothing in the course can be read out. Point at it rather than go
    // quiet: the course still answers the question, in a place where the
    // reader gets the whole chapter and the notice above it.
    b.write(
      '\n\nThe Academy covers this in "${course.title}", on the Plan tab, in '
      'about ${course.durationMinutes} minutes.',
    );
    final List<String> aims = course.objectives
        .where(safeForPan)
        .take(2)
        .toList();
    if (aims.isNotEmpty) {
      b.write('\n\nWhat it sets out to do:');
      for (final String o in aims) {
        b.write('\n  $o');
      }
    }
    b.write(
      '\n\nPan does not read that lesson out here, because parts of it name '
      'particular places to put money and quote rates of return. Those '
      'belong in the lesson, with the rest of the chapter around them, not '
      'in a one line answer.',
    );
  }

  return PanAnswer(
    topic: 'academy:${course.id}',
    // Every lesson touches money, so every one carries the trailer. That is
    // not wallpaper here: a person reading an explanation of a government
    // savings programme is exactly who needs to know it is not a nudge to
    // use one.
    aboutMoney: true,
    text: b.toString(),
    // The way to the lesson itself, and it matters most in the case where
    // nothing could be quoted. Telling somebody what Pan will not read out,
    // with no way to go and read it, is a dead end dressed as an answer.
    actions: const <PanAction>[
      PanAction(label: 'Open the course', id: 'academy'),
    ],
    followUps: <String>[
      'What is safe to spend?',
      'How much do I have right now?',
    ],
  );
}

// ---------------------------------------------------------------------------
// Salapify's own explanation
// ---------------------------------------------------------------------------

/// The explainer a question is asking for, by LONGEST matching phrase.
///
/// Longest, not first, and the difference is real: "13th month" and "month"
/// would both match a question about thirteenth month pay, and first-match
/// ordering makes the answer depend on the order somebody happened to type
/// the list in.
///
/// An ask is matched as a WHOLE phrase inside the question, so 'mp2' hits
/// "what is mp2" and "how does mp2 work" without needing either written down.
PanExplainer? _explainerFor(String q) {
  PanExplainer? best;
  int longest = 0;
  for (final PanExplainer e in panExplainers) {
    for (final String ask in e.asks) {
      if (q.contains(ask) && ask.length > longest) {
        longest = ask.length;
        best = e;
      }
    }
  }

  // A one or two letter coincidence is not a question about a subject. The
  // floor is here rather than in the data so a short real term like 'sss' or
  // 'dca' cannot be excluded by somebody tidying the list.
  if (longest < 3) return null;
  return best;
}

PanAnswer _explain(PanExplainer e) {
  final StringBuffer b = StringBuffer(e.body);

  if (e.salapifyCanDo != null) {
    // What the app can DO about it, which is the half a general explanation
    // usually leaves out. The person is already holding the tool.
    b.write('\n\nIn Salapify: ${e.salapifyCanDo}');
  }

  final CourseModule? course = e.courseId == null
      ? null
      : academyCourses
            .where((CourseModule c) => c.id == e.courseId)
            .firstOrNull;

  if (course != null) {
    b.write(
      '\n\nThere is more in the Academy course "${course.title}", on the '
      'Plan tab, about ${course.durationMinutes} minutes.',
    );
  }

  return PanAnswer(
    topic: 'explain:${e.id}',
    badge: e.title,
    // Every one of these touches money, so every one carries the trailer.
    aboutMoney: true,
    text: b.toString(),
    actions: course == null
        ? const <PanAction>[]
        : const <PanAction>[PanAction(label: 'Open the course', id: 'academy')],
    followUps: const <String>[
      'What is safe to spend?',
      'How am I doing?',
      'How much do I have right now?',
    ],
  );
}

// ---------------------------------------------------------------------------
// Can I afford it, and how am I doing
// ---------------------------------------------------------------------------

/// What a purchase does to the rest of the cycle.
///
/// The prototype's version of this ends "Recommend holding off until next
/// payday". That is an instruction about somebody's money, and it is also
/// unnecessary: a person who reads that the purchase leaves them 1,400 short
/// has been told everything they need and can decide for themselves. So this
/// one states the arithmetic and stops, which is both the safer answer and
/// the more respectful one.
PanAnswer _afford(double amount, PanFacts facts) {
  final AffordVerdict v = judgeAffordability(amount, facts);
  final StringBuffer b = StringBuffer();

  if (!v.paydayKnown) {
    b.write(
      'You have ${formatPeso(v.safeToSpendNow)} safe to spend. Spending '
      '${formatPeso(amount)} would leave ${formatPeso(v.safeToSpendAfter)}.'
      '\n\nThere is no payday set yet, so there is no daily pace to compare '
      'it against. Setting one on the Plan tab is what turns this into a '
      'figure per day.',
    );
  } else {
    switch (v.status) {
      case Afford.overBuffer:
        b.write(
          'Spending ${formatPeso(amount)} is ${formatPeso(-v.safeToSpendAfter)} '
          'more than you have safe to spend. Safe to Spend has already set '
          'aside what your bills and debts need, so this would come out of '
          'that reserve.',
        );
      case Afford.tight:
        b.write(
          'It fits, and it is tight. ${formatPeso(amount)} leaves '
          '${formatPeso(v.safeToSpendAfter)} for the ${v.daysToPayday} days '
          'to payday, which is ${formatPeso(v.dailyPaceAfter)} a day, down '
          'from ${formatPeso(v.dailyPaceNow)}.',
        );
      case Afford.comfortable:
        b.write(
          'It fits. ${formatPeso(amount)} leaves '
          '${formatPeso(v.safeToSpendAfter)} for the ${v.daysToPayday} days '
          'to payday, which is ${formatPeso(v.dailyPaceAfter)} a day, down '
          'from ${formatPeso(v.dailyPaceNow)}.',
        );
    }

    // The bills line is the reason this answer is worth more than the
    // prototype's. Safe to Spend has already reserved for them, so a person
    // can pass the check and still be surprised on Friday. Naming what is
    // coming is the difference between a number and an answer.
    if (v.billsDueBeforePayday.isNotEmpty) {
      b.write(
        '\n\nBefore that payday you have '
        '${formatPeso(v.billsBeforePayday)} of bills due: '
        '${v.billsDueBeforePayday.map((BillItem x) => x.name).join(', ')}. '
        'That is already held back inside the figure above.',
      );
    }
  }

  return PanAnswer(
    topic: 'afford',
    badge: switch (v.status) {
      Afford.comfortable => 'It fits',
      Afford.tight => 'Tight',
      Afford.overBuffer => 'Over your buffer',
    },
    text: b.toString(),
    figures: <PanFigure>[
      PanFigure(label: 'This purchase', value: formatPeso(amount)),
      PanFigure(
        label: 'Left after',
        value: formatPesoWithSign(v.safeToSpendAfter),
      ),
      if (v.paydayKnown)
        PanFigure(label: 'A day, after', value: formatPeso(v.dailyPaceAfter)),
    ],
    actions: const <PanAction>[
      PanAction(label: 'Log it as an expense', id: 'log'),
      PanAction(label: 'Inspect Safe to Spend', id: 'safeToSpend'),
    ],
    followUps: const <String>[
      'What bills are due?',
      'How am I doing?',
      'What is safe to spend?',
    ],
  );
}

/// The whole picture, scored over what could actually be measured.
PanAnswer _health(PanFacts facts) {
  final HealthCheck h = runHealthCheck(facts);

  if (!h.measurable) {
    return _nothingYet('how you are doing');
  }

  final StringBuffer b = StringBuffer(
    '${h.score} out of 100, on ${h.parts.length} '
    '${h.parts.length == 1 ? 'part' : 'parts'} of your money Salapify can '
    'see. ${h.reading}.',
  );

  for (final HealthPart p in h.parts) {
    b.write('\n\n${p.name}: ${p.reading}. ${p.points} of ${p.outOf}.');
    if (p.note != null) b.write(' ${p.note}');
  }

  // WHAT WAS NOT MEASURED IS SHOWN, never quietly dropped. A score over three
  // parts that reads like a score over four is the prototype's habit of
  // filling a gap with an invented number, arriving by a different door.
  if (h.unmeasured.isNotEmpty) {
    b.write('\n\nNot counted, because there is nothing to count yet:');
    for (final ({String name, String missing}) u in h.unmeasured) {
      b.write('\n  ${u.name}, ${u.missing}');
    }
  }

  for (final String o in h.observations) {
    b.write('\n\n$o');
  }

  return PanAnswer(
    topic: 'health',
    badge: h.reading,
    text: b.toString(),
    figures: <PanFigure>[
      PanFigure(label: 'Out of 100', value: '${h.score}'),
      for (final HealthPart p in h.parts)
        PanFigure(label: p.name, value: '${p.points}/${p.outOf}'),
    ],
    actions: const <PanAction>[
      PanAction(label: 'See Reports', id: 'reports'),
      PanAction(label: 'Inspect Safe to Spend', id: 'safeToSpend'),
    ],
    followUps: const <String>[
      'What is safe to spend?',
      'What do I owe?',
      'Where did my money go?',
    ],
  );
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
