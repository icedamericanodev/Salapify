import 'js_round.dart';

/// Money, held as whole CENTAVOS in an int.
///
/// ## Why this type exists
///
/// Salapify holds every peso figure in a `double` today, because the prototype
/// it was ported from is JavaScript and JavaScript has one number type. A
/// double cannot represent 0.1, so it stores the nearest binary fraction and
/// the error compounds:
///
///     0.1 + 0.2            is 0.30000000000000004
///     0.1 + 0.2 == 0.3     is FALSE
///     (1.005 * 100).round() is 100, not 101, because 1.005 is really
///                           1.00499999999999989...
///
/// None of that matters until it does. It matters when a reconciliation says
/// a balanced account is off by a hundredth of a centavo, when a budget shows
/// as breached by 0.0000000001, or when splitting a bill four ways leaves a
/// centavo unaccounted for and the person who paid is quietly short.
///
/// An int cannot drift. Two centavos plus two centavos is four centavos, on
/// every machine, forever, and `==` means what it says.
///
/// ## What this type does NOT change
///
/// The file on disk. `json_codec.dart` still reads and writes pesos as an
/// ordinary number, exactly as it does today, and converts at that one
/// boundary. A backup written by this version opens in the old one and the
/// other way round. That is deliberate: a stored-format change is a migration,
/// a migration can lose somebody's records, and nothing here is worth that
/// risk when the boundary conversion costs one line per field.
///
/// The arithmetic results, in the ordinary case. Every rounding rule here is
/// the prototype's own `Math.round`, through [jsRound], so a figure that was
/// right before is right after. Where a number DOES move, it moves because the
/// double was drifting, and the golden vector is re-cut only with that
/// difference demonstrated rather than assumed.
///
/// ## Reading one in a debugger
///
/// `Money(420000)` is 4,200.00 pesos. The constructor takes centavos because
/// that is what it stores and a constructor that silently took pesos would be
/// the single easiest way to be out by a hundred. Use [Money.pesos] for whole
/// pesos, which is const, or [Money.fromDouble] at a boundary.
class Money implements Comparable<Money> {
  /// Centavos. 420000 is 4,200.00 pesos.
  const Money(this.centavos);

  /// Whole pesos, with no centavos. Const, so it reads well in a fixture:
  /// `balance: const Money.pesos(23400)`.
  const Money.pesos(int wholePesos) : centavos = wholePesos * 100;

  /// Pesos and centavos separately, so `Money.of(1200, 50)` is 1,200.50 and
  /// nobody has to multiply in their head.
  ///
  /// A NEGATIVE amount puts the sign on the pesos: `Money.of(-1200, 50)` is
  /// minus 1,200.50, not minus 1,200 plus 50. Writing it the other way is how
  /// a refund comes out a peso short.
  const Money.of(int wholePesos, int centavosPart)
    : centavos = wholePesos < 0
          ? wholePesos * 100 - centavosPart
          : wholePesos * 100 + centavosPart;

  static const Money zero = Money(0);

  final int centavos;

  /// From a peso double, which is what the stored file and the ported engines
  /// still hand over.
  ///
  /// Rounds with the prototype's rule, not Dart's. They differ only on a
  /// negative half centavo, and money code outlives the assumption that there
  /// are none.
  ///
  /// THROWS on a value that is not finite. A backup can smuggle an Infinity or
  /// a NaN, and `round()` throws on both anyway; it throws here instead, with a
  /// sentence saying what was wrong, so the caller can reject one record rather
  /// than take down a screen. Use [tryFromDouble] where a bad value should be
  /// survivable.
  factory Money.fromDouble(double pesos) {
    final Money? m = tryFromDouble(pesos);
    if (m == null) {
      throw FormatException('Not a usable peso amount: $pesos');
    }
    return m;
  }

  /// [Money.fromDouble], but null rather than a throw for a value that is not
  /// finite or is too large to be a peso figure anybody holds.
  static Money? tryFromDouble(double pesos) {
    if (!pesos.isFinite) return null;
    final double c = pesos * 100;
    // Beyond this a double can no longer represent every integer, so the
    // centavo count would be a guess. It is about 90 quadrillion centavos; no
    // real balance reaches it, and a value that does came from corruption.
    if (c.abs() > 9007199254740992.0) return null;
    return Money(jsRound(c));
  }

  /// Pesos, for formatting and for the one boundary that writes the file.
  double get pesos => centavos / 100;

