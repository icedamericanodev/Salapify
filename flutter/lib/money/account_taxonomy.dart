// What KIND of financial thing is this, said once, in one place.
//
// Delivery A of docs/features/unified-financial-accounts.md. No UI depends on
// this yet, deliberately: it is the cheapest possible place to discover the
// data design is wrong.
//
// The one fact that shapes everything here: `kind` on an account is CLAMPED to
// exactly four legacy values on every load and every save
// (data/backup.dart), so anything else is silently rewritten to 'cash'. A
// payroll account stored as kind:'payroll' would come back as cash, with no
// error, permanently. So `kind` is left exactly as it is and the real answer
// lives in a NEW field. Every existing engine keeps working untouched, and the
// silent-rewrite risk disappears rather than being managed.
//
// Two more rules that are not style:
//
// STABLE IDS, NEVER LABELS. 'cash_equivalents' is a contract and never
// changes; the words on screen are a product decision and will. Storing a
// label means a copy edit silently reclassifies somebody's accounts.
//
// DERIVED, NEVER BACKFILLED. An account with no subtype is READ as its legacy
// equivalent at display time. Nothing is written over user data, so a backup
// restored from the React Native app tomorrow reads correctly without ever
// having been touched, and there is no migration to get wrong.

/// Which side of net worth a thing sits on. Liabilities are already subtracted
/// by netWorthParts, so nothing is ever modelled as a negative balance.
enum AccountClass { asset, liability }

/// Which of the three existing collections a thing is stored in.
///
/// The unification is in the UI only. Storage stays split, because the
/// collections are not interchangeable: an account can be spent from and
/// transferred between, an asset is a value with no transactions, and a debt
/// has an interest engine, due dates and payment history. Moving a row between
/// them would orphan every ledger entry and payment pointing at it.
enum AccountStore { accounts, assets, debts }

class AccountSubtype {
  /// Stored. Never changes.
  final String id;

  /// Shown. Free to change.
  final String label;

  /// One line under the label in the picker. Plain English, no jargon.
  final String hint;

  /// The legacy `kind` this maps onto, for subtypes stored in `accounts`.
  /// Null everywhere else, because assets and debts have no clamped kind.
  final String? legacyKind;

  /// True when picking this subtype should ask which bank or wallet it is.
  final bool hasInstitution;

  const AccountSubtype({
    required this.id,
    required this.label,
    required this.hint,
    this.legacyKind,
    this.hasInstitution = false,
  });
}

class AccountCategory {
  final String id;
  final String label;
  final AccountClass cls;
  final AccountStore store;
  final List<AccountSubtype> subtypes;

  const AccountCategory({
    required this.id,
    required this.label,
    required this.cls,
    required this.store,
    required this.subtypes,
  });
}

const _cashEquivalents = AccountCategory(
  id: 'cash_equivalents',
  label: 'Cash and e-wallets',
  cls: AccountClass.asset,
  store: AccountStore.accounts,
  subtypes: [
    AccountSubtype(
      id: 'cash_on_hand',
      label: 'Cash on hand',
      hint: 'Money in your wallet or at home.',
      legacyKind: 'cash',
    ),
    AccountSubtype(
      id: 'savings_account',
      label: 'Savings account',
      hint: 'A bank account you save in.',
      legacyKind: 'savings',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'checking_account',
      label: 'Checking account',
      hint: 'A bank account you pay from.',
      legacyKind: 'checking',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'payroll_account',
      label: 'Payroll account',
      hint: 'Where your salary lands.',
      // checking, not a new kind. This row is the whole reason for DECISION 2.
      legacyKind: 'checking',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'digital_bank',
      label: 'Digital bank',
      hint: 'Maya Bank, GoTyme, SeaBank and the like.',
      legacyKind: 'savings',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'ewallet',
      label: 'E-wallet',
      hint: 'GCash, Maya, GrabPay, ShopeePay.',
      legacyKind: 'ewallet',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'time_deposit',
      label: 'Time deposit',
      hint: 'Locked in for a term, still yours.',
      legacyKind: 'savings',
      hasInstitution: true,
    ),
  ],
);

