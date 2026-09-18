/// Multi-currency support, ported from src/utils/currencies.ts.
///
/// Salapify is a peso app and every account in the fixture is PHP, so this
/// whole file is a no-op on today's data. It exists because the prototype's
/// Accounts screen shows a foreign balance in its OWN currency with the peso
/// equivalent underneath, and an OFW with a Singapore payroll account is
/// exactly the person that screen was drawn for.
///
/// The rates are INDICATIVE AND FIXED, copied from the prototype. There is no
/// network call and there is not going to be one in an offline first app, so
/// a converted figure is an estimate and the UI has to say so wherever it
/// shows one. Never use a converted number as the basis of a decision the
/// user would blame on us.
library;

import 'package:intl/intl.dart';

/// The five currencies the prototype supports. Adding a sixth means adding it
/// here, in [currencySymbols], [currencyNames] and [exchangeRatesToPhp]; the
/// integrity test iterates this enum and reddens if any of the three is short.
enum CurrencyCode { php, usd, eur, jpy, sgd }

/// The wire spelling, which is what the prototype stores and what a backup
/// file will have to carry.
extension CurrencyCodeWire on CurrencyCode {
  String get wire => switch (this) {
    CurrencyCode.php => 'PHP',
    CurrencyCode.usd => 'USD',
    CurrencyCode.eur => 'EUR',
    CurrencyCode.jpy => 'JPY',
    CurrencyCode.sgd => 'SGD',
  };
}

CurrencyCode? currencyFromWire(String raw) {
  for (final CurrencyCode c in CurrencyCode.values) {
    if (c.wire == raw.toUpperCase()) return c;
  }
  return null;
}

const Map<CurrencyCode, String> currencySymbols = <CurrencyCode, String>{
  CurrencyCode.php: '₱',
  CurrencyCode.usd: r'$',
  CurrencyCode.eur: '€',
  CurrencyCode.jpy: '¥',
  CurrencyCode.sgd: r'S$',
};

const Map<CurrencyCode, String> currencyNames = <CurrencyCode, String>{
  CurrencyCode.php: 'Philippine Peso (PHP)',
  CurrencyCode.usd: 'US Dollar (USD)',
  CurrencyCode.eur: 'Euro (EUR)',
  CurrencyCode.jpy: 'Japanese Yen (JPY)',
  CurrencyCode.sgd: 'Singapore Dollar (SGD)',
};

/// The short name the picker shows, without the code in brackets.
const Map<CurrencyCode, String> currencyShortNames = <CurrencyCode, String>{
  CurrencyCode.php: 'Philippine Peso',
  CurrencyCode.usd: 'US Dollar',
  CurrencyCode.eur: 'Euro',
  CurrencyCode.jpy: 'Japanese Yen',
  CurrencyCode.sgd: 'Singapore Dollar',
};

/// One unit of the currency, in pesos. Indicative, fixed, and stale by
/// construction. See the library note above.
const Map<CurrencyCode, double> exchangeRatesToPhp = <CurrencyCode, double>{
  CurrencyCode.php: 1.0,
  CurrencyCode.usd: 58.50,
  CurrencyCode.eur: 63.80,
  CurrencyCode.jpy: 0.385,
  CurrencyCode.sgd: 44.20,
};

/// Converts an amount in [currency] to pesos at the indicative rate.
double convertToPhp(double amount, [CurrencyCode currency = CurrencyCode.php]) {
  final double rate = exchangeRatesToPhp[currency] ?? 1.0;
  return amount * rate;
}

final NumberFormat _twoDp = NumberFormat('#,##0.00');
final NumberFormat _noDp = NumberFormat('#,##0');

/// Formats an amount with its own currency's symbol.
///
/// The SIGN GOES BEFORE THE SYMBOL, so a negative dollar balance reads
/// "-$2,500.00" and not "$-2,500.00". That is the prototype's shape and it is
/// also the one people read fastest, because the minus is the first thing on
/// the line rather than buried after a glyph.
String formatCurrency(
  double amount,
  CurrencyCode currency, {
  bool includeDecimals = true,
}) {
  final String symbol = currencySymbols[currency] ?? '₱';
  final NumberFormat f = includeDecimals ? _twoDp : _noDp;
  final String body = f.format(amount.abs());
  final String sign = amount < 0 ? '-' : '';
  return '$sign$symbol$body';
}
