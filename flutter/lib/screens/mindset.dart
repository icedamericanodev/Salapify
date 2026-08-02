// Money mindset: a decision check for an impulse buy (the primary section),
// today's lesson below it (a doorway into the Learn track), and a running
// list of small wins. Wins are saved on the device in data.wins, which the
// backup already carries.
//
// The lesson card reads through content/lesson_model.dart's lessonFromMap,
// the same typed boundary learn.dart uses, instead of indexing the raw
// authoring map directly. The raw lessons never carried an 'emoji' field
// (they carry 'icon', a semantic name resolved by widgets/salapify_icon.dart)
// so reading lesson['emoji'] here printed the literal word "null" in front of
// every lesson title. Going through the typed lesson and its icon widget
// makes that class of bug impossible: a missing field falls back to '' (or
// the resolver's neutral marker for an unknown icon name), never to Dart's
// null string.

import 'package:flutter/material.dart';

import '../content/lesson_model.dart';
import '../content/lessons.dart';
import '../data/store.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/segmented.dart';
import 'learn.dart';
import 'shell.dart';

// The decision-check questions, in the order the verdict logic below reads
// them.
const _questions = [
  'Is this essential right now?',
  'Can I afford it without using money reserved for bills, debt, or goals?',
  'Have I wanted it for at least 24 hours?',
];

/// The three deterministic outcomes of the decision check.
enum _Verdict { fitsPlan, pause24h, notInPlan }

/// Null until every question has an answer, so the screen shows a neutral
/// state rather than a verdict computed from partial information.
_Verdict? _computeVerdict(List<bool?> answers) {
  if (answers.any((a) => a == null)) return null;
  final essential = answers[0]!;
  final affordableWithoutReserved = answers[1]!;
  final waited24h = answers[2]!;
  // Touching money reserved for bills, debt, or goals rules it out on its
  // own, essential or not: the plan already promised that money elsewhere.
  if (!affordableWithoutReserved) return _Verdict.notInPlan;
  if (!essential && !waited24h) return _Verdict.pause24h;
  return _Verdict.fitsPlan;
}

/// The verdict word, its color, and a non-chromatic severity icon. Mirrors
/// the shape of AffordCard's _verdictHead in afford_card.dart.
(String, Color, IconData) _verdictHead(_Verdict v) => switch (v) {
  _Verdict.fitsPlan => ('Fits your plan', Barako.primary, salapifyIcon('done')),
  _Verdict.pause24h => (
    'Pause for 24 hours',
    Barako.warning,
    salapifyIcon('paused'),
  ),
  _Verdict.notInPlan => (
    'Not in the plan right now',
    Barako.warningStrong,
    salapifyIcon('blocked'),
  ),
};

/// A one-sentence reason, built from the actual answers rather than a fixed
/// string per verdict, so it stays honest about which answer decided it.
String _whyText(_Verdict v, List<bool?> answers) {
  final essential = answers[0]!;
  final waited24h = answers[2]!;
  switch (v) {
    case _Verdict.notInPlan:
      return 'It would use money already reserved for bills, debt, or goals.';
    case _Verdict.pause24h:
      return "It is not essential right now, and you have not wanted it for "
          "a full 24 hours yet.";
    case _Verdict.fitsPlan:
      if (essential) {
        return 'It is essential, and it will not touch money reserved for '
            'bills, debt, or goals.';
      }
      return waited24h
          ? 'It is not essential, but you have wanted it for at least 24 '
                'hours and it will not touch your reserved money.'
          : 'It will not touch money reserved for bills, debt, or goals.';
  }
}

/// Never blank, never the literal word "null": a missing lesson field falls
/// back to this instead.
String _safe(String value, String fallback) =>
    value.trim().isEmpty ? fallback : value;

const _lessonTitleFallback = "Today's lesson";
const _lessonSummaryFallback = 'Check back soon for a new tip.';

/// The exact title and summary the lesson card renders for a raw authoring
/// map, fallbacks included. Exposed only so a lesson with a missing title or
/// summary can be proven safe directly, without waiting for the day-of-year
/// rotation in lessonOfTheDay to land on a broken real entry (today's real
/// content never is one; this is what stops a future one from reprinting the
/// "null" bug this screen shipped with).
@visibleForTesting
String mindsetLessonTitle(Map<String, dynamic> rawLesson) =>
    _safe(lessonFromMap(rawLesson).title, _lessonTitleFallback);

@visibleForTesting
String mindsetLessonSummary(Map<String, dynamic> rawLesson) =>
    _safe(lessonFromMap(rawLesson).summary, _lessonSummaryFallback);

class MindsetScreen extends StatefulWidget {
  /// Threaded through to Money courses so lesson actions that jump to a
  /// bottom tab keep working when courses are opened from here.
  final void Function(Destination)? onSwitchTab;
  final SalapifyStore store;
  const MindsetScreen({super.key, required this.store, this.onSwitchTab});

  @override
  State<MindsetScreen> createState() => _MindsetScreenState();
}

class _MindsetScreenState extends State<MindsetScreen> {
  final List<bool?> _answers = List<bool?>.filled(_questions.length, null);
  final _winText = TextEditingController();

