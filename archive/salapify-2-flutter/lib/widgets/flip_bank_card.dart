// A bank card you can tap to flip over, front summary to a condensed back.
//
// The FRONT is the existing BankCard, unchanged. The BACK is a condensed view
// of the account's details on the SAME card area, so a tap does not leave the
// screen for the basics; "View full details" is what opens the full wallet page
// (AccountDetailScreen), which owns the complete, freely scaling copy.
//
// This widget REUSES the primitives f3.63 already shipped rather than rebuilding
// them: BankCard for the front, bankCardGradient for the back so the AA-contrast
// promise still holds, BiometricAuthenticator + SecureWindow for the reveal, and
// the account detail screen's QR sheet for the QR shortcut. The one hard limit,
// from the data layer: only the last four digits are ever stored, never a full
// number, so the reveal shows at most "•••• 4821" behind device auth. There is
// nothing longer to unmask, by contract.
//
// Sensitive discipline, mirrored from AccountDetailScreen: the number is masked
// by default, a reveal asks for device auth when the phone can lock, forces
// FLAG_SECURE on through a latch released exactly once, auto-remasks after a
// timeout, and remasks the instant the card flips back, the app backgrounds, or
// the widget is torn down.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/qr_vault.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../theme.dart' show Haptics;
import '../screens/account_detail.dart' show showAccountQrSheet;
import '../services/secure_window.dart';
import 'bank_card.dart';
import 'lock_gate.dart' show LockAuthenticator, BiometricAuthenticator;
import 'pan_mask_widget.dart';
import 'salapify_icon.dart';

/// How long a revealed number stays visible before it remasks itself.
const Duration _revealTimeout = Duration(seconds: 30);

class FlipBankCard extends StatefulWidget {
  /// The stored row, so the back reads current values (limit, due day, notes,
  /// QR). The parent owns navigation and editing, so nothing here needs the
  /// store or which collection the row lives in.
  final Map<String, dynamic> row;

  // Front (BankCard) props, resolved by the caller exactly as for a plain card.
  final String bankName;
  final String accountType;
  final Color? brandColor;
  final String? last4;
  final double balance;
  final String? amountText;
  final String? monogram;

  /// The bundled wordmark logo asset for this institution, drawn on the front
  /// face's white brand chip. Null keeps the bank-name text. See [BankCard].
  final String? logoAsset;
  final double? creditLimit;
  final String? networkMark;
  final BankCardVariant variant;

  /// E-wallets suppress the payment-card furniture on the front face.
  final bool isWallet;

  /// Controlled flip state: the PARENT owns which card is flipped so a list can
  /// keep only one open at a time. Null-safe default is front (false).
  final bool flipped;

  /// The card asked to flip (true) or unflip (false). The parent decides.
  final ValueChanged<bool> onFlip;

  /// Open the full wallet page for this account. The parent navigates.
  final VoidCallback onViewFullDetails;

  /// Edit the account's details. The parent opens the right sheet.
  final VoidCallback onEdit;

  /// Show the one-time "Tap to view details" hint on the front.
  final bool showHint;

  /// Injectable so a widget test provides a fake (the real platform channel and
  /// documents directory do not exist in a test).
  final LockAuthenticator? authenticator;
  final QrVault? vault;

  const FlipBankCard({
    super.key,
    required this.row,
    required this.bankName,
    required this.accountType,
    required this.balance,
    required this.flipped,
    required this.onFlip,
    required this.onViewFullDetails,
    required this.onEdit,
    this.brandColor,
    this.last4,
    this.amountText,
    this.monogram,
    this.logoAsset,
    this.creditLimit,
    this.networkMark,
    this.variant = BankCardVariant.savings,
    this.isWallet = false,
    this.showHint = false,
    this.authenticator,
    this.vault,
  });

  @override
  State<FlipBankCard> createState() => _FlipBankCardState();
}

