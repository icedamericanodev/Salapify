import '../models/models.dart';

/// The starting ledger, ported from the prototype's src/data/initialData.ts.
///
/// It is deliberately LIVED IN. An empty fixture makes every screen look like
/// a first run, which is exactly the state that hides money defects: a peso
/// figure cannot be wrong if no screen ever draws one.
class SeedData {
  const SeedData._();

  /// Transaction timestamps are anchored to "now" rather than to a fixed date,
  /// so the 30-day windows the engine reads still have signal whenever the app
  /// is opened. The calendar dates stay as the prototype wrote them.
  static int _daysAgo(int days) =>
      DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;

  static const List<Account> accounts = <Account>[
    Account(
      id: 'acc_cash',
      profile: ProfileEntity.personal,
      name: 'Cash on Hand (Pitaka)',
      kind: AccountKind.cash,
      institution: 'Cash',
      balance: 1850.00,
      monogram: '₱',
      notes: 'Physical cash for jeepneys, trike, and street food',
    ),
    Account(
      id: 'acc_gcash',
      profile: ProfileEntity.personal,
      name: 'GCash Wallet',
      kind: AccountKind.gcash,
      institution: 'GCash',
      balance: 8420.50,
      monogram: 'GC',
      accountNumber: '0917-***-4821',
    ),
    Account(
      id: 'acc_maya',
      profile: ProfileEntity.household,
      name: 'Maya Savings',
      kind: AccountKind.maya,
      institution: 'Maya',
      balance: 15300.00,
      monogram: 'MY',
      interestRate: 6.0,
    ),
    Account(
      id: 'acc_bpi',
      profile: ProfileEntity.personal,
      name: 'BPI Preferred Payroll',
      kind: AccountKind.bank,
      institution: 'BPI',
      balance: 48500.00,
      monogram: 'BPI',
    ),
    Account(
      id: 'acc_seabank',
      profile: ProfileEntity.sideHustle,
      name: 'MariBank Digital Savings',
      kind: AccountKind.bank,
      institution: 'MariBank',
      balance: 24250.00,
      // MB, not the SB the prototype's seed carries. SeaBank was renamed
      // MariBank in 2024, the id still says seabank, and the monogram was
      // never updated with the name. The prototype's OWN computeMonogram
      // returns MB for MariBank, so its seed disagrees with its own function.
      // Caught by accounts_test's "every seeded account still computes the
      // monogram it was given", which is the whole reason that test compares
      // the map against the data instead of trusting either one.
      monogram: 'MB',
    ),
    Account(
      id: 'acc_ub_debit',
      profile: ProfileEntity.business,
      name: 'UnionBank Debit Card',
      kind: AccountKind.debit,
      institution: 'UnionBank',
      balance: 12400.00,
      monogram: 'UB',
      // From the prototype's own seed. Carried over 2026-09-18 with the
      // Accounts tab, because a debit account is DRAWN AS A CARD there and a
      // card with no digits on it is a picture of a defect.
      accountNumber: '1029-****-6789',
      cardNetwork: CardNetwork.mastercard,
      notes: 'Operating account for business transactions and SaaS',
    ),
    Account(
      id: 'acc_mp2',
      profile: ProfileEntity.personal,
      name: 'Pag-IBIG MP2 Fund',
      kind: AccountKind.investment,
      institution: 'Pag-IBIG',
      balance: 65000.00,
      monogram: 'MP2',
    ),
    Account(
      id: 'acc_receivables',
      profile: ProfileEntity.personal,
      name: 'Accounts Receivable (Pahiram & Split)',
      kind: AccountKind.receivable,
      institution: 'Internal Ledger',
      balance: 6250.00,
      monogram: 'AR',
    ),
    Account(
      id: 'acc_bpi_cc',
      profile: ProfileEntity.personal,
      name: 'BPI Rewards Card',
      kind: AccountKind.credit,
      institution: 'BPI',
      balance: 4200.00,
      creditLimit: 40000.00,
      monogram: 'BPI',
      accountNumber: '5424-****-****-8819',
      dueDate: 'Oct 3',
      statementDate: '10th of the month',
      cardNetwork: CardNetwork.visa,
      notes: 'Kept below 30% utilization threshold for credit score health',
    ),
    Account(
      id: 'acc_personal_loan',
      profile: ProfileEntity.personal,
      name: 'BPI Gadget Loan',
      kind: AccountKind.loan,
      institution: 'BPI',
      balance: 10000.00,
      monogram: 'LOAN',
      dueDate: 'Sep 25',
      notes: 'Remaining gadget upgrade principal balance',
    ),
    Account(
      id: 'acc_pagibig_mortgage',
      profile: ProfileEntity.household,
      name: 'Pag-IBIG Housing Loan',
      kind: AccountKind.mortgage,
      institution: 'Pag-IBIG',
      balance: 385000.00,
      monogram: 'MTG',
      dueDate: 'Sep 28',
      notes: '30-year residential housing mortgage',
    ),
  ];

