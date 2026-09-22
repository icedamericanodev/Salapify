// The core data model, ported from the prototype's src/types.ts.
// Only the types the app actually reads today are here. The rest arrive with
// the tabs that need them, so nothing sits unused.

import '../core/money/currencies.dart';

export '../core/money/currencies.dart' show CurrencyCode;

enum TransactionType { expense, income, transfer }

enum AccountKind {
  cash,
  bank,
  gcash,
  maya,
  debit,
  credit,
  loan,
  mortgage,
  investment,
  receivable,
}

/// The kinds that count as spendable cash. Credit limits and investments are
/// deliberately NOT here: money you can borrow is not money you have.
const Set<AccountKind> liquidKinds = <AccountKind>{
  AccountKind.cash,
  AccountKind.gcash,
  AccountKind.maya,
  AccountKind.bank,
  AccountKind.debit,
};

enum DebtDirection { iOwe, owedToMe }

/// Which side of a person's life a row belongs to. The prototype INFERS this
/// from the item's name rather than storing it, so the inference lives in one
/// place (see FinancialState.profileOf) and this enum is only the vocabulary.
enum ProfileEntity { personal, household, business, sideHustle }

enum DecisionScenario { conservative, optimistic }

/// The seven income shapes the prototype recognises. The names map one to one
/// onto src/types.ts, so a value can never silently mean something else.
enum IncomeStreamType {
  weeklyIncome,
  semimonthlySalary,
  monthlySalary,
  freelance,
  irregular,
  thirteenthMonth,
  remittance,
}

enum UpcomingItemType {
  bill,
  subscription,
  payday,
  debt,
  remittance,
  rent,
  insurance,
  tuition,
  government,
}

/// The scheme printed on a physical card. `none` is a real answer, not a
/// missing one: a passbook savings account and a virtual e-wallet card both
/// legitimately have no network logo.
enum CardNetwork { none, visa, mastercard, amex, jcb }

/// How fancy the plastic is. Purely cosmetic, and it is the user's own
/// statement about their card rather than anything Salapify computes.
enum CardTier { regular, gold, platinum, black, custom }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.kind,
    required this.institution,
    required this.balance,
    required this.monogram,
    this.currency = CurrencyCode.php,
    this.profile,
    this.creditLimit,
    this.interestRate,
    this.accountNumber,
    this.dueDate,
    this.statementDate,
    this.cardNetwork = CardNetwork.none,
    this.cardTier = CardTier.regular,
    this.notes,
    this.isSample = false,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String id;
  final String name;
  final AccountKind kind;
  final String institution;
  final double balance;
  final String monogram;

  /// What the balance is DENOMINATED in.
  ///
  /// Defaults to pesos, which is what every account in the fixture is, so
  /// nothing in the app changes by this field existing. It is here because
  /// the prototype's Accounts screen shows a foreign balance in its own
  /// currency with the peso equivalent underneath, and an OFW with a
  /// Singapore payroll account is exactly who that was drawn for. Anything
  /// that SUMS balances has to run them through convertToPhp first, or it
  /// adds dollars to pesos and reports the total as pesos.
  final CurrencyCode currency;

  /// Which entity this account belongs to, from src/types.ts.
  ///
  /// NULLABLE on purpose, and the null is meaningful rather than lazy. Reports
  /// filters with `!a.profile || a.profile === activeProfile`, so an account
  /// with no profile appears under EVERY entity. An account that belongs
  /// nowhere in particular belongs everywhere, which is the right answer for
  /// a wallet somebody has not classified yet.
  final ProfileEntity? profile;
  final double? creditLimit;
  final double? interestRate;
  final String? accountNumber;

  /// When the payment is due, as the user typed it ("Oct 3", "15th"). Free
  /// text on purpose, matching the prototype: a card that bills on the last
  /// working day of the month has no clean date to store, and asking somebody
  /// to pick one is how a reminder ends up wrong.
  final String? dueDate;
  final String? statementDate;
  final CardNetwork cardNetwork;
  final CardTier cardTier;
  final String? notes;

  bool get isLiquid => liquidKinds.contains(kind);

  /// The peso value of this balance, for anything that adds accounts up.
  double get balanceInPhp => convertToPhp(balance, currency);

  /// True when this balance is NOT in pesos, so the screen knows to show the
  /// conversion and label it as an estimate.
  bool get isForeign => currency != CurrencyCode.php;

  /// Only the balance ever changes on a logged entry, so this takes only that.
  /// Widening it later is easy; a general copyWith invites a caller to change
  /// something a ledger entry has no business changing.
  ///
  /// Editing an account is deliberately NOT done through here. The account
  /// sheet builds a whole new Account with the same id, so every field a
  /// person can change is visible in one place and nothing survives by
  /// accident.
  /// [isSample] is carried through DELIBERATELY.
  ///
  /// This is the copy the ledger makes when a balance moves, so logging a
  /// 250 peso expense against a demo account must not turn that whole demo
  /// account into the user's own. The sweep handles that case properly
  /// instead: an account a real entry points at is KEPT, with its seeded
  /// opening balance subtracted, rather than deleted underneath the entry.
  Account copyWith({double? balance, bool? isSample}) => Account(
    id: id,
    name: name,
    kind: kind,
    institution: institution,
    balance: balance ?? this.balance,
    monogram: monogram,
    currency: currency,
    profile: profile,
    creditLimit: creditLimit,
    interestRate: interestRate,
    accountNumber: accountNumber,
    dueDate: dueDate,
    statementDate: statementDate,
    cardNetwork: cardNetwork,
    cardTier: cardTier,
    notes: notes,
    isSample: isSample ?? this.isSample,
  );
}

