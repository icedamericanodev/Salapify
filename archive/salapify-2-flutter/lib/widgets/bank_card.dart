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
import '../typography.dart';
import 'pan_mask_widget.dart' show CardNumberMask;
import 'salapify_icon.dart' show salapifyIcon, SalapifyGlyph;

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

  /// The bundled wordmark logo asset for this institution, or null. When set,
  /// it draws on a clean white chip in place of [bankName] text (never on the
  /// colored gradient, which brand guidelines forbid). Null keeps the text
  /// name. A load failure falls back to the name too, so a missing file is
  /// never a blank card. Logos are shown only to identify the user's own
  /// account and Salapify is not affiliated with any bank; see the
  /// non-affiliation notice on the accounts screen.
  final String? logoAsset;

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

  /// An e-wallet is a phone-number-addressed balance, not an embossed card:
  /// no chip, no contactless mark, no fabricated masked number. The brand
  /// color and the corner label already carry the identity.
  final bool isWallet;

  // Not const: every Barako read happens at build time.
  // ignore: prefer_const_constructors_in_immutables
  BankCard({
    super.key,
    required this.bankName,
    required this.accountType,
    required this.balance,
    this.logoAsset,
    this.brandColor,
    this.last4,
    this.amountText,
    this.monogram,
    this.creditLimit,
    this.networkMark,
    this.isWallet = false,
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
                    // The faint brand monogram, a logo STAND-IN, bleeding off the
                    // bottom-right corner. Text and color only, and only when
                    // there is no real logo: once the wordmark chip is present
                    // the monogram is redundant, so a logo'd card drops it.
                    if (logoAsset == null)
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
                      // 16 horizontal, 12 vertical. The credit face's fixed
                      // furniture summed about 9px past the 1.586 aspect at a
                      // 390dp phone width, an overflow that had never been
                      // rendered at exactly this size; the batch 4 guard
                      // caught it in the shipped font.
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: logoAsset == null
                                      ? Text(
                                          bankName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        )
                                      : _BrandChip(
                                          logoAsset: logoAsset!,
                                          fallbackName: bankName,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                accountType.toUpperCase(),
                                // Opaque white: the gradient's AA guarantee
                                // only covers full white, and 0.85 landed
                                // around 3.7:1 on the lightest brands.
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              // A wallet has no chip and no tap-to-pay; the
                              // payment-card furniture only draws where a
                              // payment card exists.
                              if (!isWallet) ...[
                                const _CardChip(),
                                const SizedBox(width: 10),
                                // The contactless mark, the same cue a real
                                // card carries. Routed through the icon
                                // system, drawn white to sit on the card
                                // rather than in accent.
                                Icon(
                                  salapifyIcon('contactless'),
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ],
                              const Spacer(),
                              // The network wordmark rides this row, well clear
                              // of the balance and the credit utilization bar
                              // below. Text only, never a logo, white on the
                              // card's darker end so it clears the small-text AA
                              // bar the gradient guarantees.
                              if (networkMark != null &&
                                  networkMark!.isNotEmpty)
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
                          // A wallet shows no number line at all: sixteen
                          // fabricated dots on a card that has no PAN taught
                          // nothing and lied a little.
                          if (isWallet)
                            const SizedBox.shrink()
                          else
                            // The digits never show HERE since f3.88: the same
                            // four digits sit behind device auth on the flip
                            // side and the detail screen, so the front saying
                            // them out loud made that auth theater. Dots only,
                            // and the label says where the number lives.
                            Semantics(
                              label:
                                  (last4 != null &&
                                      RegExp(r'^\d{4}$').hasMatch(last4!))
                                  ? 'Card number ending $last4'
                                  : 'Card number hidden here',
                              // Three masked groups then the last four. Geometric
                              // dots and tabular digits so the line holds its
                              // width and looks identical in every font and
                              // brightness (widgets/pan_mask_widget.dart). The
                              // caller decides whether real digits are passed;
                              // when they are, the widget shows them, otherwise
                              // dots, so this stays honest either way.
                              child: ExcludeSemantics(
                                child: CardNumberMask(
                                  last4: last4,
                                  revealed: true,
                                  groups: 3,
                                  color: Colors.white,
                                  fontSize: 15,
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
                              amountText:
                                  amountText ?? formatMoneyText(balance),
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

/// A compact balance tile for physical cash, deliberately NOT card-shaped.
///
/// Cash is money you are holding, not an account at an institution, so it must
/// not share the bank cards' visual language. The founder's complaint, twice
/// over, was that a restyled card is still a card: same 16:9 footprint, same
/// swipe deck. So this is a different COMPONENT: a short, full-width soft panel
/// (no [AspectRatio], no chip, no contactless, no masked number, no gradient),
/// content-height, with a wallet emblem, the balance, and a chevron that says a
/// tap opens the account. It lives in its own "Cash on hand" section above the
/// card carousel and never flips. Every colour is a Barako getter, so it follows
/// all sixteen palettes and both brightnesses; it presents [balance] and does no
/// arithmetic (the golden-locked [formatMoneyText] does the formatting).
class CashBalanceTile extends StatelessWidget {
  /// The account's display name, e.g. "Cash on hand".
  final String name;

  /// The balance, and its preformatted foreign-currency form when the account
  /// is not in the base currency (same contract as [BankCard.amountText]).
  final double balance;
  final String? amountText;

  /// The plain-English subtitle under the name. Defaults to "Physical cash".
  final String subtitle;

  // Not const: every colour below is a mutable Barako getter read in build, so
  // a const call site would freeze the tile in the previous palette after a
  // theme switch (the same trap SalapifyGlyph documents).
  // ignore: prefer_const_constructors_in_immutables
  CashBalanceTile({
    super.key,
    required this.name,
    required this.balance,
    this.amountText,
    this.subtitle = 'Physical cash',
  });

  @override
  Widget build(BuildContext context) {
    final accent = Barako.primary;
    // A soft accent wash over the app's card surface: warm, flat, and light
    // enough that it stays ~equal to Barako.card, so every text-on-card pair the
    // contrast sweep already validates still holds and no new pair is added.
    final fill = Color.alphaBlend(accent.withValues(alpha: 0.08), Barako.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Stack(
            children: [
              // A faint banknote motif bleeding off the corner, small so it
              // never crowds a short tile. The cash stand-in for a card's
              // brand monogram: a glyph, in accent.
              Positioned(
                right: -14,
                bottom: -18,
                child: Icon(
                  salapifyIcon('cash'),
                  size: 76,
                  color: accent.withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // The wallet emblem in the app's own accent disc, which the
                    // bank cards never use: the primary "this is your cash" cue.
                    SalapifyGlyph('wallet', size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.subtitle,
                          ),
                          const SizedBox(height: 2),
                          Text(subtitle, style: AppText.caption),
                          const SizedBox(height: 10),
                          Text('AVAILABLE CASH', style: Barako.kickerStyle),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              amountText ?? formatMoneyText(balance),
                              maxLines: 1,
                              style: AppText.amountRow.w8
                                  .copyWith(fontSize: 24)
                                  .tint(Barako.primaryText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // A tap opens the account: the chevron says so, where a card
                    // would carry the flip glyph.
                    Icon(
                      salapifyIcon('forward'),
                      size: 20,
                      color: Barako.faint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bank / savings account rendered as a realistic bank card. A thin, named
/// alias over [BankCard] so call sites read as the account type they show,
/// while the single BankCard implementation keeps the one AA-contrast contract.
class BankAccountCard extends StatelessWidget {
  final String bankName;
  final String accountType;
  final Color? brandColor;
  final String? last4;
  final double balance;
  final String? amountText;
  final String? monogram;

  const BankAccountCard({
    super.key,
    required this.bankName,
    required this.accountType,
    required this.balance,
    this.brandColor,
    this.last4,
    this.amountText,
    this.monogram,
  });

  @override
  Widget build(BuildContext context) => BankCard(
    bankName: bankName,
    accountType: accountType,
    brandColor: brandColor,
    last4: last4,
    balance: balance,
    amountText: amountText,
    monogram: monogram,
    variant: BankCardVariant.savings,
  );
}

/// A credit card rendered with its outstanding balance, limit and utilization.
/// A thin, named alias over [BankCard], for the same reason as [BankAccountCard].
class CreditCardAccountCard extends StatelessWidget {
  final String bankName;
  final Color? brandColor;
  final String? last4;
  final double outstanding;
  final double? creditLimit;
  final String? monogram;
  final String? networkMark;

  const CreditCardAccountCard({
    super.key,
    required this.bankName,
    required this.outstanding,
    this.brandColor,
    this.last4,
    this.creditLimit,
    this.monogram,
    this.networkMark,
  });

  @override
  Widget build(BuildContext context) => BankCard(
    bankName: bankName,
    accountType: 'Credit',
    brandColor: brandColor,
    last4: last4,
    balance: outstanding,
    creditLimit: creditLimit,
    monogram: monogram,
    networkMark: networkMark,
    variant: BankCardVariant.credit,
  );
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
        // Plain words on the most important number a card shows: to a
        // first-jobber, "outstanding" reads as praise, not debt. It also
        // makes the card agree with the summary's "Total owed".
        _footerKicker('YOU OWE'),
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
                style: const TextStyle(
                  color: Colors.white,
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
    // The warning is words AND color: the tint flip alone was invisible to a
    // colorblind or grayscale reader, and the bare percentage TalkBack spoke
    // had no name. The words ride BESIDE the bar because the card face is a
    // fixed aspect with no vertical room to give.
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              semanticsLabel: 'Credit used',
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              color: warn ? Barako.warning : Colors.white,
            ),
          ),
        ),
        if (warn) ...[
          const SizedBox(width: 6),
          const Text(
            'Getting full',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ],
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

/// The bank's real wordmark on a clean white chip, the ONE place a logo is
/// allowed. White because brand guidelines want their mark on a neutral field,
/// not baked into a colored gradient, and because a white chip reads in every
/// palette and both brightnesses. A load failure degrades to the bank name in
/// dark text on the same chip, so a missing or bad file never blanks the card.
class _BrandChip extends StatelessWidget {
  final String logoAsset;
  final String fallbackName;
  const _BrandChip({required this.logoAsset, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150, maxHeight: 22),
        child: Image.asset(
          logoAsset,
          fit: BoxFit.contain,
          height: 20,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => Text(
            fallbackName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _footerKicker(String text) => Text(
  text,
  // Opaque, same AA reasoning as the type label above.
  style: const TextStyle(
    color: Colors.white,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  ),
);

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

Color _scale(Color c, double f) =>
    Color.fromARGB(255, _byte(c.r * f), _byte(c.g * f), _byte(c.b * f));

int _byte(double channel01) => (channel01 * 255).round().clamp(0, 255);

double _relativeLuminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _lin(double channel01) => channel01 <= 0.03928
    ? channel01 / 12.92
    : math.pow((channel01 + 0.055) / 1.055, 2.4).toDouble();
