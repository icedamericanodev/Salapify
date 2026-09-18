import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/models/models.dart';

/// Golden vectors for the Ledger, produced by RUNNING the prototype's own
/// expressions out of src/components/LedgerScreen.tsx under bun against this
/// exact fixture. Not one figure below was worked out by hand. If a Dart
/// number ever disagrees, the port is wrong and the vector stands.
///
/// The fixture is deliberately awkward. It carries an excluded row, a
/// duplicate row, a pending row, a transfer, a household row, an amount with
/// centavos, a tag and a person, because every one of those changes at least
/// one figure and a tidy fixture proves nothing.
Transaction _tx({
  required String id,
  required TransactionType type,
  required double amount,
  required String category,
  required String accountId,
  required String date,
  String? subcategory,
  String? toAccountId,
  String? merchant,
  String? note,
  String? person,
  List<String> tags = const <String>[],
  TransactionStatus status = TransactionStatus.confirmed,
  ProfileEntity? profile,
}) {
  return Transaction(
    id: id,
    type: type,
    amount: amount,
    category: category,
    accountId: accountId,
    date: date,
    createdAt: 0,
    subcategory: subcategory,
    toAccountId: toAccountId,
    merchant: merchant,
    note: note,
    person: person,
    tags: tags,
    status: status,
    profile: profile,
  );
}

final List<Transaction> _fixture = <Transaction>[
  _tx(
    id: 't1',
    type: TransactionType.income,
    amount: 32500,
    category: 'Salary & Compensation',
    accountId: 'bpi',
    date: '2026-09-15',
    merchant: 'Acme Corp',
    profile: ProfileEntity.personal,
  ),
  _tx(
    id: 't2',
    type: TransactionType.expense,
    amount: 1250.5,
    category: 'Groceries',
    subcategory: 'Supermarket',
    accountId: 'gcash',
    date: '2026-09-15',
    merchant: 'SM Hypermarket',
    tags: <String>['weekly'],
  ),
  _tx(
    id: 't3',
    type: TransactionType.expense,
    amount: 465,
    category: 'Food & Dining',
    accountId: 'cash',
    date: '2026-09-14',
    merchant: 'Jollibee',
  ),
  _tx(
    id: 't4',
    type: TransactionType.transfer,
    amount: 5000,
    category: 'Transfer',
    accountId: 'bpi',
    toAccountId: 'gcash',
    date: '2026-09-14',
  ),
  _tx(
    id: 't5',
    type: TransactionType.expense,
    amount: 2840,
    category: 'Bills & Utilities',
    accountId: 'bpi',
    date: '2026-09-13',
    merchant: 'Meralco',
    status: TransactionStatus.pending,
  ),
  _tx(
    id: 't6',
    type: TransactionType.expense,
    amount: 9999,
    category: 'Shopping & Personal',
    accountId: 'gcash',
    date: '2026-09-13',
    note: 'double charge',
    status: TransactionStatus.excluded,
  ),
  _tx(
    id: 't7',
    type: TransactionType.expense,
    amount: 420,
    category: 'Transport & Commute',
    accountId: 'cash',
    date: '2026-09-12',
    person: 'Kuya Mark',
  ),
  _tx(
    id: 't8',
    type: TransactionType.income,
    amount: 8000,
    category: 'Business Revenue',
    accountId: 'bpi',
    date: '2026-09-12',
    status: TransactionStatus.duplicate,
  ),
  _tx(
    id: 't9',
    type: TransactionType.expense,
    amount: 2000,
    category: 'Family Support',
    accountId: 'bpi',
    date: '2026-09-12',
    profile: ProfileEntity.household,
  ),
];

List<String> _ids(List<Transaction> list) =>
    list.map((Transaction t) => t.id).toList();

