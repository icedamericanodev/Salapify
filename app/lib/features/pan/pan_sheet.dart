import 'package:flutter/material.dart';

import '../../core/money/pan/pan_engine.dart';
import '../../core/money/pan/pan_context.dart';
import '../../core/money/pan/pan_knowledge.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';
import 'pan_history.dart';
import 'pan_message_bubble.dart';

/// Ask Pan.
///
/// The prototype puts a 240ms delay and three bouncing dots in front of every
/// answer, to make a keyword match feel like something thinking. That is not
/// ported. The answer appears when it is ready, which is instantly, and the
/// screen says plainly where it comes from.
///
/// Two disclosures live here and neither is behind a dot, because both change
/// how somebody weighs an answer:
///
///  - the pill in the header, on screen at the moment of reading, which is the
///    only moment that counts;
///  - Pan's own first message, rebuilt every time the sheet opens rather than
///    shown once ever, saying what it is and what it is not.
class PanSheet extends StatefulWidget {
  const PanSheet({
    super.key,
    required this.state,
    required this.onAction,
    this.openWith,
    this.history,
  });

  final FinancialState state;

  /// A question to ask the moment the sheet opens.
  ///
  /// The Home card offers three of them, and tapping one has to arrive at
  /// the answer rather than at an empty chat somebody then has to retype
  /// into. Null opens on Pan's introduction, which is what the floating
  /// button does.
  final String? openWith;

  /// Where the conversation is kept between openings.
  ///
  /// Null means do not keep one, which is what every test and every render
  /// gets unless it says otherwise. A screenshot harness writing a chat file
  /// into somebody's documents directory would be a surprise, and a test
  /// that depends on what a previous test typed is not a test.
  final PanHistoryStore? history;

  /// Handles one of `panActionIds`, AFTER this sheet has closed.
  ///
  /// Required rather than optional, and that is deliberate. An optional
  /// callback defaulting to nothing means a button that renders, invites a
  /// tap, and does nothing, which is worse than no button: somebody taps it
  /// twice and concludes the app is broken. Making it required means a new
  /// call site has to decide.
  final ValueChanged<String> onAction;

  static Future<void> show(
    BuildContext context,
    FinancialState state, {
    required ValueChanged<String> onAction,
    String? openWith,
    PanHistoryStore? history,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => PanSheet(
        state: state,
        onAction: onAction,
        openWith: openWith,
        history: history,
      ),
    );
  }

  @override
  State<PanSheet> createState() => _PanSheetState();
}

class _PanSheetState extends State<PanSheet> {
  final TextEditingController _input = TextEditingController();

  /// The KEY of the newest message, so it can be scrolled into view.
  ///
  /// Not a ScrollController. The first version made one, called animateTo on
  /// it, and attached it to nothing: SheetScaffold owns its own
  /// SingleChildScrollView and takes no controller, so `hasClients` was always
  /// false and the scroll was silently skipped every time. On a phone that
  /// reads as "I tapped a question and nothing happened", because the answer
  /// is appended below the fold. Scrolling to a widget needs no controller at
  /// all and cannot be wired to the wrong scroll view.
  final GlobalKey _newest = GlobalKey();

  /// The conversation, oldest first.
  ///
  /// This comment used to say it was never stored, and gave a good reason:
  /// a list of sentences like "should I put my 200k inheritance somewhere"
  /// sitting on a phone forever. The founder asked for it to survive an app
  /// restart so an audit is not lost, which is their call, and the reason
  /// above is answered rather than ignored: the last two dozen messages
  /// only, in their OWN file so a bad entry cannot take the ledger down, and
  /// the wipe deletes that file along with everything else.
  final List<PanMessage> _messages = <PanMessage>[];

