// Pure money helpers for the Accounts screen, ported from mobile/app/accounts.js
// and golden-locked against the real RN expressions. Only the centavo rounding
// is subtle: JS Math.round is floor(x + 0.5), which differs from Dart's
// double.round() on negative half values (a balance decrease), so it is spelled
// out here rather than using .round().

double _jsRound(double x) => (x + 0.5).floorToDouble();

/// Round to the centavo the way RN does: Math.round(x * 100) / 100. Used so
/// repeated balance moves never leave float residue like 0.30000000000000004.
double round2(double x) => _jsRound(x * 100) / 100;

/// The signed balance-adjustment amount when an account's balance is edited
/// from oldBalance to newAmount, rounded to the centavo. Positive means money
/// was added (flow in), negative means it dropped (flow out or an expense).
double balanceAdjustDelta(double newAmount, double oldBalance) =>
    round2(newAmount - oldBalance);
