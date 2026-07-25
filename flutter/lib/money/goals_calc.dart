// Pure money helpers for the Goals screen, ported from mobile/app/goals.js and
// golden-locked against the exact RN screen math (see test/goals_golden_test).
// They live in the money layer, not the screen, so a future edit cannot
// silently drift the parse or the rounding. The per-goal pace itself lives in
// analytics.goalPace; these two cover input parsing and the percent display.

/// Coerce a saved/target value the same way RN's Number() does inside toNum:
/// a number stays itself, a numeric string parses, anything else is zero.
double savedNum(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
  return 0;
}

/// Money fields accept commas: "12,000" means twelve thousand, floored at zero.
/// Matches the RN toNum so a pasted "12,000" is never read as 0.
double goalNum(String t) {
  var cleaned = t.replaceAll(RegExp(r'[, ]'), '');
  // JS Number tolerates a single trailing dot ("100." parses to 100); Dart's
  // parser does not, so drop one trailing dot to match RN toNum exactly.
  if (cleaned.endsWith('.')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  final n = double.tryParse(cleaned) ?? 0;
  // isFinite matters as much as the sign here. A pasted 400-digit number
  // parses to Infinity, which passes "> 0", reaches the store, and makes
  // jsonEncode throw so the goal is silently never saved. Every other money
  // parser in the app already guards this; this one did not.
  return (n.isFinite && n > 0) ? n : 0;
}

/// Whole-number percent for the badge, min 100, matching the RN display math
/// (Math.round((saved / target) * 100), capped). Math.round is floor(x + 0.5).
int goalPercent(double saved, double target) {
  if (target > 0) {
    final p = (saved / target * 100 + 0.5).floor();
    return p > 100 ? 100 : (p < 0 ? 0 : p);
  }
  return saved > 0 ? 100 : 0;
}
