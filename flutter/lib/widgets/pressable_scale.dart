// PressableScale: the better-ui "scale on press" tactile feel, applied the
// Flutter way (see the flutter-ui-polish skill). It dips the child to 0.96 on
// finger down and springs back on release, so a card feels physical when
// tapped.
//
// It uses a Listener, not a GestureDetector, so it NEVER steals the tap or
// scroll from the child. The child keeps its own InkWell (ripple) and onTap;
// this only adds the scale. That means it composes over any existing tappable
// without changing behavior, and a drag that turns into a scroll still works.

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/widgets.dart';

class PressableScale extends StatefulWidget {
  final Widget child;

  /// The press depth. 0.96 is the better-ui default; never go below 0.95.
  final double pressedScale;

  const PressableScale({super.key, required this.child, this.pressedScale = 0.96});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;
  Offset? _downPos;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    // Honor the OS "remove animations" / reduce-motion setting.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Listener(
      onPointerDown: (e) {
        _downPos = e.position;
        _set(true);
      },
      // The finger moving past touch slop is exactly when Flutter decides this
      // is a scroll, not a tap. Release the press then, so a card never sits
      // shrunk for the whole drag.
      onPointerMove: (e) {
        if (_down &&
            _downPos != null &&
            (e.position - _downPos!).distance > kTouchSlop) {
          _set(false);
        }
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: Duration(milliseconds: reduce ? 0 : 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
