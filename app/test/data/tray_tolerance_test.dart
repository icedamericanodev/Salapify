import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/json_codec.dart';
import 'package:salapify/data/snapshot.dart';

/// A message must never cost somebody their ledger.
///
/// Every other collection throws on a bad field, and that is right: a balance
/// this build cannot read has to stop the load, because a file left untouched
/// can still be recovered while a guessed number cannot.
///
/// The tray is different in kind. It is derived, disposable data, rebuilt from
/// the ledger every time the app opens. Rejecting a whole document over one
/// message would make accounts, entries and debts unreadable, which turns
/// saving OFF entirely and shows the red panel, all over a notification.
void main() {
  String doc(String notifications) =>
      '{"accounts":[{"id":"a1","name":"Everyday","kind":"bank",'
      '"institution":"Somewhere","balance":23400,"monogram":"EV"}],'
      '"transactions":[],"notifications":$notifications}';

  test('a message with a kind this build does not know is skipped', () {
    // A future Salapify, or a third party file, can carry a reminder kind
    // this version has never heard of.
    final Snapshot s = Snapshot.decode(
      doc('[{"id":"n1","type":"budget_alert","title":"t","body":"b"}]'),
    );

    expect(
      s.accounts,
      hasLength(1),
      reason:
          'one unreadable message rejected the whole document, which turns '
          'saving off and shows the red panel over a notification',
    );
    expect(s.accounts.first.balance, 23400);
    expect(s.notifications, isEmpty);
  });

  test('a message missing a required field is skipped, the rest survive', () {
    final Snapshot s = Snapshot.decode(
      doc(
        '[{"id":"n1","type":"bill_due","title":"Bill due","body":"b",'
        '"timestamp":1,"isRead":false},'
        '{"id":"n2","type":"bill_due","title":"No body"}]',
      ),
    );

    expect(s.accounts, hasLength(1));
    expect(
      s.notifications,
      hasLength(1),
      reason: 'a good message was dropped along with the bad one',
    );
    expect(s.notifications.first.title, 'Bill due');
  });

  test('rubbish in place of the list is ignored rather than fatal', () {
    expect(Snapshot.decode(doc('"not a list"')).accounts, hasLength(1));
    expect(Snapshot.decode(doc('[1, 2, "three"]')).accounts, hasLength(1));
  });

  test('a bad ACCOUNT still stops the load, which is the whole point', () {
    // The other half of the alarm. Being lenient everywhere would mean a
    // ledger with an unreadable balance loading as if it were fine, and then
    // being saved over.
    expect(
      () => Snapshot.decode(
        '{"accounts":[{"id":"a1","name":"Everyday","kind":"bank",'
        '"institution":"Somewhere","balance":"not a number","monogram":"EV"}]}',
      ),
      throwsA(isA<SnapshotFormatException>()),
    );
  });

  test('a good tray still round trips', () {
    final Snapshot s = Snapshot.decode(
      doc(
        '[{"id":"n1","type":"payment_due","title":"Payment due","body":"x",'
        '"timestamp":1750000000000,"isRead":true}]',
      ),
    );
    expect(s.notifications, hasLength(1));
    expect(s.notifications.first.isRead, isTrue);
    expect(s.notifications.first.createdAt, 1750000000000);

    final String again = s.encode(at: DateTime.utc(2026, 9, 19));
    expect(Snapshot.decode(again).notifications, hasLength(1));
  });
}
