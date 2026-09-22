/// The words a pasted receipt is RECOGNISED by, kept apart from anything
/// Salapify says on its own.
///
/// Same split, and for the same reason, as `pan_matchers.dart`. Salapify may
/// never name a bank or a merchant in its own voice; it absolutely must
/// recognise one in a message the person pasted in, or the feature cannot
/// work at all. Those two rules cannot live in one file, so the trigger words
/// live here where nothing is ever shown unprompted.
///
/// The `name` that comes out of a match IS shown, and that is the same
/// carve-out the assistant already relies on: a name that came from the
/// person's own data is theirs, not Salapify's opinion. Their receipt said
/// Jollibee. Echoing it back is reading, not recommending.
library;

import '../../models/models.dart';

/// The senders these messages come from, and the kind of account each is.
///
/// The KIND is what the Log sheet uses, never the name. It matches against
/// the accounts the person actually created, so somebody with no e-wallet
/// recorded simply gets no account pre-selected rather than a wrong one.
class ReceiptSender {
  const ReceiptSender({required this.match, required this.kind});
  final List<String> match;
  final AccountKind kind;
}

const List<ReceiptSender> receiptSenders = <ReceiptSender>[
  ReceiptSender(match: <String>['gcash'], kind: AccountKind.gcash),
  ReceiptSender(match: <String>['maya', 'paymaya'], kind: AccountKind.maya),
  // Everything else is a bank as far as the form is concerned. A card
  // message and a deposit message both say the name of the bank, and which
  // of their accounts it was is the person's to pick.
  ReceiptSender(
    match: <String>[
      'bpi',
      'bdo',
      'unionbank',
      'union bank',
      'ub:',
      'metrobank',
      'security bank',
      'rcbc',
      'pnb',
      'landbank',
      'chinabank',
      'china bank',
      'eastwest',
      'aub',
      'seabank',
      'gotyme',
      'maribank',
      'tonik',
      'cimb',
      'komo',
    ],
    kind: AccountKind.bank,
  ),
];

/// Every word above, flattened, for the "is this a receipt at all" check.
final List<String> receiptSenderWords = <String>[
  for (final ReceiptSender s in receiptSenders) ...s.match,
];

/// Phrases that mean money came IN rather than went out.
///
/// The prototype has none of these and treats every message as an expense,
/// so "You have received PHP 5,000.00" logs as spending. That is wrong twice
/// over: the balance falls instead of rising, and the month's spending is
/// overstated by the same amount.
const List<String> receiptIncomingWords = <String>[
  'you have received',
  'you received',
  'has been credited',
  'was credited',
  'credited to your',
  'received php',
  'padala',
  'nakatanggap',
  'cash in',
  'cash-in',
  'refund of',
  'has been refunded',
];

class ReceiptMerchant {
  const ReceiptMerchant({
    required this.match,
    required this.name,
    required this.category,
  });
  final List<String> match;
  final String name;
  final String category;
}

/// Merchants common enough in a Philippine receipt to be worth naming.
///
/// Order matters only where one name contains another; there is no such
/// pair here today. A merchant NOT on this list is still read, by the "to X"
/// shape, and comes back with no category so the Log sheet leaves the
/// category alone rather than overwriting a correct one with a guess.
const List<ReceiptMerchant> receiptMerchants = <ReceiptMerchant>[
  ReceiptMerchant(
    match: <String>['jollibee'],
    name: 'Jollibee',
    category: 'Food & Dining',
  ),
  ReceiptMerchant(
    match: <String>['mcdonald', 'mc donald', 'mcdo'],
    name: "McDonald's",
    category: 'Food & Dining',
  ),
  ReceiptMerchant(
    match: <String>['starbucks'],
    name: 'Starbucks',
    category: 'Food & Dining',
  ),
  ReceiptMerchant(
    match: <String>['grabfood'],
    name: 'GrabFood',
    category: 'Food & Dining',
  ),
  ReceiptMerchant(
    match: <String>['grab'],
    name: 'Grab',
    category: 'Transportation',
  ),
  ReceiptMerchant(
    match: <String>['angkas'],
    name: 'Angkas',
    category: 'Transportation',
  ),
  ReceiptMerchant(
    match: <String>['joyride'],
    name: 'JoyRide',
    category: 'Transportation',
  ),
  ReceiptMerchant(
    match: <String>['meralco'],
    name: 'Meralco',
    category: 'Bills & Utilities',
  ),
  ReceiptMerchant(
    match: <String>['maynilad'],
    name: 'Maynilad',
    category: 'Bills & Utilities',
  ),
  ReceiptMerchant(
    match: <String>['manila water'],
    name: 'Manila Water',
    category: 'Bills & Utilities',
  ),
  ReceiptMerchant(
    match: <String>['pldt'],
    name: 'PLDT',
    category: 'Bills & Utilities',
  ),
  ReceiptMerchant(
    match: <String>['converge'],
    name: 'Converge',
    category: 'Bills & Utilities',
  ),
  ReceiptMerchant(
    match: <String>['globe'],
    name: 'Globe',
    category: 'Bills & Utilities',
  ),
  ReceiptMerchant(
    match: <String>['smart communications', 'smart prepaid'],
    name: 'Smart',
    category: 'Bills & Utilities',
  ),
  ReceiptMerchant(
    match: <String>['shopee'],
    name: 'Shopee',
    category: 'Shopping',
  ),
  ReceiptMerchant(
    match: <String>['lazada'],
    name: 'Lazada',
    category: 'Shopping',
  ),
  ReceiptMerchant(
    match: <String>['puregold'],
    name: 'Puregold',
    category: 'Groceries',
  ),
  ReceiptMerchant(
    match: <String>['sm supermarket', 'sm hypermarket', 'savemore'],
    name: 'SM Supermarket',
    category: 'Groceries',
  ),
  ReceiptMerchant(
    match: <String>['mercury drug'],
    name: 'Mercury Drug',
    category: 'Health & Fitness',
  ),
  ReceiptMerchant(
    match: <String>['watsons'],
    name: 'Watsons',
    category: 'Health & Fitness',
  ),
];
