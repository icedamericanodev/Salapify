import '../../models/models.dart';

/// The fast-log parser, ported from src/utils/fastlog.ts.
///
/// Type "Jollibee 500" and it works out that this is a 500 peso expense at
/// Jollibee under Food & Dining. It understands Taglish, because that is how
/// people actually write a note to themselves: "padala kay nanay 8000 palawan"
/// becomes an 8,000 remittance to Nanay.
///
/// It reads five things out of one line:
///   the AMOUNT      250, 250.50, 2,500, PHP250
///   the ACCOUNT     gcash, maya, cash, a bank name, a card
///   the PERSON      "kay nanay", "ni kuya", "for mama"
///   the TYPE        sweldo and client mean income, lipat means a transfer
///   the CATEGORY    from the keyword map, first match in the line wins
///
/// Every behaviour here is the prototype's, including the odd ones, and the
/// vectors in test/core/money/fast_log_golden_test.dart were produced by
/// running the TypeScript rather than by reasoning about it.
///
/// ONE THING IS OURS, and it is flagged rather than folded in. The prototype
/// falls back to 'Food & Dining' for any word it does not know, so it answers
/// confidently and wrongly instead of not answering. The engine still computes
/// that same fallback, which is why the vectors are untouched, but it now also
/// reports whether anything DECIDED the category, and the plain English words
/// an English-first app needs were added to the map. See categoryMatched.
class FastLogResult {
  const FastLogResult({
    required this.isValid,
    required this.type,
    required this.amount,
    required this.merchant,
    required this.category,
    this.categoryMatched = false,
    this.person,
    this.accountKind,
    this.profile,
  });

  /// False when no positive amount was found. The sheet uses this to decide
  /// whether the line is worth applying at all.
  final bool isValid;
  final TransactionType type;
  final double amount;
  final String merchant;
  final String category;

  /// Whether anything in the line actually DECIDED the category, as opposed to
  /// the category being the fallback nobody chose.
  ///
  /// This exists because the fallback is 'Food & Dining', so an unrecognised
  /// word does not produce "I do not know", it produces a confident and wrong
  /// answer. The founder typed "Electricity" and got Food & Dining, and 37 of
  /// 60 common English words behaved the same way. The engine still computes
  /// exactly what the prototype computes, so the vectors are untouched; this
  /// flag is what lets the SHEET decline to apply a guess, which is where the
  /// defence belongs.
  final bool categoryMatched;
  final String? person;

  /// A HINT, not an account. The sheet matches it against the real accounts
  /// and ignores it when nothing fits.
  final AccountKind? accountKind;
  final ProfileEntity? profile;
}

