# Security Audit

Sprint 0 engineering audit, 2026-07-10. Scope: the mobile app in mobile/, the
legacy static site at the repo root, and CI/CD in .github/workflows. Review
only, no files modified. Effort scale: S under 1 day, M 1 to 3 days, L 1 to 2
weeks.

## Executive summary

The mobile app is unusually disciplined for its stage: minimal permissions, no
analytics or ad SDKs (verified against mobile/package.json), a hardened
restore path, injection safe CI, and allowBackup false. The real problems
cluster in four places: (1) the Play data safety draft makes a factually false
no transmission claim, (2) the exchange rate fetch fires on app open, which is
broader than what privacy.html promises, (3) the legacy Peso Smart PWA still
live at the GitHub Pages root has unescaped innerHTML rendering and an
unpinned CDN script on the same origin as the privacy policy and the web app,
and (4) the OTA pipeline lets a single compromised branch or token push
arbitrary JS to every installed finance app with no signing or review gate.

Verdict: BLOCKED for store submission until the must fix list at the end is
done. Most items are under a day each.

## Findings, ranked by severity

### SEC-1: OTA update chain is a single point of compromise for every device

Severity: High | Effort: M (pinning and token scoping S, code signing and
branch protection M)
Where: .github/workflows/eas-update.yml lines 15 to 27 (triggers on any push
to claude/salapify-v2 touching mobile/, plus workflow_dispatch), line 47 (npm
install -g eas-cli, unpinned latest), line 54 (EXPO_TOKEN). The same notes
apply to build-apk.yml lines 36 to 42 (unpinned global eas-cli, same token).
Exploitation scenario: anyone who can push to the publishing branch, anyone
holding a leaked EXPO_TOKEN, or a malicious release of eas-cli pulled fresh
from npm on every run, ships arbitrary JavaScript that runs inside a finance
app on every user's phone at next open. That JS can read the entire
salapify_data_v2 blob and receipt photos and exfiltrate them. EAS Update has
no end to end code signing configured here, so trust rests entirely on the
Expo account and the GitHub branch. No branch protection or independent
review gate exists; the working rules have the same agent authoring and
merging.
Business impact: a silent supply chain compromise of a finance app is a
company ending trust event and a Play policy violation.
Technical impact: remote code execution in app, full data read, on all
installs on the preview channel.
User impact: total loss of financial data confidentiality with no visible
sign.
Recommendation: pin eas-cli to an exact version, pin actions to commit SHAs,
protect the publishing branch (require review, restrict push), scope
EXPO_TOKEN to this project only and rotate it now, and enable EAS Update code
signing before production. Keep the existing env based commit message passing
(lines 53 to 56), which is already injection safe.

### SEC-2: Play data safety draft claims no transmission, but the app makes an outbound network call

Severity: High | Effort: S
Where: docs/play-store-listing.md lines 94 to 96 say data encrypted in
transit is not applicable because there is no transmission. But
mobile/hooks/useFxRates.js line 55 calls fetch to https://open.er-api.com
(mobile/lib/fxrates.js lines 17 to 18).
The nuance: the fetch sends only a currency code, not user data, so no data
collected or shared is defensible. But no transmission is literally false, so
the encrypted in transit not applicable answer is wrong. The device IP is
exposed to a third party, which is a disclosure Play expects to be
characterized honestly.
Business impact: app suspension risk, and a credibility hit for a privacy
positioned brand. The listing line nothing is uploaded, ever
(play-store-listing.md line 60) is likewise contradicted.
Technical impact: none to the device; this is an accuracy and compliance
defect.
User impact: users were told nothing leaves the phone; a request with their
IP does leave when the currency feature is active.
Recommendation: update the data safety form to reflect the exchange rate call
(transmission happens over HTTPS, no personal data collected). privacy.html
lines 54 to 55 already describe this accurately, so align the Play form to
it. Reconcile the listing line to something like your financial data is never
uploaded.

### SEC-3: Legacy Peso Smart PWA at the Pages root has unescaped innerHTML rendering and an unpinned third party CDN, sharing the origin with the privacy policy and web app

