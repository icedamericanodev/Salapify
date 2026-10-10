import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'motion.dart' show reduceMotion;

/// Pan, Salapify's character (D30, founder direction 2026-10-08).
///
/// Every screen draws him through [PanArt], so new art is a folder swap: when
/// hi-res files arrive they replace `assets/pan/` under the SAME names and no
/// code changes. Briefs: docs/revamp/pan-handoff.md (where he appears) and
/// docs/revamp/pan-motion.md (how he moves). The approved look is
/// docs/revamp/mockups/pan/motion-preview.html, and every number below that
/// is not in the brief was read from that file.
///
/// Pick the mood by what the screen SAYS, not by what looks cute. If none
/// fits, keep the icon.
enum PanMood {
  /// A hello. Home on a first run.
  wave,

  /// Nothing due, nothing owed. An "all clear".
  calm,

  /// An empty list with nothing logged yet.
  sleep,

  /// A Plan empty state that suggests a first step.
  idea,

  /// Reports before there is enough to show.
  thinking,

  /// Accounts, money coming in.
  coin,

  /// Asking permission. Later phases.
  shy,

  /// A quick confirmation, and his reply to three quick taps.
  wink,

  /// Big moments, later phases, after hi-res art.
  celebrate,
  stars,
  savings,
  love,

  /// Heads-ups and failures, later phases.
  surprised,
  nervous,
  confused,
  sad,

  /// NOT USED. Pan never judges spending. These three exist only because the
  /// art does, and `pan_art_test.dart` fails if anything in lib/ reaches
  /// them. Tear may return for the wipe-all-data confirmation, and only by a
  /// founder decision.
  annoyed,
  tear,
  crying,
}

/// The asset each mood is drawn from. One rule, so a test can check every
/// mood has a file.
String panAsset(PanMood mood) => 'assets/pan/pan_${mood.name}.png';

/// The largest Pan the current 256 x 256 art stays sharp at on a 3x phone.
/// Above it he goes soft, so callers are clamped to it until hi-res art lands.
const double panMaxSize = 96;

/// The gap under Pan on an empty state, in place of the icon's own gap. Ten
/// rather than the usual sixteen, because the art carries its own air.
const double panGap = 10;

/// HOW MANY TIMES THE IDLE PLAYS, then he rests. The founder asked for the
/// maximum animation, and every effect in the brief is in. But a Pan that
/// never stops pulls the eye off the money, and an endless animation makes
/// `pumpAndSettle` in every test hang. Changing this number is a one-line
/// founder decision and nothing else in the app has to change.
const int panIdleCycles = 3;

/// When the entrance starts, after the empty state appears.
const int panPopDelayMs = 320;

const int _popMs = 760;
const int _idleStartMs = 1000;
const int _squashMs = 560;
const int _burstMs = 620;
const int _winkMs = 1400;

/// Handles for tests. The squash layer is the one a tap moves, and the
/// whole figure is the one a drag moves; asserting on a colour or a pixel
/// would be guessing.
const Key panSquashKey = ValueKey<String>('pan-squash');
const Key panDragKey = ValueKey<String>('pan-drag');

// ---------------------------------------------------------------------------
// Keyframes. CSS applies its timing function to each segment between two
// keyframes, not to the whole run, so this does the same: that is what makes
// the pop overshoot and settle exactly like the preview.

class _K {
  const _K(this.t, this.v);
  final double t;
  final double v;
}

double _kf(List<_K> ks, double p, Curve curve) {
  if (p <= ks.first.t) return ks.first.v;
  if (p >= ks.last.t) return ks.last.v;
  for (int i = 0; i < ks.length - 1; i++) {
    final _K a = ks[i];
    final _K b = ks[i + 1];
    if (p <= b.t) {
      final double local = (p - a.t) / (b.t - a.t);
      return a.v + (b.v - a.v) * curve.transform(local);
    }
  }
  return ks.last.v;
}

const double _deg = math.pi / 180;

/// One frame of one layer: where it is, how it is squashed, how it leans.
class _Pose {
  const _Pose({
    this.tx = 0,
    this.ty = 0,
    this.sx = 1,
    this.sy = 1,
    this.rot = 0,
    this.opacity = 1,
  });

  static const _Pose rest = _Pose();

  final double tx;
  final double ty;
  final double sx;
  final double sy;
  final double rot;
  final double opacity;

  Matrix4 get matrix => Matrix4.translationValues(tx, ty, 0)
    ..multiply(Matrix4.rotationZ(rot))
    ..multiply(Matrix4.diagonal3Values(sx, sy, 1));
}

