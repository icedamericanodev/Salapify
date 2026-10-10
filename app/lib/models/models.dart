// The core data model, ported from the prototype's archive/prototype-google-ai-studio/src/types.ts.
// Only the types the app actually reads today are here. The rest arrive with
// the tabs that need them, so nothing sits unused.

import '../core/money/currencies.dart';
import '../core/money/money.dart';

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

  /// Something you OWN that is worth money: a house and lot, a vehicle.
  ///
  /// WHY IT EXISTS. Every other kind here is money or a claim on money. A
  /// mortgage and a car loan had no other side, so taking out a 385,000
  /// Pag-IBIG loan dropped net worth by the whole 385,000 on the day it was
  /// taken and climbed back as it was repaid. That is wrong in the moment
  /// that matters most, and wrong in the direction that makes borrowing to
  /// buy a home look like a catastrophe. Borrowing to buy a thing does not
  /// make you poorer: you gain the thing and you gain the debt, and what you
  /// are worth is unchanged until one of them moves.
  ///
  /// THE BALANCE IS AN ESTIMATE THE PERSON MAINTAINS. Salapify has no way to
  /// check what a house is worth and never will, so this figure is only as
  /// good as the last time somebody updated it, which the screen says out
  /// loud rather than implying a precision it does not have.
  ///
  /// DELIBERATELY NOT IN [liquidKinds] OR `cashEquivalentKinds`. You cannot
  /// spend your house this fortnight, and a kind that reached Safe to Spend
  /// would tell somebody with a paid-off condo that they can spend two
  /// million pesos today.
  property,
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

/// What the money in an account is FOR, which is a different question from
/// what kind of account it is.
///
/// [liquidKinds] above answers "could money leave this account today", and it
/// is the only question the app used to ask. That is wrong for this audience:
/// an emergency fund kept in GSave, Maya Savings, SeaBank or Tonik is a
/// `gcash`, `maya` or `bank` account, so the app counted somebody's ipon as
/// this fortnight's pocket money and told them they could spend it. Two of the
/// eleven sample accounts are literally named Savings and had the same defect.
///
/// Deliberately TWO values and not three. Paluwagan money held for the group
/// is not protected, it is not yours, and it belongs in the debt model in the
/// `iOwe` direction, because calling it protected would leave it inside net
/// worth. A wallet that is part spending money and part ipon is a partial
/// amount, which no label can express, and the real answer there is a second
/// account and a transfer, which is also exactly what GSave already is.
enum AccountPurpose {
  /// Money meant for spending. The default, always, and never inferred.
  spendable,

  /// Money set aside. Still the person's, still in their net worth, still
  /// payable from, but it stops funding today's spending.
  protected,
}

enum DebtDirection { iOwe, owedToMe }

/// Which side of a person's life a row belongs to. The prototype INFERS this
/// from the item's name rather than storing it, so the inference lives in one
/// place (see FinancialState.profileOf) and this enum is only the vocabulary.
enum ProfileEntity { personal, household, business, sideHustle }

enum DecisionScenario { conservative, optimistic }