/// What the ledger believes about an entry, from src/types.ts.
///
/// Only two of these change a number: `excluded` and `duplicate` are left OUT
/// of the in and out totals, everything else counts. That is the prototype's
/// rule and the reason this enum exists rather than a bool.
enum TransactionStatus {
  pending,
  confirmed,
  reconciled,
  duplicate,
  corrected,
  excluded,
}

class Transaction {
  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.accountId,
    required this.date,
    required this.createdAt,
    this.subcategory,
    this.toAccountId,
    this.merchant,
    this.note,
    this.person,
    this.tags = const <String>[],
    this.status = TransactionStatus.confirmed,
    this.profile,
    this.isSample = false,
    this.isTaxDeductible = false,
    this.taxTinOrRef,
    this.attachmentPath,
    this.attachmentName,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String id;
  final TransactionType type;
  final double amount;
  final String category;
  final String accountId;

  /// ISO date, YYYY-MM-DD.
  final String date;

  /// Milliseconds since epoch, the way the prototype stores it.
  final int createdAt;
  final String? subcategory;
  final String? toAccountId;
  final String? merchant;
  final String? note;

  /// Who the entry involves: Mom, Kuya Mark, a client, a vendor.
  final String? person;
  final List<String> tags;

  /// Defaults to confirmed, matching the prototype, which reads `t.status ||
  /// 'confirmed'` everywhere rather than storing it on every row.
  final TransactionStatus status;

  /// Stored here when the entry says so. Where it is null the app INFERS it
  /// from the name, the way the prototype does; see FinancialState.profileOf.
  final ProfileEntity? profile;

  /// Marked by the person as a business or freelance expense they intend to
  /// claim against income tax.
  ///
  /// A LABEL, AND ONLY A LABEL. Nothing in Salapify's arithmetic reads it:
  /// it does not reduce taxable income anywhere, it does not feed the tax
  /// calculator, and it changes no total on any screen. It exists so that
  /// somebody keeping books can find these rows again at filing time, which
  /// is the job they are actually doing.
  ///
  /// That restraint is deliberate rather than unfinished. Whether a given
  /// peso is deductible turns on the taxpayer's regime, on substantiation,
  /// and on rules this app does not model, so an app that quietly subtracted
  /// these from a tax figure would be filing somebody's return for them. The
  /// 8 percent election alone makes that dangerous: under it there are no
  /// itemised deductions at all, so every row marked here would be
  /// deductible in Salapify and not deductible at the BIR.
  final bool isTaxDeductible;

  /// The official receipt or sales invoice number, or the supplier's TIN.
  ///
  /// Free text, because that is what is printed on the paper: an OR number,
  /// an SI number, a TIN with or without its branch code. Validating a shape
  /// here would reject real receipts, and a receipt Salapify refuses to
  /// record is worse than one it records untidily.
  final String? taxTinOrRef;

