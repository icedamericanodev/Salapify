// "Load sample data", and the reasons it is safe to have in the app at all.
//
// Founder direction, 2026-09-14: sample data while developing, gone at launch.
// This is that, built so the "gone at launch" half cannot be forgotten.
//
// THREE things keep it out of a shipped app and away from real money:
//
// 1. `kDebugMode` is a compile time constant. In a release build it is `false`,
//    the branch below is dead, and the Dart compiler drops both this button and
//    the sample ledger it references. There is nothing to remember to delete
//    before the store listing, which is the point: a step somebody has to
//    remember is a step that eventually gets missed.
// 2. It only appears when the ledger is EMPTY. So it can never overwrite
//    anything: there is nothing to overwrite. That takes the whole
//    data-loss class off the table rather than guarding it with a dialog,
//    and CLAUDE.md is explicit that anything which could permanently lose user
//    data is the founder's call and not a convenience.
// 3. It writes through the same `mutate` every other feature writes through, so
//    the data lands via sanitizeData exactly as a restored backup would. Sample
//    data that skipped the front door would not be testing the real path.
//
// To get back to an empty app on an emulator: long press the app icon, App
// info, Storage, Clear storage. That is a deliberate manual step rather than a
// "wipe everything" button, because a wipe button is the one thing here that
// COULD destroy a real ledger.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/clock.dart';
import '../app/ledger_scope.dart';
import '../design/tokens.dart';
import '../design/type.dart';
import 'sample_ledger.dart';

class SampleDataAction extends StatelessWidget {
  const SampleDataAction({super.key, this.enabled = kDebugMode, this.today});

  /// Defaults to [kDebugMode] so a release build never shows it. Injectable
  /// only so a test can prove the off state renders nothing: tests themselves
  /// always run in debug, so `kDebugMode` there is always true and the release
  /// behaviour would otherwise be untestable and therefore unproven.
  final bool enabled;

  /// What the sample data is dated around. Null takes the APP'S clock, which
  /// is the right default and not the same thing as `DateTime.now()`.
  ///
  /// Reading the app's clock means the data and the screen reading it can never
  /// disagree: in the app both are the real today, and under a test or the
  /// render harness both are whatever was pinned. Calling `DateTime.now()` here
  /// instead produced a September ledger being read by a screen that thought it
  /// was some other day, which fails for a reason that has nothing to do with
  /// the code.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();

    final store = context.ledger;
    final empty = (store.data['transactions'] as List? ?? const []).isEmpty &&
        (store.data['accounts'] as List? ?? const []).isEmpty;
    if (!empty) return const SizedBox.shrink();

    final skin = context.skin;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => store.mutate((draft) {
            draft
              ..clear()
              ..addAll(sampleLedger(today: today ?? context.now));
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Load sample data',
              textAlign: TextAlign.center,
              style: TypeScale.action(skin.accent),
            ),
          ),
        ),
      ),
    );
  }
}
