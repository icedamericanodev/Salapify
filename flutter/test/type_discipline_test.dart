// Off-ladder typography can no longer silently proliferate.
//
// The 2026-08-07 design audit measured the gap between the type system and
// the screens: about a third of all text bypassed AppText, 41 sites used
// sizes that exist on no ladder (12.5 alone shipped 17 times), and the
// dominant leak shape was AppText.X.copyWith(fontSize: offLadder), the token
// system used as a base and immediately overridden. Nothing failed, because a
// raw TextStyle is invisible to every other test.
//
// This file is the boundary. It is a RATCHET, not a ban: the existing drift
// is recorded below, file by file, and the suite fails the moment any file
// gains a raw fontSize it did not have, or a brand-new off-ladder size value
// appears anywhere. Later phases convert screens to AppText and lower their
// baseline rows toward zero; this test makes sure the number only ever moves
// down.
//
// Same shape as the font-family scan in font_choice_test.dart, and like the
// weight scan in typography_test.dart it proves its own regex can catch an
// offender, because a scanner that matches nothing passes on a clean tree and
// on a broken pattern alike.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files that legitimately self-style, exempt from the ratchet entirely:
/// art and off-app rendering, not user-facing screen typography.
const Set<String> _exempt = {
  // The type system itself.
  'lib/typography.dart',
  'lib/theme.dart',
  // Bank card artwork: brand-styled card faces, sized to the card, not to
  // the reading ladder (includes the 96pt watermark glyph).
  'lib/widgets/bank_card.dart',
  'lib/widgets/flip_bank_card.dart',
  // Share images: drawn off-screen into a picture, deliberately self-styled
  // because they inherit no app text theme.
  'lib/screens/milestone_share.dart',
  'lib/screens/recap_share.dart',
  // PDF and file export rendering, print sizing rather than screen sizing.
  'lib/data/export_files.dart',
};

/// The recorded drift at the time the ratchet was installed (f3.74). Counts
/// are occurrences of a raw numeric `fontSize:` literal. A file not listed
/// here has zero and must stay at zero. Phase 2 and later lower these rows as
/// screens convert to AppText; they never go up.
const Map<String, int> _baseline = {
  'lib/screens/account_detail.dart': 3,
  'lib/screens/accounts.dart': 6,
  'lib/screens/add_account_flow.dart': 2,
  'lib/screens/afford_card.dart': 1,
  'lib/screens/bnpl_calculator.dart': 3,
  'lib/screens/budget.dart': 2,
  'lib/screens/cashflow.dart': 1,
  'lib/screens/categories.dart': 3,
  'lib/screens/contribution_calculator.dart': 2,
  'lib/screens/debts.dart': 6,
  'lib/screens/goal_create.dart': 1,
  'lib/screens/goal_detail.dart': 12,
  'lib/screens/goals.dart': 4,
  'lib/screens/insights.dart': 6,
  'lib/screens/learn.dart': 5,
  'lib/screens/loan_calculator.dart': 2,
  'lib/screens/mindset.dart': 2,
  'lib/screens/new_phone_day.dart': 1,
  'lib/screens/notes.dart': 2,
  'lib/screens/onboarding.dart': 8,
  'lib/screens/overview.dart': 11,
  'lib/screens/paluwagan.dart': 2,
  'lib/screens/pan.dart': 4,
  'lib/screens/path_screen.dart': 1,
  'lib/screens/payday.dart': 2,
  'lib/screens/recurring.dart': 1,
  'lib/screens/reports.dart': 7,
  'lib/screens/salary_calculator.dart': 3,
  'lib/screens/search.dart': 1,
  'lib/screens/split_expense.dart': 5,
  'lib/screens/tax_calculator.dart': 2,
  'lib/screens/thirteenth_calculator.dart': 4,
  'lib/screens/treats.dart': 3,
  'lib/screens/utang.dart': 6,
  'lib/screens/year_end_tax.dart': 1,
  'lib/widgets/bills_before_payday.dart': 1,
  'lib/widgets/expansion_lesson_reader.dart': 3,
  'lib/widgets/lesson_block_views.dart': 1,
  'lib/widgets/lesson_finish_card.dart': 2,
  'lib/widgets/paged_lesson_reader.dart': 2,
  'lib/widgets/period_selector.dart': 1,
  'lib/widgets/treat_card.dart': 2,
};

