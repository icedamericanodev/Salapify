// The fast log parser. "jollibee 250" becomes a saved expense with a category.
//
// This is principle 1 in 01-vision.md and it is the only reason the Log sheet
// is worth opening: under three seconds from thumb to saved. It is also NEW
// WORK rather than a port. No parser like this exists in either the shipped
// Flutter app or the React Native one before it, which was discovered on
// 2026-09-13 while looking for one to copy. What DID exist, and is reused here
// rather than rewritten, is two pieces of Pan's text layer in taglish.dart:
// normalize (Taglish folding) and extractAmount (the money number). Both are
// golden locked against the RN original.
//
// Pure Dart, no Flutter, like every other file in core/money.
import 'taglish.dart';

/// What one typed line was understood to mean.
///
/// Every field is a GUESS the user can overrule before saving. The Log sheet
/// shows this back to them in one line before anything is written, so a wrong
/// guess is caught in the same glance rather than discovered in a report six
/// weeks later.
class ParsedLine {
  const ParsedLine({
    required this.type,
    required this.amount,
    required this.label,
    this.categoryId,
  });

  /// 'expense', 'income' or 'transfer'. Never 'debt' or 'adjustment': those
  /// are made somewhere that knows who owes whom, not by reading a sentence.
  final String type;

  /// Pesos, or null when the line had no number in it yet. Null is the normal
  /// state while somebody is still typing the first word.
  final double? amount;

  /// What to call the entry, in the spelling the person actually typed.
  final String label;

  /// A default category id, or null for "no idea". Null is a real answer, not
  /// a failure. See [guessCategoryId].
  final String? categoryId;

  /// Did the line yield anything at all worth showing back?
  ///
  /// The Log sheet uses this to decide whether to draw the "Got it" line, so
  /// an empty field does not sit under a confident reading of nothing.
  bool get understood => amount != null || label.isNotEmpty;
}

/// Words that flip the line to income, AFTER [normalize] has folded Taglish.
///
/// This set is short because normalize does most of the work for free: it
/// already folds sweldo, suweldo and sahod to 'payday' through a table that is
/// golden locked, so the Filipino half of this arrives without a second
/// vocabulary to keep in step.
const _incomeWords = {
  'payday',
  'salary',
  'sahod',
  'bonus',
  'refund',
  'rebate',
  'cashback',
  'commission',
  'allowance',
  'received',
  'income',
  'paid me',
  'sideline',
  'raket',
  'tips',
  'dividend',
  'interest',
};

/// Words that mean money moved between the person's OWN accounts. Nothing
/// left their pocket, so this must never read as an expense.
const _transferWords = {
  'transfer',
  'transferred',
  'moved',
  'withdraw',
  'withdrew',
  'withdrawal',
  'deposit',
  'deposited',
  'cashin',
  'cashout',
  'load up',
  'topup',
};