const _investments = AccountCategory(
  id: 'investments',
  label: 'Investments',
  cls: AccountClass.asset,
  store: AccountStore.assets,
  subtypes: [
    AccountSubtype(
      id: 'stocks',
      label: 'Stocks',
      hint: 'Shares you hold.',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'mutual_fund',
      label: 'Mutual fund or UITF',
      hint: 'A pooled fund managed for you.',
      hasInstitution: true,
    ),
    AccountSubtype(id: 'bonds', label: 'Bonds', hint: 'Government or company.'),
    AccountSubtype(
      id: 'crypto',
      label: 'Crypto',
      hint: 'Whatever you actually hold.',
    ),
    AccountSubtype(
      id: 'retirement',
      label: 'Retirement fund',
      hint: 'Pag-IBIG MP2, PERA, a company plan.',
      hasInstitution: true,
    ),
  ],
);

const _property = AccountCategory(
  id: 'property',
  label: 'Property and things',
  cls: AccountClass.asset,
  store: AccountStore.assets,
  subtypes: [
    AccountSubtype(
      id: 'real_estate',
      label: 'Real estate',
      hint: 'A house, a lot, a unit.',
    ),
    AccountSubtype(
      id: 'vehicle',
      label: 'Vehicle',
      hint: 'Car, motorcycle, tricycle.',
    ),
    AccountSubtype(
      id: 'equipment',
      label: 'Equipment',
      hint: 'Tools, a laptop, gear you would sell.',
    ),
    AccountSubtype(
      id: 'jewellery',
      label: 'Jewellery',
      hint: 'Gold, watches, anything with resale value.',
    ),
    AccountSubtype(
      id: 'other_asset',
      label: 'Something else',
      hint: 'Anything you own that has value.',
    ),
  ],
);

const _credit = AccountCategory(
  id: 'credit',
  label: 'Credit cards',
  cls: AccountClass.liability,
  store: AccountStore.debts,
  subtypes: [
    AccountSubtype(
      id: 'credit_card',
      label: 'Credit card',
      hint: 'Has a statement date and a minimum payment.',
      hasInstitution: true,
    ),
  ],
);

const _loans = AccountCategory(
  id: 'loans',
  label: 'Loans',
  cls: AccountClass.liability,
  store: AccountStore.debts,
  subtypes: [
    AccountSubtype(
      id: 'personal_loan',
      label: 'Personal loan',
      hint: 'From a bank or a lending company.',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'salary_loan',
      label: 'Salary loan',
      hint: 'SSS, GSIS, Pag-IBIG, or through work.',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'auto_loan',
      label: 'Car or motorcycle loan',
      hint: 'The vehicle is the collateral.',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'home_loan',
      label: 'Housing loan',
      hint: 'A mortgage on a home or lot.',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'business_loan',
      label: 'Business loan',
      hint: 'Borrowed for a business.',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'other_loan',
      label: 'Other loan',
      hint: 'Anything else you are paying back.',
    ),
  ],
);

const _installments = AccountCategory(
  id: 'installments',
  label: 'Installments',
  cls: AccountClass.liability,
  store: AccountStore.debts,
  subtypes: [
    AccountSubtype(
      id: 'bnpl',
      label: 'Buy now, pay later',
      hint: 'Billease, Home Credit, a checkout plan.',
      hasInstitution: true,
    ),
    AccountSubtype(
      id: 'installment_plan',
      label: 'Installment plan',
      hint: 'Paid in fixed amounts over months.',
      hasInstitution: true,
    ),
  ],
);

