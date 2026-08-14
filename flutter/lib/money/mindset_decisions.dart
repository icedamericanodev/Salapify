// Money Mindset decision history: pure read helpers over the
// settings.mindsetDecisions list. Each entry is one logged choice from the
// four-step flow: the item, its estimated amount, the outcome, an optional
// note, and when it was logged.
//
// READ ONLY money. Nothing here is a transaction and none of it moves a
// balance. The amount on a decision is the person's own Step 1 estimate, shown
// back to them (and summed into "money avoided" for the ones they skipped),
// never added to or subtracted from any account. Keeping this logic pure and
// off the store is what lets the tests pin every count to the centavo.

/// The three outcomes a logged decision can carry. Stored as plain strings so
/// the backup preserves them with no migration, the same passthrough
/// mindsetWaiting and mindsetChecks use.
class MindsetOutcome {
  static const String purchased = 'purchased';
  static const String avoided = 'avoided';
  static const String waiting = 'waiting';
}

/// Maps the four-step flow's own outcome word ('bought' / 'skipped' /
/// 'waiting') to the stored decision outcome. Kept here, next to the vocabulary
/// it targets, so the flow and the dashboard can never drift on the mapping.
String mindsetOutcomeFromFlow(String flowOutcome) => switch (flowOutcome) {
  'bought' => MindsetOutcome.purchased,
  'skipped' => MindsetOutcome.avoided,
  _ => MindsetOutcome.waiting,
};

/// A human label for a badge.
String mindsetOutcomeLabel(String? outcome) => switch (outcome) {
  MindsetOutcome.purchased => 'Purchased',
  MindsetOutcome.avoided => 'Avoided',
  MindsetOutcome.waiting => 'Waiting',
  _ => '',
};

/// Today's counts for the dashboard summary. moneyAvoided sums the estimated
/// amount of the decisions that were AVOIDED today; a purchase or a waiting
/// item never adds to it, because nothing was kept.
class MindsetTodayStats {
  final int decisions;
  final int purchased;
  final int avoided;
  final double moneyAvoided;
  const MindsetTodayStats({
    required this.decisions,
    required this.purchased,
    required this.avoided,
    required this.moneyAvoided,
  });
}

List<Map<String, dynamic>> _valid(Iterable? raw) => [
  for (final e in (raw ?? const []))
    if (e is Map) e.cast<String, dynamic>(),
];

DateTime? _when(Map<String, dynamic> d) {
  final v = d['createdAt'];
  return v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);
}

double _amt(dynamic v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s) ?? 0,
  _ => 0,
};

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The four today-scoped figures the dashboard shows.
MindsetTodayStats mindsetTodayStats(Iterable? rawDecisions, DateTime now) {
  var decisions = 0, purchased = 0, avoided = 0;
  var money = 0.0;
  for (final d in _valid(rawDecisions)) {
    final w = _when(d);
    if (w == null || !_sameDay(w, now)) continue;
    decisions++;
    switch (d['outcome']) {
      case MindsetOutcome.purchased:
        purchased++;
      case MindsetOutcome.avoided:
        avoided++;
        money += _amt(d['amount']);
    }
  }
  return MindsetTodayStats(
    decisions: decisions,
    purchased: purchased,
    avoided: avoided,
    moneyAvoided: money,
  );
}

/// One boolean per week over the last four (oldest first), true when a decision
/// check or a win landed in that week. Shared by the flow's step 4 and the
/// standalone insights screen so the mindful streak reads identically in both,
/// and pinned by a test rather than duplicated by eye.
List<bool> mindsetWeekDots(Iterable? checks, Iterable? wins, DateTime now) {
  final dates = <DateTime>[
    for (final c in (checks ?? const []))
      if (c is Map &&
          c['date'] is String &&
          DateTime.tryParse(c['date'] as String) != null)
        DateTime.parse(c['date'] as String),
    for (final w in (wins ?? const []))
      if (w is Map &&
          w['date'] is String &&
          DateTime.tryParse(w['date'] as String) != null)
        DateTime.parse(w['date'] as String),
  ];
  return [
    for (var wk = 3; wk >= 0; wk--)
      dates.any((d) {
        final days = now.difference(d).inDays;
        return days >= wk * 7 && days < (wk + 1) * 7;
      }),
  ];
}

/// Filter decisions to a single outcome; a null [outcome] returns them all
/// (used by the "All" segment). Order is preserved; the caller sorts.
List<Map<String, dynamic>> filterMindsetByOutcome(
  Iterable? rawDecisions,
  String? outcome,
) {
  final list = _valid(rawDecisions);
  if (outcome == null) return list;
  return [
    for (final e in list)
      if (e['outcome'] == outcome) e,
  ];
}

/// Newest first, up to [limit]. A negative [limit] returns all of them.
/// Entries with no readable timestamp sort last, so a junk row never jumps
/// ahead of a real one.
List<Map<String, dynamic>> recentMindsetDecisions(
  Iterable? rawDecisions, {
  int limit = 5,
}) {
  final list = _valid(rawDecisions);
  list.sort((a, b) {
    final wa = _when(a), wb = _when(b);
    if (wa == null && wb == null) return 0;
    if (wa == null) return 1;
    if (wb == null) return -1;
    return wb.compareTo(wa);
  });
  if (limit < 0 || list.length <= limit) return list;
  return list.sublist(0, limit);
}

/// A short, human "when" for a decision row: the time of day if it happened
/// today, "Yesterday" if it was the day before, otherwise the month and day.
/// Pure so the format is tested rather than eyeballed.
String mindsetDecisionWhen(dynamic createdAt, DateTime now) {
  final w = createdAt is String
      ? DateTime.tryParse(createdAt)
      : (createdAt is DateTime ? createdAt : null);
  if (w == null) return '';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(w.year, w.month, w.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return _clock(w);
  if (diff == 1) return 'Yesterday';
  return _date(w);
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String _clock(DateTime d) {
  final h24 = d.hour;
  final period = h24 < 12 ? 'AM' : 'PM';
  var h = h24 % 12;
  if (h == 0) h = 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m $period';
}
