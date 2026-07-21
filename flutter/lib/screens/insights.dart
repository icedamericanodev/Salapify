// Insights: the decision screen. Everything here renders numbers the
// golden-verified engines already computed; nothing on this screen invents
// a figure. Sections follow the RN screen's logic with the UX critique
// applied: DO NEXT first (the ranked decisions from the coach), one honest
// win, safe to spend until sweldo, the health score with its parts, the six
// month trend on one shared scale, top categories, and the emergency
// runway with its honesty rules.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../data/store.dart';
import '../money/analytics.dart' as analytics;
import '../money/chartgeom.dart' as chartgeom;
import '../money/coach.dart' as coach;
import '../money/commitments.dart' as commitments;
import '../money/debtmath.dart' as debtmath;
import '../money/ledger.dart' show amountOf;
import '../money/surplus.dart' as surplus;
import '../theme.dart';
import 'overview.dart' show formatMoney;

const List<String> _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// An ISO 'YYYY-MM-DD' payoff date as 'Mon YYYY', the same short format the
/// Debts screen uses. The Debts screen defaults to the snowball plan while
/// this simulator projects the cheaper avalanche path on purpose, so the two
/// can differ by a little; only the date FORMAT is shared here.
String _monthYear(String iso) {
  final p = iso.split('-');
  if (p.length < 2) return iso;
  final m = int.tryParse(p[1]);
  if (m == null || m < 1 || m > 12) return iso;
  return '${_monthsShort[m - 1]} ${p[0]}';
}

/// True when at least one debt still has real money owed, so the what-if
/// simulator has something to project. The 0.5 threshold matches
/// debtFreeProjection's payoff cutoff, so a sub-centavo leftover never
/// renders a pointless "debt free this month, ₱0 interest" card. A debt-free
/// user never sees it at all.
bool _hasActiveDebt(dynamic debts) {
  for (final d in (debts is List ? debts : const [])) {
    if (d is Map && amountOf(d['remaining']) > 0.5) return true;
  }
  return false;
}

/// Whole pesos, comma grouped, shared by the forward-looking cards. Projection
/// and goal amounts are already whole, and the ladders are round, so centavos
/// would only add noise. Guards non-finite the way formatMoney does so an
/// absurd backup value renders instead of crashing round().
String _wholePeso(num v) {
  if (!v.isFinite) return '₱$v';
  final n = v.round();
  final neg = n < 0;
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}₱$buf';
}

/// The one goal that most wants a decision, for the savings simulator: still
/// funded goals only, ranked behind first, then the soonest deadline, then
/// the biggest remaining. Null when nothing is worth projecting, so a user
/// with no live goals never sees the card.
Map<String, dynamic>? _pickFocusGoal(dynamic goals, DateTime ref) {
  final active = <(Map<String, dynamic>, Map<String, dynamic>)>[];
  for (final g in (goals is List ? goals : const [])) {
    if (g is! Map) continue;
    final gm = g.cast<String, dynamic>();
    if (!(amountOf(gm['target']) > 0)) continue;
    final p = analytics.goalPace(gm, ref);
    if (p['done'] == true || !((p['remaining'] as num) > 0)) continue;
    active.add((gm, p));
  }
  if (active.isEmpty) return null;
  int rank(String? s) =>
      s == 'behind' ? 0 : (s == 'due-soon' || s == 'active') ? 1 : 2;
  active.sort((a, b) {
    final r = rank(a.$2['status'] as String?)
        .compareTo(rank(b.$2['status'] as String?));
    if (r != 0) return r;
    final da = (a.$2['targetDate'] as String?) ?? '';
    final db = (b.$2['targetDate'] as String?) ?? '';
    if (da.isNotEmpty && db.isNotEmpty && da != db) return da.compareTo(db);
    return (b.$2['remaining'] as num).compareTo(a.$2['remaining'] as num);
  });
  return active.first.$1;
}

/// Whether a funded ISO date (YYYY-MM-DD) meets a goal's target. A day
/// precise target (YYYY-MM-DD) is compared to the exact day, so a funded
/// date later in the SAME month as the target day is honestly late, not "on
/// time". A month only target (YYYY-MM) means end of that month, so any
/// same month funded date still counts as on time. Exposed for testing.
bool fundedOnTime(String fundedIso, String targetDate) {
  if (targetDate.length >= 10) return fundedIso.compareTo(targetDate) <= 0;
  final t = targetDate.length >= 7 ? targetDate.substring(0, 7) : targetDate;
  return fundedIso.substring(0, 7).compareTo(t) <= 0;
}

