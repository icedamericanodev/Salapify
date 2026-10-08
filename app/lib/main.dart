import 'package:flutter/material.dart';

import 'data/notification_gateway.dart';
import 'data/store.dart';
import 'design/app_theme.dart';
import 'design/scroll_behavior.dart';
import 'design/tokens.dart';
import 'features/lock/app_lock.dart';
import 'features/lock/lock_gate.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'shell/app_shell.dart';
import 'state/financial_state.dart';

/// Which build is this, in one line, readable on the phone.
///
/// ## What it is for, and it is exactly one thing
///
/// The founder opens Settings and compares this against the last row of
/// `docs/delivery-log.md`. That comparison is the ONLY real proof that a build
/// reached the phone, and it is the one check nobody but the founder can
/// perform. Everything else in the pipeline can be green while the phone runs
/// a build from last week.
///
/// `appVersion` in `settings_sheet.dart` cannot do this job. It is
/// "3.0.0 early access" and changes when somebody decides it does, so it
/// answers "which release line is this" and never "which build am I running".
///
/// ## KEEP IT SHORT. One line, high level, what changed and nothing else.
///
/// On Salapify 2 this grew into roughly forty lines filling the founder's
/// whole screen, because each build appended the previous build's notes
/// instead of replacing them. The detail belongs in the pull request and in
/// `docs/delivery-log.md`, which is a record of what shipped rather than a
/// changelog. The limit is enforced by `test/update_stamp_test.dart`, not by
/// good intentions, and that test exists because good intentions already
/// failed once here.
///
/// ## The `s` prefix
///
/// Salapify 2's stamps were `f0.01` through `f4.72` and they are still in
/// `docs/delivery-log.md`, which `app/` shares rather than forking. One file,
/// because CLAUDE.md's three command delivery check reads exactly that path
/// and a second file is a second place to forget to look. The different
/// prefix is what keeps the two apps' rows apart, both for a human reading
/// the table and for the publisher, which finds the previous stamp by
/// pattern and would otherwise read `f4.72` as this app's last delivery.
///
/// ## Nothing has shipped yet
///
/// `app/` has no publisher, so no stamp has ever reached a phone and
/// `docs/delivery-log.md` has no `s` row. This constant and its guards are
/// deliberately inert until the publisher lands: they prove themselves on
/// ordinary branch pushes, which is the cheapest possible time to find out
/// the cap is wrong.
const String updateStamp =
    's0.01 · First build signed with its own key. Nothing new to use yet.';

Future<void> main() async {
  // path_provider needs the bindings up before it can be asked anything.
  WidgetsFlutterBinding.ensureInitialized();

  // Read the file BEFORE the first frame. Building first and loading after
  // would show the seed's demo accounts for a moment and then swap them for
  // the person's real money, which reads like the app lost their data and
  // found it again.
  final LocalNotificationGateway notifications = LocalNotificationGateway();
  final FinancialState state = FinancialState(
    store: FileSnapshotStore(),
    // The ONLY place the real notification plugin is constructed. Everywhere
    // else, including every test and the render harness, gets NoNotifications
    // by default, so nothing reaches a platform channel by accident.
    notifications: notifications,
  );
  await state.restore();

  // App lock, read BEFORE the first frame for the same reason as the ledger:
  // a locked app that drew one frame of Home first would have shown the very
  // figures the lock exists to hide.
  final AppLockController lock = AppLockController(
    settings: FileLockSettings(),
    authenticator: DeviceLockAuthenticator(),
  );
  await lock.load();

  // While app lock is on, reminders on the phone's own lock screen show
  // "Contents hidden" instead of a bill and its amount. Kept in step with the
  // setting, and the schedule is rebuilt whenever it changes.
  notifications.privateOnLockScreen = lock.enabled;
  lock.addListener(() {
    if (notifications.privateOnLockScreen == lock.enabled) return;
    notifications.privateOnLockScreen = lock.enabled;
    state.replanNotifications();
  });

  // Rebuild the phone's schedule from the ledger that was just loaded. It is
  // a no-op until somebody switches phone reminders on in Settings, and it
  // matters on every launch after that: a bill paid on another day has to
  // stop buzzing, and a new one has to start.
  await state.replanNotifications();

  runApp(SalapifyApp(state: state, lock: lock));
}

/// Salapify, rebuilt in Flutter from the Google AI Studio prototype in archive/prototype-google-ai-studio/src/.
///
/// Everything a person types stays on the device. There is no account and no
/// server of ours.
///
/// NOT "no network call anywhere", which this comment claimed until
/// 2026-09-19 and which was false: `data/fx_service.dart` asks a public rate
/// service for today's exchange rates, sending a currency code and nothing
/// else. It is the only outbound request in the app. The sentence is
/// corrected here rather than quietly deleted, because the next person to
/// read this file would otherwise reason from a premise that has not been
/// true for some time.
class SalapifyApp extends StatefulWidget {
  const SalapifyApp({super.key, this.state, this.lock});

  /// The store, already restored from the device. [main] builds it so the
  /// first frame can be drawn from real data.
  ///
  /// Null means "make one", which is what tests and previews get: a store on
  /// [MemorySnapshotStore], so a test never touches the disk and never
  /// depends on a platform channel that does not exist in one.
  final FinancialState? state;

  /// App lock, already loaded. Null means off, which is what every test and
  /// preview gets unless it is testing the lock itself.
  final AppLockController? lock;

  @override
  State<SalapifyApp> createState() => _SalapifyAppState();
}

class _SalapifyAppState extends State<SalapifyApp> {
  late final FinancialState _state;
  late final AppLockController _lock = widget.lock ?? AppLockController.off();

  /// Only a state this widget made is a state this widget may dispose.
  late final bool _ownsState;

  @override
  void initState() {
    super.initState();
    _ownsState = widget.state == null;
    _state = widget.state ?? FinancialState(store: MemorySnapshotStore());
    if (_ownsState) {
      // Nothing to read, so this settles immediately and only turns saving on.
      _state.restore();
    }
    // One store, one listener: a change anywhere redraws the shell.
    _state.addListener(_onStateChanged);
  }

  void _onStateChanged() => setState(() {});

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    if (_ownsState) _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette palette = Palette.of(_state.theme);

    return MaterialApp(
      title: 'Salapify',
      debugShowCheckedModeBanner: false,
      // Drops Android's stretch overscroll. See scroll_behavior.dart for why.
      scrollBehavior: const SalapifyScrollBehavior(),
      theme: salapifyTheme(palette, _state.theme),
      // The lock sits INSIDE MaterialApp but around the navigator, so it
      // covers every sheet and dialog too, and Settings can reach it.
      builder: (BuildContext context, Widget? child) => AppLockScope(
        controller: _lock,
        child: LockGate(
          controller: _lock,
          palette: palette,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      // THE FIRST LAUNCH FORK, and it reads the store rather than a flag this
      // widget keeps. The shell listens to the same store, so the moment
      // either onboarding path writes, `needsWelcome` goes false and the next
      // frame is the app. One decision, one place, nothing to get out of step.
      home: _state.needsWelcome
          ? OnboardingFlow(palette: palette, state: _state)
          : AppShell(state: _state),
    );
  }
}
