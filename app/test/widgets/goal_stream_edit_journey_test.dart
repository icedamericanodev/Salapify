import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/main.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/state/financial_state.dart';

/// Editing and removing a goal or an income stream (D31, 2026-10-09). Until
/// then both could be added and never changed.
///
/// Each step is checked twice: in the store, and on the screen a person is
/// looking at. Every remove is undone again to prove the way back works, and
/// the store is reopened to prove the change was saved, not only shown.
Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<(FinancialState, MemorySnapshotStore)> _open(
  WidgetTester tester,
  String segment,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
  final MemorySnapshotStore store = MemorySnapshotStore();
  final FinancialState state = FinancialState(
    clock: DateTime(2026, 9, 18, 12),
    store: store,
  );
  await state.restore();
  state.startWithExampleData();
  await tester.pumpWidget(SalapifyApp(state: state));
  await tester.pumpAndSettle();
  await _tap(tester, find.byIcon(Icons.track_changes_outlined));
  await _tap(tester, find.text(segment).first);
  return (state, store);
}

Future<FinancialState> _reopen(
  FinancialState state,
  MemorySnapshotStore store,
) async {
  await state.flushWrites();
  final FinancialState again = FinancialState(
    clock: DateTime(2026, 9, 18, 12),
    store: store,
  );
  await again.restore();
  return again;
}

Finder _field(String key) =>
    find.descendant(of: find.byKey(Key(key)), matching: find.byType(TextField));

void main() {
  testWidgets('a goal can be edited, keeps its progress, and is saved', (
    WidgetTester tester,
  ) async {
    final (FinancialState state, MemorySnapshotStore store) = await _open(
      tester,
      'Goals',
    );
    final Goal before = state.goals.firstWhere(
      (Goal g) => g.id == 'goal_japan',
    );
    final int countBefore = state.goals.length;

    await _tap(tester, find.byKey(const ValueKey<String>('goal-goal_japan')));
    expect(find.text('Edit goal'), findsOneWidget);
    await tester.enterText(_field('goal-target'), '123456');
    await tester.enterText(_field('goal-name'), 'Japan trip 2027');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save goal'));

    final Goal after = state.goals.firstWhere((Goal g) => g.id == 'goal_japan');
    expect(after.targetAmount, const Money.pesos(123456));
    expect(after.name, 'Japan trip 2027');
    expect(
      after.currentAmount,
      before.currentAmount,
      reason: 'editing the target lost the progress already made',
    );
    expect(
      state.goals.length,
      countBefore,
      reason: 'the edit added a second goal',
    );
    // On the screen, under its new name.
    expect(find.text('Japan trip 2027'), findsOneWidget);

    final FinancialState again = await _reopen(state, store);
    expect(
      again.goals.firstWhere((Goal g) => g.id == 'goal_japan').targetAmount,
      const Money.pesos(123456),
    );
  });

  testWidgets('removing a goal asks first, moves no money, and Undo brings '
      'it back', (WidgetTester tester) async {
    final (FinancialState state, MemorySnapshotStore store) = await _open(
      tester,
      'Goals',
    );
    final Money worth = state.accounts.fold(
      Money.zero,
      (Money s, Account a) => s + a.balance,
    );
    final String name = state.goals
        .firstWhere((Goal g) => g.id == 'goal_japan')
        .name;
    final int indexBefore = state.goals.indexWhere(
      (Goal g) => g.id == 'goal_japan',
    );

    await _tap(tester, find.byKey(const ValueKey<String>('goal-goal_japan')));
    await _tap(tester, find.byKey(const Key('remove-goal')));
    // Keep it changes nothing.
    await _tap(tester, find.text('Keep it'));
    expect(state.goals.any((Goal g) => g.id == 'goal_japan'), isTrue);

    await _tap(tester, find.byKey(const Key('remove-goal')));
    await _tap(tester, find.text('Remove'));
    expect(state.goals.any((Goal g) => g.id == 'goal_japan'), isFalse);
    expect(find.text(name), findsNothing, reason: 'still on the screen');
    expect(
      state.accounts.fold(Money.zero, (Money s, Account a) => s + a.balance),
      worth,
      reason: 'a goal never held money, so removing it must move none',
    );

    await _tap(tester, find.text('Undo'));
    expect(
      state.goals.indexWhere((Goal g) => g.id == 'goal_japan'),
      indexBefore,
      reason: 'Undo put it back somewhere else in the list',
    );
    expect(state.goals.any((Goal g) => g.id == 'goal_japan'), isTrue);
    expect(find.text(name), findsOneWidget);
    final FinancialState again = await _reopen(state, store);
    expect(again.goals.any((Goal g) => g.id == 'goal_japan'), isTrue);
  });

  testWidgets('an income stream can be edited and removed, with Undo', (
    WidgetTester tester,
  ) async {
    final (FinancialState state, MemorySnapshotStore store) = await _open(
      tester,
      'Decisions',
    );

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('stream-stream_freelance')),
    );
    await tester.enterText(_field('stream-amount'), '20000');
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Save stream'));
    expect(
      state.incomeStreams
          .firstWhere((IncomeStream s) => s.id == 'stream_freelance')
          .expectedAmount,
      const Money.pesos(20000),
    );
    expect(find.text('₱20,000.00'), findsWidgets);

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('stream-stream_freelance')),
    );
    await _tap(tester, find.byKey(const Key('remove-stream')));
    await _tap(tester, find.text('Remove'));
    expect(
      state.incomeStreams.any((IncomeStream s) => s.id == 'stream_freelance'),
      isFalse,
    );
    expect(
      find.byKey(const ValueKey<String>('stream-stream_freelance')),
      findsNothing,
    );

    await _tap(tester, find.text('Undo'));
    final FinancialState again = await _reopen(state, store);
    expect(
      again.incomeStreams
          .firstWhere((IncomeStream s) => s.id == 'stream_freelance')
          .expectedAmount,
      const Money.pesos(20000),
      reason: 'Undo brought back a different stream than the one removed',
    );
  });
}
