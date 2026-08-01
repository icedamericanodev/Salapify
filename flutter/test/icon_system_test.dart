// The icon system's perimeter, as a machine.
//
// Every authored functional icon routes through lib/widgets/salapify_icon.dart
// so the meaning map is the ONE place that decides how Salapify draws. This
// scan is what stops the next feature quietly reaching for Icons.* again: a
// derived rule, not a typed list, per the lesson that guard sets which are
// lists rot the day a file is added.
//
// The emoji half guards the other boundary: no AUTHORED emoji in lib/ string
// literals outside the allowlisted files that write USER data (seed defaults,
// templates the user saves, share text the user sends, sample data, and the
// free-text emoji picker hints). User-picked emoji are user data and stay.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/salapify_icon.dart';

void main() {
  final lib = Directory('lib');

  List<File> dartFiles() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no raw Icons.* outside the icon system', () {
    final offenders = <String>[];
    for (final f in dartFiles()) {
      if (f.path.endsWith('widgets/salapify_icon.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'\bIcons\.').hasMatch(lines[i])) {
          offenders.add('${f.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Authored icons route through salapifyIcon(name). Add a MEANING to '
          'the map in salapify_icon.dart instead of importing a picture:\n'
          '${offenders.join('\n')}',
    );
  });

  test('no authored emoji outside the user-data allowlist', () {
    // Files allowed to contain emoji, each because the emoji is USER data:
    // seeded defaults the user keeps, templates saved into the user's file,
    // outbound message text, sample data, or a picker hint showing what a
    // typed emoji looks like.
    const allow = {
      'lib/data/backup.dart', // seeded default categories, restore defaults
      'lib/data/store.dart', // default category icon written as user data
      'lib/money/treats.dart', // treat templates saved into user data
      'lib/money/statement.dart', // outbound message text the user sends
      'lib/money/recap.dart', // share text footer
      'lib/money/cycle.dart', // share text footer
      'lib/money/milestones.dart', // share text footer
      'lib/money/sample_data.dart', // demo data, labeled as sample
      'lib/money/search.dart', // RN byte-locked transfer sign, drawn as a
      //   glyph by the screen, never typeset
      'lib/screens/categories.dart', // emoji field hint
      'lib/screens/accounts.dart', // emoji field hint + seeded default
      'lib/screens/treats.dart', // emoji field hint + prefill
      'lib/screens/goals.dart', // goal templates pending redesign in this
      //   same change set; remove once goals.dart carries semantic keys
    };
    final emoji = RegExp(
      r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{FE0F}]',
      unicode: true,
    );
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final rel = f.path.replaceAll('\\', '/');
      if (allow.contains(rel)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Only string literals matter; an emoji in a comment explains, it
        // does not draw.
        final noComment = line.replaceFirst(RegExp(r'//.*$'), '');
        if (emoji.hasMatch(noComment)) {
          offenders.add('$rel:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Authored UI emoji belong to the icon system as semantic glyphs. '
          'If this emoji is genuinely USER data, add the file to the '
          'allowlist with its reason:\n${offenders.join('\n')}',
    );
  });

  test('every semantic name resolves to a real glyph, and sizes are sane', () {
    // The resolver falls back to a neutral marker so a typo cannot take a
    // screen down; this is what stops the fallback being reached silently.
    final fallback = salapifyIcon('definitely-not-a-real-name-xyz');
    for (final name in salapifyIconNames) {
      expect(
        salapifyIcon(name),
        isNot(equals(fallback)),
        reason: 'name "$name" fell through to the neutral marker',
      );
    }
    expect(SalapifyIconSize.detail, lessThan(SalapifyIconSize.inline));
    expect(SalapifyIconSize.inline, lessThan(SalapifyIconSize.action));
    expect(SalapifyIconSize.action, lessThan(SalapifyIconSize.feature));
    expect(SalapifyIconSize.feature, lessThan(SalapifyIconSize.hero));
  });

  test('the raw-icons scan can actually fail', () {
    // Guard on the guard: the regex must match the shape it claims to catch.
    expect(RegExp(r'\bIcons\.').hasMatch('icon: Icons.add,'), isTrue);
    expect(
      RegExp(r'\bIcons\.').hasMatch("icon: salapifyIcon('add'),"),
      isFalse,
    );
  });
}
