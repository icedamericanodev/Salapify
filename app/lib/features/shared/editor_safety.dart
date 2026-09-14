// The three things every editor sheet has to get right, in one place.
//
// All three came out of one QA pass on the first two sheets this app ever
// grew, and none of them is specific to accounts or to budgets. Writing them
// twice is how the third sheet gets one of them wrong.
import 'package:flutter/widgets.dart';

/// Put a stored peso figure into a text field WITHOUT losing centavos.
///
/// The obvious `toStringAsFixed(0)` is a data loss bug, not a formatting
/// choice. It rounds half away from zero, and the sheet then saves whatever the
/// field holds, so a limit of 20,000.50 comes back as 20,001 and a cap of
/// 1,234.56 comes back as 1,235 by the act of OPENING the editor and pressing
/// save with no edit at all. 999.99 prefills as 1,000, so this is not even a
/// sub-peso nicety. A stored peso figure that changes with no user action is
/// exactly what the money-meaning rule in CLAUDE.md forbids, and a restored
/// backup carrying fractional amounts walks into it on the user's first visit.
///
/// So: whole pesos print with no decimals, because "20000" is what somebody
/// wants to see and edit, and anything with centavos keeps them.
String moneyField(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Read a typed peso amount. Blank is [blank]; anything unreadable is null.
///
/// `double.tryParse` is NOT enough on its own and the gap is a silent data
/// loss. It happily returns real values for 'NaN', 'Infinity' and '1e400', and
/// `n < 0` is false for every one of them, so an unguarded check passes them
/// through as if they were money. The screen then renders "your ₱Infinity
/// monthly limit", the sheet reports a successful save, and `sanitizeData`
/// coerces the non-finite value to 0 on the way to disk. The user's limit is
/// gone and nothing ever said so. Reachable by paste, by a hardware keyboard,
/// or by any keyboard with a letters toggle.
///
/// Returns null for unreadable, [negative] for a value below zero, so a caller
/// can tell somebody their number is negative rather than claiming it cannot be
/// read. It can be read. It is negative, which is a different sentence.
({double? value, bool negative}) readMoney(String raw, {double blank = 0}) {
  final t = raw.trim().replaceAll(',', '');
  if (t.isEmpty) return (value: blank, negative: false);
  final n = double.tryParse(t);
  if (n == null || !n.isFinite) return (value: null, negative: false);
  if (n < 0) return (value: null, negative: true);
  return (value: n, negative: false);
}

/// Close a sheet after a save, and never close anything else.
///
/// `if (mounted) Navigator.of(context).pop(true)` looks careful and is not.
/// `mounted` stays true for the whole exit animation and says nothing about
/// whether this route has already been popped. These sheets open on the ROOT
/// navigator (they have to, or they open underneath the tab bar), whose only
/// other page is the app shell, so a second pop does not close a sheet: it
/// pops the entire app. In debug that is go_router asserting
/// `currentConfiguration.isNotEmpty`; in release the assert is compiled out,
/// the history simply empties, and the user is left on a blank window with no
/// way back except force-quitting.
///
/// Two ordinary sequences reach it. Tapping Save twice, because the button has
/// no disabled state and the write takes a moment. And tapping Save then
/// pressing Back, which is exactly what a person does when a button appears to
/// have done nothing.
///
/// [ModalRoute.isCurrent] is the honest question: is this route still the one
/// on top, right now. It is false the moment something else pops it, animation
/// or no animation.
void closeAfterSaving<T>(BuildContext context, T result) {
  final route = ModalRoute.of(context);
  if (route == null || !route.isCurrent) return;
  Navigator.of(context).pop(result);
}
