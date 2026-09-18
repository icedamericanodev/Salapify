import 'package:flutter/material.dart';

import '../../core/money/accounts.dart';
import '../../core/money/currencies.dart';
import '../../core/money/format.dart';
import '../../design/tokens.dart';
import '../../models/models.dart';

/// A debit or credit account drawn as a piece of plastic, from
/// src/components/BankCard.tsx.
///
/// Only `debit` and `credit` accounts get one. Everything else is a row,
/// because a card is a big object and a screen made entirely of them is a
/// screen you have to scroll to count your wallets.
///
/// ONE DELIBERATE DIVERGENCE: the prototype loads each bank's logo from a
/// remote URL (src/utils/logos.ts) and falls back to the monogram when the
/// image fails. Salapify is offline first, so there is no request to make and
/// no cache to miss. The monogram IS the mark here, which means it has to be
/// right; `accounts_test.dart` is what stops an account wearing another
/// bank's badge.
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

  /// The brand skins, ported from the prototype's `bankThemes`. These are the
  /// banks' own colours rather than Salapify's, on purpose: a card is
  /// recognised by its colour before it is read, and a wallet of sixteen
  /// identical rust rectangles is slower to use than one where BPI is red and
  /// GCash is blue.
  static const Map<String, (Color, Color, Color)>
  _bankSkins = <String, (Color, Color, Color)>{
    // (gradient start, gradient end, ink)
    'BPI': (Color(0xFFB91C1C), Color(0xFF7F1D1D), Colors.white),
    'BDO': (Color(0xFF1D4ED8), Color(0xFF1E3A8A), Colors.white),
    'UnionBank': (Color(0xFFF97316), Color(0xFFC2410C), Colors.white),
    'GCash': (Color(0xFF3B82F6), Color(0xFF1D4ED8), Colors.white),
    'Maya': (Color(0xFF059669), Color(0xFF064E3B), Colors.white),
    'Metrobank': (Color(0xFF1E40AF), Color(0xFF172554), Colors.white),
    'MariBank': (Color(0xFFF97316), Color(0xFFEF4444), Colors.white),
    'GoTyme': (Color(0xFF0891B2), Color(0xFF1D4ED8), Colors.white),
    'RCBC': (Color(0xFF1D4ED8), Color(0xFF1E3A8A), Colors.white),
    'Security Bank': (Color(0xFF2563EB), Color(0xFF1E40AF), Colors.white),
    'EastWest': (Color(0xFF7E22CE), Color(0xFF581C87), Colors.white),
    'PNB': (Color(0xFF991B1B), Color(0xFF450A0A), Colors.white),
    'Atome': (Color(0xFFFACC15), Color(0xFFEAB308), Color(0xFF0F172A)),
    'AUB': (Color(0xFF60A5FA), Color(0xFF2563EB), Colors.white),
    'TikTok': (Color(0xFF000000), Color(0xFF18181B), Colors.white),
    'LandBank': (Color(0xFF16A34A), Color(0xFF166534), Colors.white),
    'PSBank': (Color(0xFF2563EB), Color(0xFF1E40AF), Colors.white),
    'China Bank': (Color(0xFFDC2626), Color(0xFF991B1B), Colors.white),
    'UNO Digital Bank': (Color(0xFFC026D3), Color(0xFFDB2777), Colors.white),
    'OwnBank': (Color(0xFF3730A3), Color(0xFF581C87), Colors.white),
  };

  /// The tier skins, which OVERRIDE the bank's own colours. Somebody who
  /// records a card as Platinum is telling us what the card looks like in
  /// their hand, and that is more use for recognising it than the bank's
  /// marketing palette.
  (Color, Color, Color) _skin() {
    switch (account.cardTier) {
      case CardTier.gold:
        return (
          const Color(0xFFB45309),
          const Color(0xFF78350F),
          const Color(0xFFFEF3C7),
        );
      case CardTier.platinum:
        return (
          const Color(0xFF52525B),
          const Color(0xFF27272A),
          const Color(0xFFF4F4F5),
        );
      case CardTier.black:
        return (
          const Color(0xFF262626),
          const Color(0xFF000000),
          const Color(0xFFE5E5E5),
        );
      case CardTier.custom:
        return (palette.surfaceAlt, palette.surface, palette.textPrimary);
      case CardTier.regular:
        return _bankSkins[account.institution] ??
            (palette.surfaceAlt, palette.surface, palette.textPrimary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCredit = account.kind == AccountKind.credit;
    final (Color from, Color to, Color ink) = _skin();
    final Color inkSoft = ink.withValues(alpha: 0.72);

    final String balance = account.isForeign
        ? formatCurrency(account.balance.abs(), account.currency)
        : formatPeso(account.balance.abs());

    // The last four digits, or four dots. Never the whole number: this screen
    // is opened in public and a full card number on a phone is a card number
    // on a phone.
    final String? number = account.accountNumber;
    final String tail = (number != null && number.length >= 4)
        ? number.substring(number.length - 4)
        : '••••';

    return Semantics(
      button: onTap != null,
      label:
          '${account.name}, ${account.institution}, '
          '${isCredit ? 'outstanding' : 'available'} $balance',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[from, to],
            ),
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          account.institution.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: inkSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          account.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(Radii.tile),
                    ),
                    child: Text(
                      account.monogram,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 22,
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    '••••  $tail',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isCredit
                              ? 'OUTSTANDING BALANCE'
                              : 'AVAILABLE BALANCE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: inkSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // A credit card's balance is money OWED, so it is
                          // drawn with a minus. The prototype does the same,
                          // and without it a 12,000 debt renders character for
                          // character like 12,000 in savings.
                          isCredit && account.balance > 0
                              ? '-$balance'
                              : balance,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        if (account.isForeign)
                          Text(
                            '≈ ${formatPeso(account.balanceInPhp.abs())}',
                            style: TextStyle(fontSize: 10, color: inkSoft),
                          ),
                      ],
                    ),
                  ),
                  if (isCredit && account.creditLimit != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'CREDIT LIMIT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: inkSoft,
                          ),
                        ),
                        Text(
                          formatCurrency(
                            account.creditLimit!,
                            account.currency,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  if (account.cardNetwork != CardNetwork.none) ...<Widget>[
                    const SizedBox(width: Spacing.sm),
                    _NetworkMark(network: account.cardNetwork, ink: ink),
                  ],
                ],
              ),
              if (isCredit) _Utilisation(account: account, ink: ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scheme wordmark. Drawn as text rather than a logo because Salapify
/// ships no third party brand assets and an offline app cannot fetch one.
class _NetworkMark extends StatelessWidget {
  const _NetworkMark({required this.network, required this.ink});

  final CardNetwork network;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final String label = switch (network) {
      CardNetwork.visa => 'VISA',
      CardNetwork.mastercard => 'MC',
      CardNetwork.amex => 'AMEX',
      CardNetwork.jcb => 'JCB',
      CardNetwork.none => '',
    };
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.4,
        color: ink.withValues(alpha: 0.8),
      ),
    );
  }
}

/// How much of the limit is used, with the rail underneath.
///
/// When the card has NO recorded limit this says so in words rather than
/// drawing a bar against an invented number. A percentage that was made up is
/// still read as advice.
class _Utilisation extends StatelessWidget {
  const _Utilisation({required this.account, required this.ink});

  final Account account;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final int? used = creditUtilization(account);
    final Color inkSoft = ink.withValues(alpha: 0.72);

    if (used == null) {
      return Padding(
        padding: const EdgeInsets.only(top: Spacing.md),
        child: Text(
          'Add this card’s limit to see how much of it you are using.',
          style: TextStyle(fontSize: 10, color: inkSoft),
        ),
      );
    }

    final bool high = isHighUtilization(account);
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Credit used',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: inkSoft,
                  ),
                ),
              ),
              Text(
                // The number AND the word, never colour alone. Roughly one man
                // in twelve cannot separate this red from this green.
                high ? '$used%, over 30%' : '$used%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ink,
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
              backgroundColor: ink.withValues(alpha: 0.18),
              valueColor: AlwaysStoppedAnimation<Color>(
                high ? const Color(0xFFF87171) : ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
