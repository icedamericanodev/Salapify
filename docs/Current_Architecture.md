# Current Architecture

Sprint 0 engineering audit, 2026-07-10.

## One paragraph summary

Salapify is a single user, offline first personal finance app built with React
Native on Expo SDK 54 (React 19.1, RN 0.81), using expo-router file based
navigation, one React context as the entire state layer, and one AsyncStorage
key as the entire database. There is no backend; the only network calls are an
optional exchange rate fetch and Expo's OTA update poll. JavaScript changes
ship over the air via EAS Update from a GitHub Action; native changes require
an EAS APK rebuild. A deprecated v1 web app (single file PWA) still lives at
the repository root and is served by GitHub Pages.

## Runtime composition

The provider stack, from mobile/app/_layout.js:

```
ErrorBoundary                crash shield with Try again remount
  ThemeProvider              light/dark palette, context/Theme.js
    AppDataProvider          ALL persistent data, context/AppData.js
      MotionProvider         reduced motion preference, context/Motion.js
        SafeAreaProvider
          PhoneFrame         web only phone shaped preview frame
            LockGate         biometric/PIN gate when app lock is on
              OnboardingGate first run welcome flow, load failure screen
                Stack        expo-router, headerShown false
```

Navigation is two tiered: a 6 tab bottom bar, in mobile/app/(tabs)/, holding
home (index), budget, debts, insights, tools, and more, plus 27 stack screens
at mobile/app/ for everything else (goals, history, search, person, split,
settings pages, the Pan chat assistant, and 8 financial calculators).

## State management

There is exactly one state system. AppDataProvider (mobile/context/AppData.js,
552 lines) owns a single `data` object in useState containing every
collection: accounts, assets, debts, payments, transactions, goals, wins,
notes, recurring, people, categories, receivables, payables, and settings.
Screens consume it through useAppData() and mutate through a closed set of
helpers: generic addItem/updateItem/removeItem plus domain aware
addTransaction/updateTransaction/removeTransaction (which keep linked account
balances consistent by reversing and reapplying deltas), updateSettings,
recategorize, deleteCategory, and replaceAll (restore path).

Design properties worth noting:

- Transaction helpers are balance safe by construction: an edit reverses the
  old entry's effect and applies the new one, so drift is structurally
  impossible rather than policed by convention.
- The provider embeds a recurring posting engine (an effect that posts due
  bills once per month with a lastPosted month marker, resistant to clock
  jumps in both directions) and the auto backup scheduler.
- The load path is failure aware in a way most apps are not: a read error
  shows the seed data but permanently disables saving for the session, so one
  bad read can never overwrite real data with samples. Data from a newer
  schema version is refused rather than mangled.

The trade off: every consumer of useAppData() re-renders on every data change,
because the context value is a fresh object each render and the single blob is
the unit of change. At current data sizes this is acceptable; the performance
audit covers where it bites first.

## Persistence

mobile/lib/storage.js (85 lines) wraps AsyncStorage:

- STORAGE_KEY salapify_data_v2 holds the entire app state as one JSON string.
- SNAPSHOT_KEY salapify_data_v2_prev is a one deep safety net written before
  any destructive operation (restore, import, erase).
- Writes are debounced 500ms in the provider, flushed immediately on app
  background and on provider unmount, so a swipe kill right after logging an
  entry does not lose it.
- The Android 2MB AsyncStorage row read cliff is known and handled as a
  visible slope: SIZE_NUDGE at 700KB suggests a backup, SIZE_WARN at 1.5MB
  warns loudly. This is a real architectural ceiling; see Database_Review.md.

Schema versioning lives in mobile/lib/backup.js: SCHEMA_VERSION is 12, with a
MIGRATIONS table applied stepwise on load, a pre migration snapshot, and
sanitizeData as a rebuild everything validation boundary on every load and
restore. Backups are plain JSON text the user exports manually or via the
Android auto backup (Storage Access Framework folder, dated files, rotation,
foreground only writes to avoid mid write suspension truncating a file).

