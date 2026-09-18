import 'package:intl/intl.dart';

/// Peso formatting, ported from the prototype's src/utils/format.ts.
/// The prototype uses toLocaleString('en-PH'), which groups in threes and
/// shows two decimals by default, so that is what these mirror.

// The locale is deliberately NOT named here. Passing 'en_PH' makes intl demand
// initializeDateFormatting() before first use, and without it the very first
// build of any screen showing a date throws LocaleDataException. The screenshot
// harness caught exactly that on Home.
//
// Nothing is lost by leaving it off: en-PH groups in threes with a comma and
// separates decimals with a dot, which is what these explicit patterns already
// say. The pattern is the contract, not the locale name.
final NumberFormat _withDecimals = NumberFormat('#,##0.00');
final NumberFormat _noDecimals = NumberFormat('#,##0');

/// Always the absolute value, the way the prototype does it. The sign is a
/// presentation decision the caller makes, not something baked into the number.
String formatPeso(num amount, {bool showDecimals = true}) {
  final String body = showDecimals
      ? _withDecimals.format(amount.abs())
      : _noDecimals.format(amount.abs());
  return '₱$body';
}

/// Income reads with a leading plus, spending reads plain.
String formatSignedPeso(num amount, {bool isIncome = false}) {
  final String formatted = formatPeso(amount.abs());
  if (isIncome || amount > 0) {
    return '+$formatted';
  }
  return formatted;
}

/// "Today", "Yesterday", or a short weekday date. Takes an ISO YYYY-MM-DD
/// string and a clock, so a test can pin "today" instead of hoping.
String formatDateLabel(String isoDate, {DateTime? now}) {
  final DateTime? date = DateTime.tryParse(isoDate);
  if (date == null) return isoDate;

  final DateTime today = now ?? DateTime.now();
  final DateTime yesterday = today.subtract(const Duration(days: 1));

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  if (sameDay(date, today)) return 'Today';
  if (sameDay(date, yesterday)) return 'Yesterday';

  // Same reason as the number patterns above: no locale name, so no
  // initializeDateFormatting() is required before the first screen builds.
  return DateFormat('EEE, MMM d').format(date);
}
