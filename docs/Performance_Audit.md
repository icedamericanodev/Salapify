# Performance Audit

Sprint 0 engineering audit, 2026-07-10. Includes the scalability review
(Phase 7). Salapify has no servers, so scale means two different things here:
data volume on a single device (the real engineering question) and user count
(a distribution and infrastructure question). Both are covered.

## Summary

Today, with typical data (a few hundred transactions), the app performs well:
startup work is small, lists are capped or virtualized where it matters, and
animations run on Reanimated. The performance debt is concentrated in two
compounding designs: a single React context that re-renders every mounted
screen on every data change, and a single JSON blob that is fully parsed,
sanitized, stringified, and rewritten as data grows. Both are fine at 1k
transactions, measurable at 10k, and terminal at 50k.

## Device data scaling (the real ceiling)

Average transaction is about 160 bytes of JSON. The math by volume:

- 1,000 transactions: about 0.2MB blob. Startup JSON.parse plus the
  sanitizeData rebuild is under 100ms even on cheap Androids. No issue.
- 10,000 transactions: about 1.6 to 1.8MB, past the SIZE_WARN threshold.
  Startup does a synchronous parse plus a full sanitize rebuild of every row,
  realistically 300 to 800ms of blocked JS thread on a mid range Android.
  Every debounced save synchronously stringifies the whole blob (100 to
  300ms) on the JS thread. Blob plus the snapshot key approaches 3.5MB in one
  SQLite file against Android's 6MB default AsyncStorage cap.
- 50,000 transactions: about 8MB. Physically impossible under this design:
  Android's CursorWindow refuses to read AsyncStorage rows near 2MB, so the
  write may succeed and the read never will, permanently locking the user
  out. See Technical_Debt.md TD-2 and Database_Review.md.

A 10 entry per day user reaches SIZE_WARN in about 2.5 years. The users who
hit this are the daily loggers, exactly the ones who convert to Pro.

### PERF-1: Whole app re-render on every data change, unmemoized derivations

Severity: High at 10k rows, Medium today | Effort: M | Ships OTA: yes
Where: one AppDataContext consumed by 32 files. The provider value object is
rebuilt every render with no useMemo and all helpers are recreated
(mobile/context/AppData.js lines 524 to 540). expo-router keeps the tabs
mounted, so a single logged expense re-renders Home, Budget, Debts, Insights,
Tools, More, and any stacked screen. Within those renders: budget.js lines
106 to 112 sort the entire transactions array on every render with no
useMemo; insights.js lines 65 to 112 filter and aggregate unmemoized;
index.js lines 62 to 70 filter the full list per render.
Business impact: jank on logging, the most repeated interaction, on exactly
the phones the target market owns.
Technical impact: O(n log n) work times the number of mounted screens per
data change.
User impact: invisible at 1k rows; at 10k rows every log costs several full
array passes and sorts on the JS thread.
Recommendation, in order: (1) useMemo the provider value with stable
callbacks, (2) useMemo the heavy derivations in budget.js, insights.js, and
index.js keyed on data.transactions (effective because setData spreads
preserve untouched collection identities), (3) later, split state and actions
into two contexts.

### PERF-2: Startup and save cost grows linearly with history

Severity: Medium today, High at scale | Effort: S for mitigations, XL for the
structural fix (see TD-4)
Where: every save stringifies the entire blob (storage.js saveData); every
startup parses and sanitize rebuilds every collection (AppData.js load
effect, backup.js sanitizeData).
Mitigations already present and good: the 500ms save debounce batches rapid
taps; the auto backup stringify runs after interactions
(InteractionManager.runAfterInteractions) so it never janks the resume frame.
Recommendation: the structural fix is the SQLite migration (per row writes,
indexed reads). Until then, the memoization work in PERF-1 and the hard size
guard in TD-2 are the right holds.

### PERF-3: List rendering is mostly ScrollView plus map, with the right exceptions

