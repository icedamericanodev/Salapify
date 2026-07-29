// The one money formatter every SCREEN uses, in plain Dart.
//
// It lived in screens/overview.dart, which imports Flutter, so anything that
// had to stay Flutter-free could not reach it. The home screen tile is exactly
// that: money/widget_tile.dart is pure Dart on purpose, so it reached for
// formatMoneyText instead and printed a different number from Home for the
// same instant. Home said the daily number was 412.50 and the tile said 413,
// rounded UP, telling somebody they could spend more than the app did.
//
// So it moved here, where both can import it, and overview.dart re-exports it
// so the thirty-odd screens that already import it from there keep working.
// There are now two formatters in the codebase and the difference is a real
// one, not an accident:
//
//   formatMoney      centavos, what every SCREEN shows a person.
//   formatMoneyText  whole pesos, byte-locked to the RN app's own formatMoney
//                    because it composes shared text (statements, reminders,
//                    logged-payment messages) that the golden vectors compare
//                    character for character.
//
// Anything a person reads as a figure on a screen or a tile takes this one.

import 'currencies.dart' show baseCurrencySymbol;

/// The month names every short date in the app uses. Public because the home
/// screen tile builds its own "as of" stamp from a DateTime rather than an ISO
/// string, and a fourth copy of this list is exactly what the drift being
/// fixed here was made of.
const List<String> monthAbbrevs = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// An ISO date as a short human day, "Jul 27". Junk comes back unchanged.
///
/// Here for the same reason formatMoney is: it lived in overview.dart, which
/// imports Flutter, so the home screen tile could not reach it and carried a
/// private copy plus a third list of month names. A test claimed to compare
/// the two "across a set of dates including junk" and in fact compared them on
/// exactly one date, because its loop asserted `anyOf(isNotEmpty, equals(iso))`
/// which every possible string satisfies. They did differ: "2026-7-4" read as
/// "2026-7-4" on Home and "Jul 4" on the tile, unreachable only because
/// paydays come from a formatter that pads.
///
/// One function means the comparison cannot drift, which is better than a test
/// that watches two functions that can.
String prettyDay(String iso) {
  if (iso.length < 10) return iso;
  final m = int.tryParse(iso.substring(5, 7));
  final day = int.tryParse(iso.substring(8, 10));
  if (m == null || day == null || m < 1 || m > 12) return iso;
  return '${monthAbbrevs[m - 1]} $day';
}

/// Sign, currency symbol, comma-grouped pesos, and centavos when there are any.
String formatMoney(num value) {
  // A backup can smuggle near-max doubles whose SUMS overflow to Infinity.
  // round() throws on non-finite, which would take down the whole screen,
  // so render the raw word instead (the RN app shows the same garbage but
  // stays alive, and staying alive is the contract here).
  if (!value.isFinite) return '$baseCurrencySymbol$value';
  final negative = value < 0;
  // A FINITE value near max double still overflows when scaled by 100 for
  // centavo rounding, and round() throws on the resulting Infinity. Same
  // contract: render the raw number, stay alive.
  final scaled = value.abs() * 100;
  if (!scaled.isFinite) return '$baseCurrencySymbol$value';
  final rounded = scaled.round() / 100;
  // Same int64 saturation guard as formatMoneyText: floor() on a double past
  // 2^53 clamps instead of overflowing, so a restored backup carrying 1e30
  // rendered a precise and completely wrong peso figure rather than obvious
  // garbage.
  if (rounded >= 9007199254740992.0) return '$baseCurrencySymbol$value';
  var whole = rounded.floor();
  final cents = ((rounded - whole) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final centsPart = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${negative ? '-' : ''}$baseCurrencySymbol$buf$centsPart';
}
