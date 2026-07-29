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
final _rawDateInString = RegExp(
  r'\$\{?[a-zA-Z_][\w.]*\['
  "['\"]"
  r'(payday|dueDate|targetDate|interestThroughISO)'
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
  });
}
