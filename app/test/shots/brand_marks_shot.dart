import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/money.dart';
import 'package:salapify/design/tokens.dart';
import 'package:salapify/models/models.dart';
import 'package:salapify/screens/accounts/bank_card.dart';

import 'screens_shot.dart' show loadRealFonts;

/// A contact sheet of every institution mark, on the card that draws it.
///
/// NOT named `*_test.dart`, for the same reason as screens_shot.dart: it
/// produces pictures rather than assertions, and `flutter test` must never
/// collect it.
///
/// It exists because five of sixteen marks fetched on 2026-10-04 were not
/// the institution's mark at all, and every one of them downloaded cleanly.
/// A list of filenames proves a file arrived. Only a render proves the right
/// picture is on the right bank.
///
///   flutter test test/shots/brand_marks_shot.dart --update-goldens
void main() {
  const List<(String, AccountKind)> row = <(String, AccountKind)>[
    ('AUB', AccountKind.bank),
    ('PNB', AccountKind.bank),
    ('LandBank', AccountKind.bank),
    ('PSBank', AccountKind.bank),
    ('China Bank', AccountKind.bank),
    ('EastWest', AccountKind.bank),
    ('CIMB', AccountKind.bank),
    ('Komo', AccountKind.bank),
    ('SSS', AccountKind.bank),
    ('TikTok', AccountKind.gcash),
    ('Atome', AccountKind.credit),
    // The control. Netbank's fetched mark was a generic shield and was
    // rejected, so this one MUST still draw as a monogram. If it ever shows
    // a picture, something unverified has been let in.
    ('Netbank', AccountKind.bank),
  ];

  testWidgets('institution marks', (WidgetTester tester) async {
    await tester.runAsync(loadRealFonts);
    final Palette p = Palette.of(ThemeMode2.gabi);

    // Three columns at DPR 1, so all twelve fit in one picture. A sheet that
    // only shows the first four is how a wrong mark further down survives.
    tester.view.physicalSize = const Size(1500, 1750);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: p.background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.md),
            child: Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: <Widget>[
                for (final (String name, AccountKind kind) in row)
                  SizedBox(
                    width: 470,
                    child: BankCard(
                      palette: p,
                      now: DateTime.utc(2026, 10, 4),
                      account: Account(
                        id: 'b_$name',
                        name: '$name Account',
                        kind: kind,
                        institution: name,
                        balance: const Money.pesos(12500),
                        monogram: name.length >= 2
                            ? name.substring(0, 2).toUpperCase()
                            : name.toUpperCase(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // PRECACHE INSIDE runAsync, or every mark draws as an empty white plate.
    // Image.asset resolves through an async codec, and a widget test's fake
    // clock never lets that complete, so the first version of this harness
    // produced a sheet of blank squares that looked exactly like a wiring
    // bug. Same trap as loading the real fonts, one layer down.
    await tester.runAsync(() async {
      for (final Element e in find.byType(Image).evaluate()) {
        final Image img = e.widget as Image;
        await precacheImage(img.image, e);
      }
    });
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('out/brand_marks.png'),
    );
  });
}
