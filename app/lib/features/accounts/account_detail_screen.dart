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
    final entries = entriesFor(data, id);

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
                    icon: _iconFor(t),
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
              '${formatMoney(limit - amount)} of ${formatMoney(limit)} left',
              style: TypeScale.caption(skin.text3),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _iconFor(Map<String, dynamic> t) => switch (t['type']) {
  'income' => Icons.payments_outlined,
  'transfer' => Icons.swap_horiz_rounded,
  'debt' => Icons.handshake_outlined,
  'adjustment' => Icons.tune_rounded,
  _ => Icons.receipt_long_outlined,
};

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
