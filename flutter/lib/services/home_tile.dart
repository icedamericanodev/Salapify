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

  /// Recomputes and writes every string. Safe to call as often as you like.
  static Future<void> push(SalapifyStore store) async {
    if (!_supported || !ready) return;
    try {
      final settings = (store.data['settings'] as Map?) ?? const {};
      // formatMoneyText reads a mutable global for the currency symbol, and
      // it is set during main.dart's build. Resolving here too costs one call
      // and stops a tile pushed from a background path carrying the wrong
      // sign.
      resolveBaseCurrency(settings);
      final values = <String, String>{
        ...widgetTileStrings(
          store.data,
          DateTime.now(),
          canWrite: store.canWrite,
          appLock: settings['appLock'] == true,
          hideAmounts: settings['widgetHideAmount'] == true,
          stamp: updateStamp.split(' ').first,
        ),
        // The palette follows the theme picker. Only TEXT colours cross: the
        // background is fixed in XML, because a rounded background colour
        // cannot be set from RemoteViews before API 31.
        'yn_text': _hex(Barako.text),
        'yn_muted': _hex(Barako.muted),
        'yn_accent': _hex(Barako.primary),
      };
      for (final e in values.entries) {
        // deleteFile: false skips a read-back round trip per key that only
        // matters for stored file paths, which this never writes.
        await HomeWidget.saveWidgetData<String>(
          e.key,
          e.value,
          deleteFile: false,
        );
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: providerClass);
    } catch (_) {
      // A launcher that refuses the broadcast, a missing native side, a phone
      // in a strange state. None of it is worth surfacing to somebody who is
      // trying to log an expense.
    }
  }
}
