// TrendChart: the trend line chart for Insights. Renders one or two series as
// proper Skia lines on native (a line is the honest form for change over
// time), and falls back to the plain-View bar rendering on web or if this
// component's own render throws, following the Mascot error boundary pattern.
// Note the boundary's limit: Skia's Canvas renders its children through its
// own reconciler, so an error INSIDE the canvas draws blank rather than
// throwing here. Keep every prop passed to Canvas children valid; chartgeom
// coerces all values to finite numbers for that reason.
//
// API:
//   <TrendChart
//     series={[{ color, values: [n...] }, ...]}   oldest first, 1 or 2 series
//     labels={['Feb', ...]}                       one per point
//     height={140}
//     accessibilityLabel="Net worth trend: Feb 10,000 ..."
//   />
// Both series share ONE scale (sharedMax), so income and spending stay
// comparable on sight. Values are clamped at 0; these charts show magnitudes.

import React, { useState } from 'react';
import { Platform, StyleSheet, Text, View } from 'react-native';
import { Canvas, Path, Circle, Skia } from '@shopify/react-native-skia';
import { useTheme } from '../context/Theme';
import { spacing, fontSize } from '../theme';
import { linePointsScaled, sharedMax } from '../lib/chartgeom';

const PAD = 10; // inset so edge dots are never clipped

function TrendChartSkia({ series, labels, height = 140 }) {
  const { colors } = useTheme();
  const [width, setWidth] = useState(0);
  const clean = (series || []).filter((s) => s && Array.isArray(s.values) && s.values.length > 0);
  const max = sharedMax(clean.map((s) => s.values));

  return (
    <View onLayout={(e) => setWidth(Math.round(e.nativeEvent.layout.width))}>
      {width > 0 && clean.length > 0 ? (
        <Canvas style={{ width, height }}>
          {clean.map((s, si) => {
            const pts = linePointsScaled(s.values, max, width, height, PAD);
            const line = Skia.Path.Make();
            pts.forEach((p, i) => (i === 0 ? line.moveTo(p.x, p.y) : line.lineTo(p.x, p.y)));
            // A soft area fill under the line, single-series charts only, so a
            // two-line chart never has overlapping washes muddying each other.
            let fill = null;
            if (clean.length === 1 && pts.length >= 2) {
              fill = line.copy();
              fill.lineTo(pts[pts.length - 1].x, height - PAD);
              fill.lineTo(pts[0].x, height - PAD);
              fill.close();
            }
            const last = pts[pts.length - 1];
            return (
              <React.Fragment key={si}>
                {fill ? <Path path={fill} color={s.color} opacity={0.13} style="fill" /> : null}
                <Path path={line} color={s.color} style="stroke" strokeWidth={3.5} strokeJoin="round" strokeCap="round" />
                {pts.map((p, i) => (
                  <Circle key={i} cx={p.x} cy={p.y} r={i === pts.length - 1 ? 7 : 4.5} color={s.color} />
                ))}
                {/* Ring the newest point so "now" reads at a glance. */}
                <Circle cx={last.x} cy={last.y} r={3} color={colors.card} />
              </React.Fragment>
            );
          })}
        </Canvas>
      ) : (
        <View style={{ height }} />
      )}
    </View>
  );
}

// Fallback: the plain-View bars this chart replaced. One series renders simple
// vertical bars; two series render paired bars per point. Web safe.
function TrendChartFallback({ series, labels, height = 140 }) {
  const clean = (series || []).filter((s) => s && Array.isArray(s.values) && s.values.length > 0);
  const max = Math.max(sharedMax(clean.map((s) => s.values)), 1);
  const n = clean.length > 0 ? clean[0].values.length : 0;
  const barMaxH = height - 20;
  return (
    <View style={fb.row}>
      {Array.from({ length: n }, (_, i) => (
        <View key={i} style={fb.col}>
          <View style={fb.duo}>
            {clean.map((s, si) => (
              <View
                key={si}
                style={{
                  width: clean.length === 1 ? 22 : 12,
                  borderRadius: 4,
                  height: Math.max(((Math.max(0, Number(s.values[i]) || 0)) / max) * barMaxH, 3),
                  backgroundColor: s.color,
                }}
              />
            ))}
          </View>
        </View>
      ))}
    </View>
  );
}

const fb = StyleSheet.create({
  row: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between' },
  col: { flex: 1, alignItems: 'center' },
  duo: { flexDirection: 'row', alignItems: 'flex-end', gap: 3 },
});

// The labels row is shared by both renderers so the two paths can never drift.
function LabelsRow({ labels, styles }) {
  if (!Array.isArray(labels) || labels.length === 0) return null;
  const n = labels.length;
  return (
    <View style={lr.row}>
      {labels.map((l, i) => (
        // First and last labels hug their edges so they sit under the first
        // and last dots (which sit at the pad, not at a flex-cell center).
        <Text
          key={i}
          style={[
            lr.label,
            { color: styles.labelColor },
            i === 0 && n > 1 ? lr.first : null,
            i === n - 1 && n > 1 ? lr.last : null,
          ]}
        >
          {l}
        </Text>
      ))}
    </View>
  );
}

const lr = StyleSheet.create({
  row: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 4, marginTop: spacing.xs },
  label: { fontSize: fontSize.caption, flex: 1, textAlign: 'center' },
  first: { textAlign: 'left' },
  last: { textAlign: 'right' },
});

export default class TrendChart extends React.Component {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch() {
    // Intentionally quiet. The bar fallback renders on the next pass.
  }

  render() {
    const { accessibilityLabel, labels } = this.props;
    const useFallback = Platform.OS === 'web' || this.state.failed;
    // The OUTER view is the one focusable, spoken element. The hide flags live
    // on the INNER wrapper only: on Android, no-hide-descendants on the outer
    // view would remove the chart AND its own label from TalkBack entirely.
    return (
      <View accessible={!!accessibilityLabel} accessibilityLabel={accessibilityLabel}>
        <View
          accessibilityElementsHidden={!!accessibilityLabel}
          importantForAccessibility={accessibilityLabel ? 'no-hide-descendants' : 'auto'}
        >
          {useFallback ? <TrendChartFallback {...this.props} /> : <TrendChartSkia {...this.props} />}
          <TrendLabels labels={labels} />
        </View>
      </View>
    );
  }
}

// Month labels under the chart, muted, one per point.
function TrendLabels({ labels }) {
  const { colors } = useTheme();
  if (!Array.isArray(labels) || labels.length === 0) return null;
  return <LabelsRow labels={labels} styles={{ labelColor: colors.muted }} />;
}