/// The keyword map. The first block is the prototype's own 145, extracted
/// rather than retyped, because a hand-copied list of 145 entries is a list
/// with a typo in it. The second block, clearly marked, is ours.
///
/// No count in this sentence on purpose. The last version of it said 145 and
/// was wrong the moment a word was added, two lines above a rule about numbers
/// in prose going stale.
const Map<String, String> fastLogCategoryKeywords = <String, String>{
  'jollibee': 'Food & Dining',
  'mcdonalds': 'Food & Dining',
  'mcdo': 'Food & Dining',
  'starbucks': 'Food & Dining',
  'coffee': 'Food & Dining',
  'kape': 'Food & Dining',
  'chowking': 'Food & Dining',
  'manginasal': 'Food & Dining',
  'inasal': 'Food & Dining',
  'kfc': 'Food & Dining',
  'lunch': 'Food & Dining',
  'dinner': 'Food & Dining',
  'breakfast': 'Food & Dining',
  'almusal': 'Food & Dining',
  'tanghalian': 'Food & Dining',
  'hapunan': 'Food & Dining',
  'merienda': 'Food & Dining',
  'snack': 'Food & Dining',
  'food': 'Food & Dining',
  'samgyup': 'Food & Dining',
  'milktea': 'Food & Dining',
  'boba': 'Food & Dining',
  'karinderya': 'Food & Dining',
  'taho': 'Food & Dining',
  'pares': 'Food & Dining',
  'siomai': 'Food & Dining',
  'foodpanda': 'Food & Dining',
  'grabfood': 'Food & Dining',
  'angkas': 'Transport & Commute',
  'grab': 'Transport & Commute',
  'joyride': 'Transport & Commute',
  'moveit': 'Transport & Commute',
  'taxi': 'Transport & Commute',
  'mrt': 'Transport & Commute',
  'lrt': 'Transport & Commute',
  'gas': 'Transport & Commute',
  'gasoline': 'Transport & Commute',
  'petron': 'Transport & Commute',
  'shell': 'Transport & Commute',
  'caltex': 'Transport & Commute',
  'toll': 'Transport & Commute',
  'rfid': 'Transport & Commute',
  'easytrip': 'Transport & Commute',
  'autosweep': 'Transport & Commute',
  'jeep': 'Transport & Commute',
  'jeepney': 'Transport & Commute',
  'trike': 'Transport & Commute',
  'tricycle': 'Transport & Commute',
  'bus': 'Transport & Commute',
  'pamasahe': 'Transport & Commute',
  'commute': 'Transport & Commute',
  'parking': 'Transport & Commute',
  'puregold': 'Groceries',
  'sm': 'Groceries',
  'supermarket': 'Groceries',
  'robinsons': 'Groceries',
  'grocery': 'Groceries',
  'palengke': 'Groceries',
  'waltermart': 'Groceries',
  'landmark': 'Groceries',
  'dali': 'Groceries',
  'oave': 'Groceries',
  'pantry': 'Groceries',
  'bigas': 'Groceries',
  'ulam': 'Groceries',
  'meralco': 'Bills & Utilities',
  'kuryente': 'Bills & Utilities',
  'maynilad': 'Bills & Utilities',
  'manilawater': 'Bills & Utilities',
  'tubig': 'Bills & Utilities',
  'pldt': 'Bills & Utilities',
  'converge': 'Bills & Utilities',
  'globe': 'Bills & Utilities',
  'smart': 'Bills & Utilities',
  'dito': 'Bills & Utilities',
  'load': 'Bills & Utilities',
  'postpaid': 'Bills & Utilities',
  'netflix': 'Bills & Utilities',
  'spotify': 'Bills & Utilities',
  'icloud': 'Bills & Utilities',
  'youtube': 'Bills & Utilities',
  'rent': 'Housing & Rent',
  'upa': 'Housing & Rent',
  'condo': 'Housing & Rent',
  'wifi': 'Bills & Utilities',
  'shopee': 'Shopping & Personal',
  'lazada': 'Shopping & Personal',
  'tiktok': 'Shopping & Personal',
  'budol': 'Shopping & Personal',
  'uniqlo': 'Shopping & Personal',
  'zara': 'Shopping & Personal',
  'h&m': 'Shopping & Personal',
  'clothes': 'Shopping & Personal',
  'damit': 'Shopping & Personal',
  'watsons': 'Health & Medical',
  'mercury': 'Health & Medical',
  'generika': 'Health & Medical',
  'gamot': 'Health & Medical',
  'meds': 'Health & Medical',
  'doctor': 'Health & Medical',
  'padala': 'Family Support & Remittance',
  'remit': 'Family Support & Remittance',
  'palawan': 'Family Support & Remittance',
  'cebuana': 'Family Support & Remittance',
  'lbc': 'Family Support & Remittance',
  'allowance': 'Family Support & Remittance',
  'baon': 'Family Support & Remittance',
  'tuition': 'Family Support & Remittance',
  'tulong': 'Family Support & Remittance',
  'utang': 'Debt & Loan Servicing',
  'bayad': 'Debt & Loan Servicing',
  'hulog': 'Debt & Loan Servicing',
  'spaylater': 'Debt & Loan Servicing',
  'lazpaylater': 'Debt & Loan Servicing',
  'homecredit': 'Debt & Loan Servicing',
  'ggives': 'Debt & Loan Servicing',
  'gcredit': 'Debt & Loan Servicing',
  'loan': 'Debt & Loan Servicing',
  'sweldo': 'Salary & Compensation',
  'salary': 'Salary & Compensation',
  'sahod': 'Salary & Compensation',
  'payroll': 'Salary & Compensation',
  'bonus': 'Salary & Compensation',
  'thirteenth': 'Salary & Compensation',
  '13th': 'Salary & Compensation',
  'pamasko': 'Other Income',
  'tip': 'Other Income',
  'mp2': 'Investment & Passive Income',
  'pagibig': 'Investment & Passive Income',
  'seabank': 'Investment & Passive Income',
  'gotyme': 'Investment & Passive Income',
  'stocks': 'Investment & Passive Income',
  'dividend': 'Investment & Passive Income',
  'interest': 'Investment & Passive Income',
  'client': 'Business Revenue',
  'retainer': 'Business Revenue',
  'benta': 'Business Revenue',
  'resell': 'Side-hustle & Gig Income',
  'gig': 'Side-hustle & Gig Income',
  'upwork': 'Side-hustle & Gig Income',
  'freelance': 'Side-hustle & Gig Income',
  'ambag': 'Bills & Utilities',
  'ambagan': 'Bills & Utilities',
  'share': 'Bills & Utilities',
  'hati': 'Bills & Utilities',

  // ---------------------------------------------------------------------
  // PLAIN ENGLISH, added 2026-09-18 after the founder typed "Electricity"
  // and got Food & Dining.
  //
  // The prototype's list is brand names and Filipino: it knows meralco and
  // kuryente and has never heard of electricity. That was survivable while
  // the app was the founder's own, and it is not survivable for a public
  // app whose UI is English first (CLAUDE.md, founder decision 2026-07-23).
  // Measured before fixing: 37 of 60 common English money words were absent,
  // and every one of them landed on Food & Dining.
  //
  // This is a DIVERGENCE from src/, deliberately. Everything above is the
  // prototype's map, extracted rather than retyped; everything below is ours.
  // Keeping the two blocks separate is what lets a future re-extraction of
  // the prototype's list replace the top half without silently deleting this.
  'electricity': 'Bills & Utilities',
  'electric': 'Bills & Utilities',
  'water': 'Bills & Utilities',
  'internet': 'Bills & Utilities',
  'broadband': 'Bills & Utilities',
  'cable': 'Bills & Utilities',
  'subscription': 'Bills & Utilities',
  'utilities': 'Bills & Utilities',

  'mortgage': 'Housing & Rent',
  'dorm': 'Housing & Rent',
  'association': 'Housing & Rent',
  'dues': 'Housing & Rent',

  'restaurant': 'Food & Dining',
  'takeout': 'Food & Dining',
  'groceries': 'Groceries',
  'market': 'Groceries',

  'train': 'Transport & Commute',
  'fuel': 'Transport & Commute',
  'fare': 'Transport & Commute',

  'dentist': 'Health & Medical',
  'medicine': 'Health & Medical',
  'pharmacy': 'Health & Medical',
  'hospital': 'Health & Medical',
  'clinic': 'Health & Medical',
  'checkup': 'Health & Medical',
  'vitamins': 'Health & Medical',

  'shoes': 'Shopping & Personal',
  'haircut': 'Shopping & Personal',
  'salon': 'Shopping & Personal',
  'barber': 'Shopping & Personal',
  'gift': 'Shopping & Personal',

  'movie': 'Entertainment & Leisure',
  'cinema': 'Entertainment & Leisure',
  'concert': 'Entertainment & Leisure',
  'gym': 'Entertainment & Leisure',
  'hobby': 'Entertainment & Leisure',

  'installment': 'Debt & Loan Servicing',
  'amortization': 'Debt & Loan Servicing',

  'school': 'Family Support & Remittance',

  // Left out ON PURPOSE, because a wrong confident answer is the defect being
  // fixed and these words cannot be read without context:
  //   bill      a restaurant bill and an electricity bill are both "the bill"
  //   payment   every entry is a payment of something
  //   credit    already an ACCOUNT hint, and "credit" alone names no category
  //   phone     the monthly bill, or the handset; load and postpaid cover the
  //             Philippine bill case already
  //   power     the utility, or a power bank
  //   game      an evening out, or a purchase
  //   refund    a direction of travel, not a category
  // Each of those now falls through to "no category recognised", which is the
  // honest answer and leaves the picker to the person.
};

