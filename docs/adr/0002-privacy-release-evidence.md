# ADR 0002: A trustworthy Android privacy contract, production release path, and honest product evidence

- Status: ACCEPTED (founder approved the four recommended options on 2026-07-31).
- Date: 2026-07-31
- Scope: significant security, notification, native-build, and production-release
  change. Delivered in stages, base APK first, per the founder's decision.

This is a decision record, not an implementation. Every factual claim was
verified against the code at the merge of f3.04 on 2026-07-30. File references
are given so a reviewer can check them. Platform behavior is cited to the
official Android and Flutter documentation, listed at the end.

## Why this phase exists

The goal, in the founder's words, is to make the Android privacy contract, the
production release path, and the product evidence trustworthy BEFORE adding more
user-facing features. Trust is the product for a money app that keeps everything
on the phone, and three parts of it are currently either implicit, unproven, or
contradicted by the code:

1. The privacy contract is stated in the app (the Privacy receipt) and enforced
   at one attribute (`allowBackup="false"`), but the shipped manifest is never
   verified against what the receipt claims, and the notification text
   contradicts the promise on the lock screen.
2. The release path signs every build with a committed preview key and labels
   the app "Salapify Preview". There is no production artifact, and nothing
   proves a production build would drop the preview key, preview copy, testing
   aids, or preview flags.
3. There is no product measurement at all, so there is no honest way to learn
   what helps users without reaching for something that would break the privacy
   promise.

## The source manifest is not the shipped manifest

Verified on 2026-07-30. `flutter/android/app/src/main/AndroidManifest.xml`
declares four permissions (INTERNET, USE_BIOMETRIC, POST_NOTIFICATIONS,
RECEIVE_BOOT_COMPLETED). The app actually ships nine: the Privacy receipt
already documents VIBRATE, WAKE_LOCK, ACCESS_NETWORK_STATE, and FOREGROUND_SERVICE,
all merged in by plugins (`lib/screens/privacy_receipt.dart:227-329`). Nothing in
the build verifies the merged set. This is the exact gap the founder named: do
not assume the source manifest equals the shipped manifest. This phase closes it
with a CI check that reads the MERGED manifest out of a real build and asserts an
allowlist.

## The four decisions (founder approved 2026-07-31)

### 1. Android backup posture: complete exclusion

Financial data is completely excluded from platform cloud backup and device
transfer. `allowBackup` stays `false`, and both explicit rule files are added as
defense in depth so the exclusion survives even if that attribute is ever
changed:

- `res/xml/data_extraction_rules.xml` for Android 12 and newer
  (`android:dataExtractionRules`), with separate `<cloud-backup>` and
  `<device-transfer>` sections that exclude everything.
- `res/xml/backup_rules.xml` for Android 11 and lower
  (`android:fullBackupContent`), excluding everything.

The Android documentation is explicit that a separate Android 11 rules file must
always be specified even when the app targets Android 12 or higher, because the
two formats are read by different OS versions. The encrypted database is useless
off the device anyway: its key lives in the Android Keystore and is not backed
up, so a restored copy could not be opened. The alternative, a deliberate
encrypted backup design, was rejected: it adds real surface for a restore that
still cannot open without the key.

### 2. Lock-screen notifications: generic by default, detail behind opt-in

Today the `bills` and `collect` reminders put debt names, person names, and peso
amounts directly into the notification title and body
(`lib/money/reminders.dart:150-193`), and the shared `AndroidNotificationDetails`
sets no visibility (`lib/services/notifications.dart:90-99`), so those render on
the lock screen. A test currently ENFORCES the peso amount "on the lock-screen
line" (`test/reminders_test.dart:137-138`); that test encodes the defect.

The default becomes generic redacted text with no name and no amount, on a
channel with `VISIBILITY_PRIVATE` (the generic content is safe on the lock
screen anyway). A clear opt-in setting turns detail back on. When detail is on,
the reminder uses a separate `VISIBILITY_SECRET` channel, which Android keeps
off a secure lock screen entirely regardless of the user's "show sensitive
content" setting, so the name and amount appear only in the shade after unlock.
`VISIBILITY_PRIVATE` was considered and rejected for the detailed case: it
redacts only when the user has separately chosen to hide sensitive content, and
many phones default to showing everything, so it would leak the body on the
lock screen for those users. Titles stay generic in both modes because a title
can still surface on the lock screen. The enforcing test is inverted to prove
the default carries no name or amount.

