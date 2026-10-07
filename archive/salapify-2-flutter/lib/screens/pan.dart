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
import '../money/format.dart' show prettyDay, prettyMonthYear;
import '../money/ledger.dart' show amountOf;
import '../money/pan/ask.dart';
import '../money/pan/normalize.dart' show extractAmount;
import '../money/pan/respond.dart' show planLine;
import '../money/pan_mood.dart';
import '../money/plan.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/pan_mascot.dart';
import '../widgets/progress_bar.dart';
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
import '../widgets/salapify_icon.dart';

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

  /// A question asked FOR the user on arrival, through the same brain as a
  /// typed one. Insights hands the context over on its "Ask Pan" actions so
  /// nobody retypes a question the app already knows; the question appears
  /// as an ordinary user bubble, so the conversation stays honest about
  /// what was asked. Nothing here bypasses the golden-locked ask().
  final String? initialQuestion;
  const PanScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onOpenReceivables,
    this.onOpenPayables,
    this.initialQuestion,
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
  void initState() {
    super.initState();
    final q = widget.initialQuestion?.trim();
    if (q != null && q.isNotEmpty) {
      // After the first frame, not during initState: _send calls setState
      // and scrolls, both of which need a built tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(q);
      });
    }
  }

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
        // The raw message, so a goal offer follows the goal the user NAMED,
        // the same way the resolver picks its focus.
        raw: text,
      );
      if (offer != null) reply['_planOffer'] = offer;
    }
    setState(() {
      messages.add(_Msg('user', {'text': text}));
      messages.add(_Msg('pan', reply));
      mood = (reply['mood'] ?? 'idle').toString();
      controller.clear();
    });
    _scrollToEnd();
  }

  /// Bring the newest bubble into view. Every path that appends a message
  /// calls this, including the plan receipts: a settings write whose receipt
  /// lands below the fold is a write the user never saw happen.
  void _scrollToEnd() {
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
        title: Row(
          children: [
            // The mascot cup reacts to the latest reply's mood, the same widget
            // and mood engine the Home check-in uses.
            PanMascot(mood: panMoodForReplyMood(mood), size: 48),
            const SizedBox(width: 10),
            Text('Pan'),
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
                    icon: Icon(salapifyIcon('up')),
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
    final pct = (status['progress'] as num).toDouble();
    final state = status['state'].toString();
    // The facts line: the trust rule says everything Pan remembers is ON the
    // card, and planLine only says the amount in the started state. Amount,
    // cadence, and start date, always visible, never only inside the editor.
    final startIso = (widget.store.activePlan?['startDate'] ?? '').toString();
    final thisYear =
        startIso.length >= 4 &&
        startIso.substring(0, 4) == DateTime.now().year.toString();
    final since = thisYear ? prettyDay(startIso) : prettyMonthYear(startIso);
    final cadenceWord = status['cadence'] == 'weekly' ? 'weekly' : 'monthly';
    final factsLine =
        '${formatMoneyText((status['amount'] as num).toDouble())} '
        '$cadenceWord since $since';
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
              Text('OUR PLAN', style: Barako.cardKickerStyle),
              const SizedBox(height: 4),
              Text(factsLine, style: AppText.caption.copyWith(fontSize: 12.5)),
              const SizedBox(height: 6),
              Text(
                planLine(status),
                style: AppText.label.w4.copyWith(height: 1.45),
              ),
              if (state != 'orphaned' && state != 'done') ...[
                const SizedBox(height: 10),
                SalapifyProgressBar(
                  value: pct,
                  size: ProgressBarSize.micro,
                  semanticsLabel: 'Plan progress',
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  // No Change on a finished or orphaned plan: there is no
                  // pace left to edit, only a card to let go of.
                  if (state != 'orphaned' && state != 'done')
                    TextButton(
                      onPressed: _editPlan,
                      child: Text(
                        'Change',
                        style: AppText.small.w7.tint(Barako.primaryText),
                      ),
                    ),
                  TextButton(
                    onPressed: _dropPlan,
                    child: Text(
                      'Drop the plan',
                      style: AppText.small.w7.tint(Barako.muted),
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
    // Light in tone, confirmed in fact: dropping erases the start date and
    // start level, so the tracked pace history cannot come back, and the
    // button sits one mis-tap away from Change. Light and confirmed are
    // compatible; light and unrecoverable are not.
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        // Kept explicitly heavy: dialog titles do not inherit appBarTheme.
        title: Text(
          'Drop the plan?',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Your money does not change, only the score keeping stops. '
          'We can always start a new one.',
          style: TextStyle(color: Barako.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep it', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Drop it',
              style: TextStyle(
                color: Barako.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await widget.store.clearActivePlan();
    } catch (_) {
      if (!mounted) return;
      _writeFailed();
      return;
    }
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
    _scrollToEnd();
  }

  Future<void> _editPlan() async {
    final plan = widget.store.activePlan;
    if (plan == null) return;
    // Prefill keeps the stored decimals: rounding 1500.50 to "1501" here
    // would make an untouched Save silently rewrite the amount by 50
    // centavos, a write the user never asked for.
    final prefill = amountOfPlan(plan);
    final saved = await showModalBottomSheet<double?>(
      context: context,
      backgroundColor: Barako.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _PlanEditSheet(
        initial: prefill == prefill.roundToDouble()
            ? prefill.toStringAsFixed(0)
            : prefill.toString(),
        weekly: plan['cadence'] == 'weekly',
      ),
    );
    if (saved == null) return;
    try {
      await widget.store.setActivePlan({...plan, 'amount': saved});
    } catch (_) {
      if (!mounted) return;
      _writeFailed();
      return;
    }
    if (!mounted) return;
    final status = planStatus(
      widget.store.data.cast<String, dynamic>(),
      DateTime.now(),
    );
    if (status != null) {
      // The receipt echoes what was actually written: after 2,000 becomes
      // 3,000, "Noted" alone never states the new amount.
      final word = plan['cadence'] == 'weekly' ? 'week' : 'month';
      setState(() {
        messages.add(
          _Msg('pan', {
            'mood': 'idle',
            'text':
                'Noted, ${formatMoneyText(saved)} a $word now. '
                '${planLine(status)}',
          }),
        );
      });
      _scrollToEnd();
    }
  }

  static double amountOfPlan(Map<String, dynamic> plan) {
    final a = plan['amount'];
    return a is num && a.isFinite && a > 0 ? a.toDouble() : 0;
  }

  Future<void> _acceptOffer(Map<String, dynamic> offer) async {
    // The chip stays tappable in chat history, so the offer it carries can
    // be stale: the debt paid down since, days passed, the target deleted.
    // Progress is measured from startDate and startLevel, so committing the
    // frozen ones would count money moved BEFORE the commitment. Re-anchor
    // both to today, and check the target still exists at all.
    final data = widget.store.data.cast<String, dynamic>();
    final kind = (offer['kind'] ?? '').toString();
    Map<String, dynamic>? target;
    for (final row
        in (data[kind == 'debt' ? 'debts' : 'goals'] is List
            ? data[kind == 'debt' ? 'debts' : 'goals'] as List
            : const [])) {
      if (row is Map && row['id'] == offer['targetId']) {
        target = row.cast<String, dynamic>();
        break;
      }
    }
    if (target == null) {
      setState(() {
        messages.add(
          _Msg('pan', {
            'mood': 'idle',
            'text':
                'That one is gone from your book now, so there is nothing '
                'to plan against. Ask me again and we can make a fresh one.',
          }),
        );
      });
      _scrollToEnd();
      return;
    }
    final now = DateTime.now();
    final level = kind == 'debt'
        ? amountOf(target['remaining'])
        : amountOf(target['saved']);
    final fresh = {
      ...offer,
      'startDate':
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}',
      'startLevel': level,
    };
    try {
      await widget.store.setActivePlan(fresh);
    } catch (_) {
      // Catch-all on purpose: read-only mode throws StateError, an Error
      // not an Exception, and a save failure can surface as either.
      if (!mounted) return;
      _writeFailed();
      return;
    }
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
    _scrollToEnd();
  }

  /// The shared receipt for a plan write that did not land: a tap that
  /// silently does nothing reads as a broken button, and worse, as a plan
  /// the user believes exists.
  void _writeFailed() {
    setState(() {
      messages.add(
        _Msg('pan', {
          'mood': 'idle',
          'text':
              'I could not save that just now, so nothing changed. '
              'Please try again in a moment.',
        }),
      );
    });
    _scrollToEnd();
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
        child: Text(text, style: AppText.label.w4.tint(Barako.onPrimary)),
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
                style: AppText.label.w4.copyWith(height: 1.45),
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
                        style: AppText.small.copyWith(
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
                        icon: Icon(salapifyIcon('copy'), size: 14),
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
                          labelStyle: AppText.caption.w6.tint(
                            Barako.textSecondary,
                          ),
                        )
                    else if (replySuggestions is List)
                      for (final s in replySuggestions)
                        ActionChip(
                          label: Text(s.toString()),
                          onPressed: () => _send(s.toString()),
                          backgroundColor: Barako.background,
                          labelStyle: AppText.caption.w6.tint(
                            Barako.textSecondary,
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
              // activePlanOf, not the raw getter: a junk activePlan from a
              // hand-edited backup is non-null but renders no card, and a
              // raw check here would then block every future offer with no
              // way out. Shape-checked, junk reads as "no plan" everywhere.
              if (reply['_planOffer'] is Map &&
                  activePlanOf(widget.store.data.cast<String, dynamic>()) ==
                      null) ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final offer = (reply['_planOffer'] as Map)
                        .cast<String, dynamic>();
                    // The cadence word comes from the offer itself, so the
                    // chip can never say monthly over a weekly plan. Icon
                    // and label are laid out by hand because
                    // FilledButton.icon does not let its label wrap, and a
                    // seven digit amount at 320dp needs to.
                    final word = offer['cadence'] == 'weekly'
                        ? 'weekly'
                        : 'monthly';
                    return FilledButton(
                      onPressed: () => _acceptOffer(offer),
                      style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(salapifyIcon('plan'), size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              // The target is NAMED on the button: a goal
                              // offer follows the reply's focus goal, and
                              // the name is how the user verifies that
                              // before committing, not after.
                              'Make it a plan: ${offer['label']}, '
                              '${formatMoneyText(amountOfPlan(offer))} $word',
                              softWrap: true,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The amount-only edit sheet. A real StatefulWidget rather than a
/// StatefulBuilder so the text controller is disposed by the framework
/// AFTER the sheet's exit animation: disposing it right after the pop left
/// the closing sheet building a dead controller. The validation error
/// renders inline on the field; a SnackBar here draws behind the modal
/// barrier and the keyboard, so Save looked like it did nothing at all.
class _PlanEditSheet extends StatefulWidget {
  const _PlanEditSheet({required this.initial, required this.weekly});

  final String initial;
  final bool weekly;

  @override
  State<_PlanEditSheet> createState() => _PlanEditSheetState();
}

class _PlanEditSheetState extends State<_PlanEditSheet> {
  late final TextEditingController amt = TextEditingController(
    text: widget.initial,
  );
  String? error;

  @override
  void dispose() {
    amt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change the plan', style: AppText.subtitle.w8),
            const SizedBox(height: 4),
            Text(
              'Same plan, new pace. Pick an amount that fits real life.',
              style: AppText.caption.copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amt,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.weekly
                    ? 'Amount per week'
                    : 'Amount per month',
                labelStyle: TextStyle(color: Barako.muted),
                errorText: error,
              ),
              style: TextStyle(color: Barako.text),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text('Cancel', style: TextStyle(color: Barako.muted)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final v = double.tryParse(amt.text.replaceAll(',', ''));
                    if (v == null || !(v > 0) || !v.isFinite || v > 100000000) {
                      setState(() {
                        error =
                            'Enter an amount above zero, up to 100 million.';
                      });
                      return;
                    }
                    Navigator.of(context).pop(v);
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
    );
  }
}
