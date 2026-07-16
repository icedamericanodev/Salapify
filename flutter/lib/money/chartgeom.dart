// Pure geometry for the trend line charts, ported 1:1 from
// mobile/lib/chartgeom.js. Maps series values onto x,y positions inside a
// box so the chart widget stays a dumb renderer and this math is golden
// verified against the RN module. No Flutter imports here on purpose.

import 'ledger.dart' show amountOf;

/// The max across several series, so multiple lines on one chart share one
/// honest scale (income and spending must be comparable on sight).
double sharedMax(dynamic seriesList) {
  final all = <double>[];
  for (final s in (seriesList is List ? seriesList : const [])) {
    if (s is List) {
      for (final v in s) {
        all.add(amountOf(v));
      }
    }
  }
  if (all.isEmpty) return 0;
  var max = 0.0;
  for (final v in all) {
    if (v > max) max = v;
  }
  return max;
}

/// Points for a polyline, scaled against a caller-supplied max. x spreads
/// evenly between the pads; y runs 0 at the bottom to maxValue at the top
/// with 8 percent headroom. All-zero draws along the baseline; a single
/// point lands centered horizontally.
List<Map<String, double>> linePointsScaled(
    dynamic values, dynamic maxValue, dynamic width, dynamic height,
    [double pad = 8]) {
  final list = [
    for (final v in (values is List ? values : const [])) amountOf(v),
  ];
  if (list.isEmpty) return [];
  final minSize = 2 * pad + 1;
  final w = amountOf(width) > minSize ? amountOf(width) : minSize;
  final h = amountOf(height) > minSize ? amountOf(height) : minSize;
  final innerW = w - 2 * pad;
  final innerH = h - 2 * pad;
  final mv = amountOf(maxValue);
  final scaled = (mv > 0 ? mv : 0) * 1.08;
  final denom = scaled > 0 ? scaled : 1;
  final n = list.length;
  return [
    for (var i = 0; i < n; i++)
      {
        'x': n == 1 ? w / 2 : pad + (innerW * i) / (n - 1),
        'y': pad +
            innerH * (1 - (list[i] > 0 ? list[i] : 0) / denom),
      },
  ];
}

/// Single-series convenience: scaled against the series' own max.
List<Map<String, double>> linePoints(
    dynamic values, dynamic width, dynamic height,
    [double pad = 8]) {
  final list = [
    for (final v in (values is List ? values : const [])) amountOf(v),
  ];
  var max = 0.0;
  for (final v in list) {
    if (v > max) max = v;
  }
  return linePointsScaled(list, list.isEmpty ? 0 : max, width, height, pad);
}
