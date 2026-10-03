import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/widgets/mindset_spectrum_bar.dart';

void main() {
  group('MindsetSpectrumBar.bandForAmount', () {
    test('reads the two thresholds, inclusive at each ceiling', () {
      expect(MindsetSpectrumBar.bandForAmount(2000, 3000, 6000), 1);
      expect(MindsetSpectrumBar.bandForAmount(3000, 3000, 6000), 1);
      expect(MindsetSpectrumBar.bandForAmount(4000, 3000, 6000), 2);
      expect(MindsetSpectrumBar.bandForAmount(6000, 3000, 6000), 2);
      expect(MindsetSpectrumBar.bandForAmount(7000, 3000, 6000), 3);
    });

    test('a zero comfort ceiling means even a tiny amount is a pause', () {
      expect(MindsetSpectrumBar.bandForAmount(1, 0, 6000), 2);
    });
  });

  testWidgets('tapping maps the x position to a proportional amount', (
    tester,
  ) async {
    double? got;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: MindsetSpectrumBar(
                value: 1000,
                maxAmount: 10000,
                comfortCeiling: 3000,
                cautionCeiling: 6000,
                onChanged: (v) => got = v,
              ),
            ),
          ),
        ),
      ),
    );

    // Tapping the horizontal middle of a 200-wide bar reports ~half of max.
    await tester.tapAt(tester.getCenter(find.byType(MindsetSpectrumBar)));
    expect(got, closeTo(5000, 200));
  });
}
