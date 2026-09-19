import 'dart:math' as math;

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
class BankCard extends StatefulWidget {
  const BankCard({
    super.key,
    required this.account,
    required this.palette,
    this.onTap,
  });

  final Account account;
  final Palette palette;

  /// Opens the edit sheet. Reached from the BACK of the card now rather than
  /// from the card itself, because tapping the card turns it over.
  final VoidCallback? onTap;

  /// How long the turn takes. Long enough to read as a physical object being
  /// flipped, short enough that somebody checking a due date twice does not
  /// start waiting for it.
  static const Duration flipDuration = Duration(milliseconds: 420);

  /// ISO/IEC 7810 ID-1: 85.60 by 53.98 mm.
  static const double aspect = 85.60 / 53.98;

  @override
  State<BankCard> createState() => _BankCardState();
}

class _BankCardState extends State<BankCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: BankCard.flipDuration,
  );

  Account get account => widget.account;
  Palette get palette => widget.palette;
  VoidCallback? get onTap => widget.onTap;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  bool get _showingBack => _flip.value > 0.5;

  void _turn() {
    if (_flip.isAnimating) return;
    if (_showingBack) {
      _flip.reverse();
    } else {
      _flip.forward();
    }
  }

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
        return (
          palette.surfaceAlt,
          palette.surface,
          palette.textPrimary,
          false,
        );
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

  String get _pan => pannedNumber(account.accountNumber);

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
      button: true,
      label:
          '${account.name}, ${account.institution}, '
          '${isCredit ? 'outstanding' : 'available'} $balance. '
          'Tap to turn the card over.',
      child: InkWell(
        onTap: _turn,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // The turn. A rotation about Y with a little perspective, so the
            // card reads as a physical object turning rather than a picture
            // being squashed and swapped. The back is pre-rotated by pi so it
            // is not mirror-imaged when it comes round.
            AnimatedBuilder(
              animation: _flip,
              builder: (BuildContext context, _) {
                final double t = Curves.easeInOut.transform(_flip.value);
                final double angle = t * math.pi;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: t <= 0.5
                      ? _plastic(
                          from,
                          to,
                          ink,
                          inkSoft,
                          metallic,
                          paleCard,
                          brand,
                          isCredit,
                          balance,
                        )
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _CardBack(
                            account: account,
                            palette: palette,
                            from: from,
                            to: to,
                            ink: ink,
                            inkSoft: inkSoft,
                            onEdit: onTap,
                          ),
                        ),
                );
              },
            ),
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
      aspectRatio: BankCard.aspect,
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

    // Whether the issuer's own logo is going to be drawn on the right. The
    // kicker below depends on it, so it is worked out once here rather than
    // asked twice and allowed to disagree with itself.
    final bool hasMark = brand != null && brand!.hasMark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // THE BANK'S NAME APPEARS ONCE, not twice.
              //
              // Founder direction, 2026-09-19, looking at a card reading "BPI"
              // over "BPI Rewards Card" with the BPI logo beside it: "i think
              // its redundant there are two brand name. We can retain 1 plus
              // the logo in the right side".
              //
              // So the kicker is dropped wherever the LOGO already says which
              // bank it is, and kept only where there is no mark to say it. A
              // Pag-IBIG card draws a monogram rather than a logo, and with
              // the kicker gone as well an account somebody named "Main card"
              // would name no institution anywhere on the plastic.
              if (!hasMark)
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
        if (hasMark)
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