  /// True once an earlier conversation has been put back on screen, so the
  /// screen can say so. Restored text appearing with no explanation reads as
  /// the app having answered something nobody just asked.
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _messages.add(const PanMessage.pan(_opening));
    _loadHistory();
    final String? first = widget.openWith;
    if (first != null && first.trim().isNotEmpty) {
      // Straight into the list rather than through _ask, which schedules a
      // scroll against a frame that has not been built yet. The opening
      // answer is at the top of a short list and needs no scrolling to.
      _messages.add(PanMessage.you(first));
      _messages.add(PanMessage.answer(askPan(first, widget.state.panFacts)));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  static const String _opening =
      'I am Pan, the money assistant built into Salapify. I read the figures '
      'you have typed into this phone and do arithmetic on them, matching '
      'what you ask against a set of built-in answers. There is no AI model '
      'and nothing leaves your phone, so I work with no signal at all.\n\n'
      'I can tell you what you hold, what is safe to spend, where the month '
      'went, what you owe and what is owed to you, and how any part of '
      'Salapify works. What I cannot do is tell you what to do with your '
      'money: that is not general information, and Salapify is not licensed '
      'to give it.';

  void _ask(String question) {
    final String q = question.trim();
    if (q.isEmpty) return;
    final PanFacts facts = widget.state.panFacts;
    final PanAnswer answer = askPan(q, facts);
    setState(() {
      _messages.add(PanMessage.you(q));
      _messages.add(PanMessage.answer(answer));
      _input.clear();
    });
    _remember();
    // After the frame, so the new message exists and has a height.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? target = _newest.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.1,
      );
    });
  }

  /// Puts the last conversation back, under a line saying what it is.
  ///
  /// Inserted BELOW the opening message and ABOVE anything asked this time,
  /// which is the only order that reads correctly: Pan introduces itself,
  /// then the earlier conversation, then today.
  Future<void> _loadHistory() async {
    final PanHistoryStore? store = widget.history;
    if (store == null) return;
    final List<PanStoredMessage> saved = await store.load();
    if (saved.isEmpty || !mounted) return;
    setState(() {
      _restored = true;
      _messages.insertAll(1, <PanMessage>[
        for (final PanStoredMessage m in saved)
          m.fromPan
              ? PanMessage.pan(m.text, badge: m.badge)
              : PanMessage.you(m.text),
      ]);
    });
  }

  /// Keeps what was said, minus Pan's opening, which is rebuilt every time.
  void _remember() {
    final PanHistoryStore? store = widget.history;
    if (store == null) return;
    store.save(<PanStoredMessage>[
      for (final PanMessage m in _messages.skip(1))
        PanStoredMessage(
          fromPan: m.fromPan,
          text: m.text,
          badge: m.answer?.badge ?? m.badge,
        ),
    ]);
  }

  /// Clears the conversation, on screen and on disk.
  ///
  /// No confirmation, deliberately. The recovery rule in this repository is
  /// about work somebody would be upset to lose, and a chat log is not that.
  /// Asking twice about it would train people to tap through the dialog that
  /// guards Delete everything, which is the one that matters.
  void _startFresh() {
    widget.history?.clear();
    setState(() {
      _messages
        ..clear()
        ..add(const PanMessage.pan(_opening));
      _restored = false;
    });
  }

  /// Closes the sheet FIRST, then does the thing.
  ///
  /// The order is the whole method. Every destination is either a tab under
  /// this sheet or another sheet, so leaving Pan open would either hide the
  /// screen somebody just asked to see or stack a second sheet on a first.
  /// The callback is read off the widget before the pop, because this
  /// State's context is gone on the far side of it.
  void _runAction(String id) {
    final ValueChanged<String> handler = widget.onAction;
    Navigator.of(context).pop();
    handler(id);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final List<String> chips = _messages.last.answer?.followUps ?? panStarters;

    return SheetScaffold(
      palette: p,
      icon: Icons.chat_bubble_outline,
      title: 'Ask Pan',
      subtitle: 'Your own figures, worked out on this phone',
      banner: _Pill(palette: p),
      footer: _Composer(
        palette: p,
        controller: _input,
        chips: chips,
        onAsk: _ask,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Only when there IS an earlier conversation. Restored text with
          // no explanation reads as the app having answered something nobody
          // just asked, and a Start fresh control with nothing to clear is a
          // button that does nothing.
          if (_restored) _RestoredMark(palette: p, onClear: _startFresh),
          for (int i = 0; i < _messages.length; i++)
            Padding(
              key: i == _messages.length - 1 ? _newest : null,
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: PanMessageBubble(
                palette: p,
                message: _messages[i],
                onAction: _runAction,
              ),
            ),
        ],
      ),
    );
  }
}

/// Says where the messages above came from, and offers to drop them.
class _RestoredMark extends StatelessWidget {
  const _RestoredMark({required this.palette, required this.onClear});

  final Palette palette;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Earlier conversation, kept on this phone',
              style: AppType.rowMeta(palette),
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: Text(
              'Start fresh',
              style: AppType.rowMeta(
                palette,
              ).copyWith(color: palette.accent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// The claim that has to be on screen while somebody is reading an answer, not
/// in Settings where the person reading a recommendation never goes.
class _Pill extends StatelessWidget {
  const _Pill({required this.palette});

  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, 0, Spacing.lg, Spacing.sm),
      child: Wrap(
        spacing: Spacing.xs,
        runSpacing: Spacing.xs,
        children: <Widget>[
          _chip(Icons.gavel_outlined, 'General info, not financial advice'),
          _chip(Icons.wifi_off_outlined, 'Works offline'),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: palette.accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppType.caption(palette).copyWith(color: palette.accent),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.palette,
    required this.controller,
    required this.chips,
    required this.onAsk,
  });

  final Palette palette;
  final TextEditingController controller;
  final List<String> chips;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Every chip is genuinely answerable, and a test asserts it. A
        // suggested question that produces "I did not understand" teaches
        // somebody on their first tap that the assistant is broken.
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: chips.length,
            separatorBuilder: (_, _) => const SizedBox(width: Spacing.xs),
            itemBuilder: (BuildContext context, int i) => Material(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.pill),
              child: InkWell(
                onTap: () => onAsk(chips[i]),
                borderRadius: BorderRadius.circular(Radii.pill),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        chips[i],
                        style: AppType.button(
                          palette,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: onAsk,
                style: AppType.body(
                  palette,
                ).copyWith(color: palette.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ask about your money or about Salapify',
                  hintStyle: AppType.body(palette),
                  filled: true,
                  fillColor: palette.surfaceAlt,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.md,
                    vertical: Spacing.md,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.tile),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Semantics(
              button: true,
              label: 'Ask Pan',
              child: Material(
                color: palette.accent,
                borderRadius: BorderRadius.circular(Radii.tile),
                child: InkWell(
                  onTap: () => onAsk(controller.text),
                  borderRadius: BorderRadius.circular(Radii.tile),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 48,
                      minWidth: 48,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.arrow_upward,
                      size: 20,
                      color: palette.onAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
