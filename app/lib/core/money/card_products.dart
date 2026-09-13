// Card networks and generic issuer products, as a catalog in CODE.
//
// The companion to money/institutions.dart. Institutions answer "which bank",
// this file answers "which card scheme, and roughly which product tier". User
// data stores only two stable ids from here: `cardNetwork` (one of five) and,
// optionally, `cardProductId` (a generic tier). Never a display label, never a
// logo, same trademark boundary the institutions catalog keeps: a network is
// recognised by its WORDMARK (the plain text "VISA"), never by its brand mark,
// which needs a permission this project does not have and cannot travel in a
// Shorebird patch.
//
// The facts here were researched against 2026 sources (see the pull request).
// Where an issuer's networks or tiers could not be independently confirmed, it
// is listed with NO forced network and a generic product only, rather than a
// guess dressed up as a catalog fact. An unlisted issuer (a digital bank, a
// wallet, "something else") offers every network and no tier, so the flow never
// dead-ends: a person can always finish, whoever their card is with.
//
// The allowed network id SET is defined once, in money/account_taxonomy.dart
// (`kCardNetworks`), because that is the persistence contract. This file only
// adds the display for those ids, so the two can never disagree about what is
// storable.

import 'account_taxonomy.dart' show kCardNetworks;

/// One card scheme, for display. The id is stored; the wordmark is drawn on the
/// card face as plain text, never a logo.
class CardNetwork {
  /// Stored in user data. One of [kCardNetworks].
  final String id;
  final String displayName;

  /// The short mark drawn on the card, e.g. "VISA". Text only.
  final String wordmark;

  const CardNetwork({
    required this.id,
    required this.displayName,
    required this.wordmark,
  });
}

/// The five networks Salapify recognises, in rough order of how common they are
/// on a Philippine consumer credit card. The ids match [kCardNetworks] exactly.
const List<CardNetwork> cardNetworks = [
  CardNetwork(id: 'visa', displayName: 'Visa', wordmark: 'VISA'),
  CardNetwork(
    id: 'mastercard',
    displayName: 'Mastercard',
    wordmark: 'Mastercard',
  ),
  CardNetwork(id: 'jcb', displayName: 'JCB', wordmark: 'JCB'),
  CardNetwork(id: 'amex', displayName: 'American Express', wordmark: 'AMEX'),
  CardNetwork(id: 'unionpay', displayName: 'UnionPay', wordmark: 'UnionPay'),
];

CardNetwork? cardNetworkById(String? id) {
  if (id == null) return null;
  final k = id.toLowerCase();
  for (final n in cardNetworks) {
    if (n.id == k) return n;
  }
  return null;
}

/// The wordmark for a stored network id, or null when there is none to show
/// (unset, or an id that is not one of the five). The card face falls back to
/// nothing rather than an "unknown" label, so a card with no network chosen
/// simply carries no mark.
String? cardNetworkWordmark(String? id) => cardNetworkById(id)?.wordmark;

/// One generic product tier a person would recognise, with a stable id.
class CardProduct {
  /// Stored in user data as `cardProductId`. Matches `^[a-z0-9_]{1,64}$`, the
  /// shape account_taxonomy validates.
  final String id;
  final String label;

  const CardProduct({required this.id, required this.label});
}

/// What one issuer commonly offers: the networks it issues on, and a few
/// generic, recognisable tiers. Keyed by the institution id from
/// money/institutions.dart.
class CardIssuerProfile {
  final String institutionId;

  /// Networks this issuer commonly issues consumer credit cards on. Empty means
  /// "not confirmed", and the flow then offers every network rather than none.
  final List<String> networks;

  /// Generic tiers. Empty means the issuer is offered with a single generic
  /// card and no tier choice.
  final List<CardProduct> products;

  const CardIssuerProfile({
    required this.institutionId,
    this.networks = const [],
    this.products = const [],
  });
}