  static List<Transaction> transactions() => <Transaction>[
    // Three rows that exist so the Activity screen can be REVIEWED rather
    // than merely rendered. Without them every entry is a plain confirmed
    // expense, so the status chips, the struck-through amount and the
    // rule that keeps excluded money out of the totals are all invisible
    // in a screenshot, and a picture that cannot show the defect proves
    // nothing. See the fixture note in CLAUDE.md.
    Transaction(
      id: 'tx_pending_card',
      profile: ProfileEntity.business,
      subcategory: 'E-commerce (Shopee/Lazada)',
      type: TransactionType.expense,
      amount: 1899.00,
      category: 'Shopping & Personal',
      accountId: 'acc_ub_debit',
      merchant: 'Lazada Order',
      date: '2026-09-17',
      createdAt: _daysAgo(1),
      status: TransactionStatus.pending,
      note: 'Card authorisation, not posted yet',
    ),
    Transaction(
      id: 'tx_excluded_double',
      profile: ProfileEntity.household,
      subcategory: 'Electricity (Meralco)',
      type: TransactionType.expense,
      amount: 2840.00,
      category: 'Bills & Utilities',
      accountId: 'acc_maya',
      merchant: 'Meralco',
      date: '2026-09-15',
      createdAt: _daysAgo(3),
      status: TransactionStatus.excluded,
      note: 'Charged twice, this one is not mine to pay',
    ),
    Transaction(
      id: 'tx_transfer_1',
      profile: ProfileEntity.personal,
      subcategory: 'Savings Allocation',
      type: TransactionType.transfer,
      amount: 5000.00,
      category: 'Transfer',
      accountId: 'acc_bpi',
      toAccountId: 'acc_gcash',
      merchant: 'Top up GCash',
      date: '2026-09-16',
      createdAt: _daysAgo(2),
    ),
    Transaction(
      id: 'tx_salary_1',
      profile: ProfileEntity.personal,
      subcategory: '15th Sweldo Cutoff',
      type: TransactionType.income,
      amount: 32500.00,
      category: 'Salary & Compensation',
      accountId: 'acc_bpi',
      merchant: 'Corporate Payroll Direct Deposit',
      date: '2026-09-01',
      createdAt: _daysAgo(17),
      note: 'First cutoff net pay after SSS, PhilHealth, and Pag-IBIG',
    ),
    Transaction(
      id: 'tx_freelance_1',
      profile: ProfileEntity.business,
      subcategory: 'Client Service Retainers',
      type: TransactionType.income,
      amount: 18500.00,
      category: 'Business Revenue',
      accountId: 'acc_seabank',
      merchant: 'Apex Retainer Invoice #104',
      date: '2026-09-08',
      createdAt: _daysAgo(10),
    ),
    Transaction(
      id: 'tx_meralco',
      profile: ProfileEntity.household,
      subcategory: 'Electricity (Meralco)',
      type: TransactionType.expense,
      amount: 2840.00,
      category: 'Bills & Utilities',
      accountId: 'acc_maya',
      merchant: 'Meralco',
      date: '2026-09-15',
      createdAt: _daysAgo(3),
    ),
    Transaction(
      id: 'tx_groceries',
      profile: ProfileEntity.household,
      subcategory: 'Supermarket (SM/Puregold/Robinsons)',
      type: TransactionType.expense,
      amount: 3250.75,
      category: 'Groceries',
      accountId: 'acc_ub_debit',
      merchant: 'S&R Membership Shopping',
      date: '2026-09-14',
      createdAt: _daysAgo(4),
    ),
    Transaction(
      id: 'tx_jollibee',
      profile: ProfileEntity.personal,
      subcategory: 'Fast Food & Karinderya',
      type: TransactionType.expense,
      amount: 285.00,
      category: 'Food & Dining',
      accountId: 'acc_gcash',
      merchant: 'Jollibee',
      date: '2026-09-17',
      createdAt: _daysAgo(1),
    ),
    Transaction(
      id: 'tx_grab',
      profile: ProfileEntity.personal,
      subcategory: 'Ride Hailing (Grab/Angkas/Joyride)',
      type: TransactionType.expense,
      amount: 420.00,
      category: 'Transport & Commute',
      accountId: 'acc_gcash',
      merchant: 'Grab',
      date: '2026-09-17',
      createdAt: _daysAgo(1),
    ),
    Transaction(
      id: 'tx_padala',
      profile: ProfileEntity.personal,
      subcategory: 'Parents & Sibling Support',
      type: TransactionType.expense,
      amount: 6000.00,
      category: 'Family Support & Remittance',
      accountId: 'acc_bpi',
      merchant: 'Nanay Monthly Padala',
      date: '2026-09-16',
      createdAt: _daysAgo(2),
    ),
    Transaction(
      id: 'tx_coffee',
      profile: ProfileEntity.personal,
      subcategory: 'Coffee & Milk Tea',
      type: TransactionType.expense,
      amount: 180.00,
      category: 'Food & Dining',
      accountId: 'acc_cash',
      merchant: 'Local Kape Shop',
      date: '2026-09-18',
      createdAt: _daysAgo(0),
    ),

    // Four entries restored from the prototype's own fixture for the Reports
    // tab. Without them three whole sections of that screen are structurally
    // empty: FINANCING has no debt repayment to report, the debt service
    // ratio is 0%, the business segment has one expense, and household
    // spending is a single utility bill. A report whose sections are all
    // zero cannot be reviewed, and the empty-fixture trap is exactly what
    // put a crossed-out peso sign on the founder's phone once already.
    //
    // Amounts, dates, categories, sub-categories and accounts are the
    // prototype's, not invented. Note that adding these does NOT move any
    // balance: seed balances are stated on the accounts rather than derived
    // from the ledger, which is the prototype's shape too.
    Transaction(
      id: 'tx_homecredit_loan',
      profile: ProfileEntity.personal,
      subcategory: 'Gadget Loan (Home Credit/SpayLater/LazPay)',
      type: TransactionType.expense,
      amount: 2450.00,
      category: 'Debt & Loan Servicing',
      accountId: 'acc_gcash',
      merchant: 'Home Credit Philippines',
      date: '2026-09-04',
      createdAt: _daysAgo(14),
    ),
    Transaction(
      id: 'tx_mp2_contribution',
      profile: ProfileEntity.personal,
      subcategory: 'Pag-IBIG / SSS Salary Loan Repayment',
      type: TransactionType.expense,
      amount: 2500.00,
      category: 'Debt & Loan Servicing',
      accountId: 'acc_bpi',
      merchant: 'Pag-IBIG MP2 Top-up',
      date: '2026-09-05',
      createdAt: _daysAgo(13),
    ),
    Transaction(
      id: 'tx_saas',
      profile: ProfileEntity.business,
      subcategory: 'Software & SaaS Subscriptions',
      type: TransactionType.expense,
      amount: 1250.00,
      category: 'Business & Freelance Ops',
      accountId: 'acc_ub_debit',
      merchant: 'Figma Professional & GitHub Copilot',
      date: '2026-09-10',
      createdAt: _daysAgo(8),
    ),
    // Pushes Debt & Loan Servicing PAST its 6,000 limit, on purpose. Without
    // it no budget in the fixture is over, so the over-budget state, the red
    // bar and the negative remaining, could not be reviewed in a render or
    // caught in one. A tidy fixture where nothing ever goes wrong is the same
    // trap as the empty one: it cannot show the defect.
    //
    // Realistic rather than contrived: paying down a card in the same month as
    // two loan instalments is an ordinary thing to do, and it is the month
    // that tips somebody over.
    Transaction(
      id: 'tx_cc_payment',
      profile: ProfileEntity.personal,
      subcategory: 'Credit Card Balance Payment',
      type: TransactionType.expense,
      amount: 1500.00,
      category: 'Debt & Loan Servicing',
      accountId: 'acc_bpi',
      merchant: 'BPI Rewards Card Payment',
      date: '2026-09-12',
      createdAt: _daysAgo(6),
    ),
    Transaction(
      id: 'tx_condo_repair',
      profile: ProfileEntity.household,
      subcategory: 'Home Repairs & Maintenance',
      type: TransactionType.expense,
      amount: 3200.00,
      category: 'Housing & Rent',
      accountId: 'acc_maya',
      merchant: 'Handyman Hardware BGC',
      date: '2026-09-15',
      createdAt: _daysAgo(3),
      status: TransactionStatus.pending,
    ),
  ];

