// How one stored entry is DRAWN, in one place.
//
// Home's "Latest" and the Ledger's day list are the same row showing the same
// stored transaction, and they each grew their own private copy of these two
// rules. Two copies of one rule drift, and the drift is invisible: both screens
// keep rendering, they just stop agreeing, and nothing fails. Home's first
// render showed a row titled "Load" captioned "Load, GCash"; fixing that in one
// file would have left the Ledger saying it forever.
import 'package:flutter/material.dart';

/// The glyph for an entry, chosen by what KIND of movement it is.
IconData entryIcon(Map<String, dynamic> t) => switch (t['type']) {
  'income' => Icons.payments_outlined,
  'transfer' => Icons.swap_horiz_rounded,
  'debt' => Icons.handshake_outlined,
  'adjustment' => Icons.tune_rounded,
  _ => Icons.receipt_long_outlined,
};

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

  final label = (t['label'] ?? '').toString().trim().toLowerCase();
  final category = nameIn('categories', t['categoryId']);
  final parts = [
    if (category != null && category.trim().toLowerCase() != label) category,
    ?nameIn('accounts', t['accountId']),
  ];
  return parts.isEmpty ? null : parts.join(', ');
}
