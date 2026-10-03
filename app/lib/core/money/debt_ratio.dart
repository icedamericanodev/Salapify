/// THE debt to income rule. One rule, stated once.
///
/// ## Why this file exists
///
/// The October expert review counted FOUR different answers to the same
/// question in one app:
///
///   - the health check called 25% comfortable and 40% tight, on take-home
///   - `calculateDsr` called under 30% healthy and over 40% stretched, while
///     separately recommending a ceiling of 35% of GROSS
///   - the debt calculator screen repeated the 30 and 40 as its own copy
///   - the Academy twice told people to stay under 15% of take-home
///
/// A person who reads two of those learns that Salapify does not know. The
/// numbers were each defensible on their own and that is exactly the problem:
/// nothing was wrong enough to notice, and together they were incoherent.
///
/// Founder decision F8 settles it: monthly debt payments at or below 30% of
/// take-home pay, one constant, referenced everywhere.
///
/// ## What this is NOT
///
/// It is a rule of thumb, not a regulation. `loan.dart` already carries the
/// warning in its own words: the BSP publishes no determination about an
/// individual's ratio, and naming a regulator turns a rule of thumb into an
/// official blessing the app cannot give. Nothing here may be presented as a
/// legal threshold.
library;

/// At or below this share of take-home pay, debt payments are comfortable.
///
/// 30, by founder decision F8. It replaced a 25 in the health check and a 15
/// in the Academy, and it is the same 30 the loan screens already used, so the
/// app now says one thing.
const int debtShareComfortable = 30;

/// Above this share, debt payments are stretched.
///
/// Unchanged at 40, which all three of the old rules that bothered to name an
/// upper band already agreed on.
const int debtShareStretched = 40;

/// The same comfortable share as a fraction, for the places that multiply
/// rather than compare.
///
/// Derived, never typed a second time. A `0.30` written out beside a `30` is
/// how two constants drift into disagreeing, which is the whole defect this
/// file exists to end.
const double debtShareComfortableFraction = debtShareComfortable / 100;
