// Every CI job must have a time limit.
//
// GitHub's default job timeout is six HOURS. That is not a timeout in any
// useful sense, and on 2026-09-14 it cost a whole afternoon: the Flutter
// check's test step hung, nothing was going to stop it, and it sat there
// blocking every merge while looking exactly like a slow build. A re-run
// passed in the usual nine minutes, so the hang itself was a flake. A flake
// with no time limit costs the same as a real failure, and it costs it every
// time.
//
// So this asserts the fence exists, on every job, in every workflow. A hang
// can still happen; what it can no longer do is hide.
//
// Deliberately NOT a YAML parser. The `yaml` package is only a transitive
// dependency here, and a guard that can break because something else changed
// its dependencies is a guard that gets deleted. Line matching is cruder and
// cannot be undermined from outside this file.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Job level keys sit at exactly four spaces. Step level ones are deeper, and
/// counting those would let a workflow pass with a timeout on one step and none
/// on the job, which is the wrong way round: the job timeout is the backstop.
final _jobTimeout = RegExp(r'^    timeout-minutes:\s*\d+\s*$');
final _runsOn = RegExp(r'^    runs-on:');

void main() {
  test('every workflow job has a timeout', () {
    final dir = Directory('../.github/workflows');
    expect(
      dir.existsSync(),
      isTrue,
      reason: 'the workflows folder moved, so this guard is now checking '
          'nothing. Point it at the new path rather than deleting it.',
    );

    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
        .toList();

    expect(
      files,
      isNotEmpty,
      reason: 'no workflows found, so this guard is checking nothing',
    );

    final offenders = <String>[];
    for (final f in files) {
      final lines = f.readAsLinesSync();
      final jobs = lines.where((l) => _runsOn.hasMatch(l)).length;
      final fences = lines.where((l) => _jobTimeout.hasMatch(l)).length;
      if (jobs != fences) {
        offenders.add(
          '${f.uri.pathSegments.last}: $jobs job(s), $fences job level '
          'timeout-minutes',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A CI job with no timeout-minutes runs until GitHub gives up after '
          'SIX HOURS, blocking every merge behind it while looking like a slow '
          'build. Add `timeout-minutes:` beside `runs-on:`, set to roughly '
          'three times how long the job really takes.\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
