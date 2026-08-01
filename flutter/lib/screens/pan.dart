// Ask Pan: the offline money assistant, adapted from mobile/app/pan.js on
// top of the golden-ported brain in money/pan/. Every answer is computed on
// the phone from the user's own data by deterministic resolvers; no
// network, no model, no invented numbers. The screen is a simple chat: a
// greeting with starter chips, user and Pan bubbles, a copyable utang
// reminder when Pan drafts one, and a button when Pan can open the right
// screen.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/pan/ask.dart';
import '../money/pan/normalize.dart' show extractAmount;
import '../money/pan/respond.dart' show planLine;
import '../money/pan_mood.dart';
import '../money/plan.dart';
import '../theme.dart';
import '../widgets/pan_mascot.dart';
import 'accounts.dart';
import 'debts.dart';
import 'goals.dart';
import 'loan_calculator.dart';
import 'contribution_calculator.dart';
import 'pan_routes.dart';
import 'payday.dart';
import 'reports.dart';
import 'salary_calculator.dart';
import 'tax_calculator.dart';
import 'thirteenth_calculator.dart';
import 'shell.dart';

class _Msg {
  final String role; // 'user' or 'pan'
  final Map<String, dynamic> reply; // pan replies; user text in reply['text']
  const _Msg(this.role, this.reply);
}

class PanScreen extends StatefulWidget {
  final SalapifyStore store;
  final void Function(Destination)? onSwitchTab;

  /// Jumps to the Utang tab showing "Owed to me". Receivables taps land
  /// there specifically; plain onSwitchTab would open the "I owe" segment.
  final VoidCallback? onOpenReceivables;
  final VoidCallback? onOpenPayables;
  const PanScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onOpenReceivables,
    this.onOpenPayables,
  });

  @override
  State<PanScreen> createState() => _PanScreenState();
}

