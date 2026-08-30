// How an account's OWN balance is written, f4.70. Display only: it changes no
// total and no stored value. A base-currency account formats as pesos exactly
// as before; a foreign account shows its OWN symbol and decimals (a dollar
// account reads "$1,000.00", never "P1,000"), which is what the card widgets'
// amountText override was built for and what stops a foreign balance clashing
// with the net worth total (which already leaves an unpriced currency out, see
// base_currency_scope).
//
// This is presentation over the SAME per-account currency rule the totals use,
// so it can never disagree with them: an account is foreign here iff
// inBaseCurrency says it is left out of the base total there.

import 'base_currency_scope.dart' show inBaseCurrency;
import 'currencies.dart' show formatConverted;
import 'format.dart' show formatMoney;

/// An account row's own currency code when it is foreign, or null when the
/// account is in the base currency (no code, or a code equal to base).
String? accountForeignCode(dynamic row, String base) {
  if (row is! Map || inBaseCurrency(row, base)) return null;
  final code = row['currencyCode'];
  return (code is String && code.isNotEmpty) ? code.toUpperCase() : null;
}

/// The display string for an account's own balance [value]: the base peso
/// formatter for a base-currency account, or the account's own symbol and
/// decimals for a foreign one.
String formatAccountBalance(num value, dynamic row, String base) {
  final code = accountForeignCode(row, base);
  return code == null ? formatMoney(value) : formatConverted(value, code);
}

/// The `amountText` override the card widgets accept: null for a base-currency
/// account (the card formats the peso itself), else the foreign string so the
/// card face shows the account's own symbol.
String? accountAmountText(num value, dynamic row, String base) {
  final code = accountForeignCode(row, base);
  return code == null ? null : formatConverted(value, code);
}
