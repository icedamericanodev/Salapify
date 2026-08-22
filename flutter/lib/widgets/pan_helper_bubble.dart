// Pan's floating helper, f4.65. A small draggable Pan that rides the edge of
// every main tab and, on a tap, opens a sheet of swipeable tips that each send
// you to the right screen or open Pan's plain-words Q&A.
//
// It reuses the existing pieces so it cannot drift: the face is [PanMascot] (the
// one shared mascot, a fixed orange on every theme), the tips are the pure
// [panTips] data, and the navigation is handed back to the shell through
// [onTipTap] rather than owned here, so this widget never learns the route map.
//
// It is chat-head shaped on purpose: drag it anywhere, and on release it snaps
// to the nearer side and remembers where it sat, so it is never in the way of
// what you are reading and never lost. The whole thing can be turned off in
// Appearance; when off the shell simply does not mount it.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/pan_mood.dart' show PanMood;
import '../money/pan_tips.dart';
import '../theme.dart';
import '../typography.dart';
import 'pan_mascot.dart' show PanMascot;

class PanHelperBubble extends StatefulWidget {
  final SalapifyStore store;

  /// Called with the tapped tip so the shell can navigate (switch a tab, push
  /// Debts, or open Pan). The sheet closes itself first.
  final void Function(PanTip) onTipTap;

  // Not const: build reads mutable Barako getters for the disc behind Pan.
  // ignore: prefer_const_constructors_in_immutables
  PanHelperBubble({super.key, required this.store, required this.onTipTap});

  @override
  State<PanHelperBubble> createState() => _PanHelperBubbleState();
}

class _PanHelperBubbleState extends State<PanHelperBubble> {
  static const double _size = 56;
  // The vertical band the bubble is allowed to sit in, as a fraction of the
  // body height: never under the top inset, never over the FAB and nav bar.
  static const double _minY = 0.06;
  static const double _maxY = 0.82;

  // Live drag state. When dragging, _dragOffset holds the raw top-left in the
  // body's coordinate space; otherwise the bubble is placed from the persisted
  // side and y fraction.
  Offset? _dragOffset;

  // Default to the LEFT edge so Pan never stacks on the Log FAB at bottom-right,
  // and mid-height so he sits clear of the header. Both are remembered once the
  // person drags him somewhere they prefer.
  bool get _rightSide =>
      (widget.store.data['settings'] as Map?)?['panHelperSide'] == 'right';

  double get _y {
    final v = (widget.store.data['settings'] as Map?)?['panHelperY'];
    final d = v is num ? v.toDouble() : 0.5;
    return d.clamp(_minY, _maxY);
  }

  void _persist(bool right, double y) {
    widget.store.setSetting('panHelperSide', right ? 'right' : 'left');
    widget.store.setSetting('panHelperY', y.clamp(_minY, _maxY));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        const margin = 12.0;
        // Resting position: the persisted side, and y as a fraction of height,
        // clamped so a tiny screen still lands it on-screen. While dragging,
        // _dragOffset wins.
        final restingLeft = _rightSide ? w - _size - margin : margin;
        final restingTop = (_y * h).clamp(_minY * h, _maxY * h);
        final left = _dragOffset?.dx ?? restingLeft;
        final top = _dragOffset?.dy ?? restingTop;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openTips(context),
                onPanUpdate: (d) {
                  setState(() {
                    final cur = _dragOffset ?? Offset(restingLeft, _y * h);
                    var nx = cur.dx + d.delta.dx;
                    var ny = cur.dy + d.delta.dy;
                    nx = nx.clamp(margin, w - _size - margin);
                    ny = ny.clamp(_minY * h, _maxY * h);
                    _dragOffset = Offset(nx, ny);
                  });
                },
                onPanEnd: (_) {
                  final o = _dragOffset;
                  if (o == null) return;
                  // Snap to the nearer side, keep the vertical fraction.
                  final right = (o.dx + _size / 2) > w / 2;
                  final yFrac = (o.dy / h).clamp(_minY, _maxY);
                  _persist(right, yFrac);
                  setState(() => _dragOffset = null);
                },
                child: _bubble(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bubble() {
    return Semantics(
      button: true,
      label: 'Pan, your money helper. Opens a few quick tips.',
      child: ExcludeSemantics(
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            // The same dark disc the Menu banner gives Pan, so he keeps an edge
            // on a warm-accented theme instead of dissolving into it.
            color: Barako.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Barako.background.withValues(alpha: 0.55), width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: PanMascot(mood: PanMood.happy, size: _size - 14),
        ),
      ),
    );
  }

  void _openTips(BuildContext context) {
    Haptics.select();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Barako.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _PanTipsSheet(
        onTipTap: (tip) {
          Navigator.of(sheetContext).pop();
          widget.onTipTap(tip);
        },
      ),
    );
  }
}

class _PanTipsSheet extends StatefulWidget {
  final void Function(PanTip) onTipTap;
  const _PanTipsSheet({required this.onTipTap});

  @override
  State<_PanTipsSheet> createState() => _PanTipsSheetState();
}

class _PanTipsSheetState extends State<_PanTipsSheet> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Barako.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Barako.background.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: PanMascot(mood: PanMood.happy, size: 30),
                ),
                const SizedBox(width: Gap.sm),
                Text('Pan says', style: Barako.kickerStyle),
              ],
            ),
            const SizedBox(height: Gap.md),
            SizedBox(
              height: 176,
              child: PageView.builder(
                controller: _controller,
                itemCount: panTips.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _tipPage(panTips[i]),
              ),
            ),
            const SizedBox(height: Gap.md),
            // The dots, so it reads as swipeable and shows where you are.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < panTips.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Container(
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? Barako.primary : Barako.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipPage(PanTip tip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tip.title, style: AppText.subtitle.w7),
        const SizedBox(height: Gap.sm),
        Expanded(
          child: Text(
            tip.body,
            style: AppText.small.tint(Barako.textSecondary).copyWith(
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: Gap.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => widget.onTipTap(tip),
            child: Text(tip.ctaLabel),
          ),
        ),
      ],
    );
  }
}
