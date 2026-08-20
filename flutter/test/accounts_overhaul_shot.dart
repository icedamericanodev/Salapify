// Working screenshots for the f4.57 accounts overhaul: the floating 3D card,
// the account action sheet, and the card skin studio. Not a `_test` file, so
// `flutter test` never collects it; run it with --update-goldens to write the
// PNGs into test/shots (gitignored), then look at them. Dark first, the mode the
// founder uses.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/account_action_sheet.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/card_skin_studio.dart';
import 'package:salapify/widgets/floating_pan_card.dart';

import 'screens_shot.dart' show loadRealFonts;

Widget _card({Color? seed, bool tilt = false}) => FloatingPanCard(
  bankName: 'BPI Credit',
  accountType: 'Credit',
  balance: 32000,
  brandColor: const Color(0xFFA51E22),
  skinSeed: seed,
  last4: '4821',
  creditLimit: 50000,
  networkMark: 'VISA',
  variant: BankCardVariant.credit,
  enableTilt: tilt,
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  await loadRealFonts(tester);
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  Barako.currentTheme = barakoThemes.first;
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(
    MaterialApp(
      theme: salapifyTheme(Barako.current),
      debugShowCheckedModeBanner: false,
      home: Scaffold(backgroundColor: Barako.background, body: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('floating pan card, four skins', (tester) async {
    await _pump(
      tester,
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _card(),
            const SizedBox(height: 16),
            _card(seed: const Color(0xFF0E7C5A)),
            const SizedBox(height: 16),
            _card(seed: const Color(0xFFB8891F)),
          ],
        ),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/floating-pan-card-dark.png'),
    );
  });

  testWidgets('account action sheet', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showAccountActionSheet(
              context,
              title: 'BPI Credit',
              cardPreview: _card(),
              onViewLedger: () {},
              onLogExpense: () {},
              onTransfer: () {},
              onEditDetails: () {},
              onExportStatement: () {},
              onCustomizeSkin: () {},
              onArchiveToggle: () {},
              isArchived: false,
              onShowQr: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/account-action-sheet-dark.png'),
    );
  });

  testWidgets('card skin studio', (tester) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () => showCardSkinStudio(
              context,
              accountId: 'demo',
              previewBuilder: (seed) => _card(seed: seed),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/card-skin-studio-dark.png'),
    );
  });
}
