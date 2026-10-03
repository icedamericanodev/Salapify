import 'receipt_words.dart';
import '../../models/models.dart';

/// Reading a Philippine receipt out of recognised TEXT.
///
/// Founder spec, 2026-09-20, feature 1, "Scan-to-Log". Ported in intent from
/// src/utils/receiptOcrParser.ts, which this deliberately does not follow
/// line for line. See "What the prototype's version actually does" below.
///
/// ## This file does no OCR, and that is the honest shape
///
/// It is a pure function from a `String` to a [ReceiptOcrResult]. Whatever
/// produced the string, a camera, a gallery image, a pasted block of text or
/// one of the built-in samples, is somebody else's problem, and keeping it
/// that way is what makes every rule below testable without a device.
///
/// Turning a PHOTOGRAPH into that string needs
/// `google_mlkit_text_recognition`, which is a native plugin. A native plugin
/// means a new APK and one manual install by the founder, which is why the
/// camera is not wired up in the same change as the parser: the parser works
/// today against the samples and against pasted text, and the camera can be
/// switched on later without any of this moving.
///
/// ## What the prototype's version actually does
///
/// It does not read the image either. `parseReceiptImage` looks at the FILE
/// NAME, matches it against six canned samples, and falls back to the
/// Jollibee one. So photographing a Mercury Drug receipt and saving it as
/// `IMG_4021.jpg` produces a Jollibee purchase, with a merchant, an amount, a
/// TIN and a date, all of it confident and none of it from the paper in your
/// hand. With the BIR fields on a transaction, that is a stranger's TIN
/// written into a row somebody may later claim.
///
/// So the samples here are LABELLED as samples. They exist to demonstrate and
/// to test, they are chosen deliberately by tapping a named chip, and nothing
/// ever falls back to one.

/// One line off the receipt, where the paper itemises.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.desc,
    required this.qty,
    required this.price,
  });

  final String desc;
  final int qty;
  final double price;
}

/// What kind of paper this looks like.
enum ReceiptKind {
  /// Carries a TIN and the words that make it a BIR document.
  officialReceipt,
  grocerySlip,
  ewalletScreenshot,
  posThermal,
  unknown,
}

/// Everything read off one receipt, with how sure the reader is.
class ReceiptOcrResult {
  const ReceiptOcrResult({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.subcategory,
    required this.confidence,
    required this.rawText,
    required this.kind,
    this.accountKind,
    this.taxTinOrRef,
    this.isTaxDeductible = false,
    this.vatAmount,
    this.lineItems = const <ReceiptLineItem>[],
    this.categoryMatched = false,
    this.dateFound = false,
  });

  final String merchant;
  final double amount;
  final DateTime date;
  final String category;
  final String subcategory;

  /// True when a merchant this file knows by name decided the category.
  ///
  /// The Log sheet must not overwrite a category somebody already chose with
  /// a guess, which is the founder's own "Electricity" report applied here
  /// before it can happen again.
  final bool categoryMatched;

  /// True when a date was actually on the paper. False means [date] is today
  /// because nothing was found, and a screen showing it has to say so.
  final bool dateFound;

  /// A KIND of account, never an id.
  ///
  /// The spec asks for a `suggestedAccountId`, matched by looking through the
  /// user's accounts for one whose name or institution is GCash. That is not
  /// ported, and the reason is the defect the pasted-receipt reader already
  /// fixed: the prototype falls back to `accounts[0].id` when nothing
  /// matches, so a mis-parse writes a real expense against whichever account
  /// happens to be first, with no signal at all. A function that never sees
  /// the account list cannot pick the wrong account. The sheet matches this
  /// kind against what the person actually has, exactly as the typed
  /// quick-line already does.
  final AccountKind? accountKind;

  final String? taxTinOrRef;
  final bool isTaxDeductible;

  /// VAT shown on the paper, when the paper shows it. Never derived.
  ///
  /// Twelve percent of the total is NOT the VAT on a receipt that mixes
  /// vatable, zero-rated and exempt lines, which a grocery slip routinely
  /// does, and a wrong VAT figure on a row somebody claims is worse than no
  /// figure at all.
  final double? vatAmount;

  final List<ReceiptLineItem> lineItems;
  final String rawText;
  final ReceiptKind kind;

  /// Zero to one, and every tenth of it is EARNED.
  ///
  /// Not a hardcoded number and not a flattering one. It counts the signals
  /// that were genuinely found, because a confidence figure that does not
  /// move is decoration, and a decoration next to a peso amount reads as a
  /// measurement. The prototype's health check shipped "89% Accuracy" as a
  /// string literal; that is the mistake this field exists not to repeat.
  final double confidence;

