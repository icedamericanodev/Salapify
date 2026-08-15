// Does the render harness photograph screens a person can actually open?
//
// The rule "look at the screen before shipping a screen" assumes the picture
// shows the app. Nothing enforced that, and it drifted badly without anyone
// noticing: by f3.59, screens_shot.dart built ExpansionLessonReader in 17
// lesson shots and PagedLessonReader in one, while `lib` had stopped
// constructing the scrolling reader entirely at f3.57. Seventeen careful
// pictures of a widget the app could no longer open, reviewed by the founder,
// proving nothing about what was shipped.
//
// The trigger for going back was even written down. learn.dart said the old
// reader stays "until this has been confirmed on a real phone", and it was
// confirmed three times. A condition nobody is scheduled to re-read is not a
// plan, so this is that condition, as a machine.
//
// The check is deliberately narrow: a widget the shot map builds must also be
// built somewhere in lib, outside its own definition file. That is not "is
// this screen reachable" in any deep sense, and this file does not pretend
// otherwise. A widget nothing in lib constructs cannot be on the phone at
// all, which is the exact failure that happened. Reachability past that
// (behind a feature flag, a dead branch, a route nobody links) is beyond what
// static text can honestly claim.
//
// Modelled on screen_readability_test.dart's own accounting check, which
// reads the lib/screens listing and compares it to a typed list with a named
// exemption map. A derived set is a rule; a typed set is a promise.
//
// Proven to fail before being trusted: the failure line is in the commit
// message that introduced this file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Widget classes the shot map is allowed to build without lib building them.
///
/// Each entry needs a reason somebody could argue with. An exemption is how
/// this guard rots, so it should stay empty unless there is a real answer.
const _exempt = <String, String>{
  // The old single-screen Money Mindset. f4.32 re-pointed the app's only two
  // links (the menu and the lesson reader) to the new flow, so lib no longer
  // builds it; it is retained because mindset_waiting_screen_test still mounts
  // it for the waiting-list flow. Its three shots document that retained screen.
  // FOLLOW-UP for the founder: remove mindset.dart, its shots, and that test
  // together as a deliberate deletion, then delete this exemption. Tracked in
  // docs/reviews/f4.32-mindset-single-entry-report.md.
  'MindsetScreen':
      'retained for mindset_waiting_screen_test; no longer app-reachable after '
      'f4.32, pending a dedicated old-screen removal',
};

void main() {
  test('every widget the render harness shoots is one the app can build', () {
    final shots = File('test/screens_shot.dart').readAsStringSync();

    // Constructor calls inside the shot map: `(s) => SomeWidget(` and the
    // occasional `const SomeWidget(`. Upper camel case followed by an open
    // paren is the whole signal, which over-matches into things like
    // Size( and EdgeInsets(; those are filtered by only keeping names that
    // are actually DEFINED somewhere in lib, so a Flutter framework widget
    // never lands here.
    final built = RegExp(
      r'\b([A-Z][A-Za-z0-9_]*)\(',
    ).allMatches(shots).map((m) => m.group(1)!).toSet();

    final libFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // WIDGET classes only, and that restriction is doing real work rather
    // than tidying. The first version of this check reported `Milestone`, a
    // plain data class the shot map builds as a fixture. A data class is not
    // a screen and cannot be "opened", so including it would have meant an
    // exemption entry excusing something that was never a defect, which is
    // how an exemption map fills up with noise and stops being read.
    final widgetsDefinedIn = <String, String>{};
    for (final f in libFiles) {
      final src = f.readAsStringSync();
      for (final m in RegExp(
        r'class\s+([A-Z][A-Za-z0-9_]*)\s+extends\s+(?:Stateless|Stateful)Widget',
      ).allMatches(src)) {
        widgetsDefinedIn[m.group(1)!] = f.path;
      }
    }

    // Everywhere a widget is actually CONSTRUCTED, which is not the same as
    // everywhere its name appears followed by a paren. A class's own file
    // always contains `const Foo({` (the constructor DECLARATION), so a
    // dead widget looks used inside the one file that proves nothing.
    //
    // Excluding the whole defining file is not the fix either: it reported
    // `PersonSheet`, which utang.dart both declares and shows in a modal,
    // which is completely legitimate and completely reachable.
    //
    // So a USE is recognised by what precedes it. A construction appears
    // after `=>`, `(`, `,`, `:`, `[`, `?`, `=`, or `return`; a declaration
    // appears after `;`, `{`, `}`, or a comment. That distinction is the only
    // reason this guard can tell a dead widget from a self-contained one.
    //
    // `?` and `=` are in that list because leaving them out produced a FALSE
    // ALARM, not because they were tidy: main.dart builds the onboarding
    // screen inside a ternary (`? OnboardingScreen(store: ...)`), and a guard
    // that names a live screen as dead gets its exemption map filled with
    // excuses and then nobody believes the entry that is real.
    final useSites = <String, Set<String>>{};
    final usePattern = RegExp(
      r'(?:=>|[(\[,:?=]|\breturn)\s*(?:const\s+)?([A-Z][A-Za-z0-9_]*)\(',
    );
    for (final f in libFiles) {
      final src = f.readAsStringSync();
      for (final m in usePattern.allMatches(src)) {
        useSites.putIfAbsent(m.group(1)!, () => {}).add(f.path);
      }
    }

    // Only Salapify's own widgets. A framework widget has no definition in
    // lib, so it is not this file's business.
    final ours = built.where(widgetsDefinedIn.containsKey).toSet();

    final orphans = ours.where((name) {
      if (_exempt.containsKey(name)) return false;
      return (useSites[name] ?? const <String>{}).isEmpty;
    }).toList()..sort();

    expect(
      orphans,
      isEmpty,
      reason:
          'the render harness photographs these, but nothing in lib builds '
          'them outside their own file, so the founder is reviewing pictures '
          'of screens the app cannot open:\n${orphans.join('\n')}\n\n'
          'Either point the shot at what the app really opens, or add the '
          'name to _exempt with a reason somebody could argue with.',
    );

    // The exemption map cannot outlive what it excuses.
    final stale = _exempt.keys
        .where((n) => !widgetsDefinedIn.containsKey(n))
        .toList();
    expect(
      stale,
      isEmpty,
      reason: 'exempted but no longer defined in lib:\n${stale.join('\n')}',
    );
  });

  test('the check would actually catch it', () {
    // The guard above reads real files, so proving it can fail by breaking
    // the repo would mean deleting a screen. This proves the RULE instead,
    // on the same shapes, so the logic cannot rot into something that always
    // finds nothing.
    //
    // Written after the real one reported ExpansionLessonReader by name.
    const defined = {
      'DeadWidget': 'lib/widgets/dead.dart',
      'LiveWidget': 'lib/widgets/live.dart',
    };
    const constructed = {
      // Only its own file builds it: dead.
      'DeadWidget': {'lib/widgets/dead.dart'},
      // A screen builds it: live.
      'LiveWidget': {'lib/widgets/live.dart', 'lib/screens/home.dart'},
    };

    List<String> orphansOf(Set<String> shot) =>
        shot
            .where(
              (n) => (constructed[n] ?? const <String>{})
                  .where((p) => p != defined[n])
                  .isEmpty,
            )
            .toList()
          ..sort();

    expect(orphansOf({'DeadWidget', 'LiveWidget'}), ['DeadWidget']);
    expect(orphansOf({'LiveWidget'}), isEmpty);
  });
}