  /// Where the receipt image lives ON THIS PHONE, relative to the app's own
  /// documents directory. Never a URL.
  ///
  /// NAMED `attachmentPath`, NOT `attachmentUrl`, and the rename is load
  /// bearing rather than a style preference. The prototype's field is a URL
  /// and its seed data fills it with `https://images.unsplash.com/...`, so
  /// three sample rows would have the app fetching images off the internet.
  /// Salapify's header badge says "On this phone" and its privacy receipt
  /// names the single outbound request the app makes by name. A field typed
  /// as a URL invites the next person to put one in it, and the guard here
  /// is the name: a path is not a URL, so the wrong thing no longer fits.
  /// `transaction_attachment_test.dart` fails the build on a stored value
  /// that looks like one.
  ///
  /// A PATH, NOT BASE64, which is the other half. The prototype stores the
  /// whole image inline as a data URL. Salapify keeps its ledger in ONE file
  /// written atomically with a previous generation kept, so inlining photos
  /// would rewrite every megabyte of every receipt on every save, twice, and
  /// a person with twenty receipts would be writing well over a hundred
  /// megabytes each time they logged a coffee.
  final String? attachmentPath;

  /// What the file was called when it was attached, for showing in a list.
  final String? attachmentName;

  bool get hasAttachment => attachmentPath != null;

  /// Left out of the in and out totals. The two states that mean "this is not
  /// really money that moved".
  bool get countsTowardTotals =>
      status != TransactionStatus.excluded &&
      status != TransactionStatus.duplicate;

  /// The same entry with a different status on it.
  ///
  /// STATUS ONLY, deliberately narrow. Marking something a duplicate changes
  /// what it MEANS to every total without changing a peso of it, and that is
  /// the only correction Salapify offers on a logged entry today. A general
  /// copyWith here would invite a caller to quietly change an amount, which is
  /// the one thing a ledger must never let anybody do without a trace.
  Transaction withStatus(TransactionStatus next) => Transaction(
    id: id,
    type: type,
    amount: amount,
    category: category,
    accountId: accountId,
    date: date,
    createdAt: createdAt,
    subcategory: subcategory,
    toAccountId: toAccountId,
    merchant: merchant,
    note: note,
    person: person,
    tags: tags,
    status: next,
    profile: profile,
    // Preserved: marking a sample entry excluded from a reconciliation is
    // housekeeping on Salapify's own demo row, not the person adopting it.
    isSample: isSample,
    isTaxDeductible: isTaxDeductible,
    taxTinOrRef: taxTinOrRef,
    attachmentPath: attachmentPath,
    attachmentName: attachmentName,
  );

  /// The same entry with its tax marking and receipt changed, and NOTHING
  /// else.
  ///
  /// A SECOND NARROW COPIER RATHER THAN A GENERAL `copyWith`, for the reason
  /// `withStatus` above already gives: a general one invites a caller to
  /// quietly change an amount, which is the single thing a ledger must never
  /// allow without a trace. Two narrow methods cost a few lines each and
  /// make the dangerous edit impossible to write by accident.
  ///
  /// Every parameter is a sentinel-free nullable, so passing nothing keeps
  /// what is there. Clearing a receipt is [withoutAttachment], because
  /// `attachmentPath: null` is indistinguishable from "leave it alone" and a
  /// person who taps Remove has to be able to actually remove it.
  Transaction withTaxDetails({
    bool? isTaxDeductible,
    String? taxTinOrRef,
    String? attachmentPath,
    String? attachmentName,
  }) => Transaction(
    id: id,
    type: type,
    amount: amount,
    category: category,
    accountId: accountId,
    date: date,
    createdAt: createdAt,
    subcategory: subcategory,
    toAccountId: toAccountId,
    merchant: merchant,
    note: note,
    person: person,
    tags: tags,
    status: status,
    profile: profile,
    isSample: isSample,
    isTaxDeductible: isTaxDeductible ?? this.isTaxDeductible,
    taxTinOrRef: taxTinOrRef ?? this.taxTinOrRef,
    attachmentPath: attachmentPath ?? this.attachmentPath,
    attachmentName: attachmentName ?? this.attachmentName,
  );

