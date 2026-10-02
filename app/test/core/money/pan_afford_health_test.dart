import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/pan/pan_affordability.dart';
import 'package:salapify/core/money/pan/pan_context.dart';
import 'package:salapify/core/money/pan/pan_engine.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/core/money/money.dart';

/// "Can I afford this" and "how am I doing", the two questions the prototype
/// answers best and the two that were missing here.
///
/// Both are MEASURED answers, which is what makes them worth testing hard: a
/// wrong figure in a measured answer does not look wrong. It looks like a
/// measurement.
///
/// "How am I doing" no longer carries a score. Founder decision F9 retired
/// Pan's own four-part engine so the whole app runs one health check, the
/// five-question one, and these tests cover Pan's ANSWER rather than the
/// engine behind it.
void main() {
  PanFacts facts({
    List<Account>? accounts,
    List<Transaction>? transactions,
    List<BillItem>? bills,
    PaydayCycle? payday,
    double safe = 12000,
    double perDay = 1200,
    double assets = 23400,
    double liabilities = 0,
    double owedToMe = 0,
    double runway = 2.1,
    bool runwayMeasured = true,
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
            balance: Money.pesos(23400),
            monogram: 'ES',
          ),
        ],
    transactions: transactions ?? const <Transaction>[],
    debts: const <Debt>[],
    budgets: const <Budget>[],
    goals: const <Goal>[],
    bills: bills ?? const <BillItem>[],
    installments: const <InstallmentPlan>[],
    upcoming: const <UpcomingItem>[],
    payday:
        payday ??
        const PaydayCycle(
          cycleType: '15_30',
          lastPayday: '2026-09-15',
          nextPayday: '2026-09-30',
          daysToPayday: 10,
          expectedIncome: 32500,
        ),
    liquidCash: 23400,
    assets: assets,
    liabilities: liabilities,
    owed: 0,
    owedToMe: owedToMe,
    safeToSpendUntilPayday: safe,
    safeToSpendPerDay: perDay,
    amountReserved: 11400,
    cashRunwayMonths: runway,
    runwayFromLoggedSpending: runwayMeasured,
    monthIn: 32500,
    monthOut: 18200,
    spendingByCategory: const <({String category, double amount})>[],
    hasSampleData: false,
    phoneRemindersOn: false,
    unreadReminders: 0,
  );

  group('can I afford it', () {
    test('a comfortable purchase reports what is left and the new pace', () {
      final AffordVerdict v = judgeAffordability(2000, facts());
      expect(v.status, Afford.comfortable);
      expect(v.safeToSpendAfter, 10000);
      expect(v.dailyPaceAfter, 1000);
    });

    test('a purchase that eats the pace is tight, not a refusal', () {
      // 11,000 of a 12,000 buffer leaves 100 a day over ten days, under the
      // 150 rule of thumb. It FITS, and saying only "yes" would be the less
      // useful half of the answer.
      final AffordVerdict v = judgeAffordability(11000, facts());
      expect(v.status, Afford.tight);
      expect(v.dailyPaceAfter, 100);
    });

    test('the shortfall keeps its minus sign', () {
      // Clamping to zero turns "you are 1,400 short" into "you have nothing
      // left". Those read the same and are not the same, and the size of the
      // hole is the whole answer.
      final AffordVerdict v = judgeAffordability(13400, facts());
      expect(v.status, Afford.overBuffer);
      expect(v.safeToSpendAfter, -1400);
    });

    test('bills falling before payday are named, not just reserved', () {
      // The reason this answer beats the prototype's. Safe to Spend has
      // already held money back for these, so a person can pass the check and
      // still be surprised on Friday.
      final AffordVerdict v = judgeAffordability(
        2000,
        facts(
          bills: <BillItem>[
            const BillItem(
              id: 'b1',
              name: 'Electricity',
              amount: 2400,
              dueDate: '2026-09-24',
              isPaid: false,
            ),
            const BillItem(
              id: 'b2',
              name: 'Way after payday',
              amount: 9000,
              dueDate: '2026-11-02',
              isPaid: false,
            ),
            const BillItem(
              id: 'b3',
              name: 'Already paid',
              amount: 800,
              dueDate: '2026-09-22',
              isPaid: true,
            ),
          ],
        ),
      );
      expect(v.billsBeforePayday, 2400);
      expect(
        v.billsDueBeforePayday.map((BillItem b) => b.name),
        <String>['Electricity'],
        reason:
            'a bill after payday, or one already paid, is not money this '
            'cycle still has to find',
      );
    });

    test('with no payday set there is no daily pace to invent', () {
      final AffordVerdict v = judgeAffordability(
        2000,
        facts(payday: PaydayCycle.unset),
      );
      expect(v.paydayKnown, isFalse);
      expect(v.dailyPaceAfter, 0);
      expect(
        v.billsDueBeforePayday,
        isEmpty,
        reason:
            'without a payday there is no horizon, so "before payday" would '
            'quietly mean "ever" and show a year of bills as this fortnight',
      );
    });
  });

  group('the question reaches the answer with the right number', () {
    test('a comma does not cut the amount down to one digit', () {
      // The defect this test exists for: normalise turns every non-word
      // character into a space, so "₱2,500" arrives as "₱2 500" and the
      // currency match takes the 2. Pan would then answer, in full and
      // confidently, about a two peso purchase.
      final PanAnswer a = askPan('can i afford ₱2,500', facts());
      expect(a.topic, 'afford');
      expect(a.text, contains('2,500'));
      expect(
        a.figures.first.value,
        '₱2,500.00',
        reason: 'the amount was read from the normalised question',
      );
    });

    test('Taglish reaches it too', () {
      expect(askPan('kaya ko ba ang 2.5k', facts()).topic, 'afford');
      expect(askPan('afford ko ba 10k', facts()).topic, 'afford');
      expect(askPan('pwede ba bilhin ang 899', facts()).topic, 'afford');
    });

    test('an asking phrase with no amount falls through honestly', () {
      // "Can I afford it" names nothing, so there is nothing to judge. Safe
      // to Spend is the true answer, not a made-up figure.
      expect(askPan('can i afford it', facts()).topic, 'safeToSpend');
    });

    test('an account called Cash does not swallow the amount', () {
      final PanAnswer a = askPan(
        'can i afford 2000',
        facts(
          accounts: <Account>[
            const Account(
              id: 'a1',
              name: 'Cash',
              kind: AccountKind.cash,
              institution: 'Wallet',
              balance: Money.pesos(900),
              monogram: 'C',
            ),
          ],
        ),
      );
      expect(a.topic, 'afford');
    });
  });

  group('how am I doing', () {
    // ONE HEALTH CHECK, by founder decision F9. Pan used to run its own
    // scoring engine, `pan_health.dart`, which marked four weighted parts out
    // of a hundred. The Health Check sheet runs the five-question engine in
    // `core/money/health_check.dart`. Both were defensible and they answered
    // the same question differently, so a person who opened the sheet and
    // then asked Pan got two readings of their own money.
    //
    // These tests are about the ANSWER, because the engine behind it is
    // already covered by `health_check_test.dart` and testing it twice here
    // is how the second engine survived as long as it did.

    /// Expenses spread over [days] separate days, so the pace is a
    /// measurement and not a guess. `paceNeedsDays` is 5.
    List<Transaction> spending({
      required int days,
      required double perDay,
      double income = 0,
      int startDay = 5,
    }) => <Transaction>[
      if (income > 0)
        Transaction(
          id: 'in',
          type: TransactionType.income,
          amount: Money.fromDouble(income),
          category: 'Salary',
          accountId: 'a1',
          date: '2026-09-15',
          createdAt: 1757900000000,
        ),
      for (int d = 0; d < days; d++)
        Transaction(
          id: 'e$d',
          type: TransactionType.expense,
          amount: Money.fromDouble(perDay),
          category: 'Food',
          accountId: 'a1',
          date: '2026-09-${(startDay + d).toString().padLeft(2, '0')}',
          createdAt: 1758000000000 + d,
        ),
    ];

    test('the tightest question leads, and it is not an average', () {
      // 2,800 a day against 23,400 held, with ten days to payday, is 4,600
      // short. An average over five questions would have reported a number
      // somewhere in the middle of that and three comfortable answers, which
      // is exactly how an 85 out of 100 once sat directly above "you owe more
      // than you hold".
      final PanAnswer a = askPan(
        'how am i doing',
        facts(transactions: spending(days: 7, perDay: 12000)),
      );

      expect(a.topic, 'health');
      expect(a.badge, 'Needs attention');
      expect(
        a.text,
        'Will I make it to payday? ₱4,600.00 short, on the pace you are on.',
      );
    });

    test(
      'and the leading question is the soonest one, not merely the worst',
      () {
        // Two answers come back tight on this ledger: payday, and keeping any
        // of it (84,000 out and nothing in). Both are real. The one that leads
        // has to be the one happening soonest, or the answer opens on a monthly
        // trend while somebody runs out of money on Thursday.
        final PanAnswer a = askPan(
          'how am i doing',
          facts(transactions: spending(days: 7, perDay: 12000)),
        );

        expect(a.text, startsWith('Will I make it to payday?'));
        expect(
          a.points.join(' '),
          contains('more out than in'),
          reason: 'the other tight answer must still be in the reply, below',
        );
      },
    );

    test('a comfortable ledger does not invent something to worry about', () {
      // The other half of the alarm, and the half that gets skipped. A rule
      // that always names a tightest question cries wolf on every answer,
      // and then it is not there for the one that matters.
      final PanAnswer a = askPan(
        'how am i doing',
        facts(transactions: spending(days: 7, perDay: 300, income: 32500)),
      );

      expect(a.badge, 'Nothing tight');
      expect(a.text, startsWith('Nothing tight on the'));
    });

    test('there is no score out of a hundred anywhere in the answer', () {
      // The guard for F9 itself. A single number standing in for five
      // separate questions is what hid the one that mattered, so it must not
      // come back in a figure row, a badge or a sentence.
      final PanAnswer a = askPan(
        'how am i doing',
        facts(transactions: spending(days: 7, perDay: 300, income: 32500)),
      );

      final String everything = <String>[
        a.text,
        a.badge ?? '',
        a.more ?? '',
        ...a.points,
        ...a.figures.map((PanFigure f) => '${f.label} ${f.value}'),
      ].join(' ');

      expect(everything, isNot(contains('out of 100')));
      expect(everything, isNot(matches(RegExp(r'\b\d{1,3}/100\b'))));
    });

    test('the one figure it does show is how much of the picture there is', () {
      // The honest replacement. On this ledger the pace is measured, so
      // payday and keeping answer; nothing is promised on a schedule, so that
      // answers too; there is no cushion goal and no budget, so two do not.
      final PanAnswer a = askPan(
        'how am i doing',
        facts(transactions: spending(days: 7, perDay: 300, income: 32500)),
      );

      expect(a.figures.single.label, 'Questions answered');
      expect(a.figures.single.value, '3 of 5');
    });

    test('what cannot be answered is named, not quietly dropped', () {
      final PanAnswer a = askPan(
        'how am i doing',
        facts(transactions: spending(days: 7, perDay: 300, income: 32500)),
      );

      final String open = a.points.lastWhere(
        (String p) => p.startsWith('Not answered yet'),
      );
      expect(open, contains('do i have a cushion'));
      expect(open, contains('am i inside the limits i set'));

      // And what each missing one NEEDS is one tap away rather than gone.
      expect(a.more, contains('emergency fund'));
      expect(a.more, contains('No limits set yet'));
    });

    test('nothing recorded says so instead of answering zero', () {
      expect(
        askPan(
          'how am i doing',
          facts(
            accounts: const <Account>[],
            payday: PaydayCycle.unset,
            assets: 0,
            liabilities: 0,
          ),
        ).topic,
        'empty',
        reason: 'a zero on an empty app is a made-up verdict',
      );
    });

    test('money owed TO you is named, and is kept out of the answers', () {
      final PanAnswer a = askPan(
        'how am i doing',
        facts(
          owedToMe: 4500,
          transactions: spending(days: 7, perDay: 300, income: 32500),
        ),
      );
      expect(a.more, contains('4,500'));
      expect(a.more, contains('owed to you'));
      expect(
        a.points.join(' '),
        isNot(contains('4,500')),
        reason: 'money that is not on this phone is not one of the readings',
      );
    });

    test('the answer reaches from several phrasings, English and Tagalog', () {
      for (final String q in <String>[
        'how am i doing',
        'audit my finances',
        'financial health',
        'rate my budget',
        'kumusta pera ko',
      ]) {
        expect(askPan(q, facts()).topic, 'health', reason: q);
      }
    });

    test('every action Pan offers is a destination the app knows', () {
      // A typo in an id ships as a button that does nothing, which is worse
      // than no button, because somebody taps it twice and decides the app
      // is broken.
      for (final String q in <String>['how am i doing', 'can i afford 2000']) {
        for (final PanAction a in askPan(q, facts()).actions) {
          expect(panActionIds, contains(a.id), reason: '$q offered "${a.id}"');
        }
      }
    });

    test('and it offers the Health Check screen the figures came from', () {
      final PanAnswer a = askPan('how am i doing', facts());
      expect(
        a.actions.map((PanAction x) => x.id),
        contains('healthCheck'),
        reason:
            'sending somebody to Reports for a health answer is what two '
            'engines looked like from the outside',
      );
    });
  });

  group('there is exactly one health check in the app', () {
    // The F9 guard that outlives this file's other tests. Nothing in a unit
    // test can see a SECOND engine being written next door, which is how Pan
    // came to carry its own for a month. This reads the source.

    test('only health_check.dart defines runHealthCheck', () {
      final List<String> definers = <String>[];
      for (final FileSystemEntity f in Directory(
        'lib',
      ).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final String src = f.readAsStringSync();
        if (RegExp(
          r'^HealthReport\s+runHealthCheck|^\w+\s+runHealthCheck\s*\(',
          multiLine: true,
        ).hasMatch(src)) {
          definers.add(f.path);
        }
      }
      expect(definers, <String>['lib/core/money/health_check.dart']);
    });

    test('and Pan reads that one rather than keeping its own', () {
      final String engine = File(
        'lib/core/money/pan/pan_engine.dart',
      ).readAsStringSync();
      expect(engine, contains("import '../health_check.dart';"));
      expect(
        engine,
        isNot(contains("import 'pan_health.dart';")),
        reason: 'the retired second engine must not be imported again',
      );
      expect(
        File('lib/core/money/pan/pan_health.dart').existsSync(),
        isFalse,
        reason: 'a deleted engine that is still on disk gets imported again',
      );
    });
  });
}
