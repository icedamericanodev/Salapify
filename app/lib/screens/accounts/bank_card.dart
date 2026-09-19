import 'package:flutter/material.dart';

import '../../core/money/accounts.dart';
import '../../core/money/currencies.dart';
import '../../core/money/format.dart';
import '../../design/institution_brand.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import 'card_art.dart';

/// A debit or credit account drawn as a piece of plastic, from
/// src/components/BankCard.tsx.
///
/// Only `debit` and `credit` accounts get one. Everything else is a row,
/// because a card is a big object and a screen made entirely of them is a
/// screen you have to scroll to count your wallets.
///
/// ## Why this looks like a real card rather than a coloured rectangle
///
/// Founder direction, 2026-09-19: make the card "look like near the real bank
/// physical cards depend of their scheme". That is not decoration. A wallet is
/// recognised by SHAPE before it is read, so the closer this is to the object
/// in somebody's hand, the faster they find the right one. Four things do the
/// work, and all four are cues from the real thing:
///
///  - the ISO/IEC 7810 ID-1 proportion, 85.6 by 53.98 mm, so it is the shape
///    of a card and not of a banner;
///  - the issuer's own mark, bundled rather than fetched (see
///    institution_brand.dart for why it is not the prototype's remote URL);
///  - a drawn EMV chip and contactless arcs, which is the cue people read as
///    "plastic" without ever noticing they read it;
///  - the scheme's own mark, in its own colours, because Visa and Mastercard
///    are how two cards from the same bank are told apart.
///
/// The tier decides the FINISH, the way it does on real plastic: gold, brushed
/// platinum, matte black. That overrides the issuer's marketing palette,
/// because somebody who recorded a card as Platinum is describing the object
/// they hold.
class BankCard extends StatelessWidget {
  const BankCard({
    super.key,
    required this.account,
    required this.palette,
    this.onTap,
  });

  final Account account;
  final Palette palette;
  final VoidCallback? onTap;

  /// ISO/IEC 7810 ID-1: 85.60 by 53.98 mm.
  static const double aspect = 85.60 / 53.98;

  /// The issuer skins, the banks' own colours rather than Salapify's.
  ///
  /// A wallet of sixteen identical rust rectangles is slower to use than one
  /// where BPI is red and GCash is blue.
  static const Map<String, (Color, Color)> _issuerSkins =
      <String, (Color, Color)>{
        'BPI': (Color(0xFFB11116), Color(0xFF6E0B0E)),
        'BDO': (Color(0xFF12519E), Color(0xFF0A2E5C)),
        'UnionBank': (Color(0xFFF58220), Color(0xFFA8490A)),
        'GCash': (Color(0xFF1972F9), Color(0xFF0B2757)),
        'Maya': (Color(0xFF1B3A4B), Color(0xFF0B1620)),
        'Metrobank': (Color(0xFF00529B), Color(0xFF002A52)),
        'MariBank': (Color(0xFFE8620C), Color(0xFF9C3D04)),
        'GoTyme': (Color(0xFF00A9E0), Color(0xFF00597A)),
        'RCBC': (Color(0xFF00529B), Color(0xFF00223F)),
        'Security Bank': (Color(0xFF00573F), Color(0xFF002A1E)),
        'EastWest': (Color(0xFF00447C), Color(0xFF001E38)),
        'PNB': (Color(0xFF00529B), Color(0xFF7A1418)),
        'LandBank': (Color(0xFF00703C), Color(0xFF00381E)),
        'PSBank': (Color(0xFF004B8D), Color(0xFF002648)),
        'China Bank': (Color(0xFFC8102E), Color(0xFF6E0918)),
        'Tonik': (Color(0xFF00C2A8), Color(0xFF00655A)),
        'CIMB': (Color(0xFFD40F2E), Color(0xFF75081A)),
        'Atome': (Color(0xFFEE3B7B), Color(0xFF8E1F49)),
      };

