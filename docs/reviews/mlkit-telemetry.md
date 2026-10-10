# ML Kit receipt reading sends usage metrics to Google

Date: 2026-10-10. Code examined: `claude/flutter-final` at `300ec93d`
(`google_mlkit_text_recognition` 0.17.1, which pulls
`com.google.mlkit:text-recognition` 16.0.1, the bundled model).
Evidence: [mlkit-telemetry/evidence.txt](mlkit-telemetry/evidence.txt).

**Status: FOUNDER DECISION NEEDED. Nothing has been changed.** No privacy
copy, no dependency, no manifest. This is a privacy decision (STOP condition 3
in CLAUDE.md), so it waits for the founder.

## The answer in plain English

Yes, data leaves the phone. Every time somebody scans a receipt, Google's ML
Kit library inside Salapify sends a small usage report to Google about 30
seconds later. It does NOT send the photo, the words on the receipt, or any
amount. It DOES send: which app, which version, the phone model and Android
build, the country, the mobile carrier code, the time zone, the language, the
network type, how long the reading took, and a random ID that stays the same
for that install of Salapify.

Opening the app without scanning sends nothing. The report only happens after
a scan.

So three of our promises are false today:

| Where | What it says | Why it is false |
| --- | --- | --- |
| `app/lib/features/settings/privacy_sheet.dart:104` | "Nothing is uploaded and no picture is sent anywhere." | The picture is not sent, but a usage report is uploaded during that same scan. |
| `app/lib/features/settings/privacy_sheet.dart:114` | "No analytics, no crash reporting, no ads" | ML Kit's report is usage analytics in Google's own words ("diagnostics and usage analytics"). |
| `app/lib/features/settings/privacy_sheet.dart:136` and `:144` | "One thing does leave this phone" and "If you never open the converter, Salapify makes no internet request at all." | A receipt scan makes a second, different request. |
| `privacy.html:27` (short version) | "no analytics, no trackers" | Same as above. |
| `privacy.html:35` (What we collect) | "Nothing. ... no analytics libraries" | ML Kit includes Google's analytics transport. |
| `privacy.html:41` (Internet permission) | "used for two things only" | There is a third use, and one of the two listed is wrong (see side findings). |
| Play data safety answers | Not yet written for Salapify 3 | Whatever is written must include this. The only existing draft, `docs/archive/play-store-listing.md`, is from the Salapify 1 and 2 era. |

Two lines are still TRUE and do not need to change: the scan sheet's "The
photo is not saved or sent anywhere" (`scan_receipt_sheet.dart:372`), and the
welcome screen's "Everything stays on this phone" if it is read as "your
records" (`welcome_screen.dart:120`). The word "Offline." at the start of that
same welcome line is shakier, and the founder may want it reworded under
option B.

## 1. What Google's documentation says

All three pages were read on 2026-10-10.

