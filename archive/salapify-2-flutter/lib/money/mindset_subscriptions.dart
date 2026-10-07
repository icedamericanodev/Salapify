// The subscriptions the person keeps for the Money Mindset Subscription path.
// A Flutter-only collection (no RN twin), stored as a CONDITIONAL key under
// settings.mindsetSubscriptions exactly like paluwagans and netWorthHistory, so
// the RN-generated golden key-set contract holds and no schema bump is needed.
//
// The amounts feed a running total the person reads, so this is money: it is
// pinned by test vectors and defensive on read (junk in, safe out), never a
// divide-by-zero or a negative total.

/// One subscription the person tracks: a service, its price, and whether the
/// price is billed monthly or once a year.
class Subscription {
  final String id;
  final String name;
  final double amount;

  /// 'monthly' or 'annual'. Anything else is treated as monthly.
  final String cycle;

  /// A user-picked emoji, or empty. User data, so it stays an emoji (never a
  /// Salapify icon), the same rule categories and treats follow.
  final String emoji;

  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.cycle,
    this.emoji = '',
  });

  bool get isAnnual => cycle == 'annual';

  /// What this subscription costs per month: an annual price divided by 12, a
  /// monthly price as-is. This is the one normalization the overview leans on.
  double get monthlyEquivalent => isAnnual ? amount / 12 : amount;

  /// What it costs across a year: a monthly price times 12, an annual price
  /// as-is.
  double get annualEquivalent => isAnnual ? amount : amount * 12;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'cycle': cycle,
    if (emoji.isNotEmpty) 'emoji': emoji,
  };

  /// Read one stored row tolerantly. A negative or non-finite amount becomes 0,
  /// an unknown cycle becomes monthly, a missing name becomes a safe label.
  static Subscription fromMap(Map<String, dynamic> m) {
    final amt = (m['amount'] is num) ? (m['amount'] as num).toDouble() : 0.0;
    final name =
        (m['name'] is String && (m['name'] as String).trim().isNotEmpty)
        ? (m['name'] as String)
        : 'Subscription';
    final emoji = m['emoji'] is String ? m['emoji'] as String : '';
    return Subscription(
      id: m['id'] is String ? m['id'] as String : '',
      name: name,
      amount: (amt.isFinite && amt > 0) ? amt : 0.0,
      cycle: m['cycle'] == 'annual' ? 'annual' : 'monthly',
      emoji: emoji,
    );
  }
}

/// A read of the whole list: how many, and what they cost together per month
/// and per year, with every annual price normalized to a monthly figure so the
/// two totals always reconcile (annualTotal == monthlyTotal * 12).
class SubscriptionsOverview {
  final int count;
  final double monthlyTotal;
  final double annualTotal;

  const SubscriptionsOverview({
    required this.count,
    required this.monthlyTotal,
    required this.annualTotal,
  });
}

/// Parse a stored list into typed subscriptions, dropping only rows that are not
/// maps. Everything else is coerced to a safe shape by [Subscription.fromMap].
List<Subscription> parseSubscriptions(dynamic list) {
  if (list is! List) return const [];
  final out = <Subscription>[];
  for (final row in list) {
    if (row is Map) {
      out.add(Subscription.fromMap(row.cast<String, dynamic>()));
    }
  }
  return out;
}

/// Total the list. Monthly is the sum of each item's monthly equivalent; annual
/// is exactly that times twelve, so the two figures can never disagree on the
/// screen.
SubscriptionsOverview subscriptionsOverview(List<Subscription> subs) {
  var monthly = 0.0;
  for (final s in subs) {
    monthly += s.monthlyEquivalent;
  }
  return SubscriptionsOverview(
    count: subs.length,
    monthlyTotal: monthly,
    annualTotal: monthly * 12,
  );
}