class _PanScreenState extends State<PanScreen> {
  final controller = TextEditingController();
  final scroll = ScrollController();
  final List<_Msg> messages = [];
  String mood = 'idle';
  late final Map<String, dynamic> greeting = helpReply();
  late final List<Map<String, String>> chips = suggestions(6);

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _send(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    final reply = ask(widget.store.data, text);
    // The make-it-a-plan offer rides on the MESSAGE, attached here at the
    // screen layer under a private key, never inside the golden-locked
    // reply the brain produced: the brain's replies must not change shape.
    // Derived fresh from the data, and re-checked at render so an old offer
    // disappears the moment a plan exists.
    final intentId = (reply['intent'] ?? '').toString();
    if (intentId == 'debt_free' || intentId == 'goal_pace') {
      final offer = planOfferFor(
        widget.store.data.cast<String, dynamic>(),
        intentId,
        DateTime.now(),
        askedAmount: extractAmount(text),
      );
      if (offer != null) reply['_planOffer'] = offer;
    }
    setState(() {
      messages.add(_Msg('user', {'text': text}));
      messages.add(_Msg('pan', reply));
      mood = (reply['mood'] ?? 'idle').toString();
      controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Turn a CTA's route into a navigation action, through the one typed
  /// registry (pan_routes.dart). An unknown route returns null and renders no
  /// button; the contract test keeps the brain from ever emitting one. The
  /// switch is over the enum, so it is exhaustive: a new PanRoute value with no
  /// arm here fails the analyzer rather than falling silently into a default.
  VoidCallback? _ctaAction(Map<dynamic, dynamic> cta) {
    final route = PanRoute.forPath((cta['route'] ?? '').toString());
    if (route == null) return null;

    VoidCallback push(Widget Function() build) =>
        () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => build()));

    switch (route) {
      case PanRoute.debts:
        // The Utang tab's "I owe" segment is the canonical home of debts now.
        // Pop to the root first (Pan can sit two deep, under Menu) and jump;
        // the pushed screen is only the fallback for a host that did not wire
        // the segment jump.
        final openPayables = widget.onOpenPayables;
        if (openPayables != null) {
          return () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            openPayables();
          };
        }
        return push(() => DebtsScreen(store: widget.store));
      case PanRoute.insights:
        final onSwitchTab = widget.onSwitchTab;
        if (onSwitchTab == null) return null;
        return () {
          // popUntil, not pop. Menu is a pushed route now, so a screen reached
          // through it sits TWO deep, and a single pop would land the user
          // back on Menu with the tab quietly changed behind it. Popping to
          // the root is correct from any depth.
          Navigator.of(context).popUntil((r) => r.isFirst);
          onSwitchTab(Destination.insights);
        };
      case PanRoute.receivables:
        final openReceivables = widget.onOpenReceivables;
        final onSwitchTab = widget.onSwitchTab;
        if (openReceivables == null && onSwitchTab == null) return null;
        return () {
          Navigator.of(context).popUntil((r) => r.isFirst);
          // The segment-aware jump when the host wires it: this CTA is about
          // money owed TO the user, and the plain tab switch would land on the
          // "I owe" segment instead.
          if (openReceivables != null) {
            openReceivables();
          } else {
            onSwitchTab!(Destination.utang);
          }
        };
      case PanRoute.accounts:
        // Previously dropped: "See accounts" / "Add accounts" rendered no
        // button at all. Accounts is a pushed screen, and the payables jump
        // rides along so its own "manage debts" note can route home.
        return push(
          () => AccountsScreen(
            store: widget.store,
            onOpenPayables: widget.onOpenPayables,
          ),
        );
      case PanRoute.reports:
        // "Plan payoff" points here: Reports carries the debt plan section and
        // the debt-free projection. Previously dropped.
        return push(
          () => ReportsScreen(
            store: widget.store,
            onSwitchTab: widget.onSwitchTab,
          ),
        );
      case PanRoute.goals:
        // Previously dropped: "Add a goal" / "Goals" had no button.
        return push(() => GoalsScreen(store: widget.store));
      case PanRoute.setPayday:
        // The RN "/(tabs)/more" route the "Set payday" CTA carries. In Flutter
        // payday has its own screen; previously this dropped to no button.
        return push(() => PaydayScreen(store: widget.store));
      case PanRoute.loanCalculator:
        return push(() => const LoanCalculatorScreen());
      case PanRoute.salaryCalculator:
        return push(() => const SalaryCalculatorScreen());
      case PanRoute.thirteenthCalculator:
        return push(() => const ThirteenthCalculatorScreen());
      case PanRoute.taxCalculator:
        return push(() => const TaxCalculatorScreen());
      case PanRoute.contributionCalculator:
        return push(() => const ContributionCalculatorScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Row(
          children: [
            // The mascot cup reacts to the latest reply's mood, the same widget
            // and mood engine the Home check-in uses.
            PanMascot(mood: panMoodForReplyMood(mood), size: 48),
            const SizedBox(width: 10),
            Text(
              'Pan',
              style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) => ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  children: [
                    // The plan card first: what Pan remembers, fully visible,
                    // editable, droppable. The trust rule made a widget.
                    ..._planCard(),
                    _panBubble(greeting, greetingChips: true),
                    for (final m in messages)
                      m.role == 'user'
                          ? _userBubble((m.reply['text'] ?? '').toString())
                          : _panBubble(m.reply),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              color: Barako.background,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      onSubmitted: _send,
                      textInputAction: TextInputAction.send,
                      style: TextStyle(color: Barako.text),
                      decoration: InputDecoration(
                        hintText: 'Ask about your money…',
                        hintStyle: TextStyle(color: Barako.faint),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () => _send(controller.text),
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The plan card: everything Pan remembers, in one glance. Change and Drop
  /// live right on it, so "memory" is never a mystery and never a trap.
  List<Widget> _planCard() {
    final status = planStatus(
      widget.store.data.cast<String, dynamic>(),
      DateTime.now(),
    );
    if (status == null) return const [];
    final actual = (status['actual'] as num).toDouble();
    final remaining = (status['remaining'] as num).toDouble();
    final journey = actual + remaining;
    final pct = journey > 0 ? (actual / journey).clamp(0.0, 1.0) : 0.0;
    final state = status['state'].toString();
    return [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Barako.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OUR PLAN', style: Barako.kickerStyle),
              const SizedBox(height: 6),
              Text(
                planLine(status),
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (state != 'orphaned' && state != 'done') ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Barako.border,
                    valueColor: AlwaysStoppedAnimation(Barako.primary),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: _editPlan,
                    child: Text(
                      'Change',
                      style: TextStyle(
                        color: Barako.primaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _dropPlan,
                    child: Text(
                      'Drop the plan',
                      style: TextStyle(
                        color: Barako.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Future<void> _dropPlan() async {
    // Plans change; dropping one is allowed to feel light. A receipt, not a
    // guilt trip.
    await widget.store.clearActivePlan();
    if (!mounted) return;
    setState(() {
      messages.add(
        _Msg('pan', {
          'mood': 'idle',
          'text':
              'Plan dropped. Nothing else changed, your money is exactly '
              'where it was. We can make a new one whenever you like.',
        }),
      );
    });
  }

  Future<void> _editPlan() async {
    final plan = widget.store.activePlan;
    if (plan == null) return;
    final controllerAmt = TextEditingController(
      text: (amountOfPlan(plan)).toStringAsFixed(0),
    );
    final saved = await showModalBottomSheet<double?>(
      context: context,
      backgroundColor: Barako.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: 20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change the plan',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Same plan, new pace. Pick an amount that fits real life.',
                style: TextStyle(color: Barako.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllerAmt,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: plan['cadence'] == 'weekly'
                      ? 'Amount per week'
                      : 'Amount per month',
                  labelStyle: TextStyle(color: Barako.muted),
                ),
                style: TextStyle(color: Barako.text),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(null),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Barako.muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      final v = double.tryParse(
                        controllerAmt.text.replaceAll(',', ''),
                      );
                      if (v == null ||
                          !(v > 0) ||
                          !v.isFinite ||
                          v > 100000000) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter an amount above zero, up to 100 million.',
                            ),
                          ),
                        );
                        return;
                      }
                      Navigator.of(sheetContext).pop(v);
                    },
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
      ),
    );
    if (saved == null) return;
    await widget.store.setActivePlan({...plan, 'amount': saved});
    if (!mounted) return;
    final status = planStatus(
      widget.store.data.cast<String, dynamic>(),
      DateTime.now(),
    );
    if (status != null) {
      setState(() {
        messages.add(
          _Msg('pan', {'mood': 'idle', 'text': 'Noted. ${planLine(status)}'}),
        );
      });
    }
  }

  static double amountOfPlan(Map<String, dynamic> plan) {
    final a = plan['amount'];
    return a is num && a.isFinite && a > 0 ? a.toDouble() : 0;
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    await widget.store.setActivePlan(offer);
    if (!mounted) return;
    final status = planStatus(
      widget.store.data.cast<String, dynamic>(),
      DateTime.now(),
    );
    setState(() {
      messages.add(
        _Msg('pan', {
          'mood': 'happy',
          'text': status != null
              ? 'Deal. ${planLine(status)} I will keep score and you can '
                    'change or drop it on the card anytime.'
              : 'Deal, the plan is set. You can change or drop it on the '
                    'card anytime.',
        }),
      );
    });
  }

  Widget _userBubble(String text) => Padding(
    padding: const EdgeInsets.only(top: 10, left: 48),
    child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Barako.primary,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(color: Barako.onPrimary, fontSize: 14),
        ),
      ),
    ),
  );

  Widget _panBubble(Map<String, dynamic> reply, {bool greetingChips = false}) {
    final cta = reply['cta'];
    final action = cta is Map ? _ctaAction(cta) : null;
    final reminder = reply['reminder'];
    final replySuggestions = reply['suggestions'];
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 32),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Barako.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (reply['text'] ?? '').toString(),
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (reminder is String && reminder.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Barako.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Barako.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder,
                        style: TextStyle(
                          color: Barako.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                            ClipboardData(text: reminder),
                          );
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Reminder copied. Paste it anywhere.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy reminder'),
                      ),
                    ],
                  ),
                ),
              ],
              if (replySuggestions is List && replySuggestions.isNotEmpty ||
                  greetingChips) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (greetingChips)
                      for (final c in chips)
                        ActionChip(
                          label: Text(c['label']!),
                          onPressed: () => _send(c['example']!),
                          backgroundColor: Barako.background,
                          labelStyle: TextStyle(
                            color: Barako.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                    else if (replySuggestions is List)
                      for (final s in replySuggestions)
                        ActionChip(
                          label: Text(s.toString()),
                          onPressed: () => _send(s.toString()),
                          backgroundColor: Barako.background,
                          labelStyle: TextStyle(
                            color: Barako.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                  ],
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: action,
                  child: Text(
                    (cta as Map)['label'].toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              // The make-it-a-plan offer: attached by the screen at send
              // time, re-checked here so it vanishes once any plan exists
              // (one plan at a time, and a stale offer must not overwrite
              // it).
              if (reply['_planOffer'] is Map &&
                  widget.store.activePlan == null) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _acceptOffer(
                    (reply['_planOffer'] as Map).cast<String, dynamic>(),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 16),
                  label: Text(
                    'Make it a plan: ${formatMoneyText(amountOfPlan((reply['_planOffer'] as Map).cast<String, dynamic>()))} monthly',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
