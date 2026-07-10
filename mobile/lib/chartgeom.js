// chartgeom.js: pure geometry for the trend line charts. Maps a series of
// values onto x,y pixel positions inside a box, so the Skia component stays a
// dumb renderer and this math can be unit tested. No Skia, no React here.

const num = (x) => (Number.isFinite(Number(x)) ? Number(x) : 0);

// sharedMax(seriesList) -> the max value across several series, so two lines
// on one chart share one honest scale (income and spending must be comparable
// on sight, never independently normalized).
export function sharedMax(seriesList) {
  const all = (Array.isArray(seriesList) ? seriesList : [])
    .flatMap((s) => (Array.isArray(s) ? s.map(num) : []));
  return all.length ? Math.max(...all, 0) : 0;
}

// linePointsScaled(values, maxValue, width, height, pad) -> [{x, y}] for a
// polyline, scaled against a caller-supplied max (use sharedMax for
// multi-series charts so every line shares one scale).
//   values  the series, oldest first. Non-numeric entries count as 0.
//   width   drawable width in px
//   height  drawable height in px
//   pad     inset from every edge so dots at the extremes are not clipped
// Scale: x spreads points evenly from left pad to right pad. y runs from 0 at
// the bottom to maxValue at the top, with 8 percent headroom so the top dot
// never kisses the edge. An all-zero series draws along the baseline. A single
// point lands centered horizontally.
export function linePointsScaled(values, maxValue, width, height, pad = 8) {
  const list = Array.isArray(values) ? values.map(num) : [];
  if (list.length === 0) return [];
  const w = Math.max(num(width), 2 * pad + 1);
  const h = Math.max(num(height), 2 * pad + 1);
  const innerW = w - 2 * pad;
  const innerH = h - 2 * pad;
  const scaled = Math.max(0, num(maxValue)) * 1.08;
  const denom = scaled > 0 ? scaled : 1;
  const n = list.length;
  return list.map((v, i) => ({
    x: n === 1 ? w / 2 : pad + (innerW * i) / (n - 1),
    y: pad + innerH * (1 - Math.max(0, v) / denom),
  }));
}

// linePoints(values, width, height, pad) -> single-series convenience: scaled
// against the series' own max.
export function linePoints(values, width, height, pad = 8) {
  const list = Array.isArray(values) ? values.map(num) : [];
  return linePointsScaled(list, list.length ? Math.max(...list, 0) : 0, width, height, pad);
}