/// The seven income shapes the prototype recognises. The names map one to one
/// onto archive/prototype-google-ai-studio/src/types.ts, so a value can never silently mean something else.
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
    this.purpose = AccountPurpose.spendable,
    this.valuedOn,
  });

  /// The day the person last said what this is worth, as an ISO date.
  ///
  /// ONLY MEANINGFUL FOR [AccountKind.property], and null everywhere else.
  /// A bank balance carries its own freshness: it moves when money moves, and
  /// a stale one is caught by Reports, Check. A house does not. Once property
  /// is excluded from every flow that writes a transaction, which it is,
  /// NOTHING will ever touch that balance again except a person editing it by
  /// hand. So the staleness is genuinely unknowable without storing this, and
  /// an estimate nobody can date is an estimate nobody can judge.
  ///
  /// NULLABLE, so every account written before this field existed stays valid
  /// with no migration and no guessing. Null means "we do not know when",
  /// which the screen says plainly rather than quietly showing today.
  ///
  /// SALAPIFY NEVER MOVES THE FIGURE ITSELF. No straight line depreciation,
  /// no "phones lose forty percent a year". That would change net worth on a
  /// day nobody did anything, which is the app inventing a peso figure that
  /// the person cannot trace and cannot argue with. The app's whole job here
  /// is to show the age and let them decide.
  final String? valuedOn;

  /// What this money is for. See [AccountPurpose].
  ///
  /// DEFAULTS TO SPENDABLE AND IS NEVER INFERRED, which is a deliberate
  /// product decision and not laziness. Guessing from the name is unsafe in
  /// both directions: "Maya Savings" is the literal product name of a wallet
  /// millions of people spend from every day, and GSave lives inside GCash so
  /// the account may be named "GCash" with both pots mixed. Guessing from the
  /// kind is worse, because every one of [liquidKinds] is used both ways.
  ///
  /// The cost of a wrong guess was measured on the sample ledger: protecting
  /// the two savings-named accounts drops Safe to Spend until payday from
  /// 38,414 to 9,838. A silent 74 percent fall in the figure somebody reads
  /// first, with no action of theirs to explain it, is indistinguishable from
  /// the app losing their money. So the app never moves this on its own.
  final AccountPurpose purpose;

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
  final Money balance;
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

  /// Which entity this account belongs to, from archive/prototype-google-ai-studio/src/types.ts.
  ///
  /// NULLABLE on purpose, and the null is meaningful rather than lazy. Reports
  /// filters with `!a.profile || a.profile === activeProfile`, so an account
  /// with no profile appears under EVERY entity. An account that belongs
  /// nowhere in particular belongs everywhere, which is the right answer for
  /// a wallet somebody has not classified yet.
  final ProfileEntity? profile;
  final Money? creditLimit;
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

  /// Whether this money should fund TODAY'S spending.
  ///
  /// [isLiquid] and this are not the same question, and conflating them is the
  /// defect P2.3 exists to fix. `isLiquid` asks "can money leave this account",
  /// which is what every pay-from picker needs and what the history filter
  /// needs. This asks "should this money inflate Safe to Spend", which is what
  /// the engine, the payday indicator and the cash shortfall alert need.
  ///
  /// Only those last three kinds of caller move to this getter. Everything
  /// that stays on [isLiquid] therefore provably cannot change behaviour,
  /// which is why the split is a new predicate rather than a redefinition of
  /// the old one.
  bool get isSpendable => isLiquid && purpose != AccountPurpose.protected;

  /// True only for an account where [purpose] means anything.
  ///
  /// A credit card, a loan, a mortgage, an investment or a receivable is never
  /// spendable cash in the first place, so marking one "set aside" would be
  /// inert, and a control that does nothing teaches people the controls do
  /// nothing. The account sheet does not render the picker for these.
  bool get purposeApplies => isLiquid;

  /// The peso value of this balance, for anything that adds accounts up.
  /// This balance in pesos, for anything that adds accounts together.
  ///
  /// A RATE is applied, so the result is a converted figure rather than a
  /// recorded one, and it is rounded to the centavo once here instead of
  /// being left to drift through every caller.
  Money get balanceInPhp => isForeign
      ? Money.fromDouble(convertToPhp(balance.pesos, currency))
      : balance;

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
  /// [purpose] is carried through, like [isSample], and that is load bearing.
  ///
  /// This is the copy the ledger makes every time a balance moves. Leaving
  /// `purpose` off the list would mean logging one expense from a protected
  /// account silently un-protected it, and the person's Safe to Spend would
  /// jump back up with nothing on any screen to explain why. A test in
  /// `test/core/money/protected_accounts_test.dart` holds this.
  Account copyWith({Money? balance, bool? isSample, AccountPurpose? purpose}) =>
      Account(
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
        purpose: purpose ?? this.purpose,
        // CARRIED THROUGH, like `isSample` and `purpose` above and for the
        // same reason. This is the copy the ledger makes when a balance
        // moves; dropping the date here would silently reset a house to "no
        // date on it" the first time anything touched the account, which is
        // the opposite of what storing the date is for.
        valuedOn: valuedOn,
      );
}

/// What the ledger believes about an entry, from archive/prototype-google-ai-studio/src/types.ts.
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

