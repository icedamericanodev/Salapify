// Which bank, wallet or lender, as a catalog in CODE and an id in user data.
//
// Delivery A of docs/features/unified-financial-accounts.md.
//
// The single design rule: user data stores an ID and nothing else. Never a
// display name, because a rename would reclassify somebody's account; never an
// asset path, because a renamed or removed image would then corrupt stored
// data and break a screen.
//
// Logos DO ship now (founder decision, 2026-08-18), as bundled assets under
// assets/institutions/, cleared first by a trademark read (nominative use with
// guardrails). They are image files, so they cannot travel in a Shorebird
// patch: a change to them costs a base APK and a manual install. A logo is
// shown ONLY to identify the user's own account; Salapify is not affiliated
// with any institution, a non-affiliation notice the accounts screen carries.
// `localAssetPath` is the card wordmark, `symbolAssetPath` the round-avatar
// mark; both are null for anything without a cleared logo, where
// `InstitutionAvatar` still draws initials, which look deliberate, work
// offline, cost nothing, and never need clearing.
//
// USD IS NOT AN INSTITUTION. Currency is chosen after the institution and
// lives in its own field. Worth saying out loud because the screen this
// replaces groups by institution, which makes it an easy mistake.
//
// BRAND COLORS live here too, on the catalog, as the ONE source of truth for
// anything that paints a bank (the avatar tint, the BankCard gradient). They
// are ported from mobile/lib/banks.js so the Flutter and React Native apps
// wear the same colors; Dart cannot import the JS list, so the values are
// copied here by id and this catalog, not a second list, is what every Flutter
// screen reads. A brand color is only the FILL. It is never a logo: text and
// color only, which is a trademark boundary this project keeps on purpose.

import 'dart:ui' show Color;

enum InstitutionType { bank, digitalBank, eWallet, lender, broker, other }

class FinancialInstitution {
  /// Stored in user data. Never changes, whatever the company renames itself.
  final String id;
  final String displayName;
  final InstitutionType type;

  /// Other things people actually type. Searched as well as the display name,
  /// because somebody looking for their account types "BPI Family" or "Bank of
  /// the Philippine Islands", not the string we happened to choose.
  final List<String> aliases;

  /// The bundled WORDMARK logo asset, drawn on a white chip on the account
  /// card. Null keeps the text-and-color treatment. Shown only to identify the
  /// user's own account; Salapify is not affiliated with any institution.
  final String? localAssetPath;

  /// The bundled standalone SYMBOL/mark asset (no wordmark), drawn in the round
  /// account avatar where a wide wordmark would not fit. Null falls back to
  /// [localAssetPath], then to initials.
  final String? symbolAssetPath;

  /// The brand FILL color, ported from mobile/lib/banks.js by id. Null for the
  /// escape hatches (something else, no institution) and anything without a
  /// known brand color; callers fall back to a neutral tint. Never a logo, just
  /// the color, which is the trademark line this project holds.
  final Color? brandColor;

  const FinancialInstitution({
    required this.id,
    required this.displayName,
    required this.type,
    this.aliases = const [],
    this.localAssetPath,
    this.symbolAssetPath,
    this.brandColor,
  });

  /// One or two letters for the avatar. Built from the DISPLAY NAME, so a
  /// custom institution somebody typed gets the same treatment as a listed one.
  String get initials => initialsFor(displayName);
}

