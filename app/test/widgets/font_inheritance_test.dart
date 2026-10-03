import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// No screen builds a bare `RichText`.
///
/// This guard exists because of a defect that reached a founder screenshot on
/// the Accounts tab and was invisible to fifteen passing assertions about the
/// same screen.
///
/// `Text` resolves its style against `DefaultTextStyle`, so it picks up Plus
/// Jakarta Sans from the app theme. `RichText` does NOT: it renders exactly
/// the style it is handed, and every style in `AppType` deliberately leaves
/// `fontFamily` unset so the theme can supply it. The result is a line drawn
/// in the platform's default font instead of the app's, and in the render
/// harness, which loads only Salapify's own fonts, a row of empty boxes.
///
/// `Text.rich` takes the same `TextSpan` and inherits properly, so the fix is
/// always one word. Nothing is lost by banning the raw widget.
void main() {
  test('no file under lib/ constructs a bare RichText', () {
    final List<String> offenders = <String>[];

    for (final FileSystemEntity e in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final List<String> lines = e.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        // Only a CONSTRUCTOR CALL, so a comment or a doc string that merely
        // names the widget (this file's own explanation, for one) passes.
        if (RegExp(
          r'^\s*(return\s+|child:\s+|\w+:\s+)?RichText\(',
        ).hasMatch(line)) {
          offenders.add('${e.path}:${i + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'RichText does not inherit DefaultTextStyle, so these lines draw in '
          'the platform font rather than Plus Jakarta Sans, and render as '
          'empty boxes in the shot harness. Use Text.rich with the same '
          'TextSpan instead: ${offenders.join(', ')}',
    );
  });
}