  void _clearCheck() {
    setState(() {
      for (var i = 0; i < _answers.length; i++) {
        _answers[i] = null;
      }
    });
  }

  @override
  void dispose() {
    _winText.dispose();
    super.dispose();
  }

  void _addWin() {
    final text = _winText.text.trim();
    if (text.isEmpty) return;
    // If saving is off (a prior load failed), keep the typed win in the box
    // rather than silently eating it, and never write over data we could not
    // read.
    if (!widget.store.canWrite) return;
    widget.store.addWin(text);
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

  void _deleteWin(Map<String, dynamic> w) {
    // A win imported from a hand-edited backup can lack a string id (sanitize
    // keeps wins verbatim), so read it defensively: the delete no-ops instead
    // of crashing, matching the RN screen.
    final id = w['id'];
    if (id is! String || !widget.store.canWrite) return;
    final text = w['text'];
    widget.store.deleteWin(id);
    // A win is user-typed content, so offer a one tap undo rather than losing
    // it silently on a stray tap.
    if (text is String && text.isNotEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Win removed'),
            duration: const Duration(seconds: 5),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                if (widget.store.canWrite) widget.store.addWin(text);
              },
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = lessonFromMap(lessonOfTheDay(DateTime.now()));
    final lessonTitle = _safe(lesson.title, _lessonTitleFallback);
    final lessonSummary = _safe(lesson.summary, _lessonSummaryFallback);
    final verdict = _computeVerdict(_answers);
    final answered = _answers.any((a) => a != null);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Money mindset',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final wins = _wins().reversed.toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                // The decision check: the primary reason someone opens this
                // screen, so it leads.
                Text('IMPULSE CHECK', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        for (var i = 0; i < _questions.length; i++)
                          _questionRow(i),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _verdictSection(verdict),
                        ),
                        if (answered)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _clearCheck,
                                child: Text(
                                  'Clear check',
                                  style: TextStyle(color: Barako.muted),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                          builder: (_) => LearnScreen(
                            store: widget.store,
                            onSwitchTab: widget.onSwitchTab,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TODAY'S LESSON",
                              style: Barako.kickerStyle.copyWith(
                                color: Barako.primaryText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SalapifyGlyph(
                                  lesson.icon,
                                  size: 22,
                                  boxed: false,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    lessonTitle,
                                    style: AppText.bodyLg.w7.copyWith(
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lessonSummary,
                              style: AppText.small.copyWith(height: 1.4),
                            ),
                            const SizedBox(height: 8),
                            // The go-deeper affordance is a real glyph now,
                            // not a '›' typeset into the sentence.
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Read this and more in Money courses',
                                    style: AppText.small.w6.tint(
                                      Barako.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  salapifyIcon('forward'),
                                  size: 16,
                                  color: Barako.primaryText,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
                        style: AppText.body,
                        decoration: InputDecoration(
                          hintText: 'e.g. Packed lunch all week',
                          hintStyle: TextStyle(color: Barako.faint),
                          filled: true,
                          fillColor: Barako.card,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
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
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      child: const Text(
                        'Add',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: wins.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No wins yet. Add a small one above.',
                              style: AppText.small.tint(Barako.faint),
                            ),
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
    return Container(
      decoration: i > 0
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Barako.border, width: 0.5)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_questions[i], style: AppText.body),
          const SizedBox(height: 10),
          Segmented<bool?>(
            options: const [
              SegmentOption(value: true, label: 'Yes'),
              SegmentOption(value: false, label: 'No'),
            ],
            current: _answers[i],
            onPick: (v) => setState(() => _answers[i] = v),
          ),
        ],
      ),
    );
  }

  // Neutral until every question has an answer (verdict is null), then the
  // verdict word, why it landed there, and updates live as an answer changes
  // because it is derived straight from _answers on every build.
  Widget _verdictSection(_Verdict? verdict) {
    if (verdict == null) {
      return Row(
        children: [
          Icon(salapifyIcon('help'), color: Barako.muted, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Answer all three questions to see where this fits.',
              style: AppText.small.tint(Barako.muted),
            ),
          ),
        ],
      );
    }
    final (word, color, icon) = _verdictHead(verdict);
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(child: Text(word, style: AppText.small.w6.tint(color))),
            ],
          ),
          const SizedBox(height: 8),
          Text('Why this result', style: AppText.small.w6),
          const SizedBox(height: 2),
          Text(
            _whyText(verdict, _answers),
            style: AppText.small.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _winRow(Map<String, dynamic> w, bool divided) {
    return Container(
      decoration: divided
          ? BoxDecoration(
              border: Border(top: BorderSide(color: Barako.border, width: 0.5)),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          SalapifyGlyph('celebrate', size: 18, boxed: false),
          const SizedBox(width: 8),
          Expanded(child: Text('${w['text'] ?? ''}', style: AppText.body)),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _deleteWin(w),
            iconSize: 18,
            visualDensity: VisualDensity.standard,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            tooltip: 'Delete win',
            icon: Icon(salapifyIcon('close'), color: Barako.faint),
          ),
        ],
      ),
    );
  }
}
