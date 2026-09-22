/// What Pan knows about Salapify itself.
///
/// Founder direction, 2026-09-19: "Make sure it know every features within the
/// app and how the data and transaction works as it flow in the entire app."
///
/// So this is not marketing copy and it is not a help centre. It is a written
/// description of what each feature ACTUALLY does in this build, kept beside
/// the code it describes so that a wrong entry is a visible wrong entry rather
/// than a plausible sentence nobody checks.
///
/// ## The rule that governs every string in this file
///
/// It describes what Salapify does. It never tells somebody what to do with
/// their money, never names a bank, a fund or a product, and never quotes a
/// rate or a return. Those are enforced by `pan_content_test.dart` over this
/// file's own text, because a content rule with no test is a rule that lasts
/// until the next person adds an entry.
library;

/// One thing Pan can explain, and where to find it.
class PanFeature {
  const PanFeature({
    required this.id,
    required this.name,
    required this.where,
    required this.what,
    required this.keywords,
  });

  final String id;

  /// What a person would call it.
  final String name;

  /// How to get there, in taps.
  final String where;

  /// What it does, and where its numbers come from.
  final String what;

  /// Words somebody might use when asking about it, including the Filipino
  /// ones. Pan UNDERSTANDS Tagalog and answers in English, which is the
  /// standing rule for the whole app.
  final List<String> keywords;
}

