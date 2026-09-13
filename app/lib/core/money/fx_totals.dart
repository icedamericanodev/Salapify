// Converting a foreign balance into the base currency, and never doing it
// silently.
//
// Delivery E of docs/features/unified-financial-accounts.md, separately gated
// from the rest because it is the one that can produce a WRONG NUMBER rather
// than a missing one.
//
// The rule from that document, in full, because every branch below is one line
// of it:
//
//   a rate exists and is fresh: convert, and show the rate's age
//   a rate is stale:            convert, and label the total as using an old rate
//   no rate at all:             exclude, name the excluded accounts, offer a manual rate
//   a manual rate:              use it, and label it as manual
//
//   There is no state in which a converted total is shown without the reader
//   being able to see what it was converted with.
//
// TWO THINGS THIS DELIBERATELY DOES NOT DO.
//
// It is not a global. `baseCurrencySymbol` is a mutable module variable set
// during a build, and that is fine for a currency SIGN, where being wrong for
// one frame is a cosmetic bug. A rate is arithmetic. A total that depends on
// hidden state set somewhere else is how a money app gets "it was right
// yesterday", so the table is passed in, explicitly, by whoever wants a
// converted answer. netWorthParts takes it as an optional argument and
// defaults to not converting at all, which is exactly what it did before this
// file existed, and is why every golden vector still passes untouched.
//
// It does not touch safeToSpend, and that is a decision rather than an
// oversight. Net worth is a VALUATION: what everything you own is worth today,
// converted, is a real and useful answer. Safe-to-spend is a SPENDING figure,
// and you cannot buy lunch with a dollar savings account without converting it
// first. Money in another currency is genuinely not spendable pesos today, so
// it stays out of that number permanently, rate or no rate.

import 'fxrates.dart' show crossRate, isFresh;

/// Where a rate came from. The order is the precedence, worst first.
enum RateSource {
  /// No usable rate. The row is excluded and named.
  none,

  /// A cached live rate older than the freshness window.
  stale,

  /// A cached live rate inside the freshness window.
  live,

  /// A rate the person typed themselves.
  manual,
}

/// Everything needed to convert, and to say what was used.
class FxTable {
  /// The base currency every converted figure lands in.
  final String base;

  /// units-per-base, the shape the provider returns and fxrates.dart parses.
  final Map<String, dynamic> rates;

  /// When [rates] was fetched, milliseconds since epoch. Null means never.
  final int? fetchedAt;

  /// Base currency per ONE unit, typed by the person. Wins over a live rate.
  final Map<String, double> manual;

  /// Now, injected so every result is reproducible in a test and identical on
  /// two devices with the same data.
  final int nowMs;

  const FxTable({
    required this.base,
    this.rates = const {},
    this.fetchedAt,
    this.manual = const {},
    required this.nowMs,
  });

  /// The table that converts nothing, which is what the app did before
  /// delivery E and what every caller gets by default.
  factory FxTable.none(String base) => FxTable(base: base, nowMs: 0);
}

/// One currency's rate and where it came from.
class ResolvedRate {
  /// Base currency per ONE unit of the foreign currency. Null when [source]
  /// is [RateSource.none].
  final double? basePerUnit;
  final RateSource source;
  const ResolvedRate(this.basePerUnit, this.source);
}

/// The rate for one currency, by the precedence in this file's header.
///
/// A MANUAL rate wins over a live one, and that is deliberate. The person
/// typed it because the app had nothing, it is about their own money, and they
/// can remove it. Letting a stale cached rate silently override an explicit
/// instruction is the opposite of the rule this whole file exists to keep.
/// Every screen that uses it says "manual", so nobody is misled about what
/// produced the figure.
ResolvedRate resolveRate(FxTable t, String code) {
  final c = code.toUpperCase();
  if (c == t.base.toUpperCase()) return const ResolvedRate(1, RateSource.live);

  final m = t.manual[c];
  if (m != null && m.isFinite && m > 0) {
    return ResolvedRate(m, RateSource.manual);
  }

  // crossRate(from, to) gives units of `to` per one unit of `from`, so asking
  // for code -> base is exactly base-per-unit. Reusing the golden-locked
  // helper rather than dividing here, so there is one place in the codebase
  // that knows which way up a rate table is.
  final r = crossRate(t.rates, c, t.base.toUpperCase());
  if (r == null || !r.isFinite || r <= 0) {
    return const ResolvedRate(null, RateSource.none);
  }
  return ResolvedRate(
    r,
    isFresh(t.fetchedAt, t.nowMs) ? RateSource.live : RateSource.stale,
  );
}

