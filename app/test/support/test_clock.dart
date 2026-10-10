/// The day the tests pretend it is.
///
/// Split out from `pinned_app.dart` so a pure engine test can take the date
/// without pulling in `flutter_test` and the whole app with it.
///
/// ## Why the tests need a date at all
///
/// The sample ledger used to carry fixed calendar dates, written against
/// 18 September 2026. It now carries OFFSETS and builds itself around whatever
/// day it is handed, which is what stops a brand new install showing a Log
/// full of entries from "yesterday" above a Budgets screen reporting nothing
/// spent this month.
///
/// Handing it this date gives back exactly the ledger the fixed dates used to
/// produce, which is why the expected figures all over the suite did not have
/// to change. `seed_dates_test.dart` asserts that equivalence directly rather
/// than leaving it as a claim.
///
/// A default argument on the seed would have let these tests compile
/// untouched, and it would have been the same mistake the whole clock fix
/// just removed: a quiet fallback to the real calendar that nothing can see.
library;

/// 18 September 2026, the day the sample ledger was written around.
DateTime get testToday => DateTime(2026, 9, 18);
