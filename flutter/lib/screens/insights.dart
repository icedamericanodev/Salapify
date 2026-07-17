// Insights: the decision screen. Everything here renders numbers the
// golden-verified engines already computed; nothing on this screen invents
// a figure. Sections follow the RN screen's logic with the UX critique
// applied: DO NEXT first (the ranked decisions from the coach), one honest
// win, safe to spend until sweldo, the health score with its parts, the six
// month trend on one shared scale, top categories, and the emergency
// runway with its honesty rules.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/analytics.dart' as analytics;
import '../money/chartgeom.dart' as chartgeom;
import '../money/coach.dart' as coach;
import '../money/commitments.dart' as commitments;
import '../theme.dart';
import 'overview.dart' show formatMoney;

class InsightsScreen extends StatelessWidget {
  final SalapifyStore store;
  final void Function(int tab)? onSwitchTab;
  const InsightsScreen({super.key, required this.store, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final data = store.data;
    final ref = DateTime.now();
    final candidates = coach.decisionCandidates(data, ref);
    final win = coach.pickWin(data, ref);
    final sts = commitments.safeToSpend(data, ref);
    final health = analytics.healthScore(data, ref);
    final series = analytics.monthlySeries(data['transactions'], 6, ref);
    final cats = analytics.categoryVsAverage(data['transactions'], ref, 6, 7);
    final runway = analytics.emergencyRunway(data, ref);
    final forecast = analytics.forecastMonthEnd(data['transactions'], ref);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const Text('INSIGHTS',
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3)),
            const SizedBox(height: 4),
            const Text('What your money is telling you, and what to do next',
                style: TextStyle(color: Barako.muted, fontSize: 13)),
            const SizedBox(height: 20),
            if (candidates.isNotEmpty) ...[
              _kicker('DO NEXT'),
              const SizedBox(height: 8),
              for (final c in candidates.take(3)) _decisionCard(c),
            ] else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('You are on track',
                          style: TextStyle(
                              color: Barako.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text(
                          'Nothing needs a money decision right now. Keep logging and enjoy the calm.',
                          style: TextStyle(
                              color: Barako.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            if (win != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.celebration_outlined,
                      color: Barako.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(win['text'] as String,
                        style: const TextStyle(
                            color: Barako.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            _safeToSpendCard(sts),
            const SizedBox(height: 12),
            _healthCard(health),
            const SizedBox(height: 12),
            _trendCard(series),
            const SizedBox(height: 12),
            if (cats.any((c) => (c['now'] as double) > 0))
              _categoriesCard(cats, forecast),
            const SizedBox(height: 12),
            _runwayCard(runway),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _kicker(String text) => Text(text,
      style: const TextStyle(
          color: Barako.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2));

  Widget _decisionCard(Map<String, dynamic> c) {
    final tone = c['tone'] as String;
    final color = tone == 'urgent'
        ? Barako.warning
        : tone == 'watch'
            ? Barako.text
            : Barako.textSecondary;
    final utang = c['kind'] == 'utang';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: utang && onSwitchTab != null ? () => onSwitchTab!(2) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tone == 'urgent'
                          ? Barako.warning
                          : tone == 'nudge'
                              ? Barako.muted
                              : Barako.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(c['title'] as String,
                        style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (utang && onSwitchTab != null)
                    const Icon(Icons.chevron_right,
                        color: Barako.faint, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(c['message'] as String,
                  style: const TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 13,
                      height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _safeToSpendCard(Map<String, dynamic> sts) {
    final available = sts['available'] as double;
    final perDay = sts['perDay'] as double;
    final daysLeft = sts['daysLeft'] as int;
    final committed = sts['committed'] as double;
    final billCount = sts['billCount'] as int;
    final tight = (sts['liquid'] as double) > 0 && available <= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('SAFE TO SPEND UNTIL SWELDO'),
            const SizedBox(height: 6),
            Text(formatMoney(available > 0 ? available : 0),
                style: TextStyle(
                    color: tight ? Barako.warning : Barako.primary,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(height: 4),
            Text(
              tight
                  ? 'Bills before payday already use up your spendable cash. Hold off on extras until sweldo.'
                  : 'About ${formatMoney(perDay)} a day for the next $daysLeft ${daysLeft == 1 ? 'day' : 'days'} (payday ${sts['payday']}). '
                      '${billCount > 0 ? '${formatMoney(committed)} is set aside for $billCount ${billCount == 1 ? 'bill' : 'bills'} landing first.' : 'No bills land before then.'}',
              style: TextStyle(
                  color: tight ? Barako.warning : Barako.muted,
                  fontSize: 13,
                  height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _healthCard(Map<String, dynamic> health) {
    final parts = (health['parts'] as Map).cast<String, dynamic>();
    final total = (health['total'] as double).toInt();
    const partMax = {'savings': 35, 'budget': 25, 'debt': 25, 'logging': 15};
    const partLabel = {
      'savings': 'Savings rate',
      'budget': 'Budget',
      'debt': 'Debt load',
      'logging': 'Logging habit',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('MONEY HEALTH'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$total',
                    style: const TextStyle(
                        color: Barako.primary,
                        fontSize: 34,
                        fontWeight: FontWeight.w800)),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 4),
                  child: Text('of 100',
                      style: TextStyle(color: Barako.muted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final key in ['savings', 'budget', 'debt', 'logging'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(partLabel[key]!,
                          style: const TextStyle(
                              color: Barako.textSecondary, fontSize: 12)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (parts[key] as double) / partMax[key]!,
                          minHeight: 6,
                          backgroundColor: Barako.border,
                          color: Barako.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                          '${(parts[key] as double).toInt()}/${partMax[key]}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              color: Barako.muted, fontSize: 11)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trendCard(List<Map<String, dynamic>> series) {
    final income = [for (final s in series) s['income'] as double];
    final expenses = [for (final s in series) s['expenses'] as double];
    final labels = [for (final s in series) s['label'] as String];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('LAST 6 MONTHS'),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendPainter(income: income, expenses: expenses),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final l in labels)
                  Text(l,
                      style: const TextStyle(
                          color: Barako.faint, fontSize: 10)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _legendDot(Barako.primary, 'Income'),
                const SizedBox(width: 14),
                _legendDot(Barako.warning, 'Spending'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) => Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Barako.textSecondary, fontSize: 12)),
        ],
      );

  Widget _categoriesCard(
      List<Map<String, dynamic>> cats, Map<String, dynamic> forecast) {
    final visible =
        cats.where((c) => (c['now'] as double) > 0).toList();
    var maxNow = 0.0;
    for (final c in visible) {
      if ((c['now'] as double) > maxNow) maxNow = c['now'] as double;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('WHERE YOUR MONEY WENT THIS MONTH'),
            const SizedBox(height: 4),
            Text(
                '${formatMoney(forecast['spent'] as double)} spent so far, on pace for ${formatMoney(forecast['projected'] as double)} by month end.',
                style: const TextStyle(color: Barako.muted, fontSize: 12)),
            const SizedBox(height: 10),
            for (final c in visible)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(c['label'] as String,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Barako.text, fontSize: 13)),
                        ),
                        Text(formatMoney(c['now'] as double),
                            style: const TextStyle(
                                color: Barako.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: maxNow > 0 ? (c['now'] as double) / maxNow : 0,
                        minHeight: 5,
                        backgroundColor: Barako.border,
                        color: (c['expected'] as double) > 0 &&
                                (c['now'] as double) >
                                    (c['expected'] as double) * 1.2
                            ? Barako.warning
                            : Barako.primary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            const Text(
                'An orange bar is running past its usual pace for this point in the month.',
                style: TextStyle(color: Barako.faint, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _runwayCard(Map<String, dynamic> runway) {
    final months = runway['monthsCovered'];
    final capped = runway['capped'] as bool;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('EMERGENCY RUNWAY'),
            const SizedBox(height: 6),
            Text(
                months == null
                    ? 'Not enough history yet'
                    : capped
                        ? '12+ months'
                        : '$months ${months == 1.0 ? 'month' : 'months'}',
                style: const TextStyle(
                    color: Barako.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              months == null
                  ? 'After two full months of logged spending, this shows how long your accessible money would carry you.'
                  : 'Your accessible money (${formatMoney(runway['buffer'] as double)}) covers ${capped ? 'more than a year' : 'about $months months'} of your typical ${formatMoney(runway['avgMonthlyExpense'] as double)} monthly spending.',
              style: const TextStyle(
                  color: Barako.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> income;
  final List<double> expenses;
  _TrendPainter({required this.income, required this.expenses});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Barako.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final max = chartgeom.sharedMax([income, expenses]);
    _drawSeries(canvas, size, income, max, Barako.primary);
    _drawSeries(canvas, size, expenses, max, Barako.warning);
  }

  void _drawSeries(Canvas canvas, Size size, List<double> values, double max,
      Color color) {
    final pts =
        chartgeom.linePointsScaled(values, max, size.width, size.height, 8);
    if (pts.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pts.first['x']!, pts.first['y']!);
    for (final p in pts.skip(1)) {
      path.lineTo(p['x']!, p['y']!);
    }
    canvas.drawPath(path, paint);
    final dot = Paint()..color = color;
    canvas.drawCircle(
        Offset(pts.last['x']!, pts.last['y']!), 3.5, dot);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.income != income || old.expenses != expenses;
}
