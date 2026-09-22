import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/accounts.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';

Account _a({
  required String id,
  required AccountKind kind,
  required double balance,
  String institution = 'BPI',
  String name = 'Test',
  CurrencyCode currency = CurrencyCode.php,
  ProfileEntity? profile,
  double? creditLimit,
}) => Account(
  id: id,
  name: name,
  kind: kind,
  institution: institution,
  balance: balance,
  monogram: 'TT',
  currency: currency,
  profile: profile,
  creditLimit: creditLimit,
);

void main() {
  group('grouping follows the prototype', () {
    test('assets fall into the five groups, in order, empties dropped', () {
      final List<AccountGroup> groups = groupAssets(<Account>[
        _a(id: '1', kind: AccountKind.receivable, balance: 500),
        _a(id: '2', kind: AccountKind.gcash, balance: 100),
        _a(id: '3', kind: AccountKind.debit, balance: 200),
        _a(id: '4', kind: AccountKind.cash, balance: 300),
        _a(id: '5', kind: AccountKind.maya, balance: 50),
        _a(id: '6', kind: AccountKind.bank, balance: 400),
      ]);

      expect(
        groups.map((AccountGroup g) => g.id).toList(),
        <String>['ewallet', 'bank', 'cash', 'receivable'],
        reason:
            'Investments is empty here and must not appear. A heading '
            'that only ever says nothing teaches people to ignore headings.',
      );
      expect(groups.first.accounts.length, 2, reason: 'gcash and maya');
      expect(groups[1].accounts.length, 2, reason: 'bank and debit');
    });

    test('liabilities fall into their three groups', () {
      final List<AccountGroup> groups = groupLiabilities(<Account>[
        _a(id: '1', kind: AccountKind.mortgage, balance: 1000),
        _a(id: '2', kind: AccountKind.credit, balance: 200),
      ]);
      expect(groups.map((AccountGroup g) => g.id).toList(), <String>[
        'credit',
        'mortgage',
      ]);
    });

    test('an asset never lands in a liability group, or the reverse', () {
      final List<Account> all = SeedData.accounts;
      final Set<String> assetIds = groupAssets(
        all,
      ).expand((AccountGroup g) => g.accounts).map((Account a) => a.id).toSet();
      final Set<String> liabilityIds = groupLiabilities(
        all,
      ).expand((AccountGroup g) => g.accounts).map((Account a) => a.id).toSet();

      expect(assetIds.intersection(liabilityIds), isEmpty);
      expect(
        assetIds.length + liabilityIds.length,
        all.length,
        reason:
            'Every seeded account must land in exactly one group. An '
            'account in neither is money that silently vanishes from the '
            'screen while still counting towards net worth.',
      );
    });
  });

  group('sums convert before they add', () {
    test('a dollar account is not counted as pesos', () {
      final List<Account> mixed = <Account>[
        _a(id: 'p', kind: AccountKind.bank, balance: 1000),
        _a(
          id: 'd',
          kind: AccountKind.bank,
          balance: 100,
          currency: CurrencyCode.usd,
        ),
      ];

      expect(
        accountsTotalPhp(mixed),
        closeTo(1000 + 5850, 0.001),
        reason:
            'USD 100 is 5,850 pesos at the fixed rate, not 100. Adding '
            'the raw balances gives 1,100, which is wrong by a factor that '
            'no peso-only fixture can reveal.',
      );
      expect(
        accountsTotalPhp(mixed),
        isNot(closeTo(1100, 0.001)),
        reason: 'the directional check: this is what the bug looks like',
      );
    });

    test('summarize agrees with Reports on the seed, to the centavo', () {
      final AccountsSummary s = summarize(SeedData.accounts);
      final FinancialPosition p = computePosition(SeedData.accounts, null);

      expect(s.totalAssets, closeTo(p.totalAssets, 0.001));
      expect(s.totalLiabilities, closeTo(p.totalLiabilities, 0.001));
      expect(
        s.netWorth,
        closeTo(p.netWorth, 0.001),
        reason:
            'Accounts and Reports read the same accounts and must never '
            'print two different net worths. Two screens disagreeing about '
            'one number is the failure this assertion exists to prevent.',
      );
      expect(
        s.netWorth,
        isNot(0),
        reason:
            'the did-anything-happen check: an empty list would satisfy '
            'the equality above perfectly',
      );
    });
  });

  group('filtering', () {
    final List<Account> accounts = <Account>[
      _a(
        id: 'p',
        kind: AccountKind.bank,
        balance: 100,
        profile: ProfileEntity.personal,
      ),
      _a(
        id: 'b',
        kind: AccountKind.bank,
        balance: 200,
        profile: ProfileEntity.business,
      ),
      _a(id: 'u', kind: AccountKind.bank, balance: 300),
      _a(
        id: 'c',
        kind: AccountKind.credit,
        balance: 50,
        profile: ProfileEntity.personal,
      ),
    ];

    test('an unclassified account appears under every entity', () {
      for (final ProfileEntity e in ProfileEntity.values) {
        expect(
          filterAccounts(accounts, profile: e).map((Account a) => a.id),
          contains('u'),
          reason:
              'An account nobody classified belongs everywhere, which is '
              'the same rule Reports uses. Hiding it would make a wallet '
              'disappear the moment somebody taps an entity chip.',
        );
      }
    });

    test('the entity filter actually excludes', () {
      expect(
        filterAccounts(
          accounts,
          profile: ProfileEntity.business,
        ).map((Account a) => a.id),
        isNot(contains('p')),
      );
    });

    test('the assets and liabilities views split the list', () {
      expect(
        filterAccounts(accounts, view: AccountView.assets).length,
        3,
        reason: 'three banks',
      );
      expect(
        filterAccounts(accounts, view: AccountView.liabilities).length,
        1,
        reason: 'one card',
      );
      expect(filterAccounts(accounts).length, 4);
    });
  });

  group('credit utilisation', () {
    test('a card with a limit reports a whole percent', () {
      expect(
        creditUtilization(
          _a(
            id: 'c',
            kind: AccountKind.credit,
            balance: 12000,
            creditLimit: 40000,
          ),
        ),
        30,
      );
    });

    test('30 exactly is NOT high, 31 is', () {
      expect(
        isHighUtilization(
          _a(
            id: 'c',
            kind: AccountKind.credit,
            balance: 12000,
            creditLimit: 40000,
          ),
        ),
        isFalse,
      );
      expect(
        isHighUtilization(
          _a(
            id: 'c',
            kind: AccountKind.credit,
            balance: 12400,
            creditLimit: 40000,
          ),
        ),
        isTrue,
      );
    });

    test('a card with NO limit reports null, never an invented percentage', () {
      expect(
        creditUtilization(
          _a(id: 'c', kind: AccountKind.credit, balance: 12000),
        ),
        isNull,
        reason:
            'The prototype falls back to a 40,000 limit here, which '
            'produces a made up percentage that this screen then colours red '
            'or green and a person reads as advice. Null means we do not '
            'know, and the screen says so.',
      );
      expect(
        creditUtilization(
          _a(id: 'c', kind: AccountKind.credit, balance: 1, creditLimit: 0),
        ),
        isNull,
        reason: 'a zero limit would divide by zero and print Infinity',
      );
    });

    test('anything that is not a credit card has no utilisation', () {
      expect(
        creditUtilization(
          _a(
            id: 'l',
            kind: AccountKind.loan,
            balance: 100000,
            creditLimit: 200000,
          ),
        ),
        isNull,
      );
    });
  });

  group('monogram', () {
    test('kind wins over institution', () {
      expect(
        computeMonogram('Pag-IBIG', AccountKind.investment, 'MP2'),
        'INV',
        reason:
            'An MP2 account reads INV, not HDMF. The prototype checks '
            'kind first and so does this.',
      );
      expect(computeMonogram('BPI', AccountKind.gcash, 'x'), 'GC');
    });

    test('a known institution gets its short code', () {
      expect(computeMonogram('Metrobank', AccountKind.bank, 'Payroll'), 'MBTC');
      expect(computeMonogram('UNO Digital Bank', AccountKind.bank, 'x'), 'UNO');
    });

    test('an unknown institution falls back to the first two letters', () {
      expect(computeMonogram('Some New Bank', AccountKind.bank, 'ipon'), 'IP');
    });

    test('an empty name never produces an empty tile', () {
      expect(computeMonogram('Some New Bank', AccountKind.bank, '   '), 'AC');
    });

    // A stored monogram is an OVERRIDE, not a derived value: the Pag-IBIG
    // account is deliberately labelled MP2 rather than the generic INV that
    // computeMonogram would give it, and that is an improvement, not a
    // defect. So this cannot simply demand that the two agree.
    //
    // What it CAN demand is that a stored label never wears a different
    // bank's badge. That rule allows MP2 and INV, which belong to nobody,
    // and catches exactly the failure that was in here: the MariBank account
    // was labelled SB, Security Bank's code, left over from when the bank
    // was called SeaBank. A person reading that tile is told the wrong bank.
    test('no stored monogram is another institution short code', () {
      final Map<String, String> codeOwner = <String, String>{
        for (final MapEntry<String, String> e in institutionMonograms.entries)
          e.value: e.key,
      };

      for (final Account a in SeedData.accounts) {
        final String? owner = codeOwner[a.monogram];
        if (owner == null) continue; // a bespoke label such as MP2
        expect(
          owner,
          a.institution,
          reason:
              'The account "${a.name}" at ${a.institution} is labelled '
              '"${a.monogram}", which is the code for $owner. Whoever reads '
              'that '
              'tile is told the wrong bank.',
        );
      }
    });

    test('every stored monogram is short enough to draw and not blank', () {
      for (final Account a in SeedData.accounts) {
        expect(a.monogram.trim(), isNotEmpty, reason: '${a.name} has none');
        expect(
          a.monogram.length,
          lessThanOrEqualTo(4),
          reason: '"${a.monogram}" on ${a.name} will not fit the tile',
        );
      }
    });
  });
}
