// A lived-in ledger, used by the tests AND by the app's debug-only sample data
// action. One definition, on purpose.
//
// It used to live in test/support/memory_store.dart, where the app could not
// reach it. That meant the screens the founder reviewed in a screenshot and the
// screens they saw on an emulator were fed by two different things: a rich
// fixture in one, a completely empty store in the other. A defect visible in
// one and not the other has nowhere to be caught, and that is exactly what
// happened on 2026-09-14, when a first run said "Set your payday in Plan" and
// Plan could not set a payday. Every test passed and every screenshot looked
// right, because both ran against a fixture that already had a payday.
//
// Deliberately not tidy. The shipped app's render harness spent most of its
// life shooting an EMPTY store, so sixteen images at two brightnesses were all
// first-run welcome screens and not one of them ever contained a peso figure; a
// crossed-out peso sign survived dozens of renders and reached the founder's
// phone. A fixture that cannot show the defect makes "look at the screen" a
// ritual.
//
// NOT shipped to users. The only thing that calls this in the app is gated on
// kDebugMode, which is a compile time constant, so a release build drops both
// the button and this data.
import '../core/data/backup.dart';

/// The date the TESTS pin to.
///
/// Tests need a fixed clock or they pass only on the days somebody happened to
/// run them. The app passes nothing and gets today, so the emulator shows a
/// ledger that looks current instead of one dated last September.
DateTime get sampleAnchor => DateTime(2026, 9, 11);

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A ledger with real balances, the default categories, debts both ways, and a
/// few days of entries.
///
/// [today] anchors every date in it. Pass [sampleAnchor] for the deterministic
/// fixture the tests use; leave it out and the data lands around the real
/// today, which is what makes it worth looking at on an emulator.
Map<String, dynamic> sampleLedger({DateTime? today}) {
  final base = today ?? DateTime.now();
  final day0 = _iso(base);
  final day1 = _iso(base.add(const Duration(days: 1)));
  final day2 = _iso(base.add(const Duration(days: 2)));

  // A recurring bill is a DAY OF THE MONTH, not a date, so neither of these can
  // simply be today or today + 2. Both have to land on a day that exists in
  // EVERY month, or the row becomes unreachable in February and the section it
  // feeds renders empty for a reason nobody would guess from the screen.
  //
  // 28 is the ceiling for that, and the first version of this only clamped the
  // second bill. Its own test caught the first one on 2026-01-30.
  final billDay1 = base.day > 28 ? 28 : base.day;
  final billDay2 = billDay1 + 2 > 28 ? billDay1 - 2 : billDay1 + 2;

  return {
    'schemaVersion': 12,
    // The eight defaults, present because a REAL ledger has them and because
    // leaving them out quietly disabled every category guess: the parser checks
    // a guessed id against the live list before using it, so an empty list
    // means no category is ever suggested. The journey test caught that, and
    // the rule was working exactly as written; the fixture was wrong.
    //
    // Three caps, chosen so the Budget screen renders every state it can be in
    // rather than a column of identical healthy rows: Groceries 2,450.50 of
    // 2,500 is down to its last 49.50 and needs a look, Food 250 of 200 is
    // over, Transport 45 of 1,500 is comfortable, and Bills and Load carry no
    // cap at all, which is its own row shape. A fixture that can only show one
    // state cannot show a defect in the other three.
    'categories': defaultCategories.map((c) {
      const caps = {
        'cat_groceries': 2500.00,
        'cat_food': 200.00,
        'cat_transport': 1500.00,
      };
      return {...c, 'monthlyCap': ?caps[c['id']]};
    }).toList(),
    // Without a schedule `normalizeSchedule` falls back to the 15th and the
    // 31st, which works, but a fixture that never states its own payday cannot
    // show a wrong one either. The 15th and the 30th is what onboarding offers
    // first. `monthlyLimit` is what budgetSummary reads for the "left to spend
    // this month" hero; without one the Budget segment renders its empty state
    // and proves nothing.
    'settings': {
      'monthlyLimit': 20000.00,
      'paydaySchedule': {
        'mode': 'semimonthly',
        'days': [15, 30],
      },
    },
    // The bills "Coming up" is made of. They have to land inside the current
    // cycle or the section has nothing to say: upcomingCommitments only counts
    // what falls on or before the next payday, so a recurring row dated outside
    // that window renders nothing and proves nothing.
    'recurring': [
      {
        'id': 'rc_meralco',
        'type': 'expense',
        'label': 'Meralco',
        'amount': 3200.00,
        'dayOfMonth': billDay1,
      },
      {
        'id': 'rc_spotify',
        'type': 'expense',
        'label': 'Spotify',
        'amount': 194.00,
        'dayOfMonth': billDay2,
      },
      // RECURRING INCOME, added for Upcoming, and the fixture was genuinely
      // missing a state without it. Every recurring row here was an expense, so
      // sweldoTimeline marked the paydays from the schedule and had nothing to
      // attach to them: every payday row showed a date and no money. That is a
      // real state, and it is what a new user sees before they tell the app
      // what they earn, but it was the ONLY state the fixture could reach, and
      // a fixture that cannot reach a state cannot show a defect in it.
      //
      // Day 15 and not 30, which also gives the window BOTH states: with the
      // schedule on the 15th and the 30th, the 15th now carries a sweldo and
      // the 30th is still a bare payday. One screen, both shapes, which is the
      // only way to look at a render and judge the one that is harder to draw.
      //
      // It moves nothing already on screen. Home reads bills through
      // upcomingCommitments, which filters to type == 'expense', and
      // safeToSpend subtracts bills from liquid without consulting income at
      // all. The full suite is the check on that claim, not this comment.
      {
        'id': 'rc_sweldo',
        'type': 'income',
        'label': 'Sweldo',
        'amount': 18500.00,
        'dayOfMonth': 15,
      },
    ],
    // An institutionId on the two that have one, because an Accounts row's only
    // decoration is the institution MONOGRAM and a fixture with no institution
    // renders a screen of question marks.
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
    // CREDIT LIVES HERE, not in `accounts`, and this is the correction the
    // first render forced. account_taxonomy.dart puts credit, loans and
    // installments in AccountStore.debts, so a credit card filed under
    // `accounts` is classified as cash on hand: it landed in "Cash and
    // e-wallets", took no utilisation bar, and was ADDED to assets instead of
    // subtracted as a liability. The screen said the founder was ₱8,240 better
    // off than they were.
    //
    // Debts total on `remaining`, which is what netWorthParts reads.
    'debts': [
      {
        'id': 'd_ubp_cc',
        'name': 'UnionBank Rewards',
        'subtype': 'credit_card',
        'remaining': 4120.00,
        'creditLimit': 40000.00,
        // `dueDay`, which is the field the ENGINE reads. The first version
        // wrote `statementDueDay`, a name nothing in core/money looks at, so
        // the card produced no due date, never reached upcomingDues, and
        // silently could not appear in any bill list.
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
    // Receivables are keyed on `amount` MINUS payments, not on `remaining`, and
    // they only count toward net worth when `cashLeg` is true, meaning real
    // money left the founder's pocket. A note that somebody owes a share of
    // something does not move net worth. Both rules live in trackedRemaining,
    // and the first fixture got both wrong, so the row silently contributed
    // nothing and the render showed assets ₱1,800 short.
    'receivables': [
      {'id': 'r_marco', 'name': 'Marco', 'amount': 1800.00, 'cashLeg': true},
      // PARTLY REPAID, so the Debt screen has something to draw a progress bar
      // against. `remainingOf` is amount minus payments, so this is 1,200 left
      // of 3,000 and the bar is 60 per cent.
      {
        'id': 'r_joy',
        'name': 'Joy',
        'amount': 3000.00,
        'cashLeg': true,
        'accountId': 'a_bpi',
        'dueDate': '2026-09-25',
        'payments': [
          {'id': 'rp_joy1', 'amount': 1000.00, 'date': '2026-08-20'},
          {'id': 'rp_joy2', 'amount': 800.00, 'date': '2026-09-05'},
        ],
      },
      // SETTLED, so the Settled section is rendered rather than assumed. It
      // went unrendered for exactly as long as no fixture row was ever paid.
      {
        'id': 'r_bea',
        'name': 'Bea',
        'amount': 500.00,
        'cashLeg': true,
        'paid': true,
        'payments': [
          {'id': 'rp_bea1', 'amount': 500.00, 'date': '2026-09-01'},
        ],
      },
    ],
    // PAYABLES: informal money the founder owes a person, the mirror of
    // receivables and a real schema collection since v7. There is no write
    // engine for it in this app or in either frozen one, so it can only arrive
    // from a restored backup, and the Debt screen shows it read only and says
    // so. The fixture carries one precisely because that path would otherwise
    // never be rendered or tested by anybody.
    'payables': [
      {'id': 'p_kuya', 'name': 'Kuya Ben', 'amount': 2500.00, 'cashLeg': true},
    ],
    'transactions': [
      {
        'id': 't1',
        'type': 'income',
        'amount': 18500.00,
        'label': 'Sweldo',
        'date': day0,
        'accountId': 'a_bpi',
      },
      {
        'id': 't2',
        'type': 'expense',
        'amount': 3200.00,
        'label': 'Meralco',
        'date': day0,
        'accountId': 'a_bpi',
        'categoryId': 'cat_bills',
      },
      {
        'id': 't3',
        'type': 'expense',
        'amount': 250.00,
        'label': 'Jollibee',
        'date': day1,
        'accountId': 'a_gcash',
        'categoryId': 'cat_food',
      },
      {
        'id': 't4',
        'type': 'expense',
        'amount': 45.00,
        'label': 'Pamasahe',
        'date': day1,
        'accountId': 'a_cash',
        'categoryId': 'cat_transport',
      },
      {
        'id': 't5',
        'type': 'expense',
        'amount': 2450.50,
        'label': 'Groceries',
        'date': day1,
        'accountId': 'a_gcash',
        'categoryId': 'cat_groceries',
      },
      {
        'id': 't6',
        'type': 'expense',
        'amount': 100.00,
        'label': 'Load',
        'date': day2,
        'accountId': 'a_gcash',
        'categoryId': 'cat_load',
      },
      {
        'id': 't7',
        'type': 'transfer',
        'amount': 5000.00,
        'label': 'To GCash',
        'date': day2,
        'accountId': 'a_bpi',
        'flow': 'out',
      },
    ],
  };
}
