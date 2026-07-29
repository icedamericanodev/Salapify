// Which bank, wallet or lender, as a catalog in CODE and an id in user data.
//
// Delivery A of docs/features/unified-financial-accounts.md.
//
// The single design rule: user data stores an ID and nothing else. Never a
// display name, because a rename would reclassify somebody's account; never an
// asset path, because a renamed or removed image would then corrupt stored
// data and break a screen.
//
// No logos ship here, on purpose. Image assets cannot travel in a Shorebird
// patch, so every batch of them costs the founder a base APK and a manual
// install, and using a bank's mark needs permission this project does not
// have. `InstitutionAvatar` will draw initials, which look deliberate, work
// offline, cost nothing, and never need clearing. `localAssetPath` exists so
// that decision can be revisited without a data change.
//
// USD IS NOT AN INSTITUTION. Currency is chosen after the institution and
// lives in its own field. Worth saying out loud because the screen this
// replaces groups by institution, which makes it an easy mistake.

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

  /// Null until a logo file is cleared for use. Nothing reads it yet.
  final String? localAssetPath;

  const FinancialInstitution({
    required this.id,
    required this.displayName,
    required this.type,
    this.aliases = const [],
    this.localAssetPath,
  });

  /// One or two letters for the avatar. Built from the DISPLAY NAME, so a
  /// custom institution somebody typed gets the same treatment as a listed one.
  String get initials => initialsFor(displayName);
}

/// Up to two letters, from the first two words that start with a letter.
///
/// "BPI" gives "BP", not "B", because a single letter on a circle reads as a
/// placeholder rather than a bank.
String initialsFor(String name) {
  final words = name
      .split(RegExp(r'[\s\-_.]+'))
      .where((w) => w.isNotEmpty && RegExp(r'^[A-Za-z]').hasMatch(w))
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
  }
  return (words[0][0] + words[1][0]).toUpperCase();
}

