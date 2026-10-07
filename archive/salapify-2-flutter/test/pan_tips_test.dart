// Content guards for Pan's floating helper tips (f4.65). A tip is an honest
// signpost, so this pins the shape: every tip has words and a button, only the
// askPan tips carry a question, and the list still leads with the four shipped
// features and ends at Pan's Q&A.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/money/pan_tips.dart';

void main() {
  test('every tip has a title, body, and a button label', () {
    expect(panTips, isNotEmpty);
    for (final t in panTips) {
      expect(t.title.trim(), isNotEmpty, reason: 'a tip has no title');
      expect(t.body.trim(), isNotEmpty, reason: '"${t.title}" has no body');
      expect(t.ctaLabel.trim(), isNotEmpty, reason: '"${t.title}" has no CTA');
    }
  });

  test('a panQuestion only rides on an askPan tip', () {
    for (final t in panTips) {
      if (t.target != PanTipTarget.askPan) {
        expect(
          t.panQuestion,
          isNull,
          reason: '"${t.title}" carries a Pan question but does not open Pan',
        );
      }
    }
  });

  test('the helper points at the shipped features and opens Pan', () {
    final targets = panTips.map((t) => t.target).toSet();
    // The three v4.58 money features it signposts, plus the open door to Pan.
    expect(targets, contains(PanTipTarget.accounts)); // safe to spend
    expect(targets, contains(PanTipTarget.debts)); // radar + avalanche/snowball
    expect(targets, contains(PanTipTarget.insights));
    expect(targets, contains(PanTipTarget.askPan));
    // The last tip is always the open door to Pan, never a dead end.
    expect(panTips.last.target, PanTipTarget.askPan);
  });

  test('no tip copy uses an em or en dash', () {
    for (final t in panTips) {
      for (final s in [t.title, t.body, t.ctaLabel]) {
        expect(s.contains('—'), isFalse, reason: 'em dash in "$s"');
        expect(s.contains('–'), isFalse, reason: 'en dash in "$s"');
      }
    }
  });
}
