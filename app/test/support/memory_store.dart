// An in-memory ledger for widget tests.
//
// Shared rather than copied into each test file, because the alternative is
// five slightly different fakes that drift, and then a test passing because
// its own fake is lenient rather than because the app is right.
//
// ledger_store_test.dart deliberately keeps its OWN fake: it asserts the exact
// order of read, write and notify, so it needs a repository that records what
// happened to it. That is a different job from this one, which is only "hold
// some JSON so a screen has something to draw".
import 'dart:convert';

import 'package:salapify/core/data/backup.dart';
import 'package:salapify/core/data/ledger_repository.dart';
import 'package:salapify/core/data/ledger_store.dart';

class MemoryRepo implements LedgerRepository {
  MemoryRepo([this._ledger]);

  String? _ledger;
  String? _undo;

  @override
  Future<String?> readLedger() async => _ledger;

  @override
  Future<void> writeLedger(String json) async => _ledger = json;

  @override
  Future<String?> readUndoSnapshot() async => _undo;

  @override
  Future<void> writeUndoSnapshot(String json) async => _undo = json;

  @override
  Future<void> clearUndoSnapshot() async => _undo = null;

  @override
  Future<void> clearLedger() async => _ledger = null;

  /// What is actually persisted, for asserting that a save survived.
  Map<String, dynamic>? get stored =>
      _ledger == null ? null : jsonDecode(_ledger!) as Map<String, dynamic>;
}

/// A loaded store over [seed], or over an empty ledger when seed is null.
Future<LedgerStore> memoryStore([Map<String, dynamic>? seed]) async {
  final store = LedgerStore(MemoryRepo(seed == null ? null : jsonEncode(seed)));
  await store.load();
  return store;
}

