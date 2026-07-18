// Pan text normalization, ported 1:1 from mobile/lib/pan/normalize.js.
// Turns a raw message into a clean lowercased token string, folding Taglish
// words to the English tokens the intent keywords use. Small data tables,
// no logic, no network. Golden-verified against the real RN module.

const Map<String, String> _diacritics = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c',
};

const Map<String, String> _synonyms = {
  'utang': 'owe',
  'pautang': 'owe',
  'naniningil': 'owe',
  'sweldo': 'payday',
  'suweldo': 'payday',
  'sahod': 'payday',
  'kinsenas': 'payday',
  'katapusan': 'payday',
  'gastos': 'spending',
  'gastusin': 'spend',
  'gumastos': 'spend',
  'gastador': 'spending',
  'pera': 'money',
  'kwarta': 'money',
  'kuwarta': 'money',
  'ipon': 'savings',
  'naiipon': 'save',
  'maipon': 'save',
  'magipon': 'save',
  'bayad': 'pay',
  'bayaran': 'pay',
  'babayaran': 'pay',
  'bayarin': 'bills',
  'utangko': 'debt',
  'magkano': 'howmuch',
  'kaya': 'can',
  'pwede': 'can',
  'sino': 'who',
  'kanino': 'who',
  'kelan': 'when',
  'kailan': 'when',
  'ngayon': 'today',
  'buwan': 'month',
  'linggo': 'week',
  'araw': 'day',
  'matatapos': 'finish',
  'natitira': 'left',
  'natira': 'left',
  'abutin': 'reach',
  'budget': 'budget',
  'baon': 'spend',
};

final List<(RegExp, String)> _phrases = [
  (RegExp(r'\bmay utang sa akin\b'), 'who owe me'),
  (RegExp(r'\bsino may utang\b'), 'who owe'),
  (RegExp(r'\bkanino ako naniningil\b'), 'who owe me'),
  (RegExp(r'\bmagkano pa\b'), 'howmuch left'),
  (RegExp(r'\bkaya ko pa ba\b'), 'can i'),
  (RegExp(r'\bkaya ko ba\b'), 'can i'),
  (RegExp(r'\bkumusta( ang)? gastos\b'), 'how spending'),
  (RegExp(r'\bpang gastos\b'), 'spend'),
  (RegExp(r'\bhanggang sweldo\b'), 'until payday'),
  (RegExp(r'\bhow much can i\b'), 'howmuch can i'),
  (RegExp(r'\bhow much do i\b'), 'howmuch i'),
  (RegExp(r'\bhow much is\b'), 'howmuch'),
];

String normalize(dynamic raw) {
  var s = (raw ?? '').toString().toLowerCase();
  // JS folds [À-ſ] (U+00C0..U+017F) through the table, leaving unknown
  // characters in that range alone.
  s = s.replaceAllMapped(RegExp(r'[À-ſ]'),
      (m) => _diacritics[m.group(0)] ?? m.group(0)!);
  for (final (re, to) in _phrases) {
    s = s.replaceAll(re, to);
  }
  s = s.replaceAll(RegExp(r'[^a-z0-9%\s]'), ' ');
  final tokens = s
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => _synonyms[t] ?? t);
  return tokens.join(' ');
}

/// Pull the first money-like number out of a message: "2000", "2,000",
/// "1.5k", "P350". Returns null when there is none. A k or m multiplier
/// applies only as a lone suffix right after the number, so "1.5k" is 1500
/// but "2000km" stays 2000 and "2 movie tickets" is 2.
double? extractAmount(dynamic raw) {
  final s = (raw ?? '').toString().toLowerCase().replaceAll(',', '');
  final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(s);
  if (m == null) return null;
  var n = double.tryParse(m.group(0)!);
  if (n == null || !n.isFinite) return null;
  final rest = s.substring(m.end);
  final mult = RegExp(r'^(k|m)(?![a-z0-9])').firstMatch(rest);
  if (mult != null) n *= mult.group(1) == 'k' ? 1000 : 1000000;
  return n;
}