/// Up to two letters, from the first two words that start with a letter.
///
/// "BPI" gives "BP", not "B", because a single letter on a circle reads as a
/// placeholder rather than a bank.
///
/// A run-together name is split at its internal capitals, so "UnionBank" gives
/// UB rather than UN. That is not fussiness: UN on a circle reads as the
/// United Nations, which the render made obvious and the code did not. It also
/// fixes GoTyme (GT), SeaBank (SB), GrabPay (GP), ShopeePay (SP) and EastWest
/// (EW) in one rule instead of five special cases.
///
/// An all-capitals name has no such boundary, so BPI, RCBC and PSBank keep
/// their first two letters, which is what anybody would write by hand.
String initialsFor(String name) {
  final words = name
      .split(RegExp(r'[\s\-_.]+'))
      .where((w) => w.isNotEmpty && RegExp(r'^[A-Za-z]').hasMatch(w))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    final camel = RegExp(r'^(.*?[a-z])([A-Z])').firstMatch(w);
    if (camel != null) return (w[0] + camel.group(2)!).toUpperCase();
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

const List<FinancialInstitution> institutions = [
  // Universal and commercial banks. Brand colors ported from banks.js by id.
  FinancialInstitution(
    id: 'bdo',
    localAssetPath: 'assets/institutions/bdo.png',
    displayName: 'BDO',
    type: InstitutionType.bank,
    aliases: ['Banco de Oro', 'BDO Unibank'],
    brandColor: Color(0xFF00308F),
  ),
  FinancialInstitution(
    id: 'bpi',
    displayName: 'BPI',
    type: InstitutionType.bank,
    aliases: ['Bank of the Philippine Islands', 'BPI Family'],
    localAssetPath: 'assets/institutions/bpi.png',
    brandColor: Color(0xFFB11116),
  ),
  FinancialInstitution(
    id: 'metrobank',
    localAssetPath: 'assets/institutions/metrobank.png',
    symbolAssetPath: 'assets/institutions/metrobank_symbol.png',
    displayName: 'Metrobank',
    type: InstitutionType.bank,
    aliases: ['Metropolitan Bank and Trust Company', 'MBTC'],
    brandColor: Color(0xFF00529C),
  ),
  FinancialInstitution(
    id: 'unionbank',
    displayName: 'UnionBank',
    type: InstitutionType.bank,
    aliases: ['Union Bank of the Philippines', 'UBP'],
    localAssetPath: 'assets/institutions/unionbank.png',
    symbolAssetPath: 'assets/institutions/unionbank_symbol.png',
    brandColor: Color(0xFFFF7A00),
  ),
  FinancialInstitution(
    id: 'securitybank',
    localAssetPath: 'assets/institutions/securitybank.png',
    symbolAssetPath: 'assets/institutions/securitybank_symbol.png',
    displayName: 'Security Bank',
    type: InstitutionType.bank,
    aliases: ['SBC'],
    brandColor: Color(0xFF00703C),
  ),
  FinancialInstitution(
    id: 'rcbc',
    // No logo: RCBC's mark is a very light cyan hexagon that vanishes on the
    // white chip and disc, so the clean initials read better. A higher-contrast
    // asset could restore it later.
    displayName: 'RCBC',
    type: InstitutionType.bank,
    aliases: ['Rizal Commercial Banking Corporation'],
    brandColor: Color(0xFF003DA5),
  ),
  FinancialInstitution(
    id: 'pnb',
    localAssetPath: 'assets/institutions/pnb.png',
    displayName: 'PNB',
    type: InstitutionType.bank,
    aliases: ['Philippine National Bank'],
    brandColor: Color(0xFF005BAA),
  ),
  FinancialInstitution(
    id: 'landbank',
    localAssetPath: 'assets/institutions/landbank.png',
    displayName: 'LandBank',
    type: InstitutionType.bank,
    aliases: ['Land Bank of the Philippines', 'LBP'],
    brandColor: Color(0xFF00A651),
  ),
  FinancialInstitution(
    id: 'chinabank',
    localAssetPath: 'assets/institutions/chinabank.png',
    displayName: 'China Bank',
    type: InstitutionType.bank,
    aliases: ['China Banking Corporation', 'Chinabank Savings'],
    brandColor: Color(0xFFC8102E),
  ),
  FinancialInstitution(
    id: 'eastwest',
    localAssetPath: 'assets/institutions/eastwest.png',
    displayName: 'EastWest',
    type: InstitutionType.bank,
    aliases: ['EastWest Bank', 'EW'],
    brandColor: Color(0xFF5C2D91),
  ),
  // Not in banks.js. Colors added here for the fuller PH bank list; still text
  // and color only, never a logo.
  FinancialInstitution(
    id: 'psbank',
    localAssetPath: 'assets/institutions/psbank.png',
    displayName: 'PSBank',
    type: InstitutionType.bank,
    aliases: ['Philippine Savings Bank'],
    brandColor: Color(0xFF009639),
  ),
  FinancialInstitution(
    id: 'aub',
    localAssetPath: 'assets/institutions/aub.png',
    displayName: 'AUB',
    type: InstitutionType.bank,
    aliases: ['Asia United Bank'],
    brandColor: Color(0xFF0060A9),
  ),
  FinancialInstitution(
    id: 'bankofcommerce',
    displayName: 'Bank of Commerce',
    type: InstitutionType.bank,
    aliases: ['BankCom'],
    brandColor: Color(0xFF0067B1),
  ),

  // Digital banks.
  FinancialInstitution(
    id: 'mayabank',
    localAssetPath: 'assets/institutions/maya.png',
    displayName: 'Maya Bank',
    type: InstitutionType.digitalBank,
    aliases: ['Maya Savings'],
    brandColor: Color(0xFF0C0C0C),
  ),
  FinancialInstitution(
    id: 'gotyme',
    displayName: 'GoTyme',
    type: InstitutionType.digitalBank,
    aliases: ['GoTyme Bank'],
    localAssetPath: 'assets/institutions/gotyme.png',
    brandColor: Color(0xFF001E28),
  ),
  FinancialInstitution(
    id: 'cimb',
    displayName: 'CIMB',
    type: InstitutionType.digitalBank,
    aliases: ['CIMB Bank Philippines', 'GSave'],
    brandColor: Color(0xFFED1C24),
  ),
  FinancialInstitution(
    id: 'seabank',
    localAssetPath: 'assets/institutions/seabank.png',
    displayName: 'SeaBank',
    type: InstitutionType.digitalBank,
    brandColor: Color(0xFFEE4D2D),
  ),
  FinancialInstitution(
    id: 'tonik',
    localAssetPath: 'assets/institutions/tonik.png',
    displayName: 'Tonik',
    type: InstitutionType.digitalBank,
    aliases: ['Tonik Bank'],
    brandColor: Color(0xFF3D2B96),
  ),
  FinancialInstitution(
    id: 'uno',
    displayName: 'UNO Digital Bank',
    type: InstitutionType.digitalBank,
    aliases: ['UNOBank'],
    brandColor: Color(0xFF15173A),
  ),
  FinancialInstitution(
    id: 'ownbank',
    displayName: 'OwnBank',
    type: InstitutionType.digitalBank,
    brandColor: Color(0xFF0A8F5B),
  ),

  // E-wallets.
  FinancialInstitution(
    id: 'gcash',
    displayName: 'GCash',
    type: InstitutionType.eWallet,
    aliases: ['G-Cash', 'Globe GCash'],
    localAssetPath: 'assets/institutions/gcash.png',
    symbolAssetPath: 'assets/institutions/gcash_symbol.png',
    brandColor: Color(0xFF007DFE),
  ),
  FinancialInstitution(
    id: 'maya',
    displayName: 'Maya',
    type: InstitutionType.eWallet,
    aliases: ['PayMaya', 'Maya Wallet'],
    localAssetPath: 'assets/institutions/maya.png',
    brandColor: Color(0xFF0C0C0C),
  ),
  FinancialInstitution(
    id: 'grabpay',
    localAssetPath: 'assets/institutions/grabpay.png',
    displayName: 'GrabPay',
    type: InstitutionType.eWallet,
    aliases: ['Grab Pay', 'Grab'],
    brandColor: Color(0xFF00B14F),
  ),
  FinancialInstitution(
    id: 'shopeepay',
    localAssetPath: 'assets/institutions/shopeepay.png',
    displayName: 'ShopeePay',
    type: InstitutionType.eWallet,
    aliases: ['Shopee Pay', 'SPay'],
    brandColor: Color(0xFFEE4D2D),
  ),

  // Lenders that are not banks. Salapify never offers or brokers a loan; these
  // exist so somebody can RECORD a debt they already have, which is the whole
  // point of the debts engine.
  FinancialInstitution(
    id: 'homecredit',
    localAssetPath: 'assets/institutions/homecredit.png',
    displayName: 'Home Credit',
    type: InstitutionType.lender,
    brandColor: Color(0xFFE1272E),
  ),
  FinancialInstitution(
    id: 'billease',
    displayName: 'BillEase',
    type: InstitutionType.lender,
    brandColor: Color(0xFF2D5BE3),
  ),
  FinancialInstitution(
    id: 'sss',
    displayName: 'SSS',
    type: InstitutionType.lender,
    aliases: ['Social Security System'],
    brandColor: Color(0xFF0057A8),
  ),
  FinancialInstitution(
    id: 'gsis',
    localAssetPath: 'assets/institutions/gsis.png',
    symbolAssetPath: 'assets/institutions/gsis_symbol.png',
    displayName: 'GSIS',
    type: InstitutionType.lender,
    aliases: ['Government Service Insurance System'],
    brandColor: Color(0xFF11508C),
  ),
  FinancialInstitution(
    id: 'pagibig',
    localAssetPath: 'assets/institutions/pagibig.png',
    symbolAssetPath: 'assets/institutions/pagibig_symbol.png',
    displayName: 'Pag-IBIG',
    type: InstitutionType.lender,
    aliases: ['HDMF', 'Pag IBIG', 'Pagibig', 'MP2'],
    brandColor: Color(0xFF1B4F9C),
  ),

  // Brokers and funds.
  FinancialInstitution(
    id: 'copstrade',
    displayName: 'COL Financial',
    type: InstitutionType.broker,
    aliases: ['COL', 'Citiseconline'],
    brandColor: Color(0xFF00337F),
  ),
  FinancialInstitution(
    id: 'firstmetrosec',
    localAssetPath: 'assets/institutions/firstmetrosec.png',
    displayName: 'First Metro Sec',
    type: InstitutionType.broker,
    aliases: ['FirstMetroSec', 'FMSBC'],
    brandColor: Color(0xFF003087),
  ),

  // The two escape hatches. 'other' is for an institution not listed, paired
  // with a typed institutionName; 'none' is a deliberate answer, for cash on
  // hand or a debt to nobody in particular, and is NOT the same as leaving the
  // question unanswered.
  FinancialInstitution(
    id: 'other',
    displayName: 'Something else',
    type: InstitutionType.other,
  ),
  FinancialInstitution(
    id: 'none',
    displayName: 'No institution',
    type: InstitutionType.other,
  ),
];

FinancialInstitution? institutionById(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final i in institutions) {
    if (i.id == id) return i;
  }
  return null;
}

