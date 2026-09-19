// The moment a debt clears or an utang settles, celebrated properly. Ported
// from the RN Celebration overlay: sixteen confetti pieces bursting from top
// center and falling under gravity, with a centered message pill, gone on
// its own inside two seconds. The app's happiest moment was a snackbar.
//
// Reduce motion, the RN contract exactly: no confetti at all, the pill
// appears instantly and holds a beat longer, the success buzz still fires
// (feedback is not motion), and the message is still announced to screen
// readers. The overlay ignores pointers, so it never blocks the screen.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';

/// Fire the celebration over the current screen. Safe to call from any
/// context inside the app's navigator; auto-dismisses itself.
void showCelebration(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  // The success buzz survives reduce motion on purpose: a confirmation is
  // feedback, not decoration. Flutter has no success-notification haptic,
  // so medium impact stands in.
  Haptics.milestone();
  // Spoken after a beat so it lands after any dialog dismiss settles, the
  // RN timing.
  final view = View.of(context);
  Future.delayed(const Duration(milliseconds: 340), () {
    SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
  });
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationOverlay(
      message: message,
      reduce: reduce,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _CelebrationOverlay extends StatefulWidget {
  final String message;
  final bool reduce;
  final VoidCallback onDone;
  // ignore: prefer_const_constructors_in_immutables
  _CelebrationOverlay({
    required this.message,
    required this.reduce,
    required this.onDone,
  });

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _Piece {
  final double startX, startY, width, fallY, driftX, spin, scale;
  final Color color;
  const _Piece({
    required this.startX,
    required this.startY,
    required this.width,
    required this.fallY,
    required this.driftX,
    required this.spin,
    required this.scale,
    required this.color,
  });
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  static const _fallMs = 1400;
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _fallMs),
  );
  final _rand = Random();
  List<_Piece>? _pieces;

  @override
  void initState() {
    super.initState();
    // Total wall clock mirrors RN: 260 enter + hold + 240 out. Reduce
    // motion holds slightly less since there is nothing to watch.
    final hold = widget.reduce ? 1100 : _fallMs - 150;
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (!widget.reduce) _progress.forward();
    });
    Future.delayed(Duration(milliseconds: 260 + hold + 240), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  List<_Piece> _buildPieces(double width) {
    // The win palette, tokens only so every theme celebrates in its own
    // colors. Never a warning hue, the RN rule.
    final colors = [
      Barako.primary,
      Barako.celebrate,
      Barako.caramel,
      Barako.primaryText,
    ];
    return List.generate(16, (i) {
      final r = _rand.nextDouble();
      final r2 = _rand.nextDouble();
      final w = 8 + r * 6;
      return _Piece(
        startX: width / 2 + (r2 - 0.5) * 80,
        startY: 90 + r * 40,
        width: w,
        fallY: 380 + r * 260,
        driftX: (r2 - 0.5) * width * 0.9,
        spin: (r - 0.5) * 720,
        scale: 0.8 + r2 * 0.6,
        color: colors[i % colors.length],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    _pieces ??= widget.reduce ? const [] : _buildPieces(width);
    return IgnorePointer(
      child: ExcludeSemantics(
        // The announcement above is the accessible version of this moment;
        // the visuals are decoration.
        child: Stack(
          children: [
            if (!widget.reduce)
              AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  final p = _progress.value;
                  return Stack(
                    children: [
                      for (final piece in _pieces!)
                        Positioned(
                          left: piece.startX + p * piece.driftX,
                          top: piece.startY + p * p * piece.fallY,
                          child: Opacity(
                            opacity: p <= 0.001
                                ? 0
                                : p < 0.66
                                ? 1
                                : (1 - (p - 0.66) / 0.34).clamp(0.0, 1.0),
                            child: Transform.rotate(
                              angle: p * piece.spin * pi / 180,
                              child: Transform.scale(
                                scale: piece.scale,
                                child: Container(
                                  width: piece.width,
                                  height: piece.width * 0.6,
                                  decoration: BoxDecoration(
                                    color: piece.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: width * 0.86),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.lg,
                  vertical: Gap.md,
                ),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: Barako.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      salapifyIcon('celebrate'),
                      size: 22,
                      color: Barako.celebrate,
                    ),
                    const SizedBox(width: Gap.sm),
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body.w8.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
