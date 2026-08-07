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
import '../money/commitmentload.dart' as commitmentload;
import '../money/commitments.dart' as commitments;
import '../money/debtmath.dart' as debtmath;
import '../money/ledger.dart' show amountOf;
import '../money/steadypay.dart' as steadypay;
import '../money/surplus.dart' as surplus;
import '../theme.dart';
import '../typography.dart';
import '../widgets/progress_bar.dart';
import '../widgets/section.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/screen_header.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import 'afford_card.dart';
import 'log_sheet.dart' show showLogSheet;
import 'overview.dart' show formatMoney, formatMoneyAbout, prettyDay;
import 'windfall_card.dart';
import 'shell.dart';
import '../money/currencies.dart' show baseCurrencySymbol;

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
  int rank(String? s) => s == 'behind'
      ? 0
      : (s == 'due-soon' || s == 'active')
      ? 1
      : 2;
  active.sort((a, b) {
    final r = rank(
      a.$2['status'] as String?,
    ).compareTo(rank(b.$2['status'] as String?));
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
  final void Function(Destination)? onSwitchTab;

  /// Jumps to the Utang tab showing "Owed to me". Receivables taps land
  /// there specifically; plain onSwitchTab would open the "I owe" segment.
  final VoidCallback? onOpenReceivables;
  final VoidCallback? onOpenPayables;
  final VoidCallback? onMenu;
  const InsightsScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onMenu,
    this.onOpenReceivables,
    this.onOpenPayables,
  });

  // The pinned header + a single card, the shape both the empty and the error
  // states share. onMenu is on the header here too: these branches are what a
  // brand new user (empty) or a person with an unreadable backup (error) sees,
  // and Menu is the only door to 16 destinations. It was missing from the empty
  // branch once, so the emptiest account had the fewest ways out of the screen,
  // and only a geometry probe noticed.
  Widget _shell(BuildContext context, Widget card) => SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: ScreenHeader(
            'Insights',
            subtitle: 'What your money is telling you, and what to do next',
            onMenu: onMenu,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
            children: [card],
          ),
        ),
      ],
    ),
  );

  // Shown before there is any data, in place of the full analytics wall. Uses
  // the shared EmptyState so it cannot drift from the other tabs' empties.
  Widget _emptyInsights(BuildContext context) => _shell(
    context,
    EmptyState(
      icon: 'chart',
      title: 'Nothing to read yet, and that is fine',
      body:
          'Log a few entries and this turns into your safe-to-spend, where your '
          'next peso should go, and a read on the month. Nothing to set up, '
          'just log.',
      actionLabel: 'Start logging',
      // Opens the Log sheet right here, so the button does the thing it names.
      // When writes are shut (an unreadable load), there is nothing to log
      // into, so it falls back to Home where the error banner explains why.
      onAction: () => store.canWrite
          ? showLogSheet(context, store)
          : onSwitchTab?.call(Destination.home),
    ),
  );

  // Shown when the ledger could not be READ, which is a different thing from
  // empty: there IS data, the app just could not open it, so the analytics
  // would be computed over an empty fallback and read as false. Says so plainly
  // and never implies the data is gone (an unreadable load overwrites nothing).
  Widget _errorInsights(BuildContext context) => _shell(
    context,
    ErrorState(
      title: 'Your saved data could not be read',
      body:
          'Nothing was overwritten, so nothing is lost. Insights reads your '
          'data to make sense of the month, so it is waiting until the app can '
          'open it again. Home has the details and the way to recover.',
      actionLabel: 'Go to Home',
      onAction: () => onSwitchTab?.call(Destination.home),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // An unreadable ledger takes precedence over everything: computing analytics
    // over the empty fallback would read as a confident, wrong picture of the
    // month. Show the honest error instead.
    if (store.loadError != null) return _errorInsights(context);

    final data = store.data;
    final ref = DateTime.now();

    // Before any data, every card here reads zero at once (safe-to-spend 0,
    // health 0 of 100, empty charts), which is the exact "this app is for
    // people who already have their life together" wall the Home screen is
    // careful to avoid. Match Home: show one warm invitation instead.
    final accts = data['accounts'];
    final txs = data['transactions'];
    final hasStarted =
        (accts is List && accts.isNotEmpty) || (txs is List && txs.isNotEmpty);
    if (!hasStarted) return _emptyInsights(context);

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
    final load = commitmentload.commitmentLoad(data, ref);

    // Header pinned above the list on every tab (founder's call). Insights
    // is the longest screen in the app, roughly ten cards, so this is the
    // tab where losing Menu to a scroll cost the most.
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ScreenHeader(
              'Insights',
              subtitle: 'What your money is telling you, and what to do next',
              onMenu: onMenu,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
              children: [
                // The DO NEXT cards carry the specifics, most urgent first, so
                // they are the takeaway on their own. A "WHAT MATTERS NOW" line
                // used to sit above them and only restated the count, which was
                // words before the first real content; it was cut for that.
                if (candidates.isNotEmpty) ...[
                  Kicker('DO NEXT'),
                  SizedBox(height: 8),
                  for (final c in candidates.take(3)) _decisionCard(c),
                ] else
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You are on track',
                            style: AppText.bodyLg.w7.tint(Barako.primaryText),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Nothing needs a money decision right now. Keep logging and enjoy the calm.',
                            style: AppText.small,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (win != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        salapifyIcon('celebrate'),
                        color: Barako.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          win['text'] as String,
                          style: AppText.small.w6.tint(Barako.primaryText),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                _safeToSpendCard(sts),
                // Steady Pay: safe-to-spend's sibling for swing income. Shows with
                // an accepted draw, a real suggestion (three or more full income
                // months), or a building state once ANY income month exists, so a
                // user sent here by the course lesson lands on an honest progress
                // line instead of nothing. Only a truly income-less store hides it.
                ...(() {
                  final accepted = steadypay.acceptedSteadyPay(data);
                  final suggestion = steadypay.steadyPaySuggestion(data, ref);
                  // A first income logged THIS month counts as a start too (the
                  // suggestion window drops the current partial month on
                  // purpose), so the course lesson's button lands on the
                  // in-progress line from day one.
                  if (accepted == null &&
                      suggestion.weeklyDraw == null &&
                      suggestion.activeMonths == 0 &&
                      !steadypay.incomeThisMonth(data, ref)) {
                    return const <Widget>[];
                  }
                  return [
                    const SizedBox(height: 12),
                    _steadyPayCard(context, data, ref, accepted, suggestion),
                  ];
                })(),
                if (plan['applicable'] == true) ...[
                  const SizedBox(height: 12),
                  _nextPesoCard(plan, focusGoal),
                ],
                // The TOOLS band: things a user reaches for on purpose, not
                // reflections of the month. They used to render fully open,
                // two permanent screenfuls of input fields whether or not
                // anyone came to use them; folded to one line each, the
                // screen answers "what should I do next" in one screenful
                // and the tools stop being scroll tax. Values inside are
                // untouched, only which pixels are open by default changed.
                const SizedBox(height: 18),
                Kicker('TOOLS'),
                const SizedBox(height: 8),
                // "Kaya mo ba ito?" always shows: a tool anyone can reach
                // for before a purchase, so it does not gate on having debt
                // or a goal.
                CollapsibleCard(
                  title: 'Can you afford it?',
                  child: AffordCard(data: data, ref: ref),
                ),
                const SizedBox(height: 8),
                CollapsibleCard(
                  title: 'A lump sum is landing?',
                  child: WindfallCard(data: data, ref: ref),
                ),
                if (_hasActiveDebt(data['debts'])) ...[
                  const SizedBox(height: 8),
                  CollapsibleCard(
                    title: 'What if you paid a little extra',
                    child: _DebtWhatIfCard(
                      debts: data['debts'],
                      sts: sts,
                      ref: ref,
                    ),
                  ),
                ],
                if (focusGoal != null) ...[
                  const SizedBox(height: 8),
                  CollapsibleCard(
                    title: 'What if you saved each week',
                    child: _GoalWhatIfCard(goal: focusGoal, sts: sts, ref: ref),
                  ),
                ],
                const SizedBox(height: 18),
                Kicker('THE BIGGER PICTURE'),
                const SizedBox(height: 8),
                // Always open, deliberately, unlike TOOLS above: these five
                // cards ARE the reason someone opens this tab, not a preview
                // of a destination. Founder feedback, 2026-08-04, after
                // seeing them all collapsed to identical chevron rows with
                // zero glanceable content: "I think it should be expanded...
                // I will not make the user overwhelmed." Each card already
                // carries its own real number, percent, score, chart, or
                // sentence; collapsing it behind a tap hid the entire point.
                //
                // Spoken-For is a structural, reflective gauge, so it sits
                // with the "understand your situation" band, not the
                // do-next cards up top. It leads the band because
                // commitment load feeds the debt-load health.
                if (load['applicable'] == true) ...[
                  _spokenForCard(load),
                  const SizedBox(height: 12),
                ],
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
        ],
      ),
    );
  }

  // The at-a-glance summary, deliberately a single LINE, not a card: it sits
  // between the reader and the first thing to tap, so it stays light. It does
  // NOT repeat any decision title (the DO NEXT cards own those); it names the
  // count and how urgent the lead is, carried by the WORD and the glyph, never
  // colour alone.
  Widget _decisionCard(Map<String, dynamic> c) {
    final tone = c['tone'] as String;
    final color = tone == 'urgent'
        ? Barako.warning
        : tone == 'watch'
        ? Barako.text
        : Barako.textSecondary;
    final utang = c['kind'] == 'utang';
    final debt = c['kind'] == 'debtdue';
    // Both owing directions land on the Utang tab, each on its own segment
    // when the host wires the richer jump, falling back to the plain tab
    // switch when it does not. An utang decision is money owed TO the user;
    // a debtdue decision is the user's own debt, which used to be an inert
    // card here.
    final fallback = onSwitchTab != null
        ? () => onSwitchTab!(Destination.utang)
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: utang
            ? (onOpenReceivables ?? fallback)
            : debt
            ? (onOpenPayables ?? fallback)
            : null,
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
                    child: Text(
                      c['title'] as String,
                      style: AppText.body.w7.tint(color),
                    ),
                  ),
                  if (utang && onSwitchTab != null)
                    Icon(
                      salapifyIcon('forward'),
                      color: Barako.faint,
                      size: 18,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                c['message'] as String,
                style: AppText.small.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Steady Pay: the weekly salary you pay yourself from swing income,
  /// planned on the three leanest of the last six full income months. Every
  /// figure comes from the tested steadypay engine; accepting or adjusting
  /// writes the one founder-approved settings key through the store.
  Widget _steadyPayCard(
    BuildContext context,
    Map<String, dynamic> data,
    DateTime ref,
    double? accepted,
    steadypay.SteadyPay suggestion,
  ) {
    Future<void> askAmount() async {
      // Prefill the EXACT stored amount when one exists (rounding here would
      // let a no-edit Save silently change a decimal draw); only a fresh
      // suggestion gets rounded to whole pesos.
      final prefill = accepted != null
          ? (accepted == accepted.roundToDouble()
                ? accepted.round().toString()
                : accepted.toString())
          : (suggestion.weeklyDraw ?? 0).round().toString();
      final controller = TextEditingController(text: prefill);
      final messenger = ScaffoldMessenger.of(context);
      final action = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Barako.background,
          title: Text('Your weekly pay', style: AppText.subtitle.w8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                suggestion.weeklyDraw == null
                    ? 'The amount you pay yourself each week, whatever the '
                          'month brings.'
                    : 'Suggested: ${formatMoney(suggestion.weeklyDraw!.roundToDouble())} a week, planned on your lean months.',
                style: AppText.small,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                style: TextStyle(color: Barako.text),
                decoration: InputDecoration(
                  prefixText: '$baseCurrencySymbol ',
                  prefixStyle: TextStyle(color: Barako.text),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Barako.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Barako.primary),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (accepted != null)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('stop'),
                child: Text(
                  'Stop Steady Pay',
                  style: TextStyle(color: Barako.muted),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text('Cancel', style: TextStyle(color: Barako.muted)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop('save'),
              style: FilledButton.styleFrom(
                backgroundColor: Barako.primary,
                foregroundColor: Barako.onPrimary,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      try {
        if (action == 'stop') {
          await store.clearSteadyPay();
        } else if (action == 'save') {
          // Commas and spaces are stripped like every other amount field in
          // the app; the dialog itself displays "₱2,769", so typing exactly
          // that must work.
          final amount = double.tryParse(
            controller.text.replaceAll(RegExp(r'[, ]'), ''),
          );
          if (amount == null || !amount.isFinite || amount <= 0) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Enter an amount above zero, nothing saved.'),
              ),
            );
          } else {
            await store.setSteadyPay(amount);
          }
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save that, nothing changed. $e')),
        );
      }
    }

    final runway = suggestion.runwayMonths;
    final runwayLine = runway == null
        ? null
        : 'Your cash covers about ${runway.toStringAsFixed(1)} lean months.';

    Widget body;
    if (accepted == null && suggestion.weeklyDraw == null) {
      // Building state: income exists, but not yet the three full months the
      // lean-month math needs. Honest progress, no button, no nagging. The
      // fraction only shows while it is true: junk-data guard paths can null
      // the suggestion with three or more active months, and a first-month
      // user has zero full months, so both get plain words instead of an
      // absurd "6 of 3".
      final n = suggestion.activeMonths;
      final progress = n == 0
          ? 'Your first month is in progress.'
          : n < 3
          ? '$n of 3 so far.'
          : 'Almost there.';
      body = Text(
        'Steady Pay suggests a weekly salary you pay yourself, planned on '
        'your lean months. It needs about three full months of logged '
        'income to be honest: $progress Keep logging and it appears here.',
        style: AppText.small.copyWith(height: 1.4),
      );
    } else if (accepted == null) {
      final weekly = suggestion.weeklyDraw!;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay yourself ${formatMoney(weekly.roundToDouble())} a week',
            style: AppText.bodyLg.w7,
          ),
          const SizedBox(height: 4),
          Text(
            'Planned on your three leanest months out of the last six '
            '(about ${formatMoneyAbout(suggestion.leanBaseline!)} a month), so a good month '
            'becomes runway, not lifestyle.'
            '${runwayLine == null ? '' : ' $runwayLine'}',
            style: AppText.small.copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: askAmount,
            style: OutlinedButton.styleFrom(
              foregroundColor: Barako.primaryText,
              side: BorderSide(color: Barako.border),
            ),
            child: const Text(
              'Set my weekly pay',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    } else {
      final week = steadypay.steadyPayWeek(data, ref, accepted);
      final over = week.remaining < 0;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${formatMoney(accepted)} a week', style: AppText.bodyLg.w7),
          const SizedBox(height: 4),
          Text(
            over
                ? 'Drawn ${formatMoney(week.spent)} this week, '
                      '${formatMoney(-week.remaining)} past your pay. It '
                      'happens; the runway absorbs it, and next week starts '
                      'fresh.'
                : 'Drawn ${formatMoney(week.spent)} of your pay this week, '
                      '${formatMoney(week.remaining)} still yours to spend.'
                      '${runwayLine == null ? '' : ' $runwayLine'}',
            style: AppText.small.copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: askAmount,
            style: OutlinedButton.styleFrom(
              foregroundColor: Barako.primaryText,
              side: BorderSide(color: Barako.border),
            ),
            child: const Text(
              'Adjust',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('STEADY PAY · YOUR OWN SALARY'),
            const SizedBox(height: 8),
            body,
          ],
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
            Kicker('SAFE TO SPEND UNTIL PAYDAY'),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(available > 0 ? available : 0),
                maxLines: 1,
                style: AppText.amountLg.w7.tint(
                  tight ? Barako.warning : Barako.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tight
                  ? 'Bills before payday already use up your spendable cash. Hold off on extras until payday.'
                  // prettyDay, not the raw stored value. This printed
                  // "(payday 2026-07-30)" for its whole life: a machine date
                  // in a sentence, on a screen whose entire job is reading
                  // plainly, while every other screen said "Jul 30". Nobody
                  // saw it because every render of this tab used an empty
                  // store and this card never had a payday to print.
                  // "for the next 1 day" was the other half of this sentence
                  // reading like a machine, and on the last day of a cycle
                  // "a day" describes nothing anyway: there is one day left
                  // and the rate and the amount are the same number.
                  : (daysLeft == 1
                            ? 'About ${formatMoneyAbout(perDay)} to reach tomorrow, your ${prettyDay((sts['payday'] ?? '').toString())} payday. '
                            : 'About ${formatMoneyAbout(perDay)} a day for the next $daysLeft days (payday ${prettyDay((sts['payday'] ?? '').toString())}). ') +
                        (billCount > 0
                            ? '${formatMoney(committed)} is set aside for $billCount ${billCount == 1 ? 'bill' : 'bills'} landing first.'
                            : 'No bills land before then.'),
              style: AppText.small
                  .tint(tight ? Barako.warning : Barako.muted)
                  .copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  /// The "Spoken-For Sweldo" card: how much of a typical month's income is
  /// already committed to bills and debt minimums before anything else. Every
  /// number comes from commitmentload.commitmentLoad, which composes the golden
  /// locked monthlySeries, so nothing here is invented. It is the gate that
  /// helps a user weigh a new subscription or BNPL against the room it eats.
  Widget _spokenForCard(Map<String, dynamic> load) {
    final committed = load['monthlyCommitted'] as double;
    final income = load['typicalIncome'] as double;
    final hasIncomeBase = load['hasIncomeBase'] as bool;
    final incomeMonths = load['incomeMonths'] as int;
    final share = load['committedShare'] as double?;
    final free = load['free'] as double?;
    final rc = load['recurringCount'] as int;
    final mc = load['minimumsCount'] as int;
    final minimumUnfilled = load['minimumUnfilled'] as bool;
    // The two committed parts, kept apart so the bar can show bills and debt
    // minimums as separate segments instead of one lump.
    final recurringTotal = load['recurringTotal'] as double;
    final minimumsTotal = load['minimumsTotal'] as double;

    // The only way the card is applicable with nothing committed is an
    // interest-bearing debt with no minimum saved. Show just the nudge; a "0%"
    // here would misread as "nothing committed" when it is really unknown.
    if (committed <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker('SPOKEN FOR EACH MONTH'),
              const SizedBox(height: 8),
              Text(
                'A debt has no minimum saved, so I can not size your monthly commitments yet. Add its minimum and this shows how spoken-for your salary is.',
                style: AppText.small.copyWith(height: 1.45),
              ),
            ],
          ),
        ),
      );
    }

    // "from 3 bills and 2 minimums", built so it never says "0 bills".
    final parts = <String>[
      if (rc > 0) '$rc ${rc == 1 ? 'bill' : 'bills'}',
      if (mc > 0) '$mc ${mc == 1 ? 'minimum' : 'minimums'}',
    ];
    final fromClause = parts.isEmpty ? '' : ', from ${parts.join(' and ')}';

    // A junk backup can overflow the committed sum or the income median to a
    // non-finite value; round() throws on those. When any input is not finite
    // we skip the percent and show the guarded peso total instead, the way
    // _wholePeso and formatMoney stay alive on absurd data.
    final finite =
        committed.isFinite &&
        income.isFinite &&
        (share == null || share.isFinite);
    final showShare = hasIncomeBase && finite && share != null;
    final over = showShare && share > 1;

    // Cap an absurd but finite percent so a junk backup never spills a 19-digit
    // number; round() is only ever called on a finite product.
    String pctText(double s) {
      final p = s * 100;
      if (!p.isFinite) return '999+%';
      final r = p.round();
      return r > 999 ? '999+%' : '$r%';
    }

    // The hero: the committed SHARE when we can size it against income, else
    // the committed peso total.
    final hero = showShare ? pctText(share) : _wholePeso(committed);
    final heroColor = over ? Barako.warningStrong : Barako.primaryText;

    // No income logged yet, so the peso total needs a sentence to mean
    // anything; that one path stays as words.
    final noShareSupport = hasIncomeBase
        ? 'About ${_wholePeso(committed)} goes to bills and minimums each month$fromClause.'
        : 'About ${_wholePeso(committed)} goes to bills and minimums each month$fromClause. Log your salary for a few months to see this as a share of your income.';

    // The concise readout that replaces the old paragraph: three amounts in the
    // same left to right order as the bar segments.
    final barCaption = over
        ? 'Bills and minimums come to ${_wholePeso(committed)}, more than your typical ${_wholePeso(income)} salary. Trim a bill or clear a debt to make room.'
        : '${_wholePeso(recurringTotal)} bills, ${_wholePeso(minimumsTotal)} minimums, ${_wholePeso(free ?? 0)} free.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('SPOKEN FOR EACH MONTH'),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                hero,
                maxLines: 1,
                style: AppText.amountLg.w7.tint(heroColor),
              ),
            ),
            if (showShare) ...[
              const SizedBox(height: 12),
              Semantics(
                label: 'Committed ${pctText(share)} of your income',
                child: _spokenForBar(
                  recurringTotal,
                  minimumsTotal,
                  free ?? 0,
                  over,
                ),
              ),
              const SizedBox(height: 8),
              Text(barCaption, style: AppText.small.copyWith(height: 1.4)),
            ] else ...[
              const SizedBox(height: 10),
              Text(noShareSupport, style: AppText.small.copyWith(height: 1.45)),
            ],
            if (showShare && incomeMonths < 6) ...[
              const SizedBox(height: 6),
              Text(
                'This uses months with income. On a lean month, more is spoken for.',
                style: AppText.caption.copyWith(height: 1.4),
              ),
            ],
            if (minimumUnfilled) ...[
              const SizedBox(height: 6),
              Text(
                'A debt has no minimum saved, so this may understate. Add its minimum for a truer picture.',
                style: AppText.caption.copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The committed salary as one stacked bar: bills, then debt minimums, then
  /// the free remainder. Widths come straight from commitmentLoad, so the
  /// picture reads the same numbers the caption names. An over-committed month
  /// has no free segment and fills with bills and minimums. Colours read live
  /// (never const) so a theme switch repaints them.
  Widget _spokenForBar(double bills, double minimums, double free, bool over) {
    int flex(double v) => v <= 0 || !v.isFinite ? 0 : (v * 100).round();
    final bf = flex(bills);
    final mf = flex(minimums);
    final ff = over ? 0 : flex(free);
    if (bf + mf + ff == 0) return const SizedBox(height: 10);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            if (bf > 0)
              Expanded(
                flex: bf,
                child: ColoredBox(color: Barako.primary),
              ),
            if (mf > 0)
              Expanded(
                flex: mf,
                child: ColoredBox(color: Barako.warning),
              ),
            if (ff > 0)
              Expanded(
                flex: ff,
                child: ColoredBox(color: Barako.border),
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
    Map<String, dynamic> plan,
    Map<String, dynamic>? focusGoal,
  ) {
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
    final haveCushion = buffer > 0
        ? ' You have about ${_wholePeso(buffer)} so far.'
        : '';
    // When an unrated debt was left out of the order, do not claim ALL debts
    // are handled; say "rated" so the copy never contradicts the note below.
    final rated = rateUnfilled ? 'rated ' : '';

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
            'About ${_wholePeso(starterGap)} more gets you to $desc, so the next surprise does not turn into debt.$haveCushion';
        break;
      case 'debt':
        activeIndex = 1;
        heroColor = Barako.warningStrong;
        final name = (topDebt?['name'] as String?) ?? 'your debt';
        final rate = (topDebt?['monthlyRate'] as double?) ?? 0;
        // Whole rates print plain; a fractional rate is capped at two decimals
        // with trailing zeros trimmed, so a junk 3.333333 never spills.
        final rateText = rate % 1 == 0
            ? rate.toInt().toString()
            : rate
                  .toStringAsFixed(2)
                  .replaceAll(RegExp(r'0+$'), '')
                  .replaceAll(RegExp(r'\.$'), '');
        title = 'Clear your costliest debt';
        support =
            'Your $name costs about $rateText% a month, more than any savings can earn back. Every ₱100 you put here is worth more than ₱100 anywhere else right now.';
        break;
      case 'fuller':
        activeIndex = 2;
        title = 'Grow your safety net';
        support =
            'Your ${rated}debts are handled. Next, build toward three months, about ${_wholePeso(fullTarget)}. That is what keeps a lost job or a hospital bill from undoing your progress. About ${_wholePeso(fullGap)} to go.';
        break;
      case 'goal':
        activeIndex = 3;
        final gnameRaw = focusGoal?['name'];
        final gname = (gnameRaw is String && gnameRaw.trim().isNotEmpty)
            ? gnameRaw.trim()
            : 'your goal';
        title = 'Now, chase your goal';
        support =
            'Your cushion and ${rateUnfilled ? 'rated debt' : 'high cost debt'} are handled. Your spare can now go to $gname. This is the fun part, you earned it.';
        break;
      default: // 'set'
        activeIndex = 4;
        title = 'You are in a good spot';
        support =
            'Your cushion and ${rated}debts are handled and no goal is waiting. Now your money can work for you, think long term saving or investing for your future self, and enjoy some of it guilt free. You earned it.';
    }

    final spareLine = crunch
        ? 'Your bills use up this pay cycle already, so treat this as a plan for after payday.'
        : 'This cycle you have about ${_wholePeso(spare)} free to move, if you can spare it.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('WHERE YOUR NEXT PESO SHOULD GO'),
            const SizedBox(height: 6),
            Text(title, style: AppText.title.w7.tint(heroColor)),
            const SizedBox(height: 4),
            Text(support, style: AppText.small.copyWith(height: 1.45)),
            const SizedBox(height: 14),
            _orderRail(activeIndex),
            const SizedBox(height: 12),
            Text(
              spareLine,
              style: AppText.caption
                  .tint(crunch ? Barako.warningStrong : Barako.muted)
                  .copyWith(height: 1.4),
            ),
            if (rateUnfilled) ...[
              const SizedBox(height: 6),
              // Informational, not a money warning, so it stays in the calm
              // muted tone (which also clears AA) instead of a third red line.
              Text(
                'A debt with no interest rate saved is left out of the order. Add its rate and I can place it properly.',
                style: AppText.caption.copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'An order based on the rates and balances you logged, not a promise. Your call always wins.',
              style: AppText.micro.w4.tint(Barako.faint).copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  /// The four tiers as a compact rail, so the user sees the whole order and
  /// where they stand in it, not just the current step. Steps before the
  /// active one read as done, the active one is filled, later ones wait.
  Widget _orderRail(int activeIndex) {
    // Single words only: a 4-across rail at 320dp with OS large-text scaling
    // would ellipsize a two-word label ("Bigger fund" to "Bigger...") mid-word.
    const labels = ['Cushion', 'Debt', 'Buffer', 'Goals'];
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
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.micro.copyWith(
                      fontSize: 10,
                      color: i == activeIndex
                          ? Barako.text
                          : i < activeIndex
                          ? Barako.muted
                          : Barako.faint,
                      fontWeight: i == activeIndex
                          ? TypeWeight.bold
                          : TypeWeight.medium,
                    ),
                  ),
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
    // "Money not spent" not "Savings rate": the part is fed by savingsRate,
    // which is income minus expenses, and debt payments are not expenses. So
    // it measures money not spent on day to day costs, not money saved. The
    // old label credited paying off a card as saving, which is not what the
    // number means.
    const partLabel = {
      'savings': 'Money not spent',
      'budget': 'Budget',
      'debt': 'Debt',
      'logging': 'Logging habit',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('MONEY HEALTH'),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$total',
                  style: AppText.title
                      .copyWith(fontSize: 34)
                      .w7
                      .tint(Barako.primary),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 6, left: 4),
                  child: Text('of 100', style: AppText.caption),
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
                      child: Text(
                        partLabel[key]!,
                        style: AppText.caption.tint(Barako.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: SalapifyProgressBar(
                        value: (parts[key] as double) / partMax[key]!,
                        size: ProgressBarSize.micro,
                        semanticsLabel: '${partLabel[key]} score',
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(parts[key] as double).toInt()}/${partMax[key]}',
                        textAlign: TextAlign.right,
                        style: AppText.micro.w4,
                      ),
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
            Kicker('LAST 6 MONTHS'),
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
                  Text(
                    l,
                    style: AppText.micro.copyWith(
                      fontSize: 10,
                      fontWeight: TypeWeight.regular,
                      color: Barako.faint,
                    ),
                  ),
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
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppText.caption.tint(Barako.textSecondary)),
    ],
  );

  Widget _categoriesCard(
    List<Map<String, dynamic>> cats,
    Map<String, dynamic> forecast,
  ) {
    final visible = cats.where((c) => (c['now'] as double) > 0).toList();
    var maxNow = 0.0;
    for (final c in visible) {
      if ((c['now'] as double) > maxNow) maxNow = c['now'] as double;
    }
    // Total spent this month, used to show each category's SHARE (34%) next to
    // its amount, so the bars read as "how much of my money went here", not
    // just rank. A share is a ratio of two figures the engine already gave us,
    // not new money math, and it is guarded against a zero total.
    final spentTotal = forecast['spent'] as double;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Kicker('WHERE YOUR MONEY WENT THIS MONTH'),
            const SizedBox(height: 4),
            Text(
              '${formatMoney(forecast['spent'] as double)} spent so far, on pace for ${formatMoney(forecast['projected'] as double)} by month end.',
              style: AppText.caption,
            ),
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
                          child: Text(
                            c['label'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.small.tint(Barako.text),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${spentTotal > 0 ? ((c['now'] as double) / spentTotal * 100).round() : 0}%',
                              style: AppText.micro.w4.tint(Barako.faint),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatMoney(c['now'] as double),
                              style: AppText.small.w6.tabular,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SalapifyProgressBar(
                      value: maxNow > 0 ? (c['now'] as double) / maxNow : 0,
                      size: ProgressBarSize.micro,
                      semanticsLabel: '${c['label']} spending',
                      color:
                          (c['expected'] as double) > 0 &&
                              (c['now'] as double) >
                                  (c['expected'] as double) * 1.2
                          ? Barako.warning
                          : Barako.primary,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              'Percent shows each category\'s share of your spending. Orange means it is running faster than usual this month.',
              style: AppText.micro.w4.tint(Barako.faint),
            ),
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
            Kicker('EMERGENCY RUNWAY'),
            const SizedBox(height: 6),
            Text(runwayLabel(months, capped), style: AppText.title),
            const SizedBox(height: 4),
            Text(
              months == null
                  ? 'After two full months of logged spending, this shows how long your accessible money would carry you.'
                  : 'Your accessible money (${formatMoney(runway['buffer'] as double)}) covers ${capped ? 'more than a year' : 'about ${runwayLabel(months, false)}'} of your typical ${formatMoney(runway['avgMonthlyExpense'] as double)} monthly spending.',
              style: AppText.small.tint(Barako.muted).copyWith(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtWhatIfCard extends StatefulWidget {
  final dynamic debts;
  final Map<String, dynamic> sts;
  final DateTime ref;
  const _DebtWhatIfCard({
    required this.debts,
    required this.sts,
    required this.ref,
  });

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
    return (name is String && name.trim().isNotEmpty)
        ? name.trim()
        : 'your debt';
  }

  // Debt types that always carry interest in real life. The store fills a
  // missing rate with 0, so a card or loan sitting at 0% almost always means
  // the user never entered the rate, not that it is genuinely free. An
  // informal utang at 0% is left alone.
  static const Set<String> _interestBearingTypes = {
    'credit card',
    'bnpl',
    'loan',
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
        ? 'Your bills use up your spendable cash until payday, so this is a what if for now. Even a small extra after payday makes a real dent.'
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (heroText.isNotEmpty) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  heroText,
                  maxLines: 1,
                  style: AppText.amountLg.w7.tint(Barako.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(supportText, style: AppText.small.copyWith(height: 1.4)),
            ] else
              Text(
                supportText,
                style: AppText.label.tint(supportColor).copyWith(height: 1.45),
              ),
            const SizedBox(height: 8),
            Text(
              grounding,
              style: AppText.caption
                  .tint(crunch ? Barako.warning : Barako.muted)
                  .copyWith(height: 1.4),
            ),
            if (unfilled) ...[
              const SizedBox(height: 6),
              Text(
                'One or more debts have no interest rate saved, so this may understate the real cost. Add the rate for a truer picture.',
                style: AppText.caption
                    .tint(Barako.warning)
                    .copyWith(height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'A projection from your logged balances, assuming you keep it up and add no new charges. A guide, not a promise.',
              style: AppText.micro.w4.tint(Barako.faint).copyWith(height: 1.35),
            ),
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
  const _GoalWhatIfCard({
    required this.goal,
    required this.sts,
    required this.ref,
  });

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
    final forecast = analytics.goalForecast(remaining, _weekly, widget.ref);
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
            'Your ${_monthYear(targetDate)} target has already passed. That is okay, a fresh date keeps the goal alive.';
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
        ? 'Your bills use up your spendable cash until payday, so treat this as a plan for after payday.'
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (heroText.isNotEmpty) ...[
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  heroText,
                  maxLines: 1,
                  style: AppText.amountLg.w7.tint(Barako.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text(supportText, style: AppText.small.copyWith(height: 1.4)),
            ] else
              Text(
                supportText,
                style: AppText.label.tint(supportColor).copyWith(height: 1.45),
              ),
            if (targetText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                targetText,
                style: AppText.small
                    .copyWith(
                      height: 1.4,
                      // Only the reward and the warning carry weight; the
                      // neutral "aim for X a week" reads as part of support.
                      fontWeight: targetTone == 'plain'
                          ? TypeWeight.regular
                          : TypeWeight.medium,
                    )
                    .tint(
                      targetTone == 'behind'
                          ? Barako.warning
                          : targetTone == 'ontime'
                          ? Barako.primary
                          : Barako.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              grounding,
              style: AppText.caption
                  .tint(crunch ? Barako.warning : Barako.muted)
                  .copyWith(height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'A projection from your target and what you set aside, assuming you keep it up. A guide, not a promise.',
              style: AppText.micro.w4.tint(Barako.faint).copyWith(height: 1.35),
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

  /// A short peso label for the y axis, so 32000 reads as "P32k" and the
  /// height of the chart finally means a number. Display only, not money math.
  String _compact(double v) {
    if (!v.isFinite || v <= 0) return '₱0';
    if (v >= 1000) {
      final k = v / 1000;
      return '₱${k >= 10 ? k.round() : k.toStringAsFixed(1)}k';
    }
    return '₱${v.round()}';
  }

  void _label(Canvas canvas, String text, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Barako.faint,
          fontSize: 9,
          fontFamily: Barako.bodyFont,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

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
    // Fills first (area under each line), then the crisp lines on top, so the
    // shape reads as magnitude while the two lines stay legible. Spending is
    // drawn last, so a month where spending rose above income shows more red.
    _drawSeries(canvas, size, income, max, Barako.primary, fill: true);
    _drawSeries(canvas, size, expenses, max, Barako.warning, fill: true);
    _drawSeries(canvas, size, income, max, Barako.primary);
    _drawSeries(canvas, size, expenses, max, Barako.warning);
    // Y axis magnitude: the top grid line is the shared max, the bottom is
    // zero. Now the chart's height answers "how much".
    if (max.isFinite && max > 0) {
      _label(canvas, _compact(max), const Offset(2, 1));
      _label(canvas, '₱0', Offset(2, size.height - 11));
    }
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    List<double> values,
    double max,
    Color color, {
    bool fill = false,
  }) {
    final pts = chartgeom.linePointsScaled(
      values,
      max,
      size.width,
      size.height,
      8,
    );
    if (pts.isEmpty) return;
    if (fill) {
      final area = Path()..moveTo(pts.first['x']!, size.height);
      area.lineTo(pts.first['x']!, pts.first['y']!);
      for (final p in pts.skip(1)) {
        area.lineTo(p['x']!, p['y']!);
      }
      area
        ..lineTo(pts.last['x']!, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
      return;
    }
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
    canvas.drawCircle(Offset(pts.last['x']!, pts.last['y']!), 3.5, dot);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.income != income || old.expenses != expenses;
}
