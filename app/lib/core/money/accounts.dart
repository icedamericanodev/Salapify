/// The Accounts tab's engine, ported from src/components/AccountsScreen.tsx.
///
/// Everything here is pure: grouping, summing, and the two derived figures
/// the screen shows (credit utilisation and the monogram). The screen itself
/// does no arithmetic, which is what lets the numbers be tested without
/// pumping a widget.
///
/// `assetKinds` and `liabilityKinds` are IMPORTED from reports.dart rather
/// than redeclared. The prototype declares the same two lists in both
/// AccountsScreen.tsx and ReportsScreen.tsx, and two copies of a rule about
/// what counts as an asset is how a balance sheet and an accounts screen end
/// up disagreeing about the same money.
library;

import 'money.dart';
import '../../models/models.dart';
import 'currencies.dart';
import 'reports.dart' show assetKinds, liabilityKinds;

/// Which slice of the accounts list the user is looking at.
enum AccountView { all, assets, liabilities, investments }

/// One collapsible group on the screen, such as "E-Wallets" or "Credit Cards".
class AccountGroup {
  const AccountGroup({
    required this.id,
    required this.title,
    required this.accounts,
  });

  final String id;
  final String title;
  final List<Account> accounts;

  /// The group's total, in pesos, with every foreign balance converted first.
  double get totalPhp => accountsTotalPhp(accounts);
}

/// Sums balances IN PESOS. Never sum `balance` directly across accounts: a
/// dollar account and a peso account are different units, and adding them
/// gives a number that is wrong in a way no test on a peso-only fixture can
/// see.
double accountsTotalPhp(Iterable<Account> accounts) => accounts.fold<double>(
  0,
  (double sum, Account a) => sum + a.balanceInPhp.pesos,
);

/// The same accounts with every balance ALREADY CONVERTED to pesos.
///
/// For handing to an engine that cannot convert for itself. `safe_to_spend`
/// is the case this was written for: it is a line-for-line port of
/// src/utils/safeToSpendEngine.ts, which has no currency field at all, so it
/// reads `balance` raw and must keep doing so to stay golden-locked. The
/// conversion therefore happens HERE, on the way in, rather than inside it.
/// Peso-only ledgers are untouched: `balanceInPhp` returns `balance`
/// unchanged when the account is not foreign, so every golden vector, all of
/// which are peso-only, computes exactly as before.
///
/// THE TRAP, and the reason this is a named function rather than an inline
/// map: `copyWith` carries `currency` through, so a returned account can read
/// USD while its balance is already pesos. That is harmless only for as long
/// as the consumer never converts again. `safe_to_spend.dart` reads `balance`
/// and nothing else, which is checked by a test rather than remembered. Any
/// engine that DOES read `currency` must be given the originals instead.
List<Account> accountsInPhp(Iterable<Account> accounts) => accounts
    .map((Account a) => a.isForeign ? a.copyWith(balance: a.balanceInPhp) : a)
    .toList();

/// The prototype's filter: entity first, then the asset or liability slice.
///
/// A null [profile] means "all entities". An account whose own profile is
/// null belongs to every entity, the same rule Reports uses, so a wallet
/// somebody never classified never vanishes from the screen.
List<Account> filterAccounts(
  List<Account> accounts, {
  ProfileEntity? profile,
  AccountView view = AccountView.all,
}) {
  return accounts.where((Account a) {
    if (profile != null && a.profile != null && a.profile != profile) {
      return false;
    }
    if (view == AccountView.assets && !assetKinds.contains(a.kind)) {
      return false;
    }
    if (view == AccountView.liabilities && !liabilityKinds.contains(a.kind)) {
      return false;
    }
    return true;
  }).toList();
}

List<Account> assetsOf(List<Account> accounts) =>
    accounts.where((Account a) => assetKinds.contains(a.kind)).toList();

List<Account> liabilitiesOf(List<Account> accounts) =>
    accounts.where((Account a) => liabilityKinds.contains(a.kind)).toList();