/// Every scale and rotation pivots at his feet, 50% across and 92% down,
/// never his middle. Alignment(0, 0.84) is that point: 0.92 * 2 - 1.
const Alignment _feet = Alignment(0, 0.84);

/// Where an idle loop is, given milliseconds since it began, honouring the
/// CSS rules the preview uses: before it starts it holds its first frame,
/// after [panIdleCycles] it holds its last, and an alternating loop runs
/// there and back for each cycle.
double _loopPhase(double ms, int period, {required bool alternate}) {
  final int runs = alternate ? panIdleCycles * 2 : panIdleCycles;
  if (ms <= 0) return 0;
  if (ms >= runs * period) return alternate ? 0 : 1;
  final int i = ms ~/ period;
  final double f = (ms - i * period) / period;
  return alternate && i.isOdd ? 1 - f : f;
}

int _loopEnd(int period, {required bool alternate}) =>
    period * (alternate ? panIdleCycles * 2 : panIdleCycles);

// ---------------------------------------------------------------------------
// The six moods' idles, transcribed from the brief's table and the preview.

enum _Move { none, float, hop }

enum _Body { none, rock, breathe, tilt }

enum _Fx { star, z, glow, dot }

class _FxSpec {
  const _FxSpec(
    this.kind,
    this.x,
    this.y,
    this.rel, {
    this.delay = 0,
    this.tone = _Tone.sparkle,
  });

  final _Fx kind;

  /// Centre, as a fraction of Pan's size.
  final double x;
  final double y;

  /// Side, as a fraction of Pan's size.
  final double rel;
  final int delay;
  final _Tone tone;
}

enum _Tone { sparkle, calm, glint, glowIdea, glowCoin, z, dot }

class _Idle {
  const _Idle({
    this.move = _Move.none,
    this.movePeriod = 0,
    this.body = _Body.none,
    this.bodyPeriod = 0,
    this.fx = const <_FxSpec>[],
  });

  final _Move move;
  final int movePeriod;
  final _Body body;
  final int bodyPeriod;
  final List<_FxSpec> fx;

  /// Float and breathe go there and back; rock, tilt and hop are full loops.
  bool get moveAlternates => move == _Move.float;
  bool get bodyAlternates => body == _Body.breathe;

  static const _Idle still = _Idle();
}

const Map<PanMood, _Idle> _idles = <PanMood, _Idle>{
  PanMood.wave: _Idle(
    move: _Move.float,
    movePeriod: 2400,
    body: _Body.rock,
    bodyPeriod: 1600,
    fx: <_FxSpec>[
      _FxSpec(_Fx.star, .80, .04, .15),
      _FxSpec(_Fx.star, .95, .22, .10, delay: 600),
      _FxSpec(_Fx.star, .66, -.04, .08, delay: 1100),
    ],
  ),
  PanMood.sleep: _Idle(
    body: _Body.breathe,
    bodyPeriod: 3200,
    fx: <_FxSpec>[
      _FxSpec(_Fx.z, .74, .10, .18, tone: _Tone.z),
      _FxSpec(_Fx.z, .82, .02, .13, delay: 1300, tone: _Tone.z),
    ],
  ),
  PanMood.idea: _Idle(
    move: _Move.hop,
    movePeriod: 2200,
    fx: <_FxSpec>[_FxSpec(_Fx.glow, .72, .04, .54, tone: _Tone.glowIdea)],
  ),
  PanMood.coin: _Idle(
    move: _Move.float,
    movePeriod: 2000,
    body: _Body.tilt,
    bodyPeriod: 2400,
    fx: <_FxSpec>[
      _FxSpec(_Fx.glow, .18, .09, .46, tone: _Tone.glowCoin),
      _FxSpec(_Fx.star, .12, .02, .16, tone: _Tone.glint),
      _FxSpec(_Fx.star, .26, .16, .09, delay: 900, tone: _Tone.glint),
    ],
  ),
  PanMood.calm: _Idle(
    move: _Move.float,
    movePeriod: 3600,
    body: _Body.breathe,
    bodyPeriod: 3600,
    fx: <_FxSpec>[
      _FxSpec(_Fx.star, .10, .22, .11, tone: _Tone.calm),
      _FxSpec(_Fx.star, .90, .16, .13, delay: 700, tone: _Tone.calm),
      _FxSpec(_Fx.star, .84, .50, .08, delay: 1400, tone: _Tone.calm),
    ],
  ),
  PanMood.thinking: _Idle(
    body: _Body.tilt,
    bodyPeriod: 3000,
    fx: <_FxSpec>[
      _FxSpec(_Fx.dot, .04, .34, .05, tone: _Tone.dot),
      _FxSpec(_Fx.dot, -.04, .26, .05, delay: 200, tone: _Tone.dot),
      _FxSpec(_Fx.dot, -.12, .18, .05, delay: 400, tone: _Tone.dot),
    ],
  ),
};

