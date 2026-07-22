// Reports: your money as three plain-language financial statements, built from
// the golden-locked engine in money/statements.dart so every number matches
// Home, Insights, and the RN app to the centavo. Each statement leads with one
// second-person takeaway and a short "what this means for you" before the
// accounting lines, so a first-time reader knows if they are okay before they
// hit a single subtotal. Reached from Menu. Read-only. Adapted and improved
// from the RN reports screen, with the design panel's decision-value framing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../money/analytics.dart' show categoryVsAverage, monthlySeries;
import '../money/debtmath.dart' show debtFreeProjection;
import '../money/ledger.dart' show amountOf;
import '../money/reports_calc.dart';
import '../money/statements.dart';
import '../theme.dart';
import '../widgets/screen_header.dart';
import 'overview.dart' show formatMoney;

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December',
];

String _monthYear(String iso) {
  final p = iso.split('-');
  if (p.length < 2) return iso;
  final m = int.tryParse(p[1]) ?? 1;
  return '${_months[(m - 1).clamp(0, 11)]} ${p[0]}';
}

class ReportsScreen extends StatefulWidget {
  final SalapifyStore store;
  final void Function(int)? onSwitchTab;
  const ReportsScreen({super.key, required this.store, this.onSwitchTab});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // 0 = Income, 1 = Cash flow, 2 = Position. Income leads because "did I
  // overspend this month" changes a decision far more often than net worth.
  int _tab = 0;
  // Months back from now; 0 is this month. Only Income and Cash flow move.
  int _monthOffset = 0;
  final _extra = TextEditingController();

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _data =>
      (widget.store.data).cast<String, dynamic>();

  DateTime get _ref {
    final now = DateTime.now();
    // Day 15 dodges month-length edges when subtracting months.
    return DateTime(now.year, now.month - _monthOffset, 15);
  }

