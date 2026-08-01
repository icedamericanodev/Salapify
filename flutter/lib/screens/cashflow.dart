// The Sweldo Timeline screen (the Cash Flow screen, grown up): a rolling
// running-balance projection on the sweldo cycle. The free view runs to the
// end of the month or to your next payday; Pro extends the horizon to 30, 60,
// or 90 days across month boundaries and overlays saved what-if scenarios.
// Every peso comes from money/timeline.dart, never invented in the widget.
// The conservative line is fact-shaped (recurring, minimums, scenarios); the
// shaded band is an honest ESTIMATE of day-to-day spending and is labeled so.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/schedule.dart' show hasExplicitPaydaySchedule;
import '../money/timeline.dart';
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

class CashFlowScreen extends StatefulWidget {
  final SalapifyStore store;

  /// The reference "today". Defaults to now; tests inject a fixed date so the
  /// projected window is stable regardless of when the suite runs.
  final DateTime? now;
  const CashFlowScreen({super.key, required this.store, this.now});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  /// 'month' (free, the original window), 'payday' (free), '30', '60', '90'
  /// (the Pro rolling horizons).
  String _horizon = 'month';

  SalapifyStore get store => widget.store;

  bool get _pro => (store.data['settings'] as Map?)?['pro'] == true;

  int _windowDays(Map<String, dynamic> data, DateTime ref) {
    final today = DateTime(ref.year, ref.month, ref.day);
    switch (_horizon) {
      case 'payday':
        return freeHorizonDays(data, ref);
      case '30':
        return 30;
      case '60':
        return 60;
      case '90':
        return 90;
      default:
        return DateTime(
          today.year,
          today.month + 1,
          0,
        ).difference(today).inDays;
    }
  }

  String get _windowSubtitle {
    switch (_horizon) {
      case 'payday':
        return 'From today to your next payday';
      case '30':
        return 'The next 30 days';
      case '60':
        return 'The next 60 days';
      case '90':
        return 'The next 90 days';
      default:
        return 'From today to the end of the month';
    }
  }

  String get _endLabel {
    switch (_horizon) {
      case 'payday':
        return 'AT PAYDAY';
      case '30':
        return 'IN 30 DAYS';
      case '60':
        return 'IN 60 DAYS';
      case '90':
        return 'IN 90 DAYS';
      default:
        return 'END OF MONTH';
    }
  }

