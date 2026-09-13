// The line at the top of Home that says hello.
//
// Pure on purpose: it takes an hour and an optional name and returns text, so
// every rule below is testable without pumping a widget or waiting for a
// clock. The screen just renders what this returns.
//
// The single most important property here is that it reads WELL WITH NO NAME.
// Every user who already has the app has no name stored, the ask is skippable
// by design, and a greeting that degrades to "Good morning, !" or that quietly
// disappears when the name is missing would make the common case the broken
// one.

/// How the app addresses the user, or null if they never said.
///
/// Deliberately not a required field anywhere. Salapify works completely
/// without it and must never imply otherwise.
String? normalizeDisplayName(Object? raw) {
  if (raw is! String) return null;
  // Collapse whitespace so " Ana  " and "Ana" are the same person, and a name
  // made only of spaces is the same as no name at all.
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.isEmpty) return null;
  // A greeting is one line on a phone. This is not a security boundary, it is
  // a layout one: the cap exists so a pasted paragraph cannot push the rest of
  // Home off the screen. Restoring a hand-edited backup is the realistic way a
  // 4000 character "name" arrives.
  if (trimmed.length > displayNameMaxLength) {
    return trimmed.substring(0, displayNameMaxLength).trim();
  }
  return trimmed;
}

/// Long enough for any real name, short enough to stay on one line.
const int displayNameMaxLength = 24;

/// morning / afternoon / evening, from a 24 hour clock.
///
/// The boundaries are the ordinary ones people expect rather than anything
/// clever: midnight to noon is morning, noon to 6pm afternoon, and the rest
/// evening. Someone logging a jeepney fare at 2am gets "Good evening", which
/// is friendlier than inventing a fourth greeting for the small hours.
String partOfDay(int hour) {
  if (hour < 12) return 'morning';
  if (hour < 18) return 'afternoon';
  return 'evening';
}

/// The greeting shown at the top of Home.
///
/// With a name: "Good morning, Ana". Without: "Good morning". Never a dangling
/// comma, never an empty string.
String greetingFor(DateTime now, {String? name}) {
  final clean = normalizeDisplayName(name);
  final part = 'Good ${partOfDay(now.hour)}';
  return clean == null ? part : '$part, $clean';
}
