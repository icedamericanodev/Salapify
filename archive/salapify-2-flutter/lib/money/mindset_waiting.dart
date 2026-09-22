// Pure helpers for Money Mindset Phase 3's Waiting list: which paused
// purchases are due for their "Do you still want this?" check-in, and the
// compact remaining-time label the Waiting section shows. No RN counterpart,
// so nothing here is golden-locked; the whole feature lives Flutter-side at
// settings.mindsetWaiting (see data/store.dart), the same passthrough
// settings.activePlan and settings.timelineScenarios already use for a
// Flutter-era collection with no RN twin.

DateTime? _parseIso(dynamic v) => v is String ? DateTime.tryParse(v) : null;

/// Items still awaiting a decision, soonest revisit first. An item with an
/// unreadable revisitAt sorts last rather than throwing, the same
/// junk-in-junk-out contract the rest of the money layer keeps.
List<Map<String, dynamic>> waitingItems(dynamic rawList) {
  final items = [
    for (final e in (rawList is List ? rawList : const []))
      if (e is Map && e['status'] == 'waiting') e.cast<String, dynamic>(),
  ];
  items.sort((a, b) {
    final da = _parseIso(a['revisitAt']);
    final db = _parseIso(b['revisitAt']);
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return da.compareTo(db);
  });
  return items;
}

/// True once [item]'s revisit time has arrived. A missing or unparsable
/// revisitAt fails toward due rather than toward silence: a corrupted record
/// should surface itself for a decision, never get stuck waiting forever
/// with no way to reach it.
bool isDue(Map<String, dynamic> item, DateTime now) {
  final at = _parseIso(item['revisitAt']);
  return at == null || !at.isAfter(now);
}

/// How long until [item] is due, or null once it already is (never negative,
/// and never zero: "due at exactly this instant" is due, the same instant
/// isDue above treats it, not a Duration.zero remaining that would round to
/// its own "a moment" label instead of "Ready to revisit").
Duration? timeUntilDue(Map<String, dynamic> item, DateTime now) {
  if (isDue(item, now)) return null;
  final at = _parseIso(item['revisitAt']);
  return at?.difference(now);
}

/// A short, rounded label for the Waiting row: "Revisit in 18h", "Revisit in
/// 6m", or "Ready to revisit" once due.
String revisitLabel(Map<String, dynamic> item, DateTime now) {
  final remaining = timeUntilDue(item, now);
  if (remaining == null) return 'Ready to revisit';
  if (remaining.inHours >= 1) return 'Revisit in ${remaining.inHours}h';
  final minutes = remaining.inMinutes;
  return minutes < 1 ? 'Revisit in a moment' : 'Revisit in ${minutes}m';
}
