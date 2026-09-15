// Insights. Question 5 of the five in 01-vision.md: where is this going?
//
// 04-screens.md: "Three to five charts, each drawn in border, positive and
// accent under one grammar, each with a sentence under it that contains a
// number. No cards; a section label per chart."
//
// NO CARDS, and that is a deliberate difference from every other screen in the
// app. Everything else is rows inside cards, because everything else is a list
// of things. A chart is not a thing in a list, and wrapping each one in a card
// makes the page read as four unrelated widgets rather than one argument about
// somebody's money.
//
// EVERY CHART CARRIES A SENTENCE. A chart shows a shape and a person acts on a
// claim, so no chart ships here without a line of prose carrying a number, and
// that number comes from the same derivation that drew the bars.
//
// THREE CHARTS, NOT FOUR. The spec lists a fourth, daily spending against the
// safe-to-spend line. It is deferred deliberately rather than forgotten: no
// engine produces a per-day series, so building it means writing a new money
// derivation, and the comparison line it needs ("what should I have spent by
// today") is a pace figure the app states exactly once, on Home. Two places
// stating a pace is the defect financial_state.dart exists to prevent, so this
// waits until the engine owns that series rather than a chart inventing it.
import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../core/money/net_worth_history.dart' show NetWorthPoint;
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'insight_rows.dart';

const String insightsRoutePath = '/insights';

/// The charts, with no chrome of their own.
///
/// SEPARATE FROM THE SCREEN because it now has two homes, which is D23.
/// Insights is the second segment of the Ledger tab, because Home is now, Plan
/// is the future, Accounts is the stock, and LEDGER IS THE PAST. Insights is
/// the past, shaped, so it belongs beside the raw version of itself rather
/// than behind a sentence at the bottom of another screen.
///
/// The pushed [InsightsScreen] below stays as well, and that is two doors into
/// one room rather than a duplicate: a deep link from a notification or the
/// home screen widget needs somewhere to land that can be backed OUT of, and a
/// tab switch is not that.
///
/// Returns a LIST, not a Column. The Ledger tab's `Screen` is a lazy ListView
/// and wrapping these in a Column would build all three charts, including the
/// CustomPainter, every time somebody opens the Ledger to check one entry.
class InsightsBody {
  const InsightsBody._();

  static List<Widget> of(BuildContext context) {
    final data = context.ledger.data;
    final now = context.now;

    final slices = spendingByCategory(data, now);
    final bars = inVersusOut(data, now);
    final points = netWorthPoints(data, now);

    final nothingAtAll =
        slices.isEmpty &&
        bars.every((b) => b.income == 0 && b.expenses == 0) &&
        points.length <= 1;

    if (nothingAtAll) {
      return const [
        EmptyState(
          icon: Icons.insights_outlined,
          title: 'Not enough logged yet',
          body:
              'Log a few entries and this fills in: where the month went, '
              'how it compares with your usual month, and which way your '
              'net worth is moving.',
        ),
      ];
    }

    return [
      _Section(
        title: 'Where this month went',
        sentence: categorySentence(slices),
        child: _CategoryBars(slices: slices),
      ),
      _Section(
        title: 'In and out, last six months',
        sentence: inVersusOutSentence(bars),
        child: _MonthBars(bars: bars),
      ),
      _Section(
        title: 'Net worth',
        sentence: netWorthSentence(points),
        child: _NetWorthLine(points: points),
      ),
    ];
  }
}

/// Insights as a pushed screen, for deep links and for Home's closing
/// sentence. The Ledger tab's segment is the discoverable route; this is the
/// one a notification can land on and back out of.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.skin.bg,
      body: Screen(
        children: [
          const BackBar(),
          const SizedBox(height: 6),
          const ScreenTitle(
            title: 'Insights',
            sub: 'Where your money went, and where it is heading.',
          ),
          const SizedBox(height: 22),
          ...InsightsBody.of(context),
        ],
      ),
    );
  }
}

/// One chart: a label, the drawing, and the sentence that makes it a claim.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.sentence,
    required this.child,
  });

  final String title;
  final String sentence;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Head(title: title),
        const SizedBox(height: 14),
        child,
        const SizedBox(height: 12),
        Text(sentence, style: TypeScale.subtitle(skin.text2)),
        const SizedBox(height: 28),
      ],
    );
  }
}

/// Horizontal bars, one per category, largest first.
///
/// Bars rather than a pie, and that is a readability decision rather than a
/// taste one: a person can compare two lengths on a shared baseline and cannot
/// compare two angles. A pie also needs a legend, which puts the label away
/// from the thing it labels.
class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.slices});
  final List<CategorySlice> slices;

  /// Six, then everything else in one row.
  ///
  /// Not a scroll and not all of them. A chart with nineteen bars is a table
  /// drawn badly, and cutting the tail off silently would make the bars add up
  /// to less than the month with nothing saying so.
  static const int shown = 6;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final head = slices.take(shown).toList();
    final tail = slices.skip(shown).toList();
    final tailTotal = tail.fold(0.0, (t, s) => t + s.amount);
    final tailFraction = tail.fold(0.0, (t, s) => t + s.fraction);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in head) ...[
          _Bar(
            // The user's own emoji beside their own category, untouched. Only
            // icons Salapify authors are theme glyphs; a category icon is user
            // data and lives in their backup file.
            label: s.icon.isEmpty ? s.name : '${s.icon}  ${s.name}',
            amount: s.amount,
            fraction: s.fraction,
            fill: skin.accent,
          ),
          const SizedBox(height: 12),
        ],
        if (tail.isNotEmpty)
          _Bar(
            label: tail.length == 1
                ? '1 more category'
                : '${tail.length} more categories',
            amount: tailTotal,
            fraction: tailFraction,
            // Quieter than the named bars, because it is a bucket rather than
            // a thing. Still drawn, so the bars still add up to the month.
            fill: skin.text3,
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.fill,
  });

  final String label;
  final double amount;
  final double fraction;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeScale.caption(skin.text2),
              ),
            ),
            const SizedBox(width: 10),
            Text(formatMoney(amount), style: TypeScale.caption(skin.text)),
          ],
        ),
        const SizedBox(height: 6),
        // Taller than the 5dp ThinBar used elsewhere. A budget rail sits under
        // a row as a hint; here the bar IS the content, and at 5dp six of them
        // read as hairlines rather than as a comparison.
        ThinBar(fraction: fraction, fill: fill, height: 9),
      ],
    );
  }
}