/// A LIVED-IN ledger: two accounts with real balances, the default categories,
/// and a few days of entries.
///
/// Deliberately not empty, and deliberately not tidy. The shipped app's render
/// harness spent most of its life shooting an EMPTY store, so sixteen images
/// at two brightnesses were all first-run welcome screens and not one of them
/// ever contained a peso figure; a crossed-out peso sign survived dozens of
/// renders and reached the founder's phone. A fixture that cannot show the
/// defect makes "look at the screen" a ritual.
Map<String, dynamic> livedIn() => {
  'schemaVersion': 12,
  // The eight defaults, present because a REAL ledger has them and because
  // leaving them out quietly disabled every category guess: the parser checks
  // a guessed id against the live list before using it, so an empty list means
  // no category is ever suggested. The journey test caught that, and the rule
  // was working exactly as written; the fixture was the thing that was wrong.
  //
  // GROWN for Plan with three caps, chosen so the Budget screen renders every
  // state it can be in rather than a column of identical healthy rows. Against
  // this fixture's September spending: Groceries 2,450.50 of 2,500 is down to
  // its last 49.50 and needs a look, Food 250 of 200 is over, Transport 45 of
  // 1,500 is comfortable, and Bills and Load carry no cap at all, which is its
  // own row shape. A fixture that can only show one state is a fixture that
  // cannot show a defect in the other three.
  'categories': defaultCategories.map((c) {
    const caps = {'cat_groceries': 2500.00, 'cat_food': 200.00, 'cat_transport': 1500.00};
    return {...c, 'monthlyCap': ?caps[c['id']]};
  }).toList(),
  // GROWN for Home. Without a schedule `normalizeSchedule` falls back to the
  // 15th and the 31st, which works, but a fixture that never states its own
  // payday cannot show a wrong one either. The 15th and the 30th is what the
  // onboarding offers first.
  // GROWN for Plan, never shrunk. `monthlyLimit` is what budgetSummary reads
  // for the "left to spend this month" hero, and without one the Budget
  // segment renders its empty state and proves nothing. 20,000 against the
  // fixture's ~6,045 of tagged September spending leaves the hero positive and
  // the rail part full, which is the ordinary case the screen is read in.
  'settings': {
    'monthlyLimit': 20000.00,
    'paydaySchedule': {
      'mode': 'semimonthly',
      'days': [15, 30],
    },
  },
  // The bills "Coming up" is made of. Both land inside the current cycle at
  // the fixture's render date, which is the only way the section has anything
  // to say: upcomingCommitments only counts what falls on or before the next
  // payday, so a recurring row dated outside that window renders nothing and
  // proves nothing.
  'recurring': [
    {
      'id': 'rc_meralco',
      'type': 'expense',
      'label': 'Meralco',
      'amount': 3200.00,
      'dayOfMonth': 11,
    },
    {
      'id': 'rc_spotify',
      'type': 'expense',
      'label': 'Spotify',
      'amount': 194.00,
      'dayOfMonth': 13,
    },
  ],
  // GROWN for the Accounts screen, never shrunk. The three original accounts
  // keep their exact balances so the journeys that name per-account movement
  // still mean what they meant.
  //
  // What was added and why each one earns its place: an institutionId on the
  // two that have one, because the row's only decoration is the institution
  // MONOGRAM and a fixture with no institution renders a screen of question
  // marks; a CREDIT CARD, because credit is the only row kind that carries a
  // utilisation bar and a limit caption, and nothing else in the fixture could
  // make one appear; and one debt each way, because the whole product claim is
  // that debt runs in both directions and a screen that has only ever been
  // rendered against zero of them has never been looked at.
  'accounts': [
    {
      'id': 'a_gcash',
      'name': 'GCash',
      'kind': 'ewallet',
      'balance': 8410.50,
      'institutionId': 'gcash',
    },
    {
      'id': 'a_bpi',
      'name': 'BPI',
      // 'bank' is NOT a kind the taxonomy knows: _kindToSubtype maps cash,
      // savings, checking and ewallet, and anything else derives to cash on
      // hand. The first render duly labelled BPI "Cash on hand".
      'kind': 'savings',
      'balance': 42300.00,
      'institutionId': 'bpi',
    },
    {'id': 'a_cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1250.00},
  ],
  // CREDIT LIVES HERE, not in `accounts`, and this is the correction the first
  // render forced. account_taxonomy.dart puts the credit, loans and
  // installments categories in AccountStore.debts, so a credit card filed
  // under `accounts` is classified as cash on hand: it landed in the "Cash and
  // e-wallets" section, took no utilisation bar, and was ADDED to assets
  // instead of subtracted as a liability. The screen said the founder was
  // ₱8,240 better off than they were.
  //
  // Debts total on `remaining`, which is what netWorthParts reads.
  'debts': [
    {
      'id': 'd_ubp_cc',
      'name': 'UnionBank Rewards',
      'subtype': 'credit_card',
      'remaining': 4120.00,
      'creditLimit': 40000.00,
      // `dueDay`, which is the field the ENGINE reads. The first version wrote
      // `statementDueDay`, a name nothing in core/money looks at, so the card
      // produced no due date, never reached upcomingDues, and silently could
      // not appear in any bill list. The screen looked fine and was missing a
      // payment.
      'dueDay': 3,
      'minPayment': 500.00,
      'institutionId': 'unionbank',
    },
    {
      'id': 'd_lola',
      'name': 'Lola',
      'subtype': 'personal_loan',
      'remaining': 6000.00,
      'dueDay': 18,
      'minPayment': 1500.00,
    },
  ],
  // Receivables are keyed on `amount` minus payments, NOT on `remaining`, and
  // they only count toward net worth when `cashLeg` is true, meaning real
  // money left the founder's pocket. A note that somebody owes a share of
  // something does not move net worth. Both rules live in trackedRemaining,
  // and the first fixture got both wrong, so the row silently contributed
  // nothing and the render showed assets ₱1,800 short.
  'receivables': [
    {'id': 'r_marco', 'name': 'Marco', 'amount': 1800.00, 'cashLeg': true},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'income',
      'amount': 18500.00,
      'label': 'Sweldo',
      'date': '2026-09-11',
      'accountId': 'a_bpi',
    },
    {
      'id': 't2',
      'type': 'expense',
      'amount': 3200.00,
      'label': 'Meralco',
      'date': '2026-09-11',
      'accountId': 'a_bpi',
      'categoryId': 'cat_bills',
    },
    {
      'id': 't3',
      'type': 'expense',
      'amount': 250.00,
      'label': 'Jollibee',
      'date': '2026-09-12',
      'accountId': 'a_gcash',
      'categoryId': 'cat_food',
    },
    {
      'id': 't4',
      'type': 'expense',
      'amount': 45.00,
      'label': 'Pamasahe',
      'date': '2026-09-12',
      'accountId': 'a_cash',
      'categoryId': 'cat_transport',
    },
    {
      'id': 't5',
      'type': 'expense',
      'amount': 2450.50,
      'label': 'Groceries',
      'date': '2026-09-12',
      'accountId': 'a_gcash',
      'categoryId': 'cat_groceries',
    },
    {
      'id': 't6',
      'type': 'expense',
      'amount': 100.00,
      'label': 'Load',
      'date': '2026-09-13',
      'accountId': 'a_gcash',
      'categoryId': 'cat_load',
    },
    {
      'id': 't7',
      'type': 'transfer',
      'amount': 5000.00,
      'label': 'To GCash',
      'date': '2026-09-13',
      'accountId': 'a_bpi',
      'flow': 'out',
    },
  ],
};
