// The Log sheet. Principle 1: logging is the heartbeat, under three seconds
// from thumb to saved. So it slides up OVER the screen you were on rather than
// being its own page, because that is how it is actually used and the dimmed
// screen behind it is part of the design, not a detail of the screenshot.
//
// Ported from docs/revamp/mockups/hapon/source/log.dart, the approved render.
//
// NOTHING HERE SAVES ANYTHING YET, and that is Phase C. In particular the
// "Got it" line under the field is a picture of a feature that DOES NOT EXIST:
// 01-vision.md principle 1 says so out loud, corrected in B2. There is no fast
// log parser in this repository, in either app. It stays in the design because
// it is the right target.
import 'package:flutter/material.dart';

import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

/// The scrim plus the sheet. Pushed as a route over the shell, so the tab you
/// were on stays visible behind it.
class LogSheet extends StatelessWidget {
  const LogSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // The Material is not decoration. Text with no Material ancestor gets
    // Flutter's yellow double underline, and the first render of this screen
    // had it on every single label. Caught by looking at the picture,
    // invisible to analyze and to every test.
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // The scrim. Dark in both skins: it is a shadow, not a surface, so
          // it does not flip with the palette.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: ColoredBox(color: context.skin.scrim),
            ),
          ),
          const Align(alignment: Alignment.bottomCenter, child: _Sheet()),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet();

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(gutter, 12, gutter, 30),
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(skin.radius + 6),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: skin.line,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Log', style: TypeScale.sheetTitle(skin.text)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Text('Cancel', style: TypeScale.quiet(skin.text3)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // The fast log field. One typed line becomes a saved expense with a
          // category, and the app says out loud what it understood BEFORE the
          // user commits, so a wrong guess is caught in the same glance.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: skin.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'jollibee 250',
                    style: TypeScale.input(skin.text),
                  ),
                ),
                Container(width: 2, height: 20, color: skin.accent),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: TypeScale.hint(skin.text3),
              children: [
                const TextSpan(text: 'Got it: '),
                TextSpan(
                  text: 'Expense',
                  style: TypeScale.hintStrong(skin.accent),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: '₱250.00',
                  style: TypeScale.hintStrong(skin.accent),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: 'Jollibee',
                  style: TypeScale.hintStrong(skin.accent),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: 'Food',
                  style: TypeScale.hintStrong(skin.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Segmented(options: ['Expense', 'Income', 'Transfer'], index: 0),
          const SizedBox(height: 22),

          Text('Category', style: TypeScale.fieldLabel(skin.text3)),
          const SizedBox(height: 10),
          const _Chips(
            labels: ['Food', 'Transport', 'Bills', 'Groceries'],
            on: 0,
          ),
          const SizedBox(height: 18),
          Text('Account', style: TypeScale.fieldLabel(skin.text3)),
          const SizedBox(height: 10),
          const _Chips(labels: ['GCash', 'Cash', 'BPI', 'Maya'], on: 0),
          const SizedBox(height: 20),

          const Row(
            children: [
              Expanded(
                child: Field(value: 'Today', leading: Icons.event_outlined),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Field(
                  value: 'Note',
                  hint: true,
                  leading: Icons.notes_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const PillButton(label: 'Save entry'),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.labels, required this.on});
  final List<String> labels;
  final int on;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var i = 0; i < labels.length; i++)
        PickChip(label: labels[i], on: i == on),
    ],
  );
}