/// The account id that names NO account of the person's: money that came
/// from, or went to, somebody else (D34, D35, 2026-10-10).
///
/// Three entries use it. A friend paid for your share of a split: an expense
/// with this as its account, so the share counts as spending and no balance
/// moves. A friend repays money you lent: a transfer FROM here into your
/// account. And it is never the destination: money lent out is a transfer
/// from your account with no destination at all.
///
/// A NAMED value rather than the empty string, because an empty account id
/// already means "nothing chosen" on the Log sheet and is what a bug would
/// produce; a sentinel nobody can type cannot be confused with either. It
/// matches no account, so the balance code skips that leg without a special
/// case (ledger.dart applyToBalances).
const String outsideAccountId = 'outside';

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
  final Money amount;
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

  /// Left out of the in and out totals. The states that mean "this is not
  /// really money that moved".
  ///
  /// THIS IS THE ONLY DEFINITION. `validLedgerEntries` in reports.dart used to
  /// carry a second copy of the same list, which is how a rule like this drifts:
  /// a state added to one and not the other counts in half the app. It now
  /// reads this getter.
  ///
  /// `corrected` means TAKEN BACK, and it joined the list on founder direction,
  /// 2026-10-02. The row stays in Activity so the history still shows what
  /// happened, and it stops counting, because the payment it describes has been
  /// undone. A row left counting while the debt has moved is the half-landed
  /// state this whole batch exists to stop.
  /// True when this entry's own account is nobody's: see [outsideAccountId].
  bool get isFromOutside => accountId == outsideAccountId;

  /// The one account of the PERSON'S that this entry touches, for a screen
  /// that labels or groups entries by account. Null when it touches none (a
  /// share a friend paid for).
  ///
  /// Read this, never [accountId], wherever an account is shown or compared:
  /// two repayments collected into GCash and BPI both carry [outsideAccountId]
  /// as their account, and comparing that paired them as "the same account".
  String? get ownAccountId => isFromOutside ? toAccountId : accountId;

  /// Money arriving from somebody else into one of the person's accounts: a
  /// friend repaying money lent. Shown as money IN (a plus and the positive
  /// colour) although it is a transfer, so a repayment does not read as a
  /// payment the person made.
  bool get arrivesFromOutside =>
      isFromOutside && type == TransactionType.transfer && toAccountId != null;

  /// Who is on the far side of an entry that involves somebody else.
  String get counterparty => person ?? 'Someone else';

  bool get countsTowardTotals =>
      status != TransactionStatus.excluded &&
      status != TransactionStatus.duplicate &&
      status != TransactionStatus.corrected;

  /// True when SALAPIFY wrote this entry to explain a debt or instalment
  /// payment, rather than the person logging it by hand.
  ///
  /// Recognised by the id this build gives such an entry, which is the ONLY
  /// trace of the link that exists: a Transaction carries no debtId and no
  /// planId, so nothing else in the app can tell a payment row from an
  /// ordinary expense. `tx_inst_` covers `tx_inst_extra_` as well, since one
  /// is a prefix of the other.
  ///
  /// IT EXISTS FOR ONE JOB: refusing a correction that can only half land.
  /// Changing such an entry's status reverses the ACCOUNT through
  /// reverseFromBalances, and cannot touch the debt or the plan, because
  /// there is nothing to follow. Reconciliation offered exactly that on its
  /// "possible double entries" list, so one tap on an orange warning put the
  /// money back in the account and left the debt still claiming it was paid,
  /// measured at 1,500.00 with no screen anywhere explaining the difference.
  ///
  /// DELIBERATELY CONSERVATIVE, and the direction matters. A hand-logged
  /// entry that happens to carry one of these ids would wrongly lose the
  /// duplicate control, which costs somebody one correction route out of
  /// several. A payment entry wrongly treated as ordinary breaks a figure
  /// that cannot be put back. Those are not comparable, so this errs toward
  /// refusing.
  ///
  /// It is a stopgap, and the right answer replaces it: once a payment
  /// carries its own stored record, the link is a fact rather than a guess at
  /// a string, and an entry from a restored backup written by some other
  /// build is covered too, which this is not.
  bool get isEnginePayment =>
      id.startsWith('tx_debt_') || id.startsWith('tx_inst_');

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
    this.paidBeforeSettle,
    this.payments = const <DebtPayment>[],
    this.archivedAt,
    this.minimumPayment,
    this.openingTxId,
  });

  /// The ledger entry that STARTED this debt, when real money moved to make
  /// it: a split bill, or money lent or borrowed (D35, 2026-10-10).
  ///
  /// It decides how a repayment is written. A debt that began with money
  /// moving is repaid by moving the money back, which is neither spending nor
  /// income: the spending (your share of a meal) or the lending was already
  /// recorded when the debt began. Without this, repaying a friend for a
  /// split counted the same 300 of dinner a second time.
  ///
  /// NULL MEANS "began with no money moving", which is every debt added by
  /// hand, every sample debt and every debt in an older backup, and they are
  /// repaid exactly as they always were.
  final String? openingTxId;

  /// What this debt costs every month, when the person has said so.
  ///
  /// NULL IS NOT ZERO, and the difference is the whole point of the field.
  /// Null means "nobody has told Salapify what this costs", which is the
  /// normal state of a debt to a relative. Zero would mean "it genuinely
  /// costs nothing a month", which is a different and much rarer claim.
  /// [monthlyMinimum] below reserves nothing for a null and respects an
  /// explicit zero, and `Money.zero` could not express that difference.
  ///
  /// Optional on purpose. Salapify never asks for it and never infers it from
  /// a percentage: see [monthlyMinimum] for why.
  final Money? minimumPayment;

  /// What to hold back for this debt each month, or null to hold back nothing.
  ///
  /// THE RULE, in the order it is applied:
  ///
  ///   1. the minimum the person entered;
  ///   2. otherwise, for a SCHEDULED debt that carries instalment numbers,
  ///      what is left divided by the instalments still to run;
  ///   3. otherwise NOTHING.
  ///
  /// Step 3 is the correction this field exists for. The prototype reserves
  /// eight percent of every outstanding debt
  /// (`archive/prototype-google-ai-studio/src/utils/safeToSpendEngine.ts:57`), and a percentage of a BALANCE is
  /// not a monthly payment. It is wrong in both directions, which reading the
  /// sample ledger showed rather than the review:
  ///
  ///   - too SMALL for a short loan. The seed's two debts are both scheduled
  ///     and really cost 4,950 a month between them, where eight percent of
  ///     their 17,350 balance is 1,388;
  ///   - too LARGE for a debt that has no schedule. "Utang kay nanay 20,000"
  ///     has no monthly minimum and never did, and charging 1,600 a cycle
  ///     against it invents an obligation the person never agreed to.
  ///
  /// Founder decision, 2026-10-04: a debt with no minimum and no schedule
  /// reserves nothing. Salapify never assumes a percentage.
  ///
  /// EVERY ANSWER IS PUT THROUGH [_withinWhatIsOwed]. A monthly cost that is
  /// bigger than the whole remaining balance is not a monthly cost, and a
  /// negative one is not a cost at all. Both were reachable before
  /// 2026-10-04: a card entered with a 3,000 minimum and paid down to 500
  /// left reserved 3,000 against it, which told the person they ran short on
  /// the 15th and took 2,500 off Safe to Spend that was really theirs; and a
  /// minimum typed with a minus in front netted off every OTHER debt's real
  /// minimum, because [monthlyDebtMinimums] sums them and
  /// `computeSafeToSpend` only clamps the total.
  Money? get monthlyMinimum {
    if (isSettled) return null;
    if (minimumPayment != null) return _withinWhatIsOwed(minimumPayment!);
    if (schedule != DebtSchedule.scheduled) return null;

    final int? total = installmentTotal;
    if (total == null || total <= 0) return null;

    // Instalments STILL TO RUN. The counter is how many have been paid, so
    // the remainder is what the rest of the balance is spread over. Clamped
    // at one so the final instalment reserves the whole remainder rather
    // than dividing by zero, and so does a plan whose term has run out with
    // a balance still on it: that money really is all due now.
    final int left = total - _instalmentsRun(total);
    return _withinWhatIsOwed(remaining.split(left < 1 ? 1 : left).first);
  }

  /// A monthly figure held between zero and what is actually still owed.
  Money _withinWhatIsOwed(Money m) {
    if (m.centavos < 0) return Money.zero;
    return m > remaining ? remaining : m;
  }

  /// How many instalments of this plan have already run.
  ///
  /// The stored counter is a HINT and the payment ledger is the truth. Two
  /// ways the hint goes wrong, both measured on 2026-10-04:
  ///
  ///   - it is ABSENT. `debtToJson` writes `installmentCurrent` only when it
  ///     is not null, and a debt restored from a backup written before the
  ///     key existed comes back with real payments and a null counter.
  ///     Reading that as "none have run" spread a 12,000 plan's last 2,000
  ///     over all six instalments and reserved 333.34, a sixth of the real
  ///     monthly cost, permanently, because the null round-trips into the
  ///     next backup. So when it is absent the count is read off what has
  ///     been PAID against the plan's own instalment size.
  ///   - it is OUT OF RANGE. A hand-edited or corrupted file can say nine of
  ///     six, which made `left` negative. Clamped into the term.
  int _instalmentsRun(int total) {
    final int? stored = installmentCurrent;
    if (stored != null) {
      if (stored < 0) return 0;
      return stored > total ? total : stored;
    }
    final Money each = totalAmount.split(total).first;
    if (!each.isPositive) return 0;
    final int run = paidAmount.centavos ~/ each.centavos;
    if (run < 0) return 0;
    return run > total ? total : run;
  }

  /// The day this debt was put away, as an ISO date. Null means it is live.
  ///
  /// ONLY A SETTLED DEBT MAY CARRY THIS, by founder direction on 2026-10-02,
  /// and that single rule is what makes archiving safe. A settled debt is
  /// already outside [outstanding], so hiding it changes no total on any
  /// screen: not "You owe", not "Owed to me", not net worth, not the Accounts
  /// debt register. The alternative, letting a live debt be archived, would
  /// have let a tap in the UI take a liability off the balance sheet, with
  /// the explanation one screen away from the figure that moved. The founder
  /// chose against it and the gate lives in [FinancialState.archiveDebt]
  /// rather than in a rule anybody has to remember.
  ///
  /// Archiving is reversible and nothing else moves when it happens. The
  /// payment register is untouched, the `tx_debt_` entries stay in Activity
  /// and keep counting, and no balance changes. The money really did leave
  /// the account, so Salapify does not put it back.
  final String? archivedAt;

  bool get isArchived => archivedAt != null;

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
  final Money totalAmount;
  final Money paidAmount;
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

  /// What [paidAmount] said before "Mark settled" FILLED it in, and null
  /// whenever that button is not what made this debt settled.
  ///
  /// ## Why a field exists for this at all
  ///
  /// "Mark settled" sets paidAmount to totalAmount, which is what makes the
  /// button honest: "settled" and "still owes 7,350" cannot both be true on
  /// one row. "Not settled after all" then used to leave the filled figure
  /// in place, and the reasoning was sound for the case it was written for,
  /// a debt settled by real payments, where the money really was paid and
  /// inventing a smaller figure would be worse than a wrong flag.
  ///
  /// The same function also served a debt settled BY THE BUTTON, where the
  /// fill was invented in the first place. Two taps, with no confirmation on
  /// either, destroyed the real figure permanently:
  ///
  ///     start        : paid 7,350.00 of 12,000.00
  ///     Mark settled : paid 12,000.00
  ///     Not settled  : paid 12,000.00, and 7,350.00 is gone
  ///
  /// A debt keeps no payment history and the app has no edit or delete for
  /// one, so 4,650.00 the person never paid was recorded as paid with no way
  /// back short of wiping the phone. "Not settled after all" is precisely the
  /// button somebody taps believing it IS the way back.
  ///
  /// Null is the meaningful value, not a missing one: it says this debt was
  /// not filled by the button, so un-settling must leave paidAmount exactly
  /// where it is. Every debt stored before this field existed reads null and
  /// therefore keeps the old behaviour, which is the correct behaviour for
  /// the case it was written for.
  final Money? paidBeforeSettle;

  /// Every payment recorded against this debt, in the order they landed.
  ///
  /// Each row carries the figures that CANNOT be recomputed from the debt
  /// afterwards, so taking one back is a restore rather than a derivation.
  /// See [DebtPayment] for which ones and why.
  ///
  /// Empty on every debt written before this existed. Empty means nothing is
  /// known about how this debt reached its current figure, which is the
  /// truth; nothing is back-filled by matching on person and amount, because
  /// two debts to the same person are indistinguishable on every field the
  /// ledger stores and a wrong guess would un-pay the other one.
  final List<DebtPayment> payments;

  Money get remaining => maxMoney(Money.zero, totalAmount - paidAmount);

  /// How far through it is, from 0 to 1. Clamped, because an overpayment
  /// would otherwise draw a bar past the end of its own track.
  double get progress => totalAmount.isPositive
      ? (paidAmount.centavos / totalAmount.centavos).clamp(0.0, 1.0)
      : 0;

  /// [isSample] is NOT carried through, and that is the point.
  ///
  /// This copy is made when a payment is recorded against a debt. Paying a
  /// demo debt with real money makes it the person's own debt, so it must
  /// survive the sample sweep rather than being deleted with the payment
  /// history pointing at it. Letting the field default to false here is what
  /// adopts it, with no extra rule anywhere.
  Debt copyWith({
    Money? paidAmount,
    bool? isSettled,
    String? settledDate,
    int? installmentCurrent,
    bool clearSettledDate = false,
    Money? paidBeforeSettle,
    bool clearPaidBeforeSettle = false,
    List<DebtPayment>? payments,
    String? archivedAt,
    bool clearArchivedAt = false,
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
    // Carried through, unlike isSample. A payment recorded while the button's
    // fill is in place must not forget what the real figure was, or the next
    // "Not settled after all" loses it again by a different route.
    paidBeforeSettle: clearPaidBeforeSettle
        ? null
        : (paidBeforeSettle ?? this.paidBeforeSettle),
    // Carried through for the same reason: the register is the record of how
    // this debt reached its figure, and a copy made for any other purpose
    // must not quietly empty it.
    payments: payments ?? this.payments,
    // Same clear-flag shape as settledDate and paidBeforeSettle, and for the
    // same reason: passing null has to mean "leave it alone", or every copy
    // made for an unrelated purpose would un-archive the debt by accident.
    archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    // CARRIED THROUGH. This copy dropped minimumPayment for as long as the
    // field existed, so recording any payment erased the minimum the person
    // had typed and Safe to Spend quietly stopped holding it back. Every
    // field without a parameter above must still be passed along here.
    minimumPayment: minimumPayment,
    openingTxId: openingTxId,
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

  /// The monthly cap for this category, in whole centavos.
  ///
  /// A cap is compared against a running total of real spending, so holding
  /// it as a double meant the comparison that decides whether somebody is
  /// over budget was a float comparison. The stored shape is still pesos:
  /// `json_codec.dart` is the only boundary, so a backup written here still
  /// opens in a build that has not migrated.
  final Money limit;
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
  final Money targetAmount;
  final Money currentAmount;
  final String targetDate;
  final Money monthlyTarget;
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
  final Money amount;

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
  final Money expectedIncome;

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
    expectedIncome: Money.zero,
  );

  /// True when nobody has told Salapify when they get paid.
  bool get isSet => daysToPayday > 0 && nextPayday.isNotEmpty;

  PaydayCycle copyWith({
    String? cycleType,
    String? lastPayday,
    String? nextPayday,
    int? daysToPayday,
    Money? expectedIncome,
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
  final Money amount;
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
  final Money amount;
  final String? note;
}

/// ONE APPLIED PAYMENT, recorded as a fact rather than left to be worked out
/// again later.
///
/// ## Why this exists, and why a running total is not enough
///
/// Both instalment engines SPLIT a payment and then throw the split away.
/// `applyExtraPayment` computes `offPrincipal` and `offInterest`,
/// `applyInstallmentPayment` computes `interestPart` and `principalPart`
/// through three clamps and an unallocated sweep, and neither is stored. The
/// plan keeps only the totals they produced.
///
/// That makes the operation impossible to reverse correctly, and the failure
/// is silent. Measured on the seeded SPayLater plan, prepaying 6,000 against
/// 5,600 principal and 991.20 interest: the true split is 5,600 principal and
/// 400 interest, and a reversal that re-derives it from the documented policy
/// ("prepayments come off principal first") puts all 6,000 back on principal.
///
///     balance restored  : correct
///     account restored  : correct
///     net worth         : correct
///     principal         : overstated by 400, permanently
///     interest          : understated by 400, permanently
///
/// Every conservation assertion passes on that wrong answer, because the total
/// foots. It is the same shape as the 991.20 defect from the other direction:
/// the parts sum to the whole and the meaning is wrong. On an add-on contract
/// the principal figure is what decides whether prepaying is worth it, so this
/// is not bookkeeping trivia.
///
/// A scheduled instalment loses even more. `paidInstallments` is a counter,
/// not a set of events, and the collected amount is capped at the running
/// balance, so a stub left by a prepayment cannot be told apart from a full
/// instalment that happened to land on zero. Reversing one by re-deriving the
/// schedule credited 1,647.80 against a ledger row holding 591.20.
///
/// So the register stores what WAS applied. Reversal then reads a fact
/// instead of recomputing a guess, and no rounding policy, clamp or sweep sits
/// between the two.
class PlanPayment {
  const PlanPayment({
    required this.id,
    required this.date,
    required this.amount,
    required this.toPrincipal,
    required this.toInterest,
    this.settledBefore = false,
    this.installmentNumber,
    this.accountId,
    this.txId,
    this.note,
  });

  final String id;

  /// ISO date, YYYY-MM-DD.
  final String date;

  /// What was actually APPLIED, which is not always what was offered: a
  /// prepayment larger than the balance is capped, and the difference exists
  /// nowhere else.
  final Money amount;

  /// The split, stored because it cannot be recovered. These two always sum
  /// to [amount]; `plan_register_test.dart` asserts it on every shape.
  final Money toPrincipal;
  final Money toInterest;

  /// Which scheduled instalment this was, or null for a prepayment. Null is
  /// the thing that tells the two apart on the way back out.
  final int? installmentNumber;

  /// Whether the plan was ALREADY settled when this landed.
  ///
  /// Not recoverable from the balance afterwards, and not always false.
  /// `applyInstallmentPayment` refuses a settled plan, but `applyExtraPayment`
  /// does not guard at entry, so a prepayment can be applied to one that was
  /// already clear. Recomputing settlement from the restored balance would
  /// then reopen a plan that was settled before the payment ever happened.
  final bool settledBefore;

  /// Where the money came from, and the ledger row that explains it.
  ///
  /// Both are nullable and both are legitimately absent: a payment recorded
  /// with no account writes no entry at all, deliberately, for somebody
  /// settling in cash they never logged.
  final String? accountId;
  final String? txId;

  final String? note;
}

/// One applied payment on a DEBT, with the fields that cannot be recomputed.
///
/// A debt keeps `paidAmount` as a single running figure, so subtracting an
/// amount gets the total back but not the rest. Two fields are genuinely
/// lossy and both are stored here as they were BEFORE the payment landed:
///
///  - `settledDate` is stamped only on the TRANSITION, and a further payment
///    on an already settled debt keeps the original date. Clearing it on the
///    way back is right in one case and destroys a real date in the other.
///  - `installmentCurrent` SATURATES at its total, so the last payment of a
///    plan does not move it. Decrementing on the way back would invent a
///    payment that was never undone.
///
/// `paidAmount` before is stored too, rather than derived by subtraction,
/// because `toggleDebtSettled` can FILL it to the total between two payments.
/// After that fill the running figure is not the sum of the payments any more,
/// and nothing else in the app can tell you the difference.
class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.date,
    required this.amount,
    required this.paidBefore,
    required this.settledBefore,
    this.settledDateBefore,
    this.installmentCurrentBefore,
    this.accountId,
    this.txId,
    this.note,
  });

  final String id;
  final String date;
  final Money amount;

  final Money paidBefore;
  final bool settledBefore;
  final String? settledDateBefore;
  final int? installmentCurrentBefore;

  final String? accountId;
  final String? txId;
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
    this.payments = const <PlanPayment>[],
    this.isSettled = false,
    this.notes,
    this.isSample = false,
    this.archivedAt,
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

  /// The day this plan was put away, as an ISO date. Null means it is live.
  ///
  /// Same rule as [Debt.archivedAt], and for the same reason: ONLY A SETTLED
  /// PLAN MAY CARRY THIS. A settled plan is already outside Safe to Spend's
  /// reserve and outside the Plans summary, so putting it away changes no
  /// figure. Allowing a LIVE plan to be archived would take a real monthly
  /// obligation out of Safe to Spend on a tap, which is the design the
  /// founder turned down for debts on 2026-10-02.
  ///
  /// Plans needed this more than debts did. Until it existed there was no way
  /// to remove a plan AT ALL, and paying one adopts it, because the copier
  /// drops [isSample] deliberately so that a real payment makes a demo record
  /// yours. So one exploratory tap on a demo plan held Safe to Spend down for
  /// ever, and the only exit was Delete everything.
  final String? archivedAt;

  bool get isArchived => archivedAt != null;

  final String id;
  final String name;
  final String provider;
  final Money principal;
  final double interestRate;
  final InterestRateType interestRateType;
  final Money totalInterest;
  final Money totalPayable;
  final int termMonths;
  final PaymentFrequency paymentFrequency;
  final String startDate;
  final String maturityDate;
  final Money installmentAmount;
  final int paidInstallments;
  final int totalInstallments;

  /// What is left to pay, principal and interest together.
  final Money runningBalance;
  final Money principalRemaining;
  final Money interestRemaining;
  final List<ExtraPayment> extraPayments;

  /// Every payment applied to this plan, scheduled and extra together, in the
  /// order they landed.
  ///
  /// ONE ORDERED LIST, not two, and that is what makes "the most recent one"
  /// a question with an answer. A prepayment shortens the plan, so every
  /// instalment after it collected a different amount; taking the prepayment
  /// back while those stand would leave their recorded amounts explainable by
  /// no schedule at all. Interleaving both kinds here is what lets a reversal
  /// refuse that, visibly, instead of quietly doing something else.
  ///
  /// Empty on every plan written before this existed, and empty is honest:
  /// it says nothing is known about how this plan got where it is, which is
  /// exactly the situation. Nothing is back-filled by guessing.
  final List<PlanPayment> payments;
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
  bool get isZeroInterest => !totalInterest.isPositive;

  /// The ONLY public copier on a plan, and it changes one field.
  ///
  /// Deliberately not a general `copyWith`. Every other change to a plan goes
  /// through the engine, which owns the arithmetic between the balances, the
  /// counter and the register, and a wide copier on this class would be an
  /// invitation to move one of those without the others. Archiving is the one
  /// change that touches no money at all.
  ///
  /// Null CLEARS it, which is what "Put it back" needs. That is safe here
  /// precisely because the parameter means one thing: unlike the flag-based
  /// clears on [Debt.copyWith], there is no "leave it alone" case to confuse
  /// it with.
  InstallmentPlan copyWithArchived(String? archivedAt) => InstallmentPlan(
    id: id,
    name: name,
    provider: provider,
    principal: principal,
    interestRate: interestRate,
    interestRateType: interestRateType,
    totalInterest: totalInterest,
    totalPayable: totalPayable,
    termMonths: termMonths,
    paymentFrequency: paymentFrequency,
    startDate: startDate,
    maturityDate: maturityDate,
    installmentAmount: installmentAmount,
    paidInstallments: paidInstallments,
    totalInstallments: totalInstallments,
    runningBalance: runningBalance,
    principalRemaining: principalRemaining,
    interestRemaining: interestRemaining,
    extraPayments: extraPayments,
    payments: payments,
    isSettled: isSettled,
    notes: notes,
    // CARRIED, unlike the engine's copier. Archiving is not a payment, so it
    // must not quietly adopt a demo plan the sweep would otherwise remove.
    isSample: isSample,
    archivedAt: archivedAt,
  );
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
  final Money expectedAmount;
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
    this.protectedCash = Money.zero,
  });

  /// Liquid money the person has marked as set aside, and which therefore did
  /// NOT feed [safeToSpendToday].
  ///
  /// It is here because the Safe to Spend sheet's first step used to read
  /// "Cash, GCash, Maya, banks and debit", which goes false the moment anybody
  /// protects an account. Under the house rule that a figure and the one line
  /// needed to read it stay on the screen, the amount left out is itself a
  /// figure, so the step shows both and the lesson goes behind the dot.
  ///
  /// Not part of [totalLiquidCash], which keeps its old meaning of every
  /// liquid account, protected or not, so the cash runway below can go on
  /// counting it.
  final Money protectedCash;

  final DecisionScenario scenario;

  // THE LAST TEN NAMES IN P2.1, and the only ones that were ever OUTPUTS
  // rather than stored figures.
  //
  // Every one of these is already a WHOLE PESO before it gets here: the
  // engine puts `jsRound` round each of them, because the prototype does,
  // and the golden vectors are whole numbers for that reason. So moving them
  // to Money is a change of TYPE and not of arithmetic. The engine keeps
  // working in pesos internally and converts once, at its return, which is
  // why every vector holds to the centavo across this change.
  //
  // What it buys: the ten figures a person reads first can no longer be
  // added to a double by accident on the way to a screen.
  final Money safeToSpendToday;
  final Money safeToSpendUntilPayday;
  final Money safeToSave;
  final Money amountReserved;
  final int cashRunwayDays;

  /// NOT money. A count of months, which is why it stays a double and keeps
  /// its one decimal place.
  final double cashRunwayMonths;
  final Money reservedBills;
  final Money reservedDebtMinimums;
  final Money reservedInstallments;
  final Money emergencyBuffer;
  final Money totalLiquidCash;
  final Money totalExpectedInflow;
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
  final Money amount;
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
  ///
  /// A twelfth of an annual plan, rounded to the centavo with the prototype's
  /// rule, which is the figure its own display worked out. Not [Money.split],
  /// which would be the right tool if these twelve shares were being CHARGED
  /// and had to sum back to the year exactly. They are not: this is one
  /// month's share shown next to eleven identical ones.
  Money get monthlyCost =>
      cycle == BillingCycle.annual ? amount.times(1 / 12) : amount;
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
