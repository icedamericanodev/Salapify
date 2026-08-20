// A bank card that floats: drag to tilt it in 3D, a soft specular highlight
// slides across as it turns, and a tap unmasks the last four with a haptic tick.
//
// WHAT IT REUSES, so it cannot drift from the rest of the app. The face IS the
// existing [BankCard]: the same brand gradient, the same AA contrast guarantee
// (white text stays readable on every seed), the same chip, network mark and
// footer. So a "skin" is just a different seed colour handed to that same face
// (services/card_skins.dart), and it inherits the readable-text promise for
// free. The number line is the shared [CardNumberMask] via BankCard, so the
// zero jitter geometric dots and tabular last four apply here too.
//
// THE NUMBER, and its full security discipline. Only the last four are ever
// stored (the app wide contract), so there is never a full number to reveal.
// Tap toggles whether those four show: masked passes last4 = null to the face
// (dots), revealed passes the real four, exactly like the detail hero. The
// reveal follows the SAME protections every other last four reveal in the app
// uses, so this surface is not a softer door than the flip card or the detail
// screen: it asks for device auth when the phone can lock, holds FLAG_SECURE
// (SecureWindow) while the digits are up so a screenshot or the recents preview
// is blanked, and re-masks on a timeout, on backgrounding, and on teardown,
// releasing the secure latch exactly once. There is no copy action here.
//
// MOTION. The tilt is a plain [Transform] with a perspective Matrix4; on release
// it springs back to flat. Under the platform "reduce motion" setting the tilt
// is disabled entirely and the card sits flat, still tappable. No physics
// package, no external dependency, all offline.

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/secure_window.dart';
import '../theme.dart' show Haptics;
import 'bank_card.dart';
import 'lock_gate.dart' show BiometricAuthenticator, LockAuthenticator;

/// How long the last four stay visible before they re-mask themselves.
const Duration _revealTimeout = Duration(seconds: 30);

/// The largest tilt, in radians, a full edge-to-edge drag produces. Small on
/// purpose: a card that leans a little reads as premium, one that flips over
/// reads as a bug.
const double _maxTilt = 0.28;

class FloatingPanCard extends StatefulWidget {
  final String bankName;
  final String accountType;

  /// The brand colour, and the optional skin seed that overrides it. The face
  /// darkens whichever wins until white text clears AA, so either is safe.
  final Color? brandColor;
  final Color? skinSeed;

  final String? last4;
  final double balance;
  final String? amountText;
  final String? monogram;
  final String? logoAsset;
  final double? creditLimit;
  final String? networkMark;
  final BankCardVariant variant;
  final bool isWallet;

  /// Allow the drag-to-tilt gesture. Off makes a static card (used where the
  /// card is inside a scrollable that owns the drag, or for a calm preview).
  final bool enableTilt;

  /// Injectable so a widget test provides a fake (the real biometric channel
  /// does not exist in a test). Null uses the real [BiometricAuthenticator],
  /// the same one the flip card and the detail screen use.
  final LockAuthenticator? authenticator;

  const FloatingPanCard({
    super.key,
    required this.bankName,
    required this.accountType,
    required this.balance,
    this.brandColor,
    this.skinSeed,
    this.last4,
    this.amountText,
    this.monogram,
    this.logoAsset,
    this.creditLimit,
    this.networkMark,
    this.variant = BankCardVariant.savings,
    this.isWallet = false,
    this.enableTilt = true,
    this.authenticator,
  });

  @override
  State<FloatingPanCard> createState() => _FloatingPanCardState();
}