/// What a conversion pass actually did, so a screen can report it.
class FxOutcome {
  /// Converted amount in the base currency.
  final double converted;

  /// The currencies that could not be converted at all, with the summed
  /// amount left out for each.
  final Map<String, double> excluded;

  /// The source of every rate that was USED. Empty when nothing converted.
  final Map<String, RateSource> used;

  const FxOutcome(this.converted, this.excluded, this.used);

  bool get anyManual => used.values.contains(RateSource.manual);
  bool get anyStale => used.values.contains(RateSource.stale);
  bool get anyExcluded => excluded.isNotEmpty;

  /// The worst thing that happened, which is what a one line label should
  /// name. Excluded beats manual beats stale beats live, because a reader
  /// needs to hear the biggest caveat first.
  RateSource get worst {
    if (anyStale) return RateSource.stale;
    if (anyManual) return RateSource.manual;
    return RateSource.live;
  }
}

/// Convert a list of (amount, currency) pairs into the base currency.
///
/// Rows already in the base currency are the caller's business and are not
/// passed here; this only ever sees foreign ones.
FxOutcome convertAll(FxTable t, List<(double, String)> rows) {
  var total = 0.0;
  final excluded = <String, double>{};
  final used = <String, RateSource>{};
  for (final (amount, code) in rows) {
    if (!amount.isFinite) continue;
    final c = code.toUpperCase();
    final r = resolveRate(t, c);
    if (r.source == RateSource.none || r.basePerUnit == null) {
      excluded[c] = (excluded[c] ?? 0) + amount;
      continue;
    }
    total += amount * r.basePerUnit!;
    // The WORST source per currency, so one manual rate among three live ones
    // is not hidden by whichever row happened to be last.
    final prev = used[c];
    if (prev == null || r.source.index < prev.index) used[c] = r.source;
  }
  return FxOutcome(total, excluded, used);
}

/// How old the cached table is, in whole days, or null when never fetched.
int? rateAgeDays(FxTable t) {
  final f = t.fetchedAt;
  if (f == null || f <= 0 || t.nowMs <= 0) return null;
  final ms = t.nowMs - f;
  if (ms < 0) return 0;
  return ms ~/ Duration.millisecondsPerDay;
}

/// The one sentence that goes under a converted total.
///
/// Null when nothing was converted and nothing was excluded, which is every
/// person who holds one currency. Otherwise it always names WHAT the figure
/// was converted with, because a converted total shown without that is the
/// exact state the design document forbids.
String? conversionNotice(FxTable t, FxOutcome o) {
  if (o.used.isEmpty && !o.anyExcluded) return null;
  final parts = <String>[];

  if (o.used.isNotEmpty) {
    final codes = (o.used.keys.toList()..sort()).join(', ');
    switch (o.worst) {
      case RateSource.manual:
        parts.add('Includes $codes converted at a rate you entered yourself.');
      case RateSource.stale:
        final days = rateAgeDays(t);
        parts.add(
          'Includes $codes converted at rates from '
          '${days == null
              ? 'an old download'
              : days <= 1
              ? 'yesterday'
              : '$days days ago'}, which may have moved since.',
        );
      case RateSource.live:
        final days = rateAgeDays(t);
        parts.add(
          'Includes $codes converted at '
          "${days == null || days == 0 ? "today's" : 'recent'} rates.",
        );
      case RateSource.none:
        break;
    }
  }

  if (o.anyExcluded) {
    final codes = (o.excluded.keys.toList()..sort()).join(', ');
    parts.add(
      'Salapify has no rate for $codes, so those are left out of the total. '
      'You can enter a rate yourself.',
    );
  }
  return parts.join(' ');
}
