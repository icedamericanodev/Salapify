// App Lock (LockGate) behavior, with a fake authenticator so no real biometric
// platform channel is needed. Covers: off is transparent, a successful unlock
// clears the overlay, no enrolled biometrics disables the lock rather than
// stranding the owner, and a failed unlock stays locked with a retry.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/lock_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth implements LockAuthenticator {
  final bool can;
  final bool auth;
  int authCalls = 0;
  _FakeAuth({this.can = true, this.auth = true});

  @override
  Future<bool> canLock() async => can;

  @override
  Future<bool> authenticate() async {
    authCalls++;
    return auth;
  }
}

Future<SalapifyStore> _store({required bool appLock}) async {
  SharedPreferences.setMockInitialValues(appLock
      ? {
          'salapify_data_v2': jsonEncode({
            'settings': {'appLock': true},
          }),
        }
      : {});
  final store = SalapifyStore();
  await store.load();
  return store;
}

Future<void> _pump(WidgetTester tester, SalapifyStore store, _FakeAuth auth) async {
  Barako.currentTheme = themeForKey('barako');
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(MaterialApp(
    home: LockGate(
      store: store,
      authenticator: auth,
      child: const Scaffold(body: Center(child: Text('SECRET'))),
    ),
  ));
  // The lock prompt is scheduled in a post-frame callback and its biometric
  // check resolves across a few microtask hops; pump a handful of times so the
  // whole async unlock chain completes before we assert.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('off: the gate is transparent, no lock overlay', (tester) async {
    final store = await _store(appLock: false);
    final auth = _FakeAuth();
    await _pump(tester, store, auth);
    expect(find.text('Salapify is locked'), findsNothing);
    expect(find.text('SECRET'), findsOneWidget);
    expect(auth.authCalls, 0);
  });

  testWidgets('on: a successful biometric unlock clears the overlay',
      (tester) async {
    final store = await _store(appLock: true);
    final auth = _FakeAuth(can: true, auth: true);
    await _pump(tester, store, auth);
    // The prompt fired and succeeded, so the lock is gone.
    expect(auth.authCalls, 1);
    expect(find.text('Salapify is locked'), findsNothing);
  });

  testWidgets('on with no enrolled biometrics: the lock disables itself',
      (tester) async {
    final store = await _store(appLock: true);
    final auth = _FakeAuth(can: false);
    await _pump(tester, store, auth);
    // Never authenticated (can't), turned App lock off so the owner is not
    // stranded, and revealed the app.
    expect(auth.authCalls, 0);
    expect((store.data['settings'] as Map)['appLock'], false);
    expect(find.text('Salapify is locked'), findsNothing);
  });

  testWidgets('on with a failed unlock: stays locked with a retry',
      (tester) async {
    final store = await _store(appLock: true);
    final auth = _FakeAuth(can: true, auth: false);
    await _pump(tester, store, auth);
    // Prompt fired but failed, so the overlay and its Unlock button remain.
    expect(auth.authCalls, 1);
    expect(find.text('Salapify is locked'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    // App lock stays on (a failure must not disable it).
    expect((store.data['settings'] as Map)['appLock'], true);
  });

  testWidgets('backgrounding covers the app; a quick return does not re-prompt',
      (tester) async {
    final store = await _store(appLock: true);
    final auth = _FakeAuth(can: true, auth: true);
    await _pump(tester, store, auth);
    // Unlocked after the initial successful auth, so no overlay.
    expect(find.text('Salapify is locked'), findsNothing);
    expect(auth.authCalls, 1);

    // Background: the cover appears so the recents thumbnail hides the money.
    // (inactive is the valid first step away from resumed; the handler treats
    // inactive/paused/hidden alike.)
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Salapify is locked'), findsOneWidget);

    // Return within the grace window: the cover lifts with no new prompt.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Salapify is locked'), findsNothing);
    expect(auth.authCalls, 1);
  });
}