- **ML Kit Terms** ([developers.google.com/ml-kit/terms](https://developers.google.com/ml-kit/terms), last updated 2025-05-14).
  Input data is processed fully on the device and ML Kit does not send the
  images, text or results to Google. But: "The ML Kit APIs may contact Google
  servers from time to time in order to receive things like bug fixes,
  updated models and hardware accelerator compatibility information", and
  "The ML Kit APIs also send metrics about the performance and utilization of
  the APIs in your app to Google." The developer "is responsible for informing
  users of your app about Google's processing of ML Kit metrics data as
  required by applicable law."
- **ML Kit Android data disclosure** ([developers.google.com/ml-kit/android-data-disclosure](https://developers.google.com/ml-kit/android-data-disclosure), footer says last updated 2026-07-15).
  For ALL features: device information (manufacturer, model, OS version and
  build, ML accelerators), application information (package name, app
  versions), performance metrics (such as latency), other diagnostics (API
  configuration such as image format and resolution, input and output size,
  feature version, event type, error codes). For BUNDLED features:
  "Per-installation identifiers that are not intended to uniquely identify a
  user or physical device." Purpose: "diagnostics and usage analytics".
  Encrypted in transit with HTTPS, not transferred to third parties. The page
  says the developer is "solely responsible" for the Play Data safety answers.
  It gives NO way to turn the collection off. It does not list the text
  recognition artifacts by name; its "all features" rows apply to them.
- **Text recognition v2 for Android** ([developers.google.com/ml-kit/vision/text-recognition/v2/android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android), last updated 2026-10-07).
  The bundled model is "statically linked to your app at build time" and
  available immediately. That is why no model download happens. It says
  nothing about metrics. The unbundled variant
  (`play-services-mlkit-text-recognition`) downloads its model through Play
  Services, so switching to it would ADD a network contact, not remove one.
- **Play Data safety** ([support.google.com/googleplay/android-developer/answer/10787469](https://support.google.com/googleplay/android-developer/answer/10787469)).
  "Collect" means transmitting data off the device, and that includes data
  sent "by libraries and/or SDKs used in your app". Data sent off the device
  for app functionality is not exempt.

Independent confirmation that this is a known pattern: the tracker database
[trackers.tweasel.org](https://trackers.tweasel.org/t/google/googledatatransport-firelog-batchlog-protobuf/)
lists the GoogleDataTransport firelog endpoints and names ML Kit as a user of
them. An F-Droid reviewer flagged ML Kit with the Tracking anti-feature
([gitlab.com/tans1/tFileTransporter/-/issues/8](https://gitlab.com/tans1/tFileTransporter/-/issues/8)).
The Box app's release notes ([newreleases.io](https://newreleases.io/project/github/jegly/Box/release/3.4.5))
describe switching off the same uploader by removing its one manifest
component. That is the approach tested under option A1 below.

**Can it be turned off with a setting?** No. Google documents no flag, no
manifest meta-data and no API to switch off ML Kit's metrics, and a different
ML Kit text dependency does not avoid it either. The only ways are to remove
the uploader yourself (A1) or not use ML Kit (A2).

## 2. What the build actually contains (static check)

From the Gradle cache on this Mac, no device needed:

- `com.google.mlkit:common` 18.11.0, which text-recognition depends on, pulls
  in `com.google.android.datatransport` transport-api 2.2.1,
  transport-backend-cct 2.3.3 and transport-runtime 2.2.6. That is Google's
  logging transport, also called Clearcut or Firelog.
- transport-backend-cct's own manifest registers the upload backend
  (`CctBackendFactory`) and adds the INTERNET and ACCESS_NETWORK_STATE
  permissions.
- The upload addresses are hidden in `CCTDestination` as two halves
  interleaved by a `StringMerger` class. Decoded:
  `https://firebaselogging.googleapis.com/v0cc/log/batch?format=json_proto3`
  and `https://firebaselogging-pa.googleapis.com/v1/firelog/legacy/batchlog`.
- The installed Salapify 3 APK's merged manifest contains all of it:
  `MlKitInitProvider`, `TransportBackendDiscovery` with the CCT backend,
  `JobInfoSchedulerService`, and ACCESS_NETWORK_STATE. That permission is not
  in our own manifest, so it arrived quietly through the library.

## 3. Verified on an emulator

**Method.** The emulator's own packet capture
(`adb emu network capture` and `-tcpdump`) recorded nothing after boot,
because this emulator version routes Wi-Fi through netsim, which those
captures cannot see. So the proof comes from the phone itself, three ways:
Google's transport logs its own uploads when its log tags are switched to
verbose, the queue it writes before uploading is a database the debug build
lets us read, and the HTTP status Google returned is logged.

I ran this on a separate throwaway AVD with the same APK and a fresh install.
The founder's emulator was in use by another app at the time (see the note at
the end). The AVD was deleted afterwards.

**Results, shipped build:**

1. Launch, then idle: no transport activity and no queue database. Nothing sent.
2. One scan through "Choose an image": the OCR ran locally ("Selected local
   version of com.google.mlkit.dynamite.text.latin", "OCR process succeeded").
   In the same second, five `FIREBASE_ML_SDK` events were queued for
   `firebaselogging.googleapis.com`.
3. 36 seconds later the app's own process logged
   "Making request to: https://firebaselogging.googleapis.com/v0cc/log/batch?format=json_proto3"
   and "Status Code: 200". The remaining low-priority events wait for a
   24-hour job. I forced that job and they went out the same way, also 200.
4. Contents (read from the queue before upload): no image, no recognised
   text, no amounts. Each payload holds the package name, app version, SDK
   version, `en-US`, a random UUID and integer metrics. The transport adds
   country, `mcc_mnc` (carrier), `tz-offset`, locale, manufacturer, model,
   device, hardware, OS build, the full build fingerprint, Android version and
   network type.
5. The UUID is stored in `shared_prefs/com.google.mlkit.internal.xml` as
   `ml_sdk_instance_id`. It lasts until the app is uninstalled or its data is
   cleared, so Google can tell that two scans came from the same install.

On a real phone in the Philippines the country, carrier and time zone fields
would carry that person's real values (for example `515xx` for a Philippine
carrier and UTC+8). Google also sees the phone's IP address, as with any
internet request.

**Results, experimental build (option A1, not committed):** the same scan read
the receipt correctly ("Jollibee", 213.00). Every event was dropped on the
device with "Transport backend 'cct' is not registered", the queue stayed
empty, and in over a minute, with the upload jobs forced, there was not one
request.

**Not verified:**
- The encrypted bytes on the wire. The queue is what the transport batches up
  and sends, and the logged request and 200 response confirm it was sent, but
  I did not decrypt the traffic.
- What Google does with the data after it arrives.
- The "Take a photo" path. It uses the same recognizer object as "Choose an
  image", so I expect the same behaviour, but I did not run it.
- The occasional "updated models and hardware accelerator compatibility"
  contact the terms mention. None was seen during the test.

## 4. The options

### Option A1: switch off Google's uploader (tested, works, NOT recommended)

Add this to `app/android/app/src/main/AndroidManifest.xml`, along with the
`xmlns:tools` namespace on the root element:

```xml
<service
    android:name="com.google.android.datatransport.runtime.backends.TransportBackendDiscovery"
    tools:node="merge">
    <meta-data
        android:name="backend:com.google.android.datatransport.cct.CctBackendFactory"
        tools:node="remove" />
</service>
```

- **Effect:** ML Kit still runs fully on the device. Its reports are written
  to a local queue and thrown away, and they never leave the phone. Every
  current privacy claim becomes true again with no copy change, apart from
  the side findings below.
- **Cost:** a manifest-only change. It is native, so it needs a new APK, not a
  hot update. No Dart code changes.
- **Risk 1, unsupported:** Google does not document this. It depends on
  internal class names, and a future ML Kit update could rename them and
  silently switch the uploader back on. It needs a guard: a check in
  `app-publish.yml` that runs `aapt2 dump xmltree` on the built APK and fails
  if `CctBackendFactory` appears. That guard has to be proven to fail first,
  per CLAUDE.md.
- **Risk 2, terms, and this is the one that decides it:** the ML Kit terms
  say nothing directly, but they incorporate the Google APIs Terms of Service
  ([developers.google.com/terms](https://developers.google.com/terms), last
  modified 2021-11-09). Section 3(a) says Google may monitor use of the APIs
  to "improve Google products and services", and then: "You will not
  interfere with this monitoring." I checked that wording myself. The ML Kit
  metrics exist for exactly that purpose, so removing the uploader on purpose
  is plausibly a breach of contract. Enforcement against an offline bundled
  model is unlikely, but a privacy promise that rests on breaking the vendor's
  terms is a weak foundation.
- **Leftovers that stay on the device:** the per-install UUID is still
  generated locally but never sent. ACCESS_NETWORK_STATE stays merged and can
  be removed the same way if wanted.

### Option A2: stop using ML Kit

Replace the OCR engine with one that has no telemetry (for example a
Tesseract-based plugin), or remove photo reading and keep the paste-the-text
path, which already exists and goes through the same parser.

- Removes the question permanently, with no Google SDK involved.
- This is a large scope expansion. Tesseract is known to read receipts worse
  than ML Kit, adds several MB of language data, and none of this was tested
  here. Removing photo reading takes away a shipped feature, which conflicts
  with "enhance, never regress" in CLAUDE.md.

### Option B: keep the reports and tell the truth

Change no code, and correct the copy and the store answers. Draft wording,
for the founder to edit:

- Privacy sheet, receipt line: "The reading happens on this phone and the
  photo is deleted as soon as Salapify has the words. The photo and the words
  are never sent. The reader is made by Google and sends Google a small usage
  report after each scan: the phone model, app version, country, carrier,
  language and how long the reading took, with a random ID for this install.
  It never includes your receipt or your money."
- Privacy sheet: retitle "No analytics, no crash reporting, no ads" to "No
  ads, no tracking of your money", and change "One thing does leave this
  phone" to "Two things leave this phone", listing exchange rates and the
  receipt reader's usage report.
- `privacy.html`: drop "no analytics" from the short version, change "What
  we collect" from "Nothing" to a two-line disclosure that names Google ML Kit
  and links to Google's data disclosure page, add a "Receipt reading" section,
  and fix the Internet permission line.
- A one-line notice the first time somebody scans, shown before the upload,
  for example: "Scanning uses Google's reader, which sends Google a small
  usage report. Never your photo, your receipt or your money." Counsel
  advises this for the Data Privacy Act (section 6). It is a UI change.
- Play Data safety: declare data collected, with the answer set in section 6.

What B costs is identity rather than effort. "No analytics" is part of what
Salapify is, and B makes the store listing say "data collected" for a
budgeting app whose pitch is that nothing leaves the phone.

### Recommendation

**B now, and decide on A2 as a separate product question.** B is the only
option that is both truthful and within Google's terms today, and it is
copy, store answers and a one-line notice, with no dependency change. If
"nothing leaves this phone" is a promise the founder wants to keep without
any asterisk, that promise needs an OCR engine with no telemetry (A2), which
is its own scoped piece of work with a quality test against real receipts.
A1 works technically but is not recommended, because of the terms clause
above.

Whichever option is chosen, fix the side findings below, because they are
wrong either way.

## 5. Side findings (separate from ML Kit, true under any option)

1. **`privacy.html:50`, "Update delivery".** This section says the app checks
   Shorebird's update service. Salapify 3 has no Shorebird: `app/pubspec.yaml`
   does not depend on it, and `.github/workflows/app-publish.yml` explains it
   publishes a signed APK instead. The policy describes a network contact that
   does not exist. That is the harmless direction to be wrong in, but it is
   still wrong, and the Internet permission line at `privacy.html:41`
   repeats it.
2. **`app/pubspec.yaml:79`** says the app "makes exactly ONE network request".
   That is false because of ML Kit. Under A1 it becomes true again, so the
   comment should name the manifest rule that keeps it true.
3. **ACCESS_NETWORK_STATE** is in the shipped APK through the transport
   library and is not declared in our own manifest. It is not a runtime
   prompt and Play does not ask about it, but the privacy policy's permission
   list does not mention it.

## 6. Counsel note (legal-compliance-counsel)

This is the specialist's view, not legal advice from a lawyer. I checked the
Google APIs Terms quote myself. The rest is counsel's judgement and is marked
as such.

**Play Data safety, if the reports stay (option B):**

| Question | Answer | Why |
| --- | --- | --- |
| Does the app collect or share data? | Yes | It leaves the device, and Play counts SDK traffic. |
| App info and performance > Diagnostics | Collected | Latency, error and config codes, image size, device and build details. |
| Device or other IDs | Collected | `ml_sdk_instance_id`. |
| Approximate location | Do not declare | Country, carrier code and time zone are coarse settings and SIM data, not a position. Describe them in the privacy policy instead. |
| Shared | Yes, to be safe (counsel's judgement) | The service provider exemption covers processing "on behalf of the developer", and Google uses these metrics for its own purposes ("improve the APIs", "detect misuse"). Over-declaring is not penalised; under-declaring is a violation. Note that Google's own disclosure page says ML Kit does not transfer the data to third parties, so a "Not shared" answer is arguable. Counsel chose the safe side. |
| Purpose | Analytics | Not app functionality: the A1 test showed the OCR works without the uploads. |
| Optional or required | Required | Play treats data as optional only if the user can opt out of the collection itself. Choosing to scan does not count. |
| Encrypted in transit | Yes | HTTPS, per Google and as observed. |
| Users can request deletion | No | Salapify holds nothing, there are no accounts, and uninstalling resets the ID. |

**Philippine Data Privacy Act (counsel's view):** together, the per-install
ID, device model, carrier code and IP address can identify a person, so
treat them as personal information. By choosing the SDK, Salapify is the
personal information controller and stays accountable for the transfer to
Google. Consent is not mandatory for non-sensitive data, but legitimate
interest needs a written assessment and accurate transparency, and that basis
is weak when the data serves Google's purposes rather than the feature. So
the defensible setup is two layers: a full disclosure in the privacy policy
plus a one-line notice at the first scan, before any upload. Sources counsel
cited: NPC legitimate interest guidelines (Circular 2023-07, consultation
draft), consent guidelines (Circular 2023-04), and the Play and Google pages
above.

**On option A1 (counsel's view, quote verified):** Google APIs ToS §3(a), "You
will not interfere with this monitoring", plus §4(a)(4), which bars
interfering with "the APIs or the servers or networks providing the APIs". No
Play policy requires SDK telemetry. The real Play risk runs the other way:
shipping the telemetry while the listing says no data is collected.

## A note on the founder's emulator

I opened Salapify once on the founder's running Pixel_8 emulator and pressed
nothing until the screenshot showed another app (`com.aurivan.app`) had come
to the front. One tap I had sent then landed on that app's Settings, on the
"10 a day" daily goal chip. If that goal was something else before, it is now
10. I also stopped a log-tailing process that another session had attached to
that emulator. After that I moved all testing to a separate AVD. On the
founder's emulator I removed the test image I had pushed and reset the log
settings I had changed.