/// Words that flip the entry from an expense to something else.
const List<String> _incomeWords = <String>[
  'sweldo',
  'salary',
  'sahod',
  'income',
  'bonus',
  'freelance',
  'client',
  '13th',
  'thirteenth',
  'benta',
  'payout',
];
const List<String> _businessWords = <String>[
  'client',
  'benta',
  'retainer',
  'upwork',
  'freelance',
];
const List<String> _transferWords = <String>[
  'transfer',
  'lipat',
  'send',
  'move',
];
const List<String> _householdWords = <String>[
  'ambag',
  'ambagan',
  'kuryente',
  'tubig',
  'pambahay',
];

final RegExp _amount = RegExp(r'(?:₱|\b)(\d+(?:,\d{3})*(?:\.\d{1,2})?)\b');
final RegExp _person = RegExp(
  r'(?:kay|ni|to|for)\s+([a-zA-Z]+)',
  caseSensitive: false,
);
final RegExp _gcash = RegExp(r'\b(gcash|gc)\b', caseSensitive: false);
final RegExp _maya = RegExp(r'\b(maya|paymaya)\b', caseSensitive: false);
final RegExp _cash = RegExp(
  r'\b(cash|barya|alkansya|wallet)\b',
  caseSensitive: false,
);
final RegExp _bank = RegExp(
  r'\b(bpi|bdo|ub|unionbank|seabank|gotyme|metrobank|bank)\b',
  caseSensitive: false,
);
final RegExp _credit = RegExp(
  r'\b(spaylater|lazpaylater|homecredit|cc|card)\b',
  caseSensitive: false,
);

