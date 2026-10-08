// App lock (founder decisions: the phone's own lock; the setting kept out of
// backups). A fake stands in for the phone's lock and a fake clock for the
// monotonic stopwatch, so every rule can be driven exactly.
//
// The most important test here is the way OUT: a phone whose screen lock
// was removed after app lock was turned on must never lock its owner out of
// their own money.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/features/lock/app_lock.dart';
import 'package:salapify/features/log/log_sheet.dart';
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

  int askedPhoneCode = 0;
  final List<UnlockOutcome> phoneCodeAnswers = <UnlockOutcome>[];

  @override
  Future<UnlockOutcome> confirmWithPhoneCode(String reason) async {
    askedPhoneCode++;
    return phoneCodeAnswers.isEmpty
        ? UnlockOutcome.cancelled
        : phoneCodeAnswers.removeAt(0);
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

/// Leaves the app and comes back the way a phone does it, one step at a
/// time. Jumping straight from paused to resumed is a transition no phone
/// makes, and the framework asserts on it once a text field is listening.
Future<void> _leave(WidgetTester tester) async {
  for (final AppLifecycleState s in <AppLifecycleState>[
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> _return(WidgetTester tester) async {
  for (final AppLifecycleState s in <AppLifecycleState>[
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pumpAndSettle();
}

class _BrokenSettings implements LockSettingsStore {
  @override
  bool get readFailed => false;

  @override
  Future<bool> readEnabled() async => false;

  @override
  Future<void> writeEnabled(bool enabled) async =>
      throw const FileSystemException('disk full');
}

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
    await _leave(tester);
    // A paused app draws no frames, here as on a phone, so the cover is
    // checked on the controller while away and on the screen once back.
    expect(rig.lock.covered, isTrue, reason: 'not covered while away');
    rig.now += const Duration(seconds: 30);
    await _return(tester);
    expect(rig.lock.locked, isFalse);
    expect(_lockScreen, findsNothing);

    // Over a minute.
    rig.phone.answers.add(UnlockOutcome.cancelled);
    await _leave(tester);
    rig.now += const Duration(seconds: 61);
    await _return(tester);
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
    // And they are TOLD why the lock went, on a screen that stays until it
    // is read, not in a note that could expire under an open sheet.
    expect(find.textContaining('no longer has a screen lock'), findsOneWidget);
    await tester.tap(find.byKey(const Key('lock-continue')));
    await tester.pumpAndSettle();
    expect(find.textContaining('no longer has a screen lock'), findsNothing);
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

  testWidgets('Back on the lock screen keeps the half typed entry under it', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    rig.phone.answers.add(UnlockOutcome.unlocked);
    await rig.pump(tester);

    await tester.tap(find.text('Log').last);
    await tester.pumpAndSettle();
    expect(find.byType(LogSheet), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('log-amount')),
        matching: find.byType(TextField),
      ),
      '777',
    );
    await tester.pump();

    // Away long enough to relock, then Back pressed on the lock screen.
    rig.phone.answers.add(UnlockOutcome.cancelled);
    await _leave(tester);
    rig.now += const Duration(minutes: 2);
    await _return(tester);
    expect(rig.lock.locked, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    rig.phone.answers.add(UnlockOutcome.unlocked);
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();
    expect(
      find.byType(LogSheet),
      findsOneWidget,
      reason: 'Back closed the sheet hidden under the lock screen',
    );
    expect(find.text('777'), findsOneWidget);
  });

  testWidgets('a phone that sleeps still counts the time away', (
    WidgetTester tester,
  ) async {
    DateTime wall = DateTime(2026, 9, 18, 12);
    final _Rig rig = _Rig();
    final AppLockController lock = AppLockController(
      settings: rig.settings,
      authenticator: rig.phone,
      elapsed: () => rig.now,
      wall: () => wall,
      setSecureWindow: (bool _) async {},
    );
    await lock.load();
    rig.phone.answers.add(UnlockOutcome.unlocked);
    await lock.unlock();
    expect(lock.locked, isFalse);

    // The stopwatch stops while the phone sleeps: 5 seconds by it, two
    // minutes by the wall clock.
    lock.onBackground();
    rig.now += const Duration(seconds: 5);
    wall = wall.add(const Duration(minutes: 2));
    lock.onForeground();
    expect(lock.locked, isTrue, reason: 'sleep shortened the time away');
  });

  testWidgets('repeated errors offer the phone PIN and warn against '
      'uninstalling', (WidgetTester tester) async {
    final _Rig rig = _Rig();
    rig.phone.answers.add(UnlockOutcome.error);
    await rig.pump(tester);
    expect(find.byKey(const Key('lock-phone-code')), findsNothing);

    rig.phone.answers.add(UnlockOutcome.error);
    await tester.tap(find.byKey(const Key('lock-unlock')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lock-phone-code')), findsOneWidget);
    expect(find.textContaining('Do not uninstall'), findsOneWidget);

    rig.phone.phoneCodeAnswers.add(UnlockOutcome.unlocked);
    await tester.tap(find.byKey(const Key('lock-phone-code')));
    await tester.pumpAndSettle();
    expect(rig.lock.locked, isFalse);
    expect(_lockScreen, findsNothing);
  });

  testWidgets('while locked, nothing underneath can take keyboard focus', (
    WidgetTester tester,
  ) async {
    final _Rig rig = _Rig();
    await rig.pump(tester);
    expect(rig.lock.locked, isTrue);
    expect(
      find.byWidgetPredicate((Widget w) => w is ExcludeFocus && w.excluding),
      findsOneWidget,
      reason: 'the app under the lock screen can still be tabbed into',
    );
  });

  testWidgets('a lock that could not be saved is reported as still off', (
    WidgetTester tester,
  ) async {
    final _FakeLock phone = _FakeLock()..answers.add(UnlockOutcome.unlocked);
    final AppLockController lock = AppLockController(
      settings: _BrokenSettings(),
      authenticator: phone,
      setSecureWindow: (bool _) async {},
    );
    await lock.load();
    expect(await lock.enable(), contains('could not be saved'));
    expect(lock.enabled, isFalse);
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