Severity: High | Effort: S to retire, M to harden
Where: index.html. User controlled values are interpolated straight into
innerHTML template strings, for example debt name at line 549, income name at
671, expense name at 756, source name at 795, account name at 823. There are
45 innerHTML occurrences and no HTML escaping helper is defined. The app
pulls Chart.js from a third party CDN with no Subresource Integrity
(index.html line 95 and sw.js line 10).
Exploitation scenario: a v1 user who types a debt or person name containing
markup, or imports a crafted v1 file, gets that markup rendered as live HTML
in their own browser (self stored XSS). More seriously, the CDN script runs
with full DOM access on icedamericanodev.github.io, the same origin that
serves privacy.html and the /app web build. A CDN compromise or a cache
poisoned service worker entry executes attacker JS on the domain.
Business impact: reputational, and it weakens the privacy story since the
same origin hosts the policy users are told to trust.
Technical impact: DOM XSS in the legacy app; third party script with no
integrity check on a shared origin.
User impact: v1 users only; data is local so blast radius is that user's own
browser, but it is still script execution.
Recommendation: decide whether the legacy root app is still shipped. If it
is, add an HTML escape helper for every data interpolation and add SRI plus a
pinned version to the Chart.js tag (and the sw.js cache entry), or self host
it. If it is not needed, stop deploying index.html and sw.js at the Pages
root and serve only the marketing page, privacy policy, and /app. The Pages
workflow copies these unconditionally (pages.yml line 30).

### SEC-4: Financial data and receipts are stored in plaintext at rest, with no app level encryption

Severity: Medium | Effort: L (needs a native module and a migration path)
Where: mobile/lib/storage.js lines 39 to 50 write the whole blob as plain
JSON to AsyncStorage. Receipts are plain image files under the documents
directory (mobile/lib/receipts.js). No expo-secure-store, SQLCipher, or
Keystore usage anywhere.
Why Medium not High: on a non rooted Android device, app private storage is
sandboxed from other apps, and allowBackup false (app.json) blocks ADB backup
extraction. The plaintext is protected by the OS sandbox and device lock, not
by the app. The privacy policy does not promise encryption at rest, so this
is a resilience gap, not a policy mismatch.
Exploitation scenario: a rooted or malware infected device, a forensic
extraction, or a physical attacker with an unlocked phone reads every account
balance, debt, salary figure, and the names and phone numbers of people who
owe the user, all in clear text. The app lock (SEC-6) is a UI overlay, not
encryption, so it does not protect the file.
Business impact: elevated for a finance app holding third party PII.
Technical impact: no defense in depth beyond the OS sandbox.
User impact: full disclosure of finances and contacts if the device is
compromised or seized.
Recommendation: for the next native build, move the master data blob behind
an encrypted store (SQLCipher backed store, or wrap the blob with a key held
in expo-secure-store and the Android Keystore). Treat as a roadmap item since
it needs a rebuild, not an OTA. Bundle with the SQLite migration.

### SEC-5: FX fetch fires on app open regardless of feature use, broader than the privacy policy states

Severity: Medium | Effort: S
Where: mobile/hooks/useFxRates.js lines 28 to 79. The hook fetches on a cache
miss whenever it mounts, and it is mounted by LogSheet (LogSheet.js line 77),
which is rendered by the tab layout. So the rate request can go out on
ordinary app open, before the user selects any foreign currency. The policy
text at privacy.html lines 54 to 55 says the request happens when, and only
when, you use a currency feature. It is throttled to twice a day and sends
only the base currency code, so the exposure is minimal, but the timing claim
is not strictly true.
Business impact: privacy policy accuracy exposure, same class as SEC-2.
Technical impact: extra IP disclosure to a third party on app open.
User impact: the third party sees the device IP more often than the policy
implies.
Recommendation: gate the fetch so it only runs after a foreign currency is
actually selected (align code to policy), or soften the policy wording.
Aligning the code is cleaner for the privacy promise.

### SEC-6: App lock is a render time overlay with a bypass window and self disabling behavior

