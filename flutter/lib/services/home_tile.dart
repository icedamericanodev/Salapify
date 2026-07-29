// The bridge to the home screen tile.
//
// Same posture as services/notifications.dart: a thin plugin shell, a guarded
// no-op anywhere that is not Android, and every failure swallowed. A widget
// problem must never be able to take down the app, because the widget is a
// convenience and the ledger is not.
//
// It writes ten plain strings and asks the launcher to redraw. Every decision
// about WHAT those strings say lives in money/widget_tile.dart, which is pure
// Dart and fully tested. Nothing here decides anything, which is why nothing
// here needs to.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show Color;
import 'package:home_widget/home_widget.dart';

import '../data/store.dart';
import '../main.dart' show updateStamp;
import '../money/currencies.dart' show resolveBaseCurrency;
import '../money/widget_tile.dart';
import '../theme.dart';

class HomeTile {
  /// Must exactly equal the receiver in AndroidManifest.xml. A typo here
  /// compiles, analyzes clean, passes every other test, and produces a widget
  /// that simply never updates. widget_manifest_test.dart reads the manifest
  /// off disk and compares, which is the only reason that failure is
  /// catchable without a phone.
  static const String providerClass =
      'dev.icedamericano.salapify.YourNumberWidget';

  /// False until the first frame has been built with the loaded settings.
  ///
  /// store.load() notifies BEFORE main.dart has built with those settings, so
  /// at that instant the palette is still its initial value and the currency
  /// symbol is still the default peso. Dropping every push until after the
  /// first frame means the first thing ever written to the tile always carries
  /// the resolved palette and the person's real currency. One boolean removes
  /// a whole class of "the tile briefly had the wrong colours and a peso sign
  /// for a dollar user".
  static bool ready = false;

  /// A COLD launch tap, waiting for a shell to exist.
  ///
  /// Only ever set when [onLogTap] is null, which on a real phone means the
  /// tap arrived before the store finished loading, before the shell was
  /// built, before onboarding was even known. Calling showLogSheet at that
  /// moment opens a sheet over a blank screen or throws, so it waits.
  ///
  /// A warm tap never lands here. That distinction is the whole fix.
  static String? pendingUri;

  /// The live consumer, registered by the shell while it is mounted.
  ///
  /// The first version had no such thing: every tap was parked in
  /// [pendingUri] and the only reader was ShellScreen.initState. The shell is
  /// built inside a ListenableBuilder with no key, so its Element is reused on
  /// every store change and initState runs exactly once per process. So the
  /// Log button worked on a cold launch and never again, while the widget
  /// picker description promising it is frozen in res/ and cannot be corrected
  /// over the air.
  ///
  /// Worse than doing nothing: the unread tap survived in memory until the
  /// next shell mount and fired there, which on a fresh install is the instant
  /// onboarding finishes, on top of the first-log sheet.
  static void Function()? onLogTap;

  /// The single door every tap comes through, cold or warm.
  ///
  /// Public so a test can drive it without a platform channel. That matters:
  /// the plugin's stream cannot be pumped in a widget test, so before this
  /// existed the entire warm path had no test and shipped broken.
  static void deliver(String? uri) {
    if (uri == null || !uri.contains('log')) return;
    final handler = onLogTap;
    if (handler != null) {
      // Warm. Act now, and park nothing: a tap that has been served must not
      // also be waiting for the next mount.
      pendingUri = null;
      handler();
      return;
    }
    pendingUri = uri;
  }

  /// Wires both sources of a tap: the launch intent and the warm stream.
  static Future<void> captureLaunch() async {
    if (!_supported) return;
    try {
      deliver((await HomeWidget.initiallyLaunchedFromHomeWidget())?.toString());
      HomeWidget.widgetClicked.listen((uri) => deliver(uri?.toString()));
    } catch (_) {
      // A tap that cannot be read is a tap that opens the app and no more,
      // which is exactly what the tile promises when logging is not offered.
    }
  }