  /// (from, to, ink, metallic)
  ///
  /// `metallic` turns on the diagonal sheen. Gold, platinum and black cards
  /// are physically reflective and a flat fill reads as paper.
  (Color, Color, Color, bool) _skin() {
    switch (account.cardTier) {
      case CardTier.gold:
        return (
          const Color(0xFFD9A441),
          const Color(0xFF8A5B12),
          const Color(0xFF2A1B03),
          true,
        );
      case CardTier.platinum:
        return (
          const Color(0xFFBFC3C7),
          const Color(0xFF6E7378),
          const Color(0xFF15181B),
          true,
        );
      case CardTier.black:
        return (
          const Color(0xFF2B2B2E),
          const Color(0xFF09090B),
          const Color(0xFFEDEDED),
          true,
        );
      case CardTier.custom:
        return (palette.surfaceAlt, palette.surface, palette.textPrimary, false);
      case CardTier.regular:
        final (Color, Color)? issuer = _issuerSkins[account.institution];
        if (issuer == null) {
          return (
            palette.surfaceAlt,
            palette.surface,
            palette.textPrimary,
            false,
          );
        }
        return (issuer.$1, issuer.$2, Colors.white, false);
    }
  }

  /// The number in card groups: `•••• •••• •••• 6789`.
  ///
  /// Never the whole number. This screen gets opened in public, and a full PAN
  /// on a phone is a PAN on a phone. The grouping is what makes it read as a
  /// card rather than as a code.
  String get _pan {
    final String? stored = account.accountNumber;
    final String digits = stored == null
        ? ''
        : stored.replaceAll(RegExp(r'[^0-9]'), '');
    final String tail = digits.length >= 4
        ? digits.substring(digits.length - 4)
        : '••••';
    return '••••  ••••  ••••  $tail';
  }

  @override
  Widget build(BuildContext context) {
    final bool isCredit = account.kind == AccountKind.credit;
    final (Color from, Color to, Color ink, bool metallic) = _skin();
    final Color inkSoft = ink.withValues(alpha: 0.74);
    final bool paleCard =
        ThemeData.estimateBrightnessForColor(from) == Brightness.light;

    final String balance = account.isForeign
        ? formatCurrency(account.balance.abs(), account.currency)
        : formatPeso(account.balance.abs());

    final InstitutionBrand? brand = brandFor(account.institution);

    return Semantics(
      button: onTap != null,
      label:
          '${account.name}, ${account.institution}, '
          '${isCredit ? 'outstanding' : 'available'} $balance',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _plastic(from, to, ink, inkSoft, metallic, paleCard, brand, isCredit, balance),
            // Utilisation sits BELOW the plastic rather than on it. Real cards
            // do not print how much of the limit you have spent, and squeezing
            // it inside would cost the card its proportions, which are the
            // thing that makes it read as a card at all.
            if (isCredit) _Utilisation(account: account, palette: palette),
          ],
        ),
      ),
    );
  }

  Widget _plastic(
    Color from,
    Color to,
    Color ink,
    Color inkSoft,
    bool metallic,
    bool paleCard,
    InstitutionBrand? brand,
    bool isCredit,
    String balance,
  ) {
    return AspectRatio(
          aspectRatio: aspect,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[from, to],
              ),
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: ink.withValues(alpha: 0.18)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // The sheen: one soft diagonal band, the way light falls
                // across a real metal card. Only on the finishes that have
                // one, or every card looks like it is behind glass.
                if (metallic)
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.card),
                        gradient: LinearGradient(
                          begin: const Alignment(-1, -1),
                          end: const Alignment(1, 1),
                          stops: const <double>[0.30, 0.46, 0.62],
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.22),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      // Everything scales off the card's own height, so the
                      // chip and the type keep their proportions whether this
                      // is drawn full width or in a narrow column.
                      final double h = c.maxHeight;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _TopRow(
                            account: account,
                            brand: brand,
                            ink: ink,
                            inkSoft: inkSoft,
                            height: h,
                          ),
                          SizedBox(height: h * 0.06),
                          Row(
                            children: <Widget>[
                              EmvChip(width: h * 0.175, dark: paleCard),
                              SizedBox(width: h * 0.05),
                              ContactlessMark(ink: inkSoft, size: h * 0.13),
                            ],
                          ),
                          SizedBox(height: h * 0.05),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _pan,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: AppType.family,
                                fontSize: h * 0.115,
                                fontWeight: FontWeight.w700,
                                letterSpacing: h * 0.012,
                                color: inkSoft,
                                height: 1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _BottomRow(
                            account: account,
                            isCredit: isCredit,
                            balance: balance,
                            ink: ink,
                            inkSoft: inkSoft,
                            height: h,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
  }
}

