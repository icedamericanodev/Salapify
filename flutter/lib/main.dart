// Salapify Flutter preview. The from-scratch Flutter rebuild, growing next
// to the live React Native app in mobile/ until it reaches parity. Every
// push that touches flutter/ builds an APK to the fixed flutter-preview
// release link and deploys the web preview. The Update stamp below bumps on
// every push so the founder can verify which build arrived.

import 'package:flutter/material.dart';

import 'data/store.dart';
import 'services/diagnostics.dart';
import 'services/notifications.dart';
import 'screens/budget.dart';
import 'screens/history.dart';
import 'screens/insights.dart';
import 'screens/menu.dart';
import 'screens/overview.dart';
import 'screens/shell.dart';
import 'screens/utang.dart';
import 'theme.dart';
import 'widgets/lock_gate.dart';
import 'widgets/salapify_icon.dart';

/// Bump on EVERY push that touches flutter/, so the founder can confirm on
/// the phone which build arrived. Format: `f<major>.<counter>`.
///
/// KEEP IT SHORT. One line, high level, what changed and nothing else. This
/// grew into a wall of text on the founder's phone because each build kept
/// appending the previous build's notes, and the row it lives in is a plain
/// right-aligned Text that will happily wrap forever. The full story belongs
/// in the pull request and docs/delivery-log.md; this row exists so the
/// founder can answer one question, which build am I running.
///
/// The limit is enforced by a test, not by good intentions.
const String updateStamp =
    'f2.52 \u00b7 Appearance is its own screen, each theme previews itself, and Forest is finally green.';

void main() {
  // Before anything else, so an error thrown during startup is still caught.
  // A crash reporter installed after the crash reports nothing.
  Diagnostics.install();
  Diagnostics.load();
  runApp(SalapifyApp(store: SalapifyStore()));
}

class SalapifyApp extends StatefulWidget {
  final SalapifyStore store;
  const SalapifyApp({super.key, required this.store});

  @override
  State<SalapifyApp> createState() => _SalapifyAppState();
}

class _SalapifyAppState extends State<SalapifyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load, then refresh the reminder schedule from the loaded data. Both are
    // safe no-ops off a real phone (web, tests), so this never blocks startup.
    widget.store.load().then((_) {
      Reminders.reschedule(widget.store.data, DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The OS flipped light/dark (auto at night, or the user toggled it). Repaint
  // so a 'system' appearance follows along.
  @override
  void didChangePlatformBrightness() => setState(() {});

  // Back to the foreground: post any recurring bills and income that came due
  // while the app was backgrounded (people keep apps open for weeks). The
  // lastPosted marker makes this idempotent, so an extra call is always safe.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.store.postDueRecurring();
      // Refill the schedule on every foreground, so tonight's log nudge is
      // dropped once you have logged, and new bills/utang are picked up.
      Reminders.reschedule(widget.store.data, DateTime.now());
    }
  }

  Destination tab = Destination.home;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        // The theme and mode live in settings so they survive backups. The
        // palette is resolved and set BEFORE anything below reads a Barako
        // color; the store's notify and the OS brightness observer both
        // rebuild this tree, so a theme/mode switch or a night-mode flip
        // repaints the whole app.
        final settings = widget.store.data['settings'];
        final (themeKey, mode) = resolveThemeChoice(settings);
        final os =
            WidgetsBinding.instance.platformDispatcher.platformBrightness;
        final theme = themeForKey(themeKey);
        Barako.currentTheme = theme;
        Barako.current = theme.resolve(effectiveBrightness(mode, os));
        return MaterialApp(
          title: 'Salapify Preview',
          theme: salapifyTheme(Barako.current),
          // Snap the theme, do not tween it. MaterialApp otherwise lerps every
          // Theme.of-derived colour over 200ms (the scaffold, every Card fill,
          // button colours) while everything reading a Barako.* getter changes
          // instantly, because those are plain static reads and not animatable.
          // So a switch from Barako light to Tidal dark showed near-white text
          // sitting on a half-faded cream card for a fifth of a second. Half an
          // animation reads as lag, not polish, and it is worst on the cheap
          // Android this app is built for, where repainting a long list under a
          // colour tween is where frames actually go.
          themeAnimationStyle: AnimationStyle.noAnimation,
          debugShowCheckedModeBanner: false,
          // LockGate wraps the whole navigator (via builder), so the lock
          // overlay covers pushed screens too, not just the home tab.
          builder: (context, child) =>
              LockGate(store: widget.store, child: child ?? const SizedBox()),
          home: Scaffold(
            // Exhaustive on purpose. A switch over the enum with no default
            // means adding a destination is a compile error here rather than a
            // tab that silently renders Home.
            body: switch (tab) {
              Destination.home => OverviewScreen(
                store: widget.store,
                onSwitchTab: (d) => setState(() => tab = d),
              ),
              Destination.budget => BudgetScreen(store: widget.store),
              Destination.history => HistoryScreen(store: widget.store),
              Destination.utang => UtangScreen(store: widget.store),
              Destination.insights => InsightsScreen(
                store: widget.store,
                onSwitchTab: (d) => setState(() => tab = d),
              ),
              Destination.menu => MenuScreen(
                store: widget.store,
                onSwitchTab: (d) => setState(() => tab = d),
              ),
            },
            bottomNavigationBar: NavigationBar(
              selectedIndex: tab.index,
              onDestinationSelected: (i) =>
                  setState(() => tab = Destination.values[i]),
              backgroundColor: Barako.card,
              indicatorColor: Barako.primary,
              // Every glyph resolves by NAME through salapify_icon.dart, the
              // same as the rest of the app's own icons. This row was the one
              // place still reaching for raw Icons.* constants, which meant a
              // restyle of Salapify's icon set would have changed every screen
              // except the one strip visible on all of them.
              destinations: [
                for (final d in Destination.values)
                  NavigationDestination(
                    icon: Icon(salapifyIcon(d.icon)),
                    selectedIcon: Icon(
                      salapifyIconSelected(d.icon),
                      color: Barako.onPrimary,
                    ),
                    label: d.label,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
