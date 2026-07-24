// The milestone engine: the achieved money wins worth a share card. Pure,
// reads the sanitized data blob, invents no numbers. Net-new logic (the RN app
// has no counterpart), so it is covered by unit tests with hard invariants
// instead of a golden replay.
//
// Four kinds, each a moment people already screenshot:
//  - debt: a debt paid down to zero, with at least one logged payment (a debt
//    merely created at zero is not a win). Amount = the payments logged.
//  - goal: a savings goal at or past its target. Amount = the target.
//  - utangIn: someone settled what they owed you. Amount = what was owed.
//  - utangOut: you paid someone back in full. Amount = what you owed.
//
// Every amount comes from the data; when the data cannot support one (a debt
// zeroed by hand with no payments is excluded entirely), no number is shown.

import 'ledger.dart' show amountOf;

class Milestone {
  final String kind; // 'debt' | 'goal' | 'utangIn' | 'utangOut'
  final String name; // debt name, goal name, or person
  final double amount; // 0 means "show no amount row"
  final String headline; // the Fraunces line on the card
  final String sub; // the honest line under it
  final String amountLabel; // row label when amount > 0
  const Milestone({
    required this.kind,
    required this.name,
    required this.amount,
    required this.headline,
    required this.sub,
    required this.amountLabel,
  });
}

List<Map<String, dynamic>> _maps(dynamic v) => [
  for (final x in (v is List ? v : const []))
    if (x is Map) x.cast<String, dynamic>(),
];

double _paidTotal(Map<String, dynamic> r) {
  var sum = 0.0;
  for (final p in _maps(r['payments'])) {
    final a = amountOf(p['amount']);
    if (a > 0) sum += a;
  }
  return sum;
}

bool _settled(Map<String, dynamic> r) {
  final amount = amountOf(r['amount']);
  if (amount <= 0) return false;
  if (r['paid'] == true) return true;
  return amount - _paidTotal(r) <= 0;
}

/// The achieved milestones, debts first, then goals, then settled utang both
/// ways. Junk shapes never throw; they are simply not milestones.
List<Milestone> milestones(dynamic data) {
  final d = data is Map ? data : const {};
  final out = <Milestone>[];

  // Debts paid to zero. The payments ledger is the proof: sum what was logged
  // for this debt (principal plus interest, the real pesos that left).
  final payments = _maps(d['payments']);
  for (final debt in _maps(d['debts'])) {
    if (amountOf(debt['remaining']) > 0) continue;
    final id = debt['id'];
    var paid = 0.0;
    var any = false;
    for (final p in payments) {
      if (id == null || p['debtId'] != id) continue;
      any = true;
      final a = amountOf(p['amount']);
      if (a > 0) paid += a;
    }
    if (!any) continue; // zeroed by hand, not a tracked payoff
    final name =
        (debt['name'] is String && (debt['name'] as String).trim().isNotEmpty)
        ? (debt['name'] as String).trim()
        : 'A debt';
    out.add(
      Milestone(
        kind: 'debt',
        name: name,
        amount: paid,
        headline: 'Debt free',
        sub: '$name, paid down to zero',
        amountLabel: 'Total paid',
      ),
    );
  }

  // Goals fully funded.
  for (final g in _maps(d['goals'])) {
    final target = amountOf(g['target']);
    if (!(target > 0) || amountOf(g['saved']) < target) continue;
    final name =
        (g['name'] is String && (g['name'] as String).trim().isNotEmpty)
        ? (g['name'] as String).trim()
        : 'A goal';
    out.add(
      Milestone(
        kind: 'goal',
        name: name,
        amount: target,
        headline: 'Goal reached',
        sub: '$name, fully funded',
        amountLabel: 'Saved up',
      ),
    );
  }

  // Utang settled, both directions.
  for (final r in _maps(d['receivables'])) {
    if (!_settled(r)) continue;
    final person =
        (r['person'] is String && (r['person'] as String).trim().isNotEmpty)
        ? (r['person'] as String).trim()
        : 'Someone';
    out.add(
      Milestone(
        kind: 'utangIn',
        name: person,
        amount: amountOf(r['amount']),
        headline: 'Settled up',
        sub: '$person paid back what they owed. No awkwardness needed.',
        amountLabel: 'Collected',
      ),
    );
  }
  for (final r in _maps(d['payables'])) {
    if (!_settled(r)) continue;
    final person =
        (r['person'] is String && (r['person'] as String).trim().isNotEmpty)
        ? (r['person'] as String).trim()
        : 'Someone';
    out.add(
      Milestone(
        kind: 'utangOut',
        name: person,
        amount: amountOf(r['amount']),
        headline: 'All paid back',
        sub: 'Settled the full amount owed to $person. Clean slate.',
        amountLabel: 'Paid back',
      ),
    );
  }

  return out;
}

/// The plain-text fallback for a milestone, mirroring recapText's shape.
String milestoneText(
  Milestone m,
  String Function(num) formatMoney, [
  bool hideAmounts = false,
]) {
  final lines = <String>['${m.headline}: ${m.sub}.'];
  if (m.amount > 0 && !hideAmounts) {
    lines.add('${m.amountLabel}: ${formatMoney(m.amount)}.');
  }
  lines.add("Tracked with Salapify, on your money's side. ☕");
  return lines.join('\n');
}
