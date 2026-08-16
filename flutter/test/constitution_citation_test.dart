// A citation to our own governing document is exactly as fabricable as a
// citation to a government website, and one was fabricated here.
//
// docs/decision-log.md briefly claimed that forcing a new base APK is "a
// release decision under section 42 of the constitution". Section 42 is
// FOUNDER DECISION REQUIRED and it has seven categories, none of which is
// releases. The sentence was well formed, confident, and pointed at a document
// sitting in this same repository. It was written WHILE a different mistake
// about which document has authority was being corrected, and the only thing
// that caught it was a person choosing to open the constitution and read.
//
// CLAUDE.md already guards this shape for Money Courses government URLs, where
// a syntactically perfect link to a real domain turned out to be invented. That
// rule was never extended to internal documents, which is why it did not apply.
// This is the machine half of extending it.
//
// Scope, and both halves of it were chosen to keep this from becoming an alarm
// nobody listens to:
//
//   - PARAGRAPH, not occurrence. The corrected text ends "Cite it that way, not
//     as a section 42 release rule, which is not a thing the document
//     contains", a correct sentence that names no category on its own. A per
//     sentence check would redden on the very fix it is meant to protect.
//   - CLAUDE.md and docs/decision-log.md only. docs/reviews/ holds frozen
//     review artifacts that carry bare "(section 42)" references, and an alarm
//     that reddens on history gets its battery taken out.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that state current rules, and so must cite accurately. Frozen review
/// artifacts under docs/reviews are deliberately excluded.
const _governing = <String>['../CLAUDE.md', '../docs/decision-log.md'];

void main() {
  test('a paragraph citing constitution section 42 names a real category', () {
    final constitution = File('../docs/Salapify_Master_Constitution.md');
    expect(constitution.existsSync(), isTrue);

    // Read section 42's own subheadings out of the document, rather than
    // hardcoding them here. A typed copy would drift the moment the founder
    // edits the constitution, and drift in the checker is worse than no
    // checker, because it would start failing correct citations.
    final lines = constitution.readAsLinesSync();
    final headings = <String>[];
    var inSection42 = false;
    for (final line in lines) {
      if (line.startsWith('# 42.')) {
        inSection42 = true;
        continue;
      }
      // Any other top level heading ends the section.
      if (inSection42 && line.startsWith('# ')) break;
      if (inSection42 && line.startsWith('### ')) {
        headings.add(line.substring(4).trim());
      }
    }

    expect(
      headings,
      hasLength(7),
      reason:
          'Expected 7 subheadings under constitution section 42, found '
          '${headings.length}: $headings. Either the constitution changed, in '
          'which case update the expectation deliberately, or the parser no '
          'longer matches and this test is passing for the wrong reason.',
    );

    // One keyword per category, derived from the heading rather than typed.
    // The first word is deliberately loose: prose says "security and privacy"
    // where the heading says "Security / Privacy", and demanding the heading
    // verbatim would fail honest sentences. Loose is fine, because the defect
    // this exists to catch named NO category at all.
    final keywords = headings
        .map((h) => h.toLowerCase().split(RegExp(r'[\s/]+')).first)
        .toList();

    final failures = <String>[];
    for (final path in _governing) {
      final file = File(path);
      if (!file.existsSync()) continue;
      // Paragraphs are blank line separated. Newlines inside one become spaces
      // so a citation wrapped across lines still reads as one string.
      final paragraphs = file.readAsStringSync().split(RegExp(r'\n\s*\n'));
      for (final para in paragraphs) {
        final flat = para.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        if (!flat.contains('section 42')) continue;
        if (keywords.any(flat.contains)) continue;
        failures.add('$path: "${flat.trim()}"');
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'These paragraphs cite constitution section 42 without naming any of '
          'its seven categories ($headings). Section 42 is FOUNDER DECISION '
          'REQUIRED and covers only those. If the claim is about something '
          'else, such as a release, cite the rule that actually says it: the '
          '"Merge or release" stop condition lives in CLAUDE.md, not in the '
          'constitution.\n\n${failures.join('\n\n')}',
    );
  });
}
