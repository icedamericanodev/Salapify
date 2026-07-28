// The period selector as a screen control, and Activity filtered by it.
//
// The engine is golden locked in period_golden_test. What is guarded here is
// the part a golden file cannot see: that the control is wired to the list, and
// above all that it never silently HIDES entries. A filter that quietly
// excludes rows makes a screen look complete while it is not, and the person
// reading it has no way to tell.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/money/period.dart';
import 'package:salapify/screens/history.dart';
import 'package:salapify/widgets/period_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime _now() => DateTime(2026, 7, 28);

Map<String, dynamic> _blob() => {
  'schemaVersion': 12,
  'settings': {'onboarded': true},
  'transactions': [
    {
      'id': 't1',
      'type': 'expense',
      'label': 'ThisMonth',
      'amount': 100,
      'date': '2026-07-05',
    },
    {
      'id': 't2',
      'type': 'expense',
      'label': 'LastMonth',
      'amount': 200,
      'date': '2026-06-20',
    },
    {
      'id': 't3',
      'type': 'expense',
      'label': 'LastYear',
      'amount': 300,
      'date': '2025-03-11',
    },
  ],
};

Future<SalapifyStore> _openHistory(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
  final store = SalapifyStore();
  await store.load();
  await tester.pumpWidget(
    MaterialApp(
      // The clock is PINNED. Without it the selector fell back to
      // DateTime.now while these fixtures are hard coded to July 2026, so
      // three of the tests below were going to start failing on 1 August and
      // turn the branch check red on main. QA caught it four days out.
      home: Scaffold(
        body: HistoryScreen(store: store, clock: _now),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

/// Mounts the bare control with a fixed clock, returning the periods it emits.
Future<List<Period>> _mountSelector(
  WidgetTester tester,
  Period start, {
  bool allowAll = true,
}) async {
  final emitted = <Period>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            final current = emitted.isEmpty ? start : emitted.last;
            return PeriodSelector(
              period: current,
              allowAll: allowAll,
              clock: _now,
              onChange: (p) => setState(() => emitted.add(p)),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return emitted;
}

/// Scoped to the selector. The type filter row on Activity sits right below
/// this one, so a bare find.text can reach the wrong chip.
Finder _chip(String label) => find.descendant(
  of: find.byType(PeriodSelector),
  matching: find.text(label),
);

/// Scoped to the list, because typing a word into the filter field puts that
/// same word on screen inside the field itself.
Finder _row(String label) =>
    find.descendant(of: find.byType(ListView), matching: find.text(label));

/// find.byTooltip resolves to the Tooltip, not the button inside it.
IconButton _stepButton(WidgetTester tester, IconData icon) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

void main() {
  testWidgets('Activity opens showing EVERYTHING, not this month', (
    tester,
  ) async {
    // The default matters more than any other behaviour here. Activity has
    // always shown every entry, so opening it pre-filtered to this month would
    // make last month's entries look deleted to someone who never touched the
    // new control.
    await _openHistory(tester);
    expect(_row('ThisMonth'), findsOneWidget);
    expect(_row('LastMonth'), findsOneWidget);
    expect(_row('LastYear'), findsOneWidget);
  });

  testWidgets('picking Month narrows the list to this month', (tester) async {
    await _openHistory(tester);
    await tester.tap(_chip('Month'));
    await tester.pumpAndSettle();
    expect(_row('ThisMonth'), findsOneWidget);
    expect(_row('LastMonth'), findsNothing);
    expect(_row('LastYear'), findsNothing);
  });

  testWidgets('picking Year keeps this year and drops the one before', (
    tester,
  ) async {
    await _openHistory(tester);
    await tester.tap(_chip('Year'));
    await tester.pumpAndSettle();
    expect(_row('ThisMonth'), findsOneWidget);
    expect(_row('LastMonth'), findsOneWidget);
    expect(_row('LastYear'), findsNothing);
  });

  testWidgets('the two chip rows do not both say All', (tester) async {
    // Looking at the render caught this: the period row and the type filter
    // row sat stacked, both leading with an orange chip called All, and
    // nothing on screen said which one did what. Exactly one chip may carry
    // the bare word.
    await _openHistory(tester);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('All time'), findsOneWidget);
  });

  testWidgets('going back to All brings every entry back', (tester) async {
    // A filter that cannot be fully undone is a filter that loses data as far
    // as the person using it is concerned.
    await _openHistory(tester);
    await tester.tap(_chip('Month'));
    await tester.pumpAndSettle();
    expect(_row('LastYear'), findsNothing);
    await tester.tap(_chip('All time'));
    await tester.pumpAndSettle();
    expect(_row('ThisMonth'), findsOneWidget);
    expect(_row('LastMonth'), findsOneWidget);
    expect(_row('LastYear'), findsOneWidget);
  });

  testWidgets('stepping back a month shows that month, and its name', (
    tester,
  ) async {
    await _openHistory(tester);
    await tester.tap(_chip('Month'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('June 2026'), findsOneWidget);
    expect(_row('LastMonth'), findsOneWidget);
    expect(_row('ThisMonth'), findsNothing);
  });

  testWidgets('the forward step is dead at the current month', (tester) async {
    // Not hidden, dead. A control that vanishes at the edge of its range reads
    // as a bug, and its neighbour jumps sideways under the thumb reaching for
    // it.
    await _mountSelector(tester, Period.monthOf(_now()));
    expect(
      _stepButton(tester, Icons.chevron_right).onPressed,
      isNull,
      reason: 'no stepping into an empty future',
    );
    expect(_stepButton(tester, Icons.chevron_left).onPressed, isNotNull);
  });

  testWidgets('the forward step comes alive once you are in the past', (
    tester,
  ) async {
    // The half that proves the guard is a guard and not just an off switch.
    await _mountSelector(tester, const Period.month('2026-06'));
    expect(_stepButton(tester, Icons.chevron_right).onPressed, isNotNull);
  });

  testWidgets('Custom opens showing everything, not nothing', (tester) async {
    // Opening the custom range at today would hide every entry the instant the
    // chip is tapped, which reads as the app having lost them.
    await _openHistory(tester);
    await tester.tap(_chip('Custom'));
    await tester.pumpAndSettle();
    expect(_row('ThisMonth'), findsOneWidget);
    expect(_row('LastMonth'), findsOneWidget);
    expect(_row('LastYear'), findsOneWidget);
    expect(find.textContaining('From: the start'), findsOneWidget);
    expect(find.textContaining('To: the end'), findsOneWidget);
  });

  testWidgets('an open custom end is named, not left blank', (tester) async {
    // A blank field reads as an incomplete form. Leaving an end open is a
    // choice, and the control has to say which choice it is.
    await _mountSelector(tester, const Period.custom(from: '2026-06-01'));
    expect(find.text('2026-06-01'), findsOneWidget);
    expect(find.textContaining('To: the end'), findsOneWidget);
  });

  testWidgets('switching mode twice does not stack periods', (tester) async {
    // Tapping the chip you are already on must be a no-op, or every rebuild
    // resets a month you deliberately stepped back to.
    final emitted = await _mountSelector(tester, const Period.month('2026-06'));
    await tester.tap(_chip('Month'));
    await tester.pumpAndSettle();
    expect(emitted, isEmpty, reason: 'tapping the current mode changed it');
  });

  testWidgets('Show all clears the PERIOD too, not just the other two', (
    tester,
  ) async {
    // QA: the one control that promises to put everything back left the
    // period untouched. Step back to an empty month, tap Show all, and the
    // list is still empty with the month chip still set, while the sentence
    // beside the button says the entries are just hidden. That reads as a lie
    // to someone who has just done what it told them.
    await _openHistory(tester);
    await tester.tap(_chip('Month'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pumpAndSettle();
    }
    expect(find.text('No entries match'), findsOneWidget);

    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(_row('ThisMonth'), findsOneWidget);
    expect(_row('LastMonth'), findsOneWidget);
    expect(_row('LastYear'), findsOneWidget);
  });

  testWidgets('a backwards custom range is swapped, not left showing nothing', (
    tester,
  ) async {
    // QA: picking the To end first and then a later From is a natural order,
    // and it produced a range matching nothing with no hint the ends were
    // inverted. Two dates describe exactly one range.
    final emitted = await _mountSelector(tester, const Period.custom());
    await tester.tap(find.textContaining('To: the end'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('From:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('25'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final p = emitted.last;
    expect(
      p.from!.compareTo(p.to!) <= 0,
      isTrue,
      reason: 'from ${p.from} is after to ${p.to}, so nothing can match',
    );
  });

  testWidgets('the clear X is a real tap target, not a 16dp dot', (
    tester,
  ) async {
    // QA measured 16x16. Missing it by a few pixels hit the button behind and
    // opened a full screen calendar, so the cost of a miss was far worse than
    // the cost of the tap.
    await _mountSelector(tester, const Period.custom(from: '2026-06-01'));
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the stepper can reach an entry dated in the future', (
    tester,
  ) async {
    // QA: a CSV imported with the day and month the wrong way round throws
    // rows into the future. They show under All time, and the forward arrow
    // refused to walk to them, so the stepper physically could not reach data
    // the person really had.
    await _openHistory(tester);
    // Month first: the stepper only exists in a stepping mode.
    await tester.tap(_chip('Month'));
    await tester.pumpAndSettle();
    expect(
      _stepButton(tester, Icons.chevron_right).onPressed,
      isNull,
      reason: 'nothing ahead, so the stop stays',
    );

    SharedPreferences.setMockInitialValues({
      storageKey: jsonEncode({
        ..._blob(),
        'transactions': [
          {
            'id': 'ahead',
            'type': 'expense',
            'label': 'Ahead',
            'amount': 10,
            'date': '2026-12-07',
          },
        ],
      }),
    });
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryScreen(store: store, clock: _now),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(_chip('Month'));
    await tester.pumpAndSettle();
    expect(
      _stepButton(tester, Icons.chevron_right).onPressed,
      isNotNull,
      reason: 'there is data ahead, so the stop moves out to it',
    );
  });

  testWidgets('the date picker opens on a phone whose clock is in 1970', (
    tester,
  ) async {
    // Session 15: the picker clamp SHIPPED WITH NO TEST. Deleting it left all
    // 982 tests green, so a future tidy-up could have quietly reintroduced the
    // crash. An Android with a dead RTC boots at 1970, and the fix has to hold
    // for a clock the person never set.
    //
    // Same bug already has a guard one screen over, at
    // test/edit_entry_test.dart, which is what makes leaving this one
    // unguarded worse than an oversight: the lesson was already written down.
    final emitted = <Period>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PeriodSelector(
              period: emitted.isEmpty ? const Period.custom() : emitted.last,
              allowAll: true,
              clock: () => DateTime(1970, 1, 1),
              onChange: (p) => setState(() => emitted.add(p)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('From: the start'));
    await tester.pumpAndSettle();
    // It opened at all. Before the clamp this threw
    // "lastDate must be on or after firstDate" out of showDatePicker.
    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the period and the text filter both apply', (tester) async {
    // Two filters that silently replace each other is the bug worth guarding:
    // the person narrows by month, types a word, and gets rows from outside
    // the month they chose.
    await _openHistory(tester);
    await tester.tap(_chip('Year'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'LastMonth');
    await tester.pumpAndSettle();
    expect(_row('LastMonth'), findsOneWidget);
    expect(_row('ThisMonth'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'LastYear');
    await tester.pumpAndSettle();
    expect(
      _row('LastYear'),
      findsNothing,
      reason: 'a text match from outside the chosen year must stay excluded',
    );
  });
}
