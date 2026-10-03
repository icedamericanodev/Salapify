/// Pulling a peso amount out of a sentence somebody typed.
///
/// Ported from `extractCurrencyAmount` in src/utils/panAiEngine.ts, with its
/// bugs fixed rather than carried over. The prototype's regex has no anchor
/// and no word boundary on the currency branch, so it matches the FIRST run
/// of digits anywhere in the sentence: "can I afford 2 tickets at 800 each"
/// comes back as 2.
///
/// Why this exists at all: "Can I afford this?" is the single most useful
/// question a person can ask a budget app, and it cannot be answered without
/// reading the amount out of the question. Everything in
/// pan_affordability.dart is downstream of this one function being right.
library;

/// The amount in a question, or null when there is not one.
///
/// Handles the shapes people actually type:
///
///   ₱2,500   P1500   php 1500   1500 pesos   2.5k   10k   2,500.50
///
/// Returns pesos, so "2.5k" is 2500. Centavos survive: "2,500.50" is 2500.5.
double? extractAmount(String raw) {
  final String clean = raw.toLowerCase().replaceAll(',', '');

  // THOUSANDS FIRST, because "10k" also contains the digits "10", and a
  // currency match would take the 10 and answer a question about ten pesos
  // with total confidence.
  final RegExpMatch? k = RegExp(
    r'(?<![\w.])(\d+(?:\.\d+)?)\s*k\b',
  ).firstMatch(clean);
  if (k != null) {
    final double? v = double.tryParse(k.group(1)!);
    if (v != null && v > 0 && v < 10000000) return (v * 1000).roundToDouble();
  }

  // An amount is a number that is MARKED as money, or a bare number in a
  // sentence that is already about spending. The prototype made the marker
  // optional everywhere, which is why "what happened in 2025" was an amount.
  final RegExp marked = RegExp(
    r'(?:₱|\bp(?=\d)|\bphp\s*)(\d+(?:\.\d{1,2})?)'
    r'|'
    r'(\d+(?:\.\d{1,2})?)\s*(?:pesos?|php)\b',
  );
  final RegExpMatch? m = marked.firstMatch(clean);
  if (m != null) {
    final double? v = double.tryParse(m.group(1) ?? m.group(2)!);
    if (v != null && v > 0 && v < 100000000) return v;
  }

  // A bare number, allowed only where the sentence is about money moving.
  // Without this guard "what happened on the 15th" is a fifteen peso
  // purchase, and with it a question has to be about buying before a plain
  // number counts as a price.
  const List<String> spendingWords = <String>[
    'afford',
    'spend',
    'buy',
    'bili',
    'bilhin',
    'gastos',
    'gastusin',
    'cost',
    'costs',
    'price',
    'pay',
    'bayad',
    'worth',
  ];
  if (!spendingWords.any(clean.contains)) return null;

  final RegExpMatch? bare = RegExp(
    r'(?<![\w.])(\d+(?:\.\d{1,2})?)(?![\w.])',
  ).firstMatch(clean);
  if (bare == null) return null;
  final double? v = double.tryParse(bare.group(1)!);
  if (v == null || v <= 0 || v >= 100000000) return null;

  // A YEAR IS NOT A PRICE, and the difference is what comes AFTER it.
  //
  // "Can I afford the 2026 trip" is a question about a trip, and answering it
  // as a 2,026 peso purchase is a confident wrong number. But "can I afford
  // 2000" is a two thousand peso question, and refusing it because the digits
  // happen to fall in a year range is just as wrong in the other direction.
  //
  // A year MODIFIES something, so a noun follows it. An amount is usually the
  // last thing said. So the guard only fires when the figure is followed by
  // more words, which is the only signal in the sentence that separates them.
  final bool inYearRange = v >= 1990 && v <= 2099 && v == v.roundToDouble();
  if (inYearRange) {
    final String after = clean.substring(bare.end).trim();
    if (after.isNotEmpty) return null;
  }

  return v;
}
