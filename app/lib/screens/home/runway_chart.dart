import 'package:flutter/material.dart';
// `show DateFormat` is load-bearing. A bare intl import also brings in intl's
// OWN TextDirection, which shadows Flutter's and takes `TextDirection.ltr`
// away from every TextPainter in this file.
import 'package:intl/intl.dart' show DateFormat;

import '../../core/money/daily_projection.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The shape of the next 45 days, drawn from figures the app already had.
///
/// WHY THIS EXISTS. `computeDailyProjection` returns a complete day by day
/// series of `balanceAfter`, computed on every Home build, and the runway card
/// read two days out of it and threw the rest away. The card's sentence can
/// say "tightest day: Friday 26 Sep, 4,180 left" and cannot say how close to
/// zero that is, how long the dip lasts, or whether the money comes back.
/// Those are shape questions, and a shape answers them in one glance where a
/// list of forty five figures answers them for nobody on a phone.
///
/// WHAT THE READER DECIDES DIFFERENTLY: "move 2,000 out of GCash before
/// Friday" instead of "I think I am fine until payday".
///
/// WHAT THIS IS NOT. It adds no figure the card did not already have, and it
/// replaces no word of the card's text. Every sentence stays readable with the
/// chart ignored completely, which is both the accessibility floor and the
/// enhance-never-regress rule. If you ever find yourself moving a number OUT
/// of the text and INTO the chart, stop: a shape cannot be read to the
/// centavo, and this is a financial report.
///
/// HAND PAINTED, NOT A CHART PACKAGE, and the reason is control rather than
/// size. A package brings a second theming vocabulary (its own grid, axis and
/// series styling) that `palette_contrast_test.dart` cannot see into, so the
/// first hardcoded grey it chooses ships looking right in one mood and wrong
/// in the other. This paints with `Palette` slots only and nothing else.
class RunwayChart extends StatelessWidget {
  const RunwayChart({
    super.key,
    required this.palette,
    required this.projection,
    required this.semanticsLabel,
  });

  final Palette palette;
  final DailyProjection projection;

  /// What a screen reader hears instead of a blank painting. The card already
  /// writes the sentence; this repeats it rather than inventing a second one,
  /// because two descriptions of one figure is how they drift apart.
  final String semanticsLabel;

  /// Tall enough for the dip to have a shape, short enough that it never
  /// pushes the notices under the fold on a small phone.
  static const double _height = 88;

  @override
  Widget build(BuildContext context) {
    final List<ProjectedDay> days = projection.days;

    // Two points are the minimum that can make a line. One day, or none, is
    // a real state (a projection built at the end of its own horizon) and it
    // renders nothing rather than a dot pretending to be a trend.
    if (days.length < 2) return const SizedBox.shrink();

    final ProjectedDay? marked = runwayMarkedDay(projection);

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: _height,
        width: double.infinity,
        child: CustomPaint(
          painter: _RunwayPainter(
            palette: palette,
            days: days,
            markedIndex: marked == null ? null : days.indexOf(marked),
          ),
        ),
      ),
    );
  }
}

class _RunwayPainter extends CustomPainter {
  _RunwayPainter({
    required this.palette,
    required this.days,
    required this.markedIndex,
  });

  final Palette palette;
  final List<ProjectedDay> days;
  final int? markedIndex;

  /// Room under the line for the two date labels.
  static const double _labelBand = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final double plotHeight = size.height - _labelBand;
    if (plotHeight <= 0 || size.width <= 0) return;

    final List<double> values = days
        .map((ProjectedDay d) => d.balanceAfter.pesos)
        .toList();