/// Paired bars, money in against money out, one pair per month.
class _MonthBars extends StatelessWidget {
  const _MonthBars({required this.bars});
  final List<MonthBar> bars;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // ONE SCALE FOR BOTH SERIES. Scaling income and expenses separately would
    // draw a 5,000 expense the same height as a 50,000 income, which is the
    // single most effective way to make a chart lie.
    final peak = bars.fold(0.0, (m, b) {
      final hi = b.income > b.expenses ? b.income : b.expenses;
      return hi > m ? hi : m;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final b in bars)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Column(
                              value: b.income,
                              peak: peak,
                              color: skin.good,
                            ),
                            const SizedBox(width: 3),
                            _Column(
                              value: b.expenses,
                              peak: peak,
                              color: skin.accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b.label,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TypeScale.caption(skin.text3),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // The key, inline. A separate legend block is one more thing to look
        // up; two coloured words beside each other is read once and remembered.
        Row(
          children: [
            _Key(color: skin.good, label: 'In'),
            const SizedBox(width: 16),
            _Key(color: skin.accent, label: 'Out'),
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.value, required this.peak, required this.color});

  final double value;
  final double peak;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // A FLOOR OF 2, so a month with a small but real figure is visible. Zero
    // stays zero: a bar drawn for a month with no money in it would claim
    // something happened.
    final h = peak <= 0 ? 0.0 : (value / peak) * 96;
    return Expanded(
      child: Container(
        height: value <= 0 ? 0 : (h < 2 ? 2 : h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: TypeScale.caption(context.skin.text3)),
    ],
  );
}

/// Net worth over the window, as a line.
class _NetWorthLine extends StatelessWidget {
  const _NetWorthLine({required this.points});
  final List<NetWorthPoint> points;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;

    // HONEST ABOUT THIN DATA. Salapify records one snapshot a month, so a new
    // user has exactly one point. A line needs two, and drawing a flat one
    // through a single point invents a history they do not have.
    if (points.length < 2) {
      return Text(
        'One month recorded so far.',
        style: TypeScale.caption(skin.text3),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 110,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(
              values: [for (final p in points) p.value],
              stroke: skin.accent,
              baseline: skin.line,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _monthLabel(points.first.month),
              style: TypeScale.caption(skin.text3),
            ),
            Text(
              _monthLabel(points.last.month),
              style: TypeScale.caption(skin.text3),
            ),
          ],
        ),
      ],
    );
  }
}

const List<String> _monthsShort = [
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

/// "Sep 2026" from the stored "2026-09".
///
/// Never the raw key. screen_readability's rule about showing a stored value
/// as it sits on disk applies to a chart axis exactly as it does to a row.
String _monthLabel(String key) {
  if (key.length < 7) return key;
  final y = key.substring(0, 4);
  final m = int.tryParse(key.substring(5, 7));
  if (m == null || m < 1 || m > 12) return key;
  return '${_monthsShort[m - 1]} $y';
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.values,
    required this.stroke,
    required this.baseline,
  });

  final List<double> values;
  final Color stroke;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    var lo = values.reduce((a, b) => a < b ? a : b);
    var hi = values.reduce((a, b) => a > b ? a : b);

    // A FLAT SERIES HAS NO RANGE TO DIVIDE BY. Without this, three identical
    // months divide by zero and the line vanishes or fills the canvas
    // depending on which way the NaN lands. Given room above and below, a flat
    // line draws through the middle, which is what flat looks like.
    if (hi - lo < 0.005) {
      final pad = hi.abs() < 1 ? 1.0 : hi.abs() * 0.1;
      lo -= pad;
      hi += pad;
    }

    const top = 6.0;
    final h = size.height - top - 6;
    final dx = size.width / (values.length - 1);

    double y(double v) => top + h - ((v - lo) / (hi - lo)) * h;

    // ZERO, where it falls inside the range. Net worth crossing from negative
    // to positive is the single most important thing this chart can show, and
    // without the line there is nothing on screen saying which side of it the
    // user is on.
    if (lo < 0 && hi > 0) {
      canvas.drawLine(
        Offset(0, y(0)),
        Offset(size.width, y(0)),
        Paint()
          ..color = baseline
          ..strokeWidth = 1,
      );
    }

    final path = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(dx * i, y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // The last point marked, because it is the one that matches the Accounts
    // hero and is the only point a person checks against a number they know.
    canvas.drawCircle(
      Offset(dx * (values.length - 1), y(values.last)),
      4,
      Paint()..color = stroke,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.stroke != stroke;
}
