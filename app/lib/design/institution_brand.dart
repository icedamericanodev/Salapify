import 'package:flutter/material.dart';

/// Who an account is WITH, drawn as that institution's own mark.
///
/// The prototype resolves these from the internet, through
/// `https://www.google.com/s2/favicons?domain=...` in `src/utils/logos.ts`.
/// That is not ported, for two reasons that both matter more than the pixels:
///
///  1. A logo that only appears with signal is a logo that vanishes on the
///     MRT. (This used to reason from the header saying "Offline Only". That
///     badge now reads "On this phone", because the FX converter does make one
///     request; the argument below stands on its own and never needed it.)
///  2. It tells Google which banks somebody keeps their money at, one request
///     per institution, every time the screen is drawn. That is a person's
///     financial relationships leaking to a third party in exchange for a
///     favicon.
///
/// So the marks are BUNDLED. They ship in the APK, they draw instantly, they
/// work in a basement, and nothing leaves the phone.
///
/// The marks are the institutions' own trademarks, used to identify an account
/// the user told us they hold. Salapify is not affiliated with, endorsed by,
/// or connected to any of them, and [brandDisclaimer] says so on the screen
/// that shows them, exactly as the prototype's own Accounts screen does.
@immutable
class InstitutionBrand {
  const InstitutionBrand({required this.name, required this.color, this.asset});

  /// The institution's display name.
  final String name;

  /// Its primary brand colour, for the fallback tile and the card's accent.
  /// Sampled from the institution's own published brand data.
  final Color color;

  /// The bundled mark, or null where no usable one exists and the monogram
  /// carries it instead.
  final String? asset;

  bool get hasMark => asset != null;
}

/// Shown wherever the marks are, and not negotiable.
///
/// The prototype carries the same sentence at the bottom of its Accounts
/// screen. Using somebody's trademark to label an account is fair; letting a
/// reader infer a relationship that does not exist is not.
const String brandDisclaimer =
    'Brand marks belong to the institutions they name and are shown only to '
    'identify your own accounts. Salapify is not affiliated with, endorsed '
    'by, or connected to any of them.';

const String _dir = 'assets/brand/institutions';

/// Every institution Salapify can draw, keyed by the LOWERCASED name.
///
/// Keyed on the name rather than a domain, because the name is what the
/// account actually stores and what the user typed. Lookup is normalised, so
/// "Union Bank", "UnionBank" and "UNIONBANK" all land on the same mark.
final Map<String, InstitutionBrand> _brands = <String, InstitutionBrand>{
  for (final InstitutionBrand b in <InstitutionBrand>[
    const InstitutionBrand(
      name: 'GCash',
      color: Color(0xFF1972F9),
      asset: '$_dir/gcash.jpg',
    ),
    const InstitutionBrand(
      name: 'Maya',
      color: Color(0xFF112432),
      asset: '$_dir/maya.jpg',
    ),
    const InstitutionBrand(
      name: 'BPI',
      color: Color(0xFFB11116),
      asset: '$_dir/bpi.jpg',
    ),
    const InstitutionBrand(
      name: 'BDO',
      color: Color(0xFF0B4DA2),
      asset: '$_dir/bdo.png',
    ),
    const InstitutionBrand(
      name: 'UnionBank',
      color: Color(0xFFF58220),
      asset: '$_dir/unionbank.jpg',
    ),
    const InstitutionBrand(
      name: 'MariBank',
      color: Color(0xFFE8620C),
      asset: '$_dir/maribank.jpg',
    ),
    const InstitutionBrand(
      name: 'GoTyme',
      color: Color(0xFF00A9E0),
      asset: '$_dir/gotyme.jpg',
    ),
    const InstitutionBrand(
      name: 'Metrobank',
      color: Color(0xFF003B71),
      asset: '$_dir/metrobank.jpg',
    ),
    const InstitutionBrand(
      name: 'Security Bank',
      color: Color(0xFF00573F),
      asset: '$_dir/securitybank.jpg',
    ),
    const InstitutionBrand(
      name: 'Tonik',
      color: Color(0xFF00C2A8),
      asset: '$_dir/tonik.png',
    ),
    const InstitutionBrand(
      name: 'RCBC',
      color: Color(0xFF00529B),
      asset: '$_dir/rcbc.jpg',
    ),

    // No usable mark, so the monogram carries it, in the institution's own
    // colour. Government funds in particular have seals rather than logos,
    // and a blurry seal at 40dp reads worse than two clean letters.
    const InstitutionBrand(name: 'Pag-IBIG', color: Color(0xFF0B5FA5)),
    const InstitutionBrand(name: 'SSS', color: Color(0xFF00693E)),
    const InstitutionBrand(name: 'LandBank', color: Color(0xFF00703C)),
    const InstitutionBrand(name: 'PNB', color: Color(0xFF00529B)),
    const InstitutionBrand(name: 'China Bank', color: Color(0xFFC8102E)),
    const InstitutionBrand(name: 'EastWest', color: Color(0xFF00447C)),
    const InstitutionBrand(name: 'PSBank', color: Color(0xFF004B8D)),
    const InstitutionBrand(name: 'CIMB', color: Color(0xFFD40F2E)),
    const InstitutionBrand(name: 'SeaBank', color: Color(0xFFE8620C)),
    const InstitutionBrand(name: 'Komo', color: Color(0xFF00B5AD)),
    const InstitutionBrand(name: 'Netbank', color: Color(0xFF1B3D6D)),
    const InstitutionBrand(name: 'Atome', color: Color(0xFFEE3B7B)),

    // Not institutions at all, and deliberately present so they resolve to
    // something deliberate rather than to a guess.
    const InstitutionBrand(name: 'Cash', color: Color(0xFF4C9A5E)),
    const InstitutionBrand(name: 'Internal Ledger', color: Color(0xFF7A6E63)),
  ])
    b.name.toLowerCase(): b,
};

/// Strips the punctuation and spacing that make the same bank miss itself.
String _key(String institution) =>
    institution.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

final Map<String, InstitutionBrand> _byLooseKey = <String, InstitutionBrand>{
  for (final InstitutionBrand b in _brands.values) _key(b.name): b,
};

/// The brand for an institution name, or null when Salapify does not know it.
///
/// Null is a real answer and callers must handle it: somebody can type any
/// institution they like into the account sheet, and inventing a mark for one
/// nobody recognises would be worse than a clean monogram.
InstitutionBrand? brandFor(String institution) {
  final String trimmed = institution.trim();
  if (trimmed.isEmpty) return null;
  return _brands[trimmed.toLowerCase()] ?? _byLooseKey[_key(trimmed)];
}

/// Every brand Salapify ships, for the tests that check the assets exist.
Iterable<InstitutionBrand> get allBrands => _brands.values;
