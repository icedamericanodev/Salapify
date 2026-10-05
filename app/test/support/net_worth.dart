// What a journey test means by "net worth", stated once.
//
// WHY THIS FILE EXISTS. Seven journey files carried their own copy of this,
// and every one of them was the same wrong definition:
//
//     s.accounts.fold(0, (sum, a) => sum + a.balance.pesos)
//
// That ADDS liabilities instead of subtracting them, because a credit card
// stores what you OWE as a positive number. It is not net worth, it is the
// sum of some unrelated figures, and for most of what those journeys did it
// happened to move in the right direction.
//
// IT HID A REAL BUG FOR AS LONG AS IT EXISTED. `applyToBalances` decided its
// direction from the transaction type alone and never read the account kind,
// so charging 1,000 to a credit card REDUCED what was owed and raised real
// net worth by 1,000. Under the hollow helper the same event read as a card
// balance falling by 1,000, which looks exactly like an asset falling by
// 1,000, which looks exactly correct. The check was shaped so the defect
// could not move it.
//
// It matters more now than it did. Since Move Money began accepting
// liabilities on 2026-10-05 a journey can pay a credit card, and paying one
// is the case where the two definitions disagree hardest: the real figure
// does not move at all, while the hollow one falls by the payment.
//
// One definition, one import, read through `computePosition` so the tests
// agree with the screen by construction rather than by coincidence.

import 'package:salapify/core/money/money.dart';
import 'package:salapify/core/money/reports.dart';
import 'package:salapify/state/financial_state.dart';

/// Net worth as the app itself computes it: what you own, less what you owe.
///
/// Reads accounts only, which is what these journeys compare before and
/// after a tap. `computePosition` also accepts debts and instalment plans,
/// and a journey that moves one of those should pass them in rather than
/// expect this helper to guess.
Money netWorthOf(FinancialState s) =>
    computePosition(s.accounts, null).netWorth;
