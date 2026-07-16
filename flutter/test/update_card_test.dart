// The update card: renders the stamp, and in an environment without the
// Shorebird engine (tests, debug builds) the check button reports honestly
// instead of crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';
import 'package:salapify/screens/update_card.dart';
import 'package:salapify/theme.dart';

void main() {
  testWidgets('shows the stamp and reports when updates are unavailable',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: barakoDarkTheme(),
      home: const Scaffold(body: UpdateCard()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining(updateStamp), findsOneWidget);
    expect(find.text('Check for update'), findsOneWidget);

    await tester.tap(find.text('Check for update'));
    await tester.pumpAndSettle();
    expect(find.text('Automatic updates are not active in this build.'),
        findsOneWidget);
  });
}
