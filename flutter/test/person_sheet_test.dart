// The person sheet, once it became a place you can act FROM rather than just
// look at. Three things get guarded here, and all three are about a document
// or a message that leaves the phone and lands in someone else's chat app:
//
//   1. What is actually shared. The share seam is injected so these tests
//      read the real built text. A test that only proves a "Share statement"
//      button exists proves nothing about the statement, and the statement is
//      the feature.
//   2. Who the statement covers. It must include utang they already paid, or
//      it can neither prove they paid nor add up to what was really lent.
//   3. When Remind is offered at all. A reminder about nothing is an
//      accusation, so it must not be reachable on a settled person.
//
// The build itself is golden locked byte for byte in statement_golden_test;
// this file proves the screen hands it the right data and the right moment.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/utang.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _blob({
  List<Map<String, dynamic>>? receivables,
  List<Map<String, dynamic>>? people,
}) => {
  'schemaVersion': 12,
  'settings': {'onboarded': true},
  'people':
      people ??
      [
        {'id': 'per1', 'name': 'Ana'},
      ],
  'receivables':
      receivables ??
      [
        {
          'id': 'r1',
          'personId': 'per1',
          'person': 'Ana',
          'amount': 5000,
          'note': 'Emergency',
          'dueDate': '2026-06-30',
          'payments': [
            {'id': 'p1', 'amount': 1500, 'date': '2026-07-10'},
          ],
        },
        {
          'id': 'r2',
          'personId': 'per1',
          'person': 'Ana',
          'amount': 800,
          'note': 'Load',
          'paid': true,
          'payments': [
            {'id': 'p2', 'amount': 800, 'date': '2026-05-20'},
          ],
        },
      ],
};

