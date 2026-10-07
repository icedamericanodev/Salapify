// This month's In / Out / Net for one account (mockup screen 5).
//
// Founder decision: include transfers, so this counts everything that moved
// through the account this month, not only its own income and expenses. Two
// shapes of transaction touch an account, and they are stored differently:
//
//   - Income and expenses carry accountId and are classified exactly the way
//     the account's activity row classifies them: an inflow when flow is 'in',
//     or when there is no flow and the type is income; an outflow otherwise.
//   - A transfer is ONE transaction carrying transferFromId and transferToId
//     (no accountId, no flow), so money leaving this account (transferFromId)
//     is an outflow and money arriving (transferToId) is an inflow.
//
// Net is inflow minus outflow. No new money methodology: every amount is a
// value already stored on a transaction, summed by its existing direction.
// The activity list on the same screen shows income and expenses only, so the
// founder accepted that In/Out here can exceed what that list adds up to when
// transfers are involved.

import 'ledger.dart' show amountOf;

typedef AccountFlow = ({double inflow, double outflow, double net});

/// In, out and net for [accountId] across [monthKey] ('YYYY-MM'). Dates are
/// ISO 'YYYY-MM-DD' strings, so a prefix match selects the month. A missing or
/// malformed date is skipped rather than guessed.
AccountFlow accountMonthFlow(
  Map<String, dynamic>? data,
  String accountId,
  String monthKey,
) {
  var inflow = 0.0;
  var outflow = 0.0;
  final txs = (data ?? const {})['transactions'];
  for (final t in (txs is List ? txs : const [])) {
    if (t is! Map) continue;
    final date = t['date']?.toString() ?? '';
    if (!date.startsWith(monthKey)) continue;
    final amount = amountOf(t['amount']);
    if (t['accountId'] == accountId) {
      final flow = t['flow'];
      final isIn = flow == 'in' || (flow == null && t['type'] == 'income');
      if (isIn) {
        inflow += amount;
      } else {
        outflow += amount;
      }
    } else if (t['type'] == 'transfer') {
      if (t['transferToId'] == accountId) {
        inflow += amount;
      } else if (t['transferFromId'] == accountId) {
        outflow += amount;
      }
    }
  }
  return (inflow: inflow, outflow: outflow, net: inflow - outflow);
}