/// The back of the card: the magnetic stripe, the signature panel, and every
/// detail that has no room on the front.
///
/// Founder direction, 2026-09-19: "For the card we can apply animation, like
/// by tapping the card it will turn back and the other details are there."
///
/// ONE THING IS DELIBERATELY ABSENT, and its absence is stated on the card
/// rather than left as a blank box: the CVV. Salapify does not store one, will
/// not ask for one, and drawing three dots where a real card has three digits
/// would invite somebody to write theirs into the account notes. A finance app
/// that looks like it wants your CVV has taught the wrong lesson even if it
/// never reads the field.
class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.account,
    required this.palette,
    required this.from,
    required this.to,
    required this.ink,
    required this.inkSoft,
    required this.onEdit,
  });

  final Account account;
  final Palette palette;
  final Color from;
  final Color to;
  final Color ink;
  final Color inkSoft;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    // The detail rows, built from what the account ACTUALLY holds. An empty
    // field is left out rather than shown blank: a card back listing "Due
    // date: —" four times reads as an app that lost something.
    final List<(String, String)> details = <(String, String)>[
      // The masked tail, never the stored string. See maskedTail: the back
      // printed the whole number here once, under a NO CVV badge.
      if (maskedTail(account.accountNumber) != null)
        ('Number', '•••• ${maskedTail(account.accountNumber)}'),
      if (account.dueDate != null) ('Payment due', account.dueDate!),
      if (account.statementDate != null) ('Statement', account.statementDate!),
      if (account.interestRate != null)
        ('Interest', '${account.interestRate}% a year'),
      if (account.creditLimit != null)
        (
          'Credit limit',
          formatCurrency(account.creditLimit!, account.currency),
        ),
      if (account.isForeign)
        ('Currency', currencyNames[account.currency] ?? account.currency.wire),
      if (account.profile != null) ('Entity', _entity(account.profile!)),
    ];

    return AspectRatio(
      aspectRatio: BankCard.aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // Reversed against the front, the way the two faces of a real card
            // catch light differently.
            begin: Alignment.bottomRight,
            end: Alignment.topLeft,
            colors: <Color>[from, to],
          ),
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: ink.withValues(alpha: 0.18)),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints c) {
            final double h = c.maxHeight;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(height: h * 0.07),
                // The magnetic stripe, full bleed, as on the real thing.
                Container(height: h * 0.16, color: Colors.black87),
                SizedBox(height: h * 0.06),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // The signature panel.
                      Expanded(
                        child: Container(
                          height: h * 0.13,
                          padding: EdgeInsets.symmetric(horizontal: h * 0.03),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(h * 0.02),
                          ),
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppType.family,
                              fontSize: h * 0.07,
                              fontStyle: FontStyle.italic,
                              color: const Color(0xFF15120F),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: h * 0.04),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: h * 0.03,
                          vertical: h * 0.02,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: inkSoft, width: 1),
                          borderRadius: BorderRadius.circular(h * 0.02),
                        ),
                        child: Text(
                          'NO CVV',
                          style: TextStyle(
                            fontFamily: AppType.family,
                            fontSize: h * 0.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: h * 0.004,
                            color: inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: h * 0.04),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: details.isEmpty
                        ? Text(
                            'Nothing else recorded for this card yet.',
                            style: TextStyle(
                              fontFamily: AppType.family,
                              fontSize: h * 0.06,
                              color: inkSoft,
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                for (final (String k, String v) in details)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: h * 0.015),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: Text(
                                            k,
                                            style: TextStyle(
                                              fontFamily: AppType.family,
                                              fontSize: h * 0.055,
                                              color: inkSoft,
                                            ),
                                          ),
                                        ),
                                        Flexible(
                                          child: Text(
                                            v,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              fontFamily: AppType.family,
                                              fontSize: h * 0.055,
                                              fontWeight: FontWeight.w700,
                                              color: ink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.lg,
                    0,
                    Spacing.lg,
                    Spacing.md,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Tap to turn back',
                          style: TextStyle(
                            fontFamily: AppType.family,
                            fontSize: h * 0.05,
                            color: inkSoft,
                          ),
                        ),
                      ),
                      if (onEdit != null)
                        Semantics(
                          button: true,
                          label: 'Edit this account',
                          child: InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(Radii.pill),
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: 32,
                                minWidth: 64,
                              ),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                horizontal: Spacing.md,
                              ),
                              decoration: BoxDecoration(
                                color: ink.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(Radii.pill),
                                border: Border.all(
                                  color: ink.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                'Edit',
                                style: TextStyle(
                                  fontFamily: AppType.family,
                                  fontSize: h * 0.055,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _entity(ProfileEntity e) => switch (e) {
    ProfileEntity.personal => 'Personal',
    ProfileEntity.household => 'Household',
    ProfileEntity.business => 'Business',
    ProfileEntity.sideHustle => 'Side hustle',
  };
}
