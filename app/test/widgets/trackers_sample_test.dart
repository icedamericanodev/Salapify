import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/state/financial_state.dart';

import '../support/pinned_app.dart';

/// P1.3: the Trackers segment stops showing a stranger's Netflix bill once the
/// demo money is gone.
///
/// ## The defect
///
/// From the October expert review's guardrails: "Habits and Subscriptions
/// always show sample Netflix data, even after sample data is removed."
///
/// They were read as compile-time constants straight off `SeedData`, so
/// "Delete the sample data" cleared eleven accounts, a housing loan and a whole
/// ledger, and left Netflix and a gym streak sitting there. Somebody who has
/// just wiped a stranger's money off their phone and still sees a stranger's
/// Netflix bill has every reason to think the wipe did not work, which is the
/// worst thing a wipe can do.
///
/// ## Why this file drives the STORE and not the screen
///
/// `plan_test.dart` already walks to the Trackers segment and reads it, so the
/// rendering is covered there. What is worth its own file is the RULE: the
/// gate is `hasSampleData`, which is derived from the isSample flag on real
/// stored records rather than from anything this screen knows. These assert
/// the gate flips, and the screen test asserts it is read.
void main() {
  test('removing the sample data flips the gate the Trackers card reads', () {
    final FinancialState s = FinancialState(clock: testToday);
    expect(
      s.hasSampleData,
      isTrue,
      reason: 'a fresh store should carry the demo ledger',
    );

    s.removeSampleData();

    expect(
      s.hasSampleData,
      isFalse,
      reason: 'the sweep left something flagged as sample behind',
    );
  });

  test('and putting it back flips it again, so the card can return', () {
    // The other half. A gate that only ever closes would leave somebody who
    // restored the demo looking at two cards claiming nothing is built.
    final FinancialState s = FinancialState(clock: testToday);
    s.removeSampleData();
    expect(s.hasSampleData, isFalse);

    s.restoreSampleData();

    expect(s.hasSampleData, isTrue);
  });

  testWidgets('the screen stops showing Netflix once the demo is gone', (
    WidgetTester tester,
  ) async {
    // The half the store test cannot reach. A gate that flips correctly and is
    // never read is the same defect with extra steps, and that is exactly what
    // this screen had: the records were right and the widget ignored them.
    final FinancialState state = await pumpSalapify(tester);

    await tester.tap(find.byIcon(Icons.track_changes_outlined));
    await tester.pumpAndSettle();

    // ensureVisible before the tap, the way plan_test.dart drives this hub.
    // The tiles sit in a scroll view and a bare tap lands nowhere, which
    // `tester.tap` only WARNS about rather than failing on.
    final Finder tile = find.text('Trackers');
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    // The subscriptions card is below the habits card, so it has to be
    // scrolled to before its rows are built.
    await tester.scrollUntilVisible(
      find.textContaining('Netflix'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Netflix'),
      findsWidgets,
      reason: 'the demo plans should be here while the demo money is',
    );

    state.removeSampleData();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Netflix'),
      findsNothing,
      reason: 'a stranger\'s Netflix bill survived the wipe',
    );
    expect(find.textContaining('not built yet'), findsWidgets);
  });
}
