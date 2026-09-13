// The Log sheet. Principle 1: logging is the heartbeat, under three seconds
// from thumb to saved. So it is rendered OVER Home rather than as its own
// page, because that is how it is actually seen and the dimmed screen behind
// it is part of the design, not a detail of the screenshot.
import 'package:flutter/material.dart';
import 'home.dart';
import 'kit.dart';
import 'skin.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // The Material is not decoration. Text with no Material ancestor gets
    // Flutter's yellow double underline, and the first render of this screen
    // had it on every single label: HomeScreen brings its own Scaffold, but
    // the sheet stacked beside it had none. Caught by looking at the picture,
    // invisible to analyze and to every test here.
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          const HomeScreen(),
          // The scrim. Dark in both skins: it is a shadow, not a surface, so
          // it does not flip with the palette.
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0xFF15120F).withValues(alpha: 0.55),
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
                child: Text(
                  'Log',
                  style: ts(22, FontWeight.w700, skin.text, ls: -0.5),
                ),
              ),
              Text('Cancel', style: ts(14, FontWeight.w500, skin.text3)),
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
                    style: ts(16, FontWeight.w500, skin.text),
                  ),
                ),
                Container(width: 2, height: 20, color: skin.accent),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: ts(13, FontWeight.w400, skin.text3),
              children: [
                const TextSpan(text: 'Got it: '),
                TextSpan(
                  text: 'Expense',
                  style: ts(13, FontWeight.w600, skin.accent),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: '₱250.00',
                  style: ts(13, FontWeight.w600, skin.accent),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: 'Jollibee',
                  style: ts(13, FontWeight.w600, skin.accent),
                ),
                const TextSpan(text: ' · '),
                TextSpan(
                  text: 'Food',
                  style: ts(13, FontWeight.w600, skin.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Segmented(options: ['Expense', 'Income', 'Transfer'], index: 0),
          const SizedBox(height: 22),

          Text('Category', style: ts(12.5, FontWeight.w500, skin.text3)),
          const SizedBox(height: 10),
          const _Chips(
            labels: ['Food', 'Transport', 'Bills', 'Groceries'],
            on: 0,
          ),
          const SizedBox(height: 18),
          Text('Account', style: ts(12.5, FontWeight.w500, skin.text3)),
          const SizedBox(height: 10),
          const _Chips(labels: ['GCash', 'Cash', 'BPI', 'Maya'], on: 0),
          const SizedBox(height: 20),

          Row(
            children: const [
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
        Chip_(label: labels[i], on: i == on),
    ],
  );
}