/// The brand fill color for an institution id, or null when there is no known
/// color (an unlisted institution, the escape hatches, or a row with no
/// institution at all). Callers fall back to a neutral tint, so a missing color
/// is never a broken screen. This is the ONE lookup anything painting a bank
/// should use, so a color only ever lives in the catalog above.
Color? institutionBrandColor(String? id) => institutionById(id)?.brandColor;

/// The bundled WORDMARK logo asset for an institution id, or null when none has
/// been cleared for use. Used on the account card's white brand chip.
String? institutionLogoAsset(String? id) => institutionById(id)?.localAssetPath;

/// The bundled mark for the round account avatar: the standalone symbol if there
/// is one, otherwise the wordmark, otherwise null so the caller draws initials.
String? institutionSymbolAsset(String? id) {
  final i = institutionById(id);
  return i?.symbolAssetPath ?? i?.localAssetPath;
}

/// What to show for a row: the catalog entry's name, the typed custom name, or
/// nothing.
///
/// A stored institutionName is only used with the 'other' id. Anything else
/// means the row names a listed institution AND carries a stray custom string,
/// and the catalog is the one that cannot have been mistyped.
String? institutionLabel(dynamic row) {
  final m = row is Map ? row : const {};
  final id = m['institutionId'];
  if (id == 'other') {
    final n = m['institutionName'];
    if (n is String && n.trim().isNotEmpty) return n.trim();
    return 'Something else';
  }
  return institutionById(id is String ? id : null)?.displayName;
}

