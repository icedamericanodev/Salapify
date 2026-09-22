// The guard for a gate that had none.
//
// CLAUDE.md requires a QA pass before every merge. That requirement existed
// for weeks with nothing enforcing it, and on f2.71 it simply did not happen:
// a Categories screen shipped whose monthly cap could not see the entries the
// app's own Log button creates. It sat wrong on the founder's phone for two
// hours. 913 tests were green the whole time, because a test suite checks what
// somebody thought to check, and nobody had thought to check that the check
// had been done.
//
// So this asserts the one thing that was missing: the stamp about to ship has
// a row in docs/qa-log.md saying what the pass found. It runs in the branch
// check, so a stamp cannot reach main without someone having opened that file.
//
// This cannot verify a pass really ran. Nothing automated can. What it does is
// make forgetting impossible and make skipping a sentence written down on
// purpose. SKIPPED is an accepted verdict here, and a far better outcome than
// silence.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/main.dart' show updateStamp;

void main() {
  test('the shipping stamp has a QA row in docs/qa-log.md', () {
    final file = File('../docs/qa-log.md');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'docs/qa-log.md is missing. It is the record of whether the QA pass '
          'CLAUDE.md requires before a merge actually ran.',
    );

    // The stamp itself, up to the first space: "f2.73" out of
    // "f2.73 · Share a statement of account ...".
    final stamp = updateStamp.split(' ').first;
    final rows = file
        .readAsLinesSync()
        .where((l) => l.trimLeft().startsWith('| $stamp |'))
        .toList();

    expect(
      rows,
      hasLength(1),
      reason:
          'Stamp $stamp has ${rows.length} rows in docs/qa-log.md, expected '
          'exactly one. Add a row saying who reviewed this batch and what '
          'they found. SKIPPED is a valid verdict; a missing row is not, '
          'because a missing row is what shipped a broken monthly cap to the '
          "founder's phone in f2.71.",
    );

    // Four filled cells: stamp, reviewer, verdict, notes. An empty verdict
    // says nothing, and saying nothing is the exact failure being guarded.
    final cells = rows.single
        .split('|')
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    expect(
      cells.length,
      greaterThanOrEqualTo(3),
      reason:
          'The row for $stamp is "${rows.single.trim()}". It needs a reviewer '
          'and a verdict, not just the stamp.',
    );
  });
}
