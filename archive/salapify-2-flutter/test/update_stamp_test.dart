// The Update stamp row must stay a row.
//
// It became a wall of text on the founder's phone: roughly forty lines of
// release notes filling the whole screen, because each build appended the
// previous build's story to the stamp instead of replacing it. The row itself
// is a right-aligned Text with no line limit, so nothing pushed back.
//
// Two guards, because either alone would have failed here. This test stops a
// long stamp being written at all, and update_card.dart caps the rendered
// lines so even a stamp that somehow gets through cannot take the screen.

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
            'narrow right-aligned column on a phone, so anything much past '
            '120 wraps into a wall. Put the detail in the pull request and '
            'docs/delivery-log.md, and keep this line high level.',
      );
    });

    test('starts with the version marker the founder compares', () {
      expect(
        RegExp(r'^f\d+\.\d+').hasMatch(updateStamp),
        isTrue,
        reason:
            'The founder reads this against the last row of '
            'docs/delivery-log.md, so it has to start with the stamp itself.',
      );
    });

    test('does not carry previous builds forward', () {
      // The exact mechanism of the wall: naming an older stamp inside the
      // current one. Each build did it once, and they accumulated.
      final others = RegExp(r'f\d+\.\d+').allMatches(updateStamp).length;
      expect(
        others,
        1,
        reason:
            'The stamp names $others versions. It should name exactly one, '
            'its own. Older builds are already recorded in the delivery log; '
            'repeating them here is what grew the wall of text.',
      );
    });

    test('has no em or en dashes, same as all copy', () {
      expect(updateStamp.contains('—'), isFalse);
      expect(updateStamp.contains('–'), isFalse);
    });
  });
}