/// Every category, in the order a picker should show them.
///
/// Deliberately excludes person-to-person utang. Money a friend lent you is a
/// relationship, not an account: it lives in `payables`, it is created through
/// the Utang tab where the person is the point, and it has no institution, no
/// interest and no statement date. Putting it in this list would make the flow
/// ask four questions that have no answer.
const List<AccountCategory> accountCategories = [
  _cashEquivalents,
  _investments,
  _property,
  _credit,
  _loans,
  _installments,
];

/// Categories on one side of net worth.
List<AccountCategory> categoriesFor(AccountClass cls) =>
    accountCategories.where((c) => c.cls == cls).toList();

AccountCategory? categoryById(String? id) {
  for (final c in accountCategories) {
    if (c.id == id) return c;
  }
  return null;
}

AccountSubtype? subtypeById(String? id) {
  for (final c in accountCategories) {
    for (final s in c.subtypes) {
      if (s.id == id) return s;
    }
  }
  return null;
}

AccountCategory? categoryOfSubtype(String? id) {
  for (final c in accountCategories) {
    for (final s in c.subtypes) {
      if (s.id == id) return c;
    }
  }
  return null;
}

/// What one stored row IS, resolved.
class ResolvedKind {
  final AccountClass cls;
  final AccountCategory category;
  final AccountSubtype subtype;

  /// True when the row carries no stored subtype and this was worked out from
  /// its legacy fields. Nothing is written back; screens can use it to know
  /// they are showing a guess rather than a choice.
  final bool derived;

  const ResolvedKind({
    required this.cls,
    required this.category,
    required this.subtype,
    required this.derived,
  });
}

/// The legacy `kind` on an account, read the way backup.dart clamps it.
const Map<String, String> _kindToSubtype = {
  'cash': 'cash_on_hand',
  'savings': 'savings_account',
  'checking': 'checking_account',
  'ewallet': 'ewallet',
};

/// The legacy `kind` on an ASSET.
///
/// Assets have a kind too, and it is NOT clamped: it is whatever the Accounts
/// screen's picker wrote (screens/accounts.dart, `_assetKinds`). The first
/// version of this file said assets "carry no type at all" and derived every
/// one of them to "something else", which would have read a crypto holding and
/// a house as the same thing on the very first screen that grouped them. The
/// comment was written from memory; the picker was three files away.
const Map<String, String> _assetKindToSubtype = {
  'crypto': 'crypto',
  'stocks': 'stocks',
  // Pag-IBIG MP2 is a retirement fund, and the picker's label for it is the
  // one people actually say.
  'mp2': 'retirement',
  'real estate': 'real_estate',
  'vehicle': 'vehicle',
  'other': 'other_asset',
};

/// What a stored row is, whether or not it has ever been classified.
///
/// [store] is which collection the row came out of, and it is required rather
/// than sniffed, because sniffing is how a debt with a `balance` key ends up
/// classified as a savings account.
///
/// A stored subtype wins, but only if it BELONGS to that collection. A row in
/// `accounts` carrying subtype 'real_estate' is not a house that can be spent
/// from; it is a corrupt or hand-edited backup, and trusting it would put a
/// property row in the spendable-cash total. In that case the legacy
/// derivation is used instead, which is always right about the collection.
ResolvedKind resolveKind(dynamic row, AccountStore store) {
  final m = row is Map ? row : const {};
  final stored = m['subtype'];
  if (stored is String && stored.isNotEmpty) {
    final s = subtypeById(stored);
    final c = categoryOfSubtype(stored);
    if (s != null && c != null && c.store == store) {
      return ResolvedKind(
        cls: c.cls,
        category: c,
        subtype: s,
        derived: false,
      );
    }
  }
  return _derive(m, store);
}

ResolvedKind _resolved(String subtypeId, {required bool derived}) {
  final s = subtypeById(subtypeId)!;
  final c = categoryOfSubtype(subtypeId)!;
  return ResolvedKind(cls: c.cls, category: c, subtype: s, derived: derived);
}

