import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/design/institution_brand.dart';
import 'package:salapify/design/institution_mark.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/data/seed_data.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/accounts/bank_card.dart';

/// The institutions' own marks, and the card they sit on.
void main() {
  group('the bundled marks', () {
    test('every declared asset is actually on disk', () {
      // A typo in an asset path does not crash and does not fail a widget
      // test: Image.asset's errorBuilder quietly swaps in the monogram, so
      // the bank simply never gets its logo and nobody finds out. This is the
      // only place that can catch it.
      final List<String> missing = <String>[
        for (final InstitutionBrand b in allBrands)
          if (b.asset != null && !File(b.asset!).existsSync()) b.asset!,
      ];
      expect(missing, isEmpty, reason: 'declared but not shipped: $missing');
    });

    test('every shipped file is declared, so nothing ships unused', () {
      final Directory dir = Directory('assets/brand/institutions');
      expect(dir.existsSync(), isTrue);

      final Set<String> declared = <String>{
        for (final InstitutionBrand b in allBrands)
          if (b.asset != null) b.asset!,
      };
      final List<String> orphans = <String>[
        for (final FileSystemEntity f in dir.listSync())
          if (f is File && !declared.contains(f.path)) f.path,
      ];
      expect(orphans, isEmpty, reason: 'shipped but unreachable: $orphans');
    });

    test('it ships more than a token one or two', () {
      expect(
        allBrands.where((InstitutionBrand b) => b.hasMark).length,
        greaterThanOrEqualTo(8),
        reason:
            'a logo system that covers two banks is a logo system that looks '
            'broken on every other account',
      );
    });
  });

  group('resolving a name', () {
    test('every institution in the seed resolves to something deliberate', () {
      for (final Account a in SeedData.accounts) {
        expect(
          brandFor(a.institution),
          isNotNull,
          reason:
              '"${a.institution}" is in the app\'s own fixture and has no '
              'brand, so it falls back to a generic plate on the first screen '
              'anybody opens',
        );
      }
    });

    test('spacing and case do not lose a bank', () {
      final InstitutionBrand? canonical = brandFor('UnionBank');
      expect(canonical, isNotNull);
      for (final String written in <String>[
        'unionbank',
        'UNIONBANK',
        'Union Bank',
        '  UnionBank  ',
      ]) {
        expect(
          brandFor(written)?.name,
          canonical!.name,
          reason: '"$written" did not find UnionBank',
        );
      }
    });

    test('an institution nobody has heard of resolves to null', () {
      // Null is a real answer that callers must handle. Somebody can type
      // anything into the account sheet, and inventing a mark for a bank we
      // do not know would be worse than a clean monogram.
      expect(brandFor('Bank of Somewhere Else'), isNull);
      expect(brandFor(''), isNull);
      expect(brandFor('   '), isNull);
    });
  });

  group('the mark widget', () {
    Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

    testWidgets('a known bank draws its logo', (WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          InstitutionMark(
            institution: 'BPI',
            monogram: 'BP',
            palette: Palette.of(ThemeMode2.gabi),
          ),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
      expect(
        find.text('BP'),
        findsNothing,
        reason: 'the monogram is showing over a bank that has a real mark',
      );
    });

    testWidgets('an unknown one draws the monogram, not a broken image', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(
          InstitutionMark(
            institution: 'Bank of Somewhere Else',
            monogram: 'BS',
            palette: Palette.of(ThemeMode2.gabi),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.text('BS'), findsOneWidget);
    });

    testWidgets('a government fund with no mark still gets its monogram', (
      WidgetTester tester,
    ) async {
      // Pag-IBIG is KNOWN (it has a brand colour) but ships no mark. That
      // combination is its own branch and it is the one a careless edit
      // breaks.
      expect(brandFor('Pag-IBIG'), isNotNull);
      expect(brandFor('Pag-IBIG')!.hasMark, isFalse);

      await tester.pumpWidget(
        host(
          InstitutionMark(
            institution: 'Pag-IBIG',
            monogram: 'MP2',
            palette: Palette.of(ThemeMode2.gabi),
          ),
        ),
      );
      expect(find.text('MP2'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });

  group('the card', () {
    Account card({
      CardNetwork network = CardNetwork.visa,
      CardTier tier = CardTier.regular,
      AccountKind kind = AccountKind.credit,
      double balance = 4200,
      double? limit = 40000,
    }) => Account(
      id: 'acc_card',
      name: 'BPI Rewards Card',
      kind: kind,
      institution: 'BPI',
      balance: balance,
      monogram: 'BP',
      accountNumber: '**** 8819',
      creditLimit: limit,
      cardNetwork: network,
      cardTier: tier,
    );

    Widget host(Account a) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: BankCard(account: a, palette: Palette.of(ThemeMode2.gabi)),
        ),
      ),
    );

    testWidgets('it is the shape of a real card, not a banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(card()));
      final Size size = tester.getSize(find.byType(AspectRatio).first);
      expect(
        size.width / size.height,
        closeTo(BankCard.aspect, 0.01),
        reason:
            'ISO/IEC 7810 ID-1 is 85.60 by 53.98 mm. The proportion is what '
            'makes this read as a card before a word of it is read.',
      );
    });

    testWidgets('the number is masked to the last four, in card groups', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(card()));
      expect(find.textContaining('8819'), findsOneWidget);
      expect(
        find.textContaining('••••  ••••  ••••'),
        findsOneWidget,
        reason: 'three masked groups then the tail, the way plastic reads',
      );
    });

    testWidgets('money owed on a credit card is drawn negative', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(card()));
      expect(
        find.textContaining('-₱4,200.00'),
        findsOneWidget,
        reason:
            'without the minus a 4,200 debt renders character for character '
            'like 4,200 in savings',
      );
      expect(find.text('OUTSTANDING BALANCE'), findsOneWidget);
    });

    testWidgets('a debit card says available, not outstanding', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        host(card(kind: AccountKind.debit, limit: null)),
      );
      expect(find.text('AVAILABLE BALANCE'), findsOneWidget);
      expect(find.text('OUTSTANDING BALANCE'), findsNothing);
    });

    testWidgets('the utilisation the card used to carry is still there', (
      WidgetTester tester,
    ) async {
      // It moved off the plastic when the card took its real proportions.
      // Moved, not dropped: this is the assertion that says so.
      await tester.pumpWidget(host(card()));
      expect(find.text('Credit used'), findsOneWidget);
      expect(find.text('11%'), findsOneWidget);
      expect(find.textContaining('Limit'), findsOneWidget);
    });

    testWidgets('a card with no recorded limit says so rather than guessing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(card(limit: null)));
      expect(find.textContaining('Add this card'), findsOneWidget);
      expect(find.text('Credit used'), findsNothing);
    });

    testWidgets('a tier is named on the card, the way it is on plastic', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(host(card(tier: CardTier.platinum)));
      expect(find.text('PLATINUM'), findsOneWidget);

      await tester.pumpWidget(host(card(tier: CardTier.regular)));
      expect(
        find.text('REGULAR'),
        findsNothing,
        reason:
            'an ordinary card does not print "REGULAR" on itself, and saying '
            'so is clutter on the most common card of all',
      );
    });

    testWidgets('every scheme draws something, and none draws nothing', (
      WidgetTester tester,
    ) async {
      for (final CardNetwork n in CardNetwork.values) {
        await tester.pumpWidget(host(card(network: n)));
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '$n threw while drawing',
        );
      }
      // And the one with a wordmark really shows it.
      await tester.pumpWidget(host(card(network: CardNetwork.visa)));
      expect(find.text('VISA'), findsOneWidget);
    });
  });
}
