// Learn: short, plain, Filipino-grounded money lessons, reached from Tools.
// Reading a lesson marks it done on the device (settings.lessonsRead). Pure
// content from lib/content/lessons.dart, no network, works offline. Education
// stays free, always.

import 'package:flutter/material.dart';

import '../content/lessons.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';

class LearnScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Optional lesson id to open straight away (e.g. from a coach nudge).
  final String? focusId;
  const LearnScreen({super.key, required this.store, this.focusId});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  @override
  void initState() {
    super.initState();
    final id = widget.focusId;
    if (id != null) {
      final l = lessonById(id);
      if (l != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _open(context, l));
      }
    }
  }

  List<String> _readIds() {
    final s = widget.store.data['settings'];
    final raw = s is Map ? s['lessonsRead'] : null;
    return [
      for (final x in (raw is List ? raw : const []))
        if (x is String) x,
    ];
  }

  void _open(BuildContext context, Map<String, dynamic> lesson) {
    widget.store.markLessonRead(lesson['id'] as String);
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _LessonReader(lesson: lesson)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Money lessons',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final read = _readIds().toSet();
            final readCount = lessons.where((l) => read.contains(l['id'])).length;
            final featured = lessonOfTheDay(DateTime.now());
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR PROGRESS', style: Barako.kickerStyle),
                        const SizedBox(height: 6),
                        Text('$readCount of ${lessons.length} lessons read',
                            style: TextStyle(
                                color: Barako.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Short reads on your money, always free.',
                            style:
                                TextStyle(color: Barako.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('LESSON OF THE DAY', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                _lessonCard(featured, read.contains(featured['id']),
                    featured: true),
                const SizedBox(height: 16),
                Text('ALL LESSONS', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                for (final l in lessons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _lessonCard(l, read.contains(l['id'])),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lessonCard(Map<String, dynamic> l, bool isRead,
      {bool featured = false}) {
    return PressableScale(
      child: Card(
        color: featured ? Barako.surfaceRaised : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(context, l),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(l['emoji'] as String,
                    style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l['title'] as String,
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(l['summary'] as String,
                          style:
                              TextStyle(color: Barako.muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text('${l['minutes']} min read',
                          style:
                              TextStyle(color: Barako.faint, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                    isRead
                        ? Icons.check_circle
                        : Icons.chevron_right,
                    color: isRead ? Barako.primary : Barako.faint,
                    size: isRead ? 20 : 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The reading view for one lesson: emoji, title, minutes, then the body.
class _LessonReader extends StatelessWidget {
  final Map<String, dynamic> lesson;
  const _LessonReader({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final body = (lesson['body'] as List).cast<String>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(lesson['emoji'] as String,
                style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(lesson['title'] as String,
                style: TextStyle(
                    fontFamily: Barako.displayFont,
                    color: Barako.text,
                    fontSize: 26,
                    height: 1.1,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${lesson['minutes']} min read',
                style: TextStyle(color: Barako.muted, fontSize: 12)),
            const SizedBox(height: 20),
            for (final p in body)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(p,
                    style: TextStyle(
                        color: Barako.textSecondary,
                        fontSize: 15,
                        height: 1.55)),
              ),
          ],
        ),
      ),
    );
  }
}
