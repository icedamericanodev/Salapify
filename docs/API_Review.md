# API Review

Sprint 0 engineering audit, 2026-07-10.
Scope: every network surface the app touches, inbound and outbound, plus the
readiness of the codebase for a future first party API.

## Summary

Salapify is offline first with no backend, so the API surface is deliberately
tiny. The entire production network footprint is:

1. Exchange rates fetch (open.er-api.com), read only, anonymous, no user data sent.
2. Expo OTA updates (u.expo.dev), the standard expo-updates channel poll.
3. Nothing else. No analytics, no crash reporting, no auth server, no sync.

This is a strength for privacy and reliability, and the code treats the one
optional API correctly (never load bearing, always overridable by hand). The
gaps are all forward looking: no HTTP client abstraction, no retry or backoff
conventions, no certificate pinning, and no place to put a first party API when
one is needed (sync, AI, or Pro licensing will all eventually want one).

## Surface 1: Exchange rates (open.er-api.com)

Where: mobile/lib/fxrates.js (pure logic, 70 lines) and
mobile/hooks/useFxRates.js (fetch and cache, 82 lines).

What it does: fetches https://open.er-api.com/v6/latest/{base} to pre fill the
exchange rate when logging a foreign currency expense. Free endpoint, no API
key, HTTPS, response cached and refetched at most every 12 hours
(FX_MAX_AGE_MS).

What is done well:

- The design comment states the contract: it only makes the app nicer when
  online, never load bearing for correctness. Offline or on failure the user
  types the rate by hand.
- Parsing is defensive: parseRatesResponse returns null on any unexpected
  shape, basePerUnit and crossRate return null on missing or non positive
  rates, so a bad payload can never produce a wrong figure silently.
- No user or financial data is sent; the only outbound information is the base
  currency code, which is not PII.
- The pure layer is unit tested (mobile/__tests__/fxrates.test.js).

Issues:

### API-1: Single unvetted third party dependency with no fallback provider

Severity: Low
Business impact: if open.er-api.com shuts down or changes shape, the
convenience feature silently degrades for all users until an OTA update.
Technical impact: provider URL and shape are hardcoded; swap is easy but reactive.
User impact: rate field stops pre filling; manual entry still works, so impact is soft.
Recommendation: none needed now, the failure mode is graceful by design. If FX
becomes a headline feature, add a second provider behind the same
parseRatesResponse seam. Effort: S.

### API-2: No timeout on the FX fetch

Severity: Low
Business impact: negligible.
Technical impact: a hanging fetch holds the hook in a loading state; RN fetch
has no default timeout on Android in some stacks.
User impact: the rate field may wait indefinitely on a bad connection instead
of falling back to manual entry.
Recommendation: wrap the fetch with an AbortController and a 10 second
timeout. Effort: S (a few lines).

## Surface 2: Expo OTA updates (u.expo.dev)

Where: mobile/app.json (updates.url), expo-updates ~29.0.18, runtimeVersion
1.4.0, channel preview via .github/workflows/eas-update.yml.

Assessment: this is Expo's managed update protocol; manifests are signed by
Expo's infrastructure and scoped by runtime version, which the project manages
correctly (runtime bumps on native changes are called out in CLAUDE.md and the
workflow comments). The supply chain risk concentrates in the EXPO_TOKEN
repository secret and the GitHub Actions workflow; see Security_Audit.md for
that chain. From an API design standpoint the setup is sound.

## Surface 3: The legacy web app (root of the repo)

index.html (about 300KB single file PWA, the v1 Peso Smart app) plus sw.js is
served via GitHub Pages. It is a static page with a service worker; it makes
no API calls. It is legacy surface kept for existing v1 users and the privacy
policy page. Not an API concern beyond its existence being undocumented; see
Technical_Debt.md.

## Readiness for a first party API

There is no first party backend today and nothing in the app assumes one.
When one becomes necessary, the likely drivers in order are:

1. AI assistant proxy (see AI_Readiness.md, the API key cannot ship in the APK).
2. Pro entitlement checks or receipt validation for monetization.
3. Optional encrypted cloud backup or multi device sync.

What the codebase would need first:

### API-3: No shared networking layer or conventions

Severity: Medium (forward looking; not a defect today)
Business impact: each future network feature will reinvent fetch handling,
multiplying bugs in the least testable part of the app.
Technical impact: no shared timeout, retry, backoff, error taxonomy, or
offline queue exists; useFxRates.js is the only pattern and it is bespoke.
User impact: inconsistent failure behavior between future online features.
Recommendation: when the second network feature is built (not before), extract
a small lib/net.js with fetchJson(url, {timeoutMs, retries}) and a single
error shape, and route both features through it. Effort: S.

### API-4: No certificate pinning and no readiness hook for it

Severity: Low today (public data only), rises to Medium once a first party
API carries user data.
Business impact: MITM on public FX rates is harmless; MITM on future sync
would be serious.
Technical impact: expo managed workflow does not pin by default; pinning needs
a config plugin or a native module, meaning an APK rebuild.
User impact: none today.
Recommendation: no action now. Decide on pinning (or at least TLS version and
domain allowlisting) as part of the first party API design, since it forces a
native rebuild and must ride an APK release, not OTA. Effort: M when needed.

### API-5: No rate limiting or abuse thinking yet (client side)

Severity: Low (N/A until an API exists)
Recommendation: design quotas into the future proxy from day one, keyed on an
anonymous install id rather than accounts, since the app has no auth. Effort:
part of the proxy work.

## Inbound interfaces (imports)

The app accepts external data in three places, which function as its inbound
API and are the real attack surface today:

- Backup JSON restore (mobile/lib/backup.js): sanitizeData rebuilds a fixed
  shape, coerces numbers, drops unknown collections, and refuses newer schema
  versions. This is a genuinely well built validation boundary.
- v1 import (same file): maps the legacy web app's localStorage export.
- Receipt OCR (mobile/lib/ocr.js, receipt-parse.js): ML Kit text output parsed
  with regexes; results are user confirmable before saving.

See Security_Audit.md for the deeper validation assessment of these paths.

## Overall grade

For the product as designed (offline first, no accounts), the API posture is
appropriate and clean: one optional read only integration, handled
defensively, plus a managed OTA channel. The forward looking gaps (no net
layer, no pinning, no proxy) are correctly sized as design work to do when the
first real API feature is committed, not as retrofits owed today.
