// Ask Pan wears Pan's own face (founder request 2026-10-08), and a screen
// reader still hears what the button does rather than a picture of him.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/pan_art.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/screens/home/ask_pan_button.dart';

void main() {
  testWidgets('the Ask Pan button shows Pan and keeps its label', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AskPanButton(palette: Palette.gabi, onTap: () {}),
          ),
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(AskPanButton),
        matching: find.byType(PanAvatar),
      ),
      findsOneWidget,
      reason: 'Ask Pan lost Pan',
    );
    expect(
      // Starts with, because the visible "Ask Pan" text merges in after it.
      find.bySemanticsLabel(RegExp('^Ask Pan, the money assistant')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
