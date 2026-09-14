// Accounts. Question 2 of the five in 01-vision.md: what do I own and owe?
//
// Accounts, not Wallets. See D3, and the comment on NavBar.tabs.
//
// The screen leads with NET WORTH and then answers "where is it" by kind. That
// order is the whole point: a list of balances is a filing cabinet, and one
// number with the list under it is an answer.
//
// Every figure on this screen comes from the golden locked engine. Nothing
// here adds, subtracts or rounds money. `netWorthParts` produces the hero and
// its sentence, `resolveKind` decides which section a row belongs to, and
// `initialsFor` makes the monogram. This file groups and paints, and that is
// deliberately all it does.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/account_taxonomy.dart';
import '../../core/money/format.dart';
import '../../core/money/institutions.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../core/money/statements.dart' show netWorthParts, trackedRemaining;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final groups = groupAccounts(data);
    final parts = netWorthParts(data);
    final debt = debtTotals(data);

    if (groups.isEmpty && !debt.any) {
      return const Screen(
        children: [
          SizedBox(height: 14),
          ScreenTitle(
            title: 'Accounts',
            sub: 'Cash, bank, e-wallet, credit, and both directions of debt.',
          ),
          SizedBox(height: 20),
          EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No accounts yet',
            body:
                'Add where your money actually sits and this screen leads with '
                'your net worth.',
          ),
        ],
      );
    }

    return Screen(
      children: [
        const SizedBox(height: 14),
        const ScreenTitle(
          title: 'Accounts',
          sub: 'Cash, bank, e-wallet, credit, and both directions of debt.',
        ),
        const SizedBox(height: 18),

        // The hero. One number, and one sentence that says what it is made of,
        // because a net worth with no parts shown is a number you cannot check.
        _NetWorth(parts: parts),
        const SizedBox(height: 22),

        for (final g in groups) ...[
          Head(title: g.label),
          const SizedBox(height: 8),
          Group(
            children: [
              for (final a in g.accounts)
                _AccountRow(account: a, category: g.id),
            ],
          ),
          const SizedBox(height: 18),
        ],

        if (debt.any) ...[
          const Head(title: 'Debt', action: 'Open'),
          const SizedBox(height: 8),
          Group(
            children: [
              ItemRow(
                icon: Icons.call_made_rounded,
                title: 'You owe',
                sub: debt.owedCount == 1
                    ? '1 open debt'
                    : '${debt.owedCount} open debts',
                amount: formatMoney(debt.owed),
                tone: Tone.owe,
              ),
              ItemRow(
                icon: Icons.call_received_rounded,
                title: 'Owed to you',
                sub: debt.dueCount == 1
                    ? '1 person owes you'
                    : '${debt.dueCount} people owe you',
                amount: formatMoney(debt.due),
                tone: Tone.good,
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

/// The hero panel: net worth, and the sentence that makes it checkable.
class _NetWorth extends StatelessWidget {
  const _NetWorth({required this.parts});
  final Map<String, dynamic> parts;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final assets = amountOf(parts['assets']);
    final liabilities = amountOf(parts['liabilities']);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net worth', style: TypeScale.quiet(skin.text3)),
          const SizedBox(height: 6),
          Text(
            formatMoney(amountOf(parts['netWorth'])),
            style: TypeScale.hero(skin.text),
          ),
          const SizedBox(height: 8),
          Text(
            'Assets ${formatMoney(assets)} · '
            'Debts ${formatMoney(liabilities)}',
            style: TypeScale.subtitle(skin.text2),
          ),
        ],
      ),
    );
  }
}

/// One account row. Monogram, name, and for credit the utilisation bar.
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account, required this.category});
  final Map<String, dynamic> account;
  final String category;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final cat = categoryById(category);
    final store = cat?.store ?? AccountStore.accounts;
    final name = (account['name'] ?? '').toString();
    final amount = rowAmount(account, store);
    final limit = amountOf(account['creditLimit']);
    final owed = cat?.cls == AccountClass.liability;

    final row = ItemRow(
      monogram: monogramFor(account),
      title: name,
      sub: accountKindLabel(account, store),
      amount: formatMoney(amount),
      onTap: () => context.push('/account/${account['id']}'),
      // A liability is money OWED, so it takes the owe colour. Cash does NOT
      // take the good colour: a bank balance is not a win, it is just a fact,
      // and colouring every amount would leave colour meaning nothing.
      tone: owed ? Tone.owe : Tone.plain,
    );

    if (limit <= 0) return row;

    // Utilisation, drawn only where there is a limit to be a fraction of.
    final used = (amount / limit).clamp(0.0, 1.0);
    final dueDay = account['statementDueDay'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ThinBar(fraction: used),
              const SizedBox(height: 7),
              Text(
                '${(used * 100).round()}% of ${formatMoney(limit)} limit'
                '${dueDay is num ? ' · due ${_ordinalMonthDay(dueDay.toInt())}' : ''}',
                style: TypeScale.caption(skin.text3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "the 3rd", as a day of the month.
///
/// Deliberately NOT a date: the stored value is a day number that repeats every
/// month, and printing it as a full date would invent a month the data never
/// said. screen_readability's rule about never showing a raw stored value is
/// the same rule seen from the other side.
String _ordinalMonthDay(int day) {
  final suffix = (day % 100 >= 11 && day % 100 <= 13)
      ? 'th'
      : switch (day % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return 'the $day$suffix';
}

/// One section of the accounts list: a taxonomy category and its rows.
class AccountGroup {
  const AccountGroup(this.id, this.label, this.accounts);
  final String id;
  final String label;
  final List<Map<String, dynamic>> accounts;
}

/// Group the accounts by taxonomy category, in the registry's own order.
///
/// Pure and top level so a test can call it without pumping a widget. The
/// ORDER comes from `accountCategories` rather than from a list written here,
/// so a new category added to the taxonomy appears on this screen instead of
/// silently vanishing into no section at all.
List<AccountGroup> groupAccounts(Map<String, dynamic> state) {
  final byCategory = <String, List<Map<String, dynamic>>>{};

  void take(String collection, AccountStore store) {
    for (final r in (state[collection] as List? ?? const [])) {
      if (r is! Map) continue;
      final row = r.cast<String, dynamic>();
      final id = resolveKind(row, store).category.id;
      byCategory.putIfAbsent(id, () => []).add(row);
    }
  }

  // THREE collections, not one, and that is the correction the first render
  // forced. `accounts` holds only cash equivalents; `assets` holds investments
  // and property; `debts` holds credit cards, loans and installments. A screen
  // that reads `accounts` alone puts a credit card in "Cash and e-wallets",
  // gives it no utilisation bar, and ADDS it to assets instead of subtracting
  // it. The render said the founder was better off than they were.
  take('accounts', AccountStore.accounts);
  take('assets', AccountStore.assets);
  take('debts', AccountStore.debts);

  return [
    for (final c in accountCategories)
      if (byCategory[c.id] != null && !rollsIntoDebtSummary(c.id))
        AccountGroup(c.id, c.label, byCategory[c.id]!),
  ];
}

/// Categories that do NOT get their own section, because the Debt summary
/// already counts them.
///
/// 04-screens.md names the kind sections exactly: "Cash and e-wallets, Bank,
/// Credit", and then a separate "Debt" head with two rows. Loans and
/// installments are in neither list, so they belong to the summary. Giving
/// them a section as well showed a personal loan twice on one screen, once as
/// its own row and once inside "You owe", which is the kind of thing that
/// makes somebody think they owe it twice.
///
/// Credit cards are the exception ON PURPOSE: they are the only liability with
/// a limit, so they are the only one with a utilisation bar to show, and the
/// spec gives them a row for exactly that reason.
bool rollsIntoDebtSummary(String categoryId) =>
    categoryById(categoryId)?.cls == AccountClass.liability &&
    categoryId != 'credit';

/// What a row's money is called, which depends on the collection it came from.
///
/// Not a convenience. Reading `balance` off a debts row gives zero, and a
/// screen that shows a credit card as nothing owed is worse than one that
/// crashes. The mapping mirrors `assetLiabilityBreakdown` in the engine.
double rowAmount(Map<String, dynamic> row, AccountStore store) =>
    switch (store) {
      AccountStore.accounts => amountOf(row['balance']),
      AccountStore.assets => amountOf(row['value']),
      AccountStore.debts => amountOf(row['remaining']),
    };

/// What the two debt rows say.
class DebtTotals {
  const DebtTotals(this.owed, this.owedCount, this.due, this.dueCount);

  /// What the founder owes other people.
  final double owed;
  final int owedCount;

  /// What other people owe the founder.
  final double due;
  final int dueCount;

  /// Whether the Debt section has anything to say at all. A section of two
  /// zeroes claims the founder is square with the world, which is a different
  /// statement from having never recorded a debt.
  bool get any => owedCount > 0 || dueCount > 0;
}

/// Both directions, from the stored rows.
///
/// Totals on `remaining`, never on `principal`. That distinction is not
/// cosmetic: principal is what was borrowed and remaining is what is left, and
/// the backup round trip test is where the difference was found the hard way.
DebtTotals debtTotals(Map<String, dynamic> state) {
  // Receivables and payables are keyed on `amount` MINUS payments, and only
  // count when `cashLeg` is true, meaning real money left the founder's
  // pocket. Both rules live in trackedRemaining, which is golden locked, so it
  // is called rather than reimplemented. The first version of this function
  // summed `remaining` on all three collections; receivables have no such key,
  // so the row contributed nothing and the render was ₱1,800 short with no
  // test able to see it.
  //
  // `debts` really is keyed on `remaining`, which is what netWorthParts reads.
  // The two collections genuinely disagree about their key names, and that is
  // the stored schema rather than a choice made here.
  final payables = trackedRemaining(state['payables']);
  final receivables = trackedRemaining(state['receivables']);

  // Only the debts that do NOT get their own section, or the credit card
  // shown two sections above would be counted here as well and the founder
  // would read the same card twice.
  var debts = 0.0;
  var debtCount = 0;
  for (final r in (state['debts'] as List? ?? const [])) {
    if (r is! Map) continue;
    final row = r.cast<String, dynamic>();
    final id = resolveKind(row, AccountStore.debts).category.id;
    if (!rollsIntoDebtSummary(id)) continue;
    debts += amountOf(row['remaining']);
    debtCount++;
  }

  int countOf(String collection) =>
      (state[collection] as List? ?? const []).whereType<Map>().length;

  return DebtTotals(
    debts + payables,
    debtCount + countOf('payables'),
    receivables,
    countOf('receivables'),
  );
}

/// The monogram for a row: the institution's initials where there is one, the
/// account's own name otherwise, so a custom account gets the same treatment
/// as a listed bank.
String monogramFor(Map<String, dynamic> account) {
  final inst = institutionById(account['institutionId'] as String?);
  if (inst != null) return inst.initials;
  return initialsFor((account['name'] ?? '').toString());
}

/// The quiet line under an account's name: what kind of thing it is.
String? accountKindLabel(Map<String, dynamic> account, AccountStore store) {
  final k = resolveKind(account, store);
  final inst = institutionById(account['institutionId'] as String?);
  // The institution is dropped when it is already the account's own name,
  // because "BPI" over "BPI, Savings account" is not information, it is an
  // echo. The first render showed exactly that.
  final name = (account['name'] ?? '').toString().trim().toLowerCase();
  final echo = inst != null && inst.displayName.trim().toLowerCase() == name;
  return inst == null || echo
      ? k.subtype.label
      : '${inst.displayName} · ${k.subtype.label}';
}
