// Deterministic pixel baselines for the screens this change set touched.
//
// This file is NAMED WITHOUT the `_test` suffix on purpose, exactly like
// screens_shot.dart, so `flutter test` never collects it. It is run by an
// explicit command (see test/golden/README.md), so a pixel diff is a separate,
// clearly-labelled signal and never a flaky gate on an ordinary push. The
// per-push regression protection lives in the layout-metric tests
// (screen_readability_test.dart, palette_contrast_test.dart, segmented_test.dart,
// transfer_screen_test.dart, insights_screen_test.dart), which cannot flake
// cross-platform because they measure layout, not pixels.
//
// Everything here is fixed so the same bytes come out every run: device size and
// pixel ratio, dark theme, en locale and LTR (via goldenApp), the text scale per
// scenario, the real committed fonts, animations off, a deterministic fixture,
// no network (the one network screen is forced offline), and an injected fixed
// clock where a screen shows a date. The only screens included are the ones that
// are time-independent or take an injectable clock; time-relative Insights
// (populated) is covered by the layout-metric sweep, not a pixel baseline that
// would rot as the calendar moves.
//
// Compare:   flutter test test/golden/ui_golden.dart
// Regenerate: flutter test test/golden/ui_golden.dart --update-goldens

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/data/store.dart';
import 'package:salapify/screens/accounts.dart';
import 'package:salapify/screens/currency_converter.dart';
import 'package:salapify/screens/insights.dart';
import 'package:salapify/screens/tax_calculator.dart';
import 'package:salapify/screens/tax_deadlines.dart';
import 'package:salapify/screens/year_end_tax.dart';
import 'package:salapify/money/institutions.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/bank_card.dart';
import 'package:salapify/widgets/empty_state.dart';
import 'package:salapify/widgets/error_state.dart';
import 'package:salapify/widgets/segmented.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens_shot.dart' show loadRealFonts;
import '../support/golden_app.dart';

/// Render [home] deterministically and compare to baseline/[name].png.
Future<void> _golden(
  WidgetTester tester, {
  required String name,
  required Widget home,
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Future<void> Function(WidgetTester)? interact,
}) async {
  // A blinking text cursor is a repeating timer and a moving pixel: it makes
  // pumpAndSettle hang and the capture non-deterministic. This pins it on and
  // still, the standard golden fix, so an autofocused field (the transfer
  // amount, the gross income) renders the same every time.
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);

  await loadRealFonts(tester);
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  // Palette before build, the order main.dart uses.
  Barako.current = Barako.currentTheme.resolve(Brightness.dark);
  await tester.pumpWidget(goldenApp(home: home, textScale: textScale));
  await tester.pumpAndSettle();
  if (interact != null) {
    await interact(tester);
    await tester.pumpAndSettle();
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('baseline/$name.png'),
  );
}

Future<SalapifyStore> _storeFrom(Object blob) async {
  SharedPreferences.setMockInitialValues({
    storageKey: blob is String ? blob : jsonEncode(blob),
  });
  final store = SalapifyStore();
  await store.load();
  return store;
}

Map<String, dynamic> _twoAccounts() => {
  'schemaVersion': 12,
  'settings': {'onboarded': true},
  'accounts': [
    {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 3200},
    {'id': 'bpi', 'name': 'BPI', 'kind': 'savings', 'balance': 48500.55},
  ],
  'transactions': <Map<String, dynamic>>[],
};

// A fixed 320dp width (a small Android phone's content width), so the fit test
// sees a concrete, predictable width: three labels fit side by side at 1.0x and
// cannot at 2.0x, where the control stacks.
Widget _modeSelector(String current) => Scaffold(
  body: Padding(
    padding: const EdgeInsets.all(20),
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 320,
        child: Segmented<String>(
          current: current,
          onPick: (_) {},
          options: const [
            SegmentOption(value: 'system', label: 'System'),
            SegmentOption(value: 'light', label: 'Light'),
            SegmentOption(value: 'dark', label: 'Dark'),
          ],
        ),
      ),
    ),
  ),
);