  bool get _isEmpty {
    final accts = _data['accounts'];
    final tx = _data['transactions'];
    return (accts is! List || accts.isEmpty) && (tx is! List || tx.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                ScreenHeader('REPORTS',
                    subtitle: 'Your money as three simple statements'),
                if (_isEmpty)
                  _emptyState(context)
                else ...[
                  _netWorthLead(),
                  const SizedBox(height: 14),
                  _segmented(),
                  const SizedBox(height: 12),
                  // Position is always "as of today" and the card already says
                  // so in its kicker, so only Income and Cash flow get a stepper.
                  if (_tab != 2) ...[
                    _monthStepper(),
                    const SizedBox(height: 12),
                  ],
                  if (_tab == 0) ...[
                    _incomeCard(),
                    const SizedBox(height: 14),
                    _trendSection(),
                    const SizedBox(height: 14),
                    _whatMovedSection(),
                  ] else if (_tab == 1)
                    _cashFlowCard()
                  else
                    _positionCard(),
                  const SizedBox(height: 22),
                  _debtPlanSection(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // ---- Net worth lead ----
  Widget _netWorthLead() {
    final parts = netWorthParts(_data);
    final net = (parts['netWorth'] as num).toDouble();
    final assets = (parts['assets'] as num).toDouble();
    final liab = (parts['liabilities'] as num).toDouble();
    final receivables = (parts['receivables'] as num).toDouble();

    String support;
    if (net >= 0) {
      support =
          'You own ${formatMoney(assets)} and owe ${formatMoney(liab)}. What is left over is really yours.';
    } else {
      support =
          'You owe ${formatMoney(liab)}, more than the ${formatMoney(assets)} you own right now. That is common early on, and chipping at the costliest debt is the fastest way up.';
    }
    // Honesty: a net worth propped up by uncollected utang is softer than it
    // looks.
    final receivableHeavy = assets > 0 && receivables > assets * 0.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('YOUR NET WORTH', style: Barako.kickerStyle),
            const SizedBox(height: 6),
            _heroAmount(net, 34),
            const SizedBox(height: 12),
            _SplitBar(
                aValue: assets,
                aColor: Barako.primary,
                bValue: liab,
                bColor: Barako.warningStrong),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _legendDot(Barako.primary, 'Own ${formatMoney(assets)}'),
                _legendDot(Barako.warningStrong, 'Owe ${formatMoney(liab)}'),
              ],
            ),
            const SizedBox(height: 10),
            Text(support,
                style: TextStyle(
                    color: Barako.muted, fontSize: 13, height: 1.4)),
            if (receivableHeavy) ...[
              const SizedBox(height: 6),
              Text(
                  'A big part of this is utang owed to you. Your real, spendable position is closer to ${formatMoney(spendablePosition(parts))} until it lands.',
                  style: TextStyle(
                      color: Barako.faint, fontSize: 12, height: 1.35)),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Segmented control ----
  Widget _segmented() {
    Widget seg(String label, int i) {
      final on = _tab == i;
      return Expanded(
        child: Material(
          color: on ? Barako.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _tab = i);
            },
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: on ? Barako.onPrimary : Barako.textSecondary,
                        fontSize: 13,
                        fontWeight:
                            on ? FontWeight.w700 : FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Barako.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        seg('Income', 0),
        seg('Cash flow', 1),
        seg('Position', 2),
      ]),
    );
  }

  Widget _monthStepper() {
    final label = '${_months[_ref.month - 1]} ${_ref.year}';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: _monthOffset < 12 ? Barako.primaryText : Barako.faint,
          onPressed:
              _monthOffset < 12 ? () => setState(() => _monthOffset++) : null,
          tooltip: 'Earlier month',
        ),
        Text(label,
            style: TextStyle(
                color: Barako.text, fontSize: 15, fontWeight: FontWeight.w700)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: _monthOffset > 0 ? Barako.primaryText : Barako.faint,
          onPressed:
              _monthOffset > 0 ? () => setState(() => _monthOffset--) : null,
          tooltip: 'Later month',
        ),
      ],
    );
  }

  // ---- Income statement ----
  Widget _incomeCard() {
    final s = incomeStatement(_data, _ref);
    final income = (s['income'] as num).toDouble();
    final expenses = (s['expenses'] as num).toDouble();
    final interest = (s['interestExpense'] as num).toDouble();
    final spending = (s['spendingExpense'] as num).toDouble();
    final net = (s['netIncome'] as num).toDouble();

    String head;
    String interp;
    Color? headColor;
    if (income == 0 && expenses == 0) {
      head = 'Nothing logged yet';
      headColor = Barako.muted;
      interp =
          'No income or spending logged for this month, so there is nothing to weigh up yet. Log a few entries and this fills in on its own.';
    } else if (income == 0 && expenses > 0) {
      head = 'No sweldo logged yet';
      headColor = Barako.muted;
      interp =
          'No income logged for this month yet, so this only counts what you have spent so far. It is not a final shortfall.';
    } else if (net > 0) {
      head = '${formatMoney(net)} kept';
      final rate = savingsRatePct(net, income);
      interp =
          'You earned more than you spent this month. About $rate% of your income stayed with you. The move now is to send some to savings before it drifts away.';
    } else if (net == 0) {
      head = 'Broke even';
      interp =
          'You spent exactly what you earned this month. Nothing lost, but nothing set aside either. Trimming one line frees up the first bit of savings.';
    } else {
      head = '${formatMoney(-net)} short';
      interp =
          'You spent more than you earned this month. One big month happens; if it repeats, the gap comes out of savings or onto utang. Pick one line to ease off, not everything.';
    }

    return _statementCard(
      forLabel: 'For ${_months[_ref.month - 1]} ${_ref.year}',
      headline: head,
      headlineColor: headColor,
      headlineValue: net,
      interp: interp,
      visual: _SplitBar(
          aValue: income,
          aColor: Barako.primary,
          bValue: expenses,
          bColor: Barako.warningStrong),
      legend: [
        _legendDot(Barako.primary, 'Earned ${formatMoney(income)}'),
        _legendDot(Barako.warningStrong, 'Spent ${formatMoney(expenses)}'),
      ],
      lines: [
        _line('Income earned', income),
        _line('Spending', spending, sub: true),
        if (interest > 0)
          _line('Debt interest', interest,
              sub: true, color: Barako.warningStrong),
        _divider(),
        _line('Net income', net,
            total: true,
            color: net >= 0 ? Barako.primary : Barako.warningStrong),
        if (interest > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                '${formatMoney(interest)} of that was pure interest, money that bought you nothing. That is the number the debt plan below is built to shrink.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 12, height: 1.35)),
          ),
      ],
    );
  }

  // ---- Spending trend: this month vs your usual ----
  Widget _trendSection() {
    final series = monthlySeries(_data['transactions'], 6, _ref);
    // For the current month, pace the "usual" to how far in we are; a past
    // month you navigated to is complete, so compare against the full usual.
    final now = DateTime.now();
    final isCurrent = _monthOffset == 0;
    final daysInMonth = DateTime(_ref.year, _ref.month + 1, 0).day;
    final frac = isCurrent ? (now.day / daysInMonth) : 1.0;
    final cmp = spendingVsUsual(series, frac);

    // The plain read. A completed month gets an exact full-to-full percentage.
    // The current month never does: fixed costs (rent, utang, subscriptions)
    // land on the 1st, so a paced percentage balloons early in the month. It
    // states the facts instead, and adds a soft run-rate read only once the
    // month is well underway.
    final usualStr = formatMoney(cmp.usual);
    String read;
    Color readColor = Barako.textSecondary;
    if (!cmp.hasHistory) {
      read =
          'Not enough history yet to compare. After a couple of logged months, this tells you whether a month is normal for you.';
      readColor = Barako.muted;
    } else if (!isCurrent) {
      // A month you navigated to is complete, so this is a like-for-like read.
      final pct = cmp.pctVsExpected.abs();
      if (cmp.priorMonths == 1) {
        read =
            'Going by just the month before, about $usualStr, this month came in ${cmp.pctVsExpected >= 0 ? '$pct% higher' : '$pct% lower'}. One month is only a rough guide.';
        readColor = Barako.muted;
      } else if (cmp.pctVsExpected >= 10) {
        read =
            'You spent about $pct% more than your usual $usualStr month. Worth a look at what moved.';
        readColor = Barako.warningStrong;
      } else if (cmp.pctVsExpected <= -10) {
        read = 'A lighter month, about $pct% below your usual $usualStr.';
        readColor = Barako.primaryText;
      } else {
        read = 'Right around your usual $usualStr for the month. Steady.';
      }
    } else {
      final soFar = formatMoney(cmp.current);
      if (cmp.priorMonths == 1) {
        read =
            'So far this month you have spent $soFar. Going by just last month, your usual is about $usualStr. One month is only a rough guide.';
        readColor = Barako.muted;
      } else if (frac < 0.34) {
        read =
            'Still early in the month. So far you have spent $soFar, and your usual full month runs about $usualStr. Check back once more of the month has passed.';
        readColor = Barako.muted;
      } else {
        final projected = cmp.current / frac;
        final projStr = formatMoney(projected);
        if (projected >= cmp.usual * 1.2) {
          read =
              'So far this month: $soFar. At this pace you are heading for about $projStr, above your usual $usualStr. Worth easing off a line or two.';
          readColor = Barako.warningStrong;
        } else if (projected <= cmp.usual * 0.8) {
          read =
              'So far this month: $soFar. At this pace you are tracking under your usual $usualStr. Just make sure that is real and not entries you have not logged yet.';
        } else {
          read =
              'So far this month: $soFar. At this pace you are tracking close to your usual $usualStr. Steady.';
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SPENDING TREND', style: Barako.kickerStyle),
            const SizedBox(height: 4),
            Text('Last 6 months, spending per month',
                style: TextStyle(color: Barako.muted, fontSize: 12)),
            const SizedBox(height: 14),
            _TrendBars(
                series: series,
                usual: cmp.hasHistory ? cmp.usual : 0,
                focusKey: series.isNotEmpty ? series.last['key'] as String : '',
                focusPartial: isCurrent),
            const SizedBox(height: 14),
            Text(read,
                style: TextStyle(color: readColor, fontSize: 13, height: 1.45)),
          ],
        ),
      ),
    );
  }

  // ---- Where it went: the categories behind the month ----
  Widget _whatMovedSection() {
    final now = DateTime.now();
    final isCurrent = _monthOffset == 0;
    // The current month uses the real date so the "more than usual" flag paces
    // against how far in we are; a navigated past month is complete.
    final catRef = isCurrent ? now : _ref;
    final all = categoryVsAverage(_data['transactions'], catRef, 6, 5);
    final rows = all.where((r) => amountOf(r['now']) > 0).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final daysInMonth = DateTime(catRef.year, catRef.month + 1, 0).day;
    // Early in a month, categories are still filling in, so hold the flags.
    final canFlag = !isCurrent || (catRef.day / daysInMonth) >= 0.34;
    // Which categories are regular enough to be judged (rent-once and
    // tuition-occasionally are ranked but never flagged).
    final history = priorCategoryHistory(_data['transactions'], catRef);

    var maxNow = 0.0;
    for (final r in rows) {
      final v = amountOf(r['now']);
      if (v > maxNow) maxNow = v;
    }
    final scale = maxNow > 0 ? maxNow : 1.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHERE IT WENT', style: Barako.kickerStyle),
            const SizedBox(height: 4),
            Text(
                isCurrent
                    ? 'Your biggest spending so far this month'
                    : 'Your biggest spending this month',
                style: TextStyle(color: Barako.muted, fontSize: 12)),
            const SizedBox(height: 14),
            for (var i = 0; i < rows.length; i++) ...[
              _moverRow(rows[i], scale, i == 0, canFlag, history),
              if (i < rows.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _moverRow(Map<String, dynamic> r, double scale, bool biggest,
      bool canFlag, CategoryHistory history) {
    final label = r['label'] as String;
    final spent = amountOf(r['now']);
    // Flag against the FULL-month average, not a paced figure, so a category
    // paid once (rent) can never cross it by simply posting. Only regular
    // categories are eligible, and the gap must be both proportionally and
    // absolutely meaningful, so a small line does not raise an alarm.
    final avg = amountOf(r['avg']);
    final over = canFlag &&
        history.isRegular(label) &&
        avg > 0 &&
        spent > avg * 1.3 &&
        (spent - avg) >= 500;
    final fill = (spent / scale).clamp(0.0, 1.0);
    final barColor = over
        ? Barako.warningStrong
        : (biggest ? Barako.primary : Barako.primary.withValues(alpha: 0.32));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 14,
                      fontWeight:
                          biggest ? FontWeight.w700 : FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            // Flexible so an outsized amount yields instead of overflowing the
            // row next to a long label.
            Flexible(
              child: Text(formatMoney(spent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ],
        ),
        // The flag rides on its own line with the actual overage, the number a
        // user would act on, not a bare "more than usual".
        if (over) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.trending_up, size: 13, color: Barako.warningStrong),
              const SizedBox(width: 3),
              Expanded(
                child: Text('${formatMoney(spent - avg)} over your usual',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Barako.warningStrong,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) {
            return Stack(
              children: [
                Container(
                    height: 7,
                    decoration: BoxDecoration(
                        color: Barako.background,
                        borderRadius: BorderRadius.circular(4))),
                Container(
                    height: 7,
                    width: c.maxWidth * fill,
                    decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(4))),
              ],
            );
          },
        ),
      ],
    );
  }

  // ---- Cash flow ----
  Widget _cashFlowCard() {
    final s = cashFlowStatement(_data, _ref);
    final op = (s['operating'] as Map)['net'] as num;
    final fin = (s['financing'] as Map)['net'] as num;
    final inv = (s['investing'] as Map)['net'] as num;
    final netChange = (s['netChange'] as num).toDouble();
    final reconciles = s['reconciles'] == true;

    // The load-bearing honesty read: cash can rise only because you borrowed.
    String head;
    Color? headColor;
    String interp;
    if (op == 0 && inv == 0 && fin == 0) {
      head = 'Nothing moved yet';
      headColor = Barako.muted;
      interp =
          'No cash moved through a linked account this month, so there is nothing to trace yet. Link an account to a few entries and the money flow shows up here.';
    } else if (op >= 0 && netChange >= 0) {
      head = '${formatMoney(netChange)} more cash';
      interp = fin < 0
          ? 'Your normal life paid for itself and you put ${formatMoney(-fin)} toward paying down what you owe. A good month.'
          : 'Your normal life paid for itself this month, with cash to spare. That is the engine everything else runs on.';
    } else if (op < 0 && netChange >= 0) {
      interp =
          'Your cash went up, but only because you borrowed, collected utang, or sold something. Your day-to-day spending actually ran ${formatMoney(-op)} short.';
      if (fin > 0) {
        interp += ' Watch this one, borrowed cash has to be paid back.';
      }
      head = '${formatMoney(netChange)} more cash';
    } else {
      head = '${formatMoney(-netChange)} less cash';
      interp =
          'More cash moved out than came in this month. If your day-to-day keeps running short, the gap is coming from somewhere, usually savings or new utang.';
    }

    List<Widget> bucket(String name, Map m) {
      final bin = (m['in'] as num).toDouble();
      final bout = (m['out'] as num).toDouble();
      final bnet = (m['net'] as num).toDouble();
      if (bin == 0 && bout == 0) return const [];
      return [
        _line(name, bnet,
            total: true,
            color: bnet >= 0 ? Barako.primary : Barako.warningStrong),
        if (bin > 0) _line('Cash in', bin, sub: true),
        if (bout > 0) _line('Cash out', bout, sub: true),
      ];
    }

    return _statementCard(
      forLabel: 'For ${_months[_ref.month - 1]} ${_ref.year}',
      headline: head,
      headlineColor: headColor,
      headlineValue: netChange,
      interp: interp,
      lines: [
        ...bucket('Day to day', s['operating'] as Map),
        ...bucket('Buying or selling', s['investing'] as Map),
        ...bucket('Utang and loans', s['financing'] as Map),
        _divider(),
        _line('Net change in cash', netChange,
            total: true,
            color: netChange >= 0 ? Barako.primary : Barako.warningStrong),
        if (!reconciles)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
                'A saved payment did not split cleanly into principal and interest, so a small amount could not be sorted. Your other totals are still correct.',
                style: TextStyle(
                    color: Barako.warningStrong, fontSize: 12, height: 1.35)),
          ),
      ],
    );
  }

  // ---- Financial position ----
  Widget _positionCard() {
    final s = balanceSheet(_data);
    final cash = (s['cash'] as num).toDouble();
    final bank = (s['bank'] as num).toDouble();
    final recv = (s['receivables'] as num).toDouble();
    final investments = (s['investments'] as num).toDouble();
    final totalAssets = (s['totalAssets'] as num).toDouble();
    final shortDebts = (s['shortDebts'] as num).toDouble();
    final longDebts = (s['longDebts'] as num).toDouble();
    final payables = (s['payables'] as num).toDouble();
    final totalLiab = (s['totalLiabilities'] as num).toDouble();
    final equity = (s['equity'] as num).toDouble();
    final balances = s['balances'] == true;

    final gap = liquidGap(s);
    final interp = gap >= 0
        ? 'If every short-term debt came due today, your cash, e-wallets, and utang owed to you would cover it, with ${formatMoney(gap)} to spare.'
        : 'If every short-term debt came due today, your cash, e-wallets, and utang owed to you would fall ${formatMoney(-gap)} short. A small buffer you do not touch is the fix.';

    return _statementCard(
      forLabel: 'As of today',
      headline: equity >= 0
          ? '${formatMoney(equity)} to your name'
          : '${formatMoney(-equity)} in the red',
      headlineValue: equity,
      interp: interp,
      lines: [
        _line('What you own', totalAssets,
            total: true, color: Barako.primary),
        if (cash > 0) _line('Cash', cash, sub: true),
        if (bank > 0) _line('Bank and e-wallets', bank, sub: true),
        if (recv > 0) _line('Utang owed to you', recv, sub: true),
        if (investments > 0) _line('Assets and holdings', investments, sub: true),
        const SizedBox(height: 6),
        _line('What you owe', totalLiab,
            total: true, color: Barako.warningStrong),
        if (shortDebts > 0) _line('Cards and short loans', shortDebts, sub: true),
        if (longDebts > 0) _line('Long-term loans', longDebts, sub: true),
        if (payables > 0) _line('Utang you owe', payables, sub: true),
        _divider(),
        _line('Net worth', equity,
            total: true,
            color: equity >= 0 ? Barako.primary : Barako.warningStrong),
        const SizedBox(height: 8),
        Text(
            balances
                ? 'Owns ${formatMoney(totalAssets)} = owes ${formatMoney(totalLiab)} + net worth ${formatMoney(equity)}. Balanced.'
                : 'These do not tie out. Check for an odd entry or a hand-edited balance.',
            style: TextStyle(
                color: balances ? Barako.faint : Barako.warningStrong,
                fontSize: 12,
                height: 1.35)),
      ],
    );
  }

  // ---- Debt-free plan ----
  Widget _debtPlanSection() {
    final pro = (_data['settings'] as Map?)?['pro'] == true;
    final debts = _data['debts'];
    final hasDebt = debts is List &&
        debts.any((d) => d is Map && amountOf(d['remaining']) > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('DEBT-FREE PLAN', style: Barako.kickerStyle),
            const SizedBox(width: 8),
            Text('PRO',
                style: TextStyle(
                    color: Barako.caramel,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: !pro
                ? _debtLocked()
                : !hasDebt
                    ? Text('No debts to project. You are already free. 🎉',
                        style: TextStyle(
                            color: Barako.primaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700))
                    : _debtPlan(debts),
          ),
        ),
      ],
    );
  }

  Widget _debtLocked() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Unlock Pro to see your debt-free date and how much interest the right strategy saves you.',
              style: TextStyle(
                  color: Barako.textSecondary, fontSize: 14, height: 1.4)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Pro is free during early access. Turn it on from a Pro feature and it stays free for early users.')));
            },
            style: FilledButton.styleFrom(
                backgroundColor: Barako.primary,
                foregroundColor: Barako.onPrimary),
            child: const Text('About Pro'),
          ),
        ],
      );

  Widget _debtPlan(List debts) {
    final extra = double.tryParse(_extra.text.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
    final ref = DateTime.now();
    final avalanche = debtFreeProjection(debts, 'avalanche', extra, ref);
    final snowball = debtFreeProjection(debts, 'snowball', extra, ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'Keep a small cash cushion first, even one sweldo, so a surprise does not send you borrowing again. Then aim any extra at debt.',
            style: TextStyle(color: Barako.faint, fontSize: 12, height: 1.35)),
        const SizedBox(height: 12),
        Text('Extra you can add each month', style: Barako.kickerStyle),
        const SizedBox(height: 6),
        TextField(
          controller: _extra,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]'))
          ],
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: Barako.text, fontSize: 15),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: TextStyle(color: Barako.faint),
            prefixText: '₱ ',
            prefixStyle: TextStyle(color: Barako.muted),
            filled: true,
            fillColor: Barako.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Barako.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Barako.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Barako.primary),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (extra <= 0)
          _debtNoExtra(avalanche)
        else
          _debtCompare(avalanche, snowball, extra),
        const SizedBox(height: 10),
        Text(
            'An estimate from your logged balances and rates. It assumes rates and minimums hold and each finished debt rolls its payment into the next.',
            style: TextStyle(color: Barako.faint, fontSize: 11, height: 1.35)),
      ],
    );
  }

  Widget _debtNoExtra(Map<String, dynamic>? avalanche) {
    if (avalanche == null) {
      return Text(
          'At your current payments the interest still grows faster than you pay it down, so there is no freedom date yet. Even a small extra aimed at your highest-rate debt can start to turn this around.',
          style: TextStyle(
              color: Barako.warningStrong, fontSize: 13, height: 1.4));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line('Debt-free ${_monthYear(avalanche['date'] as String)}',
            (avalanche['totalInterest'] as num).toDouble(),
            total: true, color: Barako.primary),
        const SizedBox(height: 4),
        Text(
            'That is the total interest you would pay keeping your payments steady until every debt is gone. Type an extra amount and I will show which strategy saves you more.',
            style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.35)),
      ],
    );
  }

  Widget _debtCompare(
      Map<String, dynamic>? avalanche, Map<String, dynamic>? snowball, double extra) {
    if (avalanche == null || snowball == null) {
      return Text(
          'At this amount the interest still outruns the payments, so there is no freedom date yet. A bigger extra, aimed at your highest-rate debt, flips this.',
          style: TextStyle(
              color: Barako.warningStrong, fontSize: 13, height: 1.4));
    }
    final avaInt = (avalanche['totalInterest'] as num).toDouble();
    final snowInt = (snowball['totalInterest'] as num).toDouble();
    final saved = interestSaved(snowInt, avaInt); // mirror RN operand order

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Both strategies get the same neutral treatment; the interest number,
        // not the color, carries the tradeoff. Snowball is a valid choice.
        _line('Avalanche · free ${_monthYear(avalanche['date'] as String)}',
            avaInt,
            total: true, color: Barako.text),
        Text('Pay the highest interest rate first. Costs the least overall.',
            style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.3)),
        const SizedBox(height: 10),
        _line('Snowball · free ${_monthYear(snowball['date'] as String)}',
            snowInt,
            total: true, color: Barako.text),
        Text(
            'Pay the smallest balance first. You clear a whole debt sooner, and that momentum is often what makes people finish.',
            style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.3)),
        const SizedBox(height: 12),
        Text(
            saved > 0
                ? 'With ${formatMoney(extra)} extra a month, avalanche keeps about ${formatMoney(saved)} more out of interest. If that gap feels small, take snowball for the quick win.'
                : 'At this amount both strategies cost about the same, so pick snowball for the motivation of an early win.',
            style: TextStyle(
                color: Barako.text, fontSize: 13, height: 1.4)),
      ],
    );
  }

  // ---- Shared building blocks ----
  Widget _statementCard({
    required String forLabel,
    required String headline,
    required double headlineValue,
    Color? headlineColor,
    required String interp,
    Widget? visual,
    List<Widget>? legend,
    required List<Widget> lines,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(forLabel.toUpperCase(), style: Barako.kickerStyle),
            const SizedBox(height: 8),
            _heroAmount(headlineValue, 27,
                labelOverride: headline, colorOverride: headlineColor),
            const SizedBox(height: 8),
            Text(interp,
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 13, height: 1.45)),
            if (visual != null) ...[
              const SizedBox(height: 14),
              visual,
            ],
            if (legend != null) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 14, runSpacing: 6, children: legend),
            ],
            const SizedBox(height: 14),
            ...lines,
          ],
        ),
      ),
    );
  }

  // The big Fraunces figure, colored by sign, scaled down so seven digits fit.
  // colorOverride wins when a headline is neutral (nothing logged, break even),
  // so a zero-activity month is not painted red like a real shortfall.
  Widget _heroAmount(double value, double size,
      {String? labelOverride, Color? colorOverride}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(labelOverride ?? formatMoney(value),
          maxLines: 1,
          style: TextStyle(
              fontFamily: 'Fraunces',
              color: colorOverride ??
                  (value >= 0 ? Barako.primary : Barako.warningStrong),
              fontSize: size,
              height: 1.05,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }

  Widget _line(String label, num value,
      {bool sub = false, bool total = false, Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: total ? 8 : (sub ? 3 : 6)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: sub ? 16 : 0, right: 12),
              child: Text(label,
                  style: TextStyle(
                      color: sub
                          ? Barako.muted
                          : (total ? Barako.text : Barako.textSecondary),
                      fontSize: sub ? 12 : 14,
                      fontWeight: total ? FontWeight.w700 : FontWeight.w500,
                      height: 1.3)),
            ),
          ),
          Text(formatMoney(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: color ?? (sub ? Barako.muted : Barako.text),
                  fontSize: sub ? 12 : (total ? 16 : 14),
                  fontWeight: total ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Divider(color: Barako.border, height: 1),
      );

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: Barako.muted,
                fontSize: 12,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
  }

  Widget _emptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text('Your reports build themselves',
                style: TextStyle(
                    fontFamily: 'Fraunces',
                    color: Barako.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                'Add an account and log a few entries, and three statements appear here. Position shows what you own and owe. Income shows what you earned and spent this month. Cash flow shows where the pesos actually moved. Nothing to set up, just log.',
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 14, height: 1.45)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                if (widget.onSwitchTab != null) {
                  Navigator.of(context).pop();
                  widget.onSwitchTab!(0);
                } else {
                  Navigator.of(context).pop();
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary),
              child: const Text('Start logging'),
            ),
          ],
        ),
      ),
    );
  }
}