  /// The figure for an INPUT BOX: no commas, no currency, and centavos only
  /// when there are centavos. "3500.55" and "3500", never "3500.00".
  ///
  /// This exists because its absence lost somebody's centavos. The budget
  /// sheet pre-filled its box with `limit.pesos.toStringAsFixed(0)`, so a
  /// stored 3,500.55 came back as "3501", and saving that box without
  /// touching it would have written 3501 over the real figure. The money was
  /// right everywhere else on the screen; only the box somebody types into
  /// rounded it, which is the worst place for it.
  ///
  /// Three other sheets each hand-rolled the same rule
  /// (`v == v.roundToDouble() ? ... : ...`) and got it right. One did not,
  /// and a rule copied four times is a rule that will be copied wrong a
  /// fifth. It lives here now.
  ///
  /// NOT for display. A figure a person reads goes through `formatPeso`,
  /// which groups thousands and adds the sign.
  String get plain =>
      isWholePesos ? pesos.toStringAsFixed(0) : pesos.toStringAsFixed(2);

  /// True when there are no centavos, so a screen can drop the ".00" without
  /// dropping a real figure.
  bool get isWholePesos => centavos % 100 == 0;

  bool get isZero => centavos == 0;
  bool get isNegative => centavos < 0;
  bool get isPositive => centavos > 0;

  Money get abs => centavos < 0 ? Money(-centavos) : this;

  Money operator +(Money other) => Money(centavos + other.centavos);
  Money operator -(Money other) => Money(centavos - other.centavos);
  Money operator -() => Money(-centavos);

  /// A whole multiple: three instalments of the same amount.
  Money operator *(int times) => Money(centavos * times);

  /// A RATE, such as an interest rate or a percentage share.
  ///
  /// Rounds to the centavo with the prototype's rule, which is exactly what
  /// `Math.round(pesos * rate * 100) / 100` did before.
  Money times(double rate) => Money(jsRound(centavos * rate));

  /// This as a share of [other], as a plain ratio. Returns null rather than an
  /// infinity when [other] is zero, because "spent 400 of a 0 budget" has no
  /// percentage and a screen showing one is showing a made-up figure.
  double? ratioTo(Money other) =>
      other.centavos == 0 ? null : centavos / other.centavos;

  /// Split into [parts] shares that SUM BACK EXACTLY to this amount.
  ///
  /// The remainder is spread one centavo at a time over the earliest shares,
  /// so 100.00 over three is 33.34, 33.33, 33.33 rather than three times 33.33
  /// with a centavo lost. Losing it is the defect this whole type exists to
  /// prevent, and a bill split is where somebody actually notices.
  ///
  /// A negative amount spreads the remainder the same way, toward the earliest
  /// shares, so the sum still comes back exact.
  List<Money> split(int parts) {
    if (parts <= 0) {
      throw ArgumentError.value(parts, 'parts', 'must be at least 1');
    }
    // Truncates toward zero, so a negative total splits the same way.
    final int base = centavos ~/ parts;
    final int remainder = centavos - base * parts;
    final int step = remainder.isNegative ? -1 : 1;
    final int extras = remainder.abs();
    return <Money>[
      for (int i = 0; i < parts; i++) Money(base + (i < extras ? step : 0)),
    ];
  }

  @override
  int compareTo(Money other) => centavos.compareTo(other.centavos);

  bool operator <(Money other) => centavos < other.centavos;
  bool operator <=(Money other) => centavos <= other.centavos;
  bool operator >(Money other) => centavos > other.centavos;
  bool operator >=(Money other) => centavos >= other.centavos;

  @override
  bool operator ==(Object other) =>
      other is Money && other.centavos == centavos;

  @override
  int get hashCode => centavos.hashCode;

  /// Plain, for a debugger and a failed test message. NOT for a screen:
  /// `format.dart` owns what the user reads, including the peso sign and the
  /// grouping.
  @override
  String toString() {
    final int c = centavos.abs();
    final String sign = centavos < 0 ? '-' : '';
    return '$sign${c ~/ 100}.${(c % 100).toString().padLeft(2, '0')}';
  }
}

/// The total of a list of amounts.
///
/// Its own function rather than a fold at every call site, because an empty
/// list has to total zero and a fold written in a hurry starts from the first
/// element and throws.
Money sumMoney(Iterable<Money> amounts) =>
    amounts.fold(Money.zero, (Money a, Money b) => a + b);

Money maxMoney(Money a, Money b) => a >= b ? a : b;
Money minMoney(Money a, Money b) => a <= b ? a : b;
