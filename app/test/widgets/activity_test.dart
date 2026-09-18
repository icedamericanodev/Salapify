import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/activity/activity_screen.dart';
import 'package:salapify/screens/activity/transaction_detail_sheet.dart';

import '../shots/screens_shot.dart' show loadRealFonts;

/// Activity, driven the way a person drives it: tap the tab, type in the
/// search box, tap a row.
void main() {
  Future<void> openActivity(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
  }

  testWidgets('the Activity tab opens and lists entries', (
    WidgetTester tester,
  ) async {
    await openActivity(tester);

    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(find.text('WHAT MOVED'), findsOneWidget);
    // A real entry from the fixture, so this fails if the list renders empty.
    expect(find.text('Local Kape Shop'), findsOneWidget);
  });

  testWidgets('an excluded entry is shown, struck through, and not counted', (
    WidgetTester tester,
  ) async {
    await openActivity(tester);

    // Two Meralco rows exist on the same day, one excluded. Both must be
    // VISIBLE, because hiding an excluded row is how somebody reconciling
    // against a statement concludes the app lost an entry.
    await tester.scrollUntilVisible(
      find.text('EXCLUDED'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('EXCLUDED'), findsOneWidget);
    expect(find.text('Meralco'), findsNWidgets(2));

    // And the day header counts ONE of them. This is the assertion that would
    // fail if excluded money leaked back into a total.
    expect(
      find.text('Out: ₱2,840.00'),
      findsOneWidget,
      reason: 'the day header should count one Meralco charge, not both',
    );
  });

  testWidgets('tapping an entry opens its detail', (WidgetTester tester) async {
    await openActivity(tester);

    // Scrolled into view first. The summary card and filters fill the 800x600
    // test viewport, so the first entry sits under the tab bar here even
    // though it is plainly visible on a phone.
    await tester.ensureVisible(find.text('Local Kape Shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local Kape Shop'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionDetailSheet), findsOneWidget);
    // The fields a person opened it for.
    expect(find.text('Category'), findsOneWidget);
    expect(find.text('Cash on Hand (Pitaka)'), findsWidgets);
  });

  testWidgets('the detail of an excluded entry says why it is not counted', (
    WidgetTester tester,
  ) async {
    await openActivity(tester);

    await tester.scrollUntilVisible(
      find.text('EXCLUDED'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('EXCLUDED'));
    await tester.pumpAndSettle();

    expect(find.byType(TransactionDetailSheet), findsOneWidget);
    expect(
      find.textContaining('not counted in your totals'),
      findsOneWidget,
      reason: 'a struck-through figure alone does not explain itself',
    );
  });

  testWidgets('search narrows the list and says how many matched', (
    WidgetTester tester,
  ) async {
    await openActivity(tester);

    await tester.enterText(find.byType(TextField).first, 'jollibee');
    await tester.pumpAndSettle();

    expect(find.text('Jollibee'), findsOneWidget);
    expect(find.text('Local Kape Shop'), findsNothing);
    expect(find.textContaining('Showing 1 of'), findsOneWidget);
  });

  testWidgets(
    'a search that matches nothing says so rather than looking empty',
    (WidgetTester tester) async {
      await openActivity(tester);

      await tester.enterText(find.byType(TextField).first, 'zzzzz');
      await tester.pumpAndSettle();

      // Two different sentences, deliberately: the line under the search box
      // counts the matches, and the empty card explains. Matching loosely on
      // "Nothing matches" finds both, so each is named.
      expect(find.textContaining('Try part of a name'), findsOneWidget);
      expect(find.text('Nothing matches these filters'), findsOneWidget);
      // The empty state must know a filter is on. "No entries yet" here would
      // be a lie that sends somebody hunting for a bug instead of a filter.
      expect(find.text('No entries yet'), findsNothing);
    },
  );

  testWidgets('searching by amount finds the row', (WidgetTester tester) async {
    await openActivity(tester);

    // The centavo shape, which is the one that needed JavaScript's number
    // formatting reproduced rather than assumed.
    await tester.enterText(find.byType(TextField).first, '3,250.75');
    await tester.pumpAndSettle();

    expect(find.text('S&R Membership Shopping'), findsOneWidget);
  });

  testWidgets('nothing on Activity overflows at 320dp', (
    WidgetTester tester,
  ) async {
    // Real fonts: the default test font is wider than Plus Jakarta, so
    // measuring layout without it answers a different question.
    await tester.runAsync(loadRealFonts);
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openActivity(tester);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Local Kape Shop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local Kape Shop'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('every filter and tab clears the 44dp floor', (
    WidgetTester tester,
  ) async {
    await openActivity(tester);

    final Finder taps = find.descendant(
      of: find.byType(ActivityScreen),
      matching: find.byType(InkWell),
    );
    expect(taps, findsWidgets);

    for (int i = 0; i < taps.evaluate().length; i++) {
      final Size size = tester.getSize(taps.at(i));
      // Rows are wide and tall by nature; the chips and tabs are the ones
      // that can shrink under a short label.
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason: 'a control on Activity is only ${size.height} tall',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(44),
        reason: 'a control on Activity is only ${size.width} wide',
      );
    }
  });
}
