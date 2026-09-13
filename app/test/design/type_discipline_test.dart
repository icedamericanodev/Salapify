// One design hand, enforced by reading the source rather than by asking.
//
// Principle 3 in 01-vision.md: "One accent colour, one type family, one card
// shape, one list physics. If two screens show a peso amount differently, that
// is a bug." The old app is what that principle is reacting to. This is the
// machine that keeps it true while nobody is watching.
//
// The rule: colours and text styles are DECIDED in lib/design and only there.
// A feature asks for TypeScale.rowTitle and context.skin.accent. It never
// spells out a hex value or a font size, because the moment one screen does,
// the next screen copies it slightly wrong and the app has two of everything.
//
// This is a source scan, not a widget test, so it covers every file including
// the ones nobody thought to render.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where a design decision is allowed to live.
const _designDir = 'lib/design';

/// Everything the rule applies to: the screens and the shell.
///
/// lib/core is deliberately NOT here. It is the money engine and the store,
/// ported byte for byte from the shipped app, and it draws nothing at all.
const _uiDirs = ['lib/features', 'lib/app'];

/// A banned shape, and the thing to write instead.
typedef Ban = (String, RegExp, String);

final _bans = <Ban>[
  (
    'a raw TextStyle',
    RegExp(r'\bTextStyle\s*\('),
    'use a role from TypeScale in lib/design/type.dart',
  ),
  (
    'a hard-coded font size',
    RegExp(r'\bfontSize\s*:'),
    'use a role from TypeScale in lib/design/type.dart',
  ),
  (
    'a hex colour literal',
    RegExp(r'\bColor\(0x'),
    'use a token from context.skin in lib/design/tokens.dart',
  ),
  (
    "one of Flutter's named colours",
    // Colors.transparent is genuinely not a colour decision, it is the absence
    // of one, so it is allowed. Anything else from that palette is Material
    // blue and grey walking into a warm orange app.
    RegExp(r'\bColors\.(?!transparent\b)\w+'),
    'use a token from context.skin in lib/design/tokens.dart',
  ),
  (
    'a Theme.of colour',
    // Reaching past the tokens into Material's own scheme gets a colour that
    // was never measured by palette_contrast_test.
    RegExp(r'Theme\.of\(\s*context\s*\)\.colorScheme'),
    'use a token from context.skin in lib/design/tokens.dart',
  ),
];

Iterable<File> _dartFilesIn(String dir) {
  final d = Directory(dir);
  if (!d.existsSync()) return const [];
  return d
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
}

void main() {
  test('the UI never decides a colour or a text style for itself', () {
    final offences = <String>[];

    for (final dir in _uiDirs) {
      for (final file in _dartFilesIn(dir)) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // A comment explaining the rule is not a breach of it.
          if (line.trimLeft().startsWith('//')) continue;
          for (final (what, pattern, instead) in _bans) {
            if (pattern.hasMatch(line)) {
              offences.add(
                '${file.path}:${i + 1} has $what. Instead, $instead.'
                '\n    ${line.trim()}',
              );
            }
          }
        }
      }
    }

    expect(
      offences,
      isEmpty,
      reason:
          'Design decisions belong in $_designDir and nowhere else:\n\n'
          '${offences.join('\n\n')}',
    );
  });

  test('the scan actually looked at the UI', () {
    // Without this the test above passes perfectly against a typo in a folder
    // name, which is exactly how a guard ends up guarding nothing.
    final counted = _uiDirs.expand(_dartFilesIn).length;
    expect(
      counted,
      greaterThanOrEqualTo(7),
      reason:
          'Only found $counted Dart files under $_uiDirs. Either the folders '
          'moved or this guard is scanning an empty tree.',
    );
  });

  test('the design folder is where the decisions actually are', () {
    // The mirror of the rule above: if lib/design contained no colour and no
    // TextStyle, the ban would be trivially satisfiable by having no design
    // system at all.
    final source = _dartFilesIn(
      _designDir,
    ).map((f) => f.readAsStringSync()).join('\n');
    expect(source, contains('Color(0x'), reason: 'no colours are defined');
    expect(source, contains('TextStyle('), reason: 'no type is defined');
  });
}
