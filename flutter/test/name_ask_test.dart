// The name ask must never get in the way, and must never become a nag.
//
// The whole design rests on the app being completely usable without a name,
// so the paths worth pinning are the ones where it could quietly stop being
// optional: an ask that reappears after being answered, an ask that survives
// onto a screen with real data, or a Menu row that cannot take a name back.
//
// The greeting itself is pinned in greeting_test.dart; this file is about the
// screens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/menu.dart';
import 'package:salapify/screens/overview.dart';
import 'package:salapify/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _fresh() async {
  SharedPreferences.setMockInitialValues({});
  final store = SalapifyStore();
  await store.load();
  return store;
}

/// Mounted the way main.dart mounts it, wrapped in a ListenableBuilder on the
/// store. Without that wrapper OverviewScreen (a StatelessWidget) never
/// rebuilds on a store change, and the test would report a stale screen as a
/// bug in the screen rather than as a bug in how the test built it.
Widget _home(SalapifyStore store) => ListenableBuilder(
  listenable: store,
  builder: (context, _) => MaterialApp(
    theme: salapifyTheme(Barako.current),
    home: OverviewScreen(store: store, onSwitchTab: (_) {}),
  ),
);

void main() {
  group('on Home', () {
    testWidgets('a new user is asked, once, inside the welcome card', (
      tester,
    ) async {
      final store = await _fresh();
      await tester.pumpWidget(_home(store));
      await tester.pumpAndSettle();
      expect(find.text('What should Pan call you?'), findsOneWidget);
    });

    testWidgets('the greeting reads cleanly before any name is given', (
      tester,
    ) async {
      final store = await _fresh();
      await tester.pumpWidget(_home(store));
      await tester.pumpAndSettle();
      // Whichever part of day the suite runs in, it must be a whole greeting
      // with nothing dangling off the end.
      final greeting = find.textContaining('Good ');
      expect(greeting, findsWidgets);
      final text = tester.widget<Text>(greeting.first).data!;
      expect(
        text.endsWith(','),
        isFalse,
        reason: 'the nameless greeting ended in a dangling comma: "$text"',
      );
    });

    testWidgets('answering it makes it go away and greets by name', (
      tester,
    ) async {
      final store = await _fresh();
      await tester.pumpWidget(_home(store));
      await tester.pumpAndSettle();

      // The ask sits below the three lanes, so it can be off the fold on a
      // small screen. Scroll to it the way a person would rather than tapping
      // at coordinates nobody can reach.
      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Ana');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text('What should Pan call you?'),
        findsNothing,
        reason:
            'The ask survived being answered. A question that keeps asking '
            'after you have answered it is the definition of a nag.',
      );
      expect(find.textContaining('Ana'), findsWidgets);
    });

    testWidgets('tapping Save on an empty field stores nothing', (
      tester,
    ) async {
      // The realistic misfire: someone taps the button to dismiss the row.
      // It must not store a blank name, because a blank that is not null is
      // a value every future reader has to remember to treat as absent.
      final store = await _fresh();
      await tester.pumpWidget(_home(store));
      await tester.pumpAndSettle();

      final save = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(store.displayName, isNull);
      expect(
        ((store.data['settings'] as Map?) ?? const {}).containsKey(
          'displayName',
        ),
        isFalse,
      );
    });

    testWidgets('a user with data is never asked', (tester) async {
      // The welcome card is gone once there is anything to show, and the ask
      // must go with it rather than following the user around.
      final store = await _fresh();
      await store.addEntry({
        'type': 'expense',
        'amount': 120.0,
        'category': 'Food',
        'date': DateTime.now().toIso8601String(),
      });
      await tester.pumpWidget(_home(store));
      await tester.pumpAndSettle();
      expect(find.text('What should Pan call you?'), findsNothing);
    });
  });

  group('in Menu', () {
    testWidgets('someone who skipped can still set a name later', (
      tester,
    ) async {
      // Without this row, skipping once on Home would mean never being able
      // to change your mind, because the welcome card never comes back.
      final store = await _fresh();
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to the BUTTON, not to the label above it. The name card puts
      // its actions on a line BELOW the text, so scrolling the label into view
      // says nothing about whether the button came with it, and a taller
      // section kicker was enough to leave it just off-screen.
      final set = find.widgetWithText(TextButton, 'Set');
      await tester.scrollUntilVisible(set, 300);
      await tester.pumpAndSettle();
      await tester.tap(set);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Ana');
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(store.displayName, 'Ana');
    });

    testWidgets('a name can be taken back, and taking it back clears the key', (
      tester,
    ) async {
      final store = await _fresh();
      await store.setDisplayName('Ana');
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final remove = find.widgetWithText(TextButton, 'Remove');
      await tester.scrollUntilVisible(remove, 300);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();

      expect(store.displayName, isNull);
      expect(
        ((store.data['settings'] as Map?) ?? const {}).containsKey(
          'displayName',
        ),
        isFalse,
        reason: 'Remove left an empty string behind instead of clearing',
      );
    });

    testWidgets('cancelling the dialog changes nothing', (tester) async {
      final store = await _fresh();
      await store.setDisplayName('Ana');
      await tester.pumpWidget(
        MaterialApp(
          theme: salapifyTheme(Barako.current),
          home: MenuScreen(store: store, onSwitchTab: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      final change = find.widgetWithText(TextButton, 'Change');
      await tester.scrollUntilVisible(change, 300);
      await tester.pumpAndSettle();
      await tester.tap(change);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Bea');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(
        store.displayName,
        'Ana',
        reason: 'Cancel saved the typed text anyway',
      );
    });
  });
}
