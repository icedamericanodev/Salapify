// The Phase 2 shared components, tested on BEHAVIOR: the busy button that
// must not go gray mid-save, the progress bar that must clamp junk and snap
// under reduce-motion, the amount that must never render off its ladder, and
// the two sheets that must speak one dialect. Every guard here was broken
// once on purpose before being trusted; the failure lines live in the commit
// message, per the house rule.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/edit_sheet.dart' show EditSheet;
import 'package:salapify/screens/log_sheet.dart' show LogSheet;
import 'package:salapify/theme.dart';
import 'package:salapify/typography.dart';
import 'package:salapify/widgets/amount_text.dart';
import 'package:salapify/widgets/choice_chip.dart';
import 'package:salapify/widgets/chart_frame.dart';
import 'package:salapify/widgets/entry_form.dart';
import 'package:salapify/widgets/insight_card.dart';
import 'package:salapify/widgets/primary_button.dart';
import 'package:salapify/widgets/progress_bar.dart';
import 'package:salapify/widgets/section.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _harness(
  Widget child, {
  double textScale = 1.0,
  bool reduceMotion = false,
}) => MaterialApp(
  theme: salapifyTheme(Barako.current),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
      ),
    ),
  ),
);

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 1000},
  ],
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'Groceries',
      'amount': 250,
      'date': '2026-07-20',
      'accountId': 'cash',
    },
  ],
};