/// Opens the sheet with the share seam captured. Returns the store and a list
/// that fills with whatever text the sheet tries to send.
Future<(SalapifyStore, List<String>)> _open(
  WidgetTester tester, {
  Map<String, dynamic>? blob,
  String name = 'Ana',
}) async {
  SharedPreferences.setMockInitialValues({
    storageKey: jsonEncode(blob ?? _blob()),
  });
  final store = SalapifyStore();
  await store.load();
  final sent = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // A tall body so the whole sheet is laid out; a ListView never builds
        // what is off screen, and an assertion on an unbuilt row is an
        // assertion on nothing.
        body: SizedBox(
          height: 2000,
          child: PersonSheet(
            store: store,
            name: name,
            share: (text) async => sent.add(text),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (store, sent);
}

Future<void> _tapThrough(
  WidgetTester tester,
  String action,
  String language,
) async {
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
  await tester.tap(find.text(language));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the shared statement covers utang they already paid', (
    tester,
  ) async {
    // The bug this guards: the sheet gathered only OPEN utang, so a statement
    // built from it would show Total lent ₱5,000 when ₱5,800 was really lent,
    // and would silently omit the ₱800 they had already settled. A person
    // reading it would see themselves accused of never paying the Load.
    final (_, sent) = await _open(tester);
    await _tapThrough(tester, 'Share statement', 'English');

    expect(sent, hasLength(1));
    final text = sent.single;
    expect(text, contains('For: Ana'));
    expect(text, contains('Emergency'));
    expect(text, contains('Load'), reason: 'the settled utang must be in it');
    expect(text, contains('Total lent: ₱5,800'));
    expect(text, contains('Total paid: ₱2,300'));
    expect(text, contains('STILL OPEN: ₱3,500'));
  });

  testWidgets('the statement can be sent in Tagalog', (tester) async {
    final (_, sent) = await _open(tester);
    await _tapThrough(tester, 'Share statement', 'Tagalog');
    expect(sent.single, contains('Para kay: Ana'));
    expect(sent.single, contains('NATITIRA: ₱3,500'));
  });

  testWidgets('cancelling the language picker sends nothing', (tester) async {
    final (_, sent) = await _open(tester);
    await tester.tap(find.text('Share statement'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sent, isEmpty, reason: 'a cancelled share must not send');
  });

  testWidgets('Remind sends the total still owed, not the total lent', (
    tester,
  ) async {
    final (_, sent) = await _open(tester);
    await _tapThrough(tester, 'Remind', 'English');
    expect(sent.single, contains('₱3,500'));
    expect(
      sent.single,
      isNot(contains('₱5,800')),
      reason: 'reminding someone of money they already paid back',
    );
  });

  testWidgets('a settled person cannot be reminded, only documented', (
    tester,
  ) async {
    final (_, sent) = await _open(
      tester,
      blob: _blob(
        receivables: [
          {
            'id': 'r1',
            'personId': 'per1',
            'person': 'Ana',
            'amount': 800,
            'note': 'Load',
            'paid': true,
            'payments': [
              {'id': 'p2', 'amount': 800, 'date': '2026-05-20'},
            ],
          },
        ],
      ),
    );
    expect(find.text('Remind'), findsNothing);
    await _tapThrough(tester, 'Share statement', 'English');
    expect(sent.single, contains('FULLY PAID'));
  });

  testWidgets('a person with no utang at all offers nothing to send', (
    tester,
  ) async {
    final (_, sent) = await _open(
      tester,
      blob: _blob(receivables: []),
      name: 'Ana',
    );
    expect(find.text('Share statement'), findsNothing);
    expect(find.text('Remind'), findsNothing);
    expect(sent, isEmpty);
  });

  testWidgets('the payment history shows every payment, newest first', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('PAYMENT HISTORY'), findsOneWidget);
    // Both payments, across two different utang, one of them settled. The
    // running figure counts DOWN as the list is read, because each row says
    // how much they had paid back BY that payment, not how much is left.
    expect(find.text('₱2,300 paid by then'), findsOneWidget);
    expect(find.text('₱800 paid by then'), findsOneWidget);
  });

  testWidgets('a settled utang is listed but carries no buttons', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('SETTLED'), findsOneWidget);
    // find.text, not textContaining: the payment history below carries
    // "₱800 paid by then", and a loose matcher would pass on that row while
    // the settled list was empty.
    expect(find.text('₱800 paid'), findsOneWidget);
    // One open utang, so exactly one set of action buttons.
    expect(find.text('Log payment'), findsOneWidget);
    expect(find.text('Mark paid'), findsOneWidget);
  });

  testWidgets('two people who share a name get two separate statements', (
    tester,
  ) async {
    // QA's worst finding. Both gathers keyed on the lowercased NAME, so two
    // people called Ana were merged, and the statement sent to Ana number one
    // billed her for the other Ana's ₱7,000. This is reachable from a plain
    // RN backup: the RN person screen renames with no uniqueness check.
    final blob = _blob(
      people: const [
        {'id': 'per1', 'name': 'Ana'},
        {'id': 'per2', 'name': 'Ana'},
      ],
      receivables: [
        {'id': 'r1', 'personId': 'per1', 'amount': 1000, 'note': 'Ana one'},
        {'id': 'r2', 'personId': 'per2', 'amount': 7000, 'note': 'Ana two'},
      ],
    );
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(blob)});
    final store = SalapifyStore();
    await store.load();
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 2000,
            child: PersonSheet(
              store: store,
              name: 'Ana',
              personId: 'per1',
              share: (text) async => sent.add(text),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapThrough(tester, 'Share statement', 'English');

    expect(sent.single, contains('Ana one'));
    expect(
      sent.single,
      isNot(contains('Ana two')),
      reason: "billing one person for a different person's debt",
    );
    expect(sent.single, contains('Total lent: ₱1,000'));
  });

  testWidgets('the settled row shows the utang, not what is left of it', (
    tester,
  ) async {
    // Two QA findings in one row. A ₱2,000 utang marked paid with a ₱750
    // logged payment printed "₱1,250 paid", which is what was LEFT. And a
    // stored amount of "2400" (a string, from a restored backup) is not a
    // num, so the row read "₱0 paid" beside a statement saying ₱2,400.
    await _open(
      tester,
      blob: _blob(
        receivables: [
          {
            'id': 'r1',
            'personId': 'per1',
            'amount': 2000,
            'note': 'Short',
            'paid': true,
            'payments': [
              {'id': 'p1', 'amount': 750, 'date': '2026-07-01'},
            ],
          },
          {
            'id': 'r2',
            'personId': 'per1',
            'amount': '2400',
            'note': 'Stringy',
            'paid': true,
          },
        ],
      ),
    );
    expect(find.text('₱2,000 paid'), findsOneWidget);
    expect(find.text('₱2,400 paid'), findsOneWidget);
    expect(find.text('₱1,250 paid'), findsNothing);
    expect(find.text('₱0 paid'), findsNothing);
  });

  testWidgets('a statement with centavos adds up in front of two people', (
    tester,
  ) async {
    // QA: the RN whole peso formatter printed two ₱100.50 utang as "₱101" and
    // "₱101" over "Total lent: ₱201", so the friend holding it adds 101 and
    // 101 and gets 202. The document has to survive being checked by hand,
    // which is the entire reason it exists.
    final (_, sent) = await _open(
      tester,
      blob: _blob(
        receivables: [
          {'id': 'r1', 'personId': 'per1', 'amount': 100.50, 'note': 'Jeep'},
          {'id': 'r2', 'personId': 'per1', 'amount': 100.50, 'note': 'Load'},
        ],
      ),
    );
    await _tapThrough(tester, 'Share statement', 'English');
    expect(sent.single, contains('Jeep   ₱100.50'));
    expect(sent.single, contains('Total lent: ₱201'));
    expect(sent.single, contains('STILL OPEN: ₱201'));
    expect(sent.single, isNot(contains('₱101')));
  });

  testWidgets('a failed share says so instead of doing nothing', (
    tester,
  ) async {
    // QA: every exception was swallowed with a comment about the user closing
    // the sheet. With no share target installed, the person picked a language
    // and then absolutely nothing happened, with no explanation at all.
    SharedPreferences.setMockInitialValues({storageKey: jsonEncode(_blob())});
    final store = SalapifyStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 2000,
            child: PersonSheet(
              store: store,
              name: 'Ana',
              share: (_) async => throw StateError('no share target'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapThrough(tester, 'Share statement', 'English');
    expect(
      find.textContaining('Could not open the share sheet'),
      findsOneWidget,
    );
  });

  testWidgets('every payment is listed once, and stays removable', (
    tester,
  ) async {
    // QA: payments were listed on the utang card AND under PAYMENT HISTORY,
    // so every one appeared twice on the same sheet, once with a remove
    // action and once without. A person with 200 payments rendered 400 rows.
    await _open(tester);
    expect(find.textContaining('Jul 10'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('a payment from another year says which year', (tester) async {
    // QA: prettyDay prints "Jul 10" with no year, in a list whose only job is
    // chronological order, so 2025-07-10 and 2026-07-10 read identically.
    await _open(
      tester,
      blob: _blob(
        receivables: [
          {
            'id': 'r1',
            'personId': 'per1',
            'amount': 5000,
            'note': 'Old',
            'payments': [
              {'id': 'p1', 'amount': 100, 'date': '2019-07-10'},
            ],
          },
        ],
      ),
    );
    expect(find.textContaining('Jul 10, 2019'), findsOneWidget);
  });

  testWidgets('a legacy name-only utang still gets a statement', (
    tester,
  ) async {
    // Utang logged before person records existed carry a name string and no
    // personId. They have to reach the same document, or the people who have
    // used the app longest get the emptiest statements.
    final (_, sent) = await _open(
      tester,
      blob: _blob(
        people: const [],
        receivables: [
          {'id': 'r1', 'person': 'Ana', 'amount': 1200, 'note': 'Ticket'},
        ],
      ),
    );
    await _tapThrough(tester, 'Share statement', 'English');
    expect(sent.single, contains('For: Ana'));
    expect(sent.single, contains('Ticket'));
    expect(sent.single, contains('STILL OPEN: ₱1,200'));
  });
}
