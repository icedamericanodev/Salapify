// Earn-your-treats: temptation bundling, ported 1:1 from mobile/lib/treats.js.
// A user pairs a small treat with a self-defined healthy action, taps one
// check-in when they do the action, and the treat is "earned" once enough
// recent check-ins land. Pure functions, no network, no health data. It never
// blocks spending and never resets to zero: check-ins age out of a rolling
// window, and lifetime only grows. Golden-verified against the real RN module
// (see scratchpad/gen-treats-goldens.js). No dashes.

import 'ledger.dart' show amountOf;

// Math.round: rounds .5 toward positive infinity, matching JS.
int _jsRound(double x) => (x + 0.5).floorToDouble().toInt();

// JS `Number.isFinite(Number(x)) ? Number(x) : 0`. amountOf already maps
// non-finite and unparseable values to 0 the same way.
double _num(dynamic x) => amountOf(x);

// JS falsiness for the `x || default` idiom.
bool _falsy(dynamic v) =>
    v == null ||
    v == false ||
    v == 0 ||
    v == '' ||
    (v is num && v.isNaN);

// JS clampInt: `min(max(round(num(x)) || dflt, lo), hi)`. A rounded 0 (or an
// unparseable value) falls back to the default before clamping.
int _clampInt(dynamic x, int lo, int hi, int dflt) {
  final r = _jsRound(_num(x));
  final v = r != 0 ? r : dflt;
  return v < lo ? lo : (v > hi ? hi : v);
}

int _lifetimeFloor(dynamic x) {
  final r = _jsRound(_num(x));
  return r > 0 ? r : 0;
}

String _todayISO(DateTime ref) {
  final m = ref.month.toString().padLeft(2, '0');
  final d = ref.day.toString().padLeft(2, '0');
  return '${ref.year}-$m-$d';
}

// 'YYYY-MM-DD' for the date n days before ref (n = 0 is today), local time.
// DateTime rolls the month/year over the same way new Date(y, m, d - n) does.
String _isoBack(DateTime ref, int n) {
  final d = DateTime(ref.year, ref.month, ref.day - n);
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Keep only check-ins inside the rolling window [today - (windowDays - 1) ..
/// today]. Deduped and sorted. ISO date strings compare chronologically, so
/// string comparison is safe here.
List<String> pruneCheckIns(dynamic checkIns, dynamic windowDays, DateTime ref) {
  final w = _clampInt(windowDays, 1, 31, 7);
  final today = _todayISO(ref);
  final cutoff = _isoBack(ref, w - 1);
  final seen = <String>{};
  final out = <String>[];
  final list = checkIns is List ? checkIns : const [];
  for (final d in list) {
    if (d is String && d.compareTo(cutoff) >= 0 && d.compareTo(today) <= 0) {
      if (seen.add(d)) out.add(d);
    }
  }
  out.sort();
  return out;
}

/// Live status of a treat rule against a reference date:
///   { id, treat, action, emoji, target, windowDays, recent, remaining,
///     earned, doneToday, lifetime }
Map<String, dynamic> treatStatus(dynamic treat, DateTime ref) {
  final t = treat is Map ? treat : const {};
  final target = _clampInt(t['target'], 1, 14, 3);
  final windowDays = _clampInt(t['windowDays'], 1, 31, 7);
  final recentList = pruneCheckIns(t['checkIns'], windowDays, ref);
  final recent = recentList.length;
  final rawEmoji = t['emoji'];
  return {
    'id': t['id'],
    'treat': t['treat'],
    'action': t['action'],
    'emoji': _falsy(rawEmoji) ? '☕' : rawEmoji,
    'target': target,
    'windowDays': windowDays,
    'recent': recent,
    'remaining': (target - recent) > 0 ? target - recent : 0,
    'earned': recent >= target,
    'doneToday': recentList.contains(_todayISO(ref)),
    'lifetime': _lifetimeFloor(t['lifetime']),
  };
}

/// Toggle today's check-in, returning a NEW treat map (never mutates). Adding
/// increments lifetime; undoing the same day decrements it (never below zero).
/// Stored check-ins are pruned to the window so state stays tiny.
Map<String, dynamic> toggleCheckIn(dynamic treat, DateTime ref) {
  final t = treat is Map
      ? Map<String, dynamic>.from(treat.cast<String, dynamic>())
      : <String, dynamic>{};
  final windowDays = _clampInt(t['windowDays'], 1, 31, 7);
  final today = _todayISO(ref);
  final existing = t['checkIns'] is List ? List.from(t['checkIns'] as List) : [];
  final has = existing.contains(today);
  var lifetime = _lifetimeFloor(t['lifetime']);
  List checkIns;
  if (has) {
    checkIns = existing.where((d) => d != today).toList();
    lifetime = lifetime - 1 > 0 ? lifetime - 1 : 0;
  } else {
    checkIns = [...existing, today];
    lifetime = lifetime + 1;
  }
  return {
    ...t,
    'checkIns': pruneCheckIns(checkIns, windowDays, ref),
    'lifetime': lifetime,
  };
}

/// Build a normalized new treat rule from form fields. The id defaults to a
/// timestamp-based value the way RN's Date.now() id does; the caller may pass a
/// stable id instead.
Map<String, dynamic> newTreat(dynamic fields, DateTime ref, {String? id}) {
  final f = fields is Map ? fields : const {};
  String s(dynamic v, String d) =>
      v is String && v.trim().isNotEmpty ? v.trim() : d;
  final rawEmoji = f['emoji'];
  return {
    'id': id ?? 'treat_${ref.millisecondsSinceEpoch}',
    'treat': s(f['treat'], 'My treat'),
    'action': s(f['action'], 'My healthy action'),
    'emoji': rawEmoji is String && rawEmoji.isNotEmpty ? rawEmoji : '☕',
    'target': _clampInt(f['target'], 1, 14, 3),
    'windowDays': _clampInt(f['windowDays'], 1, 31, 7),
    'checkIns': <String>[],
    'lifetime': 0,
    'createdAt': _todayISO(ref),
  };
}

/// Starter templates shown on the empty state, tuned for a Filipino user.
const List<Map<String, dynamic>> treatTemplates = [
  {'emoji': '☕', 'treat': 'Milk tea or kape', 'action': '30-minutong lakad', 'target': 3, 'windowDays': 7},
  {'emoji': '🍟', 'treat': 'Burger or sisig', 'action': 'Home-cooked baon', 'target': 3, 'windowDays': 7},
  {'emoji': '🎬', 'treat': 'Movie night', 'action': 'Maagang tulog', 'target': 4, 'windowDays': 7},
  {'emoji': '🛍️', 'treat': 'One item sa cart', 'action': 'Tubig, no softdrinks', 'target': 5, 'windowDays': 7},
];
