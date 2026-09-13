# Dependencies Review

Sprint 0 engineering audit, 2026-07-10.

## Summary

A deliberately small, healthy, SDK aligned dependency set: 27 runtime
dependencies and 3 dev dependencies in mobile/, all exactly on the versions
Expo SDK 54 expects (expo ~54.0.0, react 19.1.0, react-native 0.81.5). No
version drift found. Only two third party native modules of note (ML Kit OCR
and android-widget), both single purpose and gracefully degrading. The
material missing pieces are crash reporting, a real storage engine before the
2MB wall, and billing infrastructure for the Pro tier.

## mobile/package.json runtime dependencies

| Package | Version | Used | Purpose and notes | Risk |
| --- | --- | --- | --- | --- |
| expo | ~54.0.0 | yes | SDK core | Baseline |
| react, react-dom | 19.1.0 | yes / web only | react-dom needed only for the web target | Low |
| react-native | 0.81.5 | yes | Matches SDK 54 | Low |
| expo-router | ~6.0.24 | yes (38 files) | File based navigation, the app's backbone | Low |
| @expo/vector-icons | ^15.1.1 | yes (38 files) | Icons | Low |
| @react-native-async-storage/async-storage | ^2.2.0 | yes (6 files) | The entire persistence layer | Native module; the 2MB per row ceiling is the real risk, not the package |
| @react-native-ml-kit/text-recognition | ^2.0.0 | yes (lib/ocr.js only) | On device receipt OCR (Google ML Kit) | Native, community maintained; requires an APK rebuild to change; code already degrades gracefully if absent |
| @shopify/react-native-skia | ^2.2.12 | yes (TrendChart, RecapShare, MascotSkia) | Charts and the share card rendering | Native, Shopify maintained, healthy; note the MascotSkia consumer is dead code |
| react-native-reanimated | ^4.1.1 | yes (8 files) | Animations, keyboard handling | Native; v4 requires react-native-worklets, which is present |
| react-native-worklets | ^0.5.1 | peer only | Required by Reanimated 4 | Keep |
| react-native-android-widget | ^0.20.3 | yes (widgets/, app.json plugin) | The 10 Android home widgets | Native, effectively single maintainer; the only widget path, worth watching |
| react-native-safe-area-context | ~5.6.0 | yes (40 files) | Safe areas | Low |
| react-native-screens | ~4.16.0 | transitive | expo-router dependency, no direct import needed | Keep |
| react-native-web | ^0.21.2 | web target | The web build (the PhoneFrame demo) | Keep while the web target is kept |
| @expo/metro-runtime | ~6.1.2 | web target | Required for web bundling | Keep |
| expo-notifications | ^0.32.17 | yes (lib/notifications.js) | Local reminders only, no push | Native; Android OEM battery killers are the practical risk |
| expo-local-authentication | ~17.0.8 | yes (2 files) | The biometric app lock | Native; biometric only, no PIN fallback |
| expo-file-system | ~19.0.23 | yes (3 files) | Backups (SAF), receipts | Native |
| expo-image-picker | ~17.0.11 | yes (lib/receipts.js) | Receipt camera and library | Native; permissions configured in app.json |
| expo-document-picker | ~14.0.8 | yes (lib/files.js) | Restore file picking | Native |
| expo-sharing | ~14.0.8 | yes (2 files) | Share sheets (backups, recap PNG) | Low |
| expo-haptics | ~15.0.8 | yes (5 files) | Haptics via useHaptic | Low |
| expo-updates | ~29.0.18 | yes (more.js) | OTA updates, core to the release workflow | Low |
| expo-status-bar | ~3.0.9 | yes | Themed status bar | Low |
| expo-constants | ~18.0.13 | transitive | Required by expo-router | Keep (peer) |
| expo-linking | ~8.0.12 | transitive | Required by expo-router | Keep (peer) |
| expo-font | ~14.0.12 | transitive | Peer of @expo/vector-icons | Keep (peer) |
| expo-dev-client | ~6.0.21 | build time only | Dev builds; automatically excluded from release builds | Low |

Dev dependencies: babel-preset-expo ^54.0.11, jest ^29.7.0, jest-expo
~54.0.0. All correct for SDK 54.

Genuinely unused packages: none that can be safely removed. Every zero import
package (expo-constants, expo-linking, expo-font, react-native-screens,
react-native-worklets, @expo/metro-runtime, react-dom, react-native-web) is a
required peer of expo-router, vector-icons, Reanimated 4, or the web target.
The only removal candidates are react-native-web plus react-dom plus
@expo/metro-runtime if the web target were ever dropped.

## Root package.json

The legacy v1 static site (Peso Smart, index.html plus sw.js PWA). Dev only:
htmlhint ^1.1.4 and jsdom ^24.1.0, with a smoke test in tests/. No runtime
dependencies. This is a separate legacy artifact, not part of the mobile app;
see Technical_Debt.md TD-10 for its disposition.

## Gaps for a production finance app (nothing below is present)

### DEP-1: No crash reporting

Severity: High | Effort: M (Sentry is a native module, so an APK rebuild,
plus a privacy posture decision)
Business impact: offline first means there are no server logs at all; today
the only failure signal is user emails to the founder's address hardcoded in
more.js. The crash rate is unknowable.
Technical impact: ErrorBoundary catches render errors but reports them to no
one.
User impact: crashes persist invisibly until users complain or churn.
Recommendation: sentry-expo (or @sentry/react-native) in the next native
build batch, with the privacy policy updated to disclose it; interim, an opt
in send crash log share action from the ErrorBoundary.

### DEP-2: No secure storage primitive

Severity: Medium | Effort: S to add when first needed
expo-secure-store is not used. There is currently no secret to store (the
biometric lock delegates to the OS, there is no PIN), but any future PIN
fallback, Pro entitlement token, or encryption key needs it. Add it in the
same rebuild batch as at rest encryption (Security_Audit.md SEC-4).

### DEP-3: No SQLite

Severity: High (as the enabler for the storage ceiling fix) | Effort: XL for
the migration overall
expo-sqlite is the named plan in the code's own comments for escaping the
2MB AsyncStorage row limit. See Database_Review.md DB-1.

### DEP-4: No billing infrastructure

Severity: Medium now, Critical whenever monetization starts | Effort: XL
Pro is a free settings flag. react-native-purchases (RevenueCat) or expo-iap
will be needed, both native modules requiring a rebuild and Play Console
setup.

### DEP-5: No analytics or telemetry

Severity: advisory (a deliberate privacy stance)
No usage analytics exist, consistent with the privacy positioning, but it
means zero product visibility. If ever added, it should be opt in and
disclosed; a local only screen open counter surfaced through user initiated
feedback would preserve the stance.

### DEP-6: No i18n framework

Severity: Low | Effort: L if ever formalized
English and Tagalog copy is hardcoded inline across screens. Fine for the
current market; a rewrite cost if localization formalizes. Not recommended
now.

### DEP-7: No push notifications

Severity: none
Local notifications only, which fits the offline model. Push would require a
backend that does not exist. No action.

## Supply chain notes

- CI installs eas-cli unpinned at latest on every workflow run
  (Security_Audit.md SEC-1); pin it.
- GitHub Actions are referenced by tag (v4), not SHA; pin for supply chain
  rigor.
- The legacy page loads Chart.js from a CDN without Subresource Integrity
  (Security_Audit.md SEC-3).
- npm ci with committed lockfiles is used everywhere, which is correct.
- Renovate or Dependabot is not configured; with an Expo managed set the SDK
  upgrade cadence mostly covers it, but enabling Dependabot security alerts
  on the repo is free and worthwhile. Effort: S.
