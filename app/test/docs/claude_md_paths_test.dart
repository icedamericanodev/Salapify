import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every file path CLAUDE.md names must exist.
///
/// ## Why this file exists
///
/// On 2026-09-18 `flutter/` was renamed to `archive/salapify-2-flutter/`. The
/// rename was correct and nothing was deleted. What nobody could do was
/// re-read thirty pages of prose, so CLAUDE.md went on naming files at their
/// old addresses while reading as current instruction.
///
/// Three retrospectives found this by hand, one after another, and each one
/// recommended this test instead. Session 43 raised four stale paths. Session
/// 44 re-verified them nine days later, found all four still stale plus five
/// more, and wrote: "Session 43's proposed path-extraction test would have
/// caught all nine of these and none of the claims that hold." Session 45
/// found them still stale. Reading prose for broken references is exactly the
/// work a machine should be doing, and until now no machine was.
///
/// The most expensive one sat under the heading that governs every UI change:
/// a render command beginning `cd flutter`, in a repository with no `flutter`
/// directory. Anyone following the rule literally got "No such file".
///
/// ## What counts as a path, and what is deliberately not checked
///
/// A token is checked when it has two or more slash-separated segments and
/// either ends in a source extension, ends in a slash, or starts with a real
/// directory. That last clause is DERIVED by listing the repository, not
/// typed, so a new top-level folder is covered the day it appears.
///
/// Not checked, each for a reason:
///
///  - Absolute paths (`/opt/flutter`). A toolchain on the box, not a file
///    in this repository, and CI's box is not this one.
///  - Anything holding a glob or placeholder (`claude/**`, `*_test.dart`,
///    `/opt/flutter-<version>`). It names a shape, not a file.
///  - A bare directory with no trailing slash and no extension
///    (`flutter/lib/widgets`). It cannot be told apart from ordinary prose
///    like "and/or" or "read/write", and a guard that fires on English is a
///    guard somebody switches off. WRITE DIRECTORIES WITH A TRAILING SLASH
///    and they get checked.
///
/// ## Resolution
///
/// A path is resolved against the repository root AND against `app/`, because
/// CLAUDE.md legitimately writes app-relative paths when it is talking about
/// the live app (`test/palette_contrast_test.dart` means
/// `app/test/palette_contrast_test.dart`). Either hit passes.
///
/// A path that exists ONLY in the archive still fails here, and that is the
/// whole point: `archive/salapify-2-flutter/test/journeys_test.dart` is a
/// correct reference and `flutter/test/journeys_test.dart` is not, even
/// though a file by that name can be found. Write the address it lives at.
void main() {
  final Directory repoRoot = _findRepoRoot();
  final File claudeMd = File('${repoRoot.path}/CLAUDE.md');

  /// Top-level directory names, derived rather than typed, so that a folder
  /// added tomorrow is recognised without editing this file.
  final Set<String> realDirs = <String>{
    ...repoRoot.listSync().whereType<Directory>().map(_basename),
    ...Directory(
      '${repoRoot.path}/app',
    ).listSync().whereType<Directory>().map(_basename),
  };

  late final List<_Ref> refs;

  setUpAll(() {
    expect(
      claudeMd.existsSync(),
      isTrue,
      reason:
          'CLAUDE.md was not found from ${Directory.current.path}, so this '
          'test is checking nothing at all',
    );
    refs = _extract(claudeMd.readAsStringSync(), realDirs);
  });

  test('the extractor actually found paths', () {
    // THE COMPANION ASSERTION, and the reason it is first.
    //
    // Every other check in this file is "nothing is missing", which is also
    // true of an empty list. A typo in the pattern below, or a future rewrite
    // of CLAUDE.md into a shape the pattern does not match, would turn this
    // whole file green while checking zero paths, and green is exactly how it
    // would stay. So prove the extractor is alive before trusting its silence.
    expect(
      refs.length,
      greaterThan(30),
      reason:
          'the extractor found ${refs.length} paths in CLAUDE.md, which is '
          'far too few. The pattern is broken, and a broken pattern reports '
          'no stale paths forever',
    );

    // Named anchors, so a pattern that matches only ONE shape of path still
    // fails. These three are in CLAUDE.md for structural reasons and are the
    // last things that would ever be renamed out of it.
    for (final String anchor in <String>[
      '.claude/settings.json',
      'docs/lunch-and-learn.md',
      'docs/revamp/README.md',
    ]) {
      expect(
        refs.map((_Ref r) => r.path),
        contains(anchor),
        reason:
            'the extractor missed $anchor, so it is matching some path '
            'shapes and silently skipping others',
      );
    }
  });

  test('every path CLAUDE.md names exists', () {
    final List<_Ref> missing = refs
        .where((_Ref r) => !_resolves(r.path, repoRoot))
        .toList();

    expect(
      missing,
      isEmpty,
      reason:
          'CLAUDE.md points at files that are not there. Each line below is '
          'an instruction somebody will try to follow and fail.\n\n'
          '${missing.map((_Ref r) => '  CLAUDE.md:${r.line}  ${r.path}').join('\n')}\n\n'
          'Fix the PROSE, not this test. If the file genuinely moved to the '
          'archive, write its archive address; a reference that reads as '
          'current instruction and points at Salapify 2 is the defect this '
          'guard exists for.',
    );
  });
}