/// Merchant and keyword vocabulary, folded token to default category id.
///
/// This table is where the app earns its keep for a Filipino user: a tracker
/// that knows Jollibee is food and Angkas is transport removes a tap from the
/// most frequent action in the app, and a generic one cannot.
///
/// The ids are the eight defaults in data/backup.dart. Every guess is checked
/// against the user's LIVE category list before it is used, so a renamed or
/// deleted category never produces a dangling reference. See [guessCategoryId].
const Map<String, String> categoryKeywords = {
  // Food. The single most logged category in the shipped app.
  'jollibee': 'cat_food',
  'mcdo': 'cat_food',
  'mcdonalds': 'cat_food',
  'chowking': 'cat_food',
  'greenwich': 'cat_food',
  'manginasal': 'cat_food',
  'inasal': 'cat_food',
  'kfc': 'cat_food',
  'starbucks': 'cat_food',
  'dunkin': 'cat_food',
  'tapsi': 'cat_food',
  'carinderia': 'cat_food',
  'kainan': 'cat_food',
  'lunch': 'cat_food',
  'dinner': 'cat_food',
  'breakfast': 'cat_food',
  'merienda': 'cat_food',
  'coffee': 'cat_food',
  'kape': 'cat_food',
  'ulam': 'cat_food',
  'kanin': 'cat_food',
  'baon': 'cat_food',
  'milktea': 'cat_food',
  'foodpanda': 'cat_food',
  'grabfood': 'cat_food',

  // Transport.
  'grab': 'cat_transport',
  'angkas': 'cat_transport',
  'joyride': 'cat_transport',
  'jeep': 'cat_transport',
  'jeepney': 'cat_transport',
  'tricycle': 'cat_transport',
  'traysikel': 'cat_transport',
  'taxi': 'cat_transport',
  'mrt': 'cat_transport',
  'lrt': 'cat_transport',
  'bus': 'cat_transport',
  'fare': 'cat_transport',
  'pamasahe': 'cat_transport',
  'gas': 'cat_transport',
  'gasoline': 'cat_transport',
  'petron': 'cat_transport',
  'shell': 'cat_transport',
  'caltex': 'cat_transport',
  'parking': 'cat_transport',
  'toll': 'cat_transport',

  // Load and connectivity.
  'load': 'cat_load',
  'globe': 'cat_load',
  'smart': 'cat_load',
  'tnt': 'cat_load',
  'dito': 'cat_load',
  'sun': 'cat_load',
  'prepaid': 'cat_load',
  'data': 'cat_load',
  'wifi': 'cat_load',
  'internet': 'cat_load',
  'converge': 'cat_load',
  'pldt': 'cat_load',

  // Bills.
  'meralco': 'cat_bills',
  'maynilad': 'cat_bills',
  'manilawater': 'cat_bills',
  'kuryente': 'cat_bills',
  'tubig': 'cat_bills',
  'electric': 'cat_bills',
  'electricity': 'cat_bills',
  'water': 'cat_bills',
  'rent': 'cat_bills',
  'upa': 'cat_bills',
  'bills': 'cat_bills',
  'netflix': 'cat_bills',
  'spotify': 'cat_bills',
  'subscription': 'cat_bills',
  'association': 'cat_bills',
  'cable': 'cat_bills',

  // Groceries.
  'groceries': 'cat_groceries',
  'grocery': 'cat_groceries',
  'palengke': 'cat_groceries',
  'market': 'cat_groceries',
  'puregold': 'cat_groceries',
  'sm': 'cat_groceries',
  'robinsons': 'cat_groceries',
  'landers': 'cat_groceries',
  'smarket': 'cat_groceries',
  'savemore': 'cat_groceries',
  'shopwise': 'cat_groceries',
  'sari': 'cat_groceries',
  'suki': 'cat_groceries',

  // Fun.
  'movie': 'cat_fun',
  'sine': 'cat_fun',
  'cinema': 'cat_fun',
  'concert': 'cat_fun',
  'game': 'cat_fun',
  'steam': 'cat_fun',
  'inuman': 'cat_fun',
  'beer': 'cat_fun',
  'videoke': 'cat_fun',
  'karaoke': 'cat_fun',
  'gimik': 'cat_fun',
  'lakwatsa': 'cat_fun',

  // Padala, money sent to family. First class in a Filipino tracker.
  'padala': 'cat_padala',
  'remittance': 'cat_padala',
  'palawan': 'cat_padala',
  'cebuana': 'cat_padala',
  'western': 'cat_padala',
  'nanay': 'cat_padala',
  'tatay': 'cat_padala',
  'mama': 'cat_padala',
  'papa': 'cat_padala',
  'allowance ni': 'cat_padala',

  // Health.
  'mercury': 'cat_health',
  'watsons': 'cat_health',
  'southstar': 'cat_health',
  'pharmacy': 'cat_health',
  'botika': 'cat_health',
  'gamot': 'cat_health',
  'medicine': 'cat_health',
  'doctor': 'cat_health',
  'doktor': 'cat_health',
  'hospital': 'cat_health',
  'clinic': 'cat_health',
  'dentist': 'cat_health',
  'checkup': 'cat_health',
  'vitamins': 'cat_health',
};

/// The same number-shaped run [extractAmount] reads, so the label can be cut
/// out around it.
///
/// Deliberately NOT a second amount parser. The VALUE always comes from
/// extractAmount and only from there, because that function is golden locked
/// against the RN original and handles the cases that matter ("1.5k", "2,000",
/// "P350"). This regex exists purely to know WHERE in the raw string the
/// number sits, so the label can be the text around it in its real spelling.
///
/// If the two ever disagreed the label would be slightly wrong and the money
/// would still be right, which is the correct way round for them to fail. A
/// test asserts they agree anyway.
final _numberRun = RegExp(
  r'\d[\d,]*(?:\.\d+)?\s*(?:k|m)?\b',
  caseSensitive: false,
);

