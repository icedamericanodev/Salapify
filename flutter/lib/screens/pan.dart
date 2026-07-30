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
import '../money/pan/ask.dart';
import '../money/pan_mood.dart';
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

    VoidCallback push(Widget Function() build) => () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => build()));

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
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                children: [
                  _panBubble(greeting, greetingChips: true),
                  for (final m in messages)
                    m.role == 'user'
                        ? _userBubble((m.reply['text'] ?? '').toString())
                        : _panBubble(m.reply),
                ],
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
            ],
          ),
        ),
      ),
    );
  }
}