class _FlipBankCardState extends State<FlipBankCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // Created in initState, NOT as a lazy `late final`: the reduced-motion path
  // never reads _anim during build, so a lazy field would be constructed for
  // the first time inside dispose(), where createTicker looks up a now
  // deactivated TickerMode ancestor and throws. Building it eagerly while the
  // element is still mounted is what keeps both the animated and reduced-motion
  // paths safe to tear down.
  late final AnimationController _anim;
  late final LockAuthenticator _auth =
      widget.authenticator ?? BiometricAuthenticator();

  bool _revealed = false;

  /// Held FLAG_SECURE latch, released exactly once however the reveal ends.
  bool _secured = false;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: widget.flipped ? 1 : 0,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(FlipBankCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped != old.flipped) {
      final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (reduce) {
        _anim.value = widget.flipped ? 1 : 0;
      } else if (widget.flipped) {
        _anim.forward();
      } else {
        _anim.reverse();
      }
      // Flipping back to the front always re-hides a revealed number.
      if (!widget.flipped) _hide();
    }
    // The number was edited to empty while revealed: the reveal/hide buttons
    // disappear with it, so remask now rather than stranding the latch until
    // the timeout.
    if (old.last4 != null && widget.last4 == null) _hide();
  }

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
    _anim.dispose();
    super.dispose();
  }

  bool get _isCredit => widget.variant == BankCardVariant.credit;

  void _handleTap() {
    // A tap mid-flip is ignored so a fast double tap cannot land the card
    // half-turned or fight the animation.
    if (_anim.isAnimating) return;
    // Through the house vocabulary class, not the raw channel, so one grep
    // audits every haptic in the app.
    Haptics.select();
    widget.onFlip(!widget.flipped);
  }

  // --- Reveal, mirrored from AccountDetailScreen ----------------------------

  Future<void> _toggleReveal() async {
    if (_revealed) {
      _hide();
      return;
    }
    if (widget.last4 == null) return;
    // The last four are not a secret on their own, but the owner chose to keep
    // this account, and the copy action puts them on the clipboard, so we ask
    // when the phone CAN check identity. A phone that cannot lock still reveals,
    // so an owner is never hidden from their own number.
    if (await _auth.canLock()) {
      if (!await _auth.authenticate()) return;
    }
    // The auth prompt can drive the app off the foreground, which flips this
    // card back to its front. If it did, do not reveal onto a front-facing card
    // or hold FLAG_SECURE for the timeout: the next flip must ask again.
    if (!mounted || !widget.flipped) return;
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

  Future<void> _copyLast4() async {
    final last4 = widget.last4;
    if (last4 == null) return;
    if (await _auth.canLock() && !_revealed) {
      if (!await _auth.authenticate()) return;
    }
    await Clipboard.setData(ClipboardData(text: last4));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Copied. It stays only until you copy something else.'),
        ),
      );
  }

  Future<void> _openQr(String ref, String? label) => showAccountQrSheet(
    context,
    vault: widget.vault,
    qrRef: ref,
    label: label,
  );

  // --- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Semantics(
      button: true,
      label: widget.flipped
          ? '${widget.bankName} card, back. Tap to flip to the front.'
          : '${widget.bankName} card. Tap to flip to the details.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: AspectRatio(
          aspectRatio: 1.586,
          child: reduce ? _reducedMotion() : _flip(),
        ),
      ),
    );
  }

  /// Reduced motion: a short cross-fade instead of the 3D rotation.
  Widget _reducedMotion() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 180),
    child: widget.flipped
        ? KeyedSubtree(key: const ValueKey('back'), child: _back())
        : KeyedSubtree(key: const ValueKey('front'), child: _front()),
  );

  Widget _flip() => AnimatedBuilder(
    animation: _anim,
    builder: (context, _) {
      final t = _anim.value;
      final angle = t * math.pi;
      final showBack = t >= 0.5;
      // Perspective, then the Y rotation. The back is pre-rotated a half turn so
      // its text reads the right way round rather than mirrored.
      final transform = Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle);
      final face = showBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _back(),
            )
          : _front();
      return Transform(
        alignment: Alignment.center,
        transform: transform,
        child: face,
      );
    },
  );

  Widget _front() => Stack(
    children: [
      Positioned.fill(
        child: BankCard(
          bankName: widget.bankName,
          accountType: widget.accountType,
          brandColor: widget.brandColor,
          // NEVER the digits on the front. The same four digits sit behind
          // device authentication on the back and the detail screen, and a
          // front that says them out loud (and announces them to a screen
          // reader) makes that auth theater. The front shows plain dots;
          // the reveal is where the number lives.
          last4: null,
          balance: widget.balance,
          amountText: widget.amountText,
          monogram: widget.monogram,
          logoAsset: widget.logoAsset,
          creditLimit: widget.creditLimit,
          networkMark: widget.networkMark,
          variant: widget.variant,
          isWallet: widget.isWallet,
        ),
      ),
      // The affordance that the card turns over: a small rotate glyph, plus a
      // one-time hint the first time the founder ever sees a card.
      Positioned(
        right: 12,
        bottom: 10,
        child: Row(
          children: [
            if (widget.showHint)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Tap to view details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Icon(
              salapifyIcon('flip'),
              size: 18,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _back() {
    final g = bankCardGradient(widget.brandColor);
    final row = widget.row;
    final qrRef = _qrRef(row);
    final hasNotes =
        (row['paymentInstructions'] as String?)?.isNotEmpty == true;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: g[1].withValues(alpha: 0.42),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [g[0], g[1]],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _backHeader(),
                  const SizedBox(height: 8),
                  _numberRow(),
                  const SizedBox(height: 8),
                  Expanded(child: _figures()),
                  _actionRow(qrRef, hasNotes),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _backHeader() => Row(
    children: [
      Expanded(
        child: Text(
          widget.bankName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (widget.networkMark != null) ...[
        const SizedBox(width: 8),
        Text(
          widget.networkMark!,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
      const SizedBox(width: 8),
      Text(
        widget.accountType.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    ],
  );

  Widget _numberRow() {
    final last4 = widget.last4;
    return Row(
      children: [
        Text(
          'NUMBER',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 10),
        // Expanded + scale-down, not a fixed value + Spacer: the digits keep
        // the reveal and copy buttons at the right edge and shrink themselves on
        // a narrow phone rather than pushing the row past the card. The digits
        // are also excluded from the semantic tree when hidden, so a screen
        // reader never announces a value the eye cannot see.
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            // Geometric dots plus tabular last four, so revealing the digits
            // cannot change the line's width and the mask reads the same in
            // every font and both brightnesses (widgets/pan_mask_widget.dart).
            // One leading dot group then the last four, matching the old
            // "•••• ••••" the back showed. Excluded from semantics because the
            // number's spoken state lives on the reveal button beside it.
            child: ExcludeSemantics(
              child: CardNumberMask(
                last4: last4,
                revealed: _revealed,
                groups: 1,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ),
        if (last4 != null) ...[
          _iconButton(
            _revealed ? 'hidden' : 'reveal',
            _revealed
                ? 'Hide the last four digits'
                : 'Reveal the last four digits',
            _toggleReveal,
          ),
          _iconButton('copy', 'Copy the last four digits', _copyLast4),
        ],
      ],
    );
  }

  Widget _figures() {
    final row = widget.row;
    final chips = <Widget>[];
    if (_isCredit) {
      final limit = (row['creditLimit'] as num?)?.toDouble() ?? 0;
      final outstanding = widget.balance;
      final available = (limit - outstanding)
          .clamp(0, double.infinity)
          .toDouble();
      chips.add(_stat('Outstanding', formatMoneyText(outstanding)));
      if (limit > 0) {
        chips.add(_stat('Available', formatMoneyText(available)));
        chips.add(_stat('Limit', formatMoneyText(limit)));
      }
      final due = (row['dueDay'] as num?)?.toInt() ?? 0;
      final stmt = (row['statementDay'] as num?)?.toInt() ?? 0;
      if (stmt > 0) chips.add(_stat('Statement', 'Day $stmt'));
      if (due > 0) chips.add(_stat('Due', 'Day $due'));
    } else {
      chips.add(
        _stat('Balance', widget.amountText ?? formatMoneyText(widget.balance)),
      );
      final target = (row['target'] as num?)?.toDouble() ?? 0;
      if (target > 0) chips.add(_stat('Maintaining', formatMoneyText(target)));
    }
    return Align(
      alignment: Alignment.topLeft,
      child: Wrap(spacing: 18, runSpacing: 6, children: chips),
    );
  }

  Widget _stat(String label, String value) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
      const SizedBox(height: 1),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );

  Widget _actionRow(String? qrRef, bool hasNotes) => Row(
    children: [
      if (qrRef != null)
        _iconButton(
          'qr',
          'Show the receiving QR code',
          () => _openQr(qrRef, widget.row['qrLabel'] as String?),
        ),
      if (hasNotes)
        _iconButton('note', 'View the notes', widget.onViewFullDetails),
      _iconButton('edit', 'Edit this account', widget.onEdit),
      // Expanded, not a Spacer + fixed button: it hands the trailing button all
      // the room the icons leave and no more, so on a narrow card (or the wider
      // test font) the label ellipsizes inside its own space instead of pushing
      // the row a few pixels past the edge.
      Expanded(
        child: Align(
          alignment: Alignment.centerRight,
          // The one that leaves the card: the full wallet page.
          child: TextButton(
            onPressed: widget.onViewFullDetails,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Flexible(
                  child: Text(
                    'View full details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(salapifyIcon('forward'), size: 16, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _iconButton(String name, String tooltip, VoidCallback onTap) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        iconSize: 18,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        splashRadius: 20,
        icon: Icon(salapifyIcon(name), color: Colors.white),
      );

  String? _qrRef(Map<String, dynamic> row) {
    final v = row['qrRef'];
    return (v is String && v.isNotEmpty) ? v : null;
  }
}
