import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';

import '../support/test_clock.dart';
import 'package:salapify/core/money/money.dart';

/// The file format: what it promises, and what it refuses to do.
///
/// Two promises are worth more than all the others here. The first is that
/// everything survives a round trip, because a person's ledger passing
/// through this code and coming back different is the whole catastrophe. The
/// second is that a file this build cannot read correctly is REFUSED rather
/// than guessed at, because the caller's answer to a refusal is to leave the
/// file alone, and a file left alone can still be recovered.
void main() {
  Snapshot seeded() => Snapshot(
    accounts: SeedData.accounts(testToday),
    transactions: SeedData.transactions(testToday),
    debts: SeedData.debts(testToday),
    budgets: SeedData.budgets,
    goals: SeedData.goals,
    upcoming: SeedData.upcoming(testToday),
    incomeStreams: SeedData.incomeStreams,
    installments: SeedData.installments(testToday),
    reconciliations: const <ReconciliationRecord>[],
    bills: SeedData.bills(testToday),
    payday: SeedData.payday,
    theme: ThemeMode2.gabi,
    scenario: DecisionScenario.conservative,
  );

  final DateTime at = DateTime.utc(2026, 9, 19, 10);

  Snapshot roundTrip(Snapshot s) => Snapshot.decode(s.encode(at: at));

  group('the round trip', () {
    test('every collection comes back with the same number of records', () {
      final Snapshot before = seeded();
      final Snapshot after = roundTrip(before);

      expect(after.accounts, hasLength(before.accounts.length));
      expect(after.transactions, hasLength(before.transactions.length));
      expect(after.debts, hasLength(before.debts.length));
      expect(after.budgets, hasLength(before.budgets.length));
      expect(after.goals, hasLength(before.goals.length));
      expect(after.upcoming, hasLength(before.upcoming.length));
      expect(after.incomeStreams, hasLength(before.incomeStreams.length));
      expect(after.installments, hasLength(before.installments.length));
      expect(
        before.accounts,
        isNotEmpty,
        reason:
            'the fixture has to actually hold something, or every assertion '
            'above passes against nothing at all',
      );
    });

    test('not a centavo moves, on any account', () {
      final Snapshot before = seeded();
      final Snapshot after = roundTrip(before);

      for (int i = 0; i < before.accounts.length; i++) {
        expect(
          after.accounts[i].balance,
          before.accounts[i].balance,
          reason: 'account ${before.accounts[i].name} changed value on disk',
        );
        expect(after.accounts[i].id, before.accounts[i].id);
        expect(after.accounts[i].currency, before.accounts[i].currency);
      }
    });

    test('every field of an account survives, not only the ones on screen', () {
      const Account rich = Account(
        id: 'acc_rich',
        name: 'UnionBank Platinum',
        kind: AccountKind.credit,
        institution: 'UnionBank',
        // Positive: a credit balance is money OWED in this app.
        balance: Money.of(18450, 75),
        monogram: 'UB',
        currency: CurrencyCode.usd,
        profile: ProfileEntity.sideHustle,
        creditLimit: Money.pesos(120000),
        interestRate: 3.5,
        accountNumber: '**** 4291',
        dueDate: 'Oct 3',
        statementDate: 'Sep 18',
        cardNetwork: CardNetwork.visa,
        cardTier: CardTier.platinum,
        notes: 'Pay before the 3rd or it compounds.',
      );

      final Snapshot after = roundTrip(
        Snapshot(
          accounts: const <Account>[rich],
          transactions: const <Transaction>[],
          debts: const <Debt>[],
          budgets: const <Budget>[],
          goals: const <Goal>[],
          upcoming: const <UpcomingItem>[],
          incomeStreams: const <IncomeStream>[],
          installments: const <InstallmentPlan>[],
          reconciliations: const <ReconciliationRecord>[],
          bills: const <BillItem>[],
          payday: PaydayCycle.unset,
          theme: ThemeMode2.hapon,
          scenario: DecisionScenario.optimistic,
        ),
      );

      final Account back = after.accounts.single;
      expect(back.name, rich.name);
      expect(back.kind, rich.kind);
      expect(back.institution, rich.institution);
      expect(back.balance, rich.balance);
      expect(back.monogram, rich.monogram);
      expect(back.currency, rich.currency);
      expect(back.profile, rich.profile);
      expect(back.creditLimit, rich.creditLimit);
      expect(back.interestRate, rich.interestRate);
      expect(back.accountNumber, rich.accountNumber);
      expect(back.dueDate, rich.dueDate);
      expect(back.statementDate, rich.statementDate);
      expect(back.cardNetwork, rich.cardNetwork);
      expect(back.cardTier, rich.cardTier);
      expect(back.notes, rich.notes);
      expect(after.theme, ThemeMode2.hapon);
      expect(after.scenario, DecisionScenario.optimistic);
    });

    test('an instalment plan keeps all twenty two of its fields', () {
      const InstallmentPlan plan = InstallmentPlan(
        id: 'plan_1',
        name: 'iPhone 15 via Home Credit',
        provider: 'Home Credit',
        principal: Money.pesos(54990),
        interestRate: 3.5,
        interestRateType: InterestRateType.monthly,
        totalInterest: Money.of(11547, 90),
        totalPayable: Money.of(66537, 90),
        termMonths: 12,
        paymentFrequency: PaymentFrequency.semimonthly,
        startDate: '2026-03-15',
        maturityDate: '2027-03-15',
        installmentAmount: Money.of(5544, 83),
        paidInstallments: 6,
        totalInstallments: 12,
        runningBalance: Money.of(33268, 95),
        principalRemaining: Money.pesos(27495),
        interestRemaining: Money.of(5773, 95),
        extraPayments: <ExtraPayment>[
          ExtraPayment(
            id: 'ex_1',
            date: '2026-07-04',
            amount: Money.pesos(3000),
            note: 'Mid-year bonus',
          ),
        ],
        isSettled: false,
        notes: 'Cannot be pre-terminated without a fee.',
      );

      final InstallmentPlan back = roundTrip(
        Snapshot(
          accounts: const <Account>[],
          transactions: const <Transaction>[],
          debts: const <Debt>[],
          budgets: const <Budget>[],
          goals: const <Goal>[],
          upcoming: const <UpcomingItem>[],
          incomeStreams: const <IncomeStream>[],
          installments: const <InstallmentPlan>[plan],
          reconciliations: const <ReconciliationRecord>[],
          bills: const <BillItem>[],
          payday: PaydayCycle.unset,
          theme: ThemeMode2.gabi,
          scenario: DecisionScenario.conservative,
        ),
      ).installments.single;

      expect(back.provider, plan.provider);
      expect(back.principal, plan.principal);
      expect(back.interestRate, plan.interestRate);
      expect(back.interestRateType, InterestRateType.monthly);
      expect(back.totalInterest, plan.totalInterest);
      expect(back.totalPayable, plan.totalPayable);
      expect(back.termMonths, plan.termMonths);
      expect(back.paymentFrequency, PaymentFrequency.semimonthly);
      expect(back.startDate, plan.startDate);
      expect(back.maturityDate, plan.maturityDate);
      expect(back.installmentAmount, plan.installmentAmount);
      expect(back.paidInstallments, 6);
      expect(back.totalInstallments, 12);
      expect(back.runningBalance, plan.runningBalance);
      expect(back.principalRemaining, plan.principalRemaining);
      expect(back.interestRemaining, plan.interestRemaining);
      expect(back.isSettled, isFalse);
      expect(back.notes, plan.notes);
      expect(back.extraPayments, hasLength(1));
      expect(back.extraPayments.single.amount, const Money.pesos(3000));
      expect(back.extraPayments.single.note, 'Mid-year bonus');
    });
  });

  group('the wire spelling matches the prototype', () {
    // These are not style. archive/prototype-google-ai-studio/src/types.ts spells the multi word values with
    // underscores, and `.name` would have written camelCase. A side hustle
    // read back as personal is money filed in the wrong books, silently.
    test('multi word enum values are snake_case, never camelCase', () {
      expect(profileWire.encode(ProfileEntity.sideHustle), 'side_hustle');
      expect(debtDirectionWire.encode(DebtDirection.iOwe), 'i_owe');
      expect(debtDirectionWire.encode(DebtDirection.owedToMe), 'owed_to_me');
      expect(
        incomeStreamTypeWire.encode(IncomeStreamType.weeklyIncome),
        'weekly_income',
      );
      expect(
        incomeStreamTypeWire.encode(IncomeStreamType.semimonthlySalary),
        'semimonthly_salary',
      );
      expect(
        incomeStreamTypeWire.encode(IncomeStreamType.thirteenthMonth),
        'thirteenth_month',
      );
    });

    test('a debt writes its schedule under scheduleType', () {
      const Debt d = Debt(
        id: 'debt_1',
        person: 'Home Credit',
        direction: DebtDirection.iOwe,
        totalAmount: Money.pesos(20000),
        paidAmount: Money.pesos(5000),
        isSettled: false,
        schedule: DebtSchedule.scheduled,
      );
      final Map<String, dynamic> json = debtToJson(d);
      expect(
        json['scheduleType'],
        'scheduled',
        reason:
            'archive/prototype-google-ai-studio/src/types.ts calls this field scheduleType. Writing it as '
            '"schedule" means the prototype reads nothing and every debt '
            'silently becomes flexible, which removes its due date.',
      );
      expect(json.containsKey('schedule'), isFalse);
    });

    test('every enum maps both ways with nothing lost', () {
      void bothWays<T>(Wire<T> wire, List<T> all) {
        for (final T value in all) {
          expect(
            wire.fromWire[wire.encode(value)],
            value,
            reason: '$value did not survive its own encoding',
          );
        }
        expect(
          wire.toWire.length,
          all.length,
          reason:
              'the map is missing a value, and a value with no wire spelling '
              'throws a null on the first save',
        );
        expect(
          wire.fromWire.length,
          all.length,
          reason: 'two values share a wire spelling, so one overwrites other',
        );
      }

      bothWays(transactionTypeWire, TransactionType.values);
      bothWays(transactionStatusWire, TransactionStatus.values);
      bothWays(profileWire, ProfileEntity.values);
      bothWays(accountKindWire, AccountKind.values);
      bothWays(currencyWire, CurrencyCode.values);
      bothWays(cardNetworkWire, CardNetwork.values);
      bothWays(cardTierWire, CardTier.values);
      bothWays(debtDirectionWire, DebtDirection.values);
      bothWays(debtScheduleWire, DebtSchedule.values);
      bothWays(upcomingTypeWire, UpcomingItemType.values);
      bothWays(incomeStreamTypeWire, IncomeStreamType.values);
      bothWays(interestRateTypeWire, InterestRateType.values);
      bothWays(paymentFrequencyWire, PaymentFrequency.values);
      bothWays(scenarioWire, DecisionScenario.values);
      bothWays(themeWire, ThemeMode2.values);
    });

    test('the document uses the prototype export\'s own top level names', () {
      final Map<String, dynamic> doc =
          jsonDecode(seeded().encode(at: at)) as Map<String, dynamic>;
      // From archive/prototype-google-ai-studio/src/components/SettingsModal.tsx, handleExportData.
      for (final String key in <String>[
        'timestamp',
        'themeMode',
        'transactions',
        'accounts',
        'debts',
        'budgets',
        'goals',
        'upcoming',
      ]) {
        expect(
          doc.containsKey(key),
          isTrue,
          reason: 'the prototype importer looks for "$key"',
        );
      }
    });

    test('it carries what the prototype backup LEAVES OUT', () {
      final Map<String, dynamic> doc =
          jsonDecode(seeded().encode(at: at)) as Map<String, dynamic>;
      // The prototype's own export covers nine of its thirty four stored
      // keys. Somebody who exports, wipes their phone and imports loses
      // their instalment plans and their reconciliation history without ever
      // being told. That defect is deliberately not ported.
      expect(doc.containsKey('installments'), isTrue);
      expect(doc.containsKey('reconciliations'), isTrue);
      expect(doc.containsKey('incomeStreams'), isTrue);
    });
  });

  group('keys this build does not model', () {
    // The prototype's Transaction carries changeHistory, comments, approval,
    // splitId and spaceId, none of which Salapify 3 models. Reading one,
    // dropping them and saving would destroy them on a device with no second
    // copy anywhere.
    String fileWithExtras() => jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'accounts': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'acc_1',
          'name': 'GCash',
          'kind': 'gcash',
          'institution': 'GCash',
          'balance': 8420.50,
          'monogram': 'GC',
          'someFutureField': <String, dynamic>{'nested': true},
        },
      ],
      'transactions': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'tx_1',
          'type': 'expense',
          'amount': 250,
          'category': 'Food & Dining',
          'accountId': 'acc_1',
          'date': '2026-09-18',
          'createdAt': 1758153600000,
          'splitId': 'split_9',
          'comments': <String>['paid by Kuya'],
        },
      ],
      // The prototype stores these and Salapify 3 still reads its seed.
      'payday': <String, dynamic>{'cycleType': 'semimonthly'},
      'categories': <String>['Food & Dining'],
    });

    test('they come back out again, unchanged', () {
      final Snapshot loaded = Snapshot.decode(fileWithExtras());
      final Map<String, dynamic> saved =
          jsonDecode(loaded.encode(at: at)) as Map<String, dynamic>;

      final Map<String, dynamic> account =
          (saved['accounts'] as List<dynamic>).single as Map<String, dynamic>;
      expect(
        account['someFutureField'],
        <String, dynamic>{'nested': true},
        reason:
            'a field a later version wrote must survive being opened by this '
            'one, or updating the app destroys data',
      );

      final Map<String, dynamic> tx =
          (saved['transactions'] as List<dynamic>).single
              as Map<String, dynamic>;
      expect(tx['splitId'], 'split_9');
      expect(tx['comments'], <String>['paid by Kuya']);

      // payday is OURS now, and this assertion changed with it. It used to
      // read back byte for byte as a foreign key, because the app took its
      // cycle from a compile time constant and never stored one. It now
      // models five fields of it, so the object comes back with those five
      // filled in. What must NOT change is the rest: a key inside payday that
      // this build does not model is still somebody else's and is still kept.
      final Map<String, dynamic> savedPayday =
          saved['payday'] as Map<String, dynamic>;
      expect(
        savedPayday['cycleType'],
        'semimonthly',
        reason: 'the stored cycle type was overwritten by a default',
      );
      expect(
        savedPayday.containsKey('daysToPayday'),
        isTrue,
        reason: 'payday is modelled now, so its own fields are written',
      );
      expect(saved['categories'], <String>['Food & Dining']);
    });

    test('our own value wins where we DO model the field', () {
      final Snapshot loaded = Snapshot.decode(fileWithExtras());
      final Map<String, dynamic> saved =
          jsonDecode(loaded.encode(at: at)) as Map<String, dynamic>;
      final Map<String, dynamic> account =
          (saved['accounts'] as List<dynamic>).single as Map<String, dynamic>;
      expect(account['balance'], 8420.50);
      expect(account['name'], 'GCash');
    });

    test('a record deleted since loading takes its kept keys with it', () {
      final Snapshot loaded = Snapshot.decode(fileWithExtras());
      final Snapshot without = Snapshot(
        accounts: loaded.accounts,
        transactions: const <Transaction>[],
        debts: loaded.debts,
        budgets: loaded.budgets,
        goals: loaded.goals,
        upcoming: loaded.upcoming,
        incomeStreams: loaded.incomeStreams,
        installments: loaded.installments,
        reconciliations: loaded.reconciliations,
        bills: loaded.bills,
        payday: loaded.payday,
        theme: loaded.theme,
        scenario: loaded.scenario,
        extras: loaded.extras,
      );
      final Map<String, dynamic> saved =
          jsonDecode(without.encode(at: at)) as Map<String, dynamic>;
      expect(
        saved['transactions'],
        isEmpty,
        reason:
            'kept keys ride along with the record they came from. They must '
            'never resurrect an entry the person removed.',
      );
    });
  });

  group('a file it cannot read is REFUSED, never guessed', () {
    Matcher refuses(String because) => throwsA(
      isA<SnapshotFormatException>().having(
        (SnapshotFormatException e) => e.message,
        because,
        isNotEmpty,
      ),
    );

    test('text that is not JSON', () {
      expect(() => Snapshot.decode('this is not json {'), refuses('message'));
    });

    test('JSON that is not an object', () {
      expect(() => Snapshot.decode('[1, 2, 3]'), refuses('message'));
    });

    test('an amount stored as text', () {
      expect(
        () => Snapshot.decode(
          jsonEncode(<String, dynamic>{
            'transactions': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tx_1',
                'type': 'expense',
                'amount': '250.00',
                'category': 'Food & Dining',
                'accountId': 'acc_1',
                'date': '2026-09-18',
                'createdAt': 1758153600000,
              },
            ],
          }),
        ),
        refuses('message'),
      );
    });

    test('an enum value this build has never heard of', () {
      expect(
        () => Snapshot.decode(
          jsonEncode(<String, dynamic>{
            'accounts': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'acc_1',
                'name': 'Crypto',
                'kind': 'crypto_wallet',
                'institution': 'Coins.ph',
                'balance': 100,
                'monogram': 'CP',
              },
            ],
          }),
        ),
        refuses('message'),
      );
    });

    test('a file written by a NEWER version of Salapify', () {
      expect(
        () => Snapshot.decode(
          jsonEncode(<String, dynamic>{
            'schemaVersion': Snapshot.currentSchemaVersion + 1,
            'accounts': <Map<String, dynamic>>[],
          }),
        ),
        refuses('message'),
        reason:
            'an older build opening a newer file must not read the half it '
            'understands and then save that half back over the whole',
      );
    });

    test('a collection that is not a list', () {
      expect(
        () => Snapshot.decode(
          jsonEncode(<String, dynamic>{'accounts': <String, dynamic>{}}),
        ),
        refuses('message'),
      );
    });

    test('the message says what is wrong in words, not in a stack trace', () {
      try {
        Snapshot.decode(
          jsonEncode(<String, dynamic>{
            'accounts': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'acc_1',
                'name': 'GCash',
                'kind': 'gcash',
                'institution': 'GCash',
                'balance': true,
                'monogram': 'GC',
              },
            ],
          }),
        );
        fail('it accepted a balance of "true"');
      } on SnapshotFormatException catch (e) {
        expect(e.message, contains('balance'));
        expect(e.message, contains('number'));
      }
    });
  });

  // Two fence holes in the version check, closed before a second version
  // exists rather than after. Both were one line reads today and unfindable
  // bugs the day version 2 ships, because neither throws: a file simply gets
  // opened by a reader that is wrong for it and every figure quietly means
  // something else.
  //
  // The old check was a single line, `version is num && version >
  // currentSchemaVersion`, and it let two shapes past: a file with no
  // version key at all, and a version that is not a number.
  group('the version on the file', () {
    test('a version that is NOT A NUMBER is refused, not waved through', () {
      // THE DIRECTIONAL HALF, and it is the whole test. The same document
      // with a numeric 1 loads perfectly, below. If the refusal regressed,
      // this file would load too, with `"2"` read as "no objection".
      const String stringVersion =
          '{"schemaVersion":"2","accounts":[],"transactions":[]}';

      expect(
        () => Snapshot.decode(stringVersion),
        throwsA(isA<SnapshotFormatException>()),
        reason:
            'a file claiming a format this build cannot even compare was '
            'read as if it were the current one',
      );

      // The silent half of the alarm. A genuine file is NOT caught by it.
      expect(
        Snapshot.decode('{"schemaVersion":1,"accounts":[],"transactions":[]}'),
        isA<Snapshot>(),
        reason: 'the new refusal swallowed an ordinary Salapify file',
      );
    });

    test('every shape that is not a whole number is refused', () {
      for (final Object? bad in <Object?>[
        '1', // the shape that actually got past the old check
        '2',
        null, // present and empty is a broken file, not a silent one
        true,
        1.5, // there is no version one and a half to dispatch on
        double.nan,
        double.infinity,
        <String, dynamic>{'major': 1},
        <int>[1],
      ]) {
        expect(
          () => Snapshot.readSchemaVersion(<String, dynamic>{
            'schemaVersion': bad,
          }),
          throwsA(isA<SnapshotFormatException>()),
          reason: 'a schemaVersion of $bad was accepted',
        );
      }
    });

    test('a whole number is read, however JSON spelled it', () {
      // jsonDecode hands back a double for `1.0` in the text, and that is
      // the same version as `1`. Refusing it would reject a file nothing is
      // wrong with.
      expect(
        Snapshot.readSchemaVersion(<String, dynamic>{'schemaVersion': 1}),
        1,
      );
      expect(
        Snapshot.readSchemaVersion(<String, dynamic>{'schemaVersion': 1.0}),
        1,
      );
      expect(
        Snapshot.readSchemaVersion(
          jsonDecode('{"schemaVersion":7.0}') as Map<String, dynamic>,
        ),
        7,
      );
    });

    test('an ABSENT version means the oldest shape, never the current one', () {
      // Why the floor is passed in rather than read from the constant:
      // `legacySchemaVersion` and `currentSchemaVersion` are both 1 today,
      // because only one version has ever existed. So the deliberate break
      // for this rule, returning `currentSchemaVersion` from the absent
      // branch, produces NO failure at all while the two agree, and a test
      // asserting `readSchemaVersion({}) == legacySchemaVersion` would read
      // as proof while proving nothing.
      //
      // Handing it a floor the current version is not is the only shape
      // that actually reaches the branch the guard lives on.
      expect(
        Snapshot.readSchemaVersion(<String, dynamic>{}, whenAbsent: 7),
        7,
        reason:
            'silence about the version was answered with something other '
            'than the floor, which on the day version 2 ships means an '
            'unversioned backup is treated as already current and is never '
            'carried forward',
      );

      // And the production wiring, so the parameter cannot drift away from
      // what the app actually passes.
      expect(
        Snapshot.readSchemaVersion(<String, dynamic>{}),
        Snapshot.legacySchemaVersion,
      );
      expect(
        Snapshot.legacySchemaVersion,
        1,
        reason:
            'the oldest shape that ever existed is a historical fact, so '
            'this number can never be edited, only compared against',
      );
    });

    test('ONE VERSION HAS EVER EXISTED, and this fails the day that ends', () {
      // A deliberate tripwire, not an assertion about correctness.
      //
      // Everything above is exercised against two constants that happen to
      // be equal. The absent rule is therefore guarded in shape but has
      // never been run against a real version 1 file opened by a version 2
      // reader, because no such reader exists. When this expect fails,
      // that is the day: write the fixture pair, prove the file is actually
      // carried forward, and only then change this number.
      expect(
        Snapshot.currentSchemaVersion,
        Snapshot.legacySchemaVersion,
        reason:
            'a second schema version now exists. The absent-means-oldest '
            'rule has real consequences from today, so it needs a captured '
            'version 1 fixture and a migration test, not just this group.',
      );
    });
  });

  // Salapify 3 was rebuilt in Flutter from the Google AI Studio prototype in
  // src/. The React Native app in archive/salapify-1-react-native/ and Salapify 2 in archive/ are a
  // SEPARATE branch of the family that was archived, not this app's parents.
  // Both of those count their file shape to 12 while this one starts at 1,
  // because the two numbers count two different shapes.
  //
  // So a backup from either arrived at Restore, hit the newer-than-me branch,
  // and was refused with "Update the app rather than opening it here". That
  // instruction cannot be followed, because Salapify 3 IS the newer app.
  group('a backup from the OLD Salapify family', () {
    // The archived apps keep what you owe and what you are owed in two
    // separate top level lists. This app keeps both in `debts`.
    String oldFamilyBackup() => jsonEncode(<String, dynamic>{
      'schemaVersion': 12,
      'accounts': <Map<String, dynamic>>[],
      'transactions': <Map<String, dynamic>>[],
      'receivables': <Map<String, dynamic>>[],
      'people': <Map<String, dynamic>>[],
      'categories': <Map<String, dynamic>>[],
    });

    test('it is refused, and NOT sent to update an app that is this one', () {
      try {
        Snapshot.decode(oldFamilyBackup());
        fail('a Salapify 2 backup was read as a Salapify 3 ledger');
      } on SnapshotFormatException catch (e) {
        final String said = e.message.toLowerCase();
        expect(said, contains('older salapify'));
        expect(
          said,
          contains('nothing on this phone has been changed'),
          reason:
              'a refusal on the recovery screen that does not say the phone '
              'is untouched is read as damage',
        );
        expect(
          said,
          isNot(contains('update the app')),
          reason:
              'the advice cannot be followed. There is no newer Salapify to '
              'update to, because this build is it.',
        );
      }
    });

    test('the SHAPE refuses it, not the number on the file', () {
      // A version number is a label and two unrelated counters could collide
      // one day. `receivables` sitting next to `people` could not get here by
      // accident, and it is the actual reason the file cannot be read.
      expect(
        () => Snapshot.decode(
          '{"accounts":[],"transactions":[],"receivables":[],"people":[]}',
        ),
        throwsA(isA<SnapshotFormatException>()),
        reason: 'the same file without its version number was let through',
      );
    });

    test('a genuine Salapify 3 document is NOT caught by it', () {
      // THE TRIPWIRE. If anybody ever adds a `people` collection to this app,
      // this goes red and they read the comment on _oldFamilyKeys before
      // shipping a build that refuses its own files.
      expect(
        Snapshot.looksLikeTheOldSalapify(seeded().toJson(at: at)),
        isFalse,
        reason: 'the old-family refusal swallowed our own file format',
      );
      expect(Snapshot.decode(seeded().encode(at: at)), isA<Snapshot>());
    });

    test('the PROTOTYPE this app came from is not caught by it either', () {
      // archive/prototype-google-ai-studio/src/components/SettingsModal.tsx exports these collection keys, with
      // no schemaVersion and no receivables or people. It is Salapify 3's
      // actual parent, so a check aimed at the archived apps must never
      // touch it.
      //
      // Scope, stated rather than implied: this asserts the GATE lets the
      // prototype's shape through. Whether every prototype RECORD decodes is
      // a separate question and is not claimed here, which is why the
      // collections are empty and themeMode is left off.
      expect(
        Snapshot.decode(
          jsonEncode(<String, dynamic>{
            'timestamp': '2026-10-03T00:00:00.000Z',
            'transactions': <Map<String, dynamic>>[],
            'accounts': <Map<String, dynamic>>[],
            'debts': <Map<String, dynamic>>[],
            'budgets': <Map<String, dynamic>>[],
            'goals': <Map<String, dynamic>>[],
            'upcoming': <Map<String, dynamic>>[],
            'categories': <Map<String, dynamic>>[],
          }),
        ),
        isA<Snapshot>(),
        reason: 'the refusal aimed at the archived apps caught the prototype',
      );
    });

    test('a genuinely newer Salapify 3 file STILL says update the app', () {
      // The silent half of the alarm, and it is a real case rather than a
      // theoretical one: store_test.dart points out that Shorebird can roll
      // a patch back, so an older build opening a newer file happens. There,
      // "update the app" is exactly the right advice, and narrowing the
      // message for the archived apps must not have taken it away.
      try {
        Snapshot.decode(
          jsonEncode(<String, dynamic>{
            'schemaVersion': Snapshot.currentSchemaVersion + 1,
            'accounts': <Map<String, dynamic>>[],
          }),
        );
        fail('a file from the future was read anyway');
      } on SnapshotFormatException catch (e) {
        expect(e.message.toLowerCase(), contains('update the app'));
      }
    });
  });

  group('what an absent optional means', () {
    Map<String, dynamic> minimalTx() => <String, dynamic>{
      'id': 'tx_1',
      'type': 'expense',
      'amount': 250,
      'category': 'Food & Dining',
      'accountId': 'acc_1',
      'date': '2026-09-18',
      'createdAt': 1758153600000,
    };

    test('a transaction with no status is confirmed, as in the prototype', () {
      final Transaction t = transactionFromJson(minimalTx());
      expect(t.status, TransactionStatus.confirmed);
      expect(t.countsTowardTotals, isTrue);
    });

    test('an account with no currency is pesos', () {
      final Account a = accountFromJson(<String, dynamic>{
        'id': 'acc_1',
        'name': 'Cash',
        'kind': 'cash',
        'institution': 'Wallet',
        'balance': 1850,
        'monogram': 'CA',
      });
      expect(a.currency, CurrencyCode.php);
      expect(a.isForeign, isFalse);
    });

    test('a field that IS there but unreadable still throws', () {
      expect(
        () => transactionFromJson(<String, dynamic>{
          ...minimalTx(),
          'status': 'archived',
        }),
        throwsA(isA<SnapshotFormatException>()),
        reason:
            'silence about a missing field is fine. A field holding something '
            'this build cannot read is a contradiction, and defaulting it to '
            'confirmed would put an excluded entry back into the totals.',
      );
    });
  });
}
