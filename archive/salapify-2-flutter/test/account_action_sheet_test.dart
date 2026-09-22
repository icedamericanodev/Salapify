// The account action sheet wires each row to a flow the app already has. These
// prove the wiring: a tap runs the right callback and closes the sheet, and the
// QR control falls back to the details when no receiving QR is saved rather than
// pretending to show one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/theme.dart';
import 'package:salapify/widgets/account_action_sheet.dart';

class _Fired {
  final fired = <String>{};
  VoidCallback on(String name) =>
      () => fired.add(name);
}

Future<void> _open(
  WidgetTester tester,
  _Fired f, {
  bool provideQr = false,
}) async {
  Barako.currentTheme = barakoThemes.first;
  Barako.current = barakoThemes.first.dark;
  // A tall surface so the whole sheet is on screen; on a real phone the sheet
  // scrolls, but the test needs every tile hit-testable at once.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showAccountActionSheet(
                context,
                title: 'BPI Credit',
                cardPreview: const SizedBox(height: 40, key: Key('preview')),
                onViewLedger: f.on('ledger'),
                onLogExpense: f.on('log'),
                onTransfer: f.on('transfer'),
                onEditDetails: f.on('edit'),
                onExportStatement: f.on('statement'),
                onCustomizeSkin: f.on('skin'),
                onArchiveToggle: f.on('archive'),
                isArchived: false,
                onShowQr: provideQr ? f.on('qr') : null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the three tiers and the card preview all render', (
    tester,
  ) async {
    final f = _Fired();
    await _open(tester, f);
    expect(find.byKey(const Key('preview')), findsOneWidget);
    expect(find.text('QUICK'), findsOneWidget);
    expect(find.text('STATEMENTS AND MOVES'), findsOneWidget);
    expect(find.text('CUSTOMISE AND MANAGE'), findsOneWidget);
    expect(find.text('Export PDF statement'), findsOneWidget);
    expect(find.text('Card skin studio'), findsOneWidget);
    expect(find.text('Hide account'), findsOneWidget);
  });

  testWidgets('each action runs its callback and closes the sheet', (
    tester,
  ) async {
    for (final (label, key) in const [
      ('Ledger', 'ledger'),
      ('Export PDF statement', 'statement'),
      ('Card skin studio', 'skin'),
      ('Edit account details', 'edit'),
      ('Hide account', 'archive'),
    ]) {
      final f = _Fired();
      await _open(tester, f);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(f.fired, {key}, reason: '$label should fire "$key" only');
      // The sheet closed, so its section headings are gone.
      expect(find.text('QUICK'), findsNothing);
    }
  });

  testWidgets('QR Ph shows the saved code when there is one', (tester) async {
    final f = _Fired();
    await _open(tester, f, provideQr: true);
    await tester.tap(find.text('QR Ph'));
    await tester.pumpAndSettle();
    expect(f.fired, {'qr'});
  });

  testWidgets('QR Ph falls back to edit details when no code is saved', (
    tester,
  ) async {
    final f = _Fired();
    await _open(tester, f, provideQr: false);
    await tester.tap(find.text('QR Ph'));
    await tester.pumpAndSettle();
    // No fabricated code: it routes to details, where a real QR is attached.
    expect(f.fired, {'edit'});
  });
}
