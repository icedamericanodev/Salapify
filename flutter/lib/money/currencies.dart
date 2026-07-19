// The currencies the app understands, ported 1:1 from mobile/lib/currencies.js.
// There are deliberately NO exchange rates stored here. Salapify is offline
// first, and a cached rate goes stale silently; a finance app must never
// quietly show a wrong peso figure. When a user logs an expense in another
// currency they give the rate at that moment and we store the already
// converted base amount. Formatting matches the RN app to the digit, golden
// verified.

/// code and symbol, in the same order the RN picker shows.
const List<Map<String, String>> currencies = [
  {'code': 'PHP', 'symbol': '₱'},
  {'code': 'USD', 'symbol': '\$'},
  {'code': 'EUR', 'symbol': '€'},
  {'code': 'GBP', 'symbol': '£'},
  {'code': 'JPY', 'symbol': '¥'},
  {'code': 'CNY', 'symbol': '¥'},
  {'code': 'KRW', 'symbol': '₩'},
  {'code': 'INR', 'symbol': '₹'},
  {'code': 'IDR', 'symbol': 'Rp'},
  {'code': 'MYR', 'symbol': 'RM'},
  {'code': 'SGD', 'symbol': 'S\$'},
  {'code': 'THB', 'symbol': '฿'},
  {'code': 'VND', 'symbol': '₫'},
  {'code': 'HKD', 'symbol': 'HK\$'},
  {'code': 'AUD', 'symbol': 'A\$'},
  {'code': 'CAD', 'symbol': 'C\$'},
  {'code': 'AED', 'symbol': 'AED'},
  {'code': 'SAR', 'symbol': 'SAR'},
  {'code': 'CHF', 'symbol': 'CHF'},
  {'code': 'NZD', 'symbol': 'NZ\$'},
];

/// The sign for a code, falling back to the code itself so an unknown code
/// never renders blank. Matches RN currencySymbol (null and '' give '').
String currencySymbol(dynamic code) {
  for (final c in currencies) {
    if (c['code'] == code) return c['symbol']!;
  }
  return code == null ? '' : code.toString();
}

/// Currencies normally written with no decimal places, so "¥1,000" not
/// "¥1,000.00" stays honest to how they are used.
const Set<String> _zeroDecimal = {'JPY', 'KRW', 'VND', 'IDR'};

/// Comma-grouped integer part, mirroring JS toLocaleString('en-US') grouping.
String _group(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// A full converted amount with its symbol and the right decimals, e.g.
/// "\$12.34", "¥1,300", "₱690.50". Non-finite gives '' like the RN app.
String formatConverted(dynamic amount, String code) {
  final n = amount is num ? amount.toDouble() : double.tryParse('$amount');
  if (n == null || !n.isFinite) return '';
  final dp = _zeroDecimal.contains(code) ? 0 : 2;
  return '${currencySymbol(code)}${_fixed(n, dp)}';
}

/// A short original amount label like "¥1,000" or "\$13", whole numbers only,
/// shown next to a converted expense. Matches RN formatForeign.
String formatForeign(dynamic amount, String code) {
  final n = amount is num ? amount.toDouble() : double.tryParse('$amount');
  if (n == null || !n.isFinite) return '';
  return '${currencySymbol(code)}${_fixed(_jsRound(n).toDouble(), 0)}';
}

/// JS Math.round: half rounds up (toward positive infinity), unlike Dart's
/// round-half-away-from-zero on negatives.
double _jsRound(num x) => (x + 0.5).floorToDouble();

/// n rendered with exactly dp decimals, comma grouped, mirroring
/// toLocaleString('en-US', {min/maxFractionDigits: dp}). Uses JS-style
/// half-up rounding on the last kept digit.
String _fixed(double n, int dp) {
  final neg = n < 0;
  final v = n.abs();
  final factor = _pow10(dp);
  final scaled = _jsRound(v * factor);
  final rounded = scaled / factor;
  var whole = rounded.floor();
  final digits = whole.toString();
  final grouped = _group(digits);
  if (dp == 0) return '${neg && whole != 0 ? '-' : ''}$grouped';
  final fracInt = _jsRound((rounded - whole) * factor).toInt();
  final frac = fracInt.toString().padLeft(dp, '0');
  return '${neg && (whole != 0 || fracInt != 0) ? '-' : ''}$grouped.$frac';
}

int _pow10(int dp) {
  var p = 1;
  for (var i = 0; i < dp; i++) {
    p *= 10;
  }
  return p;
}
