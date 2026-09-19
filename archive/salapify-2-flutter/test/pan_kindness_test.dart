// The kindness invariant, made a machine.
//
// Pan the mascot pivoted to feeling faces, and the promise that makes that safe
// is that the AMBIENT, automatic Pan, the one driven by coach kinds, chat reply
// moods, and recent actions, never cries at, scowls at, or wearies at a user who
// is already worried about their money. sad, tired and angry are reserved for
// specific non-verdict moments wired by hand, never a reaction to the numbers.
//
// That promise lived only in a comment. This makes it a test: every PanMood, the
// only thing the reaction machine produces, must map to a kind face. A future
// edit that routes an ambient mood into sad/tired/angry reddens CI instead of
// reaching a phone.
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/widgets/pan_mascot.dart';

void main() {
  test('the ambient reactive Pan never cries, scowls, or wearies at the user', () {
    const reserved = {PanEmotion.sad, PanEmotion.tired, PanEmotion.angry};
    for (final mood in PanMood.values) {
      final emotion = emotionForMood(mood);
      expect(
        reserved.contains(emotion),
        isFalse,
        reason:
            'PanMood.${mood.name} maps to PanEmotion.${emotion.name}, which is '
            'reserved. The ambient reaction to someone already worried about '
            'money must never be crying, scowling, or weary.',
      );
    }
    // And the everyday moods resolve to the two intended faces, so this test
    // fails loudly if the mapping is gutted to a single face instead of fixed.
    expect(emotionForMood(PanMood.worried), PanEmotion.worried);
    expect(emotionForMood(PanMood.happy), PanEmotion.content);
    expect(emotionForMood(PanMood.calm), PanEmotion.content);
  });
}