int _fxPeriod(_Fx k) => switch (k) {
  _Fx.star => 1800,
  _Fx.z => 2600,
  _Fx.glow => 1200,
  _Fx.dot => 1200,
};

/// Decorative colours, which appear nowhere else in the app, so they live
/// here and not in tokens.dart (pan-motion.md, "Colours for effects").
Color _toneColor(_Tone t, {required bool dark}) => switch (t) {
  _Tone.sparkle => dark ? const Color(0xFFFFD36B) : const Color(0xFFD99A00),
  _Tone.calm => dark ? const Color(0xFF7FD9B8) : const Color(0xFF2F9E72),
  _Tone.glint => dark ? const Color(0xFFFFFFFF) : const Color(0xFFD99A00),
  _Tone.z => dark ? const Color(0xFF8FA3D9) : const Color(0xFF5B6FB0),
  _Tone.dot => dark ? const Color(0xFFC6B8AC) : const Color(0xFF8E8178),
  _Tone.glowIdea => const Color(0xF2FFE08A),
  _Tone.glowCoin => const Color(0xE6FFD66B),
};

/// The longest anything in this mood's run lasts, entrance included, so the
/// clock knows when to stop and `pumpAndSettle` can finish.
int _runMs(_Idle idle, int popDelay) {
  int end = popDelay + _popMs;
  if (idle.move != _Move.none) {
    end = math.max(
      end,
      _idleStartMs + _loopEnd(idle.movePeriod, alternate: idle.moveAlternates),
    );
  }
  if (idle.body != _Body.none) {
    end = math.max(
      end,
      _idleStartMs + _loopEnd(idle.bodyPeriod, alternate: idle.bodyAlternates),
    );
  }
  for (final _FxSpec f in idle.fx) {
    end = math.max(
      end,
      _idleStartMs +
          f.delay +
          _loopEnd(_fxPeriod(f.kind), alternate: f.kind == _Fx.glow),
    );
  }
  return end;
}

// ---------------------------------------------------------------------------

/// Pan in one [mood], [size] logical pixels square, and alive.
///
/// FOUR NESTED LAYERS, outer to inner, so the motions add up instead of
/// fighting: the entrance pop, the mood's travel (float or hop), the body's
/// shape (rock, breathe or tilt), and the tap squash. The effects ride on the
/// travel layer so they move with him.
///
/// INTERACTIVE, beyond the brief, by founder direction ("make it more
/// interactive"): a tap squashes him with a light buzz and a small burst of
/// sparkles; three quick taps and he winks back; drag him SIDEWAYS and he
/// leans after your finger, then springs home when you let go. Sideways
/// only, so a scroll that starts on him still scrolls.
///
/// Decorative to a screen reader and to focus: wherever he appears, the text
/// beside him already says what matters.
///
/// Reduce motion turns all of it off and draws him still.
class PanArt extends StatefulWidget {
  const PanArt({
    super.key,
    required this.mood,
    this.size = panMaxSize,
    this.popDelayMs = panPopDelayMs,
  });

  final PanMood mood;
  final double size;
  final int popDelayMs;

  @override
  State<PanArt> createState() => _PanArtState();
}

