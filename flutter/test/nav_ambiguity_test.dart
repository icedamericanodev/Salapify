// The assumption the whole tab refactor rests on, pinned.
//
// Moving the five destinations into an IndexedStack means they are all MOUNTED
// at once. The obvious worry is that the test suite then sees five screens
// where it used to see one: `find.text('Insights')` matching both the nav label
// and the mounted Insights header, and `find.byType(Scrollable).first`
// resolving to Home no matter which screen a test meant. The second failure
// mode is the frightening one, because a test that scrolls the wrong screen
// does not say so. It says "not found", which is a true statement about a
// screen the user is not even looking at.
//
// That worry is WRONG on Flutter 3.44.6, and this test is here to say so with
// evidence rather than with confidence. IndexedStack does not rely on Offstage
// or on Visibility to keep its inactive children out of finders. It ships a
// dedicated element that overrides the onstage walk:
//
//     class _IndexedStackElement extends MultiChildRenderObjectElement {
//       @override
//       void debugVisitOnstageChildren(ElementVisitor visitor) {
//         final int? index = widget.index;
//         // If the index is null, no child is onstage. Otherwise, only the
//         // child at the selected index is.
//         if (index != null && children.isNotEmpty) {
//           visitor(children.elementAt(index));
//         }
//       }
//     }
//
// Every finder defaults to skipOffstage: true, which walks exactly that. So an
// inactive destination is invisible to the suite, and the existing tests keep
// meaning what they say.
//
// This file exists because that is a load-bearing assumption imported from the
// SDK rather than owned by this app. If a future Flutter release changes it,
// dozens of tests start silently targeting the wrong screen, and the failures
// will point everywhere except at the cause. This test fails first, and names
// it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Two panes that both contain the same word, the way a nav label and a screen
/// header both say "Insights" in the real app.
Widget _stack(int index) => MaterialApp(
  home: Scaffold(
    body: IndexedStack(
      index: index,
      children: [
        ListView(
          key: const Key('first'),
          children: const [Text('Reports'), SizedBox(height: 2000)],
        ),
        ListView(
          key: const Key('second'),
          children: const [Text('Reports'), SizedBox(height: 2000)],
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('an inactive IndexedStack child is invisible to finders', (
    tester,
  ) async {
    await tester.pumpWidget(_stack(0));
    await tester.pumpAndSettle();

    expect(
      find.text('Reports'),
      findsOneWidget,
      reason:
          'Both panes contain this text and both are mounted, yet only the '
          'showing one matched. If this ever finds two, every test in this '
          'suite that reaches for a word the app uses on more than one screen '
          'becomes ambiguous, and tap() starts throwing on "found 2 widgets".',
    );
  });

  testWidgets('an unscoped scrollable finder still picks the visible pane', (
    tester,
  ) async {
    // Pane 1 is showing; pane 0 is first in the tree and still mounted. The
    // question is which one `.first` picks, because 27 tests in this suite
    // depend on the answer.
    await tester.pumpWidget(_stack(1));
    await tester.pumpAndSettle();

    expect(
      find.byType(Scrollable),
      findsOneWidget,
      reason:
          'The hidden pane\'s ListView is mounted but must not be collected. '
          'If it is, find.byType(Scrollable).first silently returns the WRONG '
          'screen and every scrollUntilVisible in the suite starts scrolling '
          'something the user cannot see, reporting "not found" about it.',
    );

    final picked = tester.widget<Scrollable>(find.byType(Scrollable).first);
    final visible = tester.widget<Scrollable>(
      find
          .descendant(
            of: find.byKey(const Key('second')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(identical(picked, visible), isTrue);
  });

  testWidgets('and it really is the index that decides, not the order', (
    tester,
  ) async {
    // The half that keeps the two tests above honest. If finders were simply
    // returning the first child regardless, both would pass for the wrong
    // reason. Flipping the index must flip which pane is found.
    await tester.pumpWidget(_stack(0));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('first')),
        matching: find.text('Reports'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(_stack(1));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('first')),
        matching: find.text('Reports'),
      ),
      findsNothing,
      reason:
          'Pane 0 is now hidden and must have dropped out of the finder. If '
          'it did not, the two tests above are passing by accident.',
    );
  });
}