/// The five asset groups, in the prototype's own order. An empty group is
/// dropped rather than shown empty, so somebody with no investments does not
/// get a heading that only ever says nothing.
List<AccountGroup> groupAssets(List<Account> accounts) {
  final List<Account> a = assetsOf(accounts);
  final List<AccountGroup> groups = <AccountGroup>[
    AccountGroup(
      id: 'ewallet',
      title: 'E-Wallets',
      accounts: a
          .where(
            (Account x) =>
                x.kind == AccountKind.gcash || x.kind == AccountKind.maya,
          )
          .toList(),
    ),
    AccountGroup(
      id: 'bank',
      title: 'Bank Accounts',
      accounts: a
          .where(
            (Account x) =>
                x.kind == AccountKind.bank || x.kind == AccountKind.debit,
          )
          .toList(),
    ),
    AccountGroup(
      id: 'cash',
      title: 'Cash',
      accounts: a.where((Account x) => x.kind == AccountKind.cash).toList(),
    ),
    AccountGroup(
      id: 'investment',
      title: 'Investments',
      accounts: a
          .where((Account x) => x.kind == AccountKind.investment)
          .toList(),
    ),
    // AFTER INVESTMENTS, BEFORE RECEIVABLES, so the list runs from what you
    // can spend today to what you cannot spend at all to what somebody else
    // is holding.
    //
    // IT IS HERE BECAUSE THE COMPILER COULD NOT ASK FOR IT. These groups are
    // a hand-typed list of `.where()` calls rather than a switch, so adding
    // `property` to `assetKinds` put it in this function's INPUT and in none
    // of its output. The screen's hero reads `summarize`, which counts every
    // asset, while the list below reads this, which would have dropped the
    // house: a total of 581,970.50 over a list footing to 181,970.50, with
    // 400,000 nowhere on the screen and no analyzer error anywhere. The
    // totality test below this function is what makes that impossible to
    // repeat.
    AccountGroup(
      id: 'property',
      title: 'Things you own',
      accounts: a.where((Account x) => x.kind == AccountKind.property).toList(),
    ),
    AccountGroup(
      id: 'receivable',
      title: 'Receivables',
      accounts: a
          .where((Account x) => x.kind == AccountKind.receivable)
          .toList(),
    ),
  ];
  return groups.where((AccountGroup g) => g.accounts.isNotEmpty).toList();
}

/// The three liability groups, in the prototype's own order.
List<AccountGroup> groupLiabilities(List<Account> accounts) {
  final List<Account> l = liabilitiesOf(accounts);
  final List<AccountGroup> groups = <AccountGroup>[
    AccountGroup(
      id: 'credit',
      title: 'Credit Cards',
      accounts: l.where((Account x) => x.kind == AccountKind.credit).toList(),
    ),
    AccountGroup(
      id: 'loan',
      title: 'Loans',
      accounts: l.where((Account x) => x.kind == AccountKind.loan).toList(),
    ),
    AccountGroup(
      id: 'mortgage',
      title: 'Mortgages',
      accounts: l.where((Account x) => x.kind == AccountKind.mortgage).toList(),
    ),
  ];
  return groups.where((AccountGroup g) => g.accounts.isNotEmpty).toList();
}

/// How much of a card's limit is used, as a whole percent, or null when the
/// account is not a credit card.
///
/// The prototype falls back to a 40,000 limit when a card has none recorded,
/// and that fallback is NOT ported. A made up limit produces a made up
/// percentage, and on this screen that percentage is coloured red or green
/// and read as advice. Null means "we do not know", and the screen says so
/// instead of guessing.
int? creditUtilization(Account account) {
  if (account.kind != AccountKind.credit) return null;
  final Money? limit = account.creditLimit;
  if (limit == null || !limit.isPositive) return null;
  // Converted through pesos because the FX rate is a double, so the result
  // is a double either way. The round back to centavos is what Money is for.
  final Money limitInPhp = Money.fromDouble(
    convertToPhp(limit.pesos, account.currency),
  );
  if (!limitInPhp.isPositive) return null;
  return (account.balanceInPhp.centavos / limitInPhp.centavos * 100).round();
}

/// The threshold the prototype colours red. Thirty percent is the figure
/// credit scoring models are usually described with, and the screen labels it
/// rather than just turning red, so it teaches instead of alarming.
const int highUtilizationPercent = 30;

bool isHighUtilization(Account account) {
  final int? u = creditUtilization(account);
  return u != null && u > highUtilizationPercent;
}

/// The institution short codes, ported verbatim from the prototype's
/// computeMonogram. Kind wins over institution, so an MP2 account reads INV
/// rather than HDMF.
const Map<String, String> institutionMonograms = <String, String>{
  'BPI': 'BPI',
  'BDO': 'BDO',
  'Metrobank': 'MBTC',
  'RCBC': 'RC',
  'UnionBank': 'UB',
  'Security Bank': 'SB',
  'PNB': 'PNB',
  'EastWest': 'EW',
  'AUB': 'AUB',
  'LandBank': 'LB',
  'PSBank': 'PS',
  'China Bank': 'CB',
  'MariBank': 'MB',
  'GoTyme': 'GT',
  'Tonik': 'TK',
  'CIMB': 'CIMB',
  'Komo': 'KM',
  'DiskarTech': 'DT',
  'Netbank': 'NB',
  'UNO Digital Bank': 'UNO',
  'OwnBank': 'OB',
  'TikTok': 'TK',
  'Atome': 'AT',
  'Pag-IBIG': 'HDMF',
  'SSS': 'SSS',
  'Cash': '₱',
};