  /// The Pro gate, with a working door: the snackbar's action unlocks Pro
  /// right here (free during early access, same self-served unlock the
  /// recurring screen offers) and then applies what the user was trying to
  /// do. A gate that points at a Menu row that does not exist teaches the
  /// user the app is broken, not that Pro exists.
  void _proNudge(String message, VoidCallback afterUnlock) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        // Says its persist behavior out loud, per snackbar_persist_test: this
        // nudge must NOT sit on screen forever; the gate reappears on the
        // next tap, so timing out loses nothing. Six seconds is enough to
        // read the sentence and reach the action.
        persist: false,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Unlock free',
          onPressed: () async {
            await store.setPro(true);
            if (mounted) {
              setState(() {});
              afterUnlock();
            }
          },
        ),
      ),
    );
  }

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
            final ref = widget.now ?? DateTime.now();
            // A Pro horizon must not outlive Pro: toggle Pro off elsewhere
            // with this screen on the stack and the 90 day view would keep
            // rendering for a free user until reopen.
            if (!_pro && const {'30', '60', '90'}.contains(_horizon)) {
              _horizon = 'month';
            }
            final scenarios = store.timelineScenarios;
            // Scenarios overlay the chart only for Pro (categories precedent:
            // a stored Pro thing on a non-Pro store is inert, not active).
            final active = [
              for (final s in scenarios)
                if (_pro && s['on'] != false) s,
            ];
            final tl = sweldoTimeline(
              data,
              ref,
              horizonDays: _windowDays(data, ref),
              scenarios: active,
            );
            final days = (tl['days'] as List).cast<Map<String, dynamic>>();
            final start = (tl['startBalance'] as num).toDouble();
            final end = (tl['endBalance'] as num).toDouble();
            final lowest = tl['lowest'] as Map;
            final lowBal = (lowest['balance'] as num).toDouble();
            final lowDate = lowest['date'].toString();
            final anyNegative = tl['anyNegative'] == true;
            final band = (tl['band'] as Map).cast<String, dynamic>();
            final bandRate = (band['dailyRate'] as num).toDouble();
            final paydays = (tl['paydays'] as List).cast<String>();
            final assumptions = (tl['assumptions'] as Map)
                .cast<String, dynamic>();
            final hasSchedule = hasExplicitPaydaySchedule(data);

            // Events across the window, in date order, for the list below.
            final events = <Map<String, dynamic>>[];
            for (final d in days) {
              for (final e in (d['events'] as List)) {
                events.add({
                  ...(e as Map).cast<String, dynamic>(),
                  'date': d['date'],
                });
              }
            }
            final noEvents =
                events.isEmpty &&
                (assumptions['recurringCount'] as int) == 0 &&
                (assumptions['debtCount'] as int) == 0;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _decisionCard(
                  start,
                  end,
                  lowBal,
                  lowDate,
                  tl['firstNegativeDate'] as String?,
                  anyNegative,
                  noEvents,
                ),
                const SizedBox(height: 14),
                if (noEvents)
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
                      'Add your salary and bills',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                else ...[
                  _horizonChips(hasSchedule),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PROJECTED BALANCE', style: Barako.kickerStyle),
                          const SizedBox(height: 4),
                          Text(
                            _windowSubtitle,
                            style: TextStyle(color: Barako.muted, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          _BalanceChart(
                            days: days,
                            anyNegative: anyNegative,
                            lowDate: lowDate,
                            runOutDate:
                                (tl['firstNegativeDate'] as String?) ?? lowDate,
                            showBand: bandRate > 0,
                            paydays: paydays,
                          ),
                          const SizedBox(height: 10),
                          _chartFootnotes(bandRate, paydays, assumptions),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _scenarioCard(
                    scenarios,
                    days.isNotEmpty ? days.last['date'].toString() : '',
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

  Widget _horizonChips(bool hasSchedule) {
    final choices = <(String, String, bool)>[
      ('month', 'This month', false),
      if (hasSchedule) ('payday', 'To payday', false),
      ('30', '30 days', true),
      ('60', '60 days', true),
      ('90', '90 days', true),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (key, label, needsPro) in choices) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: _horizon == key,
                onSelected: (_) {
                  if (needsPro && !_pro) {
                    // No haptic here: a buzz says "that worked" and the gate
                    // is about to say it did not.
                    _proNudge(
                      'The longer view is part of Pro, free during early '
                      'access.',
                      () => setState(() => _horizon = key),
                    );
                    return;
                  }
                  HapticFeedback.selectionClick();
                  setState(() => _horizon = key);
                },
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (needsPro && !_pro) ...[
                      Icon(Icons.lock_outline, size: 13, color: Barako.faint),
                      const SizedBox(width: 4),
                    ],
                    Text(label),
                  ],
                ),
                labelStyle: TextStyle(
                  color: _horizon == key ? Barako.onPrimary : Barako.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                selectedColor: Barako.primary,
                backgroundColor: Barako.card,
                side: BorderSide(color: Barako.border),
                showCheckmark: false,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartFootnotes(
    double bandRate,
    List<String> paydays,
    Map<String, dynamic> assumptions,
  ) {
    final r = assumptions['recurringCount'] as int;
    final d = assumptions['debtCount'] as int;
    final counts = [
      if (r > 0) '$r recurring item${r == 1 ? '' : 's'}',
      if (d > 0) '$d debt schedule${d == 1 ? '' : 's'}',
    ].join(' and ');
    final lines = <String>[
      if (bandRate > 0)
        'Shaded: after your usual day to day spending, an estimate from '
            'your last 4 weeks.',
      if (paydays.isNotEmpty) 'Hollow dots on the line mark your paydays.',
      'Counts $counts. Money owed to you is never counted as income.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              l,
              style: TextStyle(color: Barako.faint, fontSize: 11, height: 1.35),
            ),
          ),
      ],
    );
  }

  // The what-if overlay: saved scenarios, each toggleable, all Pro. The line
  // only changes here, never the real money; that sentence is on the card.
  Widget _scenarioCard(List<Map<String, dynamic>> scenarios, String endIso) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHAT IF', style: Barako.kickerStyle),
            const SizedBox(height: 4),
            Text(
              'Overlay a plan on the projection. Only the line changes, '
              'never your real money.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < scenarios.length; i++) ...[
              if (i > 0) Divider(height: 1, color: Barako.border),
              _scenarioRow(scenarios, i, endIso),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                if (!_pro) {
                  _proNudge(
                    'What ifs are part of Pro, free during early access.',
                    () => _editScenario(null),
                  );
                  return;
                }
                _editScenario(null);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Barako.primaryText,
                side: BorderSide(color: Barako.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Add a what if',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scenarioSummary(Map<String, dynamic> s) {
    final amount = formatMoneyText(
      (s['amount'] is num ? s['amount'] as num : 0).toDouble(),
    );
    switch (s['kind']) {
      case 'purchase':
        return '$amount on ${_pretty((s['date'] ?? '').toString())}';
      case 'extraMonthly':
        return '$amount monthly on day ${s['dayOfMonth']}';
      case 'incomeChange':
        return '$amount more income monthly on day ${s['dayOfMonth']}';
      case 'cutSpending':
        final cut = formatMoneyText(
          (s['amountPerMonth'] is num ? s['amountPerMonth'] as num : 0)
              .toDouble(),
        );
        return 'Cut $cut a month of day to day spending';
      default:
        return '';
    }
  }

  IconData _scenarioIcon(dynamic kind) {
    switch (kind) {
      case 'purchase':
        return Icons.shopping_bag_outlined;
      case 'extraMonthly':
        return Icons.trending_down;
      case 'incomeChange':
        return Icons.trending_up;
      case 'cutSpending':
        return Icons.content_cut;
      default:
        return Icons.help_outline;
    }
  }

  Widget _scenarioRow(
    List<Map<String, dynamic>> scenarios,
    int i,
    String endIso,
  ) {
    final s = scenarios[i];
    // The categories precedent: a stored Pro thing on a non-Pro store renders
    // INERT, never active. A saved scenario survives (it is the user's data)
    // but stops overlaying the chart, dims, and both of its actions route to
    // the unlock nudge instead of quietly working.
    final locked = !_pro;
    final on = !locked && s['on'] != false;
    final label = (s['label'] is String && (s['label'] as String).isNotEmpty)
        ? s['label'] as String
        : 'What if';
    // Deliberately NOT one MergeSemantics over the whole row: this row has
    // TWO actions (tap edits, the switch toggles) and merging them hands a
    // screen reader only one. The text half is one button node, the switch
    // announces its own label.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: locked
                  ? '$label, ${_scenarioSummary(s)}, part of Pro, double tap '
                        'to unlock'
                  : '$label, ${_scenarioSummary(s)}, double tap to edit',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: locked
                      ? () => _proNudge(
                          'What ifs are part of Pro, free during early '
                          'access.',
                          () {},
                        )
                      : () => _editScenario(i),
                  child: Row(
                    children: [
                      Icon(
                        _scenarioIcon(s['kind']),
                        size: 18,
                        color: locked ? Barako.faint : Barako.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: locked
                                          ? Barako.muted
                                          : Barako.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                // The explicit edit affordance: without it
                                // this row reads as a settings toggle (the
                                // Menu grammar) and tap-to-edit is never
                                // discovered.
                                Icon(
                                  locked
                                      ? Icons.lock_outline
                                      : Icons.edit_outlined,
                                  size: 14,
                                  color: Barako.faint,
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              // A purchase dated past the visible window
                              // contributes nothing to THIS view; say so
                              // instead of looking silently ignored.
                              (s['kind'] == 'purchase' &&
                                      s['date'] is String &&
                                      endIso.isNotEmpty &&
                                      (s['date'] as String).compareTo(endIso) >
                                          0)
                                  ? '${_scenarioSummary(s)} · after this view'
                                  : _scenarioSummary(s),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: locked ? Barako.faint : Barako.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: label,
            child: Switch(
              value: on,
              onChanged: locked
                  ? null
                  : (v) {
                      HapticFeedback.selectionClick();
                      final next = [...scenarios];
                      next[i] = {...s, 'on': v};
                      store.setTimelineScenarios(next);
                    },
              activeThumbColor: Barako.onPrimary,
              activeTrackColor: Barako.primary,
              inactiveThumbColor: Barako.faint,
              inactiveTrackColor: Barako.border,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editScenario(int? index) async {
    final scenarios = store.timelineScenarios;
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Barako.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ScenarioSheet(
        existing: index != null ? scenarios[index] : null,
        ref: widget.now ?? DateTime.now(),
      ),
    );
    if (result == null) return;
    // Re-read AFTER the await: the list can change while the sheet is open
    // (a restore finishing underneath, a second window), and applying the
    // edit against the pre-sheet copy would misapply it or throw RangeError.
    final fresh = store.timelineScenarios;
    final next = [...fresh];
    final removed = result['delete'] == true;
    final safeIndex = index != null && index < next.length ? index : null;
    if (removed) {
      if (safeIndex != null) next.removeAt(safeIndex);
    } else if (safeIndex != null) {
      next[safeIndex] = result;
    } else {
      next.add(result);
    }
    await store.setTimelineScenarios(next);
    if (removed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('What if removed. The line is back to plain facts.'),
        ),
      );
    }
  }

  Widget _decisionCard(
    double start,
    double end,
    double lowBal,
    String lowDate,
    String? firstNegativeDate,
    bool anyNegative,
    bool noEvents,
  ) {
    String head;
    String body;
    Color color;
    if (noEvents) {
      head = 'Set up your month';
      body =
          'Add your salary and bills as recurring items, and your cards and loans as debts. '
          'Then this shows the days your cash runs tight before your next payday.';
      color = Barako.muted;
    } else if (anyNegative) {
      head = 'Heads up, cash runs short';
      // The day cash FIRST crosses zero, never the lowest day: the lookahead
      // reminder names the crossing, and a push about one date opening an app
      // that shows another is how trust dies.
      final runOut = firstNegativeDate ?? lowDate;
      body =
          'At this pace your spendable cash is projected to run out around ${_pretty(runOut)}. '
          'Move a bill, hold a big buy, or set aside from your next payday so you do not get caught.';
      color = Barako.warningStrong;
    } else if (lowBal < start) {
      head = 'You are on track';
      body =
          'Your cash dips to ${formatMoneyText(lowBal)} around ${_pretty(lowDate)}, then recovers. '
          'Keep that day in mind before any big spend.';
      color = Barako.primaryText;
    } else {
      head = 'Steady stretch ahead';
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
                  // Only show LOWEST when the window actually dips below today;
                  // in a steady stretch it would just repeat the NOW figure.
                  if (lowBal < start) ...[
                    _figure(
                      'LOWEST',
                      formatMoneyText(lowBal),
                      anyNegative ? Barako.warningStrong : Barako.text,
                    ),
                    Container(width: 1, height: 30, color: Barako.border),
                  ],
                  _figure(_endLabel, formatMoneyText(end), Barako.primaryText),
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
              'Every salary in, every bill and due out',
              style: TextStyle(color: Barako.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // A short free window (To payday a few days out) can hold zero
            // events while recurring items exist; a kicker over nothing reads
            // as a bug, so say what the emptiness means.
            if (events.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Nothing due in this window. A longer view will have more.',
                  style: TextStyle(color: Barako.muted, fontSize: 12.5),
                ),
              ),
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
    final kind = e['kind']?.toString() ?? '';
    final isIn = kind == 'income' || kind == 'scenarioIn';
    final isScenario = kind == 'scenarioIn' || kind == 'scenarioOut';
    final amount = (e['amount'] as num).toDouble();
    final balance = (e['balanceAfter'] as num?)?.toDouble() ?? 0;
    final color = isScenario
        ? Barako.primaryText
        : (isIn ? Barako.primaryText : Barako.warningStrong);
    final label = e['label']?.toString() ?? '';
    final dateStr = _pretty(e['date'].toString());
    return Semantics(
      label:
          '$label, $dateStr, ${isIn ? 'in' : 'out'} ${formatMoneyText(amount)}, '
          '${isScenario ? 'what if, ' : ''}balance ${formatMoneyText(balance)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(
                isScenario
                    ? Icons.auto_awesome_outlined
                    : (isIn ? Icons.south_west : Icons.north_east),
                size: 18,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isScenario ? '$label (what if)' : label,
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
                '${isIn ? '+' : '-'}${formatMoneyText(amount)}',
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

// The add-or-edit sheet for one what-if scenario. Returns the scenario map on
// save, {'delete': true} on delete, null on dismiss. Pure UI: the caller owns
// persistence.
class _ScenarioSheet extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final DateTime ref;
  const _ScenarioSheet({this.existing, required this.ref});

  @override
  State<_ScenarioSheet> createState() => _ScenarioSheetState();
}

class _ScenarioSheetState extends State<_ScenarioSheet> {
  late String kind;
  late final TextEditingController label;
  late final TextEditingController amount;
  late final TextEditingController day;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    // Backups preserve settings.timelineScenarios verbatim, so a restored
    // scenario can carry ANY shape; `is` checks, never casts, or a junk
    // backup crashes the sheet. Unknown kinds also fall back to purchase so
    // firstWhere below can never miss.
    final rawKind = e?['kind'];
    kind = rawKind is String && _kinds.any((k) => k.$1 == rawKind)
        ? rawKind
        : 'purchase';
    final rawLabel = e?['label'];
    label = TextEditingController(text: rawLabel is String ? rawLabel : '');
    final amt = e?[kind == 'cutSpending' ? 'amountPerMonth' : 'amount'];
    amount = TextEditingController(
      text: amt is num && amt > 0 ? amt.toStringAsFixed(0) : '',
    );
    day = TextEditingController(
      text: e?['dayOfMonth'] is num
          ? '${(e!['dayOfMonth'] as num).toInt()}'
          : '',
    );
    final parsed = e?['date'] is String
        ? DateTime.tryParse(e!['date'] as String)
        : null;
    date =
        parsed ??
        DateTime(widget.ref.year, widget.ref.month, widget.ref.day + 7);
  }

  @override
  void dispose() {
    label.dispose();
    amount.dispose();
    day.dispose();
    super.dispose();
  }

  static const _kinds = <(String, String)>[
    ('purchase', 'A big buy'),
    ('extraMonthly', 'Extra monthly payment'),
    ('incomeChange', 'More income'),
    ('cutSpending', 'Spend less'),
  ];

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _save() {
    final amt = double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
    // isFinite matters: double.tryParse accepts 'Infinity' and '1e999', which
    // pass amt > 0, then jsonEncode throws in the store write AFTER the sheet
    // already closed showing success, so the scenario silently never exists.
    // The 100 million cap keeps a fat-fingered paste from drawing an absurd
    // chart; nobody is what-iffing a bigger peso figure in this app.
    if (!(amt > 0) || !amt.isFinite || amt > 100000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount above zero, up to 100 million.'),
        ),
      );
      return;
    }
    final name = label.text.trim();
    final out = <String, dynamic>{
      'kind': kind,
      'label': name.isEmpty ? _kinds.firstWhere((k) => k.$1 == kind).$2 : name,
      'on': widget.existing?['on'] != false,
    };
    if (kind == 'purchase') {
      out['amount'] = amt;
      out['date'] = _iso(date);
    } else if (kind == 'cutSpending') {
      out['amountPerMonth'] = amt;
    } else {
      final d = int.tryParse(day.text) ?? 0;
      if (d < 1 || d > 31) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a day of the month, 1 to 31.')),
        );
        return;
      }
      out['amount'] = amt;
      out['dayOfMonth'] = d;
    }
    Navigator.of(context).pop(out);
  }

  @override
  Widget build(BuildContext context) {
    final needsDay = kind == 'extraMonthly' || kind == 'incomeChange';
    final amountLabel = kind == 'cutSpending'
        ? 'Amount less per month'
        : 'Amount';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      // Scrollable, because at large system text the kind chips wrap to
      // several rows and the keyboard takes the bottom half; a bare Column
      // would overflow on exactly the phones the readability sweep protects.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Barako.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.existing == null ? 'Add a what if' : 'Edit what if',
              style: TextStyle(
                color: Barako.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (k, name) in _kinds)
                  ChoiceChip(
                    selected: kind == k,
                    onSelected: (_) => setState(() => kind = k),
                    label: Text(name),
                    labelStyle: TextStyle(
                      color: kind == k ? Barako.onPrimary : Barako.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.card,
                    side: BorderSide(color: Barako.border),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: label,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'Name (optional)',
                counterText: '',
                labelStyle: TextStyle(color: Barako.muted),
              ),
              style: TextStyle(color: Barako.text),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: amountLabel,
                labelStyle: TextStyle(color: Barako.muted),
              ),
              style: TextStyle(color: Barako.text),
            ),
            if (needsDay) ...[
              const SizedBox(height: 10),
              TextField(
                controller: day,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Day of the month (1 to 31)',
                  labelStyle: TextStyle(color: Barako.muted),
                ),
                style: TextStyle(color: Barako.text),
              ),
            ],
            if (kind == 'purchase') ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    // A stored date can be in the past by the time it is edited
                    // (saved last week, opened this week); an initialDate before
                    // firstDate asserts inside the picker.
                    initialDate: date.isBefore(widget.ref) ? widget.ref : date,
                    firstDate: widget.ref,
                    lastDate: DateTime(
                      widget.ref.year,
                      widget.ref.month,
                      widget.ref.day + 90,
                    ),
                  );
                  if (picked != null) setState(() => date = picked);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Barako.text,
                  side: BorderSide(color: Barako.border),
                ),
                icon: const Icon(Icons.event, size: 18),
                label: Text('On ${_pretty(_iso(date))}'),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop({'delete': true}),
                    child: Text(
                      'Remove',
                      style: TextStyle(
                        color: Barako.warningStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Cancel', style: TextStyle(color: Barako.muted)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// The running balance line across the window, with an area fill, the shaded
// variable-spend band when one exists, payday dots, the zero line when cash is
// projected to run out, and the lowest day marked. Canvas is the right tool
// for a curve; the numbers all come from the engine.
class _BalanceChart extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final bool anyNegative;
  final String lowDate;

  /// The day cash first crosses zero (falls back to the lowest day), the
  /// same date the decision card and the lookahead reminder name.
  final String runOutDate;
  final bool showBand;
  final List<String> paydays;
  const _BalanceChart({
    required this.days,
    required this.anyNegative,
    required this.lowDate,
    required this.runOutDate,
    required this.showBand,
    required this.paydays,
  });

  @override
  Widget build(BuildContext context) {
    final first = days.isNotEmpty ? days.first['date'].toString() : '';
    final last = days.isNotEmpty ? days.last['date'].toString() : '';
    return Semantics(
      label: anyNegative
          ? 'Projected balance chart. Cash runs out around ${_pretty(runOutDate)}.'
          : 'Projected balance from ${_pretty(first)} to ${_pretty(last)}, '
                'tightest around ${_pretty(lowDate)}.',
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
                  band: Barako.muted.withValues(alpha: 0.18),
                  warn: Barako.warningStrong,
                  label: Barako.muted,
                  grid: Barako.border,
                  payday: Barako.primaryText,
                  cardFill: Barako.card,
                  anyNegative: anyNegative,
                  lowDate: lowDate,
                  showBand: showBand,
                  paydays: paydays,
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
  final Color band;
  final Color warn;
  final Color grid;
  final Color label;
  final Color payday;
  final Color cardFill;
  final bool anyNegative;
  final String lowDate;
  final bool showBand;
  final List<String> paydays;
  _BalancePainter({
    required this.days,
    required this.line,
    required this.fill,
    required this.band,
    required this.warn,
    required this.grid,
    required this.label,
    required this.payday,
    required this.cardFill,
    required this.anyNegative,
    required this.lowDate,
    required this.showBand,
    required this.paydays,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final vals = [for (final d in days) (d['balance'] as num).toDouble()];
    final bandVals = [
      for (final d in days)
        ((d['bandLow'] as num?) ?? d['balance'] as num).toDouble(),
    ];
    var lo = vals.reduce((a, b) => a < b ? a : b);
    var hi = vals.reduce((a, b) => a > b ? a : b);
    if (showBand) {
      final bandLo = bandVals.reduce((a, b) => a < b ? a : b);
      if (bandLo < lo) lo = bandLo;
    }
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

    // The estimate band: the region between the conservative line and the
    // line after typical day to day spending. Drawn FIRST so the real line
    // stays crisp on top; a soft fill, deliberately not the accent color, so
    // an estimate never reads as a fact. One quadrilateral per day segment:
    // a single polygon around both polylines self-intersects wherever the
    // line spikes (a payday) and the winding paints stray boxes; per-segment
    // quads cannot.
    if (showBand) {
      final bp = Paint()..color = band;
      for (var i = 1; i < vals.length; i++) {
        final quad = Path()
          ..moveTo(x(i - 1), y(vals[i - 1]))
          ..lineTo(x(i), y(vals[i]))
          ..lineTo(x(i), y(bandVals[i]))
          ..lineTo(x(i - 1), y(bandVals[i - 1]))
          ..close();
        canvas.drawPath(quad, bp);
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

    // Payday dots: HOLLOW (card fill, line-colored ring). primaryText equals
    // primary across all sixteen palettes, so a solid dot in either color
    // disappears into the line; a hole in the line reads in every palette
    // with no new contrast pair.
    for (var i = 0; i < days.length; i++) {
      if (days[i]['isPayday'] == true) {
        final p = Offset(x(i).clamp(3.0, size.width - 3.0), y(vals[i]));
        canvas.drawCircle(p, 3.0, Paint()..color = cardFill);
        canvas.drawCircle(
          p,
          3.0,
          Paint()
            ..color = payday
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }

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
        // The family is named explicitly: a raw TextPainter does not inherit
        // the theme, so without it this label silently fell back to Roboto on
        // the phone and to the all-boxes Ahem font in the render harness,
        // where it drew as two grey rectangles floating in the chart.
        style: TextStyle(
          color: label,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          fontFamily: Barako.bodyFont,
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
    // A card-colored backing so the day reads even when the label crosses the
    // dashed zero line or the band.
    canvas.drawRect(
      Rect.fromLTWH(lx - 2, ly - 1, tp.width + 4, tp.height + 2),
      Paint()..color = cardFill,
    );
    tp.paint(canvas, Offset(lx, ly));
  }

  @override
  bool shouldRepaint(covariant _BalancePainter old) =>
      old.days != days ||
      old.anyNegative != anyNegative ||
      old.showBand != showBand;
}
