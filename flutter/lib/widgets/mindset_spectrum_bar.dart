// The Money Mindset spending SPECTRUM: a single bar that shows, for the money
// the person has right now, where a purchase crosses from Fits comfortably to
// Worth a pause to Big impact, with a draggable thumb so they can explore any
// amount and watch the band change live. The thresholds come from the read-only
// mindsetComfortRange engine; this widget only draws them and reports drags. It
// never computes money.
import 'package:flutter/material.dart';

import '../theme.dart';

/// A zoned, draggable spectrum bar. [value], [comfortCeiling] and
/// [cautionCeiling] are peso amounts on a 0..[maxAmount] track. Below
/// comfortCeiling the zone is the accent (Fits comfortably), up to cautionCeiling
/// it is warning (Worth a pause), and beyond it is warningStrong (Big impact).
/// [onChanged] fires with the peso amount under the finger; the parent owns the
/// value (the same controlled contract Slider keeps).
class MindsetSpectrumBar extends StatelessWidget {
  const MindsetSpectrumBar({
    super.key,
    required this.value,
    required this.maxAmount,
    required this.comfortCeiling,
    required this.cautionCeiling,
    required this.onChanged,
    this.semanticLabel,
    this.semanticValue,
    this.semanticIncreasedValue,
    this.semanticDecreasedValue,
  });

  final double value;
  final double maxAmount;
  final double comfortCeiling;
  final double cautionCeiling;
  final ValueChanged<double> onChanged;
  final String? semanticLabel;

  /// The spoken current value (e.g. "₱5,000, Worth a pause"), so a screen
  /// reader announces the amount and band, not just "slider". When set, the
  /// increased/decreased spoken values must be set too (a Flutter slider
  /// invariant when onIncrease/onDecrease are provided).
  final String? semanticValue;
  final String? semanticIncreasedValue;
  final String? semanticDecreasedValue;

  /// The nudge step assistive tech uses; kept in sync with the parent so the
  /// spoken increased/decreased values match what a nudge actually does.
  static double stepFor(double maxAmount) =>
      (maxAmount > 0 ? maxAmount : 1) / 20;

  static const double _barHeight = 8;
  static const double _thumb = 22;
  // 44dp so the whole drag target clears the minimum touch size, even though
  // the painted bar is only 8dp tall.
  static const double _rowHeight = 44;

  /// The band a peso [amount] falls in, read purely off the two thresholds, so
  /// the thumb colour and the live readout never re-score the ledger.
  static int bandForAmount(
    double amount,
    double comfortCeiling,
    double cautionCeiling,
  ) {
    if (amount <= comfortCeiling) return 1;
    if (amount <= cautionCeiling) return 2;
    return 3;
  }

  static Color _zoneColor(int band) => switch (band) {
    1 => Barako.primary,
    2 => Barako.warning,
    _ => Barako.warningStrong,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final max = maxAmount > 0 ? maxAmount : 1.0;
        double fx(double a) => (a / max).clamp(0.0, 1.0) * w;
        final comfortW = fx(comfortCeiling);
        final cautionW = (fx(cautionCeiling) - comfortW).clamp(0.0, w);
        final thumbX = fx(value.clamp(0.0, max));
        final band = bandForAmount(value, comfortCeiling, cautionCeiling);

        void report(double dx) => onChanged((dx / w).clamp(0.0, 1.0) * max);
        // A tidy step so assistive tech can move the thumb without a drag.
        final step = stepFor(max);
        void nudge(double delta) => onChanged((value + delta).clamp(0.0, max));

        return Semantics(
          slider: true,
          label: semanticLabel,
          value: semanticValue,
          increasedValue: semanticIncreasedValue,
          decreasedValue: semanticDecreasedValue,
          onIncrease: () => nudge(step),
          onDecrease: () => nudge(-step),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => report(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => report(d.localPosition.dx),
            child: SizedBox(
              height: _rowHeight,
              width: w,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // The three zones, each a translucent band of its colour.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (_rowHeight - _barHeight) / 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(_barHeight / 2),
                      child: Row(
                        children: [
                          Container(
                            width: comfortW,
                            height: _barHeight,
                            color: Barako.primary.withValues(alpha: 0.35),
                          ),
                          Container(
                            width: cautionW,
                            height: _barHeight,
                            color: Barako.warning.withValues(alpha: 0.40),
                          ),
                          Expanded(
                            child: Container(
                              height: _barHeight,
                              color: Barako.warningStrong.withValues(
                                alpha: 0.40,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // The thumb, coloured by the band the current amount is in.
                  Positioned(
                    left: (thumbX - _thumb / 2).clamp(0.0, w - _thumb),
                    top: (_rowHeight - _thumb) / 2,
                    child: Container(
                      width: _thumb,
                      height: _thumb,
                      decoration: BoxDecoration(
                        color: _zoneColor(band),
                        shape: BoxShape.circle,
                        border: Border.all(color: Barako.card, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
