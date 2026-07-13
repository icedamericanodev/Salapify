// Smoke test: the preview app renders the brand and the update stamp. The
// stamp matters because it is how the founder verifies which build arrived,
// so a build where it silently vanished must fail CI.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';

void main() {
  testWidgets('preview home shows the brand and the update stamp',
      (tester) async {
    await tester.pumpWidget(const SalapifyApp());
    expect(find.text('SALAPIFY'), findsOneWidget);
    expect(find.text('Update stamp'), findsOneWidget);
    expect(find.textContaining('f0.'), findsOneWidget);
  });
}