void main() {
  _writeTests();
  group('scoping', () {
    test('no filters keeps every row, in stored order', () {
      final List<Transaction> s = scopeTransactions(
        _fixture,
        const LedgerQuery(),
      );
      expect(_ids(s), <String>[
        't1',
        't2',
        't3',
        't4',
        't5',
        't6',
        't7',
        't8',
        't9',
      ]);
    });

    test('an account filter matches BOTH sides of a transfer', () {
      // t4 moves money bpi -> gcash and must appear under each, which is the
      // whole reason the filter reads toAccountId as well.
      expect(
        _ids(scopeTransactions(_fixture, const LedgerQuery(accountId: 'bpi'))),
        <String>['t1', 't4', 't5', 't8', 't9'],
      );
      expect(
        _ids(
          scopeTransactions(_fixture, const LedgerQuery(accountId: 'gcash')),
        ),
        <String>['t2', 't4', 't6'],
      );
    });

    test('a status filter compares against confirmed by default', () {
      // Six rows carry no explicit status and are therefore confirmed, so the
      // pending, excluded and duplicate rows drop out.
      expect(
        _ids(
          scopeTransactions(
            _fixture,
            const LedgerQuery(status: TransactionStatus.confirmed),
          ),
        ),
        <String>['t1', 't2', 't3', 't4', 't7', 't9'],
      );
    });

    test('a profile filter keeps only that profile', () {
      expect(
        _ids(
          scopeTransactions(
            _fixture,
            const LedgerQuery(profile: ProfileEntity.household),
          ),
        ),
        <String>['t9'],
      );
    });
  });

  group('search', () {
    void findsOnly(String query, List<String> expected) {
      test('"$query" finds ${expected.join(", ")}', () {
        expect(
          _ids(scopeTransactions(_fixture, LedgerQuery(search: query))),
          expected,
        );
      });
    }

    findsOnly('jollibee', <String>['t3']);
    findsOnly('kuya', <String>['t7']);
    findsOnly('weekly', <String>['t2']);
    findsOnly('zzz', <String>[]);

    // The money half. All four of these name the same two rows in different
    // ways a person actually types them.
    findsOnly('2840', <String>['t5']);
    findsOnly('1,250.50', <String>['t2']);
    findsOnly('php1250.5', <String>['t2']);
    findsOnly('₱465', <String>['t3']);
  });

  group('totals', () {
    test('unfiltered', () {
      final LedgerTotals t = computeTotals(
        scopeTransactions(_fixture, const LedgerQuery()),
      );
      // 9,999 excluded and 8,000 duplicate are both left out, and the 5,000
      // transfer is in neither total.
      expect(t.totalIn, 32500);
      expect(t.totalOut, 6975.5);
      expect(t.netMovement, 25524.5);
      expect(t.inflowCount, 1);
      expect(t.outflowCount, 5);
      expect(t.transferCount, 1);
      expect(t.outflowPercentage, 21);
      expect(t.retentionPercentage, 79);
    });

    test('scoped to one account', () {
      final LedgerTotals t = computeTotals(
        scopeTransactions(_fixture, const LedgerQuery(accountId: 'bpi')),
      );
      expect(t.totalIn, 32500);
      expect(t.totalOut, 4840);
      expect(t.netMovement, 27660);
      expect(t.outflowPercentage, 15);
      expect(t.retentionPercentage, 85);
    });

    test('nothing came in, so outflow reads 100 and retention reads 0', () {
      // The branch that has no division in it. gcash has one expense, one
      // excluded row and the receiving side of the transfer.
      final LedgerTotals t = computeTotals(
        scopeTransactions(_fixture, const LedgerQuery(accountId: 'gcash')),
      );
      expect(t.totalIn, 0);
      expect(t.totalOut, 1250.5);
      expect(t.netMovement, -1250.5);
      expect(t.outflowPercentage, 100);
      expect(
        t.retentionPercentage,
        0,
        reason: 'retention must never go negative',
      );
    });

    test('an empty selection is all zeroes, not a division by zero', () {
      final LedgerTotals t = computeTotals(
        scopeTransactions(_fixture, const LedgerQuery(search: 'zzz')),
      );
      expect(t.totalIn, 0);
      expect(t.totalOut, 0);
      expect(t.outflowPercentage, 0);
      expect(t.retentionPercentage, 0);
    });

    test('confirmed only', () {
      final LedgerTotals t = computeTotals(
        scopeTransactions(
          _fixture,
          const LedgerQuery(status: TransactionStatus.confirmed),
        ),
      );
      expect(t.totalOut, 4135.5);
      expect(t.netMovement, 28364.5);
      expect(t.outflowPercentage, 13);
      expect(t.retentionPercentage, 87);
    });

    test('a transfer moves no money into either total', () {
      // The invariant stated directly: drop the transfer and nothing changes
      // except its own count.
      final List<Transaction> withoutTransfer = _fixture
          .where((Transaction t) => t.type != TransactionType.transfer)
          .toList();
      final LedgerTotals a = computeTotals(
        scopeTransactions(_fixture, const LedgerQuery()),
      );
      final LedgerTotals b = computeTotals(
        scopeTransactions(withoutTransfer, const LedgerQuery()),
      );
      expect(b.totalIn, a.totalIn);
      expect(b.totalOut, a.totalOut);
      expect(b.transferCount, 0);
      expect(
        a.transferCount,
        1,
        reason: 'the fixture must contain a transfer or this proves nothing',
      );
    });
  });

  group('type filter', () {
    test('narrows the list without touching the summary', () {
      final List<Transaction> scoped = scopeTransactions(
        _fixture,
        const LedgerQuery(),
      );
      final LedgerTotals summary = computeTotals(scoped);

      expect(_ids(filterByType(scoped, LedgerTypeFilter.income)), <String>[
        't1',
        't8',
      ]);
      expect(_ids(filterByType(scoped, LedgerTypeFilter.transfer)), <String>[
        't4',
      ]);

      // The card still describes the whole selection. This is the behaviour
      // that would break if scoping and the type tab were merged.
      expect(computeTotals(scoped).totalOut, summary.totalOut);
    });
  });

  group('grouping', () {
    test('days come back newest first, order kept inside a day', () {
      final List<LedgerDay> days = groupByDay(_fixture);
      expect(days.map((LedgerDay d) => d.date).toList(), <String>[
        '2026-09-15',
        '2026-09-14',
        '2026-09-13',
        '2026-09-12',
      ]);
      expect(_ids(days[0].transactions), <String>['t1', 't2']);
      expect(_ids(days[1].transactions), <String>['t3', 't4']);
      expect(_ids(days[2].transactions), <String>['t5', 't6']);
      expect(_ids(days[3].transactions), <String>['t7', 't8', 't9']);
    });

    test('every transaction survives grouping', () {
      final int total = groupByDay(
        _fixture,
      ).fold<int>(0, (int sum, LedgerDay d) => sum + d.transactions.length);
      expect(total, _fixture.length);
    });
  });

  test('category spending is biggest first and skips what does not count', () {
    final List<({String category, double amount})> rows = categorySpending(
      _fixture,
    );
    expect(
      rows.map((({String category, double amount}) r) => r.category).toList(),
      <String>[
        'Bills & Utilities',
        'Family Support',
        'Groceries',
        'Food & Dining',
        'Transport & Commute',
      ],
    );
    expect(rows.first.amount, 2840);
    expect(rows.last.amount, 420);
    expect(
      rows.any(
        (({String category, double amount}) r) =>
            r.category == 'Shopping & Personal',
      ),
      isFalse,
      reason: 'the excluded 9,999 row must not appear as a spending category',
    );
  });
}