Severity: Low | Effort: S where needed
Where: only history.js and pan.js use FlatList (history.js is built right for
scale: virtualized, memoized rows, edit sheet owning its own typing state).
Other screens use ScrollView plus map, acceptable because visible collections
are small or capped (the budget Recent list is capped at 12).
Recommendation: no action now. If receivables or payables person groups grow
unbounded for heavy utang users, move those screens to FlatList when next
touched.

### PERF-4: Charts and animation are on the right architecture

Severity: none (strength)
Skia renders the trend charts with geometry precomputed in the pure, tested
lib/chartgeom.js. Reanimated 4 drives motion with a reduce motion kill
switch. AnimatedNumber caps its work. The web only PhoneFrame adds nothing on
device. No findings requiring action.

### PERF-5: Widget refresh reads and parses the whole blob per widget cycle

Severity: Low | Effort: S
Where: widgets/widget-task-handler.js does a direct AsyncStorage read of
salapify_data_v2 on widget updates (10 widgets, 30 minute update period,
guarded to safe zeros). At today's blob sizes this is cheap; at 1.5MB it is a
repeated background parse cost, and it doubles as another reader that will
fail at the 2MB wall.
Recommendation: nothing now; the SQLite migration naturally fixes both. Keep
the never crash guards.

## User count scaling (100 / 10,000 / 100,000 / 1,000,000)

Because there is no backend, user count does not touch any server Salapify
runs. What actually scales with users:

- 100 users: nothing changes. Current setup is comfortable.
- 10,000 users: nothing in the app changes; every device is independent. The
  pressure points are operational: EAS Update bandwidth is a paid Expo
  metric at volume (free tier covers 1,000 monthly active users on updates;
  beyond that is a paid plan), and support becomes the bottleneck because
  there is zero telemetry: no crash reporting, no way to know a bad OTA
  bricked startup for some devices except email volume. The Update stamp row
  plus user emails is the entire incident detection system.
- 100,000 users: OTA update costs and rollout risk grow (a bad publish
  reaches everyone on next open; there is no staged rollout on a single
  channel). Crash reporting stops being optional. The FX endpoint
  (open.er-api.com free tier) rate limits by IP, and since every device calls
  it independently, that continues to work, but the provider's terms and
  availability become a real dependency. Monetization infrastructure (Pro is
  currently a free settings flag) must exist well before this point to fund
  the paid Expo tier.
- 1,000,000 users: same architecture still fundamentally works on device,
  which is the beauty of offline first. The binding constraints are
  distribution and operations: staged OTA rollouts and code signing become
  mandatory (see Security_Audit.md SEC-1), crash and ANR monitoring at Play
  console level plus Sentry, a support system beyond a mailto link, and
  almost certainly a thin backend for entitlements and the AI features on
  the roadmap. Any future sync or backup service is a genuinely new system,
  not an extension of this one.

Identified bottlenecks in order of when they bite:

1. Device data volume (the 2MB wall), bites first and worst; fix is the
   SQLite migration (TD-4).
2. Zero observability, bites at a few thousand users; fix is Sentry plus
   Play vitals monitoring (TD-9).
3. OTA rollout safety (no staged rollout, no signing), bites with scale of
   blast radius; fix is EAS Update signing plus channel discipline (SEC-1).
4. Expo update bandwidth pricing, bites around 10k monthly active users;
   fix is budgeting or moving update hosting.
5. Monetization infrastructure absent, bites whenever revenue is needed;
   Pro entitlements are a settings flag today (TD-13).

## Strengths worth keeping

- The save pipeline (debounce, background flush, unmount flush) is loss aware
  without being chatty.
- InteractionManager use on the auto backup write shows the right instinct:
  heavy serialization off the interaction path.
- history.js proves the codebase knows how to build a virtualized list
  correctly; the pattern is ready to copy when other lists need it.
- Charts precompute geometry in pure code, keeping Skia draw passes cheap and
  testable.
- arm64-v8a only preview builds keep internal APKs small; the production
  profile correctly builds a full app bundle.
