import 'fast_log.dart';
import 'receipt_words.dart';
import '../../models/models.dart';

/// Reading a bank or e-wallet receipt somebody PASTED in.
///
/// Ported from `parsePhilippineSmsReceipt` in src/utils/smsParser.ts, which
/// the founder added to the prototype on 2026-09-20.
///
/// ## It reads pasted TEXT. It does not read your messages.
///
/// That distinction is the whole feature, and the prototype already has it
/// right: its parser is a pure function over a string, fed from a textarea.
/// Nothing anywhere touches an inbox.
///
/// It matters because READ_SMS and RECEIVE_SMS are restricted permissions on
/// Play. An app must be the device's default SMS handler to hold them, a
/// budgeting app is not on the permitted list, and the exception is granted
/// only where "no alternative method exists" to provide the function. The
/// alternative is this file. Asking Google for an exception while shipping
/// the alternative in the same binary would be a strange thing to do.
///
/// So: no manifest change, no permission, no declaration form, and it works
/// today. Nothing in Salapify may ever request either permission, including
/// as an unused placeholder, because the mere presence of a restricted
/// permission triggers the declaration flow.
///
/// ## What it is NOT called
///
/// The prototype names this the "SMS Catcher" and its success toast reads
/// "Auto-caught GCASH". Neither came across. Both describe an app capturing
/// messages by itself, which is not what happens and is the exact impression
/// that makes a reviewer start looking for the permission.
///
/// ## The one real defect fixed on the way
///
/// `suggestedAccountId = accounts[0].id` when nothing matched: a mis-parse
/// wrote a real expense against whichever account happened to be first, with
/// no signal. Here an unmatched account is left NULL and the person picks
/// one, which is the same rule the typed quick-line already follows for the
/// same reason.

/// True when this looks like a receipt message rather than a typed line.
///
/// Length alone is the signal that matters: a quick line is a few words and
/// a receipt is a sentence with a reference number in it. Checking for a
/// provider name FIRST would mean a receipt from a bank nobody listed gets
/// treated as a typed line and parsed into nonsense.
bool looksLikePastedReceipt(String raw) {
  final String t = raw.trim();
  if (t.length < 40) return false;

  final String lower = t.toLowerCase();
  final bool hasMarker =
      receiptSenderWords.any(lower.contains) ||
      RegExp(
        r'\bref(?:erence)?\.?\s*(?:no\.?|number)?\s*[:#]?\s*\w{5,}',
      ).hasMatch(lower) ||
      RegExp(r'\bphp\s*[\d,]').hasMatch(lower);

  return hasMarker && t.split(RegExp(r'\s+')).length >= 8;
}

/// What a pasted receipt means, in the same shape a typed line produces.
///
/// Returning [FastLogResult] rather than a type of its own is deliberate.
/// The Log sheet already has one careful path for turning a guess into a
/// filled form: it applies a category only when one was really named, maps
/// an account KIND rather than an account, and never saves on its own. A
/// second result type would have meant a second path, and the second one
/// would not have had those lessons in it.
/// It takes NO account list, and that is the fix rather than a convenience.
///
/// The prototype's version takes one and ends with
/// `suggestedAccountId = accounts[0].id` when nothing matched, so a
/// mis-parse wrote a real expense against whichever account happened to be
/// first, with no signal. A function that never sees the accounts cannot
/// pick the wrong one. It returns a KIND and the sheet matches that against
/// what the person actually has, the same way the typed quick-line does.
FastLogResult parsePastedReceipt(String raw) {
  final String text = raw.trim();
  final String lower = text.toLowerCase();

  final double? amount = _amountIn(text);
  if (amount == null || amount <= 0) {
    return const FastLogResult(
      isValid: false,
      type: TransactionType.expense,
      amount: 0,
      merchant: '',
      category: 'Food & Dining',
    );
  }

  // INCOME OR EXPENSE. The prototype assumes every receipt is an expense,
  // so "You have received PHP 5,000.00" logs as money leaving. A received
  // amount filed as spending is wrong in both directions at once: the
  // balance falls instead of rising, and the month's spending is overstated.
  final bool received = receiptIncomingWords.any(lower.contains);

  final ({String merchant, String? category}) who = _merchantIn(text, lower);

  // A KIND, or null. Never an account.
  final AccountKind? kind = _kindFor(lower);

  return FastLogResult(
    isValid: true,
    type: received ? TransactionType.income : TransactionType.expense,
    amount: amount,
    merchant: who.merchant,
    category: who.category ?? 'Food & Dining',
    categoryMatched: who.category != null,
    accountKind: kind,
  );
}

/// The amount, from the forms these messages actually use.
///
/// PHP 450.00, ₱450, P1,500.50, 450 pesos. Anchored on the currency marker
/// rather than taking the first run of digits, because these messages are
/// full of numbers that are not the amount: card digits, dates, reference
/// numbers.
double? _amountIn(String text) {
  final String clean = text.replaceAll(',', '');

  final RegExpMatch? marked = RegExp(
    r'(?:php|₱|\bp(?=\d))\s*(\d+(?:\.\d{1,2})?)',
    caseSensitive: false,
  ).firstMatch(clean);
  if (marked != null) {
    final double? v = double.tryParse(marked.group(1)!);
    if (v != null && v > 0) return v;
  }

  final RegExpMatch? suffixed = RegExp(
    r'(\d+(?:\.\d{1,2})?)\s*(?:pesos?|php)\b',
    caseSensitive: false,
  ).firstMatch(clean);
  if (suffixed != null) {
    final double? v = double.tryParse(suffixed.group(1)!);
    if (v != null && v > 0) return v;
  }

  return null;
}

/// Who the money went to, and what kind of spending that is.
///
/// A named merchant brings its category with it. Anything else falls back to
/// the "to X" or "at X" shape with NO category, so the Log sheet leaves the
/// category alone rather than overwriting a correct one with a guess. That
/// is the founder's own "Electricity" report, applied here before it can
/// happen again.
({String merchant, String? category}) _merchantIn(String text, String lower) {
  for (final ReceiptMerchant m in receiptMerchants) {
    if (m.match.any(lower.contains)) {
      return (merchant: m.name, category: m.category);
    }
  }

  final RegExpMatch? toAt = RegExp(
    r'''\b(?:to|at)\s+([A-Za-z0-9&'.\- ]{3,28}?)(?=\s+(?:on|using|via|with|for|last|dated)\b|\s+\d|[.,!]|$)''',
    caseSensitive: false,
  ).firstMatch(text);

  if (toAt != null) {
    final String candidate = toAt.group(1)!.trim();
    final String c = candidate.toLowerCase();
    final bool noise =
        c.contains('php') ||
        c.contains('card') ||
        c.contains('account') ||
        receiptSenderWords.any(c.contains);
    if (!noise && candidate.length >= 3) {
      return (merchant: candidate, category: null);
    }
  }

  return (merchant: '', category: null);
}

/// Which kind of account the message came from, or null.
AccountKind? _kindFor(String lower) {
  for (final ReceiptSender s in receiptSenders) {
    if (s.match.any(lower.contains)) return s.kind;
  }
  return null;
}
