// A machine date never appears in a sentence a person reads.
//
// Insights printed "(payday 2026-07-30)" for its whole life, on a screen whose
// entire job is reading plainly, while every other screen in the app said
// "Jul 30". Nobody saw it, and the reason is worth more than the bug: every
// render of that tab ran against an EMPTY store, so the card never had a
// payday to print. Sixteen shots, both brightnesses, not one with money in it.
//
// The fixture in screens_shot.dart is fixed, and this is the second half. A
// render only catches what somebody looks at; this catches the shape wherever
// it appears, including screens nobody thought to shoot.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A stored ISO date read straight out of a map and dropped into a string.
///
/// The fix, `${prettyDay(sts['payday'])}`, does not match, because the brace
/// is followed by a call rather than by the map read. That distinction is the
/// whole test, so it is asserted in its own case below.
///
/// The key names were four literal spellings for one round: payday, dueDate,
/// targetDate, interestThroughISO. Exactly the four that existed when the bug
/// was found. So this file, whose title says no raw dates in copy, let
/// `Due ${person['oldestDue']}` through onto the Owed to me list, where it
/// printed "Due 2026-08-15" at somebody about to ask a friend for money.
///
/// A test that reads as a rule and implements a list will keep doing that: the
/// next offender is by definition the spelling nobody thought of. So the key is
/// matched by SHAPE now, anything ending in Date, Due or ISO, plus payday.
///
/// Ending in `Day` deliberately does NOT match. `dueDay` and `statementDay`
/// hold a day number from 1 to 31 and printing one is correct, so a pattern
/// that caught them would be demanding a bug.
///
/// This still cannot see a date that passes through a local variable first,
/// which is said plainly here rather than implied by silence. That is why
/// screen_readability_test.dart now also checks what was actually DRAWN: a
/// static scan guesses at names, a render knows.
final _rawDateInString = RegExp(
  r'\$\{?[a-zA-Z_][\w.]*\['
  "['\"]"
  r'(payday|\w*Date|\w*Due|\w*ISO)'
  "['\"]"
  r'\]\}?',
);

void main() {
  test('no user-facing string interpolates a raw stored date', () {
    final offenders = <String>[];
    for (final f in Directory('lib/screens').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (!_rawDateInString.hasMatch(line)) continue;
        offenders.add('${f.path}:${i + 1}  ${line.trim()}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'these put a stored ISO date straight into a sentence. Every other '
          'screen writes "Jul 30"; a machine date in prose reads as a bug to '
          'the person holding the phone:\n${offenders.join('\n')}',
    );
  });

  test('the scan would actually find one', () {
    // A scanner that matches nothing passes on an empty directory and on a
    // typo in its own pattern, and reads exactly like a clean bill of health.
    expect(
      _rawDateInString.hasMatch(r"'for the next day (payday ${s['payday']}).'"),
      isTrue,
      reason: 'the shape the bug had',
    );
    expect(
      _rawDateInString.hasMatch(
        r"'for the next day (payday ${prettyDay(s['payday'])}).'",
      ),
      isFalse,
      reason: 'the fix must not be flagged, or the guard is unusable',
    );
    // Assigning it to a variable is not the bug; printing it is.
    expect(_rawDateInString.hasMatch(r"final p = s['payday'];"), isFalse);
    // The spelling that walked past the first version of this scan, and the
    // reason the key is now matched by shape.
    expect(
      _rawDateInString.hasMatch(r"'Due ${person['oldestDue']}'"),
      isTrue,
      reason: 'oldestDue is a date and was not on the old list of four',
    );
    // A day NUMBER is not a date. dueDay holds 1 to 31 and printing it is
    // correct, so flagging it would be demanding a bug rather than catching
    // one. This is the half that keeps the widened pattern honest.
    expect(_rawDateInString.hasMatch(r"'Every ${d['dueDay']}th'"), isFalse);
    expect(
      _rawDateInString.hasMatch(r"'Statement on the ${d['statementDay']}'"),
      isFalse,
    );
  });
}
