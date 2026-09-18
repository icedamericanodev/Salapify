// The Flutter pin is written in several workflow files, and only ONE property
// about it is load bearing: they must all say the same thing.
//
// The expensive version of getting this wrong is specific. flutter-preview.yml
// names the version TWICE, once in the setup step that installs the SDK the
// checks run on, and again as the `--flutter-version` argument to
// `shorebird release`, which decides the SDK the shipped app is actually built
// with. Bump the setup step and forget the Shorebird argument and every check
// runs on one toolchain while the founder's phone receives an app built on
// another. Nothing else in the repository would notice: analyze and test both
// pass, the publisher goes green, and a delivery row appears.
//
// Session 39 (docs/lunch-and-learn.md) is why this is a test and not a list.
// A hand counted inventory of where the version lives was written into
// docs/decision-log.md, was already missing two files when written, and was
// made false three hours later by a commit in the same session that removed the
// number from one of the places the list named. A derived set is a rule and a
// typed set is a promise, so this derives the set every run.
//
// The second half guards a sentence rather than a number. flutter/README.md
// once stated the SDK version in prose and went stale TWICE in one day, first
// when a newer SDK was installed to evaluate it and again when that SDK became
// the default. It now states the rule and names no version, and this keeps it
// that way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `flutter-version: '3.44.6'` in a setup step.
final _setupPin = RegExp(r"""flutter-version:\s*['"]?(\d+\.\d+\.\d+)['"]?""");

/// `--flutter-version 3.44.6` passed to a shorebird command.
final _argPin = RegExp(r'--flutter-version[=\s]+(\d+\.\d+\.\d+)');

void main() {
  test('every workflow pins the same Flutter version', () {
    final dir = Directory('../.github/workflows');
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'Cannot find ../.github/workflows from the flutter/ directory.',
    );

    // file path -> every version string that file names, with a label saying
    // which shape matched, so a failure points at the exact line to fix.
    final found = <String, String>{};
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.yml') && !f.path.endsWith('.yaml')) continue;
      final text = f.readAsStringSync();
      final name = f.uri.pathSegments.last;
      for (final m in _setupPin.allMatches(text)) {
        found['$name (setup step)'] = m.group(1)!;
      }
      for (final m in _argPin.allMatches(text)) {
        found['$name (--flutter-version argument)'] = m.group(1)!;
      }
    }

    // If this ever drops to zero the regexes stopped matching and the test
    // would pass vacuously, which is worse than no test at all.
    expect(
      found.length,
      greaterThanOrEqualTo(5),
      reason:
          'Expected at least 5 places naming the Flutter version, found '
          '${found.length}: $found. Either a workflow was deleted or the '
          'shape changed and these patterns no longer match, in which case '
          'this test is passing for the wrong reason.',
    );

    final distinct = found.values.toSet();
    expect(
      distinct,
      hasLength(1),
      reason:
          'The workflows disagree about which Flutter version to use: $found. '
          'They must all match. In particular flutter-preview.yml names it '
          'twice, and the --flutter-version argument to shorebird release is '
          'the one that decides what the phone actually runs, so bumping only '
          'the setup step ships an app built on a toolchain nothing tested.',
    );
  });

  test('the Flutter README states the pin rule and names no version', () {
    final readme = File('README.md');
    expect(readme.existsSync(), isTrue);

    final versions = RegExp(
      r'\b\d+\.\d+\.\d+\b',
    ).allMatches(readme.readAsStringSync()).map((m) => m.group(0)!).toList();

    expect(
      versions,
      isEmpty,
      reason:
          'flutter/README.md names a version number: $versions. It must state '
          'the RULE instead, because the environment can change under it. That '
          'line went stale twice in one day before it was reworded, once when a '
          'newer SDK was installed and again when that SDK became the default. '
          'The version that ships lives in the workflows, which the test above '
          'keeps consistent.',
    );
  });
}
