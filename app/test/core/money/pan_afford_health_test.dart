import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/pan/pan_affordability.dart';
import 'package:salapify/core/money/pan/pan_context.dart';
import 'package:salapify/core/money/pan/pan_engine.dart';
import 'package:salapify/core/money/pan/pan_health.dart';
import 'package:salapify/models/models.dart';

/// "Can I afford this" and "how am I doing", the two questions the prototype
/// answers best and the two that were missing here.
///
/// Both are scored answers, which is what makes them worth testing hard: a
/// wrong figure in a scored answer does not look wrong. It looks like a
/// measurement.
void main() {
  PanFacts facts({
    List<Account>? accounts,
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
            balance: 23400,
            monogram: 'ES',
          ),
        ],
    transactions: const <Transaction>[],
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
              balance: 900,
              monogram: 'C',
            ),
          ],
        ),
      );
      expect(a.topic, 'afford');
    });
  });

  group('how am I doing', () {
    test('it never scores a card against a limit nobody entered', () {
      // The prototype reads creditLimit || 40000, so a card with no limit is
      // measured against a figure Salapify invented, and the rating built on
      // it looks exactly like a measurement.
      final HealthCheck h = runHealthCheck(
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
      expect(
        h.parts.map((HealthPart p) => p.name),
        isNot(contains('Card use')),
      );
      expect(
        h.unmeasured.map((({String name, String missing}) u) => u.name),
        contains('Card use'),
      );
    });

    test('a card WITH a limit is measured, and owing reads as used', () {
      // A card balance is stored negative when money is owed on it. Reading
      // the sign straight through reports a maxed card as zero used, which
      // is the most flattering possible wrong answer.
      final HealthCheck h = runHealthCheck(
        facts(
          accounts: <Account>[
            const Account(
              id: 'c1',
              name: 'Gold Card',
              kind: AccountKind.credit,
              institution: 'Bank',
              balance: -18000,
              monogram: 'GC',
              creditLimit: 40000,
            ),
          ],
        ),
      );
      final HealthPart card = h.parts.firstWhere(
        (HealthPart p) => p.name == 'Card use',
      );
      expect(card.reading, contains('45%'));
      expect(card.points, 12);
    });

    test('the score is over what was measured, and says what was not', () {
      final HealthCheck h = runHealthCheck(
        facts(payday: PaydayCycle.unset, accounts: const <Account>[]),
      );
      // No accounts, no cards, no payday. Only the owe-against-hold part can
      // be measured, and the score has to be honest about that.
      expect(h.parts.length, 1);
      expect(h.unmeasured.length, 3);
      expect(h.possible, 20);
    });

    test('nothing recorded says so instead of scoring zero', () {
      final HealthCheck h = runHealthCheck(
        facts(
          accounts: const <Account>[],
          payday: PaydayCycle.unset,
          assets: 0,
          liabilities: 0,
        ),
      );
      expect(h.measurable, isFalse);
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
        reason:
            'a zero out of one hundred on an empty app is a made-up verdict',
      );
    });

    test('a high total never claims every part is comfortable', () {
      // Found by looking at the rendered screen, not by a test. A real ledger
      // scored 85, and the badge read "Comfortable on every part measured"
      // directly above "You owe more than you hold" and a row reading 5 of
      // 20. Both halves were correct. Together they were a lie, because an
      // average is not a statement about every part.
      final HealthCheck h = runHealthCheck(
        facts(assets: 20000, liabilities: 44000, runway: 3.9),
      );

      expect(h.score, greaterThanOrEqualTo(80));
      expect(h.weakest!.name, 'What you owe');
      expect(
        h.reading,
        isNot(contains('every part')),
        reason:
            'the summary claimed every part was comfortable while one of '
            'them scored a quarter of its maximum',
      );
      expect(h.reading, 'Stretched on what you owe');
    });

    test('and a genuinely even picture still reads as comfortable', () {
      // The other half of the alarm. A rule that always names a weakest part
      // would cry wolf on every answer, and then it is not there for the one
      // that matters.
      final HealthCheck h = runHealthCheck(
        facts(assets: 100000, liabilities: 5000, runway: 3.9),
      );
      expect(h.reading, 'Comfortable on every part measured');
    });

    test('money owed TO you is named and kept out of the score', () {
      final HealthCheck h = runHealthCheck(facts(owedToMe: 4500));
      expect(h.observations.join(' '), contains('4,500'));
      expect(h.observations.join(' '), contains('owed to you'));
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
  });

  group('Cover is not scored against a burn rate nobody logged', () {
    // The file's own heading says "It never invents a number to score
    // against", and for one component that was false. Cover does not compute
    // its own runway; it reads cashRunwayMonths from the Safe to Spend
    // engine, which stands 28,000 a month in when under 5,000 has been
    // logged in thirty days. The old guard only checked for no accounts, so
    // somebody with one account and an empty ledger got a scored Cover part
    // worth 30 of 100, the largest single weight here, computed from a
    // figure they never entered.

    test(
      'an unmeasured burn puts Cover in the missing list, not the score',
      () {
        final HealthCheck h = runHealthCheck(facts(runwayMeasured: false));
        expect(
          h.parts.map((HealthPart p) => p.name),
          isNot(contains('Cover')),
          reason: 'Cover was scored against the 28,000 stand-in',
        );
        expect(
          h.unmeasured.map((({String name, String missing}) m) => m.name),
          contains('Cover'),
        );
      },
    );

    test('and a measured one is still scored, exactly as before', () {
      // The other half. A guard that dropped Cover always would pass the
      // test above and would delete a working component for everybody.
      final HealthCheck h = runHealthCheck(facts());
      expect(h.parts.map((HealthPart p) => p.name), contains('Cover'));
      expect(
        h.unmeasured.map((({String name, String missing}) m) => m.name),
        isNot(contains('Cover')),
      );
    });

    test('the missing note names the input, and it is the user\'s to give', () {
      final HealthCheck h = runHealthCheck(facts(runwayMeasured: false));
      final String missing = h.unmeasured
          .firstWhere((({String name, String missing}) m) => m.name == 'Cover')
          .missing;
      expect(missing, contains('logged spending'));
    });

    test('no accounts still wins, because it is the earlier question', () {
      // Somebody with nothing recorded should be told they have no accounts,
      // not lectured about logging spending they have nowhere to log against.
      final HealthCheck h = runHealthCheck(
        facts(accounts: const <Account>[], runwayMeasured: false),
      );
      final String missing = h.unmeasured
          .firstWhere((({String name, String missing}) m) => m.name == 'Cover')
          .missing;
      expect(missing, contains('no accounts'));
    });
  });
}
