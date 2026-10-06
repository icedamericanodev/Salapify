import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every workflow that builds `app/` must name the SAME Flutter version.
///
/// ## The specific failure this exists for
///
/// The publisher names the toolchain separately from the branch check. Bump
/// one and not the other and every check runs on one Flutter while the
/// artifact the founder installs is built on another. Nothing else in the
/// repository can notice: analyze passes, the tests pass, the publisher goes
/// green, a delivery row appears, and the app on the phone was compiled by a
/// toolchain nothing ever tested.
///
/// Salapify 2 earned this guard the hard way, repeating its version across
/// five files including twice inside one Shorebird argument.
///
/// ## Derived, not typed
///
/// The set of workflows and the expected version are both READ from the
/// files. A test holding a hand-written list of filenames passes happily
/// after somebody adds a sixth workflow, which is the one moment it was
/// supposed to speak up. A derived set is a rule; a typed set is a promise.
///
/// Rewritten for `app/` rather than copied from
/// `archive/salapify-2-flutter/test/toolchain_pin_test.dart`, which would be
/// red on this tree on day one: it asserts the projects are exactly
/// {'app', 'flutter'} and there is no live `flutter/` any more, and it demands
/// at least five pinned locations where this tree has three.
void main() {
  // Comments are stripped before anything is matched, and that is not
  // cosmetic. app-check.yml spends forty lines discussing 3.44.6 in prose, so
  // a matcher that cannot tell a value from a sentence about one reports the
  // wrong file with total confidence.
  String withoutComments(String yaml) => yaml
      .split('\n')
      .map((String line) {
        final int hash = line.indexOf('#');
        return hash == -1 ? line : line.substring(0, hash);
      })
      .join('\n');

  final RegExp pinPattern = RegExp(r"flutter-version:\s*'([^']+)'");
  final RegExp workDirPattern = RegExp(r'working-directory:\s*(\S+)');

  late Map<String, List<String>> pinsByFile;
  late Map<String, Set<String>> dirsByFile;

  setUpAll(() {
    final Directory dir = Directory('../.github/workflows');
    expect(
      dir.existsSync(),
      isTrue,
      reason:
          '../.github/workflows is missing, so this guard reads nothing. '
          'Point it at the new path rather than deleting it.',
    );

    pinsByFile = <String, List<String>>{};
    dirsByFile = <String, Set<String>>{};

    for (final File f in dir.listSync().whereType<File>().where(
      (File f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'),
    )) {
      final String name = f.uri.pathSegments.last;
      final String body = withoutComments(f.readAsStringSync());
      pinsByFile[name] = pinPattern
          .allMatches(body)
          .map((RegExpMatch m) => m.group(1)!)
          .toList();
      dirsByFile[name] = workDirPattern
          .allMatches(body)
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();
    }
  });

  /// A workflow belongs to `app/` when it works in `app` and nowhere else.
  /// `pages.yml` builds out of `archive/...` and legitimately pins a different,
  /// older Flutter, so it must NOT be dragged into this comparison.
  bool buildsTheLiveApp(String file) => dirsByFile[file]!.contains('app');

  test('the extractor actually found something', () {
    // The vacuous-pass guard. Every assertion below is trivially satisfied by
    // finding no workflows and no pins at all, which is exactly what a renamed
    // directory or a changed YAML style would produce.
    expect(pinsByFile.keys, isNotEmpty, reason: 'no workflow files read');
    final int total = pinsByFile.values.fold(
      0,
      (int a, List<String> b) => a + b.length,
    );
    expect(
      total,
      greaterThanOrEqualTo(3),
      reason:
          'only $total Flutter pins found across all workflows. There '
          'should be at least three: two in the branch check and one in the '
          'publisher. A smaller number means the matcher stopped matching, '
          'not that the pins went away.',
    );
  });

  test('every workflow that builds app/ names the same Flutter version', () {
    final Set<String> versions = <String>{};
    final Map<String, List<String>> offenders = <String, List<String>>{};

    for (final String file in pinsByFile.keys) {
      if (!buildsTheLiveApp(file)) continue;
      if (pinsByFile[file]!.isEmpty) continue;
      versions.addAll(pinsByFile[file]!);
      offenders[file] = pinsByFile[file]!;
    }

    expect(
      versions.length,
      1,
      reason:
          'the workflows that build app/ name ${versions.length} '
          'different Flutter versions: $versions, from $offenders. They must '
          'agree, or the app the founder installs is built on a toolchain '
          'that nothing tested.',
    );
  });

  test('the publisher is one of them, not an exception', () {
    // The directional half, and the one that matters most. The test above
    // passes perfectly when the publisher pins NOTHING at all, because an
    // empty list contributes no versions to disagree about. That is precisely
    // the shape of the bug: a publisher that silently picks whatever Flutter
    // the runner defaults to.
    final Iterable<String> appFiles = pinsByFile.keys.where(buildsTheLiveApp);
    expect(
      appFiles.length,
      greaterThanOrEqualTo(2),
      reason:
          'expected at least a branch check and a publisher building '
          'app/, found ${appFiles.length}: $appFiles',
    );
    for (final String file in appFiles) {
      expect(
        pinsByFile[file],
        isNotEmpty,
        reason:
            '$file builds app/ but pins no Flutter version, so it runs on '
            'whatever the runner happens to ship.',
      );
    }
  });

  test('the archive keeps its own, older pin', () {
    // Not a nice-to-have. Without this the obvious "fix" for a future
    // disagreement is to make every workflow match, which would quietly
    // rebuild the archived app on a toolchain it was never shipped with.
    for (final String file in pinsByFile.keys) {
      if (buildsTheLiveApp(file)) continue;
      if (pinsByFile[file]!.isEmpty) continue;
      final bool archiveOnly = dirsByFile[file]!.every(
        (String d) => d.startsWith('archive/'),
      );
      expect(
        archiveOnly,
        isTrue,
        reason:
            '$file pins Flutter but works in ${dirsByFile[file]}, which '
            'is neither app/ nor the archive. Decide which group it is in.',
      );
    }
  });
}