const List<PanFeature> panFeatures = <PanFeature>[
  PanFeature(
    id: 'log',
    name: 'Logging an entry',
    where: 'The big button in the middle of the bottom bar.',
    what:
        'You record money going out, money coming in, or a transfer between '
        'your own accounts. An expense or income needs an amount, a category '
        'and which account it touched. The amount box does arithmetic, so you '
        'can type 250+180 and it works it out.',
    keywords: <String>[
      'log',
      'record',
      'add expense',
      'add entry',
      'gastos',
      'new transaction',
      'enter',
      'input',
      'how do i add',
    ],
  ),
  PanFeature(
    id: 'flow',
    name: 'What happens to an entry after you save it',
    where: 'Nothing to tap. This is the path every entry takes.',
    what:
        'One entry moves five things at once, which is why the screens always '
        'agree. The account balance changes by the amount straight away. The '
        'entry joins the Activity list, where you can find, edit or delete it '
        'later. Its category adds to the budget limit for that category on '
        'Plan. It counts toward the month totals on Reports. And because your '
        'spendable cash changed, Safe to Spend on Home is recomputed. A '
        'transfer is the one that moves two accounts and changes no total, '
        'because nothing entered or left your money as a whole.',
    keywords: <String>[
      'flow',
      'what happens when',
      'how does it work',
      'where does it go',
      'after i log',
      'connect',
      'affect',
      'update',
    ],
  ),
  PanFeature(
    id: 'safe',
    name: 'Safe to Spend',
    where: 'The big figure at the top of Home. Tap it for the breakdown.',
    what:
        'It starts from cash you can actually reach today, then sets aside '
        'what is already spoken for: your unpaid bills, your payment plan '
        'instalments, a minimum against what you owe, and a buffer. What is '
        'left is split across the days until your next payday. Conservative '
        'reserves more than Optimistic. It is arithmetic on your own figures, '
        'not a prediction.',
    keywords: <String>[
      'safe to spend',
      'how much can i spend',
      'spendable',
      'budget left',
      'pwede ko gastusin',
      'available',
    ],
  ),
  PanFeature(
    id: 'accounts',
    name: 'Accounts',
    where: 'The wallet tab.',
    what:
        'Every place your money sits: cash, bank, e-wallets, cards, loans and '
        'investments. A balance is a stored figure that moves when you log '
        'something, not a total worked out from your entries, which is why a '
        'reconciliation check exists. Cards and loans hold what you OWE as a '
        'negative number, so they lower your net worth rather than raising it.',
    keywords: <String>[
      'account',
      'balance',
      'wallet',
      'bank',
      'card',
      'pera ko',
      'magkano',
      'how much do i have',
    ],
  ),
  PanFeature(
    id: 'reconcile',
    name: 'Reconciliation check',
    where: 'Accounts, then the check on an account.',
    what:
        'You type what the account really says, and Salapify shows the '
        'difference against what it holds. Balances move entry by entry, so a '
        'forgotten fee or a missed entry makes them drift apart over months. '
        'The check is how you find the gap, and nothing is changed until you '
        'say so.',
    keywords: <String>[
      'reconcile',
      'reconciliation',
      'check balance',
      'does not match',
      'mali',
      'wrong balance',
      'drift',
    ],
  ),
  PanFeature(
    id: 'debt',
    name: 'Debt, both directions',
    where: 'The Debt register, from Home or the Plan tab.',
    what:
        'Salapify tracks what you owe AND what is owed to you, because a '
        'utang between friends goes both ways. Recording a payment against '
        'something you owe lowers the debt and lowers the account it came '
        'from, so your net worth does not move: an asset falls and a '
        'liability falls by the same amount. Money owed to you never chases '
        'the other person on your behalf.',
    keywords: <String>[
      'debt',
      'utang',
      'owe',
      'owed',
      'borrow',
      'lend',
      'pay back',
      'hulog',
    ],
  ),
  PanFeature(
    id: 'plans',
    name: 'Payment plans',
    where: 'The Plan tab, under payment plans.',
    what:
        'An instalment arrangement you already have: what you pay each time, '
        'how many are left, and what is still outstanding. Salapify shows the '
        'schedule and the total cost from the figures you entered. It does '
        'not arrange, offer or refer any of it.',
    keywords: <String>[
      'installment',
      'instalment',
      'payment plan',
      'hulugan',
      'monthly payment',
      'plan',
    ],
  ),
  PanFeature(
    id: 'budgets',
    name: 'Budget limits',
    where: 'The Plan tab.',
    what:
        'A monthly limit per category. Logging an expense in that category '
        'fills the bar. Salapify never blocks a purchase and never moves '
        'money: the limit is a line you drew, and the bar tells you where you '
        'are against it.',
    keywords: <String>[
      'budget',
      'limit',
      'category',
      'overspend',
      'lampas',
      'cap',
    ],
  ),
  PanFeature(
    id: 'goals',
    name: 'Goals',
    where: 'The targets tab.',
    what:
        'A thing you are saving toward, with an amount and a date. Salapify '
        'works out what you would need to set aside each payday to get there '
        'from where you are now. Adding to a goal records the contribution '
        'against it.',
    keywords: <String>[
      'goal',
      'saving',
      'ipon',
      'target',
      'save for',
      // 'emergency fund' used to be here and was removed on purpose. The
      // Academy ships a whole course on what one is and how big it should
      // be, and mapping the phrase to the Goals screen answered "what is an
      // emergency fund" with a description of a text field.
    ],
  ),
  PanFeature(
    id: 'bills',
    name: 'Bills and Coming up',
    where: 'Home, the Coming up card.',
    what:
        'What is due soon and how much. An unpaid bill is held back from Safe '
        'to Spend on purpose, so the figure you see is money that is really '
        'yours to spend rather than money the electricity company is about to '
        'take.',
    keywords: <String>[
      'bill',
      'due',
      'bayarin',
      'coming up',
      'upcoming',
      'rent',
      'electricity',
    ],
  ),
  PanFeature(
    id: 'reminders',
    name: 'Reminders',
    where: 'The bell in the header on Home.',
    what:
        'Four rules you control: a nudge if nothing is logged by an evening '
        'hour you choose, and a warning ahead of a payment you owe, a bill, '
        'or a subscription renewal. They collect in the tray, and if you '
        'switch phone reminders on they also arrive while Salapify is closed. '
        'Something overdue keeps being mentioned rather than going quiet.',
    keywords: <String>[
      'reminder',
      'notification',
      'alert',
      'bell',
      'paalala',
      'notify',
      'buzz',
    ],
  ),
  PanFeature(
    id: 'reports',
    name: 'Reports',
    where: 'The chart tab.',
    what:
        'Where the month went: what came in, what went out, which categories '
        'took the most, and how your net worth is made up. Transfers are '
        'excluded on purpose, because moving your own money between your own '
        'accounts is not income and not spending.',
    keywords: <String>[
      'report',
      'chart',
      'graph',
      'where did my money go',
      'saan napunta',
      'summary',
      'net worth',
    ],
  ),
  PanFeature(
    id: 'activity',
    name: 'Activity',
    where: 'The book tab.',
    what:
        'Every entry, newest first, with search and filters. Tap one to see '
        'it in full, edit it, or delete it. This is where you go when a '
        'balance moved and you want to know which entry did it.',
    keywords: <String>[
      'activity',
      'history',
      'entries',
      'transactions',
      'list',
      'search',
      'find entry',
    ],
  ),
  PanFeature(
    id: 'toolkit',
    name: 'The Philippine toolkit',
    where: 'The sparkle button in the header on Home.',
    what:
        'Four tools: a notepad that adds up as you type, an impulse check '
        'that turns a purchase into hours of your own time, a treats tracker, '
        'and a currency converter. The converter is the one part of Salapify '
        'that asks the internet for anything, and only for today\'s rates.',
    keywords: <String>[
      'toolkit',
      'calculator',
      'notes',
      'impulse',
      'treat',
      'currency',
      'exchange rate',
      'dollar',
      'fx',
    ],
  ),
  PanFeature(
    id: 'tax',
    name: 'Tax and take-home',
    where: 'Settings, or the Plan tab calculators.',
    what:
        'Estimates of take-home pay, 13th month pay, and the freelancer '
        'options, worked out from the figures you type in. They are estimates '
        'to plan with. The BIR, your employer and the agencies each produce '
        'their own, and theirs is the one that counts.',
    keywords: <String>[
      'tax',
      'buwis',
      'take home',
      'sweldo',
      'salary',
      'net pay',
      '13th month',
      'bir',
      'sss',
      'philhealth',
      'pag-ibig',
    ],
  ),
  PanFeature(
    id: 'backup',
    name: 'Backup and restore',
    where: 'Settings, under Your data.',
    what:
        'Export writes everything on this phone into one file you keep. '
        'Restore replaces what is here with a backup file, and Salapify saves '
        'a copy of the current ledger first so you can undo it. The file is '
        'plain readable text, not encrypted, and it holds your balances and '
        'the names in your debt records.',
    keywords: <String>[
      'backup',
      // Two words, because "how do I back up my data" contains no single
      // word this feature owns and was answered by the privacy card instead,
      // which is a true sentence about the wrong thing.
      'back up',
      'restore',
      'export',
      'import',
      'save file',
      'new phone',
      'transfer to',
      'lost phone',
    ],
  ),
  PanFeature(
    id: 'privacy',
    name: 'Where your data lives',
    where: 'Settings, or the badge beside the Salapify name.',
    what:
        'Everything you type stays in one file in Salapify\'s own private '
        'storage on this phone. There is no account, no server of ours, no '
        'analytics and no ads, and the automatic copy to your Google account '
        'is switched off. One request leaves, and only if you open the '
        'currency converter: it asks a public service for today\'s rates and '
        'sends a currency code, nothing else.',
    keywords: <String>[
      'privacy',
      'private',
      'data',
      'secure',
      'offline',
      'internet',
      'cloud',
      'server',
      'who can see',
      'safe',
    ],
  ),
  PanFeature(
    id: 'delete',
    name: 'Deleting everything',
    where: 'Settings, under Privacy.',
    what:
        'Erases your ledger, both spare copies Salapify keeps, and the saved '
        'exchange rates. There is no undo, because the copies that would '
        'normally provide one are part of what it removes. The sample data '
        'does not come back afterwards.',
    keywords: <String>[
      'delete',
      'erase',
      'wipe',
      'start over',
      'burahin',
      'clear everything',
      'reset',
    ],
  ),
  PanFeature(
    id: 'sample',
    name: 'The sample data',
    where: 'Settings, under Your data.',
    what:
        'Salapify starts with example entries so the screens are not blank on '
        'a new phone. They are marked wherever a figure is read, and you can '
        'remove them in one action. Anything you have entered yourself is '
        'never touched by that.',
    keywords: <String>[
      'sample',
      'demo',
      'example',
      'fake',
      'not mine',
      'test data',
    ],
  ),
];

/// A question Pan can answer, offered as a starting point.
///
/// Short, in a person's own words, and every one of them is genuinely
/// answerable: an example chip that produces "I do not know" is worse than no
/// chip at all.
const List<String> panStarters = <String>[
  'How much do I have right now?',
  'What is safe to spend?',
  'Where did my money go this month?',
  'Who do I owe?',
  'What is due soon?',
  'What happens when I log an expense?',
  'Is my data private?',
  'How do I back up my records?',
];
