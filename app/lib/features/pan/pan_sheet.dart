import 'package:flutter/material.dart';

import '../../core/money/pan.dart';
import '../../core/money/pan_facts.dart';
import '../../data/pan_knowledge.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

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
  const PanSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => PanSheet(state: state),
    );
  }

  @override
  State<PanSheet> createState() => _PanSheetState();
}

class _PanSheetState extends State<PanSheet> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  /// The conversation, oldest first. Not stored: a question somebody typed
  /// about their own money is not something Salapify needs to keep, and
  /// keeping it would put a list of sentences like "should I put my 200k
  /// inheritance somewhere" on the phone forever.
  final List<_Msg> _messages = <_Msg>[];

  @override
  void initState() {
    super.initState();
    _messages.add(const _Msg.pan(_opening));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
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
      _messages.add(_Msg.you(q));
      _messages.add(_Msg.answer(answer));
      _input.clear();
    });
    // After the frame, so the new message has a height to scroll to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
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
          for (final _Msg m in _messages)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _Bubble(palette: p, message: m),
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

class _Msg {
  const _Msg.you(this.text) : fromPan = false, answer = null;
  const _Msg.pan(this.text) : fromPan = true, answer = null;
  _Msg.answer(PanAnswer a) : fromPan = true, answer = a, text = a.display;

  final String text;
  final bool fromPan;
  final PanAnswer? answer;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.palette, required this.message});

  final Palette palette;
  final _Msg message;

  @override
  Widget build(BuildContext context) {
    final bool pan = message.fromPan;
    return Align(
      alignment: pan ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.all(Spacing.md),
        decoration: BoxDecoration(
          color: pan ? palette.surfaceAlt : palette.accent,
          borderRadius: BorderRadius.circular(Radii.tile),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              message.text,
              style: pan
                  ? AppType.body(palette).copyWith(color: palette.textPrimary)
                  : AppType.body(palette).copyWith(color: palette.onAccent),
            ),
            // The figures again, as rows. A number inside a paragraph is read;
            // a number in a row is seen, and these are the point of the
            // answer.
            if (message.answer != null &&
                message.answer!.figures.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.sm),
              for (final PanFigure f in message.answer!.figures)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(f.label, style: AppType.rowMeta(palette)),
                      ),
                      Text(f.value, style: AppType.amountSmall(palette)),
                    ],
                  ),
                ),
            ],
          ],
        ),
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
