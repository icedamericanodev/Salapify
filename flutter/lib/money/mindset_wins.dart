// Pure helpers for Money Mindset Phase 4: the local 30-day snapshot and its
// single rule-based insight, built only from records Money Mindset already
// keeps on the device (data.wins, settings.mindsetChecks,
// settings.mindsetWaiting). No RN counterpart, so nothing here is
// golden-locked; mindsetChecks is a new Flutter-only passthrough collection
// under settings, the same pattern activePlan, timelineScenarios, and
// mindsetWaiting already use.
//
// Nothing here calls out to a server, another package, or an LLM: every
// number is a plain count or sum over records the user's own taps created,
// which is the whole point of "insights come from recorded decisions."

DateTime? _dateOnly(dynamic v) {
  if (v is! String || v.length < 10) return null;
  return DateTime.tryParse(v.substring(0, 10));
}

/// True when [v] names a day within the 30 days up to and including [now]
/// (not the future, since a clock-skewed or hand-edited record should not
/// count as recent). Day granularity throughout, matching how every other
/// "last 30 days" window in this app (course_plan.dart's recommendedTrack)
/// already compares dates.
bool within30Days(dynamic v, DateTime now) {
  final d = _dateOnly(v);
  if (d == null) return false;
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = DateTime(now.year, now.month, now.day - 30);
  return !d.isBefore(cutoff) && !d.isAfter(today);
}

/// A usable, positive amount, or null. A zero, negative, or non-numeric
/// amount is not "spending avoided", it is a blank field; excluding it here
/// (rather than counting it as ₱0) is what keeps the snapshot's total and
/// its own record count honest with each other.
double? validWinAmount(dynamic v) {
  if (v is! num || !v.isFinite) return null;
  return v > 0 ? v.toDouble() : null;
}

List<Map<String, dynamic>> _maps(dynamic raw) => [
  for (final e in (raw is List ? raw : const []))
    if (e is Map) e.cast<String, dynamic>(),
];

/// The four local, on-device numbers Money Mindset's 30-day snapshot shows.
/// Every field only ever counts records dated in the last 30 days; nothing
/// here reaches into account balances or implies the total changed one.
class MindsetSnapshot {
  final int decisionChecksCompleted;
  final int purchasesPaused;
  final int purchasesSkipped;
  final double confirmedSpendingAvoided;

  /// How many of the wins in this window actually had a usable amount.
  /// Kept separate from decisionChecksCompleted etc. so the UI can say
  /// "from N records" rather than implying every win counted.
  final int spendingAvoidedRecordCount;

  const MindsetSnapshot({
    required this.decisionChecksCompleted,
    required this.purchasesPaused,
    required this.purchasesSkipped,
    required this.confirmedSpendingAvoided,
    required this.spendingAvoidedRecordCount,
  });
}

/// Builds the snapshot from the three raw collections. [wins] is data.wins,
/// [mindsetChecks] is settings.mindsetChecks (one row per completed
/// three-question check, any result), [mindsetWaiting] is
/// settings.mindsetWaiting (Phase 3's Pause queue).
MindsetSnapshot mindsetSnapshot({
  required dynamic wins,
  required dynamic mindsetChecks,
  required dynamic mindsetWaiting,
  required DateTime now,
}) {
  final checks = _maps(
    mindsetChecks,
  ).where((c) => within30Days(c['date'], now)).length;

  final waiting = _maps(
    mindsetWaiting,
  ).where((w) => within30Days(w['createdAt'], now)).toList();
  final paused = waiting.length;
  final skipped = waiting.where((w) => w['status'] == 'skipped').length;

  var total = 0.0;
  var withAmount = 0;
  for (final w in _maps(wins)) {
    if (!within30Days(w['date'], now)) continue;
    final amount = validWinAmount(w['amount']);
    if (amount == null) continue;
    total += amount;
    withAmount++;
  }

  return MindsetSnapshot(
    decisionChecksCompleted: checks,
    purchasesPaused: paused,
    purchasesSkipped: skipped,
    confirmedSpendingAvoided: total,
    spendingAvoidedRecordCount: withAmount,
  );
}

/// The minimum number of relevant records a rule needs before it is allowed
/// to name a pattern. Below this, a real pattern and pure chance look the
/// same, so the honest thing is to say nothing.
const minInsightRecords = 3;

/// One short, neutral, rule-based insight, or null when there is not yet
/// enough data. Reads only settings.mindsetWaiting; never guesses at why a
/// pause happened, never names a condition, never scores the user.
///
/// [categoryName] resolves a category id to its display name; a category
/// that no longer exists (or an item with none) is simply not counted
/// toward the category-pattern rule.
///
/// Checked in this order: a plain count of purchases the 24-hour wait
/// actually helped skip is the most concrete claim this data can support,
/// so it is offered first; the category pattern is the fallback when there
/// have not been enough skips yet but there has been enough pausing to say
/// where it clusters.
String? mindsetInsight({
  required dynamic mindsetWaiting,
  required DateTime now,
  required String? Function(String categoryId) categoryName,
}) {
  final windowed = _maps(
    mindsetWaiting,
  ).where((w) => within30Days(w['createdAt'], now)).toList();

  final skippedCount = windowed.where((w) => w['status'] == 'skipped').length;
  if (skippedCount >= minInsightRecords) {
    return 'Waiting 24 hours helped you skip $skippedCount purchases this '
        'month.';
  }

  final counts = <String, int>{};
  for (final w in windowed) {
    final id = w['categoryId'];
    if (id is String && id.isNotEmpty) counts[id] = (counts[id] ?? 0) + 1;
  }
  final withCategory = counts.values.fold(0, (a, b) => a + b);
  if (withCategory < minInsightRecords) return null;

  String? topId;
  var topCount = 0;
  for (final entry in counts.entries) {
    if (entry.value > topCount) {
      topId = entry.key;
      topCount = entry.value;
    }
  }
  if (topId == null) return null;
  // A genuine cluster, not just the largest of several near-even slices: the
  // top category must account for more than half of the categorized pauses.
  if (topCount * 2 <= withCategory) return null;
  final name = categoryName(topId);
  if (name == null || name.trim().isEmpty) return null;
  return 'Most of your pauses happened in ${name.trim()}.';
}