/// Institutions matching what somebody has typed so far.
///
/// Matches the display name AND every alias, because people type what they
/// call their bank, not what a list calls it. Ranked so that a name that
/// STARTS with the query comes before one that merely contains it: typing "ba"
/// should offer Bank of Commerce before SeaBank.
///
/// An empty query returns everything except the two escape hatches, which the
/// picker pins to the bottom itself rather than having them float mid-list.
List<FinancialInstitution> searchInstitutions(
  String query, {
  InstitutionType? only,
}) {
  final q = query.trim().toLowerCase();
  final pool = institutions
      .where((i) => only == null || i.type == only)
      .where((i) => q.isNotEmpty || i.type != InstitutionType.other)
      .toList();
  if (q.isEmpty) return pool;

  final scored = <(int, int, FinancialInstitution)>[];
  for (var i = 0; i < pool.length; i++) {
    final inst = pool[i];
    var best = -1;
    for (final name in [inst.displayName, ...inst.aliases]) {
      final n = name.toLowerCase();
      if (n.startsWith(q)) {
        best = 0;
        break;
      }
      if (n.contains(q)) best = best == -1 ? 1 : best;
    }
    // A hyphen or space typed differently should not lose the match:
    // "pagibig" must find "Pag-IBIG".
    if (best == -1) {
      final flat = [inst.displayName, ...inst.aliases]
          .map((n) => n.toLowerCase().replaceAll(RegExp(r'[\s\-_.]'), ''))
          .toList();
      final fq = q.replaceAll(RegExp(r'[\s\-_.]'), '');
      if (fq.isNotEmpty && flat.any((n) => n.contains(fq))) best = 2;
    }
    if (best >= 0) scored.add((best, i, inst));
  }
  // Decorated with the catalog index so equal scores keep catalog order rather
  // than whatever the sort happens to do, which is the same stability rule the
  // money engines use.
  scored.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return [for (final s in scored) s.$3];
}
