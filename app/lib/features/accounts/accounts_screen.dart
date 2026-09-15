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
import '../../core/state/visibility.dart';
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../debt/debt_screen.dart' show debtRoutePath;
import '../settings/settings_screen.dart' show settingsRoutePath;
import 'account_editor.dart';
import 'transfer_sheet.dart' show showTransferSheet;

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final groups = groupAccounts(data);
    final hiddenGroups = groupAccounts(data, hidden: true);
    // THE ENGINE STILL DOES THE SUM. `ownedOnly` removes the rows the user
    // said are not theirs and hands the rest to the same golden locked
    // function; nothing on this screen subtracts anything from a total. See
    // core/state/visibility.dart for why it is done this way round.
    final parts = netWorthParts(ownedOnly(data));
    final debt = debtTotals(data);
    final excluded = Excluded.of(data);

    // `hiddenGroups.isEmpty` IS PART OF THIS GUARD, and leaving it out was a
    // real defect rather than a tidiness point. Without it: install the app,
    // add one account because the empty state's own button says to, hide it,
    // and this branch renders "No accounts yet" over a ledger with your money
    // in it. The account is on disk, still counted in net worth, and there is
    // no widget left that can draw it, because the only route to account
    // detail is a row in one of these lists.
    //
    // It is worse than a wrong heading. The empty branch carries no Settings
    // action and the "Your data" row is below this return, so that state also
    // has no Backup and no Restore, which is the last recovery mechanism an
    // offline app has. Found by the recovery pass on the first build of this
    // feature, by running it rather than by reading it.
    if (groups.isEmpty && hiddenGroups.isEmpty && !debt.any) {
      return Screen(
        children: [
          const SizedBox(height: 14),
          const ScreenTitle(
            title: 'Accounts',
            sub: 'Cash, bank, e-wallet, credit, and both directions of debt.',
          ),
          const SizedBox(height: 20),
          const EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No accounts yet',
            body:
                'Add where your money actually sits and this screen leads with '
                'your net worth.',
          ),
          const SizedBox(height: 14),
          // The button that instruction has been asking for since the screen
          // was built. An empty state whose instruction cannot be followed is
          // the same defect as a sentence pointing at a screen that cannot do
          // the thing.
          PillButton(
            label: 'Add your first account',
            icon: Icons.add_rounded,
            onTap: () => showAccountEditor(context),
          ),
        ],
      );
    }

    return Screen(
      children: [
        const SizedBox(height: 14),
        // Settings is reachable from the TOP, not only from a row at the
        // bottom. It was put at the bottom first, under the Debt section, and
        // the founder looked for it and reported "there is no backup and
        // settings in the accounts tab". They were looking at the screen: this
        // page is long enough that the bottom of it is two scrolls away, and a
        // backup control nobody can find is a backup nobody takes.
        ScreenTitle(
          title: 'Accounts',
          sub: 'Cash, bank, e-wallet, credit, and both directions of debt.',
          action: 'Settings',
          onAction: () => context.push(settingsRoutePath),
        ),
        const SizedBox(height: 14),
        PillButton(
          label: 'Add an account',
          icon: Icons.add_rounded,
          onTap: () => showAccountEditor(context),
        ),
        const SizedBox(height: 18),

        // The hero. One number, and one sentence that says what it is made of,
        // because a net worth with no parts shown is a number you cannot check.
        _NetWorth(parts: parts, excluded: excluded),
        const SizedBox(height: 22),

        for (final g in groups) ...[
          Head(
            title: g.label,
            // ON THE FIRST GROUP ONLY, so Accounts is where the founder
            // checked balances gets a second door to the same sheet Home
            // carries. Not a second full-width button under "Add an
            // account": two page actions stacked is worse than one, and Head
            // already has the room for a tappable word beside a title.
            action: g == groups.first && _canMove(data) ? 'Move money' : null,
            onAction: g == groups.first && _canMove(data)
                ? () => showTransferSheet(context)
                : null,
          ),
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
          // The Debt screen exists now (roadmap step 7), so this section leads
          // somewhere and says so. It carried "no action word, there is no
          // Debt screen to open yet" until that screen was built, which was
          // right at the time and would have quietly stayed wrong afterwards.
          Head(
            title: 'Debt',
            action: 'See all',
            onAction: () => context.push(debtRoutePath),
          ),
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
                onTap: () => context.push(debtRoutePath),
              ),
              ItemRow(
                icon: Icons.call_received_rounded,
                title: 'Owed to you',
                sub: debt.dueCount == 1
                    ? '1 person owes you'
                    : '${debt.dueCount} people owe you',
                amount: formatMoney(debt.due),
                tone: Tone.good,
                onTap: () => context.push(debtRoutePath),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],

        // NOTHING IS BOTH INVISIBLE AND UNREACHABLE. A hidden account is off
        // the lists above and still HERE, at the bottom, because the only way
        // back is through the account's own screen: an account nobody can find
        // again is an account nobody can un-hide, and a one way door on
        // somebody's own money is not a view preference.
        //
        // It sits below Debt and above the data section so the everyday
        // screen is unchanged for the people who never touch this, which is
        // almost everybody. There is no count-of-zero state: the heading only
        // exists once something is in it.
        if (hiddenGroups.isNotEmpty) ...[
          const Head(title: 'Hidden'),
          const SizedBox(height: 6),
          // The sentence that explains the gap between this screen's rows and
          // the number at the top of it. Without it, somebody hides an account
          // and the totals stop reconciling with the list for no stated
          // reason, which reads as the app losing money.
          // "ANY SPENDING MONEY IN HERE", not "this is left out of safe to
          // spend". Safe to spend only ever looked at cash, e-wallets and
          // checking, so hiding a savings pot, an investment or a credit card
          // changes that figure by nothing at all. The first version of this
          // sentence claimed otherwise in every case, which is a small lie
          // about money on a screen whose whole job is explaining a gap.
          //
          // IT ALSO BRANCHES ON THE THIRD STATE. A row with BOTH flags is
          // closed, and "still counted in your net worth" is simply false
          // about it. With one closed account the screen used to say, on one
          // pump, that 8,410.50 was not counted at the top and that hidden
          // money was still counted at the bottom, which is the exact reading
          // this sentence exists to prevent.
          _Quiet(hiddenCaption(hiddenGroups)),
          const SizedBox(height: 10),
          for (final g in hiddenGroups) ...[
            Group(
              children: [
                for (final a in g.accounts)
                  _AccountRow(account: a, category: g.id),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
        ],

        // Backup lives at the bottom of Accounts because this is the screen
        // about what you HAVE, and a copy of it is the only thing standing
        // between the founder and losing all of it. It is the last thing on
        // the page rather than the first because it is not a daily action.
        const Head(title: 'Your data'),
        const SizedBox(height: 8),
        Group(
          children: [
            ItemRow(
              icon: Icons.shield_outlined,
              title: 'Backup and settings',
              sub: 'Save a copy, or restore one',
              amount: '',
              onTap: () => context.push(settingsRoutePath),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

/// What the Hidden section says about the rows in it.
///
/// Top level and pure so it can be tested without pumping a screen, because
/// the thing that went wrong here is a SENTENCE and every wrong version of it
/// was a true-looking statement about somebody's money.
///
/// Three cases, because there are three states and one sentence cannot cover
/// them. "Still counted in your net worth" is true of a hidden row, false of a
/// Whether there are two or more accounts to move money between.
///
/// The SAME question `showTransferSheet` asks of `data['accounts']` before it
/// opens, so this button and that sheet's own no-destination dialog can never
/// disagree about whether the door should be here at all.
bool _canMove(Map<String, dynamic> data) =>
    (data['accounts'] is List ? data['accounts'] as List : const []).length >=
    2;

/// closed one (hidden AND not mine), and the screen showed both claims at once
/// when a single account carried both flags.
String hiddenCaption(List<AccountGroup> groups) {
  final rows = [for (final g in groups) ...g.accounts];
  final one = rows.length == 1;
  final back = one ? 'Tap it to bring it back.' : 'Tap one to bring it back.';

  final counted = rows.where(countsAsOwned).length;
  final closed = rows.length - counted;

  // "ANY SPENDING MONEY IN HERE", never "this is left out of safe to spend".
  // Safe to spend only ever looked at cash, e-wallets and checking, so hiding
  // a savings pot, an investment or a credit card changes that figure by
  // nothing at all. The first version claimed otherwise in every case.
  const spend =
      'Any spending money in here is left out of what is safe to spend.';

  if (closed == 0) {
    return 'Kept off the lists above. Still counted in your net worth. '
        '$spend $back';
  }
  if (counted == 0) {
    return one
        ? 'Kept off the lists above, and not counted as yours, so it is out '
              'of your net worth too. $back'
        : 'Kept off the lists above, and not counted as yours, so they are '
              'out of your net worth too. $back';
  }
  return 'Kept off the lists above. The ones still counted as yours are in '
      'your net worth; the rest are not. $spend $back';
}

/// The hero's sentence about money the user said is not theirs.
///
/// Three cases, because `fromNetWorth` is SIGNED and a single sentence built
/// from its absolute value lies in two of them.
///
/// The netting is correct for net worth and wrong for a sentence. Disown one
/// account of 8,410.50 and one credit card of 8,410.50 and the figure is
/// exactly zero, which rendered as "₱0.00 across 2 accounts is not counted":
/// a sentence that reads as a bug report. Disown a debt alone and the figure
/// is negative, and printing its absolute value says money LEFT when net worth
/// actually went up.
String notMineSentence(Excluded e) {
  final n = e.notMineCount;
  final subject = n == 1 ? '1 account' : '$n accounts';
  final amount = formatMoney(e.fromNetWorth.abs());

  // Assets only, the ordinary case: money on the books that is not theirs.
  if (e.fromNetWorth > 0) {
    return '$amount in $subject is not counted, because you said it is not '
        'yours.';
  }
  // Liabilities only. Disowning a debt lowers what is owed, so net worth is
  // HIGHER, and saying it plainly is the only way the figure can be checked.
  if (e.fromNetWorth < 0) {
    return n == 1
        ? 'One debt is not counted as yours, so this is $amount higher than '
              'what the list below adds up to.'
        : '$n debts are not counted as yours, so this is $amount higher than '
              'what the list below adds up to.';
  }
  // Both directions, netting to nothing. No amount, because there is no
  // amount: net worth is exactly what it would have been.
  return n == 1
      ? '1 account is not counted, because you said it is not yours.'
      : '$subject are not counted, because you said they are not yours.';
}

/// A caption paragraph sitting directly on the page, not inside a card.
class _Quiet extends StatelessWidget {
  const _Quiet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TypeScale.caption(context.skin.text2));
}

/// The hero panel: net worth, and the sentence that makes it checkable.
class _NetWorth extends StatelessWidget {
  const _NetWorth({required this.parts, required this.excluded});
  final Map<String, dynamic> parts;

  /// What the user has said is not theirs, so the hero can SAY so.
  final Excluded excluded;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // [parts] already arrived computed from the OWNED ledger, so these three
    // reads are reads and nothing else. No figure on this panel is adjusted
    // here, which is why the panel and the rows below it can never drift
    // apart by a rounding rule this file invented.
    final netWorth = amountOf(parts['netWorth']);
    final assets = amountOf(parts['assets']);
    final liabilities = amountOf(parts['liabilities']);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net worth', style: TypeScale.quiet(skin.text3)),
          const SizedBox(height: 6),
          Text(formatMoney(netWorth), style: TypeScale.hero(skin.text)),
          const SizedBox(height: 8),
          Text(
            'Assets ${formatMoney(assets)} · '
            'Debts ${formatMoney(liabilities)}',
            style: TypeScale.subtitle(skin.text2),
          ),
          // SURFACED, NEVER SILENT. Money that vanishes from a total without a
          // word is indistinguishable from money the app lost, and on an
          // offline app with no support channel there is nobody to ask. The
          // figure above is smaller than the rows below it add up to, and this
          // is the only sentence that explains the gap.
          if (excluded.anyNotMine) ...[
            const SizedBox(height: 10),
            Text(
              notMineSentence(excluded),
              style: TypeScale.caption(skin.text2),
            ),
          ],
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

    // MARKED ON THE ROW ITSELF, not only in the hero's sentence.
    //
    // The first render of this feature showed why. The hero read ₱33,930 and
    // said underneath that ₱8,410.50 in one account was not counted, which is
    // correct and complete. Two rows below it, GCash sat in Cash and e-wallets
    // showing ₱8,410.50 and looking exactly like every other account on the
    // screen. Somebody scanning the list, which is what a list is for, adds
    // those balances up, gets a different answer from the big number, and has
    // no way to tell WHICH row is the one the sentence meant.
    //
    // A hidden account needs no such mark: it is under a heading that says it.
    final sub = accountKindLabel(account, store);
    final label = isNotMine(account)
        ? '${sub ?? ''}${sub == null ? '' : ' · '}Not counted'
        : sub;

    final row = ItemRow(
      monogram: monogramFor(account),
      title: name,
      sub: label,
      amount: formatMoney(amount),
      // ENCODED. The id is stored data, and a restored or hand edited backup
      // can carry a slash, a hash or a question mark in it. Interpolated raw,
      // a slash splits the URI into segments no route matches and a tap on an
      // ordinary account row lands on an error page; a hash or a question mark
      // truncates the id and opens the WRONG account.
      onTap: () => context.push(
        '/account/${Uri.encodeComponent((account['id'] ?? '').toString())}',
      ),
      // A liability is money OWED, so it takes the owe colour. Cash does NOT
      // take the good colour: a bank balance is not a win, it is just a fact,
      // and colouring every amount would leave colour meaning nothing.
      tone: owed ? Tone.owe : Tone.plain,
    );

    if (limit <= 0) return row;

    // Utilisation, drawn only where there is a limit to be a fraction of.
    final used = (amount / limit).clamp(0.0, 1.0);
    final dueDay = account['dueDay'];
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
/// [hidden] false gives the everyday list; true gives ONLY what was hidden.
///
/// Two calls rather than one flag inside the screen, because the hidden rows
/// need their own section. NOTHING IS BOTH INVISIBLE AND UNREACHABLE: a row
/// taken out of the main list appears in that section, always. An account that
/// could not be found again would be an account that could not be UNhidden,
/// and a one way door on somebody's own money is not a view preference.
List<AccountGroup> groupAccounts(
  Map<String, dynamic> state, {
  bool hidden = false,
}) {
  final byCategory = <String, List<Map<String, dynamic>>>{};

  void take(String collection, AccountStore store) {
    for (final r in (state[collection] as List? ?? const [])) {
      if (r is! Map) continue;
      final row = r.cast<String, dynamic>();
      if (isHiddenFromLists(row) != hidden) continue;
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
      // `rollsIntoDebtSummary` applies to the EVERYDAY list only, and applying
      // it to both was the second way an account could disappear entirely. A
      // loan is kept out of the everyday list because the Debt summary already
      // counts it, which is right; a HIDDEN loan was then kept out of the
      // hidden list for the same reason, and the two filters together left it
      // in neither. The row still shows on the Debt screen, so no figure was
      // wrong, but nothing in the app could ever un-hide it again, and that
      // flag arrives for real: the shipped app's "Hide account" button writes
      // it on debt rows, so any restored backup can carry one.
      //
      // Safe because the hidden section renders no total. The same row
      // appearing under Hidden and inside "You owe" is the treatment credit
      // cards already get, on purpose.
      if (byCategory[c.id] != null && (hidden || !rollsIntoDebtSummary(c.id)))
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

/// The engine's truthiness rule, which is not Dart's.
///
/// `statements.dart` counts 1, "yes" and true alike, because the stored JSON
/// has carried all three across twelve schema versions. Reimplementing it as
/// `r['paid'] == true` would silently miss a row stored as 1 and bring the
/// wrong count back.
bool _tracked(dynamic v) =>
    v == true || (v is num && v != 0) || (v is String && v.isNotEmpty);

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
  //
  // ROWS THE USER SAID ARE NOT THEIRS ARE DROPPED FIRST, on all three
  // collections, and this whole function is the only place that decision has
  // to be made: Accounts, Home's beam and the Debt screen headline all read
  // it. Without it, `ownedOnly` took a disowned debt out of net worth while
  // "You owe" kept counting it, so three screens gave two answers with nothing
  // saying why. A co-signed loan you are not paying is exactly the row this
  // flag exists for, and it arrives for real out of a restored backup.
  List<dynamic> mine(dynamic v) => [
    for (final r in (v is List ? v : const []))
      if (countsAsOwned(r)) r,
  ];

  final payables = trackedRemaining(mine(state['payables']));
  final receivables = trackedRemaining(mine(state['receivables']));

  // Only the debts that do NOT get their own section, or the credit card
  // shown two sections above would be counted here as well and the founder
  // would read the same card twice.
  var debts = 0.0;
  var debtCount = 0;
  for (final r in (state['debts'] as List? ?? const [])) {
    if (r is! Map) continue;
    if (!countsAsOwned(r)) continue;
    final row = r.cast<String, dynamic>();
    final id = resolveKind(row, AccountStore.debts).category.id;
    if (!rollsIntoDebtSummary(id)) continue;
    debts += amountOf(row['remaining']);
    debtCount++;
  }

  // Counted with the SAME filter the total uses, which is the whole point of
  // the count. `trackedRemaining` skips a row that is settled, or that was
  // never a cash leg (a note that somebody owes a share of something does not
  // move money). Counting every row regardless made the two disagree, so
  // clearing your last utang was rewarded with a Debt card reading "Owed to you
  // ₱0, You owe ₱0". DebtTotals.any exists precisely to prevent that claim, and
  // it was being fed by a count that could not see it.
  int countOf(String collection) => mine(state[collection])
      .whereType<Map>()
      .where((r) => _tracked(r['cashLeg']) && !_tracked(r['paid']))
      .length;

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
