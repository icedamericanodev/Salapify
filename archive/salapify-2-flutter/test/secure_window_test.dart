// The decision half of screen security, tested without a phone.
//
// FLAG_SECURE itself cannot be asserted on a CI runner: there is no window and
// no OS to blank a screenshot. So the native side (MainActivity.kt) is kept to
// a dumb set-or-clear, and everything that DECIDES the flag lives in
// lib/services/secure_window.dart, which is what this file drives. A mock
// method-channel handler stands in for the platform and records exactly what
// crossed it.
//
// What it proves: the flag follows App Lock, it is set the instant the lock is
// turned on and cleared when it is turned off, and an unrelated store change
// (the store notifies on every edit) does NOT cross the channel again. That
// last part is the guard against a method call on every keystroke.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/services/secure_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SalapifyStore> _store({required bool appLock}) async {
  SharedPreferences.setMockInitialValues(
    appLock
        ? {
            'salapify_data_v2': jsonEncode({
              'settings': {'appLock': true},
            }),
          }
        : {},
  );
  final store = SalapifyStore();
  await store.load();
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every setSecure call that reached the "platform", in order.
  late List<bool> calls;

  setUp(() {
    calls = <bool>[];
    SecureWindow.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SecureWindow.channel, (call) async {
          if (call.method == 'setSecure') {
            calls.add((call.arguments as Map)['secure'] as bool);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SecureWindow.channel, null);
  });

  test('apply crosses the channel only when the value changes', () async {
    await SecureWindow.apply(true);
    await SecureWindow.apply(true);
    await SecureWindow.apply(false);
    await SecureWindow.apply(false);
    await SecureWindow.apply(true);
    expect(
      calls,
      [true, false, true],
      reason:
          'the flag must be set once per real change, never repeated. A repeat '
          'means a method call on every store notify.',
    );
  });

  test('attach sets the flag ON when App Lock starts on', () async {
    final store = await _store(appLock: true);
    SecureWindow.attach(store);
    expect(
      calls,
      [true],
      reason: 'App Lock was already on at launch, so FLAG_SECURE must be set.',
    );
  });

  test('attach leaves the flag OFF when App Lock starts off', () async {
    final store = await _store(appLock: false);
    SecureWindow.attach(store);
    // apply(false) is a no-op from the initial null state (nothing to clear
    // that was never set), so nothing crosses the channel. What matters is that
    // it was never SET.
    expect(
      calls.contains(true),
      isFalse,
      reason: 'App Lock is off, so screenshots stay allowed. Never set secure.',
    );
  });

  test('turning App Lock on then off follows with the flag', () async {
    final store = await _store(appLock: false);
    SecureWindow.attach(store);
    await store.setAppLock(true);
    await store.setAppLock(false);
    expect(
      calls,
      [true, false],
      reason:
          'toggling App Lock must set then clear FLAG_SECURE, so the recents '
          'thumbnail and screenshots blank exactly while the lock is on.',
    );
  });

  test('an unrelated store change does not re-cross the channel', () async {
    final store = await _store(appLock: true);
    SecureWindow.attach(store);
    calls.clear();
    // A normal edit that notifies listeners but does not touch appLock.
    await store.setMonthlyLimit(5000);
    expect(
      calls,
      isEmpty,
      reason:
          'App Lock did not change, so nothing should cross the method channel. '
          'A call here is a method call on every edit.',
    );
  });
}
