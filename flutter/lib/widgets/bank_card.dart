// A physical looking bank card for one account.
//
// The gradient is built from the bank's BRAND color, which lives once in the
// institutions catalog (money/institutions.dart, ported from the RN
// mobile/lib/banks.js). This widget never reads a second color list and never
// draws a logo: text and color only, which is the trademark line the project
// keeps. A bank is recognised by its brand color plus a faint MONOGRAM (its
// initials), not by its mark, which needs a permission this project does not
// have and cannot travel in a Shorebird patch anyway. An account with no known
// brand color (cash, an unlisted wallet) gets a neutral graphite gradient so it
// still looks like a card.
//
// All text is white or white with opacity. bankCardGradient darkens the base
// until OPAQUE white clears WCAG AA (4.5:1) on the two stops that carry the
// small text (the base and the darker end); bank_card_test.dart proves that
// against every brand color in the catalog. The card also paints a lighter
// SHEEN stop above the base for depth, and only the large, bold bank name sits
// on it, which needs the gentler 3:1 large-text bar, so the sheen is a visual
// highlight rather than part of the AA contract.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../money/debtmath.dart' show formatMoneyText;
import '../money/institutions.dart' show initialsFor;
import '../theme.dart';
import 'salapify_icon.dart' show salapifyIcon;

/// Which face a [BankCard] shows. Savings shows one balance; credit shows the
/// outstanding balance against a limit, with a utilization bar.
enum BankCardVariant { savings, credit }

/// The neutral fill for an account with no brand color (cash, an unlisted
/// wallet). A calm slate so the card still reads as a card, not an error.
const Color kBankCardNeutral = Color(0xFF3A424E);

/// The width the card content is laid out at before FittedBox scales it to the
/// real card. Any value works since it scales; 320 keeps the design numbers
/// readable while editing.
const double _designWidth = 320;

/// The two AA-safe stops of a card gradient for a brand color: a readable base
/// and a darker end. Exposed so the carousel fallback and the contrast test
/// read the exact colors the card paints under its small text, never a
/// re-derived copy. The card adds a lighter sheen ABOVE [0] for depth (see the
/// file header); that sheen only underlies the large bank name.
List<Color> bankCardGradient(Color? brandColor) {
  final start = _readableBase(brandColor ?? kBankCardNeutral);
  return [start, _scale(start, 0.72)];
}

/// White text contrast against [c], per WCAG. Used both to darken a bright
/// brand color into range and, in the test, to prove the result cleared AA.
double whiteContrastOf(Color c) => 1.05 / (_relativeLuminance(c) + 0.05);

class BankCard extends StatelessWidget {
  /// Shown top left. Already resolved to a name, never a logo image.
  final String bankName;

  /// Shown top right, e.g. "Savings" or "Credit". Short.
  final String accountType;

  /// The brand fill. Null falls back to the neutral gradient.
  final Color? brandColor;

  /// The last four digits of a stored card or account number, or null. When
  /// absent the number shows as masked dots with no digits.
  final String? last4;

  /// Savings: the balance. Credit: the outstanding balance.
  final double balance;

  /// Overrides how [balance] is printed. Passed for a foreign-currency account
  /// so the card shows the account's own symbol (for example "$1,000.00")
  /// instead of a peso figure, which would be the wrong symbol and would clash
  /// with the net worth total that leaves an unpriced currency out. Null for
  /// the base currency, where [balance] is simply formatted as pesos.
  final String? amountText;

  /// The faint corner watermark, the bank's initials standing in for a logo.
  /// Null derives it from [bankName], so the carousel can pass the institution's
  /// own initials for accuracy ("UB" for a UnionBank "Salary account").
  final String? monogram;

  /// Credit only: the credit limit, used for the utilization bar.
  final double? creditLimit;

  /// The card network's WORDMARK, e.g. "VISA", or null. Drawn as plain text at
  /// the bottom-right, the corner a real card carries its scheme mark, never a
  /// logo image. White on the card's darker end, which already clears the small
  /// text AA bar the gradient guarantees.
  final String? networkMark;

  final BankCardVariant variant;

  // Not const: every Barako read happens at build time.
  // ignore: prefer_const_constructors_in_immutables
  BankCard({
    super.key,
    required this.bankName,
    required this.accountType,
    required this.balance,
    this.brandColor,
    this.last4,
    this.amountText,
    this.monogram,
    this.creditLimit,
    this.networkMark,
    this.variant = BankCardVariant.savings,
  });

