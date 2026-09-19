// The publisher's own logic, exercised instead of trusted.
//
// Everything about delivery in this project has been learned the hard way, and
// every lesson landed as a line of YAML that nothing could run. A workflow step
// is only ever tested by shipping, which is the most expensive test bench
// available and the one where a mistake is measured in stamps the founder never
// received.
//
// So the "did anything actually ship" decision was pulled out of
// .github/workflows/flutter-preview.yml into a script that takes arguments and
// returns an exit code, and this drives it with the failure shapes that
// matter. It runs on the branch check with every other test, before the merge,
// on a real runner.
//
// It is a Dart test only because `flutter test` is what runs on the branch.
// There is nothing Flutter about it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo-root relative, the same way qa_record_test.dart reaches docs/.
const _script = '../.github/scripts/verify-shipped.sh';

/// Run through `bash` rather than executing the file directly, exactly as the
/// workflow does, so the guard cannot quietly stop running the day the
/// executable bit is lost in a checkout, a rebase, or a zip.
ProcessResult _verify(
  String mode, {
  String patch = '',
  String log = '',
  String apk = '',
}) {
  return Process.runSync('bash', [_script, mode, patch, log, apk]);
}

File _logSaying(Directory dir, String contents) {
  final f = File('${dir.path}/ship.log')..writeAsStringSync(contents);
  return f;
}

File _apkOf(Directory dir, int bytes) {
  final f = File('${dir.path}/app-release.apk')
    ..writeAsBytesSync(List.filled(bytes, 0));
  return f;
}

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('salapify_ship'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('the script the workflow calls actually exists', () {
    // A path typo in a workflow is invisible until the day the step runs, and
    // this one only runs on main, after the merge, at the moment nobody is
    // watching.
    expect(
      File(_script).existsSync(),
      isTrue,
      reason:
          '$_script is missing. The publisher calls it by this exact path, so '
          'moving or renaming it breaks delivery on main and nowhere else.',
    );
  });

  group('a patch run', () {
    test('passes when Shorebird genuinely published one', () {
      final log = _logSaying(tmp, 'Building patch...\nPublished Patch 10!\n');
      final r = _verify('patch', patch: '10', log: log.path);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('Shipped: patch 10'));
    });

    test('FAILS when no patch number was published', () {
      // THE DEFECT THIS FILE EXISTS FOR. The ship step exits zero, the parse
      // finds nothing and is allowed to find nothing, and without this guard
      // the next step writes a delivery row reading "patch: none" while the
      // phone received exactly nothing.
      final log = _logSaying(tmp, 'Building patch...\nNo changes detected.\n');
      final r = _verify('patch', patch: '', log: log.path);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('NOTHING SHIPPED'));
      expect(r.stdout, contains('no patch number was published'));
    });

    test('FAILS when the log never says a patch was published', () {
      // The belt to the braces above: a patch number parsed out of some other
      // line, or carried over from a previous run's environment, cannot pass
      // on its own.
      final log = _logSaying(tmp, 'Building patch...\nAborted.\n');
      final r = _verify('patch', patch: '10', log: log.path);
      expect(r.exitCode, 1);
      expect(r.stdout, contains("no 'Published Patch' line"));
    });

    test('FAILS when the log is missing entirely', () {
      final r = _verify('patch', patch: '10', log: '${tmp.path}/absent.log');
      expect(r.exitCode, 1);
      expect(r.stdout, contains('does not exist'));
    });

    test('FAILS on a patch number that is not a number', () {
      // The parse pipeline could hand over anything if Shorebird's wording
      // changes. A row whose Patch column reads "Patch" compares against the
      // phone as nonsense, and comparing the two is the whole point of the row.
      final log = _logSaying(tmp, 'Published Patch 10!\n');
      final r = _verify('patch', patch: '10a', log: log.path);
      expect(r.exitCode, 1);
      expect(r.stdout, contains("is not a number"));
    });
  });

  group('a release run', () {
    test('passes when a real APK was built', () {
      final apk = _apkOf(tmp, 2 * 1024 * 1024);
      final r = _verify('release', apk: apk.path);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout, contains('base APK'));
    });

    test('passes with NO patch number, which is the normal case', () {
      // The half that has to stay silent. A release run has no "Published
      // Patch" line anywhere in its log, so an empty patch number is correct
      // there, and a guard that rejected it would turn every base APK build
      // red and get itself removed. Proving the silence, not only the noise.
      final apk = _apkOf(tmp, 2 * 1024 * 1024);
      final r = _verify('release', patch: '', log: '', apk: apk.path);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    });

    test('FAILS when the APK was never built', () {
      final r = _verify('release', apk: '${tmp.path}/absent.apk');
      expect(r.exitCode, 1);
      expect(r.stdout, contains('NOTHING SHIPPED'));
      expect(r.stdout, contains('never built'));
    });

    test('FAILS on a file too small to be an app', () {
      // A truncated or placeholder artifact uploads perfectly happily to the
      // release page and then will not install, which reads to the founder as
      // a broken phone rather than a broken build.
      final apk = _apkOf(tmp, 512);
      final r = _verify('release', apk: apk.path);
      expect(r.exitCode, 1);
      expect(r.stdout, contains('not an installable app'));
    });
  });

  test('FAILS when the ship step reported no mode at all', () {
    // The step falling through without setting an output. Without this the
    // delivery row is written with an empty Mode column and reads like every
    // other successful build.
    final r = _verify('');
    expect(r.exitCode, 1);
    expect(r.stdout, contains('neither patch nor release'));
  });

  test(
    'the publisher still calls this guard, and before it records anything',
    () {
      // A guard wired into a workflow can be silently unwired by an edit to a
      // different part of the same file. The ORDER is the load-bearing part: the
      // check has to run before the delivery row is written, or the row exists
      // whatever the check decides, and the row is what everyone believes.
      final yaml = File(
        '../.github/workflows/flutter-preview.yml',
      ).readAsStringSync();
      final guardAt = yaml.indexOf('verify-shipped.sh');
      final recordAt = yaml.indexOf('Record what actually shipped');
      expect(
        guardAt,
        greaterThan(-1),
        reason: 'the publisher no longer calls verify-shipped.sh at all',
      );
      expect(
        recordAt,
        greaterThan(-1),
        reason:
            'the delivery-log step was renamed; this check now proves nothing',
      );
      expect(
        guardAt,
        lessThan(recordAt),
        reason:
            'the shipped check must run BEFORE the delivery row is written. '
            'After it, the row exists whatever the check says, and the row is '
            'the thing this project treats as proof.',
      );
    },
  );
}