/// "3 months", "2.5 months", "1 month", "12+ months", or the honest
/// not-enough-history label. Whole doubles drop the ".0" the way the RN
/// screen prints plain JS numbers.
String runwayLabel(dynamic months, bool capped) {
  if (months == null) return 'Not enough history yet';
  if (capped) return '12+ months';
  final m = months as num;
  final text = m % 1 == 0 ? m.toInt().toString() : m.toString();
  return '$text ${m == 1 ? 'month' : 'months'}';
}

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
    final focusGoal = _pickFocusGoal(data['goals'], ref);
    final plan = surplus.nextPesoPlan(data, ref);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Text('INSIGHTS',
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3)),
            const SizedBox(height: 4),
            Text('What your money is telling you, and what to do next',
                style: TextStyle(color: Barako.muted, fontSize: 13)),
            SizedBox(height: 20),
            if (candidates.isNotEmpty) ...[
              _kicker('DO NEXT'),
              SizedBox(height: 8),
              for (final c in candidates.take(3)) _decisionCard(c),
            ] else
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('You are on track',
                          style: TextStyle(
                              color: Barako.primaryText,
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
                  Icon(Icons.celebration_outlined,
                      color: Barako.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(win['text'] as String,
                        style: TextStyle(
                            color: Barako.primaryText,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            _safeToSpendCard(sts),
            if (plan['applicable'] == true) ...[
              const SizedBox(height: 12),
              _nextPesoCard(plan, focusGoal),
            ],
            if (_hasActiveDebt(data['debts'])) ...[
              const SizedBox(height: 12),
              _DebtWhatIfCard(debts: data['debts'], sts: sts, ref: ref),
            ],
            if (focusGoal != null) ...[
              const SizedBox(height: 12),
              _GoalWhatIfCard(goal: focusGoal, sts: sts, ref: ref),
            ],
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
      style: TextStyle(
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
        // Tab 3 is Utang (Overview, Budget, History, Utang, Insights).
        onTap: utang && onSwitchTab != null ? () => onSwitchTab!(3) : null,
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
                    Icon(Icons.chevron_right,
                        color: Barako.faint, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(c['message'] as String,
                  style: TextStyle(
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatMoney(available > 0 ? available : 0),
                  maxLines: 1,
                  style: TextStyle(
                      fontFamily: Barako.displayFont,
                      color: tight ? Barako.warning : Barako.primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
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

  /// The order-of-operations card: where the next spare peso should go. Every
  /// number comes from surplus.nextPesoPlan, which composes the golden locked
  /// safeToSpend, emergencyRunway, and goalPace, so nothing here is invented.
  /// It fixes the quiet trap where finishing a goal looked more rewarding than
  /// clearing a debt that costs more than any savings can earn back.
  Widget _nextPesoCard(
      Map<String, dynamic> plan, Map<String, dynamic>? focusGoal) {
    final step = plan['step'] as String;
    final buffer = plan['buffer'] as double;
    final starterTarget = plan['starterTarget'] as double;
    final starterGap = plan['starterGap'] as double;
    final fullTarget = plan['fullTarget'] as double;
    final fullGap = plan['fullGap'] as double;
    final hasHistory = plan['hasHistory'] as bool;
    final crunch = plan['crunch'] as bool;
    final spare = plan['spare'] as double;
    final rateUnfilled = plan['rateUnfilled'] as bool;
    final topDebt = plan['topDebt'] as Map<String, dynamic>?;

    // A cushion this user already has, spoken plainly, so the starter and
    // fuller steps say "you have X, aim for Y" instead of a bare gap.
    final haveCushion = buffer > 0 ? ' You have about ${_wholePeso(buffer)} so far.' : '';

    var title = '';
    var support = '';
    // Debt is the only step that carries the warning tone; the rest are
    // forward and calm. warningStrong and primaryText both clear AA at these
    // small sizes on the light card, unlike the raw hero colors.
    var heroColor = Barako.primaryText;
    var activeIndex = 4; // 0 cushion, 1 debt, 2 fuller, 3 goals, 4 all done

    switch (step) {
      case 'starter':
        activeIndex = 0;
        title = 'Build a starter cushion';
        final desc = hasHistory
            ? 'a one month cushion (about ${_wholePeso(starterTarget)})'
            : 'a ${_wholePeso(starterTarget)} starter cushion';
        support =
            'About ${_wholePeso(starterGap)} more gets you to $desc, so the next gulat does not turn into utang.$haveCushion';
        break;
      case 'debt':
        activeIndex = 1;
        heroColor = Barako.warningStrong;
        final name = (topDebt?['name'] as String?) ?? 'your debt';
        final rate = (topDebt?['monthlyRate'] as double?) ?? 0;
        final rateText = rate % 1 == 0 ? rate.toInt().toString() : rate.toString();
        title = 'Clear your costliest debt';
        support =
            'Your $name costs about $rateText% a month, more than any savings can earn back. Every ₱100 you put here is worth more than ₱100 anywhere else right now.';
        break;
      case 'fuller':
        activeIndex = 2;
        title = 'Grow your safety net';
        support =
            'Your debts are handled. Next, build toward three months, about ${_wholePeso(fullTarget)}. That is what keeps a lost job or an ospital bill from undoing your progress. About ${_wholePeso(fullGap)} to go.';
        break;
      case 'goal':
        activeIndex = 3;
        final gnameRaw = focusGoal?['name'];
        final gname = (gnameRaw is String && gnameRaw.trim().isNotEmpty)
            ? gnameRaw.trim()
            : 'your goal';
        title = 'Now, chase your goal';
        support =
            'Your cushion and high cost debt are handled. Your spare can now go to $gname. This is the fun part, you earned it.';
        break;
      default: // 'set'
        activeIndex = 4;
        title = 'You are in a good spot';
        support =
            'Your cushion and debts are handled and no goal is waiting. Spare pesos are yours to enjoy, or start a new goal when you are ready.';
    }

    final spareLine = crunch
        ? 'Your bills use up this sweldo already, so treat this as a plan for after payday.'
        : 'This cycle you have about ${_wholePeso(spare)} free to move, if you can spare it.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHERE YOUR NEXT PESO SHOULD GO', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    fontFamily: Barako.displayFont,
                    color: heroColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(support,
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 13, height: 1.45)),
            const SizedBox(height: 14),
            _orderRail(activeIndex),
            const SizedBox(height: 12),
            Text(spareLine,
                style: TextStyle(
                    color: crunch ? Barako.warningStrong : Barako.muted,
                    fontSize: 12,
                    height: 1.4)),
            if (rateUnfilled) ...[
              const SizedBox(height: 6),
              Text(
                  'One debt has no interest rate saved, so I left it out of the order. Add the rate and I can place it properly.',
                  style: TextStyle(
                      color: Barako.warningStrong, fontSize: 12, height: 1.4)),
            ],
            const SizedBox(height: 8),
            Text(
                'An order based on the rates and balances you logged, not a promise. Your call always wins.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.35)),
          ],
        ),
      ),
    );
  }

  /// The four tiers as a compact rail, so the user sees the whole order and
  /// where they stand in it, not just the current step. Steps before the
  /// active one read as done, the active one is filled, later ones wait.
  Widget _orderRail(int activeIndex) {
    const labels = ['Cushion', 'Debt', 'Bigger fund', 'Goals'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < labels.length - 1 ? 6 : 0),
              child: Column(
                children: [
                  Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < activeIndex
                          ? Barako.primary.withValues(alpha: 0.45)
                          : i == activeIndex
                              ? Barako.primary
                              : Barako.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: i == activeIndex
                              ? Barako.text
                              : i < activeIndex
                                  ? Barako.muted
                                  : Barako.faint,
                          fontSize: 10,
                          fontWeight: i == activeIndex
                              ? FontWeight.w700
                              : FontWeight.w500)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _healthCard(Map<String, dynamic> health) {
    final parts = (health['parts'] as Map).cast<String, dynamic>();
    // Belt and braces: the engine guards every part against non-finite
    // sums, but toInt() on a non-finite double kills the whole tab, so the
    // screen never trusts that with its life.
    final rawTotal = health['total'] as double;
    final total = rawTotal.isFinite ? rawTotal.toInt() : 0;
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
                    style: TextStyle(
                        fontFamily: Barako.displayFont,
                        color: Barako.primary,
                        fontSize: 34,
                        fontWeight: FontWeight.w700)),
                Padding(
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
                          style: TextStyle(
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
                          style: TextStyle(
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
                      style: TextStyle(
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
              style: TextStyle(color: Barako.textSecondary, fontSize: 12)),
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
                style: TextStyle(color: Barako.muted, fontSize: 12)),
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
                              style: TextStyle(
                                  color: Barako.text, fontSize: 13)),
                        ),
                        Text(formatMoney(c['now'] as double),
                            style: TextStyle(
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
            Text(
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
            Text(runwayLabel(months, capped),
                style: TextStyle(
                    color: Barako.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              months == null
                  ? 'After two full months of logged spending, this shows how long your accessible money would carry you.'
                  : 'Your accessible money (${formatMoney(runway['buffer'] as double)}) covers ${capped ? 'more than a year' : 'about ${runwayLabel(months, false)}'} of your typical ${formatMoney(runway['avgMonthlyExpense'] as double)} monthly spending.',
              style: TextStyle(
                  color: Barako.muted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// The forward-looking decision card: drag the extra payment up and watch
/// the debt free date jump closer and the interest drop. Every number comes
/// from debtmath.whatIfLadder, which composes the golden locked
/// debtFreeProjection, so nothing here is invented and it matches the live
/// app to the peso. Only renders when there is real debt to project.
class _DebtWhatIfCard extends StatefulWidget {
  final dynamic debts;
  final Map<String, dynamic> sts;
  final DateTime ref;
  const _DebtWhatIfCard(
      {required this.debts, required this.sts, required this.ref});

  @override
  State<_DebtWhatIfCard> createState() => _DebtWhatIfCardState();
}

class _DebtWhatIfCardState extends State<_DebtWhatIfCard> {
  // A fixed pure ladder, not a free slider, so every offered number is
  // affordable-sounding and the shown result is deterministic and testable.
  static const List<int> _ladder = [200, 500, 1000];
  int _extra = 500;

  String _peso(num v) => _wholePeso(v);

  /// The debt the avalanche plan attacks first, highest monthly rate wins,
  /// so the extra has a name to land on.
  String _focusDebtName() {
    Map<String, dynamic>? best;
    for (final d in (widget.debts is List ? widget.debts as List : const [])) {
      if (d is! Map) continue;
      final dm = d.cast<String, dynamic>();
      if (!(amountOf(dm['remaining']) > 0)) continue;
      if (best == null ||
          amountOf(dm['monthlyRate']) > amountOf(best['monthlyRate'])) {
        best = dm;
      }
    }
    final name = best?['name'];
    return (name is String && name.trim().isNotEmpty) ? name.trim() : 'your debt';
  }

  // Debt types that always carry interest in real life. The store fills a
  // missing rate with 0, so a card or loan sitting at 0% almost always means
  // the user never entered the rate, not that it is genuinely free. An
  // informal utang at 0% is left alone.
  static const Set<String> _interestBearingTypes = {
    'credit card', 'bnpl', 'loan',
  };

  /// True when an interest-bearing debt still owes money but has no rate
  /// saved (0 after the store's default). Its interest reads as zero, which
  /// would understate the real cost, so the card caveats it and hides the
  /// interest figure, the same honesty buildSOA applies to a rateless card.
  bool _anyActiveRateUnfilled() {
    for (final d in (widget.debts is List ? widget.debts as List : const [])) {
      if (d is! Map) continue;
      final dm = d.cast<String, dynamic>();
      if (amountOf(dm['remaining']) > 0.5 &&
          _interestBearingTypes.contains(dm['type']) &&
          amountOf(dm['monthlyRate']) <= 0) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final result = debtmath.whatIfLadder(widget.debts, _ladder, widget.ref);
    final baseline = result['baseline'] as Map<String, dynamic>?;
    final steps = (result['steps'] as List).cast<Map<String, dynamic>>();
    final step = steps.firstWhere((s) => s['extra'] == _extra);
    final proj = step['projection'] as Map<String, dynamic>?;
    final monthsSaved = step['monthsSaved'] as int?;
    final interestSaved = step['interestSaved'] as double?;
    final focus = _focusDebtName();
    final available = widget.sts['available'] as double;
    final crunch = available <= 0;
    final extraLabel = _peso(_extra);
    final atMax = _extra == _ladder.last;
    // A blank rate makes interest read as zero, so hide the interest figure
    // and caveat it instead of quietly understating the cost.
    final unfilled = _anyActiveRateUnfilled();
    final showInterest = !unfilled;

    // The hero is the one number the card exists for, promoted to Fraunces
    // like every sibling card's headline. supportText carries the concrete
    // dates below it. Some states have no clean number, so heroText is empty
    // and supportText does the whole job.
    var heroText = '';
    var supportText = '';
    var supportColor = Barako.textSecondary;
    if (baseline != null && proj != null) {
      final date0 = _monthYear(baseline['date'] as String);
      final dateE = _monthYear(proj['date'] as String);
      final saved = monthsSaved ?? 0;
      if (saved > 0) {
        heroText = '$saved ${saved == 1 ? 'month' : 'months'} sooner';
        final interestPart =
            (showInterest && interestSaved != null && interestSaved > 0)
                ? ' You keep about ${_peso(interestSaved)} that would have gone to interest.'
                : '';
        supportText =
            'Around $dateE instead of $date0, from putting the extra on $focus.$interestPart';
      } else if (showInterest && interestSaved != null && interestSaved > 0) {
        supportText =
            'Adding $extraLabel a month keeps about ${_peso(interestSaved)} out of interest, though it is not quite enough to move the debt free month yet.${atMax ? '' : ' A bit more would.'}';
        supportColor = Barako.primaryText;
      } else {
        supportText = atMax
            ? 'Adding $extraLabel a month is not quite enough to move the date yet. This debt needs a bigger push than these steps can show.'
            : 'Adding $extraLabel a month is not quite enough to move the date yet. Try a bit more.';
      }
    } else if (baseline == null && proj != null) {
      heroText = _monthYear(proj['date'] as String);
      supportText =
          'Adding $extraLabel a month to $focus flips it from barely moving to actually shrinking. That is when you would be clear.';
    } else {
      supportText =
          'Even $extraLabel more a month is not quite enough to get ahead of the interest yet. A bigger payment, or a lower rate, turns this around.';
      supportColor = Barako.warning;
    }

    final grounding = crunch
        ? 'Your bills use up your spendable cash until sweldo, so this is a what if for now. Even a small extra after payday makes a real dent.'
        : 'You have about ${_peso(widget.sts['perDay'] as double)} a day free to spend right now, so a little extra is doable if you can spare it.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHAT IF YOU PAID A LITTLE EXTRA', style: Barako.kickerStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _ladder)
                  ChoiceChip(
                    label: Text('+${_peso(e)} a month'),
                    selected: _extra == e,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _extra = e);
                    },
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.background,
                    labelStyle: TextStyle(
                        color: _extra == e
                            ? Barako.onPrimary
                            : Barako.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (heroText.isNotEmpty) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(heroText,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: Barako.displayFont,
                        color: Barako.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(height: 4),
              Text(supportText,
                  style: TextStyle(
                      color: Barako.textSecondary, fontSize: 13, height: 1.4)),
            ] else
              Text(supportText,
                  style: TextStyle(
                      color: supportColor,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(grounding,
                style: TextStyle(
                    color: crunch ? Barako.warning : Barako.muted,
                    fontSize: 12,
                    height: 1.4)),
            if (unfilled) ...[
              const SizedBox(height: 6),
              Text(
                  'One or more debts have no interest rate saved, so this may understate the real cost. Add the rate for a truer picture.',
                  style: TextStyle(
                      color: Barako.warning, fontSize: 12, height: 1.4)),
            ],
            const SizedBox(height: 8),
            Text(
                'A projection from your logged balances, assuming you keep it up and add no new charges. A guide, not a promise.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

/// The savings twin of the debt simulator: pick what you can set aside each
/// week and see when the goal is funded, checked against the goal's own
/// target date. Uses the golden locked goalPace for the goal's facts and the
/// pace it would take to hit the date, and goalForecast for the picked pace.
class _GoalWhatIfCard extends StatefulWidget {
  final Map<String, dynamic> goal;
  final Map<String, dynamic> sts;
  final DateTime ref;
  const _GoalWhatIfCard(
      {required this.goal, required this.sts, required this.ref});

  @override
  State<_GoalWhatIfCard> createState() => _GoalWhatIfCardState();
}

class _GoalWhatIfCardState extends State<_GoalWhatIfCard> {
  static const List<int> _ladder = [200, 500, 1000];
  int _weekly = 500;

  @override
  Widget build(BuildContext context) {
    final pace = analytics.goalPace(widget.goal, widget.ref);
    final remaining = (pace['remaining'] as num).toDouble();
    final rawName = widget.goal['name'];
    final name = (rawName is String && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : 'your goal';
    final targetDate = (pace['targetDate'] as String?) ?? '';
    final status = pace['status'] as String;
    final forecast =
        analytics.goalForecast(remaining, _weekly, widget.ref);
    final available = widget.sts['available'] as double;
    final crunch = available <= 0;
    final weeklyLabel = _wholePeso(_weekly);

    var heroText = '';
    var supportText = '';
    var supportColor = Barako.textSecondary;
    if (forecast != null) {
      heroText = _monthYear(forecast['date'] as String);
      supportText =
          'Saving $weeklyLabel a week would fund $name, with ${_wholePeso(remaining)} to go.';
    } else {
      supportText =
          'Even $weeklyLabel a week would take over ten years to fund $name. A longer timeline or a smaller target would fit better.';
      supportColor = Barako.warning;
    }

    // How the picked pace lands against the date the user actually set. The
    // tone drives the color: a reward when on time, a gentle warning when the
    // target has passed, and a plain continuation of the support line
    // otherwise, so the good and the miss read differently at a glance.
    var targetText = '';
    var targetTone = 'plain';
    if (forecast != null && targetDate.isNotEmpty && status != 'no-date') {
      if (status == 'behind') {
        targetText =
            'Your ${_monthYear(targetDate)} target has already passed. Okay lang, a fresh date keeps the goal alive.';
        targetTone = 'behind';
      } else if (fundedOnTime(forecast['date'] as String, targetDate)) {
        targetText =
            'That is on time for your ${_monthYear(targetDate)} target. Nice.';
        targetTone = 'ontime';
      } else if (status == 'active') {
        targetText =
            'That lands after your ${_monthYear(targetDate)} target. To hit the date, aim for about ${_wholePeso(pace['perWeek'] as num)} a week.';
      } else {
        targetText = 'That lands after your ${_monthYear(targetDate)} target.';
      }
    }

    final grounding = crunch
        ? 'Your bills use up your spendable cash until sweldo, so treat this as a plan for after payday.'
        : 'You have about ${_wholePeso(widget.sts['perDay'] as double)} a day free right now, so setting a little aside each week is doable if you can spare it.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHAT IF YOU SAVED EACH WEEK', style: Barako.kickerStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in _ladder)
                  ChoiceChip(
                    label: Text('${_wholePeso(e)} a week'),
                    selected: _weekly == e,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _weekly = e);
                    },
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.background,
                    labelStyle: TextStyle(
                        color: _weekly == e
                            ? Barako.onPrimary
                            : Barako.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (heroText.isNotEmpty) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(heroText,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: Barako.displayFont,
                        color: Barako.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()])),
              ),
              const SizedBox(height: 4),
              Text(supportText,
                  style: TextStyle(
                      color: Barako.textSecondary, fontSize: 13, height: 1.4)),
            ] else
              Text(supportText,
                  style: TextStyle(
                      color: supportColor,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600)),
            if (targetText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(targetText,
                  style: TextStyle(
                      color: targetTone == 'behind'
                          ? Barako.warning
                          : targetTone == 'ontime'
                              ? Barako.primary
                              : Barako.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                      // Only the reward and the warning carry weight; the
                      // neutral "aim for X a week" reads as part of support.
                      fontWeight: targetTone == 'plain'
                          ? FontWeight.w400
                          : FontWeight.w600)),
            ],
            const SizedBox(height: 8),
            Text(grounding,
                style: TextStyle(
                    color: crunch ? Barako.warning : Barako.muted,
                    fontSize: 12,
                    height: 1.4)),
            const SizedBox(height: 8),
            Text(
                'A projection from your target and what you set aside, assuming you keep it up. A guide, not a promise.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.35)),
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