  @override
  Widget build(BuildContext context) {
    final g = bankCardGradient(brandColor);
    final mark = (monogram == null || monogram!.isEmpty)
        ? initialsFor(bankName)
        : monogram!;
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
        // Shadow only, tinted with the darkest gradient color, drawn outside
        // the clip so it is not itself clipped.
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
          // The content is laid out at a fixed REFERENCE size that shares the
          // card's 1.586 ratio, then scaled to the real card by FittedBox, the
          // way a physical card scales: a narrow phone gets a smaller but
          // identical card instead of an overflow, a wide one gets a larger one.
          // System font scaling is clamped first so the design stays stable; the
          // freely scaling copy of every number lives in the detail panel and
          // the account rows below, which is where accessibility lives.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.0,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _designWidth,
                height: _designWidth / 1.586,
                child: Stack(
                  children: [
                    // Two-tone brand gradient: a lighter sheen at the top-left,
                    // the readable base through the middle, the darker end at the
                    // bottom-right where the balance sits.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_sheen(g[0]), g[0], g[1]],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // The faint brand monogram, a logo stand-in, bleeding off the
                    // bottom-right corner. Text and color only.
                    Positioned(
                      right: -6,
                      bottom: -18,
                      child: Text(
                        mark,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.08),
                          fontSize: 96,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  bankName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                accountType.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const _CardChip(),
                              const SizedBox(width: 10),
                              // The contactless mark, the same cue a real card
                              // carries. Routed through the icon system, drawn
                              // white to sit on the card rather than in accent.
                              Icon(
                                salapifyIcon('contactless'),
                                size: 18,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const Spacer(),
                              // The network wordmark rides this row, well clear
                              // of the balance and the credit utilization bar
                              // below. Text only, never a logo, white on the
                              // card's darker end so it clears the small-text AA
                              // bar the gradient guarantees.
                              if (networkMark != null && networkMark!.isNotEmpty)
                                Text(
                                  networkMark!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                          const Spacer(),
                          // A screen reader hears "ending 1234" once, not the
                          // run of bullets. The last four is not a secret (a
                          // physical card shows it), so the hero states it
                          // cleanly; the secure section below is where reveal,
                          // copy and auth live for the account number.
                          Semantics(
                            label: (last4 != null &&
                                    RegExp(r'^\d{4}$').hasMatch(last4!))
                                ? 'Card number ending $last4'
                                : 'Card number not saved',
                            child: ExcludeSemantics(
                              child: Text(
                                _maskedNumber(last4),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (variant == BankCardVariant.credit)
                            _CreditFooter(
                              outstanding: balance,
                              limit: creditLimit ?? 0,
                            )
                          else
                            _SavingsFooter(
                              amountText: amountText ?? formatMoneyText(balance),
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

/// A wallet, not a card, for physical cash.
///
/// Cash has no number to mask, no chip, no contactless tap, and no network, so
/// dressing it as a bank card was a small lie the founder caught at a glance:
/// "Cash on hand" wore a `•••• •••• •••• 1111` and a gold chip. This is the
/// honest visual, sharing the card's exact footprint (the same 1.586 ratio,
/// shadow, neutral graphite gradient and FittedBox scaling, so it sits in the
/// carousel beside the real cards) but carrying a wallet emblem and the balance
/// instead. It does not flip, because there is no back worth turning to: a tap
/// opens the account, the same as before the flip card shipped.
class CashCard extends StatelessWidget {
  /// The account's display name, e.g. "Cash on hand".
  final String name;

  /// The balance, and its preformatted foreign-currency form when the account
  /// is not in the base currency (same contract as [BankCard.amountText]).
  final double balance;
  final String? amountText;

  /// The short kicker, top-right, e.g. "Cash". Defaults to "Cash".
  final String label;

  // Not const: reads no Barako getter today, but kept parallel to BankCard so a
  // later themed cash color cannot silently freeze behind a const call site.
  // ignore: prefer_const_constructors_in_immutables
  CashCard({
    super.key,
    required this.name,
    required this.balance,
    this.amountText,
    this.label = 'Cash',
  });

  @override
  Widget build(BuildContext context) {
    final g = bankCardGradient(null); // always the neutral graphite: cash has no brand
    return AspectRatio(
      aspectRatio: 1.586,
      child: Container(
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
            maxScaleFactor: 1.0,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _designWidth,
                height: _designWidth / 1.586,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_sheen(g[0]), g[0], g[1]],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // The wallet emblem bleeding off the corner, standing in for
                    // the brand monogram a real card carries. A glyph, not text.
                    Positioned(
                      right: -10,
                      bottom: -22,
                      child: Icon(
                        salapifyIcon('wallet'),
                        size: 128,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                label.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // The wallet emblem where a card's chip would sit: a
                          // soft rounded pouch with the wallet glyph, so the
                          // tile reads as money you are holding, not a card.
                          Container(
                            width: 44,
                            height: 34,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                            child: Icon(
                              salapifyIcon('wallet'),
                              size: 22,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                          const Spacer(),
                          _SavingsFooter(
                            amountText: amountText ?? formatMoneyText(balance),
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

/// The savings face: a label and the balance, no bar.
class _SavingsFooter extends StatelessWidget {
  final String amountText;
  const _SavingsFooter({required this.amountText});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _footerKicker('BALANCE'),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amountText,
            maxLines: 1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// The credit face: outstanding as the big number, the limit beside it small,
/// and a thin utilization bar that warns above 70 percent.
class _CreditFooter extends StatelessWidget {
  final double outstanding;
  final double limit;
  const _CreditFooter({required this.outstanding, required this.limit});

  @override
  Widget build(BuildContext context) {
    // Guard the divide: a card with no limit set has no meaningful bar, so it
    // sits empty rather than dividing by zero.
    final fraction = limit > 0 ? (outstanding / limit).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _footerKicker('OUTSTANDING'),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatMoneyText(outstanding),
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (limit > 0) ...[
              const SizedBox(width: 8),
              Text(
                'of ${formatMoneyText(limit)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (limit > 0) ...[
          const SizedBox(height: 6),
          _UtilizationBar(fraction: fraction.toDouble()),
        ],
      ],
    );
  }
}

/// The thin utilization track. White fill under 70 percent, the Barako warning
/// color at or above it, because that is the point a card is getting full.
class _UtilizationBar extends StatelessWidget {
  final double fraction;
  const _UtilizationBar({required this.fraction});

  @override
  Widget build(BuildContext context) {
    final warn = fraction >= 0.70;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 6,
        backgroundColor: Colors.white.withValues(alpha: 0.24),
        color: warn ? Barako.warning : Colors.white,
      ),
    );
  }
}

/// The little gold chip, drawn, never an asset. Two faint contact lines across
/// a rounded gold rectangle read as a card chip at a glance.
class _CardChip extends StatelessWidget {
  const _CardChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 26,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6DE9A), Color(0xFFC79A2E)],
        ),
      ),
      child: Center(
        child: Container(
          width: 20,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: const Color(0xFF9A6E08).withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _footerKicker(String text) => Text(
  text,
  style: TextStyle(
    color: Colors.white.withValues(alpha: 0.85),
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  ),
);

String _maskedNumber(String? last4) {
  final ok = last4 != null && RegExp(r'^\d{4}$').hasMatch(last4);
  return '•••• •••• '
      '•••• ${ok ? last4 : '••••'}';
}

// --- Color math: darken a bright brand color until white text clears AA. ---

Color _readableBase(Color base) {
  var c = Color.fromARGB(255, _byte(base.r), _byte(base.g), _byte(base.b));
  var guard = 0;
  // 4.5:1 is the AA bar for the small labels on the card, not just the hero
  // number, so every line stays readable on the lightest brand color.
  while (whiteContrastOf(c) < 4.5 && guard < 60) {
    c = _scale(c, 0.94);
    guard++;
  }
  return c;
}

/// The lighter sheen stop, a small step toward white for depth. Only the large
/// bank name sits on it, so it is not held to the small-text AA bar.
Color _sheen(Color c) => Color.lerp(c, Colors.white, 0.10)!;

Color _scale(Color c, double f) => Color.fromARGB(
  255,
  _byte(c.r * f),
  _byte(c.g * f),
  _byte(c.b * f),
);

int _byte(double channel01) => (channel01 * 255).round().clamp(0, 255);

double _relativeLuminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _lin(double channel01) => channel01 <= 0.03928
    ? channel01 / 12.92
    : math.pow((channel01 + 0.055) / 1.055, 2.4).toDouble();