## Rendering and UI system

- theme.js (506 lines) defines palettes for light and dark plus type and
  spacing constants; context/Theme.js resolves the active scheme.
- Shared primitives in mobile/components/ (Card, SectionHeader, EmptyState,
  Bar, PeriodSelector, motion/PressableScale, AnimatedNumber, Celebration).
- Charts are Shopify react-native-skia (TrendChart) with geometry computed in
  the pure module lib/chartgeom.js (tested).
- The mascot Pan has three implementations (Skia, clay PNG, fallback) selected
  by capability.
- Android home screen widgets (10 of them) via react-native-android-widget,
  rendering from the same stored blob in a background task handler.

## The logic layer

mobile/lib/ holds 35 modules of pure, React free logic: Philippine tax tables
(phtax), salary and contribution math, loan and BNPL amortization, 13th month,
analytics and coach insights, week recap, search, allocation, categories,
statements/SOA parsing, receipt OCR parsing, holidays, tax deadlines, backup
and migration, and the Pan assistant engine (lib/pan/: normalize, intents,
resolvers, respond, ask). This layer is where the 313 passing unit tests
concentrate, and it is the strongest part of the codebase.

## Build, release, and CI

- eas.json defines development (dev client APK), preview (internal APK,
  arm64-v8a only, preview channel), and production (app bundle) profiles,
  with remote app version source and auto increment.
- .github/workflows/eas-update.yml publishes an OTA update to the preview
  channel on every push to claude/salapify-v2 touching mobile/, authenticated
  by the EXPO_TOKEN secret, with commit message injection guarded by passing
  it through an env var. Concurrency group prevents racing publishes.
- .github/workflows/build-apk.yml submits an EAS APK build when
  .github/build-request.txt changes (a deliberate manual trigger ritual).
- .github/workflows/ci.yml runs lint and tests for the LEGACY web page only,
  on PRs to main. The mobile Jest suite (17 suites, 313 tests, all passing as
  of this audit) is not executed by any CI workflow. This is the most
  important CI gap; see Technical_Debt.md.
- .github/workflows/pages.yml plus branch based Pages serving publish the
  legacy web app.

## Update and versioning model

runtimeVersion 1.4.0 with appVersion 1.4.1: JS only changes ride OTA within a
runtime; native changes (new modules, app.json plugins or permissions) bump
the runtime and require a full rebuild, isolating incompatible bundles. The
CLAUDE.md working rules encode this distinction, including bumping a visible
Update stamp in the More tab on every push so the founder can verify which
bundle arrived on the phone. This is a thoughtful, working release process for
a one person product with AI assistance.

## Architectural strengths

1. Pure logic layer with real test coverage on the money math.
2. Balance consistent transaction mutations by construction.
3. Failure aware persistence (load error never enables overwrites, save
   failures surface after three consecutive misses, background flush).
4. Migration framework with version refusal and pre migration snapshots.
5. Offline first honesty: the single network nicety is designed to never be
   load bearing.
6. Clear seam for future storage swap (screens never touch storage directly)
   and for a future LLM (Pan's facts versus phrasing split).

## Architectural ceilings

1. Single JSON blob persistence has a hard Android read ceiling (~2MB) and
   rewrite the world write amplification; fine today, needs SQLite or
   per collection keys before power users hit years of history. 
2. Single context means whole app re-renders on every mutation; fine at
   hundreds of transactions, measurable at thousands.
3. No crash reporting or telemetry of any kind; production failures are
   invisible unless a user emails.
4. No TypeScript and no static typing convention; the sanitize layer
   compensates at the data boundary but nothing protects intra app contracts.
5. CI does not run the product's tests (legacy page tests only).

Each ceiling is elaborated with severity and effort in Technical_Debt.md,
Performance_Audit.md, and Database_Review.md.
