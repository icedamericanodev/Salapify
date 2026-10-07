// Financial Guides: the browse hub for Salapify's short money explainers, and
// the reader for one guide. Reached from Menu > Learn, beside Money courses.
//
// The hub is a discovery layer OVER content the app already teaches: category
// chips, a Popular row, a Browse by Topic grid with live counts, a Continue
// Learning row driven by real per-guide progress, an Explore Money Courses
// hero, and a Pan tip. The reader renders one guide as plain prose and, at the
// end, offers the fuller Money Courses lesson behind it.
//
// Everything here reuses the existing system (Barako, the shared widgets) and
// invents no new primitive. Guides are static content, so there is no load or
// network state; the only degraded case is a read-only store (after a failed
// data load), where reading still works and progress simply is not recorded,
// the same best-effort rule the lesson reader follows.

import 'package:flutter/material.dart';

import '../content/financial_guides.dart';
import '../data/store.dart';
import '../money/guide_progress.dart';
import '../money/pan_mood.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/choice_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/lesson_block_views.dart' show RiseIn;
import '../widgets/pan_mascot.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/progress_bar.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/salapify_motion.dart';
import '../widgets/screen_header.dart' show HeaderTier, headerStyle;
import '../widgets/section.dart';
import 'learn.dart';
import 'pan.dart';
import 'shell.dart';

class FinancialGuidesScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Lets the Explore Money Courses and Ask Pan links reach a bottom tab when
  /// a lesson action or a Pan reply wants one. Optional; every push works
  /// without it.
  final void Function(Destination)? onSwitchTab;
  final VoidCallback? onOpenReceivables;
  final VoidCallback? onOpenPayables;

  /// Optional guide id to open straight away, e.g. from a deep link or a Pan
  /// suggestion. An id that matches no guide is a safe no-op, the same
  /// convention LearnScreen.focusId follows, never a crash.
  final String? focusGuideId;

  const FinancialGuidesScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onOpenReceivables,
    this.onOpenPayables,
    this.focusGuideId,
  });

  @override
  State<FinancialGuidesScreen> createState() => _FinancialGuidesScreenState();
}

class _FinancialGuidesScreenState extends State<FinancialGuidesScreen> {
  /// The active topic filter. Null is the All view: the full sectioned hub.
  GuideCategory? _cat;