Severity: Medium | Effort: M
Where: mobile/components/LockGate.js.
- Children always render underneath the lock overlay (lines 91 to 98); the
  lock is an absolute fill view drawn on top (line 100). Content is only
  hidden from screen readers. Anything that captures the view tree before the
  overlay paints, or reads state rather than pixels, is not gated.
- loadFailed passthrough: lines 87 to 89 render the whole app when settings
  could not be read, even if app lock would have been on. A deliberate anti
  lockout tradeoff, but a real bypass path.
- Unenrolled biometrics disables the lock entirely: lines 36 to 42 turn
  appLock off and unlock when no biometrics are enrolled. Removing enrolled
  fingerprints silently and permanently unlocks the app.
- No PIN fallback and no app level attempt counter (OS level throttling
  applies via LocalAuthentication).
Business impact: the store listing sells the fingerprint lock as a privacy
feature; users may over trust it.
Technical impact: the lock is a convenience shield over plaintext data (see
SEC-4), not a security boundary.
User impact: financial data viewable in the scenarios above.
Recommendation: document the lock honestly as a casual privacy shield. For
real protection, pair it with at rest encryption (SEC-4) so data is
unreadable without authentication rather than visually covered. Keep the lock
setting sticky (show a re enroll prompt instead of auto disabling) and
consider a PIN fallback with attempt limiting. The 60 second background grace
window is reasonable for usability.

### SEC-7: Backup and CSV exports contain debtor names and phone numbers in cleartext

