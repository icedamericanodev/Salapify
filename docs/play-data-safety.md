# Play data safety answers, Salapify 3

DRAFT, 2026-10-10. Nothing is submitted. The founder enters these in Play
Console when the store listing is set up. They must match `privacy.html`, so
when one changes, change the other in the same pull request.

Basis: `docs/reviews/mlkit-telemetry.md` (what leaves the phone, verified on an
emulator), and the legal-compliance-counsel answer recorded there. The
founder chose option B on 2026-10-10: keep Google's receipt reader and declare
its usage report. This file replaces nothing for Salapify 3. The older
`docs/archive/play-store-listing.md` belongs to Salapify 1 and 2.

## What actually leaves the phone

| Trigger | Goes to | What is sent |
| --- | --- | --- |
| Opening the currency converter | open.er-api.com | A currency code, for example PHP, plus the IP address any request reveals. |
| Scanning a receipt (photo or image) | Google, firebaselogging.googleapis.com | ML Kit usage report: device manufacturer, model, Android version and build, app package and version, ML Kit version, country, carrier code, time zone, language, network type, latency, image size, error codes, and a per-install random ID. Never the image, the text or any amount. |

Nothing else. No request at launch, none from Pan, none from backup,
export, reminders or app lock. Backups and exports go only where the person
sends them, which Play does not count as collection, because the person moves
the file themselves.

## The answers

**Does your app collect or share any of the required user data types?** Yes.

**Is all of the user data collected by your app encrypted in transit?** Yes.
Both requests use HTTPS, and the manifest sets `usesCleartextTraffic="false"`.

**Do you provide a way for users to request that their data is deleted?** No.
Salapify holds nothing and has no accounts. Uninstalling removes everything on
the phone and resets the ML Kit install ID.

### Data types

| Data type | Collected | Shared | Processed ephemerally | Required or optional | Purpose |
| --- | --- | --- | --- | --- | --- |
| App info and performance > Diagnostics | Yes | Yes | No | Required | Analytics |
| Device or other IDs | Yes | Yes | No | Required | Analytics |

Every other data type: not collected. In particular:

- **Approximate location: do not declare.** Country, carrier code and time
  zone are settings and SIM data, not a position fix. Play defines
  approximate location as a position to within about 3 square kilometres.
  They are named in the privacy policy instead.
- **Photos: not collected.** The receipt photo is read on the phone and
  deleted. It never leaves.
- **Financial info: not collected.** Nothing the person types leaves the phone.

### Why these choices (counsel's judgement where marked)

- **Shared = Yes (counsel's judgement).** Play waives "sharing" for a service
  provider that processes data on the developer's behalf and on the
  developer's instructions. Google uses ML Kit metrics to improve its own
  APIs and detect misuse, which is its own purpose. Over-declaring carries no
  penalty and under-declaring is a policy violation. Google's own disclosure
  page says ML Kit does not transfer the data to third parties, so "No" is
  arguable. The safe side was chosen.
- **Purpose = Analytics, not App functionality.** The reading works without
  the report. That was proven on 2026-10-10 by a build with the uploader
  removed, which still read the receipt.
- **Required, not optional.** Play counts data as optional only when the
  person can refuse the collection itself. Choosing to scan is not that.
  The paste path avoids it, but that is avoiding the feature, not opting out.
- **The exchange rate request is not declared as a data type.** A currency
  code is a setting, not user data in any Play category, and the developer
  does not collect the IP address the rate service sees. **Confirm this with
  legal-compliance-counsel before submitting.** It is the one answer here
  that was reasoned rather than checked.

## When this must be redone

- Any change to `google_mlkit_text_recognition` or anything else under
  `com.google.mlkit` or `com.google.android.datatransport`. Google's
  disclosure page covers only the latest SDK versions.
- Any new package that opens a network connection.
- Any change to `privacy.html`.
