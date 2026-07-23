// The Pan mood mapping is the contract that keeps the cup consistent whether a
// mood came from the coach (Home) or from an Ask Pan reply (chat). This locks
// every coach kind and every reply mood to its cup mood, and confirms the two
// sources agree where they should (an overdue-utang coach item and a worried
// reply about money both read as the same cup mood family).

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:salapify/money/pan_mood.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/pan_mascot.dart';

void main() {
  group('coach kind -> cup mood', () {
    test('money-at-risk kinds read worried', () {
      for (final k in ['crunch', 'debtdue', 'overspend', 'payday', 'forecast']) {
        expect(panMoodForCoachKind(k), PanMood.worried, reason: k);
      }
    });
    test('gentle to-do kinds read nudge', () {
      for (final k in ['utang', 'hot', 'logtoday', 'buffer', 'goal', 'lesson']) {
        expect(panMoodForCoachKind(k), PanMood.nudge, reason: k);
      }
    });
    test('the all-clear reads happy', () {
      expect(panMoodForCoachKind('good'), PanMood.happy);
    });
    test('unknown or null rests calm', () {
      expect(panMoodForCoachKind(null), PanMood.calm);
      expect(panMoodForCoachKind('something-new'), PanMood.calm);
    });
  });

  group('reply mood -> cup mood', () {
    test('the three reply moods map cleanly', () {
      expect(panMoodForReplyMood('worried'), PanMood.worried);
      expect(panMoodForReplyMood('happy'), PanMood.happy);
      expect(panMoodForReplyMood('idle'), PanMood.calm);
    });
    test('unknown or null rests calm', () {
      expect(panMoodForReplyMood(null), PanMood.calm);
      expect(panMoodForReplyMood('???'), PanMood.calm);
    });
  });

  test('coach and chat agree on the shared worried/happy states', () {
    // A debt-due coach item and a worried reply are the same cup mood, so Pan
    // never contradicts itself between Home and chat.
    expect(panMoodForCoachKind('debtdue'), panMoodForReplyMood('worried'));
    expect(panMoodForCoachKind('good'), panMoodForReplyMood('happy'));
  });

  test('every mood has a distinct Rive input number', () {
    final inputs = PanMood.values.map((m) => m.input).toSet();
    expect(inputs.length, PanMood.values.length);
    expect(PanMood.calm.input, 0);
    expect(PanMood.happy.input, 3);
  });

  testWidgets('PanMascot renders for every mood without error', (tester) async {
    // The placeholder cup reads the active Barako palette, so set one first,
    // exactly as the app does before any screen builds.
    Barako.currentTheme = themeForKey('barako');
    Barako.current = Barako.currentTheme.resolve(Brightness.light);
    for (final m in PanMood.values) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: PanMascot(mood: m))),
      ));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PanMascot), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
