// The Cash Flow Calendar screen: your month ahead on the sweldo cycle. A running
// balance line from today to the end of the month shows the days your cash runs
// tight, and the event list below spells out every sweldo in and every bill or
// due out. Every peso comes from money/cashflow_calendar.dart, never invented in
// the widget.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/cashflow_calendar.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../theme.dart';
import 'recurring.dart';

const _months = [
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

String _pretty(String iso) {
  if (iso.length < 10) return iso;
  final m = int.tryParse(iso.substring(5, 7));
  final d = int.tryParse(iso.substring(8, 10));
  if (m == null || d == null || m < 1 || m > 12) return iso;
  return '$d ${_months[m - 1]}';
}

class CashFlowScreen extends StatelessWidget {
  final SalapifyStore store;

  /// The reference "today". Defaults to now; tests inject a fixed date so the
  /// projected window is stable regardless of when the suite runs.
  final DateTime? now;
  const CashFlowScreen({super.key, required this.store, this.now});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Cash flow',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final data = store.data.cast<String, dynamic>();
            final cal = cashFlowCalendar(data, now ?? DateTime.now());
            final days = (cal['days'] as List).cast<Map<String, dynamic>>();
            final start = (cal['startBalance'] as num).toDouble();
            final end = (cal['endBalance'] as num).toDouble();
            final lowest = cal['lowest'] as Map;
            final lowBal = (lowest['balance'] as num).toDouble();
            final lowDate = lowest['date'].toString();
            final anyNegative = cal['anyNegative'] == true;

            // Events across the window, in date order, for the list below.
            final events = <Map<String, dynamic>>[];
            for (final d in days) {
              for (final e in (d['events'] as List)) {
                // Each event already carries its own balanceAfter from the
                // engine; just tag which day it lands on for the list.
                events.add({
                  ...(e as Map).cast<String, dynamic>(),
                  'date': d['date'],
                });
              }
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _decisionCard(
                  start,
                  end,
                  lowBal,
                  lowDate,
                  anyNegative,
                  events.isEmpty,
                ),
                const SizedBox(height: 14),
                if (events.isEmpty)
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecurringScreen(store: store),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add your sweldo and bills',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PROJECTED BALANCE', style: Barako.kickerStyle),
                          const SizedBox(height: 4),
                          Text(
                            'From today to the end of the month',
                            style: TextStyle(color: Barako.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          _BalanceChart(
                            days: days,
                            anyNegative: anyNegative,
                            lowDate: lowDate,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _eventsCard(events),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _decisionCard(
    double start,
    double end,
    double lowBal,
    String lowDate,
    bool anyNegative,
    bool noEvents,
  ) {
    String head;
    String body;
    Color color;
    if (noEvents) {
      head = 'Set up your month';
      body =
          'Add your sweldo and bills as recurring items, and your cards and loans as debts. '
          'Then this shows the days your cash runs tight before your next sweldo.';
      color = Barako.muted;
    } else if (anyNegative) {
      head = 'Heads up, cash runs short';
      body =
          'At this pace your spendable cash is projected to run out around ${_pretty(lowDate)}. '
          'Move a bill, hold a big buy, or set aside from your next sweldo so you do not get caught.';
      color = Barako.warningStrong;
    } else if (lowBal < start) {
      head = 'You are on track';
      body =
          'Your cash dips to ${formatMoneyText(lowBal)} around ${_pretty(lowDate)}, then recovers. '
          'Keep that day in mind before any big spend.';
      color = Barako.primaryText;
    } else {
      head = 'Steady month ahead';
      body =
          'Your cash only goes up from here, staying at or above ${formatMoneyText(start)}. '
          'A good time to move a little to savings.';
      color = Barako.primaryText;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  anyNegative
                      ? Icons.warning_amber_rounded
                      : Icons.event_available_outlined,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    head,
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
            if (!noEvents) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  _figure('NOW', formatMoneyText(start), Barako.text),
                  Container(width: 1, height: 30, color: Barako.border),
                  // Only show LOWEST when the month actually dips below today; in
                  // a steady month it would just repeat the NOW figure.
                  if (lowBal < start) ...[
                    _figure(
                      'LOWEST',
                      formatMoneyText(lowBal),
                      anyNegative ? Barako.warningStrong : Barako.text,
                    ),
                    Container(width: 1, height: 30, color: Barako.border),
                  ],
                  _figure(
                    'END OF MONTH',
                    formatMoneyText(end),
                    Barako.primaryText,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _figure(String label, String value, Color color) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Barako.kickerStyle),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _eventsCard(List<Map<String, dynamic>> events) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHAT IS COMING', style: Barako.kickerStyle),
            const SizedBox(height: 4),
            Text(
              'Every sweldo in, every bill and due out',
              style: TextStyle(color: Barako.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < events.length; i++) ...[
              if (i > 0) Divider(height: 1, color: Barako.border),
              _eventRow(events[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _eventRow(Map<String, dynamic> e) {
    final isIncome = e['kind'] == 'income';
    final amount = (e['amount'] as num).toDouble();
    final balance = (e['balanceAfter'] as num?)?.toDouble() ?? 0;
    final color = isIncome ? Barako.primaryText : Barako.warningStrong;
    final label = e['label']?.toString() ?? '';
    final dateStr = _pretty(e['date'].toString());
    return Semantics(
      label:
          '$label, $dateStr, ${isIncome ? 'in' : 'out'} ${formatMoneyText(amount)}, '
          'balance ${formatMoneyText(balance)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(
                isIncome ? Icons.south_west : Icons.north_east,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Barako.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$dateStr · balance ',
                            style: TextStyle(color: Barako.faint),
                          ),
                          TextSpan(
                            text: formatMoneyText(balance),
                            style: TextStyle(
                              color: Barako.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isIncome ? '+' : '-'}${formatMoneyText(amount)}',
                style: TextStyle(
                  color: color,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The running balance line across the window, with an area fill, the zero line
// drawn when cash is projected to run out, and the lowest day marked. Canvas is
// the right tool for a curve; the numbers all come from the engine.
class _BalanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final bool anyNegative;
  final String lowDate;
  const _BalanceChart({
    required this.days,
    required this.anyNegative,
    required this.lowDate,
  });

  @override
  Widget build(BuildContext context) {
    final first = days.isNotEmpty ? days.first['date'].toString() : '';
    final last = days.isNotEmpty ? days.last['date'].toString() : '';
    return Semantics(
      label: anyNegative
          ? 'Projected balance chart. Cash runs out around ${_pretty(lowDate)}.'
          : 'Projected balance chart for the rest of the month.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _BalancePainter(
                  days: days,
                  line: Barako.primary,
                  fill: Barako.primary.withValues(alpha: 0.19),
                  warn: Barako.warningStrong,
                  label: Barako.muted,
                  grid: Barako.border,
                  anyNegative: anyNegative,
                  lowDate: lowDate,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _pretty(first),
                  style: TextStyle(color: Barako.faint, fontSize: 10.5),
                ),
                Text(
                  _pretty(last),
                  style: TextStyle(color: Barako.faint, fontSize: 10.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalancePainter extends CustomPainter {
  final List<Map<String, dynamic>> days;
  final Color line;
  final Color fill;
  final Color warn;
  final Color grid;
  final Color label;
  final bool anyNegative;
  final String lowDate;
  _BalancePainter({
    required this.days,
    required this.line,
    required this.fill,
    required this.warn,
    required this.grid,
    required this.label,
    required this.anyNegative,
    required this.lowDate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final vals = [for (final d in days) (d['balance'] as num).toDouble()];
    var lo = vals.reduce((a, b) => a < b ? a : b);
    var hi = vals.reduce((a, b) => a > b ? a : b);
    // Always include zero in view so a run-out reads against the empty line.
    if (lo > 0) lo = 0;
    if (hi < 0) hi = 0;
    if (hi == lo) hi = lo + 1; // avoid divide by zero on a flat line
    const padTop = 8.0;
    final h = size.height - padTop - 4;
    double x(int i) =>
        days.length == 1 ? size.width / 2 : i / (days.length - 1) * size.width;
    double y(double v) => padTop + (hi - v) / (hi - lo) * h;

    // Zero line (the empty-cash line), only meaningful when cash dips near or
    // below it.
    if (lo < 0) {
      final zeroY = y(0);
      final zp = Paint()
        ..color = warn.withValues(alpha: 0.5)
        ..strokeWidth = 1;
      const dash = 4.0;
      for (var dx = 0.0; dx < size.width; dx += dash * 2) {
        canvas.drawLine(Offset(dx, zeroY), Offset(dx + dash, zeroY), zp);
      }
    }

    // Area fill under the line.
    final area = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < vals.length; i++) {
      area.lineTo(x(i), y(vals[i]));
    }
    area
      ..lineTo(x(vals.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = fill);

    // The line itself.
    final linePath = Path()..moveTo(x(0), y(vals[0]));
    for (var i = 1; i < vals.length; i++) {
      linePath.lineTo(x(i), y(vals[i]));
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );

    // Mark the lowest day.
    var lowI = 0;
    for (var i = 1; i < days.length; i++) {
      if (days[i]['date'] == lowDate) {
        lowI = i;
        break;
      }
    }
    final lowV = vals[lowI];
    final markColor = anyNegative ? warn : line;
    // Inset the marker so a lowest-day-is-today dot is not clipped at the edge.
    final markX = x(lowI).clamp(3.5, size.width - 3.5);
    final markY = y(lowV);
    canvas.drawCircle(Offset(markX, markY), 3.5, Paint()..color = markColor);
    canvas.drawCircle(
      Offset(markX, markY),
      3.5,
      Paint()
        ..color = markColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Label the dip day right at the marker, so the tightest day reads at a
    // glance instead of only from the card.
    final tp = TextPainter(
      text: TextSpan(
        text: _pretty(lowDate),
        style: TextStyle(
          color: label,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Keep the label inside the canvas horizontally, and place it above the dot
    // unless that would clip the top, in which case drop it below.
    var lx = markX - tp.width / 2;
    lx = lx.clamp(0.0, size.width - tp.width);
    final aboveY = markY - tp.height - 6;
    final ly = aboveY < 0 ? markY + 8 : aboveY;
    tp.paint(canvas, Offset(lx, ly));
  }

  @override
  bool shouldRepaint(covariant _BalancePainter old) =>
      old.days != days || old.anyNegative != anyNegative;
}
