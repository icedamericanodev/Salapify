import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/pan/pan_engine.dart';
import 'package:salapify/core/money/pan/pan_explainers.dart';
import 'package:salapify/core/money/pan/pan_bans.dart';
import 'package:salapify/core/money/pan/pan_context.dart';
import 'package:salapify/data/academy_data.dart';
import 'package:salapify/core/money/pan/pan_knowledge.dart';
import 'package:salapify/models/academy.dart';
import 'package:salapify/models/models.dart';

/// Pan: what it answers, and what it may never say.
///
/// Two halves, and the second is the one that will still matter in a year.
/// The behaviour tests check it can answer. The CONTENT tests read every
/// string Salapify itself authors and fail on the four things a securities
/// review of the prototype found in its own answers: a named product, an
/// instruction about somebody's money, a quoted return, and a professional
/// title. A content rule with no test is a rule that lasts until the next
/// person adds an answer.
void main() {
  qaRegressions();
  PanFacts facts({
    List<Account>? accounts,
    List<Transaction>? transactions,
    List<Debt>? debts,
    List<BillItem>? bills,
    List<Budget>? budgets,
    List<Goal>? goals,
    PaydayCycle? payday,
    double liquid = 23400,
    double assets = 23400,
    double liabilities = 0,
    double owed = 0,
    double owedToMe = 0,
    double safe = 12000,
    double perDay = 1200,
    double reserved = 11400,
    double monthIn = 32500,
    double monthOut = 18200,
    List<({String category, double amount})>? spending,
  }) => PanFacts(
    now: DateTime(2026, 9, 19, 12),
    accounts:
        accounts ??
        <Account>[
          const Account(
            id: 'a1',
            name: 'Everyday Savings',
            kind: AccountKind.bank,
            institution: 'Bank',
            balance: 23400,
            monogram: 'ES',
          ),
        ],
    transactions: transactions ?? const <Transaction>[],
    debts: debts ?? const <Debt>[],
    budgets: budgets ?? const <Budget>[],
    goals: goals ?? const <Goal>[],
    bills: bills ?? const <BillItem>[],
    installments: const <InstallmentPlan>[],
    upcoming: const <UpcomingItem>[],
    payday: payday ?? PaydayCycle.unset,
    liquidCash: liquid,
    assets: assets,
    liabilities: liabilities,
    owed: owed,
    owedToMe: owedToMe,
    safeToSpendUntilPayday: safe,
    safeToSpendPerDay: perDay,
    amountReserved: reserved,
    cashRunwayMonths: 2.1,
    monthIn: monthIn,
    monthOut: monthOut,
    spendingByCategory:
        spending ??
        const <({String category, double amount})>[
          (category: 'Food & Dining', amount: 8200),
          (category: 'Transport', amount: 4100),
          (category: 'Bills', amount: 3900),
        ],
    hasSampleData: false,
    phoneRemindersOn: false,
    unreadReminders: 0,
  );

  group('it knows the figures the person typed in', () {
    test('how much do I have', () {
      final PanAnswer a = askPan('how much do i have right now?', facts());
      expect(a.topic, 'cash');
      expect(a.text, contains('23,400'));
    });

    test(
      'magkano works, because Pan understands Tagalog and answers English',
      () {
        final PanAnswer a = askPan('magkano pera ko', facts());
        expect(a.topic, 'cash');
        // The REPLY is English. Understanding Tagalog input and replying in
        // Tagalog are different decisions, and the app made only the first.
        expect(a.text, isNot(contains('Magkano')));
      },
    );

    test('safe to spend gives the figure AND what was held back', () {
      final PanAnswer a = askPan('what is safe to spend?', facts());
      expect(a.topic, 'safeToSpend');
      expect(a.text, contains('12,000'));
      expect(
        a.text,
        contains('11,400'),
        reason:
            'a headline figure with no explanation of what was reserved is '
            'the number people distrust most in this app',
      );
    });

    test('net worth keeps what is held and what is owed apart', () {
      final PanAnswer a = askPan(
        'what is my net worth',
        facts(assets: 50000, liabilities: 200000),
      );
      expect(a.topic, 'netWorth');
      expect(a.text, contains('50,000'));
      expect(a.text, contains('200,000'));
      expect(
        a.text,
        contains('housing'),
        reason:
            'a net worth of minus 150,000 with no explanation is alarm with '
            'nowhere to go, and a housing loan alone can do it',
      );
    });

    test('an account by its own name', () {
      final PanAnswer a = askPan('how much is in Everyday Savings', facts());
      expect(a.topic, 'account');
      expect(a.text, contains('Everyday Savings'));
      expect(a.text, contains('23,400'));
    });

    test('a card in the red reads as owing, not as money held', () {
      final PanAnswer a = askPan(
        'what about my Gold Card',
        facts(
          accounts: <Account>[
            const Account(
              id: 'c1',
              name: 'Gold Card',
              kind: AccountKind.credit,
              institution: 'Bank',
              balance: -18400,
              monogram: 'GC',
            ),
          ],
        ),
      );
      expect(a.text, contains('owing'));
      expect(
        a.text,
        isNot(contains('holds ₱')),
        reason: 'an amount owing was read out as an amount held',
      );
    });

    test('where the month went, largest first', () {
      final PanAnswer a = askPan('where did my money go this month', facts());
      expect(a.topic, 'spending');
      expect(a.text, contains('Food & Dining'));
      expect(
        a.text.indexOf('Food & Dining'),
        lessThan(a.text.indexOf('Transport')),
      );
    });

    test('what is owed, both directions, and they never mix', () {
      final PanFacts f = facts(
        owed: 5000,
        owedToMe: 900,
        debts: <Debt>[
          const Debt(
            id: 'd1',
            person: 'Ana',
            direction: DebtDirection.iOwe,
            totalAmount: 5000,
            paidAmount: 0,
            isSettled: false,
          ),
          const Debt(
            id: 'd2',
            person: 'Mark',
            direction: DebtDirection.owedToMe,
            totalAmount: 900,
            paidAmount: 0,
            isSettled: false,
          ),
        ],
      );

      final PanAnswer mine = askPan('who do i owe', f);
      expect(mine.text, contains('Ana'));
      expect(
        mine.text,
        isNot(contains('Mark')),
        reason:
            'money owed TO you appeared in the answer about what you owe, '
            'which is the one confusion a two-way debt register must never '
            'create',
      );

      final PanAnswer theirs = askPan('who owes me money', f);
      expect(theirs.text, contains('Mark'));
      expect(theirs.text, isNot(contains('Ana')));
    });

    test('an empty ledger says so rather than inventing a zero', () {
      final PanFacts empty = facts(
        accounts: const <Account>[],
        liquid: 0,
        assets: 0,
        spending: const <({String category, double amount})>[],
      );
      final PanAnswer a = askPan('how much do i have', empty);
      expect(a.topic, 'empty');
      expect(a.text, contains('nothing recorded yet'));
    });
  });

  group('it knows the app itself', () {
    test('what happens to an entry after you save it', () {
      final PanAnswer a = askPan('what happens when i log an expense', facts());
      expect(a.topic, startsWith('feature:'));
      // The FLOW, which is what the founder asked for: one entry moving five
      // things, named.
      expect(a.text, contains('balance'));
      expect(a.text, contains('Safe to Spend'));
    });

    test('privacy, including the one thing that leaves', () {
      final PanAnswer a = askPan('is my data private', facts());
      expect(a.text, contains('private storage'));
      expect(
        a.text,
        contains('currency converter'),
        reason:
            'Pan claimed nothing leaves the phone, which is the same false '
            'absolute the header badge carried for weeks',
      );
    });

    test('every starter question is genuinely answerable', () {
      // A suggested question that produces "I did not understand" is worse
      // than no suggestion at all: it teaches somebody the assistant is
      // broken on their first tap.
      for (final String starter in panStarters) {
        final PanAnswer a = askPan(starter, facts());
        expect(
          a.topic,
          isNot('unknown'),
          reason: 'the starter chip "$starter" is not understood by Pan',
        );
      }
    });

    test('every follow-up Pan offers is answerable too', () {
      final List<String> seen = <String>[];
      for (final String starter in panStarters) {
        seen.addAll(askPan(starter, facts()).followUps);
      }
      for (final String f in seen.toSet()) {
        expect(
          askPan(f, facts()).topic,
          isNot('unknown'),
          reason: 'Pan offered "$f" and then cannot answer it',
        );
      }
    });

    test('nonsense gets an honest miss that says what Pan can do', () {
      final PanAnswer a = askPan('qwertyuiop', facts());
      expect(a.topic, 'unknown');
      expect(a.text, contains('no AI model'));
      expect(a.followUps, isNotEmpty);
    });
  });

  group('the advice boundary', () {
    test('it answers the answerable part before naming the line', () {
      final PanAnswer a = askPan('where should i put my savings?', facts());
      expect(a.topic, 'boundary');

      // Four things, all required. A refusal that leaves somebody less
      // informed sends them to a Facebook group, which is worse.
      expect(a.text, contains('Money you might need within a few days'));
      expect(a.text, contains('not something Salapify can work out'));
      expect(a.text, contains('Pan cannot see'));
      expect(a.text, contains('goal'));
    });

    test('it ends on something to do, never on the refusal', () {
      final PanAnswer a = askPan('should i invest in something', facts());
      expect(a.followUps, isNotEmpty);
      expect(a.display, endsWith(PanAnswer.trailer));
    });

    test('it wins over a topic that would otherwise match', () {
      // "where should i save" contains "save". Without the boundary being
      // checked FIRST, this answers with a goals summary, which is a
      // confident non-answer to a question about what to do.
      expect(askPan('where should i save my money', facts()).topic, 'boundary');
      expect(askPan('should i buy this', facts()).topic, 'boundary');
      expect(askPan('which bank is best', facts()).topic, 'boundary');
    });

    test('an ordinary question does NOT get the boundary', () {
      // The other half of the alarm. A boundary that fires on everything is
      // an assistant that answers nothing.
      expect(askPan('how much do i have', facts()).topic, 'cash');
      expect(askPan('what is due soon', facts()).topic, 'due');
    });

    test('the trailer is on money answers and off the rest', () {
      // A disclaimer on every message is wallpaper within two days, and then
      // it is not there for the one that matters.
      expect(
        askPan('should i invest', facts()).display,
        contains(PanAnswer.trailer),
      );
      expect(
        askPan('who owes me money', facts()).display,
        isNot(contains(PanAnswer.trailer)),
      );
    });
  });

  group('what Pan may never say', () {
    /// Every string literal Salapify itself authors for Pan.
    ///
    /// Comments are stripped, because these files DOCUMENT the banned words in
    /// order to ban them, and a guard that forbids naming the thing it guards
    /// against gets deleted by the next person who trips over it.
    List<String> panSource() {
      final List<String> out = <String>[];
      for (final String path in <String>[
        'lib/core/money/pan/pan_engine.dart',
        'lib/core/money/pan/pan_knowledge.dart',
      ]) {
        out.add(
          File(path)
              .readAsLinesSync()
              .where((String l) => !l.trimLeft().startsWith('//'))
              .join('\n'),
        );
      }
      return out;
    }

    void banned(List<String> words, String why) {
      final List<String> hits = <String>[];
      for (final String text in panSource()) {
        for (final String w in words) {
          if (text.toLowerCase().contains(w.toLowerCase())) hits.add(w);
        }
      }
      expect(hits, isEmpty, reason: why);
    }

    test(
      'no bank, wallet, fund or product is named in Salapify\'s own words',
      () {
        // The rule is sharper than "do not name things", and the distinction is
        // one grep: a product name that came from the USER'S data is fine and
        // necessary, because refusing to say "your BPI Savings holds X" would
        // make the assistant useless. A product name that is a literal in
        // Salapify's source is not.
        banned(
          <String>[
            'MP2',
            'MariBank',
            'GoTyme',
            'SeaBank',
            'Tonik',
            'CIMB',
            'UITF',
            'Atome',
            'BillEase',
            'Binance',
            'bitcoin',
          ],
          'Salapify named a specific product in its own voice. Under PH '
          'securities law, information intended to bring a transaction about '
          'is the test, and an app that names where to put money is doing '
          'exactly that.',
        );
      },
    );

    test('no instruction about the reader\'s money', () {
      banned(
        <String>[
          'you should',
          'we recommend',
          'i recommend',
          'invest in ',
          'put your money',
          'move your money',
          'keep it in',
          'best place to',
        ],
        'Pan told somebody what to do with their money. It may do the '
        'arithmetic and name the consequence; the decision is theirs.',
      );
    });

    test('no yield, return or forward-looking figure', () {
      banned(
        <String>[
          '% p.a.',
          'per annum',
          'tax-free dividend',
          'guaranteed return',
          'average return',
        ],
        'Pan quoted a performance figure. It cannot be kept current in an '
        'app with no network, and a stale yield is worse than none.',
      );
    });

    test('no professional title Salapify has not got', () {
      banned(
        <String>[
          'CPA',
          'financial adviser',
          'financial advisor',
          'expert council',
          'financial coach',
          'certified',
          'licensed adviser',
        ],
        'Pan claimed professional standing. A badge is two words and feels '
        'harmless, and it is the thing that makes a reader treat a string '
        'match as qualified to tell them what to do.',
      );
    });

    test('it is never CLAIMED to be AI, though it may deny being one', () {
      // There is no model, no inference and no network, so "AI" is a claim
      // about a characteristic the product does not have.
      //
      // The first version of this banned the two letters outright and failed
      // on Pan's own honest line, "There is no AI model and nothing leaves
      // your phone". That sentence is the best privacy copy in the app and is
      // the opposite of the harm. So what is banned is the CLAIM, phrase by
      // phrase, and a denial is left alone.
      banned(
        <String>[
          'ai assistant',
          'ai powered',
          'ai-powered',
          'powered by ai',
          'pan ai',
          'ai model that',
          'artificial intelligence',
          'copilot',
          'smart ai',
        ],
        'Pan is presented as AI. It is keyword matching over figures the '
        'person typed in, which is a better claim and a true one.',
      );
    });

    test('no reply promises an encrypted backup', () {
      // The prototype's knowledge base says people "can export an encrypted
      // JSON backup file". The export is JsonEncoder.withIndent.
      banned(<String>[
        'encrypted backup',
        'encrypted JSON',
        'bank grade',
      ], 'Pan promised a protection the export does not have.');
    });

    test('and the ban is scoped, not a blanket silence', () {
      // Without this, somebody eventually "fixes" a failure above by
      // censoring the user's own data, which would break the feature to
      // satisfy the guard.
      final PanAnswer a = askPan(
        'how much is in my MP2 Savings',
        facts(
          accounts: <Account>[
            const Account(
              id: 'a1',
              name: 'MP2 Savings',
              kind: AccountKind.bank,
              institution: 'Pag-IBIG',
              balance: 41000,
              monogram: 'MP',
            ),
          ],
        ),
      );
      expect(
        a.text,
        contains('MP2 Savings'),
        reason:
            'Pan refused to name an account the person themselves created, '
            'which makes it useless rather than careful',
      );
      expect(a.text, contains('41,000'));
    });
  });

  group('it teaches from the Academy the app already ships', () {
    // Founder finding, 2026-09-20: "why Pan cannot answer the questions I fed
    // into it, in the prototype Pan knows about the courses and academy".
    // Asking "what is MP2" returned the honest miss while a course called
    // "PAG-IBIG MP2: The Wealth Engine" sat in the same build, unreachable.
    // Pan had the ledger and the feature list and never had the curriculum.

    test('what is MP2 teaches, and says which course goes deeper', () {
      // This began as an assertion that Pan QUOTED the MP2 lesson. It does
      // not any more, and the change came from the founder: the lesson
      // quotes a dividend range Salapify may not repeat, so quoting meant
      // refusing, and refusing produced "Pan does not read that lesson out
      // here", which is the original complaint wearing better manners.
      // Salapify writes its own answer now, and still names the course.
      final PanAnswer a = askPan('what is mp2', facts());
      expect(a.topic, 'explain:mp2');
      expect(a.text, contains('Pag-IBIG'));
      expect(
        a.text,
        contains('PAG-IBIG MP2: The Wealth Engine'),
        reason:
            'an answer on a subject the Academy covers must say where the '
            'longer version is',
      );
      expect(
        a.aboutMoney,
        isTrue,
        reason:
            'a lesson about a savings programme is exactly the answer that '
            'needs the trailer saying this is not a nudge to use one',
      );
    });

    test('EVERY course is reachable by its own name', () {
      // Derived from the registry rather than a typed list of examples, so a
      // course added to academy_data.dart is covered the day it lands. A
      // typed set of favourites would have passed while thirty of them
      // stayed unreachable, which is the bug this group exists for.
      final List<String> unreachable = <String>[];
      for (final CourseModule c in academyCourses) {
        final PanAnswer a = askPan('what is ${c.title}', facts());
        // EITHER prefix counts, and that is the point rather than a
        // loosening. A course whose subject Salapify explains in its own
        // words is answered better by the explainer, and the explainer names
        // the course. What must never happen is the honest miss.
        final bool taught =
            a.topic.startsWith('academy:') || a.topic.startsWith('explain:');
        if (!taught) unreachable.add('${c.title} -> ${a.topic}');
      }
      expect(
        unreachable,
        isEmpty,
        reason:
            'a course nobody can ask Pan about is a course Pan does not have',
      );
    });

    test('a question about the APP still gets the app answer', () {
      // The curriculum is large and its words are ordinary, so it out-scored
      // the feature list on its first build: "is my data private" reached a
      // course on startup data privacy compliance, which is a true answer to
      // a question nobody asked.
      expect(askPan('is my data private', facts()).topic, 'feature:privacy');
      expect(
        askPan('how do i back up my data', facts()).topic,
        'feature:backup',
      );
      expect(
        askPan('what happens when i log an expense', facts()).topic,
        'feature:flow',
      );
      expect(
        askPan('how do reminders work', facts()).topic,
        'feature:reminders',
      );
    });

    test('a question about THEIR figures still gets the figure', () {
      expect(askPan('what is my net worth', facts()).topic, 'netWorth');
      expect(askPan('how much do i have', facts()).topic, 'cash');
      expect(askPan('what is my budget', facts()).topic, 'budgets');
      expect(askPan('what is safe to spend', facts()).topic, 'safeToSpend');
      expect(askPan('what is my biggest expense', facts()).topic, 'spending');
    });

    test('the possessive is what separates the idea from the amount', () {
      // "What is net worth" wants the idea. "What is MY net worth" wants a
      // peso figure. Salapify holds both and the only thing telling them
      // apart is the word my.
      expect(askPan('what is net worth', facts()).topic, 'explain:networth');
      expect(askPan('what is my net worth', facts()).topic, 'netWorth');
      expect(askPan('what is cash flow', facts()).topic, 'explain:cashflow');
      expect(askPan('what is my cash flow', facts()).topic, 'cash');
    });

    test('the advice boundary still comes first, even on a course subject', () {
      // The dangerous case. MP2 is now something Pan will happily explain,
      // and "should I put my money in MP2" is still a question about what to
      // do with somebody's savings, which Pan does not answer.
      for (final String q in <String>[
        'should i invest in mp2',
        'should i put my money in mp2',
        'is mp2 a good idea',
        'what should i invest in',
        'which is better mp2 or a time deposit',
      ]) {
        expect(
          askPan(q, facts()).topic,
          'boundary',
          reason: '"$q" asks what to DO with money and got taught instead',
        );
      }
    });

    test('a question the curriculum cannot answer still misses honestly', () {
      // No paluwagan course ships, so Pan says so rather than reaching for
      // whichever lesson happens to share a word. A confident wrong lesson is
      // worse than an honest miss.
      // Paluwagan USED to be the example here, because no course covered it.
      // Salapify explains it itself now, which is the right outcome and
      // meant this test needed a subject the app genuinely has nothing on.
      expect(askPan('what is a paluwagan', facts()).topic, 'explain:paluwagan');
      expect(askPan('what is the weather', facts()).topic, 'unknown');
      expect(askPan('who won the game last night', facts()).topic, 'unknown');
    });
  });

  group('the bans follow what Pan SAYS, not which file it was typed in', () {
    // This group exists because the four content bans went green while
    // broken, for a whole batch. They read two source files, which was the
    // same thing as reading Pan's output right up until Pan could quote the
    // Academy. Then "what is an emergency fund" came back naming three banks
    // and quoting four to six percent per annum, and every ban still
    // reported PASS, because none of those words had been typed into either
    // file. A guard scoped to a location stops being a guard the moment the
    // content moves.
    //
    // A securities review found it. No test could have, in that shape.

    test('no answer to any question names a bank or quotes a return', () {
      // Deliberately includes the questions the review traced by hand, and
      // every course title, so a course added later is swept too.
      final List<String> corpus = <String>[
        'what is an emergency fund',
        'what is wealth',
        'what is inflation',
        'what is compound interest',
        'what is a digital bank',
        'what is a time deposit',
        'do i need life insurance',
        'how do i get out of debt',
        'what is bnpl',
        'how do i send money home as an ofw',
        'what is diversification',
        'how do i pay my taxes',
        'what is budgeting',
        'what is cash flow',
        'what is retirement',
        'how much do i have',
        'what is safe to spend',
        'who owes me money',
        'where should i put my savings',
        for (final CourseModule c in academyCourses) 'what is ${c.title}',
      ];

      // Quoted spans are stripped, and this is the one carve-out in the
      // guard, so it is written down rather than buried. What sits in quotes
      // in a Pan answer is the NAME of the course the answer came from, and
      // one course is called "High-Yield Digital Banking". Refusing to say
      // that would stop Pan naming its own source, which is the thing
      // keeping the answer on the education side. A citation is a name and
      // asserts nothing; the sentence around it is checked in full. Course
      // titles get their own, stricter check in the test below.
      final RegExp citation = RegExp('"[^"]*"');

      final List<String> offenders = <String>[];
      for (final String q in corpus) {
        final String said = askPan(q, facts()).display.replaceAll(citation, '');
        final String? bad = bannedPhraseIn(said);
        if (bad != null) offenders.add('"$q" said "$bad"');
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Pan put a named provider, a quoted return, an instruction about '
            'the reader\'s money, or a professional title on the screen',
      );
    });

    test('EVERY explainer Salapify writes is safe to say', () {
      // Derived from the collection, not from a list of questions, and that
      // difference was a real gap for one round. The sweep above asks a fixed
      // set of questions, so an explainer nobody thought to ask about was
      // never checked. A derived set is a rule; a typed corpus is a promise,
      // and this one was already half broken when it was written.
      final List<String> offenders = <String>[];
      for (final PanExplainer e in panExplainers) {
        for (final ({String what, String text}) part
            in <({String what, String text})>[
              (what: 'title', text: e.title),
              (what: 'body', text: e.body),
              if (e.salapifyCanDo != null)
                (what: 'in Salapify', text: e.salapifyCanDo!),
            ]) {
          final String? bad = bannedPhraseIn(part.text);
          if (bad != null) offenders.add('${e.id} ${part.what}: "$bad"');
        }
      }
      expect(offenders, isEmpty);
    });

    test('an explainer never quotes what money earns', () {
      // The specific thing these exist to avoid. A rate in an app with no
      // network is stale the day it ships and the reader has no way to know,
      // which is worse than no figure at all.
      for (final PanExplainer e in panExplainers) {
        expect(
          RegExp(r'\d+(\.\d+)?\s*%').hasMatch(e.body),
          isFalse,
          reason: '${e.id} states a percentage, which rots offline',
        );
      }
    });

    test('an explainer actually explains, rather than deferring', () {
      // The founder's whole complaint in one assertion: "what if the user has
      // no time to navigate to the academy and they need answer in 2 sec".
      final PanAnswer a = askPan('what is mp2', facts());
      expect(a.topic, 'explain:mp2');
      expect(
        a.text,
        isNot(contains('does not read that lesson out here')),
        reason: 'Pan deferred instead of answering',
      );
      expect(a.text, contains('Pag-IBIG Fund'));
      expect(a.text, contains('five years'));
      expect(
        a.text.length,
        greaterThan(400),
        reason: 'a two sentence answer is a brush-off with better manners',
      );
    });

    test('every explainer body is long enough to be an answer', () {
      for (final PanExplainer e in panExplainers) {
        expect(
          e.body.length,
          greaterThan(300),
          reason: '${e.id} is too short to have said anything',
        );
      }
    });

    test('a course an explainer points at actually exists', () {
      // A courseId typo ships as a paragraph that promises a lesson and a
      // button that opens nothing.
      for (final PanExplainer e in panExplainers) {
        if (e.courseId == null) continue;
        expect(
          academyCourses.any((CourseModule c) => c.id == e.courseId),
          isTrue,
          reason:
              '${e.id} points at a course "${e.courseId}" that is not there',
        );
      }
    });

    test('no course is NAMED after a company', () {
      // The strict half of the carve-out above. A course may be called
      // "High-Yield Digital Banking", because that describes a kind of
      // account. None may be called after a particular company, because
      // Pan quotes titles verbatim and that would put an endorsement in its
      // mouth through the one door left open.
      for (final CourseModule c in academyCourses) {
        expect(
          safeToCite(c.title),
          isTrue,
          reason: '"${c.title}" names a company, and Pan quotes titles',
        );
      }
    });

    test('a passage Pan may not read is pointed at, not swallowed', () {
      // The other half. A filter that answers nothing is not safer, it is
      // just useless, and the founder's original complaint was Pan having
      // nothing to say. So when the whole course is unquotable, the answer
      // still has to name the course and say where it is.
      final PanAnswer a = askPan('what is wealth', facts());
      expect(a.topic, startsWith('academy:'));
      expect(a.text, contains('on the Plan tab'));
      expect(
        a.text,
        contains('does not read that lesson out here'),
        reason: 'Pan went quiet instead of pointing somewhere useful',
      );
    });

    test('the frame is read BEFORE the lesson, not after it', () {
      final PanAnswer a = askPan('what is an emergency fund', facts());
      expect(
        a.text.indexOf('General knowledge'),
        lessThan(a.text.indexOf('emergency')),
        reason:
            'a notice under a passage records that we knew, it does not '
            'change what the reader read first',
      );
    });

    test('questions that ask Pan to vouch for a product get the boundary', () {
      // Every one of these reached a lesson before the review. The subject
      // sits in the MIDDLE of the sentence, which is why a list of fixed
      // phrases could never hold them and adviceShapes exists.
      for (final String q in <String>[
        'is mp2 safe',
        'is mp2 legit',
        'how much can i earn in mp2',
        'where do i open an mp2 account',
        'how do i start investing',
        'is mp2 better than a bank',
        'mp2 or stocks',
        'is now a good time to invest',
        'what is the best way to invest my money',
        // Tagalog. Pan understands it everywhere else, so the boundary has
        // to as well, or it holds in one language only.
        'saan ko ilalagay ang ipon ko',
        'saan maganda maglagay ng pera',
        'dapat ba akong mag invest',
      ]) {
        expect(
          askPan(q, facts()).topic,
          'boundary',
          reason: '"$q" asks Salapify to vouch for or pick a product',
        );
      }
    });

    test('a lesson answer never carries the reader\'s own figures', () {
      // The single thing keeping curriculum text on the education side is
      // that it is never mixed with this person's balances. General
      // information is education; the same information shaped around
      // somebody's own money starts to look like a recommendation for them.
      for (final CourseModule c in academyCourses) {
        final PanAnswer a = askPan('what is ${c.title}', facts());
        if (!a.topic.startsWith('academy:')) continue;
        expect(
          a.figures,
          isEmpty,
          reason: '${c.title} returned a lesson carrying the reader\'s money',
        );
        expect(
          a.text,
          isNot(contains('23,400')),
          reason: '${c.title} read the reader\'s balance into a lesson',
        );
      }
    });
  });
}

