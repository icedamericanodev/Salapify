// One account, and what has happened to it.
//
// Pushed OVER the shell, not inside a tab: 04-screens.md puts details,
// editors, Insights and Settings there, so this screen has no tab bar and
// carries a BackBar instead.
//
// It answers one question the Accounts list deliberately cannot: the list says
// what a balance IS, and this says how it got there. That is why the entries
// are the body of the screen rather than a footnote under a big number.
//
// Like the list, it does no arithmetic on money. `groupByDay` and
// `signedAmount` are the Ledger's own, reused rather than re-derived, so an
// account's history and the full ledger can never disagree about a row's sign.
import 'package:flutter/material.dart';

import '../../app/ledger_scope.dart';
import '../../core/money/account_taxonomy.dart';
import '../../core/money/format.dart';
import '../../core/money/ledger.dart' show amountOf;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../ledger/entry_presentation.dart';
import '../ledger/ledger_screen.dart' show groupByDay, signedAmount;
import 'accounts_screen.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.id});

  /// The stored row's id. An id rather than the row itself, because the row
  /// this screen shows has to come from the LIVE store: pass the map in and
  /// the screen would keep showing the balance as it was when it was opened,
  /// which is wrong the moment anything is logged behind it.
  final String id;

  @override
  Widget build(BuildContext context) {
    final data = context.ledger.data;
    final found = findAccount(data, id);

    if (found == null) {
      // Reachable for real: a deep link from the home screen widget or a
      // notification can name an account that has since been deleted. The
      // route exists, the row does not, and a crash here would be a crash on
      // opening a notification.
      return const _Page(
        children: [
          BackBar(),
          SizedBox(height: 20),
          EmptyState(
            icon: Icons.help_outline_rounded,
            title: 'Account not found',
            body: 'It may have been deleted since this link was made.',
          ),
        ],
      );
    }

    final (row, store) = found;
    // `accountHistory`, not `entriesFor`: a debt payment moves this balance and
    // is not stored as one of this account's transactions. See that function.
    final entries = accountHistory(data, id);

    return _Page(
      children: [
        const BackBar(),
        const SizedBox(height: 6),
        _Header(row: row, store: store),
        const SizedBox(height: 22),
        if (entries.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Nothing logged here yet',
            body: 'Entries you tag to this account show up here, newest first.',
          )
        else
          for (final day in groupByDay({'transactions': entries})) ...[
            Head(title: prettyDay(day.date)),
            const SizedBox(height: 8),
            Group(
              children: [
                for (final t in day.rows)
                  ItemRow(
                    icon: entryIcon(t),
                    title: (t['label'] ?? '').toString(),
                    amount: formatMoney(signedAmount(t)),
                    tone: signedAmount(t) > 0 ? Tone.good : Tone.plain,
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

/// [Screen] plus the Scaffold a pushed route has to bring with it.
///
/// The shell gives every TAB screen its Scaffold, so a screen that lives in a
/// tab never needs one and none of them carries one. A route pushed over the
/// shell has no such parent, and the first render of this screen showed
/// exactly what that costs: every line of text came out with a yellow double
/// underline, which is what Flutter draws for text with no Material ancestor,
/// and the page had no background of its own either.
///
/// It passed every test while looking like that.
class _Page extends StatelessWidget {
  const _Page({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.skin.bg,
    body: Screen(children: children),
  );
}

/// The account's name, what it is, and its balance.
class _Header extends StatelessWidget {
  const _Header({required this.row, required this.store});
  final Map<String, dynamic> row;
  final AccountStore store;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final cat = categoryById(resolveKind(row, store).category.id);
    final owed = cat?.cls == AccountClass.liability;
    final amount = rowAmount(row, store);
    final limit = amountOf(row['creditLimit']);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (row['name'] ?? '').toString(),
            style: TypeScale.screenTitle(skin.text),
          ),
          const SizedBox(height: 2),
          Text(
            accountKindLabel(row, store) ?? '',
            style: TypeScale.quiet(skin.text3),
          ),
          const SizedBox(height: 14),
          // The WORD, not just a colour. "Owed" and "Balance" are the same
          // shape on screen and opposite in meaning, and a person reading a
          // number in orange has to already know the rule to read it right.
          Text(owed ? 'Owed' : 'Balance', style: TypeScale.caption(skin.text3)),
          const SizedBox(height: 4),
          Text(
            formatMoney(amount),
            style: TypeScale.hero(owed ? skin.accent : skin.text),
          ),
          if (limit > 0) ...[
            const SizedBox(height: 14),
            ThinBar(fraction: (amount / limit).clamp(0.0, 1.0)),
            const SizedBox(height: 7),
            Text(
              creditCaption(amount, limit),
              style: TypeScale.caption(skin.text3),
            ),
          ],
        ],
      ),
    );
  }
}

/// "₱35,880 of ₱40,000 left", or the truth when the card is past its limit.
///
/// Two figures here can go wrong and both did. An OVERPAID card stores a
/// negative remaining, and `limit - amount` then offered more credit than the
/// limit: "₱41,500 of ₱40,000 left". A card pushed past its limit by fees gave
/// "-₱5,000 left", which is not a sentence about money anybody can act on.
///
/// Every place in the engine that ratios a card floors the balance at zero
/// first (`credit_utilization.dart`, `debtmath.dart`). The bar directly above
/// this caption clamps correctly, so before this the bar and the words under it
/// disagreed.
String creditCaption(double amount, double limit) {
  final owed = amount < 0 ? 0.0 : amount;
  if (owed > limit) return '${formatMoney(owed - limit)} over your limit';
  return '${formatMoney(limit - owed)} of ${formatMoney(limit)} left';
}

/// Find one row by id, across all three collections, with the collection it
/// came from.
///
/// The store comes back with the row because everything downstream needs it:
/// which key holds the money, which category it belongs to, whether it is a
/// liability. Returning the row alone would make every caller guess, and
/// guessing is what put a credit card in the cash section the first time.
(Map<String, dynamic>, AccountStore)? findAccount(
  Map<String, dynamic> state,
  String id,
) {
  for (final (collection, store) in [
    ('accounts', AccountStore.accounts),
    ('assets', AccountStore.assets),
    ('debts', AccountStore.debts),
  ]) {
    for (final r in (state[collection] as List? ?? const [])) {
      if (r is! Map) continue;
      if (r['id'] == id) return (r.cast<String, dynamic>(), store);
    }
  }
  return null;
}

/// This account's entries, newest first.
///
/// A TRANSFER between two accounts is stored once, on the account it moved
/// from, so it appears in that account's history and not the other's. That is
/// the stored shape rather than a choice made here, and it is why this filter
/// is a plain accountId match and not something cleverer: inventing the
/// mirror row would put money on a screen that the ledger does not have.
List<Map<String, dynamic>> entriesFor(Map<String, dynamic> state, String id) =>
    [
      for (final t in (state['transactions'] as List? ?? const []))
        if (t is Map && t['accountId'] == id) t.cast<String, dynamic>(),
    ];

/// Everything that moved this account's balance, which is NOT the same list.
///
/// The founder paid 1,500 off a loan from BPI, opened BPI, and found nothing.
/// The balance had gone down by 1,500. A balance that moves with no entry
/// behind it is unauditable, and it was the first place they looked.
///
/// Why it happens, and why the fix is here rather than in the engine.
/// `applyDebtPayment` lowers the debt, debits the paying account DIRECTLY, and
/// writes its ledger entries tagged with `debtId` and deliberately NOT with an
/// `accountId`. That omission is correct and must not be undone: `addTransaction`
/// moves the linked account's balance by the signed amount, so an entry carrying
/// both the account tag AND the manual debit would take the money out twice.
/// Tagging the row afterwards would be worse, because `removeTransaction` would
/// then credit the account back on delete for money it never debited.
///
/// So the account link lives where the engine did put it: the top level
/// `payments` collection records `account`. This reads it and presents those
/// payments as history. DISPLAY ONLY. Nothing is written, no stored row gains a
/// field, and the balance is untouched, because the balance was already right.
/// The only thing that was missing was the founder being able to see why.
List<Map<String, dynamic>> accountHistory(
  Map<String, dynamic> state,
  String id,
) {
  String debtName(dynamic debtId) {
    for (final d in (state['debts'] as List? ?? const [])) {
      if (d is Map && d['id'] == debtId) {
        return (d['name'] ?? 'a debt').toString();
      }
    }
    return 'a debt';
  }

  return [
    ...entriesFor(state, id),
    for (final p in (state['payments'] as List? ?? const []))
      if (p is Map && p['account'] == id && amountOf(p['amount']) > 0)
        // Shaped as a `debt` entry so it takes the same sign and the same icon
        // as every other debt row, through the golden-locked `balanceSign`
        // rather than a second opinion about which way the money went.
        {
          'id': (p['id'] ?? '').toString(),
          'type': 'debt',
          'label': 'Debt payment: ${debtName(p['debtId'])}',
          'amount': amountOf(p['amount']),
          'date': (p['date'] ?? '').toString(),
          'debtId': p['debtId'],
        },
  ];
}
