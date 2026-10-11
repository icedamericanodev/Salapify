import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/debt.dart';
import 'package:salapify/core/money/ledger.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reconciliation.dart';
import 'package:salapify/core/money/usual_entries.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Editing an entry (Batch 2, 2026-10-11).
///
/// An edit marks the old row Taken back and adds the corrected one beside it,
/// in one save, so the history keeps both. Every invariant below has a
/// directional companion naming what actually moved, because "the totals
/// agree" also holds when the edit silently did nothing.
void main() {
  final DateTime today = DateTime(2026, 9, 18, 12);

  Future<FinancialState> fresh() async {
    final FinancialState s = FinancialState(
      clock: today,
      store: MemorySnapshotStore(),
    );
    await s.restore();
    s.startWithExampleData();
    return s;
  }

  Money cash(FinancialState s, String id) =>
      s.accounts.firstWhere((Account a) => a.id == id).balance;

  Transaction row(FinancialState s, String id) =>
      s.transactions.firstWhere((Transaction t) => t.id == id);

  double spending(FinancialState s) => computeTotals(s.transactions).totalOut;

  // The person's own entry, never an example one: examples are refused.
  const Transaction lunch = Transaction(
    id: 'tx_100',
    type: TransactionType.expense,
    amount: Money.pesos(250),
    category: 'Food & Dining',
    subcategory: 'Lunch',
    accountId: 'acc_cash',
    date: '2026-09-17',
    createdAt: 1000,
    merchant: 'Mang Inasal',
    isTaxDeductible: true,
    taxTinOrRef: 'OR-77',
    attachmentPath: '/receipts/a.jpg',
    attachmentName: 'a.jpg',
    profile: ProfileEntity.personal,
  );

  Transaction edit(
    Transaction t, {
    Money? amount,
    String? accountId,
    TransactionType? type,
    String? category,
    String? note,
  }) => Transaction(
    id: t.id,
    type: type ?? t.type,
    amount: amount ?? t.amount,
    category: category ?? t.category,
    accountId: accountId ?? t.accountId,
    toAccountId: t.toAccountId,
    date: t.date,
    createdAt: t.createdAt,
    merchant: t.merchant,
    note: note ?? t.note,
  );

  test('a new amount moves the account by the difference, and keeps the '
      'old row as Taken back', () async {
    final FinancialState s = await fresh();
    s.logTransaction(lunch);
    final Money before = cash(s, 'acc_cash');
    final double spentBefore = spending(s);

    final EditReceipt? r = s.editTransaction(
      'tx_100',
      edit(lunch, amount: const Money.pesos(320)),
    );

    expect(r, isNotNull);
    // Directional: 70 more left the account, and 70 more is spending.
    expect(cash(s, 'acc_cash'), before - const Money.pesos(70));
    expect(spending(s) - spentBefore, closeTo(70, 0.001));
    // The history keeps both.
    expect(row(s, 'tx_100').status, TransactionStatus.corrected);
    final Transaction now = row(s, r!.replacementId);
    expect(now.amount, const Money.pesos(320));
    expect(now.countsTowardTotals, isTrue);
    expect(s.wasEditedAway(row(s, 'tx_100')), isTrue);
    expect(s.wasEditedAway(now), isFalse);
  });

  test('what the form does not show is carried over', () async {
    final FinancialState s = await fresh();
    s.logTransaction(lunch);
    final EditReceipt r = s.editTransaction(
      'tx_100',
      edit(lunch, amount: const Money.pesos(300)),
    )!;
    final Transaction now = row(s, r.replacementId);
    // createdAt drives Safe to Spend's measuring window; a correction is
    // not new spending (ledger-reconciler, 2026-10-11).
    expect(now.createdAt, 1000);
    expect(now.isTaxDeductible, isTrue);
    expect(now.taxTinOrRef, 'OR-77');
    expect(now.attachmentPath, '/receipts/a.jpg');
    expect(now.attachmentName, 'a.jpg');
    expect(now.subcategory, 'Lunch', reason: 'same category, so kept');
    expect(now.profile, ProfileEntity.personal);
    expect(now.id, startsWith('tx_100_e'));

    // A different category drops the sub-category that belonged to the old.
    final EditReceipt r2 = s.editTransaction(
      now.id,
      edit(now, category: 'Transportation'),
    )!;
    final Transaction again = row(s, r2.replacementId);
    expect(again.subcategory, isNull);
    // One suffix however many edits.
    expect(RegExp(r'^tx_100_e\d+$').hasMatch(again.id), isTrue);
    expect(s.wasEditedAway(row(s, now.id)), isTrue);
  });

  test('moving it to another account puts the money back where it was '
      'and takes it from the new one', () async {
    final FinancialState s = await fresh();
    s.logTransaction(lunch);
    final Money cashBefore = cash(s, 'acc_cash');
    final Money gcashBefore = cash(s, 'acc_gcash');

    s.editTransaction('tx_100', edit(lunch, accountId: 'acc_gcash'));

    expect(cash(s, 'acc_cash'), cashBefore + const Money.pesos(250));
    expect(cash(s, 'acc_gcash'), gcashBefore - const Money.pesos(250));
  });

  test('turning a spend into income swings the account by twice the '
      'amount', () async {
    final FinancialState s = await fresh();
    s.logTransaction(lunch);
    final Money before = cash(s, 'acc_cash');
    s.editTransaction(
      'tx_100',
      edit(lunch, type: TransactionType.income, category: 'Salary'),
    );
    expect(cash(s, 'acc_cash'), before + const Money.pesos(500));
  });

  test('an edit that changes nothing writes nothing', () async {
    final FinancialState s = await fresh();
    s.logTransaction(lunch);
    final int rows = s.transactions.length;
    expect(s.editTransaction('tx_100', edit(lunch)), isNull);
    expect(s.transactions.length, rows);
    expect(row(s, 'tx_100').status, isNot(TransactionStatus.corrected));
  });

  group('refusals', () {
    test('an example entry is refused, and nothing moves', () async {
      final FinancialState s = await fresh();
      final Transaction sample = s.transactions.firstWhere(
        (Transaction t) =>
            t.isSample && s.takeBackPreview(t.id) == TakeBackOutcome.done,
      );
      final List<Account> before = s.accounts;
      expect(s.editPreview(sample.id), EditOutcome.example);
      expect(
        s.editTransaction(
          sample.id,
          edit(sample, amount: sample.amount + const Money.pesos(1)),
        ),
        isNull,
      );
      expect(s.accounts, before);
    });

    test('a bill payment is refused', () async {
      final FinancialState s = await fresh();
      // A monthly bill that has since moved on, so this older payment is
      // one take-back allows (D31) and the edit still refuses.
      s.addUpcoming(
        const UpcomingItem(
          id: 'up_x',
          name: 'Some bill nobody has',
          amount: Money.pesos(1299),
          dueDate: '2026-10-15',
          type: UpcomingItemType.bill,
          repeatDay: 15,
        ),
      );
      s.logTransaction(
        const Transaction(
          id: 'tx_bill_1',
          type: TransactionType.expense,
          amount: Money.pesos(1299),
          category: 'Utilities',
          accountId: 'acc_cash',
          date: '2026-09-17',
          createdAt: 5,
          merchant: 'Some bill nobody has',
        ),
      );
      expect(s.takeBackPreview('tx_bill_1'), TakeBackOutcome.done);
      expect(s.editPreview('tx_bill_1'), EditOutcome.billPayment);
    });

    test('a debt payment is refused, like its take-back', () async {
      final FinancialState s = await fresh();
      final Debt d = s.debts.firstWhere(
        (Debt d) => d.direction == DebtDirection.iOwe && !d.isSettled,
      );
      s.recordDebtPayment(d.id, 100, accountId: 'acc_cash');
      final Transaction paid = s.transactions.first;
      expect(s.editPreview(paid.id), EditOutcome.refused);
      expect(
        s.editTransaction(paid.id, edit(paid, amount: const Money.pesos(50))),
        isNull,
      );
    });
  });

  group('refusals found by QA (2026-10-11)', () {
    test('money lent with its debt gone is refused: the sheet cannot say '
        '"a person" and filled in an account of their own', () async {
      final FinancialState s = await fresh();
      s.logTransaction(
        lendingEntry(
          id: 'tx_lend_qa',
          amount: const Money.pesos(600),
          person: 'Ana',
          accountId: 'acc_gcash',
          today: today,
          createdAt: 1,
        ),
      );
      expect(s.takeBackPreview('tx_lend_qa'), TakeBackOutcome.done);
      expect(s.editPreview('tx_lend_qa'), EditOutcome.otherPerson);
      final Money cashBefore = cash(s, 'acc_cash');
      final Transaction lent = row(s, 'tx_lend_qa');
      // What the sheet used to hand back: the same entry, now with a
      // destination of the person's own. Refused, and nothing moves.
      expect(
        s.editTransaction(
          lent.id,
          Transaction(
            id: lent.id,
            type: TransactionType.transfer,
            amount: lent.amount,
            category: 'Transfer',
            accountId: 'acc_gcash',
            toAccountId: 'acc_cash',
            date: lent.date,
            createdAt: lent.createdAt,
          ),
        ),
        isNull,
      );
      expect(cash(s, 'acc_cash'), cashBefore);
    });

    test('a share a friend paid is refused', () async {
      final FinancialState s = await fresh();
      s.logTransaction(
        paidByOtherEntry(
          id: 'tx_share_qa',
          amount: const Money.pesos(300),
          category: 'Food & Dining',
          person: 'Ana',
          today: today,
          createdAt: 1,
        ),
      );
      expect(s.editPreview('tx_share_qa'), EditOutcome.otherPerson);
    });

    test('accounts an edit cannot offer are refused: money owed to you, or '
        'a loan as the source', () async {
      final FinancialState s = await fresh();
      Transaction move(String id, String from, String to) => Transaction(
        id: id,
        type: TransactionType.transfer,
        amount: const Money.pesos(1000),
        category: 'Transfer',
        accountId: from,
        toAccountId: to,
        date: '2026-09-17',
        createdAt: 1,
      );
      s.logTransaction(move('tx_to_recv', 'acc_gcash', 'acc_receivables'));
      s.logTransaction(move('tx_from_loan', 'acc_personal_loan', 'acc_cash'));
      s.logTransaction(move('tx_move_ok', 'acc_gcash', 'acc_cash'));
      expect(s.editPreview('tx_to_recv'), EditOutcome.otherAccount);
      expect(s.editPreview('tx_from_loan'), EditOutcome.otherAccount);
      expect(s.editPreview('tx_move_ok'), EditOutcome.done);
    });
  });

  group('card payments (2026-10-11)', () {
    Transaction payCard(int pesos) => Transaction(
      id: 'tx_move_card',
      type: TransactionType.transfer,
      amount: Money.pesos(pesos),
      category: 'Transfer',
      accountId: 'acc_gcash',
      toAccountId: 'acc_bpi_cc',
      date: '2026-09-17',
      createdAt: 1,
      merchant: 'Transfer: GCash Wallet to BPI Rewards Card',
    );

    test('a card payment edited from 500 to 700 leaves every account where '
        'a 700 payment would have', () async {
      final FinancialState edited = await fresh();
      edited.logTransaction(payCard(500));
      final Money gcashAt500 = cash(edited, 'acc_gcash');
      final Money cardAt500 = cash(edited, 'acc_bpi_cc');
      expect(edited.editPreview('tx_move_card'), EditOutcome.done);
      expect(edited.editTransaction('tx_move_card', payCard(700)), isNotNull);

      // Directional: 200 more left GCash and the card moved.
      expect(cash(edited, 'acc_gcash'), gcashAt500 - const Money.pesos(200));
      expect(cash(edited, 'acc_bpi_cc'), isNot(cardAt500));

      // The invariant, measured against the engine itself rather than a
      // sign this test would have to assume: the same as paying 700.
      final FinancialState direct = await fresh();
      direct.logTransaction(payCard(700));
      for (final Account a in direct.accounts) {
        expect(cash(edited, a.id), a.balance, reason: a.name);
      }
    });

    test('a spend on the card is editable and moves only the card', () async {
      final FinancialState s = await fresh();
      const Transaction onCard = Transaction(
        id: 'tx_on_card',
        type: TransactionType.expense,
        amount: Money.pesos(1200),
        category: 'Shopping & Personal',
        accountId: 'acc_bpi_cc',
        date: '2026-09-17',
        createdAt: 1,
      );
      s.logTransaction(onCard);
      final Money cardBefore = cash(s, 'acc_bpi_cc');
      final Money gcashBefore = cash(s, 'acc_gcash');
      expect(s.editPreview('tx_on_card'), EditOutcome.done);
      s.editTransaction(
        'tx_on_card',
        edit(onCard, amount: const Money.pesos(1500)),
      );
      expect(cash(s, 'acc_bpi_cc'), isNot(cardBefore));
      expect(cash(s, 'acc_gcash'), gcashBefore);
      final FinancialState direct = await fresh();
      direct.logTransaction(edit(onCard, amount: const Money.pesos(1500)));
      expect(cash(s, 'acc_bpi_cc'), cash(direct, 'acc_bpi_cc'));
    });
  });

  test('a reconciled row whose money changes goes back to Confirmed; a '
      'note alone keeps it Reconciled', () async {
    final FinancialState s = await fresh();
    const Transaction checked = Transaction(
      id: 'tx_rec_1',
      type: TransactionType.expense,
      amount: Money.pesos(250),
      category: 'Food & Dining',
      accountId: 'acc_cash',
      date: '2026-09-17',
      createdAt: 1000,
      status: TransactionStatus.reconciled,
    );
    s.logTransaction(checked);
    final EditReceipt a = s.editTransaction(
      'tx_rec_1',
      edit(checked, note: 'just a note'),
    )!;
    final Transaction noted = row(s, a.replacementId);
    expect(noted.status, TransactionStatus.reconciled);
    final EditReceipt b = s.editTransaction(
      noted.id,
      edit(noted, amount: const Money.pesos(260)),
    )!;
    expect(row(s, b.replacementId).status, TransactionStatus.confirmed);
  });

  group('undo', () {
    test('puts the money, the row and its status back', () async {
      final FinancialState s = await fresh();
      s.logTransaction(lunch);
      final Money before = cash(s, 'acc_cash');
      final int rows = s.transactions.length;
      final TransactionStatus status = row(s, 'tx_100').status;

      final EditReceipt r = s.editTransaction(
        'tx_100',
        edit(lunch, amount: const Money.pesos(900)),
      )!;
      expect(cash(s, 'acc_cash'), isNot(before));

      expect(s.undoEdit(r), isTrue);
      expect(cash(s, 'acc_cash'), before);
      expect(s.transactions.length, rows);
      expect(row(s, 'tx_100').status, status);
      expect(
        s.transactions.any((Transaction t) => t.id == r.replacementId),
        isFalse,
      );
    });

    test('refuses, changing nothing, when the edit was taken back '
        'since', () async {
      final FinancialState s = await fresh();
      s.logTransaction(lunch);
      final EditReceipt r = s.editTransaction(
        'tx_100',
        edit(lunch, amount: const Money.pesos(900)),
      )!;
      s.takeBackEntry(r.replacementId);
      final Money afterTakeBack = cash(s, 'acc_cash');

      expect(s.undoEdit(r), isFalse);
      expect(
        cash(s, 'acc_cash'),
        afterTakeBack,
        reason: 'undo moved money a second time',
      );
    });
  });

  test('the two versions are not offered as a possible double entry, and '
      'the old one is not a usual', () async {
    final FinancialState s = await fresh();
    const Transaction kape = Transaction(
      id: 'tx_k1',
      type: TransactionType.expense,
      amount: Money.pesos(150),
      category: 'Food & Dining',
      accountId: 'acc_cash',
      date: '2026-09-17',
      createdAt: 10,
      merchant: 'Kape',
    );
    s.logTransaction(kape);
    s.logTransaction(
      const Transaction(
        id: 'tx_k2',
        type: TransactionType.expense,
        amount: Money.pesos(150),
        category: 'Food & Dining',
        accountId: 'acc_cash',
        date: '2026-09-16',
        createdAt: 11,
        merchant: 'Kape',
      ),
    );
    s.editTransaction('tx_k1', edit(kape, note: 'with pandesal'));

    // The usual chip counts what still counts.
    final List<UsualEntry> usual = usualEntries(s.transactions);
    final UsualEntry k = usual.firstWhere(
      (UsualEntry u) => u.merchant == 'Kape',
    );
    expect(k.count, 2, reason: 'the taken-back version was counted too');

    // What Reconciliation hands the duplicate finder.
    final List<DuplicatePair> pairs = findDuplicates(
      s.transactions
          .where((Transaction t) => t.status != TransactionStatus.corrected)
          .toList(),
    );
    expect(
      pairs.any(
        (DuplicatePair p) =>
            p.first.id.startsWith('tx_k1') && p.second.id.startsWith('tx_k1'),
      ),
      isFalse,
    );
  });

  test('a balanced statement check after the entry is found, one before '
      'it is not', () async {
    final FinancialState s = await fresh();
    s.logTransaction(lunch);
    expect(s.checkedAfter(lunch, 'acc_cash'), isNull);
    s.recordReconciliation(
      accountId: 'acc_cash',
      bookBalance: 100,
      actualBalance: 100,
    );
    // lunch was logged (createdAt 1000) long before the check: found.
    expect(s.checkedAfter(lunch, 'acc_cash'), isNotNull);
    // An entry logged after the check is not covered by it.
    final Transaction later = Transaction(
      id: 'tx_later',
      type: TransactionType.expense,
      amount: const Money.pesos(10),
      category: 'Food & Dining',
      accountId: 'acc_cash',
      date: '2026-09-18',
      createdAt: today.millisecondsSinceEpoch + 1,
    );
    expect(s.checkedAfter(later, 'acc_cash'), isNull);
    // Another account's check says nothing about this one.
    expect(s.checkedAfter(lunch, 'acc_gcash'), isNull);
  });
}
