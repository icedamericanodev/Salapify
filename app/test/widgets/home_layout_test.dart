import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/home/debt_beam_card.dart';

/// Layout guards for Home.
///
/// These exist because two separate widgets rendered at ZERO height while the
/// screen around them looked finished, and no assertion about text could see
/// it. Both had the same cause: a box with no intrinsic size handed loose
/// constraints by its parent.
void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();
  }

  testWidgets('the debt beam is actually drawn, not collapsed to nothing', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    await tester.scrollUntilVisible(find.byKey(debtBeamKey), 200);
    await tester.pumpAndSettle();

    final Size beam = tester.getSize(find.byKey(debtBeamKey));
    expect(
      beam.height,
      greaterThanOrEqualTo(4),
      reason: 'the debt beam collapsed, so the card shows no bar at all',
    );
    expect(beam.width, greaterThan(100));

    // Both halves must have real width, or the split is a lie: one side
    // filling the whole bar looks exactly like a correct bar for the other.
    final Finder halves = find.descendant(
      of: find.byKey(debtBeamKey),
      matching: find.byType(ColoredBox),
    );
    expect(halves, findsNWidgets(2), reason: 'the beam should have two halves');

    for (int i = 0; i < 2; i++) {
      final Size half = tester.getSize(halves.at(i));
      expect(half.height, greaterThanOrEqualTo(4));
      expect(half.width, greaterThan(0));
    }
  });

  testWidgets('the tab bar leaves the body real height', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    final Size listView = tester.getSize(find.byType(ListView).first);
    expect(
      listView.height,
      greaterThan(200),
      reason: 'the bottom bar swallowed the screen again',
    );
  });

  testWidgets('nothing on Home overflows its width at 320dp', (
    WidgetTester tester,
  ) async {
    // 320 logical pixels is the narrowest phone worth supporting.
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpHome(tester);

    // A RenderFlex overflow reports through the exception channel, so a clean
    // pump is the assertion.
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Reminders card never truncates its own name', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    final Finder title = find.text('Reminders');
    await tester.scrollUntilVisible(title, 200);
    await tester.pumpAndSettle();

    // Present in full. When it was a Row, the title lost the fight with the
    // tag beside it and the card read "Reminders & ..." instead.
    expect(title, findsOneWidget);
    final Text widget = tester.widget<Text>(title);
    expect(widget.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('and it no longer calls itself a simulator', (
    WidgetTester tester,
  ) async {
    // The tag was honest while nothing behind the card worked. Something does
    // now, so the tag would be the lie instead. This asserts the swap
    // happened rather than the label merely being restyled.
    await pumpHome(tester);

    expect(find.text('SIMULATOR'), findsNothing);
    expect(find.text('Test Alerts'), findsNothing);
  });
}