class _PanArtState extends State<PanArt> with TickerProviderStateMixin {
  AnimationController? _clock;
  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _squashMs),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _burstMs),
  );
  late final AnimationController _wink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _winkMs),
  );

  /// Sideways offset in logical pixels. Unbounded, because a spring
  /// overshoots past zero on its way home and that overshoot is the wobble.
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );

  final List<DateTime> _taps = <DateTime>[];
  bool _still = false;

  /// Where the finger has taken him BEFORE the rubber band, so the band is
  /// applied once to the whole drag rather than compounded on every pointer
  /// event. Compounding it made the lean depend on how often the phone
  /// reports the finger: a 120 Hz screen leaned him less than a 60 Hz one.
  double _rawDx = 0;

  _Idle get _idle => _idles[widget.mood] ?? _Idle.still;
  double get _size => widget.size.clamp(0, panMaxSize).toDouble();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = reduceMotion(context);
    if (still == _still && (_clock != null || still)) return;
    _still = still;
    if (still) {
      _clock?.dispose();
      _clock = null;
      _squash.value = 0;
      _burst.value = 0;
      _wink.value = 0;
      _drag.value = 0;
    } else {
      _clock ??= AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _runMs(_idle, widget.popDelayMs)),
      )..forward();
    }
  }

  /// A new mood on the same element gets its own run. Without this the old
  /// clock's length would cut the new idle off mid-cycle and freeze him in a
  /// tilted or half-faded pose.
  @override
  void didUpdateWidget(PanArt old) {
    super.didUpdateWidget(old);
    if (_still) return;
    if (old.mood != widget.mood || old.popDelayMs != widget.popDelayMs) {
      _clock?.dispose();
      _clock = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _runMs(_idle, widget.popDelayMs)),
      )..forward();
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    _squash.dispose();
    _burst.dispose();
    _wink.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _onTap() {
    if (_still) return;
    HapticFeedback.lightImpact();
    _squash.forward(from: 0);
    _burst.forward(from: 0);
    final DateTime now = DateTime.now();
    _taps
      ..add(now)
      ..removeWhere(
        (DateTime t) => now.difference(t) > const Duration(milliseconds: 1200),
      );
    if (_taps.length >= 3) {
      _taps.clear();
      _wink.forward(from: 0);
    }
  }

  double get _dragLimit => _size * 0.42;

  void _onDragStart(DragStartDetails _) {
    if (_still) return;
    _drag.stop();
    // Pick up from wherever the spring had him, undoing the band once.
    final double x = (_drag.value / _dragLimit).clamp(-0.999, 0.999);
    _rawDx = _dragLimit * 0.5 * math.log((1 + x) / (1 - x));
    HapticFeedback.selectionClick();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_still) return;
    // Rubber band: he follows the finger, but less and less the further it
    // goes, so he leans rather than leaves.
    _rawDx += d.delta.dx * 0.6;
    _drag.value = _dragLimit * _tanh(_rawDx / _dragLimit);
  }

  void _onDragEnd(DragEndDetails d) {
    if (_still) return;
    HapticFeedback.lightImpact();
    _drag.animateWith(
      SpringSimulation(
        const SpringDescription(mass: 1, stiffness: 420, damping: 10),
        _drag.value,
        0,
        d.velocity.pixelsPerSecond.dx * 0.15,
      ),
    );
    _squash.forward(from: 0);
  }

  static double _tanh(double x) {
    final double e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  @override
  Widget build(BuildContext context) {
    final double size = _size;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    if (_still) {
      return ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              _shadow(size, scaleX: 1, opacity: 0.5),
              Positioned.fill(child: _image(widget.mood, size)),
            ],
          ),
        ),
      );
    }

    final Listenable tick = Listenable.merge(<Listenable>[
      _clock!,
      _squash,
      _burst,
      _wink,
      _drag,
    ]);

    return ExcludeSemantics(
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: tick,
            builder: (BuildContext context, Widget? _) => _frame(size, dark),
          ),
        ),
      ),
    );
  }

  Widget _frame(double size, bool dark) {
    final double t = _clock!.value * _clock!.duration!.inMilliseconds;
    final _Idle idle = _idle;

    final _Pose pop = _popPose(t - widget.popDelayMs);
    final double idleMs = t - _idleStartMs;
    final ({_Pose pose, double lift}) move = _movePose(idle, idleMs, size);
    final _Pose body = _bodyPose(idle, idleMs);
    final _Pose squash = _squashPose(_squash.value, size);

    // The drag leans him from the feet, a few degrees per finger-width.
    final double dx = _drag.value;
    final _Pose drag = _Pose(tx: dx, rot: (dx / size) * 0.45);

    final ({double sx, double opacity}) sh = _shadowState(
      idle,
      idleMs,
      move.lift,
    );

    final PanMood shown = _wink.isAnimating ? PanMood.wink : widget.mood;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        // The shadow stays on the ground, outside every layer, exactly as
        // in the preview: it is there before he pops in, and when he floats
        // it shrinks and fades rather than rising with him.
        _shadow(size, scaleX: sh.sx, opacity: sh.opacity, dx: dx * 0.6),
        Positioned.fill(
          child: Opacity(
            opacity: pop.opacity.clamp(0.0, 1.0),
            child: Transform(
              alignment: _feet,
              transform: pop.matrix,
              child: Transform(
                key: panDragKey,
                alignment: _feet,
                transform: drag.matrix,
                child: Transform(
                  alignment: _feet,
                  transform: move.pose.matrix,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FxPainter(
                            idle.fx,
                            idleMs,
                            dark: dark,
                            back: true,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Transform(
                          alignment: _feet,
                          transform: body.matrix,
                          child: Transform(
                            key: panSquashKey,
                            alignment: _feet,
                            transform: squash.matrix,
                            child: _image(shown, size),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FxPainter(
                            idle.fx,
                            idleMs,
                            dark: dark,
                            back: false,
                            burst: _burst.isAnimating ? _burst.value : null,
                            burstColor: _toneColor(
                              widget.mood == PanMood.calm
                                  ? _Tone.calm
                                  : _Tone.sparkle,
                              dark: dark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The PNG with its baked shadow clipped off. The bottom 7.5% of every
  /// file is a faint grey smudge under his feet; PanArt draws its own.
  static Widget _image(PanMood mood, double size) {
    return ClipRect(
      clipper: const _TopClip(0.925),
      child: Image.asset(
        panAsset(mood),
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        gaplessPlayback: true,
      ),
    );
  }

  static Widget _shadow(
    double size, {
    required double scaleX,
    required double opacity,
    double dx = 0,
  }) {
    final double w = size * 0.54;
    final double h = size * 0.09;
    return Positioned(
      left: (size - w) / 2,
      bottom: size * 0.04,
      width: w,
      height: h,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          transform: Matrix4.translationValues(dx, 0, 0)
            ..multiply(Matrix4.diagonal3Values(scaleX, 1, 1)),
          alignment: Alignment.center,
          child: const CustomPaint(painter: _ShadowPainter()),
        ),
      ),
    );
  }

  // --- the poses --------------------------------------------------------

  static _Pose _popPose(double ms) {
    final double p = ms / _popMs;
    const Curve c = Curves.easeOut;
    return _Pose(
      opacity: _kf(const <_K>[_K(0, 0), _K(.55, 1), _K(1, 1)], p, c),
      ty: _kf(const <_K>[_K(0, 28), _K(.55, -8), _K(.75, 2), _K(1, 0)], p, c),
      sx: _kf(
        const <_K>[_K(0, .35), _K(.55, 1.08), _K(.75, .96), _K(1, 1)],
        p,
        c,
      ),
      sy: _kf(
        const <_K>[_K(0, .35), _K(.55, 1.08), _K(.75, .96), _K(1, 1)],
        p,
        c,
      ),
    );
  }

  /// The travel layer, and how high off the ground he is (0 to 1), which
  /// the shadow reads.
  static ({_Pose pose, double lift}) _movePose(
    _Idle idle,
    double ms,
    double size,
  ) {
    switch (idle.move) {
      case _Move.none:
        return (pose: _Pose.rest, lift: 0);
      case _Move.float:
        final double f = Curves.easeInOut.transform(
          _loopPhase(ms, idle.movePeriod, alternate: true),
        );
        return (pose: _Pose(ty: -0.09 * size * f), lift: f);
      case _Move.hop:
        final double p = _loopPhase(ms, idle.movePeriod, alternate: false);
        const Curve l = Curves.linear;
        final double up = _kf(
          const <_K>[_K(0, 0), _K(.66, 0), _K(.80, 1), _K(.92, 0), _K(1, 0)],
          p,
          l,
        );
        return (
          pose: _Pose(
            ty: -0.16 * size * up,
            sx: _kf(_hopSx, p, l),
            sy: _kf(_hopSy, p, l),
          ),
          lift: up,
        );
    }
  }

  static const List<_K> _hopSx = <_K>[
    _K(0, 1),
    _K(.58, 1),
    _K(.66, 1.1),
    _K(.80, .95),
    _K(.92, 1.06),
    _K(1, 1),
  ];
  static const List<_K> _hopSy = <_K>[
    _K(0, 1),
    _K(.58, 1),
    _K(.66, .88),
    _K(.80, 1.06),
    _K(.92, .93),
    _K(1, 1),
  ];

  static _Pose _bodyPose(_Idle idle, double ms) {
    const Curve c = Curves.easeInOut;
    switch (idle.body) {
      case _Body.none:
        return _Pose.rest;
      case _Body.rock:
        final double p = _loopPhase(ms, idle.bodyPeriod, alternate: false);
        return _Pose(
          rot:
              _kf(
                const <_K>[_K(0, 0), _K(.25, -6), _K(.75, 6), _K(1, 0)],
                p,
                c,
              ) *
              _deg,
        );
      case _Body.breathe:
        final double f = c.transform(
          _loopPhase(ms, idle.bodyPeriod, alternate: true),
        );
        return _Pose(sx: 1 + 0.035 * f, sy: 1 - 0.035 * f);
      case _Body.tilt:
        final double p = _loopPhase(ms, idle.bodyPeriod, alternate: false);
        return _Pose(
          rot: _kf(const <_K>[_K(0, -4), _K(.5, 4), _K(1, -4)], p, c) * _deg,
        );
    }
  }

  static _Pose _squashPose(double p, double size) {
    if (p <= 0 || p >= 1) return _Pose.rest;
    const Curve c = Curves.easeOut;
    return _Pose(
      sx: _kf(
        const <_K>[
          _K(0, 1),
          _K(.22, 1.16),
          _K(.52, .9),
          _K(.78, 1.05),
          _K(1, 1),
        ],
        p,
        c,
      ),
      sy: _kf(
        const <_K>[
          _K(0, 1),
          _K(.22, .82),
          _K(.52, 1.12),
          _K(.78, .96),
          _K(1, 1),
        ],
        p,
        c,
      ),
      ty:
          _kf(
            const <_K>[
              _K(0, 0),
              _K(.22, 0),
              _K(.52, -.14),
              _K(.78, 0),
              _K(1, 0),
            ],
            p,
            c,
          ) *
          size,
    );
  }

  static ({double sx, double opacity}) _shadowState(
    _Idle idle,
    double ms,
    double lift,
  ) {
    switch (idle.move) {
      case _Move.float:
        return (sx: 1 - 0.26 * lift, opacity: 0.5 - 0.28 * lift);
      case _Move.hop:
        final double p = _loopPhase(ms, idle.movePeriod, alternate: false);
        const Curve l = Curves.linear;
        return (
          sx: _kf(
            const <_K>[
              _K(0, 1),
              _K(.58, 1),
              _K(.66, 1.12),
              _K(.80, .62),
              _K(1, 1),
            ],
            p,
            l,
          ),
          opacity: _kf(
            const <_K>[
              _K(0, .5),
              _K(.58, .5),
              _K(.66, .55),
              _K(.80, .16),
              _K(1, .5),
            ],
            p,
            l,
          ),
        );
      case _Move.none:
        if (idle.body == _Body.breathe) {
          final double f = Curves.easeInOut.transform(
            _loopPhase(ms, idle.bodyPeriod, alternate: true),
          );
          return (sx: 1 + 0.06 * f, opacity: 0.5);
        }
        return (sx: 1, opacity: 0.5);
    }
  }
}

/// The ground shadow, a soft ellipse filling its whole box: the preview's
/// `radial-gradient(closest-side, ...)`. Flutter's RadialGradient measures
/// its radius against the box's SHORTEST side, so on a box 52 wide and 9
/// tall it drew a 9 pixel dot; drawing a unit circle and stretching the
/// canvas to the box gives the ellipse.
class _ShadowPainter extends CustomPainter {
  const _ShadowPainter();

  static final Paint _paint = Paint()
    ..shader = const RadialGradient(
      colors: <Color>[Color(0xD9000000), Color(0x00000000)],
    ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..translate(size.width / 2, size.height / 2)
      ..scale(size.width / 2, size.height / 2)
      ..drawCircle(Offset.zero, 1, _paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => false;
}

/// Pan small and STILL, as the face of Ask Pan (founder request 2026-10-08,
/// "can we also put mascot on it?").
///
/// Still on purpose. The floating button is on screen for as long as Home
/// is, and a figure that keeps moving in the corner pulls the eye off the
/// money every second it is there; the empty states are where he moves.
/// The baked shadow is clipped off, since at this size it reads as a smudge.
class PanAvatar extends StatelessWidget {
  const PanAvatar({super.key, this.mood = PanMood.wave, this.size = 28});

  final PanMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double side = size.clamp(0, panMaxSize).toDouble();
    return ExcludeSemantics(
      child: SizedBox(
        width: side,
        height: side,
        child: ClipRect(
          clipper: const _TopClip(0.925),
          child: Image.asset(
            panAsset(mood),
            width: side,
            height: side,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// Keeps the top [fraction] of the child: the image minus its baked shadow.
class _TopClip extends CustomClipper<Rect> {
  const _TopClip(this.fraction);

  final double fraction;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, size.height * fraction);

  @override
  bool shouldReclip(_TopClip old) => old.fraction != fraction;
}

/// The effects: sparkles, z letters, glows, thinking dots, and the burst a
/// tap sends out. Painted, not built from widgets, so twelve moving shapes
/// cost one layer.
class _FxPainter extends CustomPainter {
  _FxPainter(
    this.fx,
    this.ms, {
    required this.dark,
    required this.back,
    this.burst,
    this.burstColor,
  });

  final List<_FxSpec> fx;
  final double ms;
  final bool dark;

  /// Glows sit BEHIND him; everything else in front.
  final bool back;
  final double? burst;
  final Color? burstColor;

  static final Path _star = Path()
    ..moveTo(12, 0)
    ..cubicTo(12.8, 6.4, 17.6, 11.2, 24, 12)
    ..cubicTo(17.6, 12.8, 12.8, 17.6, 12, 24)
    ..cubicTo(11.2, 17.6, 6.4, 12.8, 0, 12)
    ..cubicTo(6.4, 11.2, 11.2, 6.4, 12, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final double s0 = size.width;
    for (final _FxSpec f in fx) {
      if ((f.kind == _Fx.glow) != back) continue;
      final Offset centre = Offset(f.x * s0, f.y * s0);
      final double side = f.rel * s0;
      final int period = _fxPeriod(f.kind);
      final bool alt = f.kind == _Fx.glow;
      final double p = _loopPhase(ms - f.delay, period, alternate: alt);
      final Color color = _toneColor(f.tone, dark: dark);
      switch (f.kind) {
        case _Fx.star:
          const Curve c = Curves.easeInOut;
          final List<_K> k01 = const <_K>[_K(0, 0), _K(.5, 1), _K(1, 0)];
          final double o = _kf(k01, p, c);
          if (o <= 0.001) continue;
          final double sc = .3 + .7 * _kf(k01, p, c);
          _drawStar(
            canvas,
            centre,
            side * sc,
            45 * _deg * _kf(k01, p, c),
            color.withValues(alpha: o),
          );
        case _Fx.z:
          const Curve c = Curves.easeOut;
          final double o = _kf(const <_K>[_K(0, 0), _K(.2, 1), _K(1, 0)], p, c);
          if (o <= 0.001) continue;
          final double m = c.transform(p.clamp(0, 1));
          final double sc = .6 + .65 * m;
          final TextPainter tp = TextPainter(
            text: TextSpan(
              text: 'z',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: side * sc,
                height: 1,
                fontWeight: FontWeight.w800,
                color: color.withValues(alpha: o),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            centre +
                Offset(16 * m, -36 * m) -
                Offset(tp.width / 2, tp.height / 2),
          );
          tp.dispose();
        case _Fx.glow:
          final double f2 = Curves.easeInOut.transform(p);
          final double o = .2 + .75 * f2;
          final double r = side / 2 * (.75 + .55 * f2);
          final Paint paint = Paint()
            ..shader = RadialGradient(
              colors: <Color>[
                color.withValues(alpha: color.a * o),
                const Color(0x00FFE08A),
              ],
            ).createShader(Rect.fromCircle(center: centre, radius: r));
          canvas.drawCircle(centre, r, paint);
        case _Fx.dot:
          const Curve c = Curves.easeInOut;
          final double k = _kf(const <_K>[_K(0, 0), _K(.5, 1), _K(1, 0)], p, c);
          canvas.drawCircle(
            centre + Offset(0, -4 * k),
            side / 2,
            Paint()..color = color.withValues(alpha: .25 + .75 * k),
          );
      }
    }

    // THE TAP BURST: five small stars thrown out from above his head.
    final double? b = burst;
    if (!back && b != null && b > 0 && b < 1) {
      final Color c = burstColor ?? const Color(0xFFFFD36B);
      final double e = Curves.easeOutCubic.transform(b);
      final Offset origin = Offset(s0 / 2, s0 * 0.38);
      for (int i = 0; i < 5; i++) {
        final double a = -math.pi / 2 + (i - 2) * 0.62;
        final Offset at =
            origin + Offset(math.cos(a), math.sin(a)) * (s0 * 0.55 * e);
        final double side = s0 * 0.11 * (1 - 0.5 * b);
        _drawStar(
          canvas,
          at,
          side,
          a + b * math.pi / 2,
          c.withValues(alpha: 1 - b),
        );
      }
    }
  }

  void _drawStar(
    Canvas canvas,
    Offset centre,
    double side,
    double rot,
    Color color,
  ) {
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(rot)
      ..scale(side / 24)
      ..translate(-12, -12)
      ..drawPath(_star, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_FxPainter old) =>
      old.ms != ms || old.dark != dark || old.burst != burst || old.fx != fx;
}

// ---------------------------------------------------------------------------

/// The middle of an empty state with Pan in it: Pan, then the title, body
/// and optional action, which rise in one after another once he has landed.
///
/// This is the one place an empty state's motion lives, so no screen carries
/// animation code of its own (pan-motion.md, "Scope"). The screen still
/// owns the card, the copy and the styles, and passes them in, so nothing a
/// person reads changes.
///
/// [ring] is for the Home first-run button only: two soft accent rings go
/// out from it after Pan lands, pointing at the one thing to do next.
class PanEmptyContent extends StatefulWidget {
  const PanEmptyContent({
    super.key,
    required this.mood,
    required this.title,
    this.body,
    this.action,
    this.gap = 4,
    this.actionGap = 14,
    this.ring = false,
    this.ringColor,
    this.ringRadius = 999,
  });

  final PanMood mood;
  final Widget title;
  final Widget? body;
  final Widget? action;

  /// Between the title and the body, as each screen already had it.
  final double gap;
  final double actionGap;
  final bool ring;
  final Color? ringColor;

  /// The corner radius of the button the rings go out from, so they follow
  /// its shape instead of drawing a pill around a rounded rectangle.
  final double ringRadius;

  @override
  State<PanEmptyContent> createState() => _PanEmptyContentState();
}

class _PanEmptyContentState extends State<PanEmptyContent>
        // NOT the single-ticker mixin: reduce motion switched on and off again
        // disposes this clock and builds a new one, and the single-ticker mixin
        // asserts on a second ticker even after the first is gone.
        with
        TickerProviderStateMixin {
  AnimationController? _clock;

  static const int _riseMs = 520;
  static const int _ringStart = 1500;
  static const int _ringMs = 1600;
  static const Cubic _riseCurve = Cubic(0.2, 0.8, 0.2, 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool still = reduceMotion(context);
    if (still) {
      _clock?.dispose();
      _clock = null;
    } else if (_clock == null) {
      final int total = widget.ring && widget.action != null
          ? _ringStart + 2 * _ringMs
          : 720 + _riseMs;
      _clock = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: total),
      )..forward();
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  double get _ms =>
      _clock == null ? 1e9 : _clock!.value * _clock!.duration!.inMilliseconds;

  Widget _rise(int delay, Widget child) {
    if (_clock == null) return child;
    return AnimatedBuilder(
      animation: _clock!,
      child: child,
      builder: (BuildContext context, Widget? c) {
        final double p = ((_ms - delay) / _riseMs).clamp(0.0, 1.0);
        final double e = _riseCurve.transform(p);
        return Opacity(
          opacity: e,
          // A screen reader hears the text from the first frame. A plain
          // Opacity at zero drops its child from the semantics tree, which
          // hid "Log your first entry" from TalkBack for most of a second.
          alwaysIncludeSemantics: true,
          child: Transform.translate(offset: Offset(0, 14 * (1 - e)), child: c),
        );
      },
    );
  }

  Widget _ringed(Widget child) {
    if (_clock == null || !widget.ring) return child;
    final Color base = widget.ringColor ?? const Color(0xFFFF9A52);
    return AnimatedBuilder(
      animation: _clock!,
      child: child,
      builder: (BuildContext context, Widget? c) {
        final double since = _ms - _ringStart;
        double spread = 0;
        double alpha = 0;
        if (since > 0 && since < 2 * _ringMs) {
          final double p = Curves.easeOut.transform(
            (since % _ringMs) / _ringMs,
          );
          spread = 16 * p;
          alpha = 0.55 * (1 - p);
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(widget.ringRadius)),
            boxShadow: alpha <= 0
                ? const <BoxShadow>[]
                : <BoxShadow>[
                    BoxShadow(
                      color: base.withValues(alpha: alpha),
                      spreadRadius: spread,
                    ),
                  ],
          ),
          child: c,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PanArt(mood: widget.mood),
        const SizedBox(height: panGap),
        _rise(560, widget.title),
        if (widget.body != null) ...<Widget>[
          SizedBox(height: widget.gap),
          _rise(630, widget.body!),
        ],
        if (widget.action != null) ...<Widget>[
          SizedBox(height: widget.actionGap),
          _rise(720, _ringed(widget.action!)),
        ],
      ],
    );
  }
}