  static const List<Debt> debts = <Debt>[
    // The instalment counts, the schedule type, the settled date and the notes
    // are all from the prototype's own seed. They were dropped when this list
    // was first ported because no screen read them; the Debt screen does, and
    // a debt with no "3 of 6" on it is a phone plan that looks like a mystery
    // balance.
    Debt(
      id: 'debt_homecredit',
      person: 'Home Credit (Phone)',
      direction: DebtDirection.iOwe,
      totalAmount: 14700,
      paidAmount: 7350,
      dueDate: 'Sep 18',
      isSettled: false,
      schedule: DebtSchedule.scheduled,
      installmentCurrent: 3,
      installmentTotal: 6,
      notes: 'Monthly phone installment, auto-debit or pay via GCash',
    ),
    Debt(
      id: 'debt_bpi_loan',
      person: 'BPI Personal Loan',
      direction: DebtDirection.iOwe,
      totalAmount: 15000,
      paidAmount: 5000,
      dueDate: 'Sep 25',
      isSettled: false,
      schedule: DebtSchedule.scheduled,
      installmentCurrent: 2,
      installmentTotal: 6,
      notes: 'Gadget upgrade loan',
    ),
    Debt(
      id: 'debt_kuya_mark',
      person: 'Kuya Mark',
      direction: DebtDirection.owedToMe,
      totalAmount: 5000,
      paidAmount: 0,
      dueDate: 'Sep 30',
      isSettled: false,
      notes: 'Concert tickets advance for Olivia Rodrigo',
    ),
    Debt(
      id: 'debt_sarah',
      person: 'Sarah (Office lunch)',
      direction: DebtDirection.owedToMe,
      totalAmount: 1250,
      paidAmount: 0,
      dueDate: 'Sep 16',
      isSettled: false,
      notes: 'Hotpot dinner share at Robinson Galleria',
    ),
    Debt(
      id: 'debt_mom_settled',
      person: 'Mom',
      direction: DebtDirection.iOwe,
      totalAmount: 2000,
      paidAmount: 2000,
      isSettled: true,
      settledDate: 'Sep 3',
      notes: 'Pahiram for groceries last month, all paid',
    ),
  ];

