import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart';

/// Claims the app makes about itself, checked against what it actually does.
///
/// This file exists because "Offline Only" sat beside the wordmark, under a
/// shield, for weeks after `fx_service.dart` started asking a public rate
/// service for today's rates. Nothing could see it: 723 tests passed, the
/// renders looked right, and the sentence was simply false. A claim is not
/// code, so no ordinary test reaches it, and the only thing that can is a test
/// written about the claim itself.
///
/// Founder direction, 2026-09-19: change the badge, keep the converter.
void main() {
  testWidgets('the header claims what is true, and nothing absolute', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    expect(find.text('On this phone'), findsOneWidget);

    // The other half, and the half that matters. An absolute claim is false
    // the moment ONE request exists, and one does.
    for (final String banned in <String>[
      'Offline Only',
      'Offline only',
      '100% Offline',
      '100% offline',
      'No internet',
      'Zero network',
    ]) {
      expect(
        find.text(banned),
        findsNothing,
        reason:
            '"$banned" is an absolute claim, and fx_service.dart makes a '
            'request. Play\'s deceptive behavior policy and PH consumer law '
            'both bite on a false claim about what a product does.',
      );
    }
  });

  testWidgets('the badge opens the receipt that backs it up', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SalapifyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('On this phone'));
    await tester.pumpAndSettle();

    expect(find.text('What stays on this phone'), findsOneWidget);
    expect(
      find.textContaining('One thing does leave this phone'),
      findsOneWidget,
      reason:
          'the receipt omits the exchange rate request, which is the one line '
          'item a receipt exists to disclose',
    );
    expect(
      find.textContaining('not encrypted'),
      findsOneWidget,
      reason:
          'a person emailing themselves a backup they believe is protected is '
          'the harm a false security claim causes',
    );
  });

  test('no source file promises an encrypted backup', () {
    // The prototype's knowledge base tells people they "can export an
    // encrypted JSON backup file". The export is JsonEncoder.withIndent, which
    // is plain readable text. This is the guard against that string being
    // carried over with Pan, which is the next thing to port.
    //
    // COMMENTS ARE STRIPPED FIRST, and that is not a loophole, it is the only
    // way the rule can be written down. The first version of this test failed
    // on privacy_sheet.dart, whose doc comment lists these exact phrases as
    // the ones that may never ship. A guard that forbids naming the thing it
    // guards against gets deleted by the next person who trips over it, and
    // then it is not there for the real string. What ships to a person is a
    // string literal, so that is what is checked.
    final List<String> offenders = <String>[];
    for (final FileSystemEntity f in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final String text = f
          .readAsLinesSync()
          .where((String line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final String claim in <String>[
        'encrypted backup',
        'encrypted JSON',
        'bank grade',
        'bank-grade',
        'military grade',
        'military-grade',
      ]) {
        if (text.toLowerCase().contains(claim.toLowerCase())) {
          offenders.add('${f.path}: $claim');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Salapify claims a protection it does not have. The backup is '
          'plain readable JSON.',
    );
  });
}
