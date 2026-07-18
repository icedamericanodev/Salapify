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
import '../theme.dart';
import 'debts.dart';
import 'loan_calculator.dart';

class _Msg {
  final String role; // 'user' or 'pan'
  final Map<String, dynamic> reply; // pan replies; user text in reply['text']
  const _Msg(this.role, this.reply);
}

class PanScreen extends StatefulWidget {
  final SalapifyStore store;
  final void Function(int)? onSwitchTab;
  const PanScreen({super.key, required this.store, this.onSwitchTab});

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
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  /// Pan's CTAs use the RN route names; open what exists in the Flutter app
  /// today and quietly skip the rest (the reply text stands on its own).
  VoidCallback? _ctaAction(Map<dynamic, dynamic> cta) {
    final route = (cta['route'] ?? '').toString();
    switch (route) {
      case '/debts':
        return () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => DebtsScreen(store: widget.store)));
      case '/loan-calculator':
        return () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const LoanCalculatorScreen()));
      case '/insights':
        final onSwitchTab = widget.onSwitchTab;
        if (onSwitchTab == null) return null;
        return () {
          Navigator.of(context).pop();
          onSwitchTab(4);
        };
      case '/receivables':
        final onSwitchTab = widget.onSwitchTab;
        if (onSwitchTab == null) return null;
        return () {
          Navigator.of(context).pop();
          onSwitchTab(3);
        };
      default:
        return null;
    }
  }

  String get _face =>
      mood == 'happy' ? '😄' : mood == 'worried' ? '😟' : '☕';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Barako.primary,
              child: Text(_face, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Text('Pan',
                style: TextStyle(
                    color: Barako.text, fontWeight: FontWeight.w800)),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Barako.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(text,
                style: TextStyle(color: Barako.onPrimary, fontSize: 14)),
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
              Text((reply['text'] ?? '').toString(),
                  style: TextStyle(
                      color: Barako.text, fontSize: 14, height: 1.45)),
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
                      Text(reminder,
                          style: TextStyle(
                              color: Barako.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                              fontStyle: FontStyle.italic)),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(
                              ClipboardData(text: reminder));
                          messenger.showSnackBar(const SnackBar(
                              content: Text(
                                  'Reminder copied. Paste it anywhere.')));
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
                              fontWeight: FontWeight.w600),
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
                              fontWeight: FontWeight.w600),
                        ),
                  ],
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: action,
                  child: Text((cta as Map)['label'].toString(),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
