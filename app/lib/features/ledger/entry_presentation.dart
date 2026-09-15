// How one stored entry is DRAWN, in one place.
//
// Home's "Latest" and the Ledger's day list are the same row showing the same
// stored transaction, and they each grew their own private copy of these two
// rules. Two copies of one rule drift, and the drift is invisible: both screens
// keep rendering, they just stop agreeing, and nothing fails. Home's first
// render showed a row titled "Load" captioned "Load, GCash"; fixing that in one
// file would have left the Ledger saying it forever.
import 'package:flutter/material.dart';

import '../../core/money/format.dart' show formatMoney;
import '../../core/money/ledger.dart' show amountOf, balanceSign;

/// What an entry did to the balance it is linked to, in a signed peso figure.
///
/// [balanceSign] is the golden-locked rule for which way a stored type moves
/// a balance, so this cannot disagree with the account screen about which
/// way any entry went. MOVED HERE from ledger_screen.dart, because that file
/// already imports this one for the icon and the caption, and a second copy
/// of this function was one bad edit away from a screen that drew a sign
/// this file did not agree with.
double signedAmount(Map<String, dynamic> t) =>
    balanceSign(t) * amountOf(t['amount']);

/// The glyph for an entry, chosen by what KIND of movement it is.
IconData entryIcon(Map<String, dynamic> t) => switch (t['type']) {
  'income' => Icons.payments_outlined,
  'transfer' => Icons.swap_horiz_rounded,
  'debt' => Icons.handshake_outlined,
  'adjustment' => Icons.tune_rounded,
  _ => Icons.receipt_long_outlined,
};

/// Whether [t] is the STORED shape of a transfer: `applyTransfer`'s own row,
/// carrying no `flow` and no `accountId`.
///
/// The one thing `accountHistory` adds a `flow` to, display only, so the leg
/// shown INSIDE an account correctly reads as money in or out THERE. A row
/// reaching this function still flowless is the original, seen from a screen
/// that lists every account's activity together rather than one account's.
bool _isUnflowedTransfer(Map<String, dynamic> t) =>
    t['type'] == 'transfer' && t['flow'] == null;

/// The peso figure an entry shows, and its direction.
///
/// A stored transfer carries no `flow` by design, because `applyTransfer`
/// moves both balances itself and a `flow` would be a second opinion about
/// which way the money went (see transfers.dart). `signedAmount`'s own rule
/// for "no flow" is `type == 'income' ? 1 : -1`, which is correct for a
/// transaction that touches ONE account and wrong for one that touches two:
/// a transfer read as an expense, drawn with the same minus sign and the same
/// plain tone as spending, directly under a sheet that had just promised "not
/// income, not spending". The one thing on screen a person checks contradicted
/// the two things the app told them.
///
/// So THIS is unsigned, here, once, for the one row type the golden locked
/// engine deliberately leaves unsigned. Every other type still goes through
/// `signedAmount`, untouched.
String entryAmountText(Map<String, dynamic> t) => _isUnflowedTransfer(t)
    ? formatMoney(amountOf(t['amount']))
    : formatMoney(signedAmount(t));

/// "Groceries, GCash", the caption under an entry's label.
///
/// The category is DROPPED when it only repeats the label. A caption exists to
/// add what the title does not already carry, so "Load" over "Load, GCash" is a
/// line spent saying nothing. Filipino money labels collide with category names
/// constantly (Load, Groceries, Rent, Sweldo), so this is the common case and
/// not an edge one.
///
/// [data] is the whole ledger, because the stored row holds IDs and the names
/// live in the categories and accounts lists.
String? entrySubtitle(Map<String, dynamic> data, Map<String, dynamic> t) {
  String? nameIn(String collection, dynamic id) {
    if (id is! String || id.isEmpty) return null;
    for (final row in (data[collection] as List? ?? const [])) {
      if (row is Map && row['id'] == id) return (row['name'] ?? '').toString();
    }
    return null;
  }

  // A TRANSFER HAS NEITHER a categoryId nor an accountId (see
  // entryAmountText above for why), so the general rule below returns null
  // for it and the row draws with no caption at all under a title that just
  // says "Transfer: A to B". "Between your own accounts" is the one sentence
  // this row type needs and no other row type can produce by accident.
  if (_isUnflowedTransfer(t)) return 'Between your own accounts';

  final label = (t['label'] ?? '').toString().trim().toLowerCase();
  final category = nameIn('categories', t['categoryId']);
  final parts = [
    if (category != null && category.trim().toLowerCase() != label) category,
    ?nameIn('accounts', t['accountId']),
  ];
  return parts.isEmpty ? null : parts.join(', ');
}
