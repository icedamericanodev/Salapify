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
double accountsTotalPhp(Iterable<Account> accounts) =>
    accounts.fold<double>(0, (double sum, Account a) => sum + a.balanceInPhp);

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
  final double? limit = account.creditLimit;
  if (limit == null || limit <= 0) return null;
  return (account.balanceInPhp / convertToPhp(limit, account.currency) * 100)
      .round();
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
/// This deliberately does NOT add the debt register. Reports' Position tab
/// counts debts as well, because a balance sheet has to; this screen is a
/// list of accounts with its own total, and the debt register sits below it
/// as its own card with its own figures. Two cards, two questions, and the
/// screen says which is which rather than quietly producing a third number
/// that matches neither.
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