/// A currency mark or a bare minus sitting against the number, so "P350" and
/// "-350" do not leave "P" or "-" behind as the label.
final _currencyMark = RegExp(r'[₱P\$]\s*$', caseSensitive: false);

/// Read one typed line.
///
/// [categories] is the user's live category list (the maps out of the ledger),
/// used only to check that a guessed id still exists.
ParsedLine parseLogLine(String raw, {dynamic categories}) {
  final text = raw.trim();
  if (text.isEmpty) {
    return const ParsedLine(type: 'expense', amount: null, label: '');
  }

  final amount = extractAmount(text);
  final folded = normalize(text);
  final type = _guessType(folded);
  final label = _labelFrom(text);

  return ParsedLine(
    type: type,
    amount: amount,
    label: label,
    // Categories are an expense-side idea. Tagging income with "Food" would be
    // meaningless, and tagging a transfer would double-count it in a budget.
    categoryId: type == 'expense'
        ? guessCategoryId(folded, categories: categories)
        : null,
  );
}

String _guessType(String folded) {
  final tokens = folded.split(' ').where((t) => t.isNotEmpty).toSet();
  // Transfer is checked FIRST. "deposit 5000" is money moving into an account
  // the person already owns, not income, and reading it as income would invent
  // money that does not exist.
  for (final w in _transferWords) {
    if (tokens.contains(w) || folded.contains(w)) return 'transfer';
  }
  for (final w in _incomeWords) {
    if (tokens.contains(w) || folded.contains(w)) return 'income';
  }
  return 'expense';
}

/// The text around the number, in the spelling the person typed.
///
/// Cut from the RAW string, never from [normalize]'s output: normalize
/// lowercases and strips punctuation, which is exactly right for matching
/// keywords and exactly wrong for a name a person will read back later.
String _labelFrom(String raw) {
  var s = raw;
  final m = _numberRun.firstMatch(s);
  if (m != null) {
    var before = s.substring(0, m.start);
    // Drop a currency mark or minus left dangling by the cut.
    before = before.replaceAll(_currencyMark, '');
    before = before.replaceAll(RegExp(r'[-+]\s*$'), '');
    s = '$before ${s.substring(m.end)}';
  }
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Strip leading connectives left behind by the cut, like "for" in
  // "250 for jollibee".
  s = s.replaceFirst(
    RegExp(r'^(for|sa|kay|ng|na|to)\s+', caseSensitive: false),
    '',
  );
  s = s.trim();
  if (s.isEmpty) return '';
  return _titleCase(s);
}

/// "jollibee" to "Jollibee", "mang inasal" to "Mang Inasal".
///
/// A word already carrying an interior capital is left alone, so "GCash" and
/// "SM" survive being typed correctly rather than being flattened to "Gcash".
String _titleCase(String s) {
  return s
      .split(' ')
      .map((w) {
        if (w.isEmpty) return w;
        if (w.substring(1).contains(RegExp(r'[A-Z]'))) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Guess a category from folded tokens, or return null.
///
/// Three rules, and all three are about being WRONG LESS OFTEN rather than
/// right more often. A category the person taps once is cheap. A wrong
/// category they never notice quietly poisons every budget and every report
/// that reads it, for months, and it is the kind of error nobody goes looking
/// for because nothing looks broken.
///
///   1. No keyword match means NO GUESS. Silence is a real answer.
///   2. A guessed id must still exist in [categories]. Categories can be
///      renamed and deleted, so the live list decides, never this table.
///   3. The FIRST token wins, scanning left to right. "grab groceries" is a
///      grocery run paid through Grab in most real usage, but arguing either
///      way is guessing; taking the leftmost word at least makes the rule
///      predictable and explainable to the person using it.
String? guessCategoryId(String folded, {dynamic categories}) {
  final live = _liveIds(categories);
  for (final token in folded.split(' ')) {
    if (token.isEmpty) continue;
    final id = categoryKeywords[token];
    if (id == null) continue;
    // Rule 2. When the category is gone, so is the guess: better no tag than
    // a tag pointing at nothing.
    if (live != null && !live.contains(id)) continue;
    return id;
  }
  return null;
}

/// The ids in the user's category list, or null when no list was supplied
/// (which means "do not check", used by the pure vocabulary tests).
Set<String>? _liveIds(dynamic categories) {
  if (categories is! List) return null;
  return {
    for (final c in categories)
      if (c is Map && c['id'] is String) c['id'] as String,
  };
}