// Six monthly spending bars with a dashed "usual" reference line, so a glance
// answers "is this month normal for me". The focus month is emphasized; the
// others recede. Pure Dart, no painter. Heights come from the golden-locked
// monthlySeries, so the bars never disagree with the statement above them.
class _TrendBars extends StatelessWidget {
  final List<Map<String, dynamic>> series;
  final double usual;
  final String focusKey;
  final bool focusPartial;
  const _TrendBars({
    required this.series,
    required this.usual,
    required this.focusKey,
    this.focusPartial = false,
  });

  double _exp(Map<String, dynamic> m) {
    final e = amountOf(m['expenses']);
    return e.isFinite && e > 0 ? e : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    const areaH = 76.0;
    // The tallest bar (or the usual line) sets the scale.
    var peak = usual.isFinite ? usual : 0.0;
    for (final m in series) {
      final e = _exp(m);
      if (e > peak) peak = e;
    }
    if (!(peak > 0)) peak = 1;
    // Keep the line 2px below the top so it stays visible even when the usual
    // equals the peak (every shown month at or below average).
    final usualH = (usual / peak * areaH).clamp(0.0, areaH - 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: areaH,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final m in series)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            // A true no-spend month shows nothing, not a stub,
                            // so a glance does not read it as a small spend.
                            height: _exp(m) > 0
                                ? (_exp(m) / peak * areaH).clamp(2.0, areaH)
                                : 0.0,
                            decoration: BoxDecoration(
                              color: m['key'] == focusKey
                                  ? Barako.primary
                                  : Barako.primary.withValues(alpha: 0.26),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (usual > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: usualH,
                  child: const _DashedLine(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in series)
              Expanded(
                child: Column(
                  children: [
                    Text(m['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: m['key'] == focusKey
                                ? Barako.text
                                : Barako.faint,
                            fontSize: 10,
                            fontWeight: m['key'] == focusKey
                                ? FontWeight.w700
                                : FontWeight.w500)),
                    // The current month's bar is only spending so far, not a
                    // finished month, so it is labeled to avoid a false
                    // "low month" read against the completed bars beside it.
                    if (m['key'] == focusKey && focusPartial)
                      Text('so far',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Barako.faint, fontSize: 8.5)),
                  ],
                ),
              ),
          ],
        ),
        if (usual > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 16, child: Divider(color: Barako.faint, height: 1)),
              const SizedBox(width: 6),
              Text('Your usual ${formatMoney(usual)} a month',
                  style: TextStyle(color: Barako.muted, fontSize: 11)),
            ],
          ),
        ],
      ],
    );
  }
}

