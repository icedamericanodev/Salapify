// The Flutter pin is written in several workflow files, and only ONE property
// about it is load bearing: every workflow serving the SAME APP must say the
// same thing.
//
// It used to say "they must all say the same thing", and that was right while
// this repository held one Flutter app. It now holds two. flutter/ is pinned
// by SHOREBIRD, which lags stable and cannot be moved on a whim, and app/ has
// no publisher at all, so it runs the SDK the founder actually has on their
// Mac (docs/decision-log.md, 2026-09-18). Those are two different constraints
// with two different reasons, and a guard that demanded one number would be
// demanding the rebuild be built on a toolchain nothing requires.
//
// So the grouping is derived from each workflow's own `working-directory`
// rather than from a list of filenames here, for the same reason the version
// set is derived: a typed set is a promise and a derived set is a rule.
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

/// `working-directory: app` or `working-directory: flutter`, which is how a
/// workflow says which of the two Flutter projects it builds. `.` and `mobile`
/// are not Flutter projects and are ignored.
final _project = RegExp(r"""working-directory:\s*['"]?(app|flutter)['"]?\s*$""",
    multiLine: true);

/// Strips YAML comments before any pattern is matched.
///
/// Not cosmetic. app-check.yml carries a comment EXPLAINING Shorebird's pin,
/// which names `--flutter-version 3.44.6` in prose, and reading it as a real
/// pin made app/ look like it was demanding two different toolchains at once.
/// A guard that cannot tell a configured value from a sentence about one
/// reports the wrong file.
String _withoutComments(String yaml) => yaml
    .split('\n')
    .map((String line) {
      final int hash = line.indexOf('#');
      return hash == -1 ? line : line.substring(0, hash);
    })
    .join('\n');

void main() {
  test('every workflow serving one app pins the same Flutter version', () {
    final dir = Directory('../.github/workflows');
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'Cannot find ../.github/workflows from the flutter/ directory.',
    );

    // project -> (label -> version). The label says which file and which shape
    // matched, so a failure points at the exact line to fix.
    final byProject = <String, Map<String, String>>{};
    final found = <String, String>{};
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.yml') && !f.path.endsWith('.yaml')) continue;
      final text = _withoutComments(f.readAsStringSync());
      final name = f.uri.pathSegments.last;

      final here = <String, String>{};
      for (final m in _setupPin.allMatches(text)) {
        here['$name (setup step)'] = m.group(1)!;
      }
      for (final m in _argPin.allMatches(text)) {
        here['$name (--flutter-version argument)'] = m.group(1)!;
      }
      if (here.isEmpty) continue;
      found.addAll(here);

      // Which app does this workflow build? Derived from its own
      // working-directory lines, never from a list of filenames in this test.
      final projects =
          _project.allMatches(text).map((m) => m.group(1)!).toSet();
      expect(
        projects,
        hasLength(1),
        reason:
            '$name pins a Flutter version but does not name exactly one '
            'Flutter project through working-directory: it names $projects. '
            'Without that this test cannot tell which app its pin belongs to, '
            'and a wrong pin would sail through.',
      );
      byProject.putIfAbsent(projects.single, () => <String, String>{}).addAll(here);
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

    // Both apps must still be represented. Without this, deleting every
    // workflow for one of them would leave the remaining group unanimous and
    // this test would go green on a repository that had lost half its CI.
    expect(
      byProject.keys.toSet(),
      <String>{'app', 'flutter'},
      reason:
          'Expected workflows pinning Flutter for BOTH projects, found '
          '${byProject.keys.toList()}. A project losing all of its pinned '
          'workflows is not something this test should pass quietly.',
    );

    for (final entry in byProject.entries) {
      final distinct = entry.value.values.toSet();
      expect(
        distinct,
        hasLength(1),
        reason:
            'The workflows building ${entry.key}/ disagree about which Flutter '
            'version to use: ${entry.value}. Every workflow serving one app '
            'must match. In particular flutter-preview.yml names it twice, and '
            'the --flutter-version argument to shorebird release is the one '
            'that decides what the phone actually runs, so bumping only the '
            'setup step ships an app built on a toolchain nothing tested.',
      );
    }

    // The two apps are pinned for DIFFERENT reasons (Shorebird for flutter/,
    // the founder's own Mac for app/), so they are allowed to differ. They are
    // not required to.
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