/// Issuer profiles. Only issuers whose card business was confirmed appear here.
/// Tiers are deliberately generic (Classic, Gold, Platinum and the like) plus a
/// small number of well-known flagships; they are a convenience, not a claim
/// that these are every product an issuer sells.
const List<CardIssuerProfile> cardIssuers = [
  CardIssuerProfile(
    institutionId: 'bdo',
    networks: ['visa', 'mastercard', 'jcb', 'unionpay', 'amex'],
    products: [
      CardProduct(id: 'classic', label: 'Classic or Standard'),
      CardProduct(id: 'gold', label: 'Gold'),
      CardProduct(id: 'platinum', label: 'Platinum'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'bpi',
    networks: ['visa', 'mastercard'],
    products: [
      CardProduct(id: 'gold', label: 'Gold Rewards'),
      CardProduct(id: 'platinum', label: 'Platinum Rewards'),
      CardProduct(id: 'signature', label: 'Signature'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'metrobank',
    networks: ['visa', 'mastercard'],
    products: [
      CardProduct(id: 'titanium', label: 'Titanium'),
      CardProduct(id: 'platinum', label: 'Platinum'),
      CardProduct(id: 'world', label: 'World Mastercard'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'unionbank',
    networks: ['visa', 'mastercard'],
    products: [
      CardProduct(id: 'entry', label: 'U or entry card'),
      CardProduct(id: 'gold', label: 'Gold'),
      CardProduct(id: 'platinum', label: 'Platinum'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'securitybank',
    networks: ['mastercard'],
    products: [
      CardProduct(id: 'gold', label: 'Classic or Gold'),
      CardProduct(id: 'platinum', label: 'Platinum'),
      CardProduct(id: 'world', label: 'World Mastercard'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'rcbc',
    networks: ['visa', 'mastercard', 'jcb', 'unionpay'],
    products: [
      CardProduct(id: 'classic', label: 'Classic or Gold'),
      CardProduct(id: 'platinum', label: 'Platinum'),
      CardProduct(id: 'world', label: 'World Mastercard'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'pnb',
    networks: ['mastercard', 'visa'],
    products: [
      CardProduct(id: 'zelo', label: 'Ze-Lo, no annual fee'),
      CardProduct(id: 'platinum', label: 'Gold or Platinum'),
      CardProduct(id: 'mabuhay', label: 'PAL Mabuhay Miles'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'chinabank',
    networks: ['mastercard'],
    products: [
      CardProduct(id: 'freedom', label: 'Freedom, waived fee'),
      CardProduct(id: 'cash_rewards', label: 'Cash Rewards'),
      CardProduct(id: 'platinum', label: 'Platinum'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'eastwest',
    networks: ['visa', 'mastercard', 'jcb'],
    products: [
      CardProduct(id: 'gold', label: 'Gold'),
      CardProduct(id: 'platinum', label: 'Platinum'),
      CardProduct(id: 'dolce_vita', label: 'Dolce Vita Titanium'),
    ],
  ),
  CardIssuerProfile(
    institutionId: 'aub',
    networks: ['mastercard'],
    products: [
      CardProduct(id: 'easy', label: 'AUB Easy Mastercard'),
      CardProduct(id: 'platinum', label: 'Platinum'),
    ],
  ),
  // Confirmed as issuers, but the specific networks or tiers were not
  // independently verified this cycle, so they carry a generic offering only.
  CardIssuerProfile(
    institutionId: 'landbank',
    networks: ['mastercard', 'visa'],
  ),
  CardIssuerProfile(institutionId: 'psbank', networks: ['mastercard']),
  CardIssuerProfile(
    institutionId: 'bankofcommerce',
    networks: ['visa', 'mastercard'],
  ),
  // Maya Bank issues a co-brand card; its network was not confirmed, so every
  // network stays selectable rather than a guessed one being forced.
  CardIssuerProfile(institutionId: 'mayabank'),
];

CardIssuerProfile? cardIssuerProfile(String? institutionId) {
  if (institutionId == null) return null;
  for (final p in cardIssuers) {
    if (p.institutionId == institutionId) return p;
  }
  return null;
}

/// The networks to OFFER for an issuer: its known networks, or all five when
/// the issuer is unlisted or unconfirmed. Never an empty list, so the picker
/// always has something to show and a card can always be finished.
List<CardNetwork> networksForIssuer(String? institutionId) {
  final p = cardIssuerProfile(institutionId);
  if (p == null || p.networks.isEmpty) return cardNetworks;
  return [
    for (final id in p.networks)
      if (cardNetworkById(id) != null) cardNetworkById(id)!,
  ];
}

/// The generic tiers to offer for an issuer, or an empty list when there are
/// none to choose and the card is simply "generic".
List<CardProduct> tiersForIssuer(String? institutionId) =>
    cardIssuerProfile(institutionId)?.products ?? const [];

/// The label for a stored product id under a given issuer, or null when it does
/// not resolve (an issuer with no tiers, or a stale id). Callers show nothing
/// rather than a raw id.
String? cardProductLabel(String? institutionId, String? productId) {
  if (productId == null || productId.isEmpty) return null;
  for (final p in tiersForIssuer(institutionId)) {
    if (p.id == productId) return p.label;
  }
  return null;
}

/// Whether an institution is known to issue consumer credit cards. A soft hint
/// for the flow, never a gate: the credit-card path lets a person pick any
/// institution, because a catalog is never complete and "not on our list" is a
/// real card too.
bool issuerOffersCreditCards(String? institutionId) =>
    cardIssuerProfile(institutionId) != null;

/// Institutions commonly able to RECEIVE money by QR (QR Ph P2P) in the
/// Philippines, by institution id. A soft UX hint only: it decides whether the
/// detail screen SUGGESTS adding a receiving QR, never whether one can be added.
/// SeaBank is deliberately absent: it was not found on the current QR Ph P2P
/// roster this cycle, and a hint is better silent than wrong.
const Set<String> _qrReceivingInstitutions = {
  'bdo',
  'bpi',
  'metrobank',
  'unionbank',
  'securitybank',
  'rcbc',
  'pnb',
  'landbank',
  'chinabank',
  'eastwest',
  'psbank',
  'aub',
  'bankofcommerce',
  'gcash',
  'maya',
  'mayabank',
  'shopeepay',
  'grabpay',
  'cimb',
  'tonik',
  'ownbank',
  'gotyme',
  'uno',
};

bool institutionSupportsQrReceiving(String? institutionId) =>
    institutionId != null && _qrReceivingInstitutions.contains(institutionId);