// A thin dashed rule for the "usual" reference line. Pure Dart, laid out from
// the available width so it never overflows.
class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dash = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dash + gap)).floor().clamp(1, 400);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              Container(width: dash, height: 1.5, color: Barako.faint),
          ],
        );
      },
    );
  }
}

// A proportion bar: two segments sized by value, with a 2px surface gap so the
// two colors never touch. Pure Dart, no painter. Colors passed in, so the
// widget is safe even though it carries color (the values move every build).
class _SplitBar extends StatelessWidget {
  final double aValue;
  final Color aColor;
  final double bValue;
  final Color bColor;
  const _SplitBar({
    required this.aValue,
    required this.aColor,
    required this.bValue,
    required this.bColor,
  });

  @override
  Widget build(BuildContext context) {
    final a = aValue.abs();
    final b = bValue.abs();
    // Clamp each to at least 1 so a zero side still shows a sliver. round()
    // throws on a non-finite value, so guard it: an Infinity or NaN side takes
    // the full flex rather than crashing the whole screen (the formatMoney
    // "stay alive" contract).
    final af = a.isFinite ? (a * 1000).round().clamp(1, 1 << 30) : (1 << 30);
    final bf = b.isFinite ? (b * 1000).round().clamp(1, 1 << 30) : (1 << 30);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Row(
        children: [
          Expanded(flex: af, child: Container(height: 10, color: aColor)),
          const SizedBox(width: 2),
          Expanded(flex: bf, child: Container(height: 10, color: bColor)),
        ],
      ),
    );
  }
}
