// Smoke test: proves the runner discovers tests and can import a pure lib
// module through the Expo babel transform. If this fails, the harness is
// misconfigured, not the app.
import { RATES_YEAR } from '../lib/phtax';

test('jest can import a pure lib module and read its constant', () => {
  expect(RATES_YEAR).toBe(2026);
});
