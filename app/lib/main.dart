import 'package:flutter/material.dart';

import 'data/notification_gateway.dart';
import 'data/store.dart';
import 'design/app_theme.dart';
import 'design/scroll_behavior.dart';
import 'design/tokens.dart';
import 'shell/app_shell.dart';
import 'state/financial_state.dart';

Future<void> main() async {
  // path_provider needs the bindings up before it can be asked anything.
  WidgetsFlutterBinding.ensureInitialized();

  // Read the file BEFORE the first frame. Building first and loading after
  // would show the seed's demo accounts for a moment and then swap them for
  // the person's real money, which reads like the app lost their data and
  // found it again.
  final FinancialState state = FinancialState(
    store: FileSnapshotStore(),
    // The ONLY place the real notification plugin is constructed. Everywhere
    // else, including every test and the render harness, gets NoNotifications
    // by default, so nothing reaches a platform channel by accident.
    notifications: LocalNotificationGateway(),
  );
  await state.restore();

  // Rebuild the phone's schedule from the ledger that was just loaded. It is
  // a no-op until somebody switches phone reminders on in Settings, and it
  // matters on every launch after that: a bill paid on another day has to
  // stop buzzing, and a new one has to start.
  await state.replanNotifications();

  runApp(SalapifyApp(state: state));
}

/// Salapify, rebuilt in Flutter from the Google AI Studio prototype in src/.
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
  const SalapifyApp({super.key, this.state});

  /// The store, already restored from the device. [main] builds it so the
  /// first frame can be drawn from real data.
  ///
  /// Null means "make one", which is what tests and previews get: a store on
  /// [MemorySnapshotStore], so a test never touches the disk and never
  /// depends on a platform channel that does not exist in one.
  final FinancialState? state;

  @override
  State<SalapifyApp> createState() => _SalapifyAppState();
}

class _SalapifyAppState extends State<SalapifyApp> {
  late final FinancialState _state;

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
      home: AppShell(state: _state),
    );
  }
}