/// Every rung on the ladder (TypeScale in typography.dart). A raw literal at
/// one of these sizes is still drift (it should be an AppText role), but it
/// is COUNTED drift, held by the baseline above.
final Set<double> _ladder = {
  10,
  11,
  12,
  13,
  14,
  15,
  16,
  17,
  18,
  20,
  22,
  24,
  28,
  30,
  34,
  42,
};

/// Off-ladder sizes that already shipped when the ratchet was installed,
/// frozen. The conversion phases purge these; nothing may join them. If a
/// value disappears from the tree, delete it here in the same change.
final Set<double> _legacyOffLadder = {
  // 8.5, 9, 10.5, and 11.5 were purged in Phase 5 (reports, insights, and
  // cashflow); per the rule above, a value that leaves the tree leaves this
  // set in the same change so it cannot quietly return.
  12.5,
  13.5,
  14.5,
  19,
  26,
  27,
};

final RegExp _rawFontSize = RegExp(r'fontSize:\s*([0-9]+(?:\.[0-9]+)?)');

String _norm(String path) => path.replaceAll('\\', '/');

void main() {
  final counts = <String, int>{};
  final values = <String, Set<double>>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final path = _norm(f.path);
    if (_exempt.contains(path)) continue;
    final matches = _rawFontSize.allMatches(f.readAsStringSync()).toList();
    if (matches.isEmpty) continue;
    counts[path] = matches.length;
    values[path] = matches.map((m) => double.parse(m.group(1)!)).toSet();
  }

  test('no file gains a raw fontSize literal', () {
    final offenders = <String>[];
    counts.forEach((path, n) {
      final allowed = _baseline[path] ?? 0;
      if (n > allowed) {
        offenders.add(
          '$path has $n raw fontSize literals, the ratchet allows $allowed. '
          'Use an AppText role (or .tint / .w6 / .w7 / .w8) instead of a raw '
          'size; the ladder lives in typography.dart.',
        );
      }
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test(
    'a converted file lowers its baseline row, so the ratchet stays tight',
    () {
      final slack = <String>[];
      _baseline.forEach((path, allowed) {
        final n = counts[path] ?? 0;
        if (n < allowed) {
          slack.add(
            '$path now has $n raw fontSize literals but the baseline still '
            'says $allowed. Lower (or remove) its row in '
            'test/type_discipline_test.dart so the freed slack cannot be '
            'spent on new drift.',
          );
        }
      });
      expect(slack, isEmpty, reason: slack.join('\n'));
    },
  );

  test('no new off-ladder size value appears anywhere', () {
    final offenders = <String>[];
    values.forEach((path, vs) {
      for (final v in vs) {
        if (!_ladder.contains(v) && !_legacyOffLadder.contains(v)) {
          offenders.add(
            '$path uses fontSize $v, which is on no ladder and is not part '
            'of the recorded legacy drift. Snap it to the nearest TypeScale '
            'rung via AppText.',
          );
        }
      }
    });
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the scanner would actually catch an offender', () {
    // The regex must see both leak shapes the audit measured: a raw
    // TextStyle size and the copyWith override of a token style.
    final raw = _rawFontSize.firstMatch('TextStyle(fontSize: 12.5)');
    expect(raw, isNotNull);
    expect(double.parse(raw!.group(1)!), 12.5);
    final leak = _rawFontSize.firstMatch('AppText.body.copyWith(fontSize: 19)');
    expect(leak, isNotNull);
    expect(double.parse(leak!.group(1)!), 19);
    // And it must NOT see a tokenized size, or conversion would be punished.
    expect(_rawFontSize.hasMatch('fontSize: TypeScale.body'), isFalse);
  });

  test('the exempt list stays small and justified', () {
    // An allowlist that grows is the drift coming back with paperwork. Seven
    // entries: the two system files plus five art or export surfaces named in
    // the audit. Growing this list is a design decision, not a fix for a red
    // test.
    expect(_exempt.length, 7);
    for (final path in _exempt) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '$path is exempt but does not exist; prune the list.',
      );
    }
  });
}