  bool get isValid => amount > 0;
}

/// Read a receipt out of [text].
ReceiptOcrResult parseReceiptText(String text) {
  final String raw = text;
  final List<String> lines = raw
      .split('\n')
      .map((String l) => l.trim())
      .where((String l) => l.isNotEmpty)
      .toList();
  final String lower = raw.toLowerCase();

  final ({String name, String category, String subcategory})? known =
      _merchantIn(lower);
  final String merchant = known?.name ?? _fallbackMerchant(lines);

  final double amount = _totalIn(lines) ?? 0;
  final ({DateTime value, bool found}) date = _dateIn(raw);
  final String? tin = _tinIn(raw);
  final String? ref = tin ?? _referenceIn(raw);
  final bool birWords =
      lower.contains('official receipt') ||
      lower.contains('vat reg') ||
      lower.contains('vat registered');

  final double? vat = _vatIn(lines);
  final List<ReceiptLineItem> items = _lineItemsIn(lines);
  final AccountKind? account = _accountKindIn(lower);

  // HOW SURE, counted rather than asserted.
  double confidence = 0.2;
  if (amount > 0) confidence += 0.3;
  if (known != null) confidence += 0.2;
  if (date.found) confidence += 0.1;
  if (tin != null) confidence += 0.1;
  if (items.isNotEmpty) confidence += 0.05;
  if (account != null) confidence += 0.05;
  if (amount <= 0) confidence = 0.05;

  return ReceiptOcrResult(
    merchant: merchant,
    amount: amount,
    date: date.value,
    dateFound: date.found,
    category: known?.category ?? 'Other Expenses',
    subcategory: known?.subcategory ?? 'Miscellaneous Expense',
    categoryMatched: known != null,
    accountKind: account,
    taxTinOrRef: ref,
    // THE PAPER DECIDES, not the app. A TIN or the words that make a document
    // an official receipt are what the BIR itself looks for. It is still only
    // a SUGGESTION: the sheet shows it as a toggle the person can turn off,
    // because whether an expense is deductible depends on their regime and on
    // what the expense was for, neither of which is printed on the paper.
    isTaxDeductible: tin != null || birWords,
    vatAmount: vat,
    lineItems: items,
    rawText: raw,
    kind: _kindOf(lower, tin != null || birWords, items.length),
    confidence: confidence.clamp(0.0, 1.0),
  );
}

/// The merchants this file knows, in the app's OWN category vocabulary.
///
/// The spec names categories like "Transportation", "Healthcare" and
/// "Shopping". Salapify calls those "Transport & Commute", "Health & Medical"
/// and "Shopping & Personal", and the subcategories are its own too. Writing
/// the spec's spelling would file every scanned receipt under a category that
/// does not exist, which is a defect this repository has already met once:
/// the prototype's instalment payments land in a subcategory missing from its
/// own list, so the money sits perfectly in the ledger and vanishes from
/// every summary that reads it.
const List<({List<String> match, String name, String cat, String sub})>
_ocrMerchants = <({List<String> match, String name, String cat, String sub})>[
  (
    match: <String>['jollibee'],
    name: 'Jollibee',
    cat: 'Food & Dining',
    sub: 'Fast Food & Karinderya',
  ),
  (
    match: <String>['mcdonald', 'mc donald', 'mcdo'],
    name: "McDonald's",
    cat: 'Food & Dining',
    sub: 'Fast Food & Karinderya',
  ),
  (
    match: <String>['starbucks'],
    name: 'Starbucks',
    cat: 'Food & Dining',
    sub: 'Coffee & Milk Tea',
  ),
  (
    match: <String>['7-eleven', '7 eleven', 'seven eleven', 'philippine seven'],
    name: '7-Eleven',
    cat: 'Food & Dining',
    sub: 'Office Lunch & Snacks',
  ),
  (
    match: <String>['grabfood', 'grab food', 'foodpanda'],
    name: 'Food delivery',
    cat: 'Food & Dining',
    sub: 'Food Delivery (Grab/Foodpanda)',
  ),
  (
    match: <String>['grabcar', 'grab car', 'angkas', 'joyride', 'grab ride'],
    name: 'Ride hailing',
    cat: 'Transport & Commute',
    sub: 'Ride Hailing (Grab/Angkas/Joyride)',
  ),
  (
    match: <String>['petron', 'shell', 'caltex', 'phoenix petroleum'],
    name: 'Fuel',
    cat: 'Transport & Commute',
    sub: 'Fuel & Gas',
  ),
  (
    match: <String>[
      'puregold',
      'sm supermarket',
      'sm hypermarket',
      'savemore',
      'robinsons supermarket',
      'waltermart',
      'landers',
      's&r',
    ],
    name: 'Supermarket',
    cat: 'Groceries',
    sub: 'Supermarket (SM/Puregold/Robinsons)',
  ),
  (
    match: <String>['mercury drug', 'watsons', 'rose pharmacy', 'southstar'],
    name: 'Pharmacy',
    cat: 'Health & Medical',
    sub: 'Pharmacy & Maintenance Meds',
  ),
  (
    match: <String>['shopee', 'lazada', 'tiktok shop'],
    name: 'Online shopping',
    cat: 'Shopping & Personal',
    sub: 'E-commerce (Shopee/Lazada)',
  ),
  (
    match: <String>['meralco'],
    name: 'Meralco',
    cat: 'Bills & Utilities',
    sub: 'Electricity (Meralco)',
  ),
  (
    match: <String>['maynilad', 'manila water'],
    name: 'Water',
    cat: 'Bills & Utilities',
    sub: 'Water (Maynilad/Manila Water)',
  ),
  (
    match: <String>['pldt', 'converge', 'globe telecom', 'sky broadband'],
    name: 'Internet',
    cat: 'Bills & Utilities',
    sub: 'Home Internet (PLDT/Converge/Globe)',
  ),
];

