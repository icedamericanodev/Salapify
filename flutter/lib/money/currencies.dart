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

/// n rendered with exactly dp decimals, comma grouped, mirroring V8
/// toLocaleString('en-US', {min/maxFractionDigits: dp}). V8 rounds the SHORTEST
/// decimal representation half up, not the raw binary double, so 1.005 becomes
/// "1.01"; a naive multiply-then-floor would wrongly give "1.00". So this
/// rounds the decimal STRING. The sign follows the input (V8 keeps a minus even
/// on a value that rounds to zero, e.g. "-0.00"), matching the RN app.
String _fixed(double n, int dp) {
  final neg = n < 0;
  final mag = n.abs();
  var s = mag.toString();
  // Only absurd magnitudes (far past any real money value) print in
  // exponential form; accept a plain binary-rounded expansion there.
  if (s.contains('e') || s.contains('E')) s = mag.toStringAsFixed(dp);
  final dot = s.indexOf('.');
  var intPart = dot == -1 ? s : s.substring(0, dot);
  var fracPart = dot == -1 ? '' : s.substring(dot + 1);
  if (fracPart.length > dp) {
    final roundUp = fracPart.codeUnitAt(dp) - 48 >= 5;
    var kept = dp == 0 ? '' : fracPart.substring(0, dp);
    if (roundUp) {
      final carried = _incDecimal('$intPart$kept');
      if (dp == 0) {
        intPart = carried;
        kept = '';
      } else {
        intPart = carried.substring(0, carried.length - dp);
        kept = carried.substring(carried.length - dp);
      }
    }
    fracPart = kept;
  } else {
    fracPart = fracPart.padRight(dp, '0');
  }
  intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  final grouped = _group(intPart);
  final sign = neg ? '-' : '';
  return dp == 0 ? '$sign$grouped' : '$sign$grouped.$fracPart';
}

/// Add one to the last digit of a decimal digit string, carrying left.
String _incDecimal(String digits) {
  final buf = digits.split('');
  var carry = true;
  for (var i = buf.length - 1; i >= 0 && carry; i--) {
    final d = buf[i].codeUnitAt(0) - 48 + 1;
    if (d == 10) {
      buf[i] = '0';
    } else {
      buf[i] = String.fromCharCode(48 + d);
      carry = false;
    }
  }
  return carry ? '1${buf.join()}' : buf.join();
}
