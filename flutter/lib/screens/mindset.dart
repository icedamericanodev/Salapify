// Money mindset: today's lesson (a doorway into the Learn track), a quick
// impulse-spending check, and a running list of small wins. Ported from the
// RN mindset screen. Tips are currency neutral. Wins are saved on the device
// in data.wins, which the backup already carries.

import 'package:flutter/material.dart';

import '../content/lessons.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';
import 'learn.dart';

// The impulse check questions, verbatim from the RN screen.
const _questions = [
  'Do I actually need this?',
  'Can I wait 24 hours and still want it?',
  'Does it fit my budget this month?',
];

class MindsetScreen extends StatefulWidget {
  final SalapifyStore store;
  const MindsetScreen({super.key, required this.store});

  @override
  State<MindsetScreen> createState() => _MindsetScreenState();
}

class _MindsetScreenState extends State<MindsetScreen> {
  final _checks = [false, false, false];
  final _winText = TextEditingController();

  @override
  void dispose() {
    _winText.dispose();
    super.dispose();
  }

  void _addWin() {
    final text = _winText.text.trim();
    if (text.isEmpty) return;
    if (widget.store.canWrite) widget.store.addWin(text);
    _winText.clear();
    FocusScope.of(context).unfocus();
  }

  List<Map<String, dynamic>> _wins() {
    final raw = widget.store.data['wins'];
    return [
      for (final w in (raw is List ? raw : const []))
        if (w is Map) w.cast<String, dynamic>(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lesson = lessonOfTheDay(DateTime.now());
    final yesCount = _checks.where((v) => v).length;
    final allYes = yesCount == 3;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Money mindset',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final wins = _wins().reversed.toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // Today's lesson: a doorway into the Learn track.
                PressableScale(
                  child: Card(
                    color: Barako.surfaceRaised,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Barako.primary),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LearnScreen(store: widget.store),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("TODAY'S LESSON",
                                style: Barako.kickerStyle
                                    .copyWith(color: Barako.primaryText)),
                            const SizedBox(height: 8),
                            Text('${lesson['emoji']}  ${lesson['title']}',
                                style: TextStyle(
                                    color: Barako.text,
                                    fontSize: 16,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(lesson['summary'] as String,
                                style: TextStyle(
                                    color: Barako.textSecondary,
                                    fontSize: 13,
                                    height: 1.4)),
                            const SizedBox(height: 8),
                            Text('Read this and more in Money lessons ›',
                                style: TextStyle(
                                    color: Barako.primaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Impulse check.
                Text('IMPULSE CHECK', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < _questions.length; i++)
                          _questionRow(i),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              allYes
                                  ? 'Looks like a thoughtful buy. Go for it.'
                                  : 'Maybe wait a bit before buying.',
                              style: TextStyle(
                                  color:
                                      allYes ? Barako.primary : Barako.warning,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Small wins.
                Text('SMALL WINS', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _winText,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addWin(),
                        style: TextStyle(color: Barako.text, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'e.g. Packed lunch all week',
                          hintStyle: TextStyle(color: Barako.faint),
                          filled: true,
                          fillColor: Barako.card,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Barako.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Barako.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Barako.primary),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _addWin,
                      style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      child: const Text('Add',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: wins.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text('No wins yet. Add a small one above.',
                                style: TextStyle(
                                    color: Barako.faint, fontSize: 13)),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < wins.length; i++)
                                _winRow(wins[i], i > 0),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _questionRow(int i) {
    final on = _checks[i];
    return InkWell(
      onTap: () => setState(() => _checks[i] = !_checks[i]),
      child: Container(
        decoration: i > 0
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Barako.border, width: 0.5)))
            : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(on ? Icons.check_box : Icons.check_box_outline_blank,
                color: on ? Barako.primary : Barako.muted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_questions[i],
                  style: TextStyle(color: Barako.text, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _winRow(Map<String, dynamic> w, bool divided) {
    return Container(
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Barako.border, width: 0.5)))
          : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text('🎉 ${w['text']}',
                style: TextStyle(color: Barako.text, fontSize: 15)),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              if (widget.store.canWrite) {
                widget.store.deleteWin(w['id'] as String);
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, color: Barako.faint, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
