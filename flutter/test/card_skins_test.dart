// Card skins: the two promises that matter. A skin can never make the card's
// white text unreadable (it rides the same AA darkening every brand colour
// does), and the per account choice round-trips through local storage without
// ever touching the backup.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/services/card_skins.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the registry', () {
    test('ships exactly the four named finishes, each resolvable', () {
      expect(cardSkins.map((s) => s.id).toList(), [
        'obsidian',
        'emerald',
        'gold',
        'platinum',
      ]);
      for (final s in cardSkins) {
        expect(skinById(s.id), same(s));
      }
    });

    test('an unknown, empty, or null id resolves to no skin', () {
      expect(skinById('does-not-exist'), isNull);
      expect(skinById(''), isNull);
      expect(skinById(null), isNull);
    });
  });

  test('white text clears WCAG AA on every skin (structural guarantee)', () {
    // A skin is a seed fed through the same bankCardGradient the bank cards use,
    // which DARKENS until white clears 4.5:1. So this can never fail by
    // construction; it is here to document the inherited guarantee, not to guard
    // it. The guard that CAN fail is the distinctness test below: the real risk
    // is not an unreadable skin (impossible) but two skins that darken into the
    // same card. bank_card_test owns the falsifiable AA contract on the seed.
    for (final skin in cardSkins) {
      for (final stop in bankCardGradient(skin.seed)) {
        expect(whiteContrastOf(stop), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('every finish renders as a visibly distinct card', () {
    // The falsifiable guard: each finish, AND the neutral default, must produce
    // a base stop no other finish produces, so no two skins collapse into the
    // same look after the AA darkening. Setting two seeds equal reddens this.
    double dist(Color a, Color b) =>
        ((a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs());
    final bases = <String, Color>{
      'default': bankCardGradient(null).first,
      for (final s in cardSkins) s.id: bankCardGradient(s.seed).first,
    };
    final entries = bases.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        expect(
          dist(entries[i].value, entries[j].value),
          greaterThan(0.08),
          reason:
              '${entries[i].key} and ${entries[j].key} render too alike '
              '(${entries[i].value} vs ${entries[j].value}).',
        );
      }
    }
  });

  group('the local store', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('sets, reads, and clears a per account skin', () async {
      final store = CardSkinStore();
      await store.load();
      expect(store.skinIdFor('acct1'), isNull);

      await store.setSkin('acct1', 'gold');
      expect(store.skinIdFor('acct1'), 'gold');
      expect(store.seedFor('acct1'), const Color(0xFFB8891F));

      // Clearing removes it entirely rather than leaving a blank.
      await store.setSkin('acct1', null);
      expect(store.skinIdFor('acct1'), isNull);
      expect(store.seedFor('acct1'), isNull);
    });

    test(
      'a choice survives a reload (persisted, not just in memory)',
      () async {
        final a = CardSkinStore();
        await a.load();
        await a.setSkin('acct2', 'emerald');

        // A fresh store over the same backing must see the saved choice.
        final b = CardSkinStore();
        await b.load();
        expect(b.skinIdFor('acct2'), 'emerald');
      },
    );

    test(
      'an unknown skin id is treated as clearing, never stored raw',
      () async {
        final store = CardSkinStore();
        await store.load();
        await store.setSkin('acct3', 'gold');
        await store.setSkin('acct3', 'bogus');
        expect(store.skinIdFor('acct3'), isNull);
      },
    );
  });
}