({String name, String category, String subcategory})? _merchantIn(
  String lower,
) {
  // The SPECIFIC before the general, because "grabfood" contains "grab" and
  // a food delivery filed as a taxi ride is wrong in the one field somebody
  // would use to find it again. The list above is already in that order and
  // this comment is here so a later insertion keeps it.
  for (final ({List<String> match, String name, String cat, String sub}) m
      in _ocrMerchants) {
    if (m.match.any(lower.contains)) {
      return (name: m.name, category: m.cat, subcategory: m.sub);
    }
  }
  return null;
}

/// The first line with something on it, capped, when nothing is recognised.
String _fallbackMerchant(List<String> lines) {
  for (final String l in lines) {
    // A line that is only a number, a date or a separator is not a name.
    if (RegExp(r'^[\d\s\-_=*.,:/#]+$').hasMatch(l)) continue;
    final String cleaned = l.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length < 2) continue;
    return cleaned.length > 30 ? cleaned.substring(0, 30).trim() : cleaned;
  }
  return '';
}

/// Words that mean a line is NOT the total, however much it looks like one.
///
/// `sukli` is change in Filipino and appears on thermal slips from stores
/// that print in Tagalog. A receipt where the customer paid 1,000 for a 240
/// peso purchase shows 760 sukli and 1,000 cash tendered, both larger and
/// more prominent than the figure that matters.
const List<String> _notTheTotal = <String>[
  'subtotal',
  'sub-total',
  'sub total',
  'sukli',
  'change',
  'cash tendered',
  'cash tender',
  'tendered',
  'vat 12',
  'vatable',
  'vat exempt',
  'zero rated',
  'zero-rated',
  'vat amount',
  'less vat',
  'discount',
];

double? _totalIn(List<String> lines) {
  // 1. A line that says it is the total.
  final RegExp labelled = RegExp(
    r'(?:total\s+amount\s+due|total\s+amount|amount\s+due|total\s+sale|grand\s+total|\btotal\b)'
    r'\s*[:=]?\s*(?:php|₱|p)?\s*([0-9][0-9,]*\.[0-9]{2})',
    caseSensitive: false,
  );
  final RegExp paid = RegExp(
    r'(?:\bamount\b|\bpaid\b|\bamount\s+paid\b)\s*[:=]?\s*'
    r'(?:php|₱|p)?\s*([0-9][0-9,]*\.[0-9]{2})',
    caseSensitive: false,
  );

  for (final RegExp re in <RegExp>[labelled, paid]) {
    for (final String line in lines) {
      final String l = line.toLowerCase();
      if (_notTheTotal.any(l.contains)) continue;
      final RegExpMatch? m = re.firstMatch(line);
      if (m != null) {
        final double? v = _money(m.group(1)!);
        if (v != null && v > 0) return v;
      }
    }
  }

  // 2. Nothing said "total". Take the LARGEST currency amount, off lines that
  //    are not disqualified, which is the prototype's own fallback.
  double? biggest;
  final RegExp anyAmount = RegExp(
    r'(?:php|₱|p)\s*([0-9][0-9,]*\.[0-9]{2})',
    caseSensitive: false,
  );
  for (final String line in lines) {
    final String l = line.toLowerCase();
    if (_notTheTotal.any(l.contains)) continue;
    for (final RegExpMatch m in anyAmount.allMatches(line)) {
      final double? v = _money(m.group(1)!);
      if (v != null && (biggest == null || v > biggest)) biggest = v;
    }
  }
  return biggest;
}