Severity: Low | Effort: S to confirm the data safety form, M for an encrypted
backup option
Where: mobile/lib/backup.js buildBackup serializes the entire data object;
people, receivables, and payables include name, phone, and note. The policy
discloses this (privacy.html line 47). Receipts are correctly excluded from
backups. Positives: the backup does not leak app lock state, and restore
forces appLock off so a backup cannot lock someone out.
Harm scenario: a user shares a backup file to an insecure destination and
third party PII (other people's phone numbers) leaks. App cache copies are
cleaned up promptly (mobile/lib/files.js), which is good hygiene.
Recommendation: keep the in app warning. Consider an optional passphrase
encrypted backup format later. Confirm the Play data safety form notes that
user initiated exports can contain contact info the user entered.

### SEC-8: Restore and import validation is strong; the size cliff is the remaining availability risk

Severity: Low | Effort: covered by the SQLite roadmap (L)
Where: validation is genuinely good. mobile/lib/backup.js lines 156 to 174
refuse newer schema data and clamp hostile version values; sanitizeData
coerces every field, strips crafted receiptUri path traversal, rejects
negative amounts, dedupes category ids, and validates the category tree.
parseBackup rejects non backup files. This is a well defended restore path.
The availability note: Android refuses to read AsyncStorage rows near 2MB
(documented in storage.js), the app warns but nothing caps growth. Data loss
capable even though it is not an attacker path; see Database_Review.md.

### SEC-9: OCR runs on device; confirm the native ML Kit module ships no telemetry

Severity: Low | Effort: S to verify
Where: mobile/lib/ocr.js uses @react-native-ml-kit/text-recognition and the
comments state the photo and text never leave the phone. Google ML Kit on
device text recognition is local, but model download and Play Services
telemetry are outside this repo's control.
Recommendation: verify with a network capture on a real build that ML Kit
does not phone home, and ensure the on device (not cloud) recognizer is used.
Document the dependency in the data safety review.

## OWASP Mobile Top 10 (2024) ratings

- M1 Improper Credential Usage: LOW. No credentials, no accounts, no API keys
  in the client (grep found only EXPO_TOKEN in CI, never in app code).
- M2 Inadequate Supply Chain Security: HIGH. OTA pipeline and unpinned
  eas-cli and CDN, see SEC-1 and SEC-3.
- M3 Insecure Authentication and Authorization: MEDIUM. App lock is an
  overlay with bypass paths, see SEC-6.
- M4 Insufficient Input and Output Validation: MEDIUM. The mobile restore
  path is well hardened; the legacy web app is not (SEC-3).
- M5 Insecure Communication: MEDIUM. The only outbound call is HTTPS to a
  public FX API, no pinning. Acceptable for non sensitive data but disclosure
  accuracy is off (SEC-2, SEC-5). No certificate pinning readiness.
- M6 Inadequate Privacy Controls: MEDIUM. Strong intent, but policy versus
  behavior mismatches (SEC-2, SEC-5) and third party PII in exports (SEC-7).
- M7 Insufficient Binary Protections: LOW to MEDIUM. No root detection, no
  obfuscation, plaintext at rest (SEC-4). Reasonable for the threat model
  today.
- M8 Security Misconfiguration: LOW. allowBackup false, minimal permissions,
  CI permissions scoped to contents read.
- M9 Insecure Data Storage: MEDIUM. Plaintext AsyncStorage and plaintext
  receipt files, sandbox protected only (SEC-4).
- M10 Insufficient Cryptography: MEDIUM. No cryptography is used at all where
  at rest encryption would be expected for a finance app.

## Readiness assessments requested in scope

- Certificate pinning: not implemented, not currently needed (public data
  only). Requires a native rebuild when a first party API ships; decide then.
- Root and jailbreak detection: not implemented. For an offline single user
  app the main beneficiary would be the at rest encryption story; consider
  only after SEC-4, and weigh the false positive cost on the target market's
  rooted budget phones.
- Rate limiting: N/A today (no server). Design quotas into any future proxy
  from day one.
- Session management: the lock re triggers after a 60 second background grace
  window, a sane default. No other session concept exists.

## Security strengths (verified, worth keeping)

- No analytics, crash reporter, or ad SDK in mobile/package.json. The no
  trackers claim in privacy.html holds against the dependency list.
- Only one app code network call exists (useFxRates.js to a public FX API);
  grep for fetch, axios, and XMLHttpRequest across mobile/ found nothing
  else. No hidden endpoints, no hardcoded secrets in app code.
- Restore and import is defense in depth hardened: schema fencing, field
  coercion, path traversal rejection on receiptUri, category tree validation.
- allowBackup false blocks ADB and system backup exfiltration.
- Erase actually erases: replaceAll with snapshot false clears the hidden
  snapshot key, cleanupReceipts deletes orphaned photo files, and the peak
  net worth key is removed. Cannot be undone is literally true.
- Logging is safe: every console.warn logs a generic message or an error
  object, never balances, names, or amounts.
- CI is injection safe: the commit message passes through an env var, not
  shell interpolation, and workflow permissions are least privilege.
- Receipts live in app private storage, are excluded from backups, and are
  cleaned on delete, restore, and erase, matching the policy.

## PII inventory

- What: account names and balances, transactions, debts, salary figures
  implied by income entries, goals, notes, and third party PII: names, phone
  numbers, and notes for people who owe the user or whom the user owes.
  Receipt photos.
- Where: salapify_data_v2 in AsyncStorage (plaintext), receipt files in the
  documents directory (plaintext), FX cache in salapify_fx_v1 (no PII), peak
  net worth in salapify_peak_networth.
- Retention: indefinite on device until the user deletes items, erases, or
  uninstalls. No server retention (there is no server).
- Deletion capability: per item delete, Start fresh full erase with two
  confirmations, and uninstall. Deletion is complete (snapshot and receipt
  files included).

## Must fix before store submission

1. SEC-2: correct the Play data safety form and the nothing is uploaded
   listing line. (S)
2. SEC-1: pin eas-cli and action SHAs, protect the publishing branch, scope
   and rotate EXPO_TOKEN, enable EAS Update code signing before production. (M)
3. SEC-3: retire the legacy PWA from the Pages root, or escape its HTML and
   pin the CDN script with SRI. (S to retire, M to harden)
4. SEC-5: align the FX fetch timing to the privacy policy. (S)

Should fix on the roadmap: SEC-4 plus SEC-6 together (at rest encryption so
the lock becomes a real boundary; needs a native build, L), SEC-7 encrypted
backup option (M), SEC-9 ML Kit verification (S).