/// Findings from an adversarial QA pass, each pinned so it cannot return.
void qaRegressions() {
  PanFacts ledger({
    List<Account>? accounts,
    double liquid = 23400,
    double assets = 23400,
    double liabilities = 0,
  }) => PanFacts(
    now: DateTime(2026, 9, 19, 12),
    accounts: accounts ?? const <Account>[],
    transactions: const <Transaction>[],
    debts: const <Debt>[],
    budgets: const <Budget>[],
    goals: const <Goal>[],
    bills: const <BillItem>[],
    installments: const <InstallmentPlan>[],
    upcoming: const <UpcomingItem>[],
    payday: PaydayCycle.unset,
    liquidCash: liquid,
    assets: assets,
    liabilities: liabilities,
    owed: 0,
    owedToMe: 0,
    safeToSpendUntilPayday: 0,
    safeToSpendPerDay: 0,
    amountReserved: 0,
    cashRunwayMonths: 1,
    monthIn: 0,
    monthOut: 0,
    spendingByCategory: const <({String category, double amount})>[],
    hasSampleData: false,
    phoneRemindersOn: false,
    unreadReminders: 0,
  );

  Account account(String name, double balance) => Account(
    id: name,
    name: name,
    kind: balance < 0 ? AccountKind.credit : AccountKind.bank,
    institution: 'Somewhere',
    balance: balance,
    monogram: 'XX',
  );

  group('a negative figure keeps its minus sign', () {
    test('net worth below zero is not reported as money held', () {
      // formatPeso drops the sign on purpose, and for a net worth that does
      // not understate it, it REVERSES it. Reports showed minus 200,000 and
      // Pan showed 200,000 for the same store on the same afternoon.
      final PanAnswer a = askPan(
        'what is my net worth',
        ledger(
          accounts: <Account>[account('Savings', 100000)],
          assets: 100000,
          liabilities: 300000,
        ),
      );
      expect(
        a.text,
        contains('-₱200,000.00'),
        reason: 'a net worth of minus 200,000 was read out as a positive sum',
      );
      expect(a.figures.first.value, '-₱200,000.00');
    });

    test('and a positive one carries no sign at all', () {
      final PanAnswer a = askPan(
        'what is my net worth',
        ledger(
          accounts: <Account>[account('Savings', 100000)],
          assets: 100000,
          liabilities: 40000,
        ),
      );
      expect(a.text, contains('₱60,000.00'));
      expect(a.text, isNot(contains('-₱60,000.00')));
    });

    test('overdrawn cash reads as overdrawn', () {
      final PanAnswer a = askPan(
        'how much do i have',
        ledger(accounts: <Account>[account('Everyday', -5000)], liquid: -5000),
      );
      expect(a.text, contains('-₱5,000.00'));
    });
  });

  group('an account name does not swallow the sentence', () {
    test('an account called One does not answer a question about money', () {
      // "money" contains "one". The old match was a bare substring test, so
      // "how much MONEY do i have" answered about the account.
      final PanFacts f = ledger(accounts: <Account>[account('One', 42)]);
      expect(askPan('how much money do i have', f).topic, 'cash');
      expect(askPan('where did my money go', f).topic, isNot('account'));
    });

    test('accounts called Pay and Due do not hijack their words', () {
      expect(
        askPan(
          'when is my payday',
          ledger(accounts: <Account>[account('Pay', 42)]),
        ).topic,
        'payday',
      );
      expect(
        askPan(
          'what bills are due',
          ledger(accounts: <Account>[account('Due', 42)]),
        ).topic,
        'due',
      );
    });

    test('the LONGEST matching account wins, not the first in the list', () {
      final PanFacts f = ledger(
        accounts: <Account>[
          account('GCash', 500),
          account('GCash Business', 90000),
        ],
      );
      final PanAnswer a = askPan('how much is in my gcash business', f);
      expect(
        a.text,
        contains('₱90,000.00'),
        reason:
            'the shorter name matched first and answered about the '
            'wrong account',
      );
    });

    test('the first word of a long account name is enough', () {
      // The converse failure: the WHOLE stored name had to appear in the
      // question, so "how much is in BPI" never matched "BPI Preferred
      // Payroll", which is how people name accounts and how they ask.
      final PanFacts f = ledger(
        accounts: <Account>[account('BPI Preferred Payroll', 12400)],
      );
      final PanAnswer a = askPan('how much is in bpi', f);
      expect(a.topic, 'account');
      expect(a.text, contains('₱12,400.00'));
    });

    test('and an exact name still works', () {
      final PanFacts f = ledger(accounts: <Account>[account('Everyday', 300)]);
      expect(askPan('how much is in everyday', f).topic, 'account');
    });
  });
}