### 3. Production artifact identity: separate flavors, production safe by default

Two Gradle product flavors, `preview` and `prod`, sharing one `applicationId`
(`dev.icedamericano.salapify`) so the preview app the founder runs stays
installable in place. Preview keeps the committed key, the "Salapify Preview"
label, and the testing aids (`kTestingAids`, already gated in
`lib/build_flags.dart`). Prod uses the upload key loaded from a repo secret at
build time (never committed), the "Salapify" label, and `SALAPIFY_PREVIEW=false`.
Production is the default in the production workflow. CI asserts a production
build cannot use the preview certificate, preview copy, sample-data aids, or
preview flags. Introducing flavors changes the Shorebird release identity and is
native, so it forces a new base APK; the preview and Shorebird commands move to
`--flavor preview` and are proven on a real runner before merge.

### 4. Local product measurement: on device by default, never sensitive

A new counters store lives under its OWN key, never inside `salapify_data_v2`,
following the diagnostics rule that a side feature must not share the ledger's
blob (`lib/services/diagnostics.dart:29-31`). It holds counters only, for
activation and feature funnels, and can never contain an amount, label, name,
account name, note, free-text Pan prompt, exact transaction date, or file path.
Counters stay on the device. A local tester diagnostics view shows them, and
sharing is a manual opt-in of a safe aggregate, previewed before it leaves the
phone, mirroring the diagnostics copy-after-preview pattern
(`lib/screens/update_card.dart:146-148`). Nothing is ever auto-uploaded. A
privacy test proves no metric payload can include a financial value or user
text.

## Never collected

Amounts, labels, names, account names, notes, free-text Pan prompts, exact
transaction dates, and file names or paths. This applies to notifications by
default, to diagnostics (already enforced by `test/diagnostics_test.dart`), and
to the new metrics store (enforced by a new privacy test).

## Target SDK

Flutter 3.44.6 resolves `flutter.targetSdkVersion` to 36 (Android 16), so the
app already targets Android 16, but only implicitly through the Flutter default,
which can move. This phase pins `targetSdk = 36` literally in
`build.gradle.kts` with a test, and adds tests for the Android 16 behavior
changes that touch this app. Google Play requires new and updated apps to target
at least Android 15 (API 35) by 2026, so 36 clears the bar with margin.

## Delivery, staged

Per the founder's decision, base APK first:

- PR 1 (native, one manual base-APK install): the privacy contract. Backup rules
  and guards, secure-window tied to App Lock, generic notifications and the
  opt-in, explicit `targetSdk = 36` and tests, the CI merged-manifest allowlist,
  SHA-pinned actions, and the Flutter check on PRs without duplicate runs.
- PR 2 (native): the production flavor and AAB workflow, upload signing from a
  secret, production label, and the CI assertions that production cannot use the
  preview key, copy, testing aids, or flags.
- PR 3 (over the air): the evidence. Privacy-receipt copy derived from verified
  behavior, the local metrics store and tester view with opt-in safe sharing, and
  real README and pubspec descriptions.

Native changes force a new base APK the founder installs by hand; over-the-air
updates cannot cross that boundary. This is flagged loudly at each merge, per the
standing rule.

## How each guard is proven

Every new guard is proven to fail before it is trusted, per the repo rule: the
manifest allowlist is broken and watched to redden, the backup-rules test is run
against a manifest with the attribute removed, the notification redaction test is
run against the old leaking strings, the secure-window test against a build that
never sets the flag, and the metrics privacy test against a payload carrying an
amount. The failure line goes in each commit message.

## Sources

- Android, Back up user data with Auto Backup (dataExtractionRules and
  fullBackupContent, and the rule that an Android 11 file must always be
  specified): https://developer.android.com/identity/data/autobackup
- Android, Security recommendations for backups:
  https://developer.android.com/privacy-and-security/risks/backup-best-practices
- Android, notification visibility on the lock screen (VISIBILITY_PUBLIC,
  VISIBILITY_PRIVATE, VISIBILITY_SECRET, and the redacted public version):
  https://developer.android.com/develop/ui/views/notifications/build-notification
- Android, secure sensitive activities (FLAG_SECURE blocks screenshots and the
  recents thumbnail): https://developer.android.com/security/fraud-prevention/activities
- Flutter, set up flavors for Android:
  https://docs.flutter.dev/deployment/flavors
- Google Play, target API level requirement:
  https://developer.android.com/google/play/requirements/target-sdk
