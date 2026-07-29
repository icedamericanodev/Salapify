// Salapify Flutter preview. The from-scratch Flutter rebuild, growing next
// to the live React Native app in mobile/ until it reaches parity. Every
// push that touches flutter/ builds an APK to the fixed flutter-preview
// release link and deploys the web preview. The Update stamp below bumps on
// every push so the founder can verify which build arrived.

import 'package:flutter/material.dart';

import 'data/store.dart';
import 'money/currencies.dart' show resolveBaseCurrency;
import 'services/home_tile.dart';
import 'services/diagnostics.dart';
import 'services/notifications.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'theme.dart';
import 'widgets/lock_gate.dart';

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
    'f2.82 \u00b7 Foreign currency accounts, kept honestly out of your peso totals.';

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
    HomeTile.attach(widget.store);
    // Recorded here, ACTED ON in shell.dart. A widget tap lands before the
    // store has loaded and before any shell exists.
    HomeTile.captureLaunch();
    // whenComplete, NOT then.
    //
    // load() awaits postDueRecurring OUTSIDE its own try/catch, and that path
    // rethrows when the write to disk fails. A full disk is an ordinary
    // condition on the cheap Android phones this app is for. With .then, one
    // such failure meant the body never ran, HomeTile.ready stayed false for
    // the whole session, and EVERY push was dropped, including the one that
    // clears the tile after "erase everything on this phone". Somebody's
    // salary would have stayed on their home screen after they erased the app.
    // Reminders.reschedule was lost the same way.
    widget.store.load().whenComplete(() {
      Reminders.reschedule(widget.store.data, DateTime.now());
      // Post-frame, so the first build has already resolved the palette and
      // the base currency. Until this runs HomeTile.ready is false and every
      // push is dropped, so the first thing ever written to the tile is never
      // the default palette or a peso sign on a dollar user.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HomeTile.ready = true;
        HomeTile.push(widget.store);
      });
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
    if (state == AppLifecycleState.paused) {
      // The user is on their way to the home screen RIGHT NOW, so this is the
      // push that matters most. It is also the cheapest place to catch a day
      // rollover: the tile is rewritten with today's date every time the app
      // goes to the background.
      HomeTile.push(widget.store);
    }
    if (state == AppLifecycleState.resumed) {
      // Recurring first, then push, so posted bills are already in the figure.
      widget.store.postDueRecurring().then((_) => HomeTile.push(widget.store));
      // Refill the schedule on every foreground, so tonight's log nudge is
      // dropped once you have logged, and new bills/utang are picked up.
      Reminders.reschedule(widget.store.data, DateTime.now());
    }
  }

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
        // The base currency resolves here for the same reason the palette
        // does: BEFORE anything below formats an amount, on every store
        // notify, so a currency change reflows every figure at once.
        resolveBaseCurrency(settings);
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
          // The tab state, the nav bar, the Log button and the per-tab scroll
          // positions all live in the shell now. This file keeps what only it
          // can do: resolving the palette before anything reads it, and the
          // lifecycle observers.
          //
          // Until load() settles, a plain background: the RN app does the
          // same, because flashing the shell at a user who is about to be
          // routed to onboarding reads as a glitch. Load is a local read and
          // settles in well under a frame's worth of patience.
          home: !widget.store.loaded
              ? Scaffold(backgroundColor: Barako.background)
              : widget.store.needsOnboarding
              ? OnboardingScreen(store: widget.store)
              : ShellScreen(store: widget.store),
        );
      },
    );
  }
}