  /// The same entry with its receipt removed.
  ///
  /// Separate from [withTaxDetails] because null cannot mean two things at
  /// once. It does NOT clear the tax marking or the reference: somebody who
  /// deletes a blurry photo has not stopped claiming the expense, and
  /// silently unticking it would lose a deliberate decision they made.
  Transaction withoutAttachment() => Transaction(
    id: id,
    type: type,
    amount: amount,
    category: category,
    accountId: accountId,
    date: date,
    createdAt: createdAt,
    subcategory: subcategory,
    toAccountId: toAccountId,
    merchant: merchant,
    note: note,
    person: person,
    tags: tags,
    status: status,
    profile: profile,
    isSample: isSample,
    isTaxDeductible: isTaxDeductible,
    taxTinOrRef: taxTinOrRef,
  );
}

/// Whether a debt has a schedule or is paid whenever there is money.
///
/// This is not decoration. A scheduled debt has a next payment somebody can
/// miss; a flexible one, the pahiram from a sibling, does not, and showing it
/// a due date it was never going to keep turns a favour into a deadline.
enum DebtSchedule { scheduled, flexible }

class Debt {
  const Debt({
    required this.id,
    required this.person,
    required this.direction,
    required this.totalAmount,
    required this.paidAmount,
    required this.isSettled,
    this.dueDate,
    this.schedule = DebtSchedule.flexible,
    this.installmentCurrent,
    this.installmentTotal,
    this.settledDate,
    this.notes,
    this.isSample = false,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String id;
  final String person;
  final DebtDirection direction;
  final double totalAmount;
  final double paidAmount;
  final bool isSettled;
  final String? dueDate;
  final DebtSchedule schedule;

  /// Which payment this is, of how many. Null on a flexible debt, which has
  /// no instalments to count.
  final int? installmentCurrent;
  final int? installmentTotal;

  /// The day it was cleared, as an ISO date. Only set once [isSettled].
  final String? settledDate;
  final String? notes;

  double get remaining => (totalAmount - paidAmount).clamp(0, double.infinity);

  /// How far through it is, from 0 to 1. Clamped, because an overpayment
  /// would otherwise draw a bar past the end of its own track.
  double get progress =>
      totalAmount <= 0 ? 0 : (paidAmount / totalAmount).clamp(0.0, 1.0);

  /// [isSample] is NOT carried through, and that is the point.
  ///
  /// This copy is made when a payment is recorded against a debt. Paying a
  /// demo debt with real money makes it the person's own debt, so it must
  /// survive the sample sweep rather than being deleted with the payment
  /// history pointing at it. Letting the field default to false here is what
  /// adopts it, with no extra rule anywhere.
  Debt copyWith({
    double? paidAmount,
    bool? isSettled,
    String? settledDate,
    int? installmentCurrent,
    bool clearSettledDate = false,
  }) => Debt(
    id: id,
    person: person,
    direction: direction,
    totalAmount: totalAmount,
    paidAmount: paidAmount ?? this.paidAmount,
    isSettled: isSettled ?? this.isSettled,
    dueDate: dueDate,
    schedule: schedule,
    installmentCurrent: installmentCurrent ?? this.installmentCurrent,
    installmentTotal: installmentTotal,
    settledDate: clearSettledDate ? null : (settledDate ?? this.settledDate),
    notes: notes,
  );
}

/// Which side of the ledger a category is for.
enum CategoryKind { expense, income, both }

class CategoryInfo {
  const CategoryInfo({
    required this.id,
    required this.name,
    required this.emoji,
    required this.subcategories,
    this.kind = CategoryKind.expense,
    this.isCustom = false,
  });

  final String id;
  final String name;

  /// User-facing emoji. Deliberately NOT a Salapify icon: category icons are
  /// the user's own choice and live in their backup file.
  final String emoji;
  final List<String> subcategories;
  final CategoryKind kind;
  final bool isCustom;
}

class Budget {
  const Budget({
    required this.category,
    required this.limit,
    required this.emoji,
    this.isSample = false,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String category;
  final double limit;
  final String emoji;
}

class Goal {
  const Goal({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.monthlyTarget,
    this.isSample = false,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String id;
  final String name;
  final String emoji;
  final double targetAmount;
  final double currentAmount;
  final String targetDate;
  final double monthlyTarget;
}

class UpcomingItem {
  const UpcomingItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.type,
    this.isIncome = false,
    this.isPaid = false,
    this.category,
    this.isSample = false,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String id;
  final String name;
  final double amount;

  /// A human label such as "Today", "Sunday" or "Sep 18", exactly as the
  /// prototype stores it.
  final String dueDate;
  final UpcomingItemType type;
  final bool isIncome;
  final bool isPaid;

  /// Feeds the profile inference alongside the name.
  final String? category;

  /// Payday counts as income even when the flag is not set, which is the rule
  /// the prototype applies everywhere it splits inflow from outflow.
  bool get countsAsIncome => isIncome || type == UpcomingItemType.payday;
}

class PaydayCycle {
  const PaydayCycle({
    required this.cycleType,
    required this.lastPayday,
    required this.nextPayday,
    required this.daysToPayday,
    required this.expectedIncome,
    this.paydayDays = const <int>[],
  });

  final String cycleType;
  final String lastPayday;
  final String nextPayday;
  final int daysToPayday;
  final double expectedIncome;

  /// The RULE: which days of the month the money lands on.
  ///
  /// This is the only field here that does not go stale, and it is why it
  /// was added. Every other one is a snapshot of a moment: `daysToPayday` is
  /// a countdown, and `nextPayday` and `lastPayday` are labels for two dates
  /// that move. Stored on their own they were frozen the instant they were
  /// written, which `json_codec.dart` already recorded as a defect: the
  /// cycle "would have said the same in December, because nothing ever
  /// recomputed or stored it".
  ///
  /// `[15, 30]` is the usual Philippine sweldo and `[10, 25]` is just as
  /// real. Founder direction, 2026-09-20: "give them options since it
  /// differs per company." One entry means paid once a month.
  ///
  /// EMPTY IS NOT A DEFAULT, it is a different state: a cycle from before
  /// this field existed, or one restored from an older backup. Those keep
  /// showing exactly what they stored, frozen as they always were, rather
  /// than being guessed at. `FinancialState.payday` refreshes the countdown
  /// only when there is a rule here to refresh it from.
  final List<int> paydayDays;

  /// True when the countdown can be worked out fresh rather than recalled.
  bool get hasRule => paydayDays.isNotEmpty;

  /// What a ledger with no payday set looks like.
  ///
  /// NOT the seed's cycle, and the difference is the whole point. Until this
  /// existed, the app read a compile time constant, so somebody who installed
  /// it today was told they had four days to a payday on 15 September and an
  /// income of 32,500 pesos, none of which was theirs. The empty answer is
  /// "we do not know yet", and the screens say that rather than filling it in.
  ///
  /// expectedIncome of zero matters: the engine only falls back to it when it
  /// is ABOVE zero, so an unset cycle invents no inflow.
  static const PaydayCycle unset = PaydayCycle(
    cycleType: '15_30',
    lastPayday: '',
    nextPayday: '',
    daysToPayday: 0,
    expectedIncome: 0,
  );

  /// True when nobody has told Salapify when they get paid.
  bool get isSet => daysToPayday > 0 && nextPayday.isNotEmpty;

  PaydayCycle copyWith({
    String? cycleType,
    String? lastPayday,
    String? nextPayday,
    int? daysToPayday,
    double? expectedIncome,
    List<int>? paydayDays,
  }) => PaydayCycle(
    cycleType: cycleType ?? this.cycleType,
    lastPayday: lastPayday ?? this.lastPayday,
    nextPayday: nextPayday ?? this.nextPayday,
    daysToPayday: daysToPayday ?? this.daysToPayday,
    expectedIncome: expectedIncome ?? this.expectedIncome,
    paydayDays: paydayDays ?? this.paydayDays,
  );
}

class BillItem {
  const BillItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    this.isPaid = false,
    this.isSample = false,
  });

  final String id;
  final String name;
  final double amount;
  final String dueDate;
  final bool isPaid;

  /// See Account.isSample. Bills carry it for the same reason and with more
  /// urgency: demo bills were reserving 41,184 pesos of a real person's money.
  final bool isSample;
}

/// The four things Salapify will remind somebody about, ported from the
/// prototype's `ReminderType`. The wire names in json_codec.dart are the
/// prototype's own, so a backup written by either app reads in the other.
enum ReminderKind { dailyExpense, paymentDue, billDue, subscription }

/// One reminder that has actually been raised, sitting in the tray.
///
/// The [id] IS the dedupe tag, deliberately. The engine builds a tag from what
/// a reminder is about and the day it is about it, and storing it as the id
/// means there is exactly one thing to compare against instead of two that can
/// drift apart. Whether a reminder has been seen before is then the same
/// question as whether the tray already holds it.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final ReminderKind kind;
  final String title;
  final String body;

  /// Milliseconds since the epoch, so "2h ago" can be worked out later.
  final int createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );
}

/// How a provider quotes the rate. The same number means wildly different
/// money depending which of these it is: 1.5 a MONTH is 18 a year.
enum InterestRateType { annual, monthly, daily, fixed }

enum PaymentFrequency { monthly, semimonthly, biweekly, weekly }

/// One extra payment somebody made on top of the schedule.
class ExtraPayment {
  const ExtraPayment({
    required this.id,
    required this.date,
    required this.amount,
    this.note,
  });

  final String id;
  final String date;
  final double amount;
  final String? note;
}

/// A formal instalment plan: a phone on Home Credit, a laptop on a bank's
/// special instalment plan, a desk on SPayLater.
///
/// Distinct from a Debt, and the distinction matters. A Debt is money owed to
/// a person or a lender with a running balance. An InstallmentPlan is a
/// CONTRACT: fixed term, fixed cycle, a maturity date, and a rate that was
/// agreed at the start and does not move. That is why it carries its own
/// interest split rather than deriving one.
///
/// This class was a four field stub until 2026-09-18, holding a name and an
/// amount because that was all Safe to Spend needed. The coverage audit did
/// not catch it: it compared RECORD COUNTS, three against three, and three
/// stubs count the same as three plans.
class InstallmentPlan {
  const InstallmentPlan({
    required this.id,
    required this.name,
    required this.provider,
    required this.principal,
    required this.interestRate,
    required this.interestRateType,
    required this.totalInterest,
    required this.totalPayable,
    required this.termMonths,
    required this.installmentAmount,
    required this.paidInstallments,
    required this.totalInstallments,
    required this.runningBalance,
    required this.principalRemaining,
    required this.interestRemaining,
    required this.startDate,
    required this.maturityDate,
    this.paymentFrequency = PaymentFrequency.monthly,
    this.extraPayments = const <ExtraPayment>[],
    this.isSettled = false,
    this.notes,
    this.isSample = false,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String id;
  final String name;
  final String provider;
  final double principal;
  final double interestRate;
  final InterestRateType interestRateType;
  final double totalInterest;
  final double totalPayable;
  final int termMonths;
  final PaymentFrequency paymentFrequency;
  final String startDate;
  final String maturityDate;
  final double installmentAmount;
  final int paidInstallments;
  final int totalInstallments;

  /// What is left to pay, principal and interest together.
  final double runningBalance;
  final double principalRemaining;
  final double interestRemaining;
  final List<ExtraPayment> extraPayments;
  final bool isSettled;
  final String? notes;

  /// How far through the schedule, 0 to 1. Clamped, so an overpaid plan does
  /// not draw a bar past the end of its own track.
  double get progress => totalInstallments <= 0
      ? 0
      : (paidInstallments / totalInstallments).clamp(0.0, 1.0);

  int get installmentsLeft =>
      (totalInstallments - paidInstallments).clamp(0, totalInstallments);

  /// True when the plan charges nothing, which is the real 0 percent promo
  /// rather than one with the interest folded into the price.
  bool get isZeroInterest => totalInterest <= 0;
}

class IncomeStream {
  const IncomeStream({
    required this.id,
    required this.name,
    required this.type,
    required this.expectedAmount,
    this.isSample = false,
  });

  /// True for a record Salapify put there itself, so the screens are not blank
  /// on a brand new phone. NEVER true for anything the person entered.
  ///
  /// This one flag is what makes the sample data removable without a rule
  /// anybody has to remember: the sweep deletes only where this is true, which
  /// is a single condition in one method rather than a convention spread
  /// across every write path. It defaults to false, so a record rebuilt by the
  /// plain constructor, which is what an edit does, becomes the user's own
  /// automatically.
  final bool isSample;

  final String id;
  final String name;
  final IncomeStreamType type;
  final double expectedAmount;
}

/// What computeSafeToSpend returns. Mirrors SafeToSpendAnalysis in types.ts.
class SafeToSpendAnalysis {
  const SafeToSpendAnalysis({
    required this.scenario,
    required this.safeToSpendToday,
    required this.safeToSpendUntilPayday,
    required this.safeToSave,
    required this.amountReserved,
    required this.cashRunwayDays,
    required this.cashRunwayMonths,
    required this.reservedBills,
    required this.reservedDebtMinimums,
    required this.reservedInstallments,
    required this.emergencyBuffer,
    required this.totalLiquidCash,
    required this.totalExpectedInflow,
    required this.daysToPayday,
    this.runwayFromLoggedSpending = true,
  });

  final DecisionScenario scenario;
  final double safeToSpendToday;
  final double safeToSpendUntilPayday;
  final double safeToSave;
  final double amountReserved;
  final int cashRunwayDays;
  final double cashRunwayMonths;
  final double reservedBills;
  final double reservedDebtMinimums;
  final double reservedInstallments;
  final double emergencyBuffer;
  final double totalLiquidCash;
  final double totalExpectedInflow;
  final int daysToPayday;

  /// Whether [cashRunwayDays] was measured from spending the person actually
  /// logged, or computed against the engine's 28,000 a month stand-in.
  ///
  /// THE FLAG IS NEW, THE BEHAVIOUR IS NOT. The stand-in is the prototype's
  /// own and is locked by golden vectors, so the figure it produces is not
  /// being corrected here. What was wrong is that nothing downstream could
  /// tell the two apart, and two places then presented the stand-in as the
  /// person's own: the Decision sheet said "at your recent burn rate" to
  /// somebody who had logged no spending at all, and Pan's health check
  /// scored a Cover component out of 30 against it while the file doing the
  /// scoring carried a heading reading "It never invents a number to score
  /// against".
  ///
  /// So this is the seam CLAUDE.md asks for by name: where the prototype
  /// does something odd, the engine reproduces it and a vector locks it, and
  /// the defence lives in the UI rather than in a quietly corrected number.
  /// Every existing figure is untouched and every golden vector still holds.
  ///
  /// It defaults to true so that no test or caller constructing this by hand
  /// silently claims a measurement it did not make. The engine is the only
  /// thing that knows, and the engine always sets it.
  final bool runwayFromLoggedSpending;
}

/// How often a subscription bills. The two the prototype's data uses.
enum BillingCycle { monthly, annual }

/// Whether a subscription is live, on trial, or flagged for review.
enum SubscriptionState { active, trial }

/// One recurring charge, for the Subscriptions tracker.
class SubscriptionItem {
  const SubscriptionItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    required this.nextBilling,
    required this.state,
    this.unusedAlert = false,
    this.duplicateAlert = false,
    this.trialEnds,
  });

  final String id;
  final String name;
  final double amount;
  final BillingCycle cycle;

  /// ISO date, so it can be compared rather than only printed.
  final String nextBilling;
  final SubscriptionState state;

  /// Flagged as probably not being used. The prototype carries these as data
  /// rather than deriving them, and so does this: deriving "unused" needs
  /// usage tracking the app does not have and must not pretend to.
  final bool unusedAlert;
  final bool duplicateAlert;
  final String? trialEnds;

  /// What this costs PER MONTH, so annual and monthly plans can be added up.
  ///
  /// The prototype hardcodes its monthly total, and the hardcoded figure does
  /// not match its own list. Computing it is the fix.
  double get monthlyCost => cycle == BillingCycle.annual ? amount / 12 : amount;
}

/// One habit in the Habits tracker.
class HabitItem {
  const HabitItem({
    required this.id,
    required this.name,
    required this.streak,
    required this.doneToday,
    required this.isDaily,
  });

  final String id;
  final String name;
  final int streak;
  final bool doneToday;
  final bool isDaily;
}