    // ZERO IS ALWAYS IN THE RANGE, and that is the single most important
    // decision in this file.
    //
    // Scaling to min..max would make a line that never leaves 40,000 fill the
    // whole box with dramatic peaks, and a line that dips to 200 look exactly
    // the same. The question this chart answers is "how close to zero am I",
    // so zero has to be on it. The cost is honest: somebody with a large,
    // steady balance sees a flat line near the top, which is the truth.
    double lo = 0;
    double hi = 0;
    for (final double v in values) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }

    // A FLAT LINE AT EXACTLY ZERO is the degenerate case that divides by zero
    // in any naive normaliser, and it is reachable: an empty wallet with
    // nothing dated. Give it a span so the arithmetic stays finite, and the
    // line then draws along the zero rule, which is what it means.
    final double span = (hi - lo) == 0 ? 1 : (hi - lo);

    double xOf(int i) => size.width * (i / (days.length - 1));
    double yOf(double v) => plotHeight * (1 - ((v - lo) / span));

    final double zeroY = yOf(0);

    _paintZeroRule(canvas, size, zeroY);
    _paintFill(canvas, size, values, xOf, yOf, zeroY);
    _paintLine(canvas, values, xOf, yOf);

    // The marker goes down FIRST and reports the strip of baseline its date
    // label occupies, so the two end labels can stand out of its way. On the
    // first render "Today" and a marker on day 7 printed on top of each
    // other. The marked day is the one the card's sentence names, so it wins
    // every collision and the end label is what gives.
    final _Span? taken = _paintMarker(
      canvas,
      size,
      values,
      xOf,
      yOf,
      plotHeight,
    );
    _paintDateLabels(canvas, size, plotHeight, taken);
  }

  /// The baseline, dashed so it reads as a reference and not as data.
  void _paintZeroRule(Canvas canvas, Size size, double zeroY) {
    final Paint rule = Paint()
      ..color = palette.borderStrong
      ..strokeWidth = 1;

    const double dash = 3;
    const double gap = 3;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, zeroY),
        Offset((x + dash).clamp(0, size.width), zeroY),
        rule,
      );
    }
  }

  /// The area between the line and zero, which is what gives the dip its
  /// weight. Soft on purpose: the LINE is the data, this is its shadow.
  ///
  /// TWO TONES, SPLIT AT THE ZERO RULE, and the first version got this wrong
  /// in a way the first render made obvious. One `accentSoft` polygon filled
  /// the whole band, so the stretch where the balance was BELOW zero was
  /// shaded in the same friendly colour as the stretch where it was healthy.
  /// The 2px line changed colour and a filled region twenty times its area
  /// did not, which is the wrong thing shouting.
  ///
  /// Done by clipping one polygon twice rather than building two, because the
  /// polygon's edge IS the balance line and splitting it by hand would mean
  /// computing the crossing points, which is arithmetic that can disagree
  /// with the line drawn beside it.
  void _paintFill(
    Canvas canvas,
    Size size,
    List<double> values,
    double Function(int) xOf,
    double Function(double) yOf,
    double zeroY,
  ) {
    final Path path = Path()..moveTo(xOf(0), zeroY);
    for (int i = 0; i < values.length; i++) {
      path.lineTo(xOf(i), yOf(values[i]));
    }
    path
      ..lineTo(xOf(values.length - 1), zeroY)
      ..close();

    void fill(Rect band, Color color) {
      if (band.height <= 0) return;
      canvas.save();
      canvas.clipRect(band);
      canvas.drawPath(path, Paint()..color = color);
      canvas.restore();
    }

    final double plotHeight = size.height - _labelBand;
    fill(Rect.fromLTRB(0, 0, size.width, zeroY), palette.accentSoft);
    fill(Rect.fromLTRB(0, zeroY, size.width, plotHeight), palette.negativeSoft);
  }

  /// The balance itself, with any stretch below zero restated in the negative
  /// ink.
  ///
  /// COLOUR IS NOT THE ONLY CARRIER of that. Somebody who cannot tell the two
  /// inks apart still gets the dashed zero rule the line visibly crosses, the
  /// marker dot and its dated label, and the card's own sentence above, which
  /// says "You run short on Friday 26 Sep" in words. A red segment is the
  /// fourth way of saying it, never the only one.
  void _paintLine(
    Canvas canvas,
    List<double> values,
    double Function(int) xOf,
    double Function(double) yOf,
  ) {
    final Paint above = Paint()
      ..color = palette.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint below = Paint()
      ..color = palette.negative
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Segment by segment rather than one path, because a single stroke cannot
    // change colour where it crosses zero. Forty four segments is nothing to
    // draw and the alternative is clipping two paths, which is more code for
    // the same picture.
    for (int i = 0; i < values.length - 1; i++) {
      final bool shortHere = values[i] < 0 || values[i + 1] < 0;
      canvas.drawLine(
        Offset(xOf(i), yOf(values[i])),
        Offset(xOf(i + 1), yOf(values[i + 1])),
        shortHere ? below : above,
      );
    }
  }

  /// The one day the card's sentence names, tied to the line so the words and
  /// the picture point at the same place.
  _Span? _paintMarker(
    Canvas canvas,
    Size size,
    List<double> values,
    double Function(int) xOf,
    double Function(double) yOf,
    double plotHeight,
  ) {
    final int? i = markedIndex;
    if (i == null || i < 0 || i >= values.length) return null;

    final double x = xOf(i);
    final double y = yOf(values[i]);
    final bool short = values[i] < 0;
    final Color ink = short ? palette.negative : palette.accent;

    // A hairline down to the baseline, so the eye can carry the point to its
    // date label without guessing.
    canvas.drawLine(
      Offset(x, y),
      Offset(x, plotHeight),
      Paint()
        ..color = palette.borderStrong
        ..strokeWidth = 1,
    );

    // Ringed in the card's own surface colour so the dot stays legible where
    // it sits on top of the fill.
    canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = palette.surface);
    canvas.drawCircle(Offset(x, y), 3, Paint()..color = ink);

    return _text(
      canvas,
      DateFormat('d MMM').format(days[i].date),
      ink,
      x,
      plotHeight + 2,
      size.width,
      center: true,
    );
  }

  /// Only the two ends are labelled. Forty five dates across 264dp is a grey
  /// smear, and the day in the middle that matters already has its own label
  /// under the marker.
  void _paintDateLabels(
    Canvas canvas,
    Size size,
    double plotHeight,
    _Span? taken,
  ) {
    // Four pixels of air, so two labels that merely touch still read as two.
    const double air = 4;

    final _Span today = _measure('Today', 0, size.width);
    if (taken == null || !taken.overlaps(today, air)) {
      _text(canvas, 'Today', palette.textMuted, 0, plotHeight + 2, size.width);
    }

    final String last = DateFormat('d MMM').format(days.last.date);
    final _Span end = _measure(last, size.width, size.width, alignRight: true);
    if (taken == null || !taken.overlaps(end, air)) {
      _text(
        canvas,
        last,
        palette.textMuted,
        size.width,
        plotHeight + 2,
        size.width,
        alignRight: true,
      );
    }
  }

  TextPainter _painterFor(String value, Color color) => TextPainter(
    text: TextSpan(
      text: value,
      // The shipped face, read from the type scale rather than named here,
      // so a label in a painting cannot drift from a label in a widget.
      style: AppType.caption(palette).copyWith(fontSize: 10, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// Where a label WOULD land, without drawing it.
  _Span _measure(
    String value,
    double x,
    double maxWidth, {
    bool center = false,
    bool alignRight = false,
  }) {
    final TextPainter tp = _painterFor(value, palette.textMuted);
    final double left = _leftFor(tp, x, maxWidth, center, alignRight);
    return _Span(left, left + tp.width);
  }

  double _leftFor(
    TextPainter tp,
    double x,
    double maxWidth,
    bool center,
    bool alignRight,
  ) {
    double left = x;
    if (center) left = x - tp.width / 2;
    if (alignRight) left = x - tp.width;
    // Keep a label inside the card even when its anchor sits at the very edge.
    return left.clamp(0, (maxWidth - tp.width).clamp(0, maxWidth));
  }

  _Span _text(
    Canvas canvas,
    String value,
    Color color,
    double x,
    double y,
    double maxWidth, {
    bool center = false,
    bool alignRight = false,
  }) {
    final TextPainter tp = _painterFor(value, color);
    final double left = _leftFor(tp, x, maxWidth, center, alignRight);
    tp.paint(canvas, Offset(left, y));
    return _Span(left, left + tp.width);
  }

  @override
  bool shouldRepaint(_RunwayPainter old) =>
      old.palette != palette ||
      old.markedIndex != markedIndex ||
      old.days != days;
}

/// THE DAY WORTH MARKING, defined once and read by both the painting and the
/// sentence that describes it.
///
/// ONE FUNCTION, NOT TWO COPIES, and the reason is a test that nearly shipped
/// pretending to check this. The chart and `runwayChartSemantics` each had
/// their own `firstShortfall ?? tightestDay`, and the test asserting they
/// agreed only ever read the sentence: reversing the chart's copy left it
/// green while the picture marked a different day from the words beside it.
/// Agreement is now structural, so there is nothing left to assert.
///
/// THE ORDER IS THE DESIGN. The first shortfall is the day somebody has to act
/// BEFORE. The tightest day may come after a payment has already bounced, so
/// marking it would point at the bottom of a hole rather than at the edge.
/// `runway_row.dart`'s state machine chooses in the same order, which is what
/// keeps the card's sentence and this marker on the same day.
ProjectedDay? runwayMarkedDay(DailyProjection projection) =>
    projection.firstShortfall ?? projection.tightestDay;

/// A horizontal strip of the baseline that a label occupies.
class _Span {
  const _Span(this.left, this.right);

  final double left;
  final double right;

  bool overlaps(_Span other, double air) =>
      left < other.right + air && other.left < right + air;
}

/// The sentence a screen reader hears in place of the painting.
///
/// Built from the same two accessors the chart draws from, so it cannot
/// describe a different day from the one marked.
String runwayChartSemantics(DailyProjection projection) {
  final List<ProjectedDay> days = projection.days;
  if (days.length < 2) return 'No projection to show yet.';

  final ProjectedDay? marked = runwayMarkedDay(projection);
  final String range =
      'Your balance over the next ${days.length - 1} days, '
      'starting at ${formatPeso(projection.openingBalance.pesos)}';

  if (marked == null) return '$range.';

  final String when = formatDayAndDate(marked.date, now: days.first.date);
  final String amount = formatPeso(marked.balanceAfter.pesos.abs());
  return marked.balanceAfter.isNegative
      ? '$range. It goes below zero on $when, short by $amount.'
      : '$range. Its lowest point is $when, with $amount left.';
}
