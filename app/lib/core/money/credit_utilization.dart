// Credit Utilization Radar, f4.63. Honest, offline, from data the app already
// holds: for every tracked credit card, how much of its limit is in use, and
// the same ratio across all cards together.
//
// Utilization is balance divided by credit limit. It is a measure of HEADROOM,
// not interest: the widely taught healthy ceiling is 30 percent, and staying
// under it leaves room for emergencies and keeps a card from looking stretched
// near its statement date, which is roughly what a lender sees. Two honesty
// points the bank-officer and financial-coach reviews (2026-08-22) insisted on,
// and which the copy in the card carries:
//   - Utilization is NOT what drives interest. Interest tracks the peso balance
//     you carry past the due date; a high ratio you pay in full costs nothing.
//     So the radar never tells anyone to get under 30 percent "to save
//     interest".
//   - This reads the LIVE balance (remaining), not the statement balance, so a
//     card paid in full before its statement cuts owes no interest and the
//     number resets. That caveat sits under every non-healthy status.
//
// It composes the SAME per-card reads cardForecast already uses (balance is
// remaining floored at zero, limit is creditLimit), does no interest math, and
// changes no stored data. It only ratios two numbers the user already entered
// and names where each one sits against the 30 percent line in plain English.

import 'ledger.dart' show amountOf;

/// The health band a utilization ratio falls in. The cutoffs are the ones the
/// financial-coach and bank-officer reviews settled on (2026-08-22), taught as
/// general credit literacy, not a score formula: at or under 30 percent is
/// healthy, up to 50 percent is worth watching, above that is high, and a card
/// effectively at its limit is its own message.
enum UtilizationBand { none, healthy, watch, high, maxed }

/// The healthy ceiling, one constant so the card, the copy, and any guide all
/// draw the line in the same place.
const double healthyUtilizationLine = 0.30;

UtilizationBand bandFor(double? utilization) {
  if (utilization == null) return UtilizationBand.none;
  if (utilization >= 0.90) return UtilizationBand.maxed;
  if (utilization > 0.50) return UtilizationBand.high;
  if (utilization > healthyUtilizationLine) return UtilizationBand.watch;
  return UtilizationBand.healthy;
}

/// One card's utilization, or null utilization when the card has no usable
/// limit (so the caller shows "no limit set" rather than a fake 0 percent).
class CardUtilization {
  final String id;
  final String name;
  final double balance;
  final double limit;

  /// balance / limit, or null when limit is not a positive number.
  final double? utilization;

  const CardUtilization({
    required this.id,
    required this.name,
    required this.balance,
    required this.limit,
    required this.utilization,
  });

  UtilizationBand get band => bandFor(utilization);
}

/// The whole radar: every credit card with a limit, worst utilization first, and
/// the overall ratio across all of them. Returns null when there is no credit
/// card with a positive limit to measure, so the caller shows nothing rather
/// than an empty card.
///
/// Only debts of type 'credit card' are considered; a loan or an informal utang
/// has no revolving limit and does not belong in a utilization figure. A card
/// with no limit saved is counted separately (limitsUnset) and kept OUT of the
/// overall ratio, the same honesty the Safe-to-Spend buffer uses for a missing
/// minimum: a blank field is not a zero.
Map<String, dynamic>? creditUtilization(dynamic debts) {
  final cards = <CardUtilization>[];
  var limitsUnset = 0;
  var totalBalance = 0.0;
  var totalLimit = 0.0;

  for (final raw in (debts is List ? debts : const [])) {
    if (raw is! Map) continue;
    final d = raw.cast<String, dynamic>();
    if (d['type'] != 'credit card') continue;
    final balRaw = amountOf(d['remaining']);
    final balance = balRaw > 0 ? balRaw : 0.0;
    final limit = amountOf(d['creditLimit']);
    final name = (d['name'] is String && (d['name'] as String).isNotEmpty)
        ? d['name'] as String
        : 'Card';
    final id = (d['id'] ?? '').toString();
    if (!(limit > 0)) {
      limitsUnset += 1;
      cards.add(
        CardUtilization(
          id: id,
          name: name,
          balance: balance,
          limit: 0,
          utilization: null,
        ),
      );
      continue;
    }
    totalBalance += balance;
    totalLimit += limit;
    cards.add(
      CardUtilization(
        id: id,
        name: name,
        balance: balance,
        limit: limit,
        utilization: balance / limit,
      ),
    );
  }

  // No card, or no card with a usable limit, means there is nothing to measure
  // against the 30 percent line, so the radar does not appear at all. It is a
  // headroom gauge, not a "you have cards" reminder: a book of cards that all
  // lack a saved limit shows no radar rather than a nag with no ratio in it.
  // (When at least one card HAS a limit, the ones that do not are still flagged
  // via limitsUnset, per the reviews.)
  if (cards.isEmpty || totalLimit <= 0) return null;

  // Worst first among cards that have a ratio; the no-limit cards sink to the
  // bottom so the number that needs attention is at the top.
  cards.sort((a, b) {
    final au = a.utilization, bu = b.utilization;
    if (au == null && bu == null) return 0;
    if (au == null) return 1;
    if (bu == null) return -1;
    return bu.compareTo(au);
  });

  final overall = totalLimit > 0 ? totalBalance / totalLimit : null;
  return {
    'cards': cards,
    'overallBalance': totalBalance,
    'overallLimit': totalLimit,
    'overall': overall,
    'overallBand': bandFor(overall),
    'limitsUnset': limitsUnset,
    'cardCount': cards.length,
  };
}