/// One path reference, with where it was written so a failure is navigable.
class _Ref {
  const _Ref(this.path, this.line);

  final String path;
  final int line;

  @override
  String toString() => 'CLAUDE.md:$line $path';
}

/// Two or more segments, or one segment with a trailing slash. Every segment
/// must START with a letter, digit, dot or underscore, which is what keeps
/// prose like "a flutter/-touching PR" from reading as a path.
final RegExp _pathish = RegExp(
  r'[A-Za-z0-9_.][A-Za-z0-9_.\-]*(?:/[A-Za-z0-9_.][A-Za-z0-9_.\-]*)+/?'
  r'|[A-Za-z0-9_.][A-Za-z0-9_.\-]*/',
);

const List<String> _sourceExtensions = <String>[
  '.dart',
  '.md',
  '.yml',
  '.yaml',
  '.json',
  '.sh',
  '.js',
  '.ts',
  '.tsx',
  '.py',
  '.html',
  '.kts',
  '.gradle',
  '.lock',
  '.png',
];

List<_Ref> _extract(String text, Set<String> realDirs) {
  final Map<String, int> seen = <String, int>{};
  final List<String> lines = text.split('\n');

  for (int i = 0; i < lines.length; i++) {
    for (final RegExpMatch m in _pathish.allMatches(lines[i])) {
      final String? p = _candidate(m.group(0)!, realDirs);
      if (p != null) {
        seen.putIfAbsent(p, () => i + 1);
      }
    }
  }

  return seen.entries
      .map((MapEntry<String, int> e) => _Ref(e.key, e.value))
      .toList()
    ..sort((_Ref a, _Ref b) => a.line.compareTo(b.line));
}

/// Decide whether a matched token is a path this repository promises exists.
String? _candidate(String raw, Set<String> realDirs) {
  // Trailing sentence punctuation is part of the prose, not of the path.
  String t = raw;
  while (t.isNotEmpty &&
      '.,;:)'.contains(t[t.length - 1]) &&
      !t.endsWith('/')) {
    t = t.substring(0, t.length - 1);
  }
  if (t.isEmpty) return null;

  final List<String> segments = t
      .split('/')
      .where((String s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return null;

  final bool hasExtension = _sourceExtensions.any(t.endsWith);
  final bool isDirRef = t.endsWith('/');
  final bool rootedInRealDir = realDirs.contains(segments.first);

  if (segments.length == 1) {
    // `app/`, `mobile/`. A lone word with a slash is a path only when a
    // directory of that name is really there, which is what keeps the
    // sentence "the feature folder is debt/ not utang/" out of this test.
    return isDirRef && rootedInRealDir ? t : null;
  }

  if (hasExtension || isDirRef || rootedInRealDir) return t;
  return null;
}

/// Resolved against the repository root AND `app/`, because CLAUDE.md writes
/// app-relative paths whenever it is discussing the live app.
bool _resolves(String path, Directory root) {
  for (final String base in <String>['', 'app']) {
    final String full = base.isEmpty
        ? '${root.path}/$path'
        : '${root.path}/$base/$path';
    if (File(full).existsSync() || Directory(full).existsSync()) return true;
  }
  return false;
}

/// `flutter test` runs from `app/`, a developer may run it from the root, so
/// find the root by walking up to the file rather than assuming either.
Directory _findRepoRoot() {
  Directory d = Directory.current;
  for (int i = 0; i < 6; i++) {
    if (File('${d.path}/CLAUDE.md').existsSync()) return d;
    final Directory parent = d.parent;
    if (parent.path == d.path) break;
    d = parent;
  }
  return Directory.current;
}

String _basename(FileSystemEntity e) => e.path.split('/').last;
