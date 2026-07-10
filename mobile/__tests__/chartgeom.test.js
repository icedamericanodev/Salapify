// Regression suite for lib/chartgeom.js: the pure math under the Skia trend
// lines. Wrong geometry here draws a lying chart, so scale, ordering, and the
// degenerate inputs are locked in.

import { linePoints, linePointsScaled, sharedMax } from '../lib/chartgeom';

describe('linePoints maps a series into the box honestly', () => {
  test('x spreads evenly and y puts bigger values higher (smaller y)', () => {
    const pts = linePoints([10, 20, 40], 320, 120, 10);
    expect(pts).toHaveLength(3);
    expect(pts[0].x).toBe(10);
    expect(pts[2].x).toBe(310);
    expect(pts[1].x).toBeCloseTo(160, 5);
    // 40 is the max, so it sits highest (smallest y); 10 sits lowest.
    expect(pts[2].y).toBeLessThan(pts[1].y);
    expect(pts[1].y).toBeLessThan(pts[0].y);
  });

  test('the max value keeps 8 percent headroom, never touching the top pad', () => {
    const pts = linePoints([100], 320, 120, 10);
    // Single point: centered horizontally, above the baseline but below the pad line.
    expect(pts[0].x).toBe(160);
    expect(pts[0].y).toBeGreaterThan(10);
    expect(pts[0].y).toBeLessThan(110);
  });

  test('an all-zero series draws flat along the baseline', () => {
    const pts = linePoints([0, 0, 0], 320, 120, 10);
    for (const p of pts) expect(p.y).toBe(110); // height - pad
  });

  test('empty and junk input are safe', () => {
    expect(linePoints([], 320, 120)).toEqual([]);
    expect(linePoints(null, 320, 120)).toEqual([]);
    const pts = linePoints([10, 'x', 30], 320, 120, 10);
    expect(pts).toHaveLength(3);
    expect(pts[1].y).toBe(110); // junk counts as 0, on the baseline
  });
});

describe('two series share one honest scale', () => {
  test('sharedMax finds the max across series, and scaled points agree', () => {
    const income = [100, 200];
    const spending = [50, 400];
    const max = sharedMax([income, spending]);
    expect(max).toBe(400);
    const inc = linePointsScaled(income, max, 320, 120, 10);
    const spd = linePointsScaled(spending, max, 320, 120, 10);
    // spending's 400 is the global max, so it sits higher than income's 200.
    expect(spd[1].y).toBeLessThan(inc[1].y);
    // Same value on either series would land at the same height: check by
    // scaling income's 200 and spending's 400 against the shared 400.
    expect(inc[1].y).toBeGreaterThan(spd[1].y);
  });

  test('sharedMax of empty input is 0 and scaled points sit on the baseline', () => {
    expect(sharedMax([])).toBe(0);
    const pts = linePointsScaled([0, 0], 0, 320, 120, 10);
    for (const p of pts) expect(p.y).toBe(110);
  });
});
