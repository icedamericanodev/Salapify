import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/accounts.dart';

/// What may be STORED for a card number, and what may be SHOWN.
///
/// Two rules, deliberately different, and the difference is the whole point of
/// the file. The account form is labelled "last four digits" and used to
/// accept and store anything at all, while the card drew it masked. Somebody
/// pasting a full sixteen digit number saw "•••• 4402" and concluded four
/// digits were what got kept. The file held the lot.
void main() {
  group('what reaches the file', () {
    test('a full card number is cut down to the last four', () {
      expect(cardTailForStorage('4127 8890 2211 4402'), '4402');
      expect(cardTailForStorage('4127889022114402'), '4402');
      expect(
        cardTailForStorage('4127-8890-2211-4402'),
        '4402',
        reason: 'punctuation must not smuggle the rest of the number through',
      );
    });

    test('a short entry is KEPT, not silently dropped', () {
      // maskedTail returns null below four, which is right for drawing and
      // wrong for saving: discarding what somebody typed is a small data loss
      // they would only discover by noticing something missing later.
      expect(cardTailForStorage('88'), '88');
      expect(cardTailForStorage('8'), '8');
    });

    test('nothing at all is null, not an empty string', () {
      expect(cardTailForStorage(null), isNull);
      expect(cardTailForStorage(''), isNull);
      expect(cardTailForStorage('   '), isNull);
      expect(
        cardTailForStorage('no digits here'),
        isNull,
        reason: 'a row reading "Number: " is worse than no row',
      );
    });

    test('no input of any length can produce more than four digits', () {
      // The property, rather than three examples of it. This is the promise
      // the privacy fix actually makes.
      for (int n = 1; n <= 24; n++) {
        final String typed = List<String>.generate(
          n,
          (int i) => '$i'.substring(0, 1),
        ).join();
        final String? stored = cardTailForStorage(typed);
        expect(
          (stored ?? '').length,
          lessThanOrEqualTo(4),
          reason: '$n typed digits stored as "$stored"',
        );
      }
    });
  });

  group('what reaches the screen', () {
    test('four digits draw, fewer than four draw nothing', () {
      expect(maskedTail('4402'), '4402');
      expect(
        maskedTail('88'),
        isNull,
        reason:
            '"•••• 88" is not a tail anybody can identify a card by, so the '
            'card would rather draw no row at all',
      );
    });

    test('the grouped form never contains more than the tail', () {
      final String drawn = pannedNumber('4127 8890 2211 4402');
      expect(drawn, contains('4402'));
      for (final String leading in <String>['4127', '8890', '2211']) {
        expect(drawn, isNot(contains(leading)));
      }
    });
  });
}