/// The WRITE side: what logging an entry does to account balances. Every
/// figure below came from running addTransaction's own balance block out of
/// src/context/FinancialContext.tsx under bun.
void _writeTests() {
  List<Account> base() => <Account>[
    const Account(
      id: 'bpi',
      name: 'BPI',
      kind: AccountKind.bank,
      institution: 'BPI',
      balance: 48500,
      monogram: 'B',
    ),
    const Account(
      id: 'gcash',
      name: 'GCash',
      kind: AccountKind.gcash,
      institution: 'GCash',
      balance: 8420.5,
      monogram: 'G',
    ),
    const Account(
      id: 'cash',
      name: 'Cash',
      kind: AccountKind.cash,
      institution: 'Cash',
      balance: 1850,
      monogram: 'C',
    ),
  ];

  double balanceOf(List<Account> accounts, String id) =>
      accounts.firstWhere((Account a) => a.id == id).balance;

  double sumOf(List<Account> accounts) =>
      accounts.fold<double>(0, (double s, Account a) => s + a.balance);

  Transaction logged({
    required TransactionType type,
    required double amount,
    required String accountId,
    String? toAccountId,
    TransactionStatus status = TransactionStatus.confirmed,
  }) => Transaction(
    id: 'new',
    type: type,
    amount: amount,
    category: 'Test',
    accountId: accountId,
    toAccountId: toAccountId,
    date: '2026-09-18',
    createdAt: 0,
    status: status,
  );

  group('applying a logged entry to balances', () {
    test('an expense lowers the source account by exactly the amount', () {
      final List<Account> r = applyToBalances(
        base(),
        logged(type: TransactionType.expense, amount: 285, accountId: 'gcash'),
      );
      expect(balanceOf(r, 'gcash'), 8135.5);
      expect(
        balanceOf(r, 'bpi'),
        48500,
        reason: 'other accounts must not move',
      );
      expect(sumOf(r), 58485.5);
    });

    test('income raises the source account', () {
      final List<Account> r = applyToBalances(
        base(),
        logged(type: TransactionType.income, amount: 32500, accountId: 'bpi'),
      );
      expect(balanceOf(r, 'bpi'), 81000);
      expect(sumOf(r), 91270.5);
    });

    test('a transfer moves money and changes net worth by nothing', () {
      final List<Account> r = applyToBalances(
        base(),
        logged(
          type: TransactionType.transfer,
          amount: 5000,
          accountId: 'bpi',
          toAccountId: 'gcash',
        ),
      );
      // The invariant.
      expect(sumOf(r), sumOf(base()));
      // And the directional companion, without which a transfer that
      // transferred nothing would satisfy the line above perfectly.
      expect(balanceOf(r, 'bpi'), 43500);
      expect(balanceOf(r, 'gcash'), 13420.5);
    });

    test('an excluded entry moves no money at all', () {
      final List<Account> r = applyToBalances(
        base(),
        logged(
          type: TransactionType.expense,
          amount: 9999,
          accountId: 'gcash',
          status: TransactionStatus.excluded,
        ),
      );
      expect(sumOf(r), sumOf(base()));
      expect(balanceOf(r, 'gcash'), 8420.5);
    });

    test('a duplicate entry moves no money at all', () {
      final List<Account> r = applyToBalances(
        base(),
        logged(
          type: TransactionType.income,
          amount: 8000,
          accountId: 'bpi',
          status: TransactionStatus.duplicate,
        ),
      );
      expect(balanceOf(r, 'bpi'), 48500);
    });

    test('a PENDING entry does move the money, and may go negative', () {
      // Pending means not yet settled, not "did not happen". The prototype
      // debits it, and it is allowed to push an account below zero, which is
      // how an overdrawn wallet shows up rather than being hidden.
      final List<Account> r = applyToBalances(
        base(),
        logged(
          type: TransactionType.expense,
          amount: 1899,
          accountId: 'cash',
          status: TransactionStatus.pending,
        ),
      );
      expect(balanceOf(r, 'cash'), -49);
    });

    test('centavos survive', () {
      final List<Account> r = applyToBalances(
        base(),
        logged(
          type: TransactionType.expense,
          amount: 1250.5,
          accountId: 'gcash',
        ),
      );
      expect(balanceOf(r, 'gcash'), 7170);
    });

    test('a transfer to an unknown account LOSES money, quirk preserved', () {
      // Documented in applyToBalances and locked here so it cannot change by
      // accident in either direction. The source is debited, nobody is
      // credited, and net worth falls. The UI must make this unreachable; the
      // engine reproduces the prototype.
      final List<Account> r = applyToBalances(
        base(),
        logged(
          type: TransactionType.transfer,
          amount: 100,
          accountId: 'bpi',
          toAccountId: 'nope',
        ),
      );
      expect(balanceOf(r, 'bpi'), 48400);
      expect(sumOf(r), 58670.5);
      expect(
        sumOf(r),
        lessThan(sumOf(base())),
        reason: 'this is the quirk: money genuinely disappears',
      );
    });
  });

  group('the Log sheet parsers', () {
    test('tags split on commas and gain a hash', () {
      expect(parseTags('weekly, groceries'), <String>['#weekly', '#groceries']);
      expect(parseTags('#already, plain'), <String>['#already', '#plain']);
      expect(parseTags('  '), isEmpty);
      expect(parseTags('a,,b'), <String>['#a', '#b']);
    });

    test('an amount must be a positive number, commas allowed', () {
      expect(parseLoggedAmount('1,250.50'), 1250.5);
      expect(parseLoggedAmount('285'), 285);
      expect(parseLoggedAmount(''), isNull);
      expect(parseLoggedAmount('0'), isNull);
      expect(parseLoggedAmount('-5'), isNull);
      expect(parseLoggedAmount('abc'), isNull);
    });
  });
}
