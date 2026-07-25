// The diagnostics report must never carry money off the phone.
//
// Salapify's promise is that the numbers stay on the device. The diagnostics
// dump is the ONE feature that deliberately moves data off it, so it is the
// one place that promise can be broken by accident. A comment saying "counts
// only" cannot stop someone adding a field that looked harmless. This can.
//
// The store below is deliberately incriminating: a real peso amount, a shop
// name, a friend's name, a note. If any of it reaches the report, these tests
// fail and say which one.

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/services/diagnostics.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything a report must never contain, with the value and why it matters.
const _forbidden = {
  '18450': 'an amount',
  'Jollibee': 'a merchant the user visited',
  'BPI Savings': 'an account name',
  'Kuya Mark': "another person's name",
  'lunch with mom': 'a private note',
  'Groceries': 'a spending category',
};

Map<String, dynamic> _incriminatingStore() => {
  'transactions': [
    {
      'id': 't1',
      'amount': 18450,
      'note': 'lunch with mom',
      'category': 'Groceries',
      'merchant': 'Jollibee',
    },
    {'id': 't2', 'amount': 300},
  ],
  'accounts': [
    {'id': 'a1', 'name': 'BPI Savings', 'balance': 18450},
  ],
  'debts': [
    {'id': 'd1', 'name': 'Kuya Mark', 'amount': 18450},
  ],
  'goals': [],
  'utang': [
    {'id': 'u1', 'person': 'Kuya Mark', 'amount': 18450},
  ],
  'recurring': [],
  'categories': [
    {'id': 'c1', 'name': 'Groceries'},
  ],
};

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Diagnostics.clear();
  });

  group('the privacy rule', () {
    test('no amount, name, note, or category reaches the report', () {
      final report = Diagnostics.report(
        stamp: 'f9.99',
        patch: 42,
        data: _incriminatingStore(),
        platform: 'android 14',
      );
      for (final entry in _forbidden.entries) {
        expect(
          report.contains(entry.key),
          isFalse,
          reason:
              'The report leaked ${entry.value} ("${entry.key}"). This dump '
              'is pasted into a chat, so anything in it has left the phone. '
              'Counts and shapes only.',
        );
      }
    });

    test('a recorded error is trimmed and does not smuggle data through', () {
      // The realistic leak: an exception message that quotes the offending
      // value. Anything genuinely secret has to be kept out of exception
      // text in the first place, so this pins the trimming that limits the
      // blast radius rather than pretending to sanitise arbitrary strings.
      Diagnostics.record('Bad state: ${'x' * 900}', null);
      final report = Diagnostics.report(stamp: 'f9.99', platform: 'test');
      expect(report.contains('x' * 900), isFalse);
      expect(report.contains('...'), isTrue, reason: 'it should say it cut');
    });

    test('counts are still reported, because that is the useful part', () {
      final report = Diagnostics.report(
        stamp: 'f9.99',
        data: _incriminatingStore(),
        platform: 'test',
      );
      expect(report, contains('transactions: 2'));
      expect(report, contains('accounts: 1'));
      expect(report, contains('utang entries: 1'));
    });
  });

  group('recording', () {
    test('junk data never throws, it reports zeroes', () {
      for (final junk in [null, 'nope', 42, <String, dynamic>{}]) {
        final r = Diagnostics.report(stamp: 'f1.0', data: junk, platform: 't');
        expect(r, contains('transactions: 0'));
      }
    });

    test('the newest errors win when the buffer is full', () {
      for (var i = 0; i < maxRecordedErrors + 5; i++) {
        Diagnostics.record('failure number $i', null);
      }
      expect(Diagnostics.recent.length, maxRecordedErrors);
      final report = Diagnostics.report(stamp: 'f1.0', platform: 't');
      expect(
        report,
        contains('failure number ${maxRecordedErrors + 4}'),
        reason: 'the most recent failure is the one being investigated',
      );
      expect(
        report.contains('failure number 0'),
        isFalse,
        reason: 'the oldest should have been dropped',
      );
    });

    test('errors survive a restart, because a crash causes one', () async {
      Diagnostics.record('the thing that crashed', null);
      // Give the async persist a turn, then reload as a fresh start would.
      await Future<void>.delayed(Duration.zero);
      await Diagnostics.load();
      expect(
        Diagnostics.report(stamp: 'f1.0', platform: 't'),
        contains('the thing that crashed'),
        reason:
            'an error the founder cannot report after rebooting may as well '
            'not have been recorded',
      );
    });

    test('the stack keeps Salapify frames, not framework noise', () {
      Diagnostics.record(
        'boom',
        '#0      SomeWidget.build (package:flutter/src/widgets/framework.dart:1)\n'
            '#1      BudgetScreen.build (package:salapify/screens/budget.dart:99)\n'
            '#2      more framework (package:flutter/src/widgets/binding.dart:2)',
      );
      final report = Diagnostics.report(stamp: 'f1.0', platform: 't');
      expect(
        report,
        contains('package:salapify/screens/budget.dart'),
        reason: 'a stack that is all framework does not locate our bug',
      );
    });

    test('clearing empties it, so a bug can be reproduced cleanly', () async {
      Diagnostics.record('old noise', null);
      await Diagnostics.clear();
      expect(
        Diagnostics.report(stamp: 'f1.0', platform: 't'),
        contains('Recent errors: none recorded.'),
      );
    });
  });

  group('the report says which build it came from', () {
    test('stamp and patch are both present, because both are asked for', () {
      final r = Diagnostics.report(stamp: 'f2.39', patch: 33, platform: 't');
      expect(r, contains('f2.39'));
      expect(r, contains('33'));
    });

    test('no patch reads as the base build, not as a blank', () {
      final r = Diagnostics.report(stamp: 'f2.39', platform: 't');
      expect(r, contains('none (running the base build)'));
    });
  });
}