  @override
  void initState() {
    super.initState();
    final id = widget.focusGuideId;
    if (id == null) return;
    final g = guideById(id);
    if (g != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openGuide(g));
    }
  }

  void _pick(GuideCategory? c) {
    if (_cat == c) return;
    Haptics.select();
    setState(() => _cat = c);
  }

  void _openCourses({String? focusId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearnScreen(
          store: widget.store,
          focusId: focusId,
          onSwitchTab: widget.onSwitchTab,
        ),
      ),
    );
  }

  void _openPan() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PanScreen(
          store: widget.store,
          onSwitchTab: widget.onSwitchTab,
          onOpenReceivables: widget.onOpenReceivables,
          onOpenPayables: widget.onOpenPayables,
        ),
      ),
    );
  }

  void _openGuide(FinancialGuide g, {bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (_) => _GuideReader(
        guide: g,
        store: widget.store,
        onExploreCourse: (id) => _openCourses(focusId: id),
        onOpenGuide: _openGuide,
      ),
    );
    // Opening the NEXT guide replaces this reader rather than stacking on it,
    // so a chain of Next taps leaves one back step to the hub instead of one
    // per guide, and "Back to guides" always means the hub. The same rule the
    // lesson reader follows.
    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            GuideSearchScreen(store: widget.store, onOpenGuide: _openGuide),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Guides'),
        actions: [
          IconButton(
            icon: Icon(salapifyIcon('search'), size: 22, color: Barako.text),
            tooltip: 'Search guides',
            onPressed: _openSearch,
          ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final progress = widget.store.guideProgress;
            return ListView(
              padding: Insets.screen,
              children: [
                RiseIn(
                  index: 0,
                  child: Text(
                    'Simple guides to help you understand and manage your '
                    'money better.',
                    style: AppText.small
                        .tint(Barako.muted)
                        .copyWith(height: 1.45),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                RiseIn(index: 1, child: _chipRow()),
                const SizedBox(height: Gap.lg),
                RiseIn(index: 2, child: _hero()),
                const SizedBox(height: Gap.gutter),
                SalapifyFadeThrough(
                  stateKey: _cat ?? 'all',
                  child: _cat == null
                      ? _allView(progress)
                      : _categoryView(_cat!, progress),
                ),
                const SizedBox(height: Gap.gutter),
                RiseIn(index: 6, child: _panTip()),
              ],
            );
          },
        ),
      ),
    );
  }

  // The horizontal filter row: All, then every category in display order.
  Widget _chipRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: Gap.xs),
      child: Row(
        children: [
          SalapifyChoiceChip(
            label: 'All',
            selected: _cat == null,
            onSelected: (_) => _pick(null),
          ),
          for (final c in GuideCategory.values) ...[
            const SizedBox(width: Gap.sm),
            SalapifyChoiceChip(
              label: c.label,
              selected: _cat == c,
              onSelected: (_) => _pick(c),
            ),
          ],
        ],
      ),
    );
  }

  // The filled primary hero, Pan on a dark disc, an inverted CTA into the
  // fuller Money Courses. The one raised, coloured surface at the top.
  Widget _hero() {
    return Card(
      color: Barako.primary,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: Insets.hero,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Barako.background.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: PanMascot(mood: PanMood.happy, size: 56),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Learn. Apply. Grow.',
                    style: AppText.subtitle.w8.tint(Barako.onPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Short reads on real Philippine money questions, then use '
                    'it in Salapify. No jargon, no shame.',
                    style: AppText.small.tint(
                      Barako.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.onPrimary,
                      foregroundColor: Barako.primary,
                    ),
                    onPressed: () => _openCourses(),
                    child: const Text('Explore Money Courses'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // The All view: Continue (if any), Popular carousel, Browse grid.
  Widget _allView(Map<String, double> progress) {
    final continueList = [
      for (final g in allFinancialGuides)
        if (isGuideInProgress(progress[g.id] ?? 0)) g,
    ]..sort((a, b) => (progress[b.id] ?? 0).compareTo(progress[a.id] ?? 0));
    final popular = popularGuides();
    return Column(
      key: const ValueKey('all'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (continueList.isNotEmpty) ...[
          RiseIn(index: 3, child: Kicker('CONTINUE LEARNING')),
          const SizedBox(height: Gap.sm),
          for (final g in continueList) ...[
            _continueCard(g, progress[g.id] ?? 0),
            const SizedBox(height: Gap.md),
          ],
          const SizedBox(height: Gap.sm),
        ],
        if (popular.isNotEmpty) ...[
          RiseIn(index: 4, child: Kicker('POPULAR GUIDES')),
          const SizedBox(height: Gap.sm),
          // A horizontally scrolling rail. IntrinsicHeight plus a stretched
          // Row gives every card the height of the tallest, so the min-read
          // row lines up across cards, and nothing is a fixed height that
          // could overflow or force an ellipsis at a large font. No summary
          // is ever truncated, the same rule the lesson rows follow.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, g) in popular.indexed) ...[
                    if (i > 0) const SizedBox(width: Gap.md),
                    SizedBox(
                      width: 264,
                      child: _popularCard(g, i + 1, progress),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.gutter),
        ],
        RiseIn(index: 5, child: Kicker('BROWSE BY TOPIC')),
        const SizedBox(height: Gap.sm),
        _browseGrid(),
      ],
    );
  }

  // A single category: a flat vertical list of that topic's guides.
  Widget _categoryView(GuideCategory cat, Map<String, double> progress) {
    final list = guidesInCategory(cat);
    if (list.isEmpty) {
      return EmptyState(
        key: ValueKey('empty-${cat.name}'),
        icon: 'search',
        showPan: false,
        title: 'This shelf is still being written',
        body:
            'No guides here yet. While we finish them, the guides in Money '
            'Basics cover the ground most people need first.',
        actionLabel: 'Explore Money Courses',
        onAction: () => _openCourses(),
      );
    }
    return Column(
      key: ValueKey('cat-${cat.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(cat.label.toUpperCase()),
        const SizedBox(height: Gap.sm),
        for (final (i, g) in list.indexed) ...[
          RiseIn(index: i, child: _guideRow(g, progress[g.id] ?? 0)),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }

  // The 2-up grid of topics, dropping to 1 column at large font so a tile can
  // grow taller instead of clipping.
  Widget _browseGrid() {
    return LayoutBuilder(
      builder: (ctx, c) {
        final scale = MediaQuery.textScalerOf(ctx).scale(14) / 14;
        final cols = scale >= 1.5 ? 1 : 2;
        final w = (c.maxWidth - Gap.md * (cols - 1)) / cols;
        return Wrap(
          spacing: Gap.md,
          runSpacing: Gap.md,
          children: [
            for (final cat in GuideCategory.values)
              SizedBox(width: w, child: _topicCard(cat)),
          ],
        );
      },
    );
  }

  // ---- card composers (non-const: every one reads Barako in build) ----

  Widget _popularCard(FinancialGuide g, int rank, Map<String, double> prog) {
    final read = isGuideRead(prog[g.id] ?? 0);
    return Semantics(
      button: true,
      label:
          '${g.title}. ${g.category.label}. ${g.minutes} minute read. '
          '${g.summary}${read ? '. Read' : ''}',
      child: ExcludeSemantics(
        child: PressableScale(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () => _openGuide(g),
              child: Padding(
                padding: Insets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Barako.primary.withValues(
                              alpha: BarakoAlpha.tint,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$rank',
                            style: AppText.caption.w8.tint(Barako.primaryText),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        SalapifyGlyph(g.icon, size: 20),
                        const Spacer(),
                        if (read)
                          Icon(
                            salapifyIcon('selected'),
                            size: 16,
                            color: Barako.primary,
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.sm),
                    // No maxLines, no ellipsis: authored copy wraps in full,
                    // the same rule the lesson rows follow. The rail's
                    // IntrinsicHeight sizes every card to the tallest, so a
                    // longer summary grows the whole rail rather than being
                    // cut.
                    Text(
                      g.title,
                      style: read
                          ? AppText.subtitle.tint(Barako.muted)
                          : AppText.subtitle,
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      g.summary,
                      style: AppText.small
                          .tint(Barako.textSecondary)
                          .copyWith(height: 1.4),
                    ),
                    const SizedBox(height: Gap.sm),
                    // Pushes the meta to the bottom so it lines up across the
                    // stretched, equal-height cards. A Wrap, not a Row, so a
                    // long tag and the min-read drop to a second line at a
                    // large font instead of overflowing, the same pattern the
                    // lesson rows use.
                    const Spacer(),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _categoryTag(g.category),
                        Text(
                          '${g.minutes} min read',
                          style: AppText.micro.w4.tint(Barako.faint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _guideRow(FinancialGuide g, double fraction) {
    final read = isGuideRead(fraction);
    final started = isGuideInProgress(fraction);
    return Semantics(
      button: true,
      label:
          '${g.title}. ${g.category.label}. ${g.minutes} minute read. '
          '${g.summary}${read
              ? '. Read'
              : started
              ? '. In progress'
              : ''}',
      child: ExcludeSemantics(
        child: PressableScale(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () => _openGuide(g),
              child: Padding(
                padding: Insets.card,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SalapifyGlyph(g.icon, size: 22),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.title,
                            style: read
                                ? AppText.subtitle.tint(Barako.muted)
                                : AppText.subtitle,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            g.summary,
                            style: AppText.small
                                .tint(Barako.textSecondary)
                                .copyWith(height: 1.4),
                          ),
                          const SizedBox(height: Gap.sm),
                          Wrap(
                            spacing: Gap.sm,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _categoryTag(g.category),
                              Text(
                                '${g.minutes} min read',
                                style: AppText.micro.w4.tint(Barako.faint),
                              ),
                              if (read)
                                Icon(
                                  salapifyIcon('selected'),
                                  size: 14,
                                  color: Barako.primary,
                                )
                              else if (started)
                                Text(
                                  'Continue',
                                  style: AppText.micro.w7.tint(
                                    Barako.primaryText,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topicCard(GuideCategory cat) {
    final count = guideCountFor(cat);
    return Semantics(
      button: true,
      label: '${cat.label}. ${cat.blurb}. $count guides.',
      child: ExcludeSemantics(
        child: PressableScale(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () => _pick(cat),
              child: Padding(
                padding: Insets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SalapifyGlyph(cat.icon, size: 24),
                    const SizedBox(height: Gap.sm),
                    Text(cat.label, style: AppText.subtitle),
                    const SizedBox(height: Gap.xxs),
                    Text(cat.blurb, style: AppText.caption),
                    const SizedBox(height: Gap.sm),
                    Text(
                      '$count guides',
                      style: AppText.caption.w7.tint(Barako.primaryText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _continueCard(FinancialGuide g, double fraction) {
    final pct = (fraction * 100).round();
    return Semantics(
      button: true,
      label:
          'Continue ${g.title}. $pct percent read. ${g.minutes} minute read.',
      child: ExcludeSemantics(
        child: PressableScale(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () => _openGuide(g),
              child: Padding(
                padding: Insets.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SalapifyGlyph(g.icon, size: 22),
                        const SizedBox(width: Gap.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.title, style: AppText.subtitle),
                              const SizedBox(height: 3),
                              Text(
                                g.summary,
                                style: AppText.small
                                    .tint(Barako.textSecondary)
                                    .copyWith(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    SalapifyProgressBar(
                      value: fraction,
                      size: ProgressBarSize.micro,
                      semanticsLabel: null,
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      '$pct% read',
                      style: AppText.caption.w7.tint(Barako.primaryText),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panTip() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: Insets.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SalapifyGlyph('mind', size: 20),
                const SizedBox(width: Gap.sm),
                Text("PAN'S TIP", style: Barako.cardKickerStyle),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Pick one guide that matches a money decision you are actually '
              'facing this payday. One read you act on beats ten you only '
              'scrolled past.',
              style: AppText.small.copyWith(height: 1.45),
            ),
            const SizedBox(height: Gap.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _openPan,
                icon: Icon(salapifyIcon('mindset'), size: 18),
                label: const Text('Ask Pan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small bordered category pill, reusing the PHILIPPINES-tag shape from the
/// lesson reader so guides and lessons speak one visual language.
Widget _categoryTag(GuideCategory cat) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
  decoration: BoxDecoration(
    border: Border.all(color: Barako.border),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Text(
    cat.label.toUpperCase(),
    style: AppText.micro.w7.copyWith(letterSpacing: 1),
  ),
);

/// The reader for one guide: hero, prose sections, key takeaway, a link into
/// the fuller course, and a finish affordance. Modeled on learn.dart's
/// _LessonReader so a guide and a lesson feel like one app.
class _GuideReader extends StatefulWidget {
  final FinancialGuide guide;
  final SalapifyStore store;

  /// Opens the fuller Money Courses lesson behind this guide (or the hub when
  /// the id is null or unknown, which LearnScreen handles safely).
  final void Function(String? lessonId) onExploreCourse;

  /// Opens another guide. [replace] swaps this reader for the next one (the
  /// Next affordance), so the back stack does not grow one entry per guide.
  final void Function(FinancialGuide, {bool replace}) onOpenGuide;

  const _GuideReader({
    required this.guide,
    required this.store,
    required this.onExploreCourse,
    required this.onOpenGuide,
  });

  @override
  State<_GuideReader> createState() => _GuideReaderState();
}

class _GuideReaderState extends State<_GuideReader> {
  final ScrollController _scroll = ScrollController();

  /// The furthest scroll fraction reached, persisted on the way out so the
  /// Continue Learning row can resume this guide. Starts at whatever the store
  /// already knew, so a guide reopened after being read stays read.
  late double _maxFraction = widget.store.guideProgress[widget.guide.id] ?? 0.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    final f = (_scroll.offset / max).clamp(0.0, 1.0);
    if (f <= _maxFraction) return;
    final wasRead = isGuideRead(_maxFraction);
    // Tracked every frame, but WITHOUT a rebuild. The only thing build reads
    // from this is whether the guide is now read (the finish card), so the
    // screen only needs to change the moment that flips. Reaching the end
    // reads the guide with no button; persist that once, here. Otherwise the
    // final fraction is persisted on the way out (dispose). Scrolling back up
    // can never lower it, the store keeps the max.
    _maxFraction = f;
    if (isGuideRead(f) && !wasRead) {
      if (widget.store.canWrite) {
        widget.store.setGuideProgress(widget.guide.id, f);
      }
      setState(() {});
    }
  }

  void _markRead() {
    setState(() => _maxFraction = 1.0);
    if (widget.store.canWrite) widget.store.markGuideRead(widget.guide.id);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    // Best effort, fire and forget: record how far this reader got so a
    // meaningfully-started guide can be resumed. A stray flick below the
    // started threshold records nothing, so it never becomes a phantom
    // "0% read" Continue Learning row. A read-only store simply skips it.
    if (widget.store.canWrite && _maxFraction >= kGuideStartedThreshold) {
      widget.store.setGuideProgress(widget.guide.id, _maxFraction);
    }
    _scroll.dispose();
    super.dispose();
  }

  /// The next unread guide in catalog order, wrapping once, or null when the
  /// whole set is read.
  FinancialGuide? _next() {
    final all = allFinancialGuides;
    final here = all.indexWhere((g) => g.id == widget.guide.id);
    if (here < 0) return null;
    final progress = widget.store.guideProgress;
    for (var step = 1; step <= all.length; step++) {
      final g = all[(here + step) % all.length];
      if (g.id == widget.guide.id) break;
      if (!isGuideRead(progress[g.id] ?? 0)) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    var step = 0;
    final children = <Widget>[_hero(g), const SizedBox(height: 20)];

    for (final s in g.sections) {
      children.add(
        RiseIn(
          index: step++,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.heading, style: AppText.subtitle),
                const SizedBox(height: Gap.sm),
                for (final p in s.paragraphs) ...[
                  Text(p, style: AppText.body.copyWith(height: 1.5)),
                  const SizedBox(height: Gap.sm),
                ],
              ],
            ),
          ),
        ),
      );
    }

    children.add(RiseIn(index: step++, child: _takeaway(g)));
    children.add(const SizedBox(height: 16));
    children.add(RiseIn(index: step++, child: _deepDive(g)));
    children.add(const SizedBox(height: 16));
    children.add(RiseIn(index: step, child: _finishCard(g)));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${g.minutes} min read',
          style: AppText.caption.tint(Barako.muted),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hero(FinancialGuide g) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SalapifyGlyph(g.icon, size: 28),
      const SizedBox(height: 10),
      Row(
        children: [
          Text('${g.minutes} MIN READ', style: Barako.kickerStyle),
          const SizedBox(width: 8),
          _categoryTag(g.category),
        ],
      ),
      const SizedBox(height: 6),
      Text(g.title, style: headerStyle(HeaderTier.cover)),
      const SizedBox(height: 8),
      Text(
        g.summary,
        style: AppText.body.tint(Barako.muted).copyWith(height: 1.45),
      ),
    ],
  );

  Widget _takeaway(FinancialGuide g) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Barako.surfaceRaised,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('KEEP THIS', style: Barako.cardKickerStyle),
        const SizedBox(height: Gap.sm),
        Text(
          g.keyTakeaway,
          style: AppText.label.w4
              .tint(Barako.textSecondary)
              .copyWith(height: 1.5),
        ),
      ],
    ),
  );

  Widget _deepDive(FinancialGuide g) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => widget.onExploreCourse(g.deepDiveLessonId),
      icon: Icon(salapifyIcon('learning'), size: 18),
      label: Text(
        g.deepDiveLessonId != null
            ? 'Go deeper in Money Courses'
            : 'Explore Money Courses',
      ),
    ),
  );

  Widget _finishCard(FinancialGuide g) {
    final read = isGuideRead(_maxFraction);
    if (!read) {
      return OutlinedButton(
        onPressed: _markRead,
        child: const Text('Mark as read'),
      );
    }
    final next = _next();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            header: true,
            child: Row(
              children: [
                Icon(salapifyIcon('selected'), size: 18, color: Barako.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Read',
                    style: AppText.label.w7.tint(Barako.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            g.keyTakeaway,
            style: AppText.label.w4
                .tint(Barako.textSecondary)
                .copyWith(height: 1.5),
          ),
          if (next != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onOpenGuide(next, replace: true),
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Next: ${next.title}',
                      textAlign: TextAlign.center,
                      style: AppText.label.w7.tint(Barako.onPrimary),
                    ),
                    Text(
                      '${next.minutes} min read',
                      style: AppText.caption.tint(
                        Barako.onPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Back to guides'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A dedicated search over the guides: matches the query against a guide's
/// title, summary, and category. Its own screen so the AppBar search means
/// "find a guide", never the app-wide transaction search.
class GuideSearchScreen extends StatefulWidget {
  final SalapifyStore store;
  final void Function(FinancialGuide) onOpenGuide;

  const GuideSearchScreen({
    super.key,
    required this.store,
    required this.onOpenGuide,
  });

  @override
  State<GuideSearchScreen> createState() => _GuideSearchScreenState();
}

class _GuideSearchScreenState extends State<GuideSearchScreen> {
  String _query = '';

  List<FinancialGuide> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [
      for (final g in allFinancialGuides)
        if (g.title.toLowerCase().contains(q) ||
            g.summary.toLowerCase().contains(q) ||
            g.category.label.toLowerCase().contains(q))
          g,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final typing = _query.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: AppText.body,
          decoration: InputDecoration(
            hintText: 'Search guides',
            border: InputBorder.none,
            hintStyle: AppText.body.tint(Barako.faint),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      body: SafeArea(
        child: !typing
            ? _hint()
            : results.isEmpty
            ? _noResults()
            : ListView.separated(
                padding: Insets.screen,
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (_, i) => _resultTile(results[i]),
              ),
      ),
    );
  }

  Widget _hint() => Padding(
    padding: Insets.screen,
    child: Text(
      'Type a word like tax, ipon (savings), utang (debt), or MP2.',
      style: AppText.small.tint(Barako.muted).copyWith(height: 1.45),
    ),
  );

  Widget _noResults() => Padding(
    padding: Insets.screen,
    child: EmptyState(
      icon: 'search',
      showPan: false,
      title: 'No guide matches that yet',
      body:
          'Try a shorter word like tax, ipon, utang, or MP2, or browse the '
          'topics from the Financial Guides screen. We add new guides over '
          'time.',
    ),
  );

  Widget _resultTile(FinancialGuide g) {
    return Semantics(
      button: true,
      label:
          '${g.title}. ${g.category.label}. ${g.minutes} minute read. '
          '${g.summary}',
      child: ExcludeSemantics(
        child: PressableScale(
          child: Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () {
                // Guard a fast double-tap: once this search route is no longer
                // current, the first tap already popped it, so a second tap
                // must not pop the hub underneath.
                final route = ModalRoute.of(context);
                if (route == null || !route.isCurrent) return;
                Navigator.of(context).pop();
                widget.onOpenGuide(g);
              },
              child: Padding(
                padding: Insets.card,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SalapifyGlyph(g.icon, size: 22),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.title, style: AppText.subtitle),
                          const SizedBox(height: 3),
                          Text(
                            g.summary,
                            style: AppText.small
                                .tint(Barako.textSecondary)
                                .copyWith(height: 1.4),
                          ),
                          const SizedBox(height: Gap.sm),
                          Wrap(
                            spacing: Gap.sm,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _categoryTag(g.category),
                              Text(
                                '${g.minutes} min read',
                                style: AppText.micro.w4.tint(Barako.faint),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