  /// Takes the parked cold-launch tap. Reading ALWAYS clears it, including
  /// when the answer is no, so a tap the shell cannot serve is dropped rather
  /// than left queued for a later mount.
  static bool takeLogRequest() {
    final wanted = pendingUri != null && pendingUri!.contains('log');
    pendingUri = null;
    return wanted;
  }

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Mirrors the store onto the tile after every change.
  ///
  /// The store itself knows nothing about widgets, deliberately: its own
  /// comment says it stays free of platform dependencies so it remains unit
  /// testable, and 144 test files rely on that.
  static void attach(SalapifyStore store) {
    store.onChanged = () => push(store);
  }

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// Everything that gets written, as a plain map.
  ///
  /// Split out of [push] because a retrospective proved the design claim was
  /// FALSE: "every decision lives in the tested pure function" was true of
  /// widget_tile.dart and not of this file. Three decisions lived here,
  /// untested, and breaking all three left 1026 tests green: which settings
  /// key means app lock, which means hide the amount, and which palette
  /// colour the Log bar takes. On a phone those are, in order, the daily
  /// number showing on a locked phone's home screen, a privacy switch that
  /// does nothing when it is flipped, and an invisible Log button.
  ///
  /// So the reads and the colour mapping are in here, where a test can drive
  /// them, and [push] is left with nothing but plumbing.
  static Map<String, String> buildValues(SalapifyStore store, DateTime now) {
    final settings = (store.data['settings'] as Map?) ?? const {};
    // formatMoneyText reads a mutable global for the currency symbol, set
    // during main.dart's build. Resolving here too costs one call and stops a
    // tile pushed from a background path carrying the wrong sign.
    resolveBaseCurrency(settings);
    return <String, String>{
      ...widgetTileStrings(
        store.data,
        now,
        canWrite: store.canWrite,
        appLock: settings['appLock'] == true,
        hideAmounts: settings['widgetHideAmount'] == true,
        stamp: updateStamp.split(' ').first,
      ),
      // The palette follows the chosen THEME, and is pinned to that theme's
      // DARK side whatever the app is currently showing.
      //
      // Not a preference. widget_bg.xml fixes the card at #251A13 on every
      // phone, because a rounded background colour cannot be set from
      // RemoteViews before API 31 and half the launch audience is still on
      // Android 11. So the card is always dark and the text must always be
      // the text that reads on a dark card.
      //
      // Sending Barako.current instead put #241812 on #251A13 in light mode,
      // a contrast ratio of 1.02 to 1. Invisible, not merely dim. The default
      // appearance is 'system' and most phones ship light, so that was the
      // default experience of the whole feature. widget_contrast_test measures
      // every theme at both brightnesses against the literal card colour.
      'yn_text': _hex(Barako.currentTheme.dark.text),
      'yn_muted': _hex(Barako.currentTheme.dark.muted),
      'yn_accent': _hex(Barako.currentTheme.dark.primary),
    };
  }

  /// The last map that reached the launcher, so an unchanged one costs nothing.
  static Map<String, String>? _lastPushed;

  /// Recomputes and writes every string. Safe to call as often as you like.
  static Future<void> push(SalapifyStore store) async {
    if (!_supported || !ready) return;
    final values = buildValues(store, DateTime.now());
    // Every store change pushes, and some screens change the store on a timer:
    // the notes editor debounce-saves every 600ms of typing. Without this
    // check that was ten platform round trips plus a broadcast asking the
    // launcher to re-inflate the tile, every 600ms, while somebody typed a
    // note that cannot change a single string on it. The "as of" line carries
    // the minute, so a genuine change still gets through within the minute.
    if (_lastPushed != null && _sameAs(values)) return;
    // Cleared BEFORE the writes, so a failure partway through cannot leave a
    // stale map claiming the launcher is up to date.
    _lastPushed = null;
    for (final e in values.entries) {
      try {
        // deleteFile: false skips a read-back round trip per key that only
        // matters for stored file paths, which this never writes.
        await HomeWidget.saveWidgetData<String>(
          e.key,
          e.value,
          deleteFile: false,
        );
      } catch (_) {
        // Per key, not around the whole loop. updateWidget is the LAST call,
        // so one failed key used to skip the redraw entirely and leave the
        // launcher rendering the previous peso figure forever, since
        // updatePeriodMillis is 0 and nothing else ever repaints it. Nine
        // correct strings and one stale one beats ten stale ones.
      }
    }
    try {
      await HomeWidget.updateWidget(qualifiedAndroidName: providerClass);
      _lastPushed = values;
    } catch (_) {
      // A launcher that refuses the broadcast, a missing native side, a phone
      // in a strange state. None of it is worth surfacing to somebody who is
      // trying to log an expense.
    }
  }

  static bool _sameAs(Map<String, String> values) {
    final last = _lastPushed!;
    if (last.length != values.length) return false;
    for (final e in values.entries) {
      if (last[e.key] != e.value) return false;
    }
    return true;
  }
}