/// Issuer mark and name, the way they sit on real plastic: the brand at the
/// top, the tier called out beside it when there is one.
class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.account,
    required this.brand,
    required this.ink,
    required this.inkSoft,
    required this.height,
  });

  final Account account;
  final InstitutionBrand? brand;
  final Color ink;
  final Color inkSoft;
  final double height;

  @override
  Widget build(BuildContext context) {
    final String? tier = switch (account.cardTier) {
      CardTier.gold => 'GOLD',
      CardTier.platinum => 'PLATINUM',
      CardTier.black => 'BLACK',
      CardTier.regular || CardTier.custom => null,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                account.institution.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppType.family,
                  fontSize: height * 0.075,
                  fontWeight: FontWeight.w800,
                  letterSpacing: height * 0.012,
                  color: inkSoft,
                  height: 1.1,
                ),
              ),
              Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppType.family,
                  fontSize: height * 0.10,
                  fontWeight: FontWeight.w700,
                  color: ink,
                  height: 1.2,
                ),
              ),
              if (tier != null)
                Text(
                  tier,
                  style: TextStyle(
                    fontFamily: AppType.family,
                    fontSize: height * 0.062,
                    fontWeight: FontWeight.w800,
                    letterSpacing: height * 0.02,
                    color: inkSoft,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        // The issuer's own mark on a white plate, which is how it appears on
        // the real card: printed, not tinted to the plastic.
        if (brand != null && brand!.hasMark)
          Container(
            width: height * 0.2,
            height: height * 0.2,
            padding: EdgeInsets.all(height * 0.022),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(height * 0.05),
            ),
            child: Image.asset(
              brand!.asset!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          )
        else
          Text(
            account.monogram,
            style: TextStyle(
              fontFamily: AppType.family,
              fontSize: height * 0.10,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
      ],
    );
  }
}

class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.account,
    required this.isCredit,
    required this.balance,
    required this.ink,
    required this.inkSoft,
    required this.height,
  });

  final Account account;
  final bool isCredit;
  final String balance;
  final Color ink;
  final Color inkSoft;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                isCredit ? 'OUTSTANDING BALANCE' : 'AVAILABLE BALANCE',
                style: TextStyle(
                  fontFamily: AppType.family,
                  fontSize: height * 0.062,
                  fontWeight: FontWeight.w800,
                  letterSpacing: height * 0.012,
                  color: inkSoft,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  // A credit card's balance is money OWED, so it is drawn
                  // with a minus. Without it a 12,000 debt renders character
                  // for character like 12,000 in savings.
                  isCredit && account.balance > 0 ? '-$balance' : balance,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: AppType.family,
                    fontSize: height * 0.145,
                    fontWeight: FontWeight.w800,
                    color: ink,
                    height: 1.1,
                  ),
                ),
              ),
              if (account.isForeign)
                Text(
                  '≈ ${formatPeso(account.balanceInPhp.abs())}',
                  style: TextStyle(
                    fontFamily: AppType.family,
                    fontSize: height * 0.062,
                    color: inkSoft,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: Spacing.sm),
        SchemeMark(
          network: account.cardNetwork,
          ink: ink,
          height: height * 0.13,
        ),
      ],
    );
  }
}

/// How much of the limit is used, on the app's own surface under the card.
///
/// It moved off the plastic when the card took its real proportions. That is
/// an improvement rather than a compromise: real cards do not print your
/// utilisation, and on the app's surface this can use the palette's own
/// warning colour instead of a wash of the card's ink.
class _Utilisation extends StatelessWidget {
  const _Utilisation({required this.account, required this.palette});

  final Account account;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final int? used = creditUtilization(account);

    if (used == null) {
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.sm),
        child: Text(
          'Add this card’s limit to see how much of it you are using.',
          style: AppType.caption(palette),
        ),
      );
    }

    final bool high = isHighUtilization(account);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text('Credit used', style: AppType.caption(palette)),
              ),
              Text(
                // The number AND the word, never colour alone. Roughly one man
                // in twelve cannot separate this red from this green.
                high ? '$used%, over 30%' : '$used%',
                style: AppType.caption(palette).copyWith(
                  fontWeight: FontWeight.w800,
                  color: high ? palette.negative : palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: (used / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: palette.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                high ? palette.negative : palette.accent,
              ),
            ),
          ),
          if (account.creditLimit != null)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.xs),
              child: Text(
                'Limit ${formatCurrency(account.creditLimit!, account.currency)}',
                style: AppType.caption(palette),
              ),
            ),
        ],
      ),
    );
  }
}