ResolvedKind _derive(Map row, AccountStore store) {
  switch (store) {
    case AccountStore.accounts:
      // kind is already clamped to these four by the time anything reads it,
      // so the fallback is for a row that never went through sanitizeData.
      return _resolved(
        _kindToSubtype[row['kind']] ?? 'cash_on_hand',
        derived: true,
      );
    case AccountStore.assets:
      // Unlike an account's, this kind is a free string and nothing clamps it,
      // so an unrecognised value is entirely possible and lands on "something
      // else", which is honest rather than a guess dressed up as a fact.
      final k = row['kind'];
      return _resolved(
        (k is String ? _assetKindToSubtype[k] : null) ?? 'other_asset',
        derived: true,
      );
    case AccountStore.debts:
      // `type` is a free string whose only branched-on value is 'credit card'
      // (money/debts.dart). Matching it exactly, because that string is what
      // the payment engine already keys on.
      final t = row['type'];
      return _resolved(
        t == 'credit card' ? 'credit_card' : 'other_loan',
        derived: true,
      );
  }
}

bool _isFourDigits(dynamic v) =>
    v is String && RegExp(r'^\d{4}$').hasMatch(v);

/// The new fields, validated, as keys to merge into a stored row.
///
/// CONDITIONAL, every one of them. The backup goldens compare key sets
/// STRICTLY against fixtures generated from the React Native app, and those
/// fixtures will never carry `subtype` or `institutionId`. So a key appears
/// only when the row genuinely has a usable value, exactly the pattern
/// `paluwagans`, `steadyPay` and `quickAddsEdited` already use.
///
/// Junk is DROPPED rather than corrected. A subtype that does not exist, a
/// last4 that is not four digits, a currency code that is not three letters:
/// all of it vanishes, and the row falls back to its legacy derivation, which
/// is always safe. Correcting junk means guessing what somebody meant about
/// their own money.
///
/// Never accepted, in any field, ever: full account numbers, card numbers,
/// CVV, PIN, OTP, username, password. `last4` is the only digits this feature
/// stores and it is exactly four.
Map<String, dynamic> taxonomyKeys(dynamic row, AccountStore store) {
  final m = row is Map ? row : const {};
  final out = <String, dynamic>{};

  final stored = m['subtype'];
  if (stored is String) {
    final c = categoryOfSubtype(stored);
    if (c != null && c.store == store) {
      out['subtype'] = stored;
      out['category'] = c.id;
      out['accountClass'] = c.cls == AccountClass.asset ? 'asset' : 'liability';
    }
  }

  final inst = m['institutionId'];
  if (inst is String && inst.isNotEmpty) out['institutionId'] = inst;
  final instName = m['institutionName'];
  if (instName is String && instName.trim().isNotEmpty) {
    out['institutionName'] = instName.trim();
  }

  final cur = m['currencyCode'];
  if (cur is String && RegExp(r'^[A-Za-z]{3}$').hasMatch(cur)) {
    out['currencyCode'] = cur.toUpperCase();
  }

  if (_isFourDigits(m['last4'])) out['last4'] = m['last4'];

  // Both default to the safe answer when absent, so only the NON-default is
  // ever written. A row that counts and is not archived carries neither key,
  // which is every row that has ever existed.
  if (m['includeInNetWorth'] == false) out['includeInNetWorth'] = false;
  if (m['isArchived'] == true) out['isArchived'] = true;

  for (final k in const ['createdAt', 'updatedAt']) {
    final v = m[k];
    if (v is String && v.isNotEmpty) out[k] = v;
  }
  return out;
}

/// Does this row count toward net worth?
///
/// Absent means yes, for both keys, so every row that predates this feature
/// counts exactly as it always did.
bool countsInNetWorth(dynamic row) {
  final m = row is Map ? row : const {};
  return m['includeInNetWorth'] != false && m['isArchived'] != true;
}