/// Forces every HttpClient request to fail, so the currency converter lands on
/// its offline state without a real network call or a 6 second timeout.
class _OfflineHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw const SocketException('offline (golden)');
  }
}

void main() {
  group('the System label selector', () {
    testWidgets('normal text scale', (tester) async {
      await _golden(
        tester,
        name: 'system-selector-normal',
        home: _modeSelector('system'),
        size: const Size(390, 320),
      );
    });

    testWidgets('large text scale, no clipping', (tester) async {
      // At 2.0x on a 320dp content width in the shipped font (Plus Jakarta
      // Sans), "System" wraps to two lines rather than clipping, and the
      // reserved leading slot keeps all three segments the same height. This is
      // the real-device behaviour, and segmented_test.dart now loads the same
      // real font, so the widget test and this baseline agree: a row here, not a
      // stack. The vertical-stack safety net only fires at even narrower widths
      // (about 250dp at 2.0x) or beyond 2.0x, and segmented_test.dart covers
      // that path directly.
      await _golden(
        tester,
        name: 'system-selector-large',
        home: _modeSelector('system'),
        size: const Size(390, 300),
        textScale: 2.0,
      );
    });
  });

  group('the transfer sheet', () {
    testWidgets('normal size', (tester) async {
      final store = await _storeFrom(_twoAccounts());
      await _golden(
        tester,
        name: 'transfer-sheet-normal',
        home: AccountsScreen(store: store),
        interact: (t) => t.tap(find.text('Transfer')),
      );
    });

    testWidgets('constrained height and large text', (tester) async {
      final store = await _storeFrom(_twoAccounts());
      await _golden(
        tester,
        name: 'transfer-sheet-constrained-large',
        home: AccountsScreen(store: store),
        size: const Size(360, 600),
        textScale: 1.5,
        // Transfer sits in the quick-actions row near the top; ensureVisible
        // brings it on screen at large text. The captured golden is the
        // transfer SHEET, unaffected by how far the list behind it scrolled.
        interact: (t) async {
          final finder = find.text('Transfer');
          await t.ensureVisible(finder);
          await t.pumpAndSettle();
          await t.tap(finder);
        },
      );
    });
  });

  group('Insights states', () {
    testWidgets('empty', (tester) async {
      final store = await _storeFrom({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
      });
      await _golden(
        tester,
        name: 'insights-empty',
        home: InsightsScreen(store: store),
      );
    });

    testWidgets('error (unreadable load)', (tester) async {
      final store = await _storeFrom('{broken');
      await _golden(
        tester,
        name: 'insights-error',
        home: InsightsScreen(store: store),
      );
    });

    testWidgets('populated month story (fixed clock)', (tester) async {
      // Possible since Phase 5 gave InsightsScreen an injectable clock (the
      // header's old exclusion of populated Insights was about calendar
      // rot, and a fixed clock removes it): two fixed months, Jul 20, so
      // the pulse, the chart readout, and WHAT CHANGED's paced shifts
      // produce the same bytes every run. Tall canvas: the story band is
      // the subject.
      final store = await _storeFrom({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
        'accounts': [
          {'id': 'cash', 'name': 'Cash', 'kind': 'cash', 'balance': 30000},
        ],
        'transactions': [
          {
            'id': 'i6',
            'type': 'income',
            'label': 'Sweldo',
            'amount': 20000,
            'date': '2026-06-15',
            'accountId': 'cash',
          },
          {
            'id': 'f6',
            'type': 'expense',
            'label': 'Food',
            'amount': 1000,
            'date': '2026-06-10',
            'accountId': 'cash',
          },
          {
            'id': 't6',
            'type': 'expense',
            'label': 'Transport',
            'amount': 2000,
            'date': '2026-06-12',
            'accountId': 'cash',
          },
          {
            'id': 'i7',
            'type': 'income',
            'label': 'Sweldo',
            'amount': 20000,
            'date': '2026-07-15',
            'accountId': 'cash',
          },
          {
            'id': 'f7a',
            'type': 'expense',
            'label': 'Food',
            'amount': 900,
            'date': '2026-07-02',
            'note': 'Grab food',
            'accountId': 'cash',
          },
          {
            'id': 'f7b',
            'type': 'expense',
            'label': 'Food',
            'amount': 800,
            'date': '2026-07-09',
            'note': 'grab food',
            'accountId': 'cash',
          },
          {
            'id': 'f7c',
            'type': 'expense',
            'label': 'Food',
            'amount': 400,
            'date': '2026-07-11',
            'note': 'groceries',
            'accountId': 'cash',
          },
        ],
      });
      await _golden(
        tester,
        name: 'insights-month-story',
        home: InsightsScreen(store: store, clock: () => DateTime(2026, 7, 20)),
        size: const Size(390, 2600),
      );
    });
  });

  testWidgets('the currency converter offline state', (tester) async {
    await HttpOverrides.runZoned(() async {
      final store = await _storeFrom({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
      });
      await _golden(
        tester,
        name: 'currency-offline',
        home: CurrencyConverterScreen(store: store),
        size: const Size(390, 900),
      );
    }, createHttpClient: (c) => _OfflineHttpOverrides().createHttpClient(c));
  });

  group('the tax screens', () {
    testWidgets('income tax with a result', (tester) async {
      await _golden(
        tester,
        name: 'tax-income',
        home: const TaxCalculatorScreen(),
        size: const Size(390, 1500),
        interact: (t) => t.enterText(find.byType(TextField).first, '600000'),
      );
    });

    testWidgets('BIR dates', (tester) async {
      final store = await _storeFrom({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
      });
      await _golden(
        tester,
        name: 'bir-dates',
        home: TaxDeadlinesScreen(
          store: store,
          clock: () => DateTime(2026, 4, 10),
        ),
        size: const Size(390, 1400),
      );
    });

    testWidgets('year-end tax check', (tester) async {
      final store = await _storeFrom({
        'schemaVersion': 12,
        'settings': {'onboarded': true},
      });
      await _golden(
        tester,
        name: 'year-end-tax',
        home: YearEndTaxScreen(store: store),
        size: const Size(390, 1200),
        interact: (t) async {
          await t.enterText(find.byType(TextField).at(0), '25000');
          await t.enterText(find.byType(TextField).at(3), '25000');
          await t.enterText(find.byType(TextField).at(4), '30000');
        },
      );
    });
  });

  group('the bank card', () {
    Widget wrapCard(Widget card) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 340, child: card),
        ),
      ),
    );

    testWidgets('savings card', (tester) async {
      await _golden(
        tester,
        name: 'bank-card-savings',
        home: wrapCard(
          BankCard(
            bankName: 'BPI Savings',
            accountType: 'Savings',
            brandColor: institutionBrandColor('bpi'),
            last4: '1234',
            balance: 48500.55,
          ),
        ),
        size: const Size(390, 320),
      );
    });

    testWidgets('credit card', (tester) async {
      await _golden(
        tester,
        name: 'bank-card-credit',
        home: wrapCard(
          BankCard(
            bankName: 'BPI Credit',
            accountType: 'Credit',
            brandColor: institutionBrandColor('bpi'),
            last4: '9012',
            balance: 42000,
            creditLimit: 50000,
            variant: BankCardVariant.credit,
          ),
        ),
        size: const Size(390, 320),
      );
    });
  });

  group('the shared state widgets', () {
    Widget wrap(Widget card) => Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Align(alignment: Alignment.topCenter, child: card),
      ),
    );

    testWidgets('shared empty state', (tester) async {
      await _golden(
        tester,
        name: 'shared-empty',
        home: wrap(
          EmptyState(
            icon: 'chart',
            title: 'Nothing here yet, and that is okay',
            body: 'Log a few entries and this fills in.',
            actionLabel: 'Start logging',
            onAction: () {},
          ),
        ),
      );
    });

    testWidgets('shared error state', (tester) async {
      await _golden(
        tester,
        name: 'shared-error',
        home: wrap(
          ErrorState(
            title: 'Your saved data could not be read',
            body:
                'Nothing was overwritten, so nothing is lost. Open the app again '
                'to retry.',
            actionLabel: 'Go to Home',
            onAction: () {},
          ),
        ),
      );
    });
  });
}
