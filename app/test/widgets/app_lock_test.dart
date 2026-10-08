// App lock (founder decisions: the phone's own lock; the setting kept out of
// backups). A fake stands in for the phone's lock and a fake clock for the
// monotonic stopwatch, so every rule can be driven exactly.
//
// The most important test here is the way OUT: a phone whose screen lock
// was removed after app lock was turned on must never lock its owner out of
// their own money.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/features/lock/app_lock.dart';
import 'package:salapify/main.dart';
import 'package:salapify/state/financial_state.dart';

class _FakeLock implements LockAuthenticator {
  final List<UnlockOutcome> answers = <UnlockOutcome>[];
  int asked = 0;

  @override
  Future<UnlockOutcome> authenticate(String reason) async {
    asked++;
    return answers.isEmpty ? UnlockOutcome.cancelled : answers.removeAt(0);
  }
}

class _Rig {
  _Rig({bool enabled = true})
    : settings = MemoryLockSettings(enabled),
      phone = _FakeLock();

  final MemoryLockSettings settings;
  final _FakeLock phone;
  Duration now = Duration.zero;
  final List<bool> secure = <bool>[];
  late final AppLockController lock = AppLockController(
    settings: settings,
    authenticator: phone,
    elapsed: () => now,
    setSecureWindow: (bool on) async => secure.add(on),
  );

  Future<FinancialState> pump(WidgetTester tester) async {
    final FinancialState state = FinancialState(
      clock: DateTime(2026, 9, 18, 12),
      store: MemorySnapshotStore(),
    );
    await state.restore();
    state.startWithExampleData();
    await lock.load();
    await tester.pumpWidget(SalapifyApp(state: state, lock: lock));
    await tester.pumpAndSettle();
    return state;
  }
}

final Finder _lockScreen = find.text('Salapify is locked');

void main() {
  testWidgets('off by default: the app opens with no lock screen', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig(enabled: false);
    await rig.pump(tester);
    expect(_lockScreen, findsNothing);
    expect(rig.phone.asked, 0);
  });

  testWidgets('on: a cold start is locked, asks once, and opens on success', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    // The automatic prompt is backed out of.
    rig.phone.answers.add(UnlockOutcome.cancelled);
    await rig.pump(tester);

    expect(_lockScreen, findsOneWidget);
    expect(rig.phone.asked, 1, reason: 'the prompt must come once, not loop');
    expect(rig.lock.locked, isTrue);

    rig.phone.answers.add(UnlockOutcome.unlocked);
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();
    expect(_lockScreen, findsNothing);
    expect(rig.lock.locked, isFalse);
  });

  testWidgets('a minute away locks again; a quick hop does not', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    rig.phone.answers.add(UnlockOutcome.unlocked);
    await rig.pump(tester);
    expect(rig.lock.locked, isFalse);

    // Thirty seconds in GCash and back.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    // A paused app draws no frames, here as on a phone, so the cover is
    // checked on the controller while away and on the screen once back.
    expect(rig.lock.covered, isTrue, reason: 'not covered while away');
    rig.now += const Duration(seconds: 30);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(rig.lock.locked, isFalse);
    expect(_lockScreen, findsNothing);

    // Over a minute.
    rig.phone.answers.add(UnlockOutcome.cancelled);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    rig.now += const Duration(seconds: 61);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(rig.lock.locked, isTrue, reason: 'a minute away did not relock');
    expect(_lockScreen, findsOneWidget);
  });

  testWidgets('a phone with no screen lock any more is let in, never trapped', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    rig.phone.answers.add(UnlockOutcome.unavailable);
    await rig.pump(tester);

    expect(
      _lockScreen,
      findsNothing,
      reason: 'the owner was locked out of their own money',
    );
    expect(rig.lock.enabled, isFalse);
    expect(rig.settings.enabled, isFalse, reason: 'the setting stayed on');
    // And they are TOLD why the lock went, not left to wonder.
    expect(find.textContaining('no longer has a screen lock'), findsOneWidget);
  });

  testWidgets('turning it on needs the phone lock; a phone without one says '
      'so and stays off', (WidgetTester tester) async {
    final _Rig rig = _Rig(enabled: false);
    await rig.pump(tester);

    rig.phone.answers.add(UnlockOutcome.unavailable);
    expect(await rig.lock.enable(), contains('Set a screen lock'));
    expect(rig.lock.enabled, isFalse);
    expect(rig.settings.enabled, isFalse);

    rig.phone.answers.add(UnlockOutcome.unlocked);
    expect(await rig.lock.enable(), isNull);
    expect(rig.lock.enabled, isTrue);
    expect(rig.settings.enabled, isTrue);
    expect(rig.secure.last, isTrue, reason: 'screenshots were not shielded');
  });

  testWidgets('turning it off needs the phone lock too', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    rig.phone.answers.add(UnlockOutcome.unlocked);
    await rig.pump(tester);

    rig.phone.answers.add(UnlockOutcome.cancelled);
    expect(await rig.lock.disable(), isNotNull);
    expect(rig.lock.enabled, isTrue, reason: 'switched off without the lock');

    rig.phone.answers.add(UnlockOutcome.unlocked);
    expect(await rig.lock.disable(), isNull);
    expect(rig.lock.enabled, isFalse);
    expect(rig.secure.last, isFalse);
  });

  testWidgets('delete everything takes app lock with it', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    rig.phone.answers.add(UnlockOutcome.unlocked);
    await rig.pump(tester);
    await rig.lock.wipe();
    expect(rig.lock.enabled, isFalse);
    expect(rig.settings.enabled, isFalse);
  });
}
