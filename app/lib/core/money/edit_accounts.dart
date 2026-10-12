/// Which accounts an entry being EDITED may use (2026-10-11).
///
/// ONE rule, read by both the Log sheet in edit mode (what the pickers
/// offer) and `FinancialState.editPreview` (whether Edit is offered at all).
/// Before this, the store refused any entry on a card or loan because the
/// sheet could only pick everyday accounts, so a card payment typed as 500
/// instead of 700 could only be taken back and made again.
///
/// Nothing here is new: each half copies a rule a write path already uses.
///
/// - A MOVE leaves from where Move money lets money leave and arrives where
///   Move money lets it arrive, which is how a card or a loan gets paid.
/// - A SPEND or an INCOME uses an everyday account or a credit card, the
///   rule the receipt scanner already uses, because buying something ON the
///   card is the commonest card entry there is.
///
/// Logging a NEW entry is unchanged: the Log sheet still offers everyday
/// accounts only, and paying a card is still Move money's job.
library;

import '../../models/models.dart';
import 'reports.dart' show settlementKinds, liabilityKinds;

/// Whether an edited entry of [type] may come FROM [a].
bool canEditFrom(Account a, TransactionType type) =>
    type == TransactionType.transfer
    ? settlementKinds.contains(a.kind)
    : a.isLiquid || a.kind == AccountKind.credit;

/// Whether an edited move may arrive IN [a].
bool canEditTo(Account a) =>
    settlementKinds.contains(a.kind) || liabilityKinds.contains(a.kind);
