/// Splitting a bill between people, ported from the prototype.
///
/// Source: `calculateSplitShares` in `src/utils/collaborationEngine.ts`.
/// Ported on founder direction, 2026-10-01 ("do the Split Bill").
///
/// ## The numbers came from RUNNING it, not reading it
///
/// `app/tool/gen_split_vectors.ts` imports the real function and executes it
/// over twenty fixtures, and what it printed is what
/// `test/core/money/split_bill_test.dart` asserts. Nothing here was worked
/// out by hand, because a figure worked out by hand can agree with my own
/// misreading of the source.
///
/// ## The prototype does five odd things, and all five are REPRODUCED
///
/// The repository's rule is that where the prototype does something odd the
/// engine reproduces it and a vector locks it, and the defence lives in the
/// UI rather than in a quietly corrected number. These are the five, each
/// locked by a named test:
///
/// 1. An equal split of 100 between seven people gives the first person
///    14.319999999999999, not 14.32. That is `equalShare + remainder` in
///    binary floating point and it is what the prototype returns.
/// 2. Percentages that do not add to 100 still produce shares adding to the
///    bill, because the LAST participant absorbs whatever is left. Two people
///    at 80% each give 800 and 200, and the second still displays 80%.
/// 3. Fixed amounts are not reconciled at all. Two people at 900 on a 1,000
///    bill produce 1,800 of shares.
/// 4. A fixed or shares split with no inputs can land a centavo short: three
///    ways on 1,000 sums to 999.99.
/// 5. A zero or negative bill returns NO shares, rather than zeroes.
///
/// Numbers 2, 3 and 4 mean the shares cannot be assumed to equal the bill.
/// [sharesReconcile] exists so the screen can say so instead of letting
/// somebody read a column that does not add up.
library;

import 'dart:math' as math;

/// How a bill is divided.
enum SplitMethod {
  /// Straight down the middle, with the odd centavo to the first person.
  equal,

  /// Each person names a percentage. The last one absorbs the rounding.
  percentage,

  /// Each person names an amount. Nothing makes these add up.
  fixed,

  /// A ratio, for instance two shares against one.
  shares,
}

/// One person's part of the bill.
class SplitShare {
  const SplitShare({
    required this.name,
    required this.amount,
    required this.percentage,
  });

  final String name;

  /// Pesos, to the centavo, exactly as the prototype computes it.
  final double amount;

  /// What the prototype SHOWS as this person's percentage, which is not
  /// always what [amount] is of the bill. See odd thing 2 in the library
  /// comment: the last participant's amount is adjusted and their percentage
  /// is not.
  final double percentage;
}

/// JavaScript's Math.round, which Dart's round() is not.
///
/// Dart rounds a half away from zero and JS rounds it toward positive
/// infinity, so they differ on exactly one case: a negative half. A bill is
/// guarded to be positive before any of this runs, but a percentage is not,
/// and nothing stops somebody typing a negative one.
double _jsRound(double x) {
  if (!x.isFinite) return x;
  return (x + 0.5).floorToDouble();
}

/// `Math.round(v * 100) / 100`, the prototype's way of reaching centavos.
double _toCentavos(double v) => _jsRound(v * 100) / 100;

/// JavaScript's `??`: only null falls through. A zero does NOT.
double? _nullish(Map<String, double> inputs, String key) => inputs[key];

/// JavaScript's `||`: null, zero and NaN all fall through to the fallback.
///
/// This is not interchangeable with `??` and the difference is load bearing:
/// in the shares branch the prototype writes `customInputs?.[id] || 1`, so
/// somebody who types 0 shares gets 1 share, not none. In the fixed branch it
/// writes `??`, so somebody who types 0 gets 0.
double _falsy(Map<String, double> inputs, String key, double fallback) {
  final double? v = inputs[key];
  if (v == null || v == 0 || v.isNaN) return fallback;
  return v;
}