double? _money(String s) => double.tryParse(s.replaceAll(',', ''));

/// VAT, only where the paper prints it.
double? _vatIn(List<String> lines) {
  final RegExp re = RegExp(
    r'(?:vat\s*(?:amount|12%?)?|value\s+added\s+tax)\s*[:=]?\s*'
    r'(?:php|₱|p)?\s*([0-9][0-9,]*\.[0-9]{2})',
    caseSensitive: false,
  );
  for (final String line in lines) {
    final String l = line.toLowerCase();
    if (l.contains('exempt') || l.contains('zero')) continue;
    final RegExpMatch? m = re.firstMatch(line);
    if (m != null) {
      final double? v = _money(m.group(1)!);
      if (v != null && v > 0) return v;
    }
  }
  return null;
}

({DateTime value, bool found}) _dateIn(String raw) {
  const List<String> months = <String>[
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  final RegExpMatch? iso = RegExp(
    r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b',
  ).firstMatch(raw);
  if (iso != null) {
    final DateTime? d = _safeDate(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
    if (d != null) return (value: d, found: true);
  }

  // "20 Sep 2026" and "Sep 20, 2026".
  final RegExpMatch? dayFirst = RegExp(
    r'\b(\d{1,2})\s+([A-Za-z]{3,9})\.?\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(raw);
  if (dayFirst != null) {
    final int m = months.indexOf(
      dayFirst.group(2)!.toLowerCase().substring(0, 3),
    );
    if (m >= 0) {
      final DateTime? d = _safeDate(
        int.parse(dayFirst.group(3)!),
        m + 1,
        int.parse(dayFirst.group(1)!),
      );
      if (d != null) return (value: d, found: true);
    }
  }

  final RegExpMatch? monthFirst = RegExp(
    r'\b([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})\b',
    caseSensitive: false,
  ).firstMatch(raw);
  if (monthFirst != null) {
    final int m = months.indexOf(
      monthFirst.group(1)!.toLowerCase().substring(0, 3),
    );
    if (m >= 0) {
      final DateTime? d = _safeDate(
        int.parse(monthFirst.group(3)!),
        m + 1,
        int.parse(monthFirst.group(2)!),
      );
      if (d != null) return (value: d, found: true);
    }
  }

  // DD/MM/YYYY, which is what Philippine receipts print.
  //
  // AMBIGUOUS BY NATURE and resolved deliberately rather than by luck.
  // 05/09/2026 is the 5th of September here and the 9th of May in the US
  // convention, and nothing on the paper says which. Day first is the local
  // reading, so day first is what this uses; where the first number is above
  // 12 it cannot be a month and the other order is forced.
  final RegExpMatch? slashed = RegExp(
    r'\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{2,4})\b',
  ).firstMatch(raw);
  if (slashed != null) {
    int a = int.parse(slashed.group(1)!);
    int b = int.parse(slashed.group(2)!);
    int y = int.parse(slashed.group(3)!);
    if (y < 100) y += 2000;
    if (a > 12 && b <= 12) {
      final DateTime? d = _safeDate(y, b, a);
      if (d != null) return (value: d, found: true);
    } else if (b > 12 && a <= 12) {
      final DateTime? d = _safeDate(y, a, b);
      if (d != null) return (value: d, found: true);
    } else {
      final DateTime? d = _safeDate(y, b, a);
      if (d != null) return (value: d, found: true);
    }
  }

  // NOT FOUND. Today, and the caller is told it is today, so a screen can say
  // "we could not read a date" instead of printing one as though it read it.
  final DateTime now = DateTime.now();
  return (value: DateTime(now.year, now.month, now.day), found: false);
}

/// A real calendar date, or null. `DateTime(2026, 2, 31)` is quietly the 3rd
/// of March, so a misread digit would become a confident wrong date.
DateTime? _safeDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  if (y < 2000 || y > 2100) return null;
  final DateTime made = DateTime(y, m, d);
  if (made.year != y || made.month != m || made.day != d) return null;
  return made;
}

/// A taxpayer identification number, nine digits plus an optional branch
/// code, however the paper spaces it.
String? _tinIn(String raw) {
  final RegExpMatch? m = RegExp(
    r'\b(?:vat\s*reg\.?\s*tin|tin)\s*[:=#]?\s*'
    r'(\d{3}[\-\s]?\d{3}[\-\s]?\d{3}(?:[\-\s]?\d{3,5})?)\b',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  return m.group(1)!.replaceAll(RegExp(r'\s+'), '-');
}

/// An OR, SI, invoice or transaction reference.
String? _referenceIn(String raw) {
  final RegExpMatch? m = RegExp(
    r'\b(?:or|si|invoice|inv|ref(?:erence)?|trans(?:action)?)\s*'
    r'(?:no\.?|number|#)?\s*[:=]?\s*([A-Za-z0-9][A-Za-z0-9\-]{3,})\b',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  final String v = m.group(1)!;
  // A bare number that is really a date or an amount is not a reference.
  if (RegExp(r'^\d{1,2}[\-/]\d{1,2}').hasMatch(v)) return null;
  return v;
}

/// Itemised lines, where the paper itemises. "2 Chickenjoy 180.00".
List<ReceiptLineItem> _lineItemsIn(List<String> lines) {
  final List<ReceiptLineItem> out = <ReceiptLineItem>[];
  final RegExp re = RegExp(
    r'^(?:(\d{1,2})\s*[xX]?\s+)?([A-Za-z][A-Za-z0-9 &\x27.\-/]{2,34}?)\s+'
    r'(?:php|₱|p)?\s*([0-9][0-9,]*\.[0-9]{2})$',
    caseSensitive: false,
  );
  for (final String line in lines) {
    final String l = line.toLowerCase();
    if (_notTheTotal.any(l.contains)) continue;
    if (l.contains('total') || l.contains('tin') || l.contains('vat')) continue;
    final RegExpMatch? m = re.firstMatch(line);
    if (m == null) continue;
    final double? price = _money(m.group(3)!);
    if (price == null || price <= 0) continue;
    final String desc = m.group(2)!.trim();
    if (_notAnItemName(desc)) continue;
    out.add(
      ReceiptLineItem(
        desc: desc,
        qty: int.tryParse(m.group(1) ?? '1') ?? 1,
        price: price,
      ),
    );
  }
  return out;
}

/// A description that is not the name of anything bought.
///
/// Both of these were caught by the tests rather than by reading the code,
/// and both are the same shape: a PAYMENT line has a word and an amount,
/// exactly like an item does.
///
///   "CASH                  2000.00"  became an item called CASH
///   "PHP 2,500.00"                   became an item called PHP
///
/// The second one is the nastier of the two, because an e-wallet screenshot
/// is mostly that shape, so a GCash transfer came back looking like a till
/// receipt with one thing on it. The items then summed to nearly three times
/// the total of the purchase they claimed to itemise.
bool _notAnItemName(String desc) {
  final String d = desc.toLowerCase().trim();
  const List<String> never = <String>[
    'php',
    'p',
    'peso',
    'pesos',
    'cash',
    'change',
    'sukli',
    'tendered',
    'tender',
    'total',
    'subtotal',
    'amount',
    'amount due',
    'amount sent',
    'amount paid',
    'balance',
    'due',
    'vat',
    'vatable',
    'discount',
    'paid',
    'payment',
    'fare',
    'ref',
    'reference',
  ];
  return never.contains(d);
}

/// Which KIND of account this came from. Never an account.
AccountKind? _accountKindIn(String lower) {
  for (final ReceiptSender s in receiptSenders) {
    if (s.match.any(lower.contains)) return s.kind;
  }
  return null;
}

ReceiptKind _kindOf(String lower, bool birWords, int itemCount) {
  if (lower.contains('gcash') ||
      lower.contains('maya') ||
      lower.contains('express send') ||
      lower.contains('reference no')) {
    if (itemCount == 0) return ReceiptKind.ewalletScreenshot;
  }
  if (birWords) return ReceiptKind.officialReceipt;
  if (itemCount >= 3) return ReceiptKind.grocerySlip;
  if (lower.contains('thank you') || lower.contains('pos') || itemCount > 0) {
    return ReceiptKind.posThermal;
  }
  return ReceiptKind.unknown;
}
