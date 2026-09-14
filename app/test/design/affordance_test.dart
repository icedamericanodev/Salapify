// A row that leads somewhere has to LOOK like it leads somewhere.
//
// The founder opened the Ledger, found a transaction they wanted to correct,
// and asked: "how will the user know if they can edit or do something on this
// transaction, if there is no edit button?" The rows were tappable. Nothing on
// the screen said so, because the widget's own doc comment had argued a marker
// was unnecessary in a list where every row leads somewhere. That reasoning
// reads fine to whoever wrote the list and is invisible to whoever opens it.
//
// This file guards the answer: the chevron appears when, and only when, a row
// has somewhere to go, and the Ledger says it in words as well.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/app/clock.dart';
import 'package:salapify/app/ledger_scope.dart';
import 'package:salapify/app/router.dart';
import 'package:salapify/core/data/ledger_store.dart';
import 'package:salapify/design/kit.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/dev/sample_ledger.dart';

import '../support/memory_store.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: salapifyTheme(gabi),
  home: Scaffold(body: Center(child: Group(children: [child]))),
);

Widget _app(LedgerStore store) => LedgerScope(
  store: store,
  child: AppClock(
    now: sampleAnchor,
    child: MaterialApp.router(
      theme: salapifyTheme(gabi),
      routerConfig: buildRouter(),
    ),
  ),
);

Finder get _chevron => find.byWidgetPredicate(
  (w) => w is Icon && w.icon == Icons.chevron_right_rounded,
);

void main() {
  testWidgets('a row that goes somewhere shows a chevron', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ItemRow(
          title: 'Jollibee',
          amount: '-250.00',
          onTap: () {},
        ),
      ),
    );

    expect(
      _chevron,
      findsOneWidget,
      reason:
          'a tappable row drew no marker at all, which is the exact defect '
          'the founder found on the Ledger',
    );
  });

  testWidgets('a row that goes nowhere does NOT', (tester) async {
    // The other half, and the half that makes the first one mean anything. A
    // chevron on every row regardless would pass the test above while telling
    // the user nothing, because a mark that is always there distinguishes
    // nothing.
    await tester.pumpWidget(
      _wrap(const ItemRow(title: 'Opening balance', amount: '12,000.00')),
    );

    expect(
      _chevron,
      findsNothing,
      reason:
          'a row with nowhere to go promised somewhere to go, which is worse '
          'than no marker: it is a wrong one',
    );
  });

  testWidgets('holding a tappable row dims it', (tester) async {
    // Discovery is the chevron. This is confirmation: a press that is about to
    // open something must feel different from a press on dead pixels.
    await tester.pumpWidget(
      _wrap(ItemRow(title: 'Jollibee', amount: '-250.00', onTap: () {})),
    );

    double opacity() => tester
        .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
        .opacity;

    expect(opacity(), 1.0);

    final down = await tester.startGesture(
      tester.getCenter(find.text('Jollibee')),
    );
    await tester.pump();
    expect(
      opacity(),
      lessThan(1.0),
      reason: 'the row gave no feedback while it was being held',
    );

    await down.up();
    await tester.pumpAndSettle();
    expect(opacity(), 1.0);
  });

  testWidgets('the Ledger says in words that an entry can be edited', (
    tester,
  ) async {
    // The chevron teaches somebody already hunting for a control. The sentence
    // reaches the person who never thought to hunt, which is the person who
    // asked the question.
    final store = await memoryStore(livedIn());
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(NavBar), matching: find.text('Ledger')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Tap any entry to edit'),
      findsOneWidget,
      reason:
          'the screen offered editing and delete but never said so anywhere a '
          'first time user would read it',
    );
  });
}