FastLogResult parseFastLog(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const FastLogResult(
      isValid: false,
      type: TransactionType.expense,
      amount: 0,
      merchant: '',
      category: 'Food & Dining',
    );
  }

  double amount = 0;
  String rest = trimmed;
  final RegExpMatch? m = _amount.firstMatch(trimmed);
  if (m != null) {
    amount = double.parse(m.group(1)!.replaceAll(',', ''));
    // Replaces the FIRST occurrence only, matching JS String.replace with a
    // string argument. A line with the same digits twice keeps the second.
    rest = trimmed.replaceFirst(m.group(0)!, '').trim();
  }

  // Account hints. Note that gcash, maya and cash are REMOVED from the text
  // and bank and card are NOT, which is the prototype's behaviour and is why
  // "meralco 2840 bpi" ends up with the merchant "Meralco Bpi".
  AccountKind? accountKind;
  if (_gcash.hasMatch(rest)) {
    accountKind = AccountKind.gcash;
    rest = rest.replaceAll(_gcash, '').trim();
  } else if (_maya.hasMatch(rest)) {
    accountKind = AccountKind.maya;
    rest = rest.replaceAll(_maya, '').trim();
  } else if (_cash.hasMatch(rest)) {
    accountKind = AccountKind.cash;
    rest = rest.replaceAll(_cash, '').trim();
  } else if (_bank.hasMatch(rest)) {
    accountKind = AccountKind.bank;
  } else if (_credit.hasMatch(rest)) {
    accountKind = AccountKind.credit;
  }

  final RegExpMatch? pm = _person.firstMatch(rest);
  final String? person = pm == null
      ? null
      : pm.group(1)![0].toUpperCase() + pm.group(1)!.substring(1);

  final List<String> words = rest
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();

  TransactionType type = TransactionType.expense;
  String category = 'Food & Dining';
  ProfileEntity profile = ProfileEntity.personal;

  // Tracks whether the category was DECIDED or merely defaulted to. The type
  // branches below decide one on purpose, so they set it; the initial
  // 'Food & Dining' above is nobody's decision and deliberately does not.
  bool categoryMatched = false;

  if (words.any(_incomeWords.contains)) {
    type = TransactionType.income;
    category = 'Salary & Compensation';
    categoryMatched = true;
    if (words.any(_businessWords.contains)) {
      profile = ProfileEntity.business;
      category = 'Business Revenue';
    }
  } else if (words.any(_transferWords.contains)) {
    type = TransactionType.transfer;
    category = 'Transfer';
    categoryMatched = true;
  } else if (words.any(_householdWords.contains)) {
    profile = ProfileEntity.household;
  }

  // First keyword in the LINE wins, not the strongest match. "ambag kuryente"
  // hits ambag first and both map to Bills & Utilities anyway.
  for (final String w in words) {
    final String? hit = fastLogCategoryKeywords[w];
    if (hit != null) {
      category = hit;
      categoryMatched = true;
      break;
    }
  }

  final String merchant = rest.isEmpty
      ? 'Quick Entry'
      : rest
            .split(' ')
            .where((String w) => w.isNotEmpty)
            .map((String w) => w[0].toUpperCase() + w.substring(1))
            .join(' ');

  return FastLogResult(
    isValid: amount > 0,
    type: type,
    amount: amount,
    merchant: merchant,
    category: category,
    categoryMatched: categoryMatched,
    person: person,
    accountKind: accountKind,
    profile: profile,
  );
}
