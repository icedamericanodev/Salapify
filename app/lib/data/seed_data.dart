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
  static int _daysAgo(int days) => DateTime.now()
      .subtract(Duration(days: days))
      .millisecondsSinceEpoch;

  static const List<Account> accounts = <Account>[
    Account(
      id: 'acc_cash',
      name: 'Cash on Hand (Pitaka)',
      kind: AccountKind.cash,
      institution: 'Cash',
      balance: 1850.00,
      monogram: '₱',
      notes: 'Physical cash for jeepneys, trike, and street food',
    ),
    Account(
      id: 'acc_gcash',
      name: 'GCash Wallet',
      kind: AccountKind.gcash,
      institution: 'GCash',
      balance: 8420.50,
      monogram: 'GC',
      accountNumber: '0917-***-4821',
    ),
    Account(
      id: 'acc_maya',
      name: 'Maya Savings',
      kind: AccountKind.maya,
      institution: 'Maya',
      balance: 15300.00,
      monogram: 'MY',
      interestRate: 6.0,
    ),
    Account(
      id: 'acc_bpi',
      name: 'BPI Preferred Payroll',
      kind: AccountKind.bank,
      institution: 'BPI',
      balance: 48500.00,
      monogram: 'BPI',
    ),
    Account(
      id: 'acc_seabank',
      name: 'MariBank Digital Savings',
      kind: AccountKind.bank,
      institution: 'MariBank',
      balance: 24250.00,
      monogram: 'SB',
    ),
    Account(
      id: 'acc_ub_debit',
      name: 'UnionBank Debit Card',
      kind: AccountKind.debit,
      institution: 'UnionBank',
      balance: 12400.00,
      monogram: 'UB',
    ),
    Account(
      id: 'acc_mp2',
      name: 'Pag-IBIG MP2 Fund',
      kind: AccountKind.investment,
      institution: 'Pag-IBIG',
      balance: 65000.00,
      monogram: 'MP2',
    ),
    Account(
      id: 'acc_receivables',
      name: 'Accounts Receivable (Pahiram & Split)',
      kind: AccountKind.receivable,
      institution: 'Internal Ledger',
      balance: 6250.00,
      monogram: 'AR',
    ),
    Account(
      id: 'acc_bpi_cc',
      name: 'BPI Rewards Card',
      kind: AccountKind.credit,
      institution: 'BPI',
      balance: 4200.00,
      creditLimit: 40000.00,
      monogram: 'BPI',
    ),
    Account(
      id: 'acc_personal_loan',
      name: 'BPI Gadget Loan',
      kind: AccountKind.loan,
      institution: 'BPI',
      balance: 10000.00,
      monogram: 'LOAN',
    ),
    Account(
      id: 'acc_pagibig_mortgage',
      name: 'Pag-IBIG Housing Loan',
      kind: AccountKind.mortgage,
      institution: 'Pag-IBIG',
      balance: 385000.00,
      monogram: 'MTG',
    ),
  ];

  static List<Transaction> transactions() => <Transaction>[
        Transaction(
          id: 'tx_salary_1',
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
          type: TransactionType.expense,
          amount: 6000.00,
          category: 'Family & Remittance',
          accountId: 'acc_bpi',
          merchant: 'Nanay Monthly Padala',
          date: '2026-09-16',
          createdAt: _daysAgo(2),
        ),
        Transaction(
          id: 'tx_coffee',
          type: TransactionType.expense,
          amount: 180.00,
          category: 'Food & Dining',
          accountId: 'acc_cash',
          merchant: 'Local Kape Shop',
          date: '2026-09-18',
          createdAt: _daysAgo(0),
        ),
      ];

  static const List<Debt> debts = <Debt>[
    Debt(
      id: 'debt_homecredit',
      person: 'Home Credit (Phone)',
      direction: DebtDirection.iOwe,
      totalAmount: 14700,
      paidAmount: 7350,
      dueDate: 'Sep 18',
      isSettled: false,
    ),
    Debt(
      id: 'debt_bpi_loan',
      person: 'BPI Personal Loan',
      direction: DebtDirection.iOwe,
      totalAmount: 15000,
      paidAmount: 5000,
      dueDate: 'Sep 25',
      isSettled: false,
    ),
    Debt(
      id: 'debt_kuya_mark',
      person: 'Kuya Mark',
      direction: DebtDirection.owedToMe,
      totalAmount: 5000,
      paidAmount: 0,
      dueDate: 'Sep 30',
      isSettled: false,
    ),
    Debt(
      id: 'debt_sarah',
      person: 'Sarah (Office lunch)',
      direction: DebtDirection.owedToMe,
      totalAmount: 1250,
      paidAmount: 0,
      dueDate: 'Sep 16',
      isSettled: false,
    ),
    Debt(
      id: 'debt_mom_settled',
      person: 'Mom',
      direction: DebtDirection.iOwe,
      totalAmount: 2000,
      paidAmount: 2000,
      isSettled: true,
    ),
  ];

  static const List<Budget> budgets = <Budget>[
    Budget(category: 'Food & Dining', limit: 9000, emoji: '\u{1F354}'),
    Budget(category: 'Transport & Commute', limit: 3500, emoji: '\u{1F6F5}'),
    Budget(category: 'Bills & Utilities', limit: 6500, emoji: '⚡'),
    Budget(category: 'Groceries', limit: 8000, emoji: '\u{1F6D2}'),
    Budget(category: 'Shopping & Personal', limit: 4000, emoji: '\u{1F6CD}'),
    Budget(category: 'Business & Freelance Ops', limit: 5000, emoji: '\u{1F4BC}'),
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
    BillItem(id: 'bill_meralco', name: 'Meralco Electricity', amount: 2840.00, dueDate: '2026-09-15'),
    BillItem(id: 'bill_water', name: 'Manila Water', amount: 480.00, dueDate: '2026-09-18'),
    BillItem(id: 'bill_internet', name: 'Converge FiberX 1500', amount: 1500.00, dueDate: '2026-09-20'),
    BillItem(id: 'bill_spotify', name: 'Spotify Family Plan', amount: 239.00, dueDate: '2026-09-14', isPaid: true),
    BillItem(id: 'bill_rent', name: 'Condo Unit Rental', amount: 14000.00, dueDate: '2026-09-30'),
    BillItem(id: 'bill_insurance', name: 'Pru Life UK VUL Insurance', amount: 2500.00, dueDate: '2026-09-25'),
    BillItem(id: 'bill_tuition', name: 'Sibling College Tuition (2nd Tranche)', amount: 8500.00, dueDate: '2026-10-05'),
    BillItem(id: 'bill_sss', name: 'SSS Voluntary Contribution', amount: 1120.00, dueDate: '2026-09-30'),
    BillItem(id: 'bill_philhealth', name: 'PhilHealth Contribution', amount: 500.00, dueDate: '2026-09-30'),
    BillItem(id: 'bill_remittance', name: 'Nanay Monthly Padala & Groceries', amount: 6000.00, dueDate: '2026-09-16'),
  ];

  static const List<InstallmentPlan> installments = <InstallmentPlan>[
    InstallmentPlan(id: 'inst_home_credit', name: 'Inverter Refrigerator (Abenson)', installmentAmount: 2409.17),
    InstallmentPlan(id: 'inst_bpi_sip', name: 'MacBook Air M2 Work Setup', installmentAmount: 2291.25),
    InstallmentPlan(id: 'inst_spaylater', name: 'Ergonomic Desk & Chair', installmentAmount: 1647.80),
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
}
