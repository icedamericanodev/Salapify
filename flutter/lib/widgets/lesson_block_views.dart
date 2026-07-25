// One widget per block kind.
//
// The design rule these follow: each block should look like WHAT IT IS at a
// glance, without reading it. A nugget is a short line with a tick. A story is
// a tinted card with a person's name on it. A trap is two halves, before and
// after. A challenge is bordered in the accent colour because it asks
// something of you. Scrolling a lesson should feel like scrolling a
// conversation, where the shape of each turn tells you what kind of turn it is.
//
// The opposite failure, which the previous reader had, is every section
// rendering as the same paragraph block with a different heading. That is a
// document with labels on it.
//
// Motion is deliberately small: a short fade and rise, staggered slightly down
// the page. Enough to feel alive on arrival, never enough to make someone wait.

import 'package:flutter/material.dart';

import '../content/lesson_blocks.dart';
import '../theme.dart';

/// Fade and rise, once, on first build. Stagger is capped so a long lesson
/// never makes the last card arrive noticeably late.
class RiseIn extends StatefulWidget {
  final Widget child;
  final int index;
  const RiseIn({super.key, required this.child, this.index = 0});

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    final delayMs = (widget.index.clamp(0, 6)) * 45;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 12 * (1 - _fade.value)),
        child: child,
      ),
      child: widget.child,
    ),
  );
}

/// The personal line. Styled as a quiet aside from the app, not as content,
/// and visibly different when it is the honest fallback rather than a real
/// observation, so a generic line can never read as a personal one.
class InsightView extends StatelessWidget {
  final String text;
  final bool personalized;
  const InsightView({
    super.key,
    required this.text,
    required this.personalized,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: personalized ? Barako.positiveSurface : null,
        border: Border.all(
          color: personalized ? Barako.positiveBorder : Barako.border,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            personalized ? Icons.auto_awesome : Icons.lock_clock_outlined,
            size: 16,
            color: personalized ? Barako.primary : Barako.faint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: personalized ? Barako.text : Barako.muted,
                fontSize: 13,
                height: 1.45,
                fontWeight: personalized ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProseView extends StatelessWidget {
  final ProseBlock block;
  const ProseView(this.block, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (block.heading.isNotEmpty) ...[
        Text(block.heading.toUpperCase(), style: Barako.kickerStyle),
        const SizedBox(height: 8),
      ],
      for (final p in block.paragraphs)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            p,
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ),
    ],
  );
}

class NuggetsView extends StatelessWidget {
  final NuggetsBlock block;
  const NuggetsView(this.block, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in block.items)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Barako.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check, size: 16, color: Barako.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    color: Barako.text,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

/// Question first, answer on tap. The delay is the teaching device: a guess
/// made before the reveal is what makes the answer stick.
class DiscoveryView extends StatefulWidget {
  final DiscoveryBlock block;
  final VoidCallback? onRevealed;
  const DiscoveryView(this.block, {super.key, this.onRevealed});

  @override
  State<DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<DiscoveryView> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Barako.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THINK FIRST', style: Barako.kickerStyle),
          const SizedBox(height: 8),
          Text(
            widget.block.question,
            style: TextStyle(
              color: Barako.text,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? Text(
                    widget.block.reveal,
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _open = true);
                        widget.onRevealed?.call();
                      },
                      child: const Text('Show me'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class StoryView extends StatelessWidget {
  final StoryBlock block;
  const StoryView(this.block, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Barako.surfaceRaised,
      borderRadius: BorderRadius.circular(18),
      border: Border(left: BorderSide(color: Barako.primary, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.who.isNotEmpty) ...[
          Text(block.who.toUpperCase(), style: Barako.kickerStyle),
          const SizedBox(height: 6),
        ],
        Text(
          block.text,
          style: TextStyle(
            color: Barako.textSecondary,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    ),
  );
}

/// A flow as a column of steps with connectors. Widgets, not an image, so it
/// scales with the system font and reads aloud correctly.
class DiagramView extends StatelessWidget {
  final DiagramBlock block;
  const DiagramView(this.block, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < block.steps.length; i++) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: i == block.steps.length - 1
                  ? Barako.primary
                  : Barako.border,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            block.steps[i],
            textAlign: TextAlign.center,
            style: TextStyle(
              color: i == block.steps.length - 1
                  ? Barako.primaryText
                  : Barako.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (i < block.steps.length - 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Barako.faint,
            ),
          ),
      ],
      if (block.caption.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          block.caption,
          textAlign: TextAlign.center,
          style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.4),
        ),
      ],
    ],
  );
}

class TrapView extends StatelessWidget {
  final TrapBlock block;
  const TrapView(this.block, {super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _half(
        'WHAT MOST PEOPLE DO',
        block.mostPeople,
        Barako.border,
        Barako.muted,
      ),
      const SizedBox(height: 8),
      _half(
        'WHAT USUALLY WORKS BETTER',
        block.worksBetter,
        Barako.positiveBorder,
        Barako.text,
      ),
    ],
  );

  Widget _half(String kicker, String text, Color border, Color textColor) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(kicker, style: Barako.kickerStyle),
            const SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(color: textColor, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      );
}

/// Guess first, then go and look. The button does not check the answer,
/// because the point is the comparison the learner makes themselves.
class ChallengeView extends StatelessWidget {
  final ChallengeBlock block;
  final VoidCallback? onAccepted;
  const ChallengeView(this.block, {super.key, this.onAccepted});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border.all(color: Barako.primary),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt_outlined, size: 16, color: Barako.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text('ONE MINUTE CHALLENGE', style: Barako.kickerStyle),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          block.prompt,
          style: TextStyle(
            color: Barako.text,
            fontSize: 15,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (block.compare.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            block.compare,
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ],
    ),
  );
}

class ReflectionView extends StatelessWidget {
  final ReflectionBlock block;
  const ReflectionView(this.block, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
    decoration: BoxDecoration(
      color: Barako.surfaceRaised,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      block.line,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: Barako.displayFont,
        color: Barako.text,
        fontSize: 19,
        height: 1.35,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The one dispatcher. Sealed blocks mean a new kind is a compile error here
/// until it has a view, instead of silently rendering as nothing.
Widget viewForBlock(
  LessonBlock block, {
  VoidCallback? onRevealed,
}) => switch (block) {
  ProseBlock() => ProseView(block),
  NuggetsBlock() => NuggetsView(block),
  DiscoveryBlock() => DiscoveryView(block, onRevealed: onRevealed),
  StoryBlock() => StoryView(block),
  DiagramBlock() => DiagramView(block),
  TrapBlock() => TrapView(block),
  ChallengeBlock() => ChallengeView(block),
  ReflectionBlock() => ReflectionView(block),
};
