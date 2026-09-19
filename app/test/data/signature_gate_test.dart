import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/snapshot.dart';
import 'package:salapify/data/store.dart';

/// A valid JSON file that is not a Salapify ledger must never be loaded as an
/// empty one.
///
/// Snapshot.fromJson is deliberately tolerant, because that is how a prototype
/// backup covering nine of thirty four keys opens at all. The cost is that
/// `{}` decodes into a complete, entirely empty ledger. Without a gate the
/// loader then turns saving ON and writes that emptiness over the real file
/// within two notifications, because every notify is a save and every save
/// demotes the previous generation.
void main() {
  group('the shape check', () {
    test('a document with no Salapify parts is refused', () {
      for (final String raw in <String>[
        '{}',
        '{"foo": 1}',
        '{"version": 3, "notes": []}',
        '{"accounts": "not a list"}',
      ]) {
        expect(
          looksLikeSalapify(_decode(raw)),
          isFalse,
          reason: '$raw was accepted as a Salapify ledger',
        );
      }
    });

    test('a genuinely empty Salapify backup still passes', () {
      // Somebody who cleared everything and exported. It carries a
      // schemaVersion, so it is a real backup of nothing and must remain
      // importable. Refusing it would be refusing their own file.
      expect(looksLikeSalapify(<String, dynamic>{'schemaVersion': 1}), isTrue);
    });

    test('one collection is enough, even with no schemaVersion', () {
      expect(
        looksLikeSalapify(<String, dynamic>{'accounts': <dynamic>[]}),
        isTrue,
      );
      expect(
        looksLikeSalapify(<String, dynamic>{'transactions': <dynamic>[]}),
        isTrue,
      );
    });
  });

  group('the loader', () {
    test(
      'a JSON file that is not a ledger falls back, it does not load',
      () async {
        final MemorySnapshotStore store = MemorySnapshotStore('{"photo": {}}');
        final LoadResult r = await loadSnapshot(store);

        expect(
          r.status,
          isNot(LoadStatus.loaded),
          reason:
              'an unrelated JSON file loaded as a valid empty ledger, and the '
              'next notification would write that emptiness over the real file',
        );
        expect(r.status, LoadStatus.unreadable);
      },
    );

    test(
      'with a previous generation it recovers rather than emptying',
      () async {
        final MemorySnapshotStore store = MemorySnapshotStore('{"photo": {}}');
        store.previous =
            '{"schemaVersion":1,"accounts":[{"id":"a","name":"Mine",'
            '"kind":"cash","institution":"Cash","balance":900,"monogram":"C"}],'
            '"transactions":[]}';

        final LoadResult r = await loadSnapshot(store);
        expect(r.status, LoadStatus.recovered);
        expect(r.snapshot!.accounts.single.name, 'Mine');
      },
    );

    test('a real ledger still loads, so the gate is not simply off', () async {
      final MemorySnapshotStore store = MemorySnapshotStore(
        '{"schemaVersion":1,"accounts":[],"transactions":[]}',
      );
      expect((await loadSnapshot(store)).status, LoadStatus.loaded);
    });
  });
}

Map<String, dynamic> _decode(String raw) =>
    Map<String, dynamic>.from(jsonDecode(raw) as Map);