const List<FinancialInstitution> institutions = [
  // Universal and commercial banks.
  FinancialInstitution(
    id: 'bdo',
    displayName: 'BDO',
    type: InstitutionType.bank,
    aliases: ['Banco de Oro', 'BDO Unibank'],
  ),
  FinancialInstitution(
    id: 'bpi',
    displayName: 'BPI',
    type: InstitutionType.bank,
    aliases: ['Bank of the Philippine Islands', 'BPI Family'],
  ),
  FinancialInstitution(
    id: 'metrobank',
    displayName: 'Metrobank',
    type: InstitutionType.bank,
    aliases: ['Metropolitan Bank and Trust Company', 'MBTC'],
  ),
  FinancialInstitution(
    id: 'unionbank',
    displayName: 'UnionBank',
    type: InstitutionType.bank,
    aliases: ['Union Bank of the Philippines', 'UBP'],
  ),
  FinancialInstitution(
    id: 'securitybank',
    displayName: 'Security Bank',
    type: InstitutionType.bank,
    aliases: ['SBC'],
  ),
  FinancialInstitution(
    id: 'rcbc',
    displayName: 'RCBC',
    type: InstitutionType.bank,
    aliases: ['Rizal Commercial Banking Corporation'],
  ),
  FinancialInstitution(
    id: 'pnb',
    displayName: 'PNB',
    type: InstitutionType.bank,
    aliases: ['Philippine National Bank'],
  ),
  FinancialInstitution(
    id: 'landbank',
    displayName: 'LandBank',
    type: InstitutionType.bank,
    aliases: ['Land Bank of the Philippines', 'LBP'],
  ),
  FinancialInstitution(
    id: 'chinabank',
    displayName: 'China Bank',
    type: InstitutionType.bank,
    aliases: ['China Banking Corporation', 'Chinabank Savings'],
  ),
  FinancialInstitution(
    id: 'eastwest',
    displayName: 'EastWest',
    type: InstitutionType.bank,
    aliases: ['EastWest Bank', 'EW'],
  ),
  FinancialInstitution(
    id: 'psbank',
    displayName: 'PSBank',
    type: InstitutionType.bank,
    aliases: ['Philippine Savings Bank'],
  ),
  FinancialInstitution(
    id: 'aub',
    displayName: 'AUB',
    type: InstitutionType.bank,
    aliases: ['Asia United Bank'],
  ),
  FinancialInstitution(
    id: 'bankofcommerce',
    displayName: 'Bank of Commerce',
    type: InstitutionType.bank,
    aliases: ['BankCom'],
  ),

  // Digital banks.
  FinancialInstitution(
    id: 'mayabank',
    displayName: 'Maya Bank',
    type: InstitutionType.digitalBank,
    aliases: ['Maya Savings'],
  ),
  FinancialInstitution(
    id: 'gotyme',
    displayName: 'GoTyme',
    type: InstitutionType.digitalBank,
    aliases: ['GoTyme Bank'],
  ),
  FinancialInstitution(
    id: 'cimb',
    displayName: 'CIMB',
    type: InstitutionType.digitalBank,
    aliases: ['CIMB Bank Philippines', 'GSave'],
  ),
  FinancialInstitution(
    id: 'seabank',
    displayName: 'SeaBank',
    type: InstitutionType.digitalBank,
  ),
  FinancialInstitution(
    id: 'tonik',
    displayName: 'Tonik',
    type: InstitutionType.digitalBank,
    aliases: ['Tonik Bank'],
  ),
  FinancialInstitution(
    id: 'uno',
    displayName: 'UNO Digital Bank',
    type: InstitutionType.digitalBank,
    aliases: ['UNOBank'],
  ),
  FinancialInstitution(
    id: 'ownbank',
    displayName: 'OwnBank',
    type: InstitutionType.digitalBank,
  ),

  // E-wallets.
  FinancialInstitution(
    id: 'gcash',
    displayName: 'GCash',
    type: InstitutionType.eWallet,
    aliases: ['G-Cash', 'Globe GCash'],
  ),
  FinancialInstitution(
    id: 'maya',
    displayName: 'Maya',
    type: InstitutionType.eWallet,
    aliases: ['PayMaya', 'Maya Wallet'],
  ),
  FinancialInstitution(
    id: 'grabpay',
    displayName: 'GrabPay',
    type: InstitutionType.eWallet,
    aliases: ['Grab Pay', 'Grab'],
  ),
  FinancialInstitution(
    id: 'shopeepay',
    displayName: 'ShopeePay',
    type: InstitutionType.eWallet,
    aliases: ['Shopee Pay', 'SPay'],
  ),

  // Lenders that are not banks. Salapify never offers or brokers a loan; these
  // exist so somebody can RECORD a debt they already have, which is the whole
  // point of the debts engine.
  FinancialInstitution(
    id: 'homecredit',
    displayName: 'Home Credit',
    type: InstitutionType.lender,
  ),
  FinancialInstitution(
    id: 'billease',
    displayName: 'BillEase',
    type: InstitutionType.lender,
  ),
  FinancialInstitution(
    id: 'sss',
    displayName: 'SSS',
    type: InstitutionType.lender,
    aliases: ['Social Security System'],
  ),
  FinancialInstitution(
    id: 'gsis',
    displayName: 'GSIS',
    type: InstitutionType.lender,
    aliases: ['Government Service Insurance System'],
  ),
  FinancialInstitution(
    id: 'pagibig',
    displayName: 'Pag-IBIG',
    type: InstitutionType.lender,
    aliases: ['HDMF', 'Pag IBIG', 'Pagibig', 'MP2'],
  ),

  // Brokers and funds.
  FinancialInstitution(
    id: 'copstrade',
    displayName: 'COL Financial',
    type: InstitutionType.broker,
    aliases: ['COL', 'Citiseconline'],
  ),
  FinancialInstitution(
    id: 'firstmetrosec',
    displayName: 'First Metro Sec',
    type: InstitutionType.broker,
    aliases: ['FirstMetroSec', 'FMSBC'],
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
      final flat = [
        inst.displayName,
        ...inst.aliases,
      ].map((n) => n.toLowerCase().replaceAll(RegExp(r'[\s\-_.]'), '')).toList();
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