/// The two-or-so letters drawn on the account's tile when there is no logo.
String computeMonogram(String institution, AccountKind kind, String name) {
  switch (kind) {
    case AccountKind.gcash:
      return 'GC';
    case AccountKind.maya:
      return 'MY';
    case AccountKind.investment:
      return 'INV';
    case AccountKind.receivable:
      return 'REC';
    case AccountKind.mortgage:
      return 'MORT';
    case AccountKind.loan:
      return 'LOAN';
    case AccountKind.property:
      return 'OWN';
    case AccountKind.cash:
    case AccountKind.bank:
    case AccountKind.debit:
    case AccountKind.credit:
      break;
  }
  final String? byInstitution = institutionMonograms[institution];
  if (byInstitution != null) return byInstitution;
  final String trimmed = name.trim();
  if (trimmed.isEmpty) return 'AC';
  final String head = trimmed.length >= 2 ? trimmed.substring(0, 2) : trimmed;
  return head.toUpperCase();
}

/// Everything the Accounts hero card shows, computed once.
class AccountsSummary {
  const AccountsSummary({
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.assetCount,
    required this.liabilityCount,
  });

  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final int assetCount;
  final int liabilityCount;
}

/// Net worth from ACCOUNTS ALONE.
///
/// This deliberately does NOT add the debt register. This screen is a list of
/// accounts with its own total, and the debt register sits below it as its
/// own card with its own figures. Two cards, two questions, and the screen
/// says which is which rather than quietly producing a third number that
/// matches neither.
///
/// THIS COMMENT USED TO CLAIM THAT "Reports' Position tab counts debts as
/// well, because a balance sheet has to". It does not, and never has:
/// `computePosition` filters `accounts` by `liabilityKinds` and reads no
/// other collection. Measured on the sample ledger, Position reports 399,200
/// of liabilities while the Debt register holds 17,350 and the instalment
/// plans hold 50,950.35, none of which appear. So the balance sheet
/// understates what is owed by everything a person entered on the Debt or
/// Plans screens rather than as an account.
///
/// The sentence is left here, named as false, rather than quietly deleted,
/// because it is the likeliest reason nobody looked for years: a reader
/// checking whether debts were on the balance sheet found a confident
/// statement that they were. Putting debts on the balance sheet moves a
/// figure people already read, so it is a founder decision and is tracked as
/// one; this correction is only about the comment no longer lying.
AccountsSummary summarize(List<Account> accounts) {
  final List<Account> a = assetsOf(accounts);
  final List<Account> l = liabilitiesOf(accounts);
  final double assets = accountsTotalPhp(a);
  final double liabilities = accountsTotalPhp(l);
  return AccountsSummary(
    totalAssets: assets,
    totalLiabilities: liabilities,
    netWorth: assets - liabilities,
    assetCount: a.length,
    liabilityCount: l.length,
  );
}

/// The last four digits of a stored card number, and NEVER any more than that.
///
/// This lives with the DATA rather than with the card that draws it, because
/// it turned out to be a rule about what may be stored and not only about what
/// may be shown. Two defects, a week apart, both came from treating it as
/// presentation:
///
///  1. The back of the card listed `account.accountNumber` straight out of
///     storage while the front masked it, so a card recorded in full printed
///     all sixteen digits on a screen people open in public.
///  2. The account form was labelled "last four digits" and accepted anything,
///     so somebody pasting a full number saw a masked card and concluded four
///     digits were what got kept. The masking made that MORE convincing.
///
/// Returns null rather than a partial mask when there is nothing usable, so a
/// caller can leave the row out entirely instead of drawing an empty one.
String? maskedTail(String? stored) {
  if (stored == null) return null;
  final String digits = stored.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 4) return null;
  return digits.substring(digits.length - 4);
}

/// The number in card groups: `••••  ••••  ••••  6789`.
///
/// The grouping is what makes it read as a card rather than as a code. A
/// number too short to have a meaningful tail masks completely instead of
/// showing what little was typed.
String pannedNumber(String? stored) =>
    '••••  ••••  ••••  ${maskedTail(stored) ?? '••••'}';

/// What may be WRITTEN to the file for a card number: never more than the last
/// four digits, and never more than the person actually typed.
///
/// Deliberately a different rule from [maskedTail], which is about DISPLAY.
/// maskedTail insists on a full four, because "•••• 88" is not a tail anybody
/// can identify a card by, so it would rather draw nothing. Storage has the
/// opposite duty: whatever the person typed is theirs, and silently dropping a
/// two digit entry on save is a small data loss that they would discover only
/// by noticing something missing later.
///
/// So this caps, and never discards. Returns null only for genuinely nothing.
String? cardTailForStorage(String? typed) {
  if (typed == null) return null;
  final String digits = typed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return digits.length > 4 ? digits.substring(digits.length - 4) : digits;
}