void main() {
  group('AmountText', () {
    testWidgets('every role renders its ladder rung, never a local size', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          Column(
            children: [
              AmountText(1250.50, role: AmountRole.card),
              AmountText(1250.50, role: AmountRole.row),
              AmountText(1250.50, role: AmountRole.metric),
            ],
          ),
        ),
      );
      final texts = tester
          .widgetList<Text>(find.textContaining('1,250.50'))
          .toList();
      expect(texts, hasLength(3));
      expect(texts[0].style!.fontSize, TypeScale.big);
      expect(texts[0].style!.fontWeight, TypeWeight.heavy);
      expect(texts[1].style!.fontSize, TypeScale.body);
      expect(texts[1].style!.fontWeight, TypeWeight.bold);
      expect(texts[2].style!.fontSize, TypeScale.subtitle);
      // Tabular figures on every money role, so columns line up.
      for (final t in texts) {
        expect(
          t.style!.fontFeatures,
          contains(const FontFeature.tabularFigures()),
          reason: 'A money figure without tnum jitters in its column.',
        );
      }
    });

    testWidgets(
      'signed prefixes + on income only, direction never color-only',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            Column(
              children: [
                AmountText(500, signed: true),
                AmountText(-500, signed: true),
              ],
            ),
          ),
        );
        expect(find.text('+₱500'), findsOneWidget);
        expect(find.text('-₱500'), findsOneWidget);
      },
    );

    testWidgets('a figure too wide for its slot scales down, never clips', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 60,
            child: AmountText(123456789.25, role: AmountRole.card),
          ),
        ),
      );
      // The FittedBox is the no-clip contract: present and scaling.
      final fitted = tester.widget<FittedBox>(
        find.ancestor(
          of: find.textContaining('123,456,789'),
          matching: find.byType(FittedBox),
        ),
      );
      expect(fitted.fit, BoxFit.scaleDown);
    });
  });

  group('PrimaryButton', () {
    testWidgets('busy disables the tap but keeps the working colors', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          PrimaryButton('Save entry', busy: true, onPressed: () => taps++),
        ),
      );
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(taps, 0, reason: 'A busy save must not be double-tappable.');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The whole point: mid-save the button must not go Material-disabled
      // gray, which reads as "it broke" on the app's most used path.
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byType(Material),
        ),
      );
      expect(
        material.color,
        Barako.primary,
        reason: 'Busy must keep the primary fill, not the disabled wash.',
      );
    });

    testWidgets('not busy: taps fire and no spinner shows', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(PrimaryButton('Save entry', onPressed: () => taps++)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.byType(FilledButton));
      expect(taps, 1);
    });
  });

  group('SalapifyProgressBar', () {
    testWidgets('junk values clamp instead of throwing', (tester) async {
      await tester.pumpWidget(
        _harness(
          Column(
            children: [
              SalapifyProgressBar(value: 3.5, semanticsLabel: 'Over'),
              SalapifyProgressBar(value: double.nan, semanticsLabel: 'Junk'),
              SalapifyProgressBar(value: -2, semanticsLabel: 'Under'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars[0].value, 1.0);
      expect(bars[1].value, 0.0);
      expect(bars[2].value, 0.0);
    });

    testWidgets('the two sizes are the only two heights', (tester) async {
      await tester.pumpWidget(
        _harness(
          Column(
            children: [
              SalapifyProgressBar(value: 0.5, semanticsLabel: 'A'),
              SalapifyProgressBar(
                value: 0.5,
                size: ProgressBarSize.micro,
                semanticsLabel: 'B',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final bars = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .toList();
      expect(bars[0].minHeight, 8);
      expect(bars[1].minHeight, 5);
    });

    testWidgets('a value change animates instead of teleporting', (
      tester,
    ) async {
      Widget at(double v) =>
          _harness(SalapifyProgressBar(value: v, semanticsLabel: 'Goal'));
      await tester.pumpWidget(at(0.2));
      await tester.pumpAndSettle();
      await tester.pumpWidget(at(0.8));
      // Halfway through Motion.reveal the fill must be in between: neither
      // still at the old value nor already teleported to the new one.
      await tester.pump(const Duration(milliseconds: 210));
      final mid = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(mid, greaterThan(0.2));
      expect(mid, lessThan(0.8));
      await tester.pumpAndSettle();
    });

    testWidgets('reduce-motion snaps, the setting means no animation', (
      tester,
    ) async {
      Widget at(double v) => _harness(
        SalapifyProgressBar(value: v, semanticsLabel: 'Goal'),
        reduceMotion: true,
      );
      await tester.pumpWidget(at(0.2));
      await tester.pump();
      await tester.pumpWidget(at(0.8));
      await tester.pump();
      final now = tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value!;
      expect(now, 0.8);
    });
  });

  group('SalapifyChoiceChip', () {
    testWidgets('selection clicks, re-selection stays silent', (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments.toString());
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var picked = '';
      await tester.pumpWidget(
        _harness(
          Row(
            children: [
              SalapifyChoiceChip(
                label: 'Expense',
                selected: true,
                onSelected: (_) => picked = 'expense',
              ),
              const SizedBox(width: 8),
              SalapifyChoiceChip(
                label: 'Income',
                selected: false,
                onSelected: (_) => picked = 'income',
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Expense'));
      expect(picked, 'expense');
      expect(
        haptics,
        isEmpty,
        reason:
            'Re-tapping the already selected chip changes nothing; a buzz on '
            'a no-op teaches the hand to distrust every other buzz.',
      );
      await tester.tap(find.text('Income'));
      expect(picked, 'income');
      expect(haptics, hasLength(1), reason: 'A real change clicks once.');
    });

    testWidgets('selection carries a shape cue, not color alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          SalapifyChoiceChip(label: 'On', selected: true, onSelected: (_) {}),
        ),
      );
      final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
      expect(
        chip.showCheckmark,
        isTrue,
        reason: 'The check glyph is the non-color selection cue.',
      );
    });
  });

  group('Kicker', () {
    testWidgets('muted outside a card, caramel inside', (tester) async {
      await tester.pumpWidget(
        _harness(
          Column(children: [Kicker('OUTSIDE'), Kicker('INSIDE', inCard: true)]),
        ),
      );
      expect(
        tester.widget<Text>(find.text('OUTSIDE')).style!.color,
        Barako.muted,
      );
      expect(
        tester.widget<Text>(find.text('INSIDE')).style!.color,
        Barako.caramel,
      );
    });
  });

  group('StatPair', () {
    testWidgets('large text stacks the pair so figures keep their scale', (
      tester,
    ) async {
      Widget pair() => StatPair(
        leftLabel: 'Assets',
        leftValue: '₱88,560',
        rightLabel: 'Owed',
        rightValue: '₱46,000',
      );
      await tester.pumpWidget(_harness(pair()));
      expect(
        find.ancestor(
          of: find.text('₱46,000'),
          matching: find.byType(Expanded),
        ),
        findsWidgets,
        reason: 'At normal scale the two sides share a row.',
      );
      await tester.pumpWidget(_harness(pair(), textScale: 1.5));
      expect(
        find.ancestor(
          of: find.text('₱46,000'),
          matching: find.byType(Expanded),
        ),
        findsNothing,
        reason:
            'At 1.5x the pair stacks full-width instead of shrinking the '
            'figures back toward 1.0x inside half-width columns.',
      );
    });
  });

  group('ChartFrame', () {
    testWidgets('kicker is the inside-card caramel voice, caption renders', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          ChartFrame(
            kicker: 'SIX MONTH TREND',
            chart: const SizedBox(height: 40),
            caption: 'July spending was ₱2,300 under June.',
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('SIX MONTH TREND')).style!.color,
        Barako.caramel,
        reason: 'A kicker inside a card warms to caramel, the written rule.',
      );
      expect(
        find.text('July spending was ₱2,300 under June.'),
        findsOneWidget,
        reason: 'Every chart states its own conclusion with a number.',
      );
    });
  });

  group('InsightCard and Metric', () {
    testWidgets('the three slots render and attention speaks warning ink', (
      tester,
    ) async {
      var acted = false;
      await tester.pumpWidget(
        _harness(
          InsightCard(
            kicker: 'FOOD SPENDING',
            observation: 'You spent ₱1,420 more on food.',
            meaning: 'Most of the increase came from delivery.',
            actionLabel: 'Review spending',
            onAction: () => acted = true,
            tone: InsightTone.attention,
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('FOOD SPENDING')).style!.color,
        Barako.warning,
      );
      expect(find.text('You spent ₱1,420 more on food.'), findsOneWidget);
      expect(
        find.text('Most of the increase came from delivery.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Review spending'));
      expect(acted, isTrue);
    });

    testWidgets('Metric draws its value on the amountMetric rung', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          Metric(label: 'Income', value: '₱52,000', delta: '+₱4,200 vs June'),
        ),
      );
      final value = tester.widget<Text>(find.text('₱52,000'));
      expect(value.style!.fontSize, TypeScale.subtitle);
      expect(value.style!.fontWeight, TypeWeight.heavy);
      expect(find.text('+₱4,200 vs June'), findsOneWidget);
    });
  });

  group('the two sheets speak one dialect', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
    });

    testWidgets('log and edit render the same shared form and amount face', (
      tester,
    ) async {
      final store = SalapifyStore();
      await store.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: Scaffold(body: LogSheet(store: store)),
        ),
      );
      expect(find.byType(EntryFormBody), findsOneWidget);
      final logAmount = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextField),
        ),
      );
      expect(logAmount.style!.fontSize, TypeScale.big);
      expect(logAmount.style!.fontWeight, TypeWeight.heavy);

      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: Scaffold(
            body: EditSheet(
              store: store,
              tx: (store.data['transactions'] as List).first
                  .cast<String, dynamic>(),
              splittable: false,
            ),
          ),
        ),
      );
      expect(find.byType(EntryFormBody), findsOneWidget);
      final editAmount = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AmountField),
          matching: find.byType(TextField),
        ),
      );
      // The audit's P0-3 in one assertion: the two sheets' amount fields are
      // the same field. 28 against 24 was the tell that they had drifted.
      expect(editAmount.style!.fontSize, logAmount.style!.fontSize);
      expect(editAmount.style!.fontWeight, logAmount.style!.fontWeight);
    });

    testWidgets('the form error is a live region, so a failed save is heard', (
      tester,
    ) async {
      final store = SalapifyStore();
      await store.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: Scaffold(body: LogSheet(store: store)),
        ),
      );
      // Empty amount is invalid; save must surface the error.
      await tester.ensureVisible(find.text('Save entry'));
      await tester.tap(find.text('Save entry'), warnIfMissed: false);
      await tester.pump();
      final errorText = find.textContaining('Enter a plain amount');
      expect(errorText, findsOneWidget);
      final semantics = tester.widget<Semantics>(
        find.ancestor(of: errorText, matching: find.byType(Semantics)).first,
      );
      expect(semantics.properties.liveRegion, isTrue);
    });
  });
}