/// Divide [total] between [names].
///
/// Returns an EMPTY list for an empty name list or a bill of zero or less,
/// which is the prototype's behaviour and is deliberately not softened into
/// a list of zeroes: nothing to split is different from everybody owing
/// nothing, and the screen says so differently.
List<SplitShare> calculateSplitShares({
  required double total,
  required SplitMethod method,
  required List<String> names,
  Map<String, double> inputs = const <String, double>{},
}) {
  if (names.isEmpty || total <= 0 || !total.isFinite) {
    return const <SplitShare>[];
  }

  final int count = names.length;

  switch (method) {
    case SplitMethod.equal:
      // FLOOR, not round, so the division never overshoots. Whatever is left
      // goes to the first person, which is where 14.319999999999999 comes
      // from: it is 14.28 + 0.04 in binary floating point, and the prototype
      // returns exactly that.
      final double equalShare = (total / count * 100).floorToDouble() / 100;
      final double remainder = _toCentavos(total - equalShare * count);
      final double pct = _jsRound(100 / count * 10) / 10;
      return <SplitShare>[
        for (int i = 0; i < count; i++)
          SplitShare(
            name: names[i],
            amount: i == 0 ? equalShare + remainder : equalShare,
            percentage: pct,
          ),
      ];

    case SplitMethod.percentage:
      // The LAST participant is given whatever is left rather than their own
      // percentage of the bill. That is what makes the column add up when the
      // percentages do not, and it is also why their stated percentage can
      // disagree with their amount.
      double allocated = 0;
      return <SplitShare>[
        for (int i = 0; i < count; i++)
          () {
            final double pct = _nullish(inputs, names[i]) ?? (100 / count);
            final bool isLast = i == count - 1;
            double share;
            if (isLast) {
              share = math.max(0, _toCentavos(total - allocated));
            } else {
              share = _toCentavos(total * (pct / 100));
              allocated += share;
            }
            return SplitShare(name: names[i], amount: share, percentage: pct);
          }(),
      ];

    case SplitMethod.fixed:
      // Nothing reconciles these against the bill. Deliberately preserved.
      return <SplitShare>[
        for (final String name in names)
          () {
            final double amount =
                _nullish(inputs, name) ?? _toCentavos(total / count);
            return SplitShare(
              name: name,
              amount: amount,
              percentage: _jsRound(amount / total * 1000) / 10,
            );
          }(),
      ];

    case SplitMethod.shares:
      // `|| 1` rather than `?? 1`, so a typed zero becomes one share. See
      // [_falsy]: this is the prototype's own operator and swapping it would
      // give somebody who asked for no shares a share of the bill anyway, or
      // the reverse, depending which way it was swapped.
      double totalShares = 0;
      for (final String name in names) {
        totalShares += _falsy(inputs, name, 1);
      }
      return <SplitShare>[
        for (final String name in names)
          () {
            final double sharesCount = _falsy(inputs, name, 1);
            final double pct = sharesCount / totalShares * 100;
            return SplitShare(
              name: name,
              amount: _toCentavos(total * (sharesCount / totalShares)),
              percentage: _jsRound(pct * 10) / 10,
            );
          }(),
      ];
  }
}

/// Do the shares actually add up to the bill?
///
/// NET NEW, with no counterpart in the prototype, and it exists because the
/// prototype has no answer to this question and needs one. Fixed amounts are
/// never reconciled, and a rounding path can land a centavo short, so a
/// person can be looking at a column of figures that does not come to what
/// they are paying. The screen uses this to say so.
///
/// The slack SCALES with the number of people, and that is not fussiness.
///
/// Every share is rounded to the centavo, so each one can sit up to half a
/// centavo away from its true value and the sum can drift by roughly half a
/// centavo per person. A flat one centavo of tolerance looked right and was
/// wrong: three ways on 1,000 is 999.99, which it allowed, but seven ways on
/// 1,000 under the fixed default comes to 1,000.03, which it would have
/// called a mismatch and warned about. Warning somebody about three centavos
/// of rounding is how a warning gets ignored, and then it is not there for
/// the 700 peso one.
///
/// What it must still catch is a real shortfall: fixed amounts of 100 and 200
/// against a 1,000 bill are 700 out and that is the case this exists for.
bool sharesReconcile(double total, List<SplitShare> shares) {
  if (shares.isEmpty) return false;
  final double slack = shares.length * 0.01 + 0.005;
  return (sharesTotal(shares) - total).abs() <= slack;
}

/// What the shares actually come to.
double sharesTotal(List<SplitShare> shares) =>
    shares.fold<double>(0, (double s, SplitShare p) => s + p.amount);
