// The Update stamp row must stay a ROW.
//
// On Salapify 2 it became roughly forty lines of release notes filling the
// founder's whole screen, because each build appended the previous build's
// story to the stamp instead of replacing it. The row rendering it was a Text
// with no line limit, so nothing pushed back until the founder looked at their
// phone and said so.
//
// TWO GUARDS, because either alone would have failed there. This test caps
// what can be WRITTEN. `_Row`'s `subtitleMaxLines` in settings_sheet.dart caps
// what can be RENDERED, so even a stamp that somehow gets past this cannot
// take the screen.
//
// Rewritten for app/ rather than copied from
// archive/salapify-2-flutter/test/update_stamp_test.dart. The prefix differs,
// because app/ and Salapify 2 share one docs/delivery-log.md and the prefix is
// what keeps their rows apart. The rest is the same lesson, which is why it is
// here at all: app/ has no publisher yet, so this guard is inert, and inert is
// exactly when it is cheapest to get right.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart' show updateStamp;

void main() {
  group('the update stamp', () {
    test('is short enough to stay one row', () {
      expect(
        updateStamp.length,
        lessThanOrEqualTo(120),
        reason:
            'The stamp is ${updateStamp.length} characters. It renders in a '
            'narrow column on a phone, so anything much past 120 wraps into a '
            'wall. Put the detail in the pull request and in '
            'docs/delivery-log.md, and keep this line high level.',
      );
    });

    test('starts with the version marker the founder compares', () {
      expect(
        RegExp(r'^s\d+\.\d+').hasMatch(updateStamp),
        isTrue,
        reason:
            'The founder reads this against the last row of '
            'docs/delivery-log.md, so it has to START with the stamp itself. '
            'A stamp buried mid-sentence cannot be compared at a glance.',
      );
    });

    test('does not carry previous builds forward', () {
      // The exact mechanism of the wall on Salapify 2: naming an older stamp
      // inside the current one. Each build did it once and they accumulated.
      final int named = RegExp(r's\d+\.\d+').allMatches(updateStamp).length;
      expect(
        named,
        1,
        reason:
            'The stamp names $named versions. It should name exactly one, its '
            'own. Older builds are already recorded in the delivery log, and '
            'repeating them here is what grew the wall of text.',
      );
    });

    test('never carries a Salapify 2 stamp', () {
      // app/ and Salapify 2 share docs/delivery-log.md, so an `f` stamp
      // appearing in an `s` row is the one way the two apps' histories could
      // be confused. The publisher finds the previous stamp by pattern.
      expect(
        RegExp(r'f\d+\.\d+').hasMatch(updateStamp),
        isFalse,
        reason:
            'This names an f stamp, which belongs to Salapify 2 in '
            'archive/. app/ stamps start with s.',
      );
    });

    test('has no em or en dashes, same as all copy', () {
      expect(updateStamp.contains('—'), isFalse);
      expect(updateStamp.contains('–'), isFalse);
    });

    test('actually says something', () {
      // The directional half. Every assertion above is satisfied by the bare
      // string 's0.01', which passes the cap, starts correctly, names one
      // version and contains no dashes, while telling the founder nothing at
      // all about what they are running.
      final String afterMarker = updateStamp
          .replaceFirst(RegExp(r'^s\d+\.\d+'), '')
          .replaceAll(RegExp(r'^[\s·.:-]+'), '');
      expect(
        afterMarker.length,
        greaterThanOrEqualTo(15),
        reason:
            'The stamp is only a version number. It should also say, in a few '
            'words, what this build is, because that is what makes the row '
            'worth reading rather than just worth comparing.',
      );
    });
  });
}