  /// The starting category tree, from src/data/initialData.ts. The emojis are
  /// USER data: they live in the backup file and are never replaced by
  /// Salapify's own icon set.
  /// The 21 categories from src/data/categories.ts, names and all.
  ///
  /// The NAMES are load bearing, not decoration. A transaction stores its
  /// category as a STRING, the fast-log parser returns one of these strings,
  /// and the Category manager counts usage by matching them. An earlier
  /// version of this list paraphrased five of them (Health & Meds for Health
  /// & Medical, Family Support for Family Support & Remittance) and dropped
  /// Entertainment & Leisure entirely, which meant two seeded transactions
  /// were tagged with categories that did not exist and their spending was
  /// counted against nothing.
  static const List<CategoryInfo> categories = <CategoryInfo>[
    CategoryInfo(
      id: 'food',
      name: 'Food & Dining',
      emoji: '🍔',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Fast Food & Karinderya',
        'Sit-down Restaurants',
        'Coffee & Milk Tea',
        'Food Delivery (Grab/Foodpanda)',
        'Office Lunch & Snacks',
      ],
    ),
    CategoryInfo(
      id: 'groceries',
      name: 'Groceries',
      emoji: '🛒',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Supermarket (SM/Puregold/Robinsons)',
        'Wet Market (Palengke)',
        'Pantry & Staples',
        'Toiletries & Household Supplies',
      ],
    ),
    CategoryInfo(
      id: 'transport',
      name: 'Transport & Commute',
      emoji: '🛵',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Ride Hailing (Grab/Angkas/Joyride)',
        'Public Transit (Jeep/Bus/MRT/LRT)',
        'Fuel & Gas',
        'Tolls & RFID (Easytrip/Autosweep)',
        'Parking & Vehicle Maintenance',
      ],
    ),
    CategoryInfo(
      id: 'bills',
      name: 'Bills & Utilities',
      emoji: '⚡',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Electricity (Meralco)',
        'Water (Maynilad/Manila Water)',
        'Home Internet (PLDT/Converge/Globe)',
        'Mobile Postpaid/Prepaid Load',
        'Digital Subscriptions (Spotify/Netflix/iCloud)',
      ],
    ),
    CategoryInfo(
      id: 'housing',
      name: 'Housing & Rent',
      emoji: '🏠',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Apartment / House Rent',
        'Condo / HOA Dues',
        'Home Repairs & Maintenance',
        'Furniture & Appliance Repair',
      ],
    ),
    CategoryInfo(
      id: 'health',
      name: 'Health & Medical',
      emoji: '💊',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Pharmacy & Maintenance Meds',
        'Doctor Consultation & Clinic',
        'Dental Care',
        'HMO Co-pay & Diagnostics',
        'Fitness & Gym Membership',
      ],
    ),
    CategoryInfo(
      id: 'shopping',
      name: 'Shopping & Personal',
      emoji: '🛍️',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Clothing & Footwear',
        'Gadgets & Tech Accessories',
        'E-commerce (Shopee/Lazada)',
        'Personal Grooming & Salon',
      ],
    ),
    CategoryInfo(
      id: 'debt_servicing',
      name: 'Debt & Loan Servicing',
      emoji: '🤝',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Credit Card Balance Payment',
        'Personal Loan Installment',
        'Gadget Loan (Home Credit/SpayLater/LazPay)',
        'Mortgage Monthly Amortization',
        'Pag-IBIG / SSS Salary Loan Repayment',
      ],
    ),
    CategoryInfo(
      id: 'family_support',
      name: 'Family Support & Remittance',
      emoji: '❤️',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Monthly Family Allowance',
        'Parents & Sibling Support',
        'School Tuition / Baon',
        'Family Gifts & Celebrations',
      ],
    ),
    CategoryInfo(
      id: 'business_expense',
      name: 'Business & Freelance Ops',
      emoji: '💼',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Software & SaaS Subscriptions',
        'Subcontractor & Freelancer Fees',
        'Client Entertainment & Meetings',
        'Marketing & Ads (Meta/Google)',
        'Office Supplies & Shipping',
        'Professional Licenses & BIR Taxes',
      ],
    ),
    CategoryInfo(
      id: 'entertainment',
      name: 'Entertainment & Leisure',
      emoji: '🎬',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Cinema & Concerts',
        'Gaming & In-app Purchases',
        'Weekend Trips & Staycations',
        'Hobbies & Leisure',
      ],
    ),
    CategoryInfo(
      id: 'adjustments_expense',
      name: 'Adjustments & Write-offs',
      emoji: '⚖️',
      kind: CategoryKind.expense,
      subcategories: <String>[
        'Reconciliation Discrepancy Write-down',
        'Bank Service Fees & Penalties',
        'Unresolved Ledger Variance',
      ],
    ),
    CategoryInfo(
      id: 'other_expense',
      name: 'Other Expenses',
      emoji: '📦',
      kind: CategoryKind.expense,
      subcategories: <String>['Miscellaneous Expense', 'Donations & Tithes'],
    ),
    CategoryInfo(
      id: 'salary',
      name: 'Salary & Compensation',
      emoji: '💰',
      kind: CategoryKind.income,
      subcategories: <String>[
        '15th Sweldo Cutoff',
        '30th Sweldo Cutoff',
        '13th Month Pay (Tax-exempt under 90k)',
        'Overtime & Holiday Pay',
        'De Minimis Benefits & Allowance',
        'Performance Bonus',
      ],
    ),
    CategoryInfo(
      id: 'business_revenue',
      name: 'Business Revenue',
      emoji: '🏢',
      kind: CategoryKind.income,
      subcategories: <String>[
        'Client Service Retainers',
        'Product Sales Revenue',
        'Consulting Fees',
        'Project Milestone Payments',
      ],
    ),
    CategoryInfo(
      id: 'side_hustle_income',
      name: 'Side-hustle & Gig Income',
      emoji: '✨',
      kind: CategoryKind.income,
      subcategories: <String>[
        'Freelance Writing/Design/Dev',
        'Online Store / Reselling',
        'Affiliate & Content Creator Payouts',
        'Baking / Food Selling',
      ],
    ),
    CategoryInfo(
      id: 'investment_income',
      name: 'Investment & Passive Income',
      emoji: '📈',
      kind: CategoryKind.income,
      subcategories: <String>[
        'Digital Bank High-Yield Interest',
        'Pag-IBIG MP2 Dividends',
        'Stock / Mutual Fund Dividends',
        'Rental Property Income',
      ],
    ),
    CategoryInfo(
      id: 'receivables_collected',
      name: 'Receivables & Repayments',
      emoji: '💸',
      kind: CategoryKind.income,
      subcategories: <String>[
        'Pahiram Repayment Collected',
        'Split Bill Reimbursement',
        'Company Expense Reimbursement',
      ],
    ),
    CategoryInfo(
      id: 'adjustments_income',
      name: 'Adjustments & Found Cash',
      emoji: '⚖️',
      kind: CategoryKind.income,
      subcategories: <String>[
        'Reconciliation Upward Adjustment',
        'Cashback & Merchant Rebates',
        'Found Money / Windfall',
      ],
    ),
    CategoryInfo(
      id: 'other_income',
      name: 'Other Income',
      emoji: '🪙',
      kind: CategoryKind.income,
      subcategories: <String>['Gift Money / Pamasko', 'Miscellaneous Inflow'],
    ),
    CategoryInfo(
      id: 'transfer',
      name: 'Transfer',
      emoji: '🔄',
      kind: CategoryKind.both,
      subcategories: <String>[
        'Bank to E-Wallet Transfer',
        'E-Wallet to Bank Transfer',
        'ATM Cash Withdrawal',
        'Savings Allocation',
      ],
    ),
  ];

  static const List<Budget> budgets = <Budget>[
    Budget(category: 'Food & Dining', limit: 9000, emoji: '\u{1F354}'),
    Budget(category: 'Transport & Commute', limit: 3500, emoji: '\u{1F6F5}'),
    Budget(category: 'Bills & Utilities', limit: 6500, emoji: '⚡'),
    Budget(category: 'Groceries', limit: 8000, emoji: '\u{1F6D2}'),
    Budget(category: 'Shopping & Personal', limit: 4000, emoji: '\u{1F6CD}'),
    Budget(
      category: 'Business & Freelance Ops',
      limit: 5000,
      emoji: '\u{1F4BC}',
    ),
    Budget(category: 'Debt & Loan Servicing', limit: 6000, emoji: '\u{1F91D}'),
  ];

  static const List<UpcomingItem> upcoming = <UpcomingItem>[
    UpcomingItem(
      id: 'up_meralco',
      name: 'Meralco Electric Bill',
      amount: 2840.00,
      dueDate: 'Today',
      type: UpcomingItemType.bill,
    ),
    UpcomingItem(
      id: 'up_spotify',
      name: 'Spotify Premium Family',
      amount: 239.00,
      dueDate: 'Sunday',
      type: UpcomingItemType.subscription,
    ),
    UpcomingItem(
      id: 'up_homecredit',
      name: 'Home Credit Installment',
      amount: 2450.00,
      dueDate: 'Sep 18',
      type: UpcomingItemType.debt,
    ),
    UpcomingItem(
      id: 'up_payday',
      name: 'Sweldo Payday (15th Cutoff)',
      amount: 32500.00,
      dueDate: 'Monday, Sep 15',
      type: UpcomingItemType.payday,
      isIncome: true,
    ),
  ];

  static const List<Goal> goals = <Goal>[
    Goal(
      id: 'goal_emergency',
      name: 'Emergency Fund (6 Mos)',
      emoji: '\u{1F6E1}',
      targetAmount: 60000,
      currentAmount: 42500,
      targetDate: 'Dec 2026',
      monthlyTarget: 5000,
    ),
    Goal(
      id: 'goal_japan',
      name: 'Japan Autumn Trip',
      emoji: '✈',
      targetAmount: 75000,
      currentAmount: 28000,
      targetDate: 'Nov 2027',
      monthlyTarget: 4500,
    ),
    Goal(
      id: 'goal_phone',
      name: 'New Work Station Setup',
      emoji: '\u{1F4BB}',
      targetAmount: 35000,
      currentAmount: 35000,
      targetDate: 'Aug 2026',
      monthlyTarget: 0,
    ),
  ];

  /// Header badge counts. These are placeholders with a deliberate shape: the
  /// notification engine and the collaboration hub are later migration steps,
  /// and the badges exist now so the header they sit in is the real one.
  static const int unreadNotifications = 12;
  static const int memberCount = 5;

  static const PaydayCycle payday = PaydayCycle(
    cycleType: '15_30',
    lastPayday: 'Sep 1',
    nextPayday: 'Sep 15',
    daysToPayday: 4,
    expectedIncome: 32500,
  );

  static const List<BillItem> bills = <BillItem>[
    BillItem(
      id: 'bill_meralco',
      name: 'Meralco Electricity',
      amount: 2840.00,
      dueDate: '2026-09-15',
    ),
    BillItem(
      id: 'bill_water',
      name: 'Manila Water',
      amount: 480.00,
      dueDate: '2026-09-18',
    ),
    BillItem(
      id: 'bill_internet',
      name: 'Converge FiberX 1500',
      amount: 1500.00,
      dueDate: '2026-09-20',
    ),
    BillItem(
      id: 'bill_spotify',
      name: 'Spotify Family Plan',
      amount: 239.00,
      dueDate: '2026-09-14',
      isPaid: true,
    ),
    BillItem(
      id: 'bill_rent',
      name: 'Condo Unit Rental',
      amount: 14000.00,
      dueDate: '2026-09-30',
    ),
    BillItem(
      id: 'bill_insurance',
      name: 'Pru Life UK VUL Insurance',
      amount: 2500.00,
      dueDate: '2026-09-25',
    ),
    BillItem(
      id: 'bill_tuition',
      name: 'Sibling College Tuition (2nd Tranche)',
      amount: 8500.00,
      dueDate: '2026-10-05',
    ),
    BillItem(
      id: 'bill_sss',
      name: 'SSS Voluntary Contribution',
      amount: 1120.00,
      dueDate: '2026-09-30',
    ),
    BillItem(
      id: 'bill_philhealth',
      name: 'PhilHealth Contribution',
      amount: 500.00,
      dueDate: '2026-09-30',
    ),
    BillItem(
      id: 'bill_remittance',
      name: 'Nanay Monthly Padala & Groceries',
      amount: 6000.00,
      dueDate: '2026-09-16',
    ),
  ];

  /// The prototype's three plans, in full.
  ///
  /// These were three name-and-amount stubs until 2026-09-18, because Safe to
  /// Spend was the only thing reading them and an amount was all it needed.
  /// Every other field here is transcribed from src/data/initialData.ts. The
  /// three deliberately differ in shape: one with a monthly add-on rate, one
  /// genuine 0 percent promo with an extra payment against it, and one
  /// e-commerce plan at 2.95 a month, so the Installments screen can be
  /// REVIEWED rather than merely rendered.
  static const List<InstallmentPlan> installments = <InstallmentPlan>[
    InstallmentPlan(
      id: 'inst_home_credit',
      name: 'Inverter Refrigerator (Abenson)',
      provider: 'Home Credit',
      principal: 24500.00,
      interestRate: 1.5,
      interestRateType: InterestRateType.monthly,
      totalInterest: 4410.00,
      totalPayable: 28910.00,
      termMonths: 12,
      startDate: '2026-04-18',
      maturityDate: '2027-04-18',
      installmentAmount: 2409.17,
      paidInstallments: 5,
      totalInstallments: 12,
      runningBalance: 16864.19,
      principalRemaining: 14291.67,
      interestRemaining: 2572.52,
      notes: '0% downpayment promo, auto-debited on the 18th of each month',
    ),
    InstallmentPlan(
      id: 'inst_bpi_sip',
      name: 'MacBook Air M2 Work Setup',
      provider: 'BPI Special Installment Plan (SIP)',
      principal: 54990.00,
      interestRate: 0.0,
      interestRateType: InterestRateType.fixed,
      totalInterest: 0.0,
      totalPayable: 54990.00,
      termMonths: 24,
      startDate: '2025-11-25',
      maturityDate: '2027-11-25',
      installmentAmount: 2291.25,
      paidInstallments: 10,
      totalInstallments: 24,
      runningBalance: 32077.50,
      principalRemaining: 32077.50,
      interestRemaining: 0.0,
      extraPayments: <ExtraPayment>[
        ExtraPayment(
          id: 'ext_1',
          date: '2026-06-15',
          amount: 4582.50,
          note: 'Mid-year bonus prepayment',
        ),
      ],
      notes: '24-month real 0% installment on BPI Rewards Credit Card',
    ),
    InstallmentPlan(
      id: 'inst_spaylater',
      name: 'Ergonomic Desk & Chair',
      provider: 'SPayLater',
      principal: 8400.00,
      interestRate: 2.95,
      interestRateType: InterestRateType.monthly,
      totalInterest: 1486.80,
      totalPayable: 9886.80,
      termMonths: 6,
      startDate: '2026-07-05',
      maturityDate: '2027-01-05',
      installmentAmount: 1647.80,
      paidInstallments: 2,
      totalInstallments: 6,
      runningBalance: 6591.20,
      principalRemaining: 5600.00,
      interestRemaining: 991.20,
      notes: 'E-commerce installment via Shopee SPayLater',
    ),
  ];

  static const List<IncomeStream> incomeStreams = <IncomeStream>[
    IncomeStream(
      id: 'stream_salary',
      name: 'Corporate Employment Salary',
      type: IncomeStreamType.semimonthlySalary,
      expectedAmount: 32500.00,
    ),
    IncomeStream(
      id: 'stream_freelance',
      name: 'UI/UX Design Retainer (Apex Digital)',
      type: IncomeStreamType.freelance,
      expectedAmount: 18500.00,
    ),
    IncomeStream(
      id: 'stream_13th_month',
      name: '13th-Month Pay Projection',
      type: IncomeStreamType.thirteenthMonth,
      expectedAmount: 65000.00,
    ),
    IncomeStream(
      id: 'stream_remittance',
      name: 'OFW Sibling Support / Padala',
      type: IncomeStreamType.remittance,
      expectedAmount: 5000.00,
    ),
  ];

  /// The Habits tracker's rows, from src/components/HabitTrackerView.tsx,
  /// where they are hardcoded inside the component.
  static const List<HabitItem> habits = <HabitItem>[
    HabitItem(
      id: 'habit_log',
      name: 'Log every expense',
      streak: 12,
      doneToday: true,
      isDaily: true,
    ),
    HabitItem(
      id: 'habit_nospend',
      name: 'No-spend day',
      streak: 2,
      doneToday: false,
      isDaily: true,
    ),
    HabitItem(
      id: 'habit_review',
      name: 'Weekly review',
      streak: 4,
      doneToday: true,
      isDaily: false,
    ),
    HabitItem(
      id: 'habit_receipt',
      name: 'Capture receipts',
      streak: 5,
      doneToday: true,
      isDaily: true,
    ),
    HabitItem(
      id: 'habit_reconcile',
      name: 'Reconcile accounts',
      streak: 1,
      doneToday: false,
      isDaily: false,
    ),
    HabitItem(
      id: 'habit_budget',
      name: 'Budget review',
      streak: 8,
      doneToday: true,
      isDaily: false,
    ),
  ];

  /// The Subscriptions tracker's rows, from
  /// src/components/SubscriptionTrackerView.tsx.
  ///
  /// The prototype prints a hardcoded monthly total of 3,288 beside this list,
  /// and the list does not add up to that under any reading. app/ computes it
  /// from the rows instead, which is why SubscriptionItem carries monthlyCost.
  static const List<SubscriptionItem> subscriptions = <SubscriptionItem>[
    SubscriptionItem(
      id: 'sub_netflix',
      name: 'Netflix Premium',
      amount: 549,
      cycle: BillingCycle.monthly,
      nextBilling: '2026-10-05',
      state: SubscriptionState.active,
    ),
    SubscriptionItem(
      id: 'sub_spotify',
      name: 'Spotify Duo',
      amount: 239,
      cycle: BillingCycle.monthly,
      nextBilling: '2026-10-12',
      state: SubscriptionState.active,
    ),
    SubscriptionItem(
      id: 'sub_google',
      name: 'Google One 2TB',
      amount: 4790,
      cycle: BillingCycle.annual,
      nextBilling: '2027-04-15',
      state: SubscriptionState.active,
      unusedAlert: true,
    ),
    SubscriptionItem(
      id: 'sub_gym',
      name: 'Gym Membership',
      amount: 2500,
      cycle: BillingCycle.monthly,
      nextBilling: '2026-10-01',
      state: SubscriptionState.active,
      duplicateAlert: true,
    ),
    SubscriptionItem(
      id: 'sub_adobe',
      name: 'Adobe Creative Cloud',
      amount: 1549,
      cycle: BillingCycle.monthly,
      nextBilling: '2026-10-22',
      state: SubscriptionState.trial,
      trialEnds: '2026-09-22',
    ),
  ];
}