class _FloatingPanCardState extends State<FloatingPanCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // The live tilt, in radians: x leans forward/back, y leans left/right.
  Offset _tilt = Offset.zero;

  // Drives the spring back to flat when the finger lifts.
  late final AnimationController _settle;

  late final LockAuthenticator _auth =
      widget.authenticator ?? BiometricAuthenticator();

  bool _revealed = false;

  /// Held FLAG_SECURE latch, released exactly once however the reveal ends.
  bool _secured = false;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _settle =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() {
          // Ease the tilt toward flat as the controller runs 0..1.
          if (mounted) {
            setState(
              () => _tilt = Offset.lerp(
                _tiltAtRelease,
                Offset.zero,
                _settle.value,
              )!,
            );
          }
        });
    WidgetsBinding.instance.addObserver(this);
  }

  Offset _tiltAtRelease = Offset.zero;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Leaving the foreground with digits on screen re-hides them.
    if (state != AppLifecycleState.resumed && _revealed) _hide();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    if (_secured) {
      SecureWindow.release();
      _secured = false;
    }
    WidgetsBinding.instance.removeObserver(this);
    _settle.dispose();
    super.dispose();
  }

  bool _reduceMotion(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _onPanUpdate(DragUpdateDetails d, Size size) {
    if (size.width == 0 || size.height == 0) return;
    _settle.stop();
    // Map the finger's position within the card to a tilt. A drag to the right
    // edge leans the card right; to the top edge leans it back.
    final next = Offset(
      (_tilt.dx + d.delta.dx / size.width * _maxTilt * 2).clamp(
        -_maxTilt,
        _maxTilt,
      ),
      (_tilt.dy - d.delta.dy / size.height * _maxTilt * 2).clamp(
        -_maxTilt,
        _maxTilt,
      ),
    );
    setState(() => _tilt = next);
  }

  void _onPanEnd() {
    _tiltAtRelease = _tilt;
    _settle
      ..reset()
      ..forward();
  }

  Future<void> _toggleReveal() async {
    if (_revealed) {
      Haptics.select();
      _hide();
      return;
    }
    // A no-op tap on a card with no stored number does not buzz.
    if (widget.last4 == null) return;
    Haptics.select();
    // The same gate the flip card and the detail screen use: ask for device
    // auth when the phone can lock. A phone that cannot lock still reveals, so
    // an owner is never shut out of their own number.
    if (await _auth.canLock()) {
      if (!await _auth.authenticate()) return;
    }
    if (!mounted) return;
    // Hold FLAG_SECURE while the digits are up, released exactly once in _hide
    // (or dispose). Blanks screenshots and the recents preview, matching the
    // rest of the app's last four reveals.
    if (!_secured) {
      SecureWindow.retain();
      _secured = true;
    }
    setState(() => _revealed = true);
    _revealTimer?.cancel();
    _revealTimer = Timer(_revealTimeout, _hide);
  }

  void _hide() {
    _revealTimer?.cancel();
    if (_secured) {
      SecureWindow.release();
      _secured = false;
    }
    if (!mounted) return;
    if (_revealed) setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    final tilt = reduce ? Offset.zero : _tilt;

    final card = BankCard(
      bankName: widget.bankName,
      accountType: widget.accountType,
      // The skin seed wins over the brand colour, both AA safe through the face.
      brandColor: widget.skinSeed ?? widget.brandColor,
      // Masked passes null (dots); revealed passes the real four. Same rule the
      // detail hero uses, so the four live in exactly one place at a time.
      last4: _revealed ? widget.last4 : null,
      balance: widget.balance,
      amountText: widget.amountText,
      monogram: widget.monogram,
      logoAsset: widget.logoAsset,
      creditLimit: widget.creditLimit,
      networkMark: widget.networkMark,
      variant: widget.variant,
      isWallet: widget.isWallet,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 320,
          (constraints.maxWidth.isFinite ? constraints.maxWidth : 320) / 1.586,
        );
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(tilt.dy)
          ..rotateY(tilt.dx);

        return Semantics(
          button: true,
          label: widget.last4 != null
              ? (_revealed
                    ? '${widget.bankName} card. Tap to hide the last four digits.'
                    : '${widget.bankName} card. Tap to show the last four digits.')
              : '${widget.bankName} card.',
          child: GestureDetector(
            onTap: _toggleReveal,
            onPanUpdate: widget.enableTilt && !reduce
                ? (d) => _onPanUpdate(d, size)
                : null,
            onPanEnd: widget.enableTilt && !reduce ? (_) => _onPanEnd() : null,
            child: Transform(
              alignment: Alignment.center,
              transform: matrix,
              child: Stack(
                children: [
                  card,
                  // The specular sheen: a soft diagonal highlight that slides
                  // with the tilt, the cue a real card gives when it catches the
                  // light. Decorative and low opacity so it only brightens the
                  // face, never darkens the white text. Ignores pointers so the
                  // tap and drag land on the card beneath.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(
                                (tilt.dx / _maxTilt).clamp(-1.0, 1.0) - 0.6,
                                (-tilt.dy / _maxTilt).clamp(-1.0, 1.0) - 0.6,
                              ),
                              end: Alignment(
                                (tilt.dx / _maxTilt).clamp(-1.0, 1.0) + 0.9,
                                (-tilt.dy / _maxTilt).clamp(-1.0, 1.0) + 0.9,
                              ),
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.16),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              stops: const [0.30, 0.5, 0.70],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
