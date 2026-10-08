# App lock: review note (2026-10-08)

Phase 3's last screen item. Founder decisions taken before building: open
Salapify with the **phone's own lock**, and **keep the setting out of
backups**. Pictures: [app-lock/README.md](app-lock/README.md).

## Scope

- Turning app lock on or off in Settings, Privacy. Either way needs the
  phone's lock first.
- A lock screen drawn over the app:
  - on a cold start;
  - again after a minute away;
  - as a cover the moment the app leaves the screen.
- While app lock is on:
  - Salapify is blanked in screenshots and recent apps (FLAG_SECURE);
  - reminders on the phone's lock screen carry no figure and no name.
- Delete everything turns app lock off, and also removes the copies that
  exports left in the cache.

## What did NOT change

- **Money:** nothing. No value, sign, rounding, calculation or
  classification moved.
- **The ledger file:** unchanged. The lock setting is a separate file,
  `app_lock.json`, beside the ledger and never inside it, so no export
  carries it.
- **Encryption:** none. Settings says so plainly: app lock stops somebody
  opening Salapify on this phone, and it does not encrypt the data or the
  backups.

## Second pass: the security and recovery reviews

Two specialist reviews ran on the first build, security-privacy-auditor and
recovery-designer. Every item below was checked against the code before it
was fixed.

| Finding | Fix | Guard, proven by breaking it |
|---|---|---|
| Reminders showed amounts and names on the lock screen. Android's "private" setting hides them only when the person has turned off "show sensitive content", and that is on by default. | The words change too: "A reminder is due. Open Salapify to see it." | `notification_privacy_test`: "an amount was shown on a locked phone" |
| A sleeping phone stops the stopwatch, so an hour away counted as seconds. | The time away is the longer of the stopwatch and the wall clock. Moving the clock back still cannot shorten it. | "sleep shortened the time away" |
| A plugged-in keyboard could Tab into buttons under the lock screen. | `ExcludeFocus` as well as `ExcludeSemantics`. | the focus test, found 0 when removed |
| Back on the lock screen closed the sheet hidden underneath it. | Back and the predictive back gesture are swallowed while locked. | "Back closed the sheet hidden under the lock screen" |
| A phone whose prompt keeps erroring had no second way in. | After two errors, "Use your phone's PIN instead" opens the phone's own PIN screen. A prompt that hangs gives up after two minutes. | `lock-phone-code` absent when the offer is disabled |
| The error copy did not warn against uninstalling, which deletes everything. | It does now. | in the same test |
| A save that failed still showed app lock as on. | The setting is saved first and reported only after it is written. Writes go to a temporary file, then a rename. | "contains 'could not be saved'", got null |
| Delete everything left export copies in the cache. | They are swept: Salapify's own backup files, CSVs, and the `share_plus` copies. Nothing else is touched, and only on the phone, never a computer's `/tmp`. | `export_copies_test`: 5 removed where 4 were ours |
| The lock-turned-itself-off note could expire under an open sheet. | It is now a screen that stays up until "Open Salapify" is tapped. | the way-out test taps it |

Also fixed: the privacy policy (`privacy.html`) listed only fingerprint or
face. It now says fingerprint, face, PIN, pattern or password, and that the
setting is not part of any export.

## Validation

- `flutter analyze` on the 3.47.4 pin: clean.
- The full suite: see the commit message.
- New tests:
  - `app_lock_test`: 12 tests;
  - `notification_privacy_test`: 2 tests;
  - `export_copies_test`: 2 tests.
- Renders: dark first, then light. The two failure states are dark only.

## Native change

`MainActivity` is a `FlutterFragmentActivity` and has two channel methods:
`setSecure`, and `confirmDeviceCredential`, which opens the phone's own PIN
screen. The launch themes are AppCompat. This needs a full rebuild, not a
hot restart. The Android build on CI is what compiles the Kotlin.

## Waiting on the founder (not built)

1. **Moving to a new phone.** The privacy sheet says that setting up a new
   phone by copying from this one brings Salapify across. It does not.
   - `data_extraction_rules.xml` includes the `file` domain.
   - The ledger lives in Flutter's documents folder, `app_flutter/`, which
     is outside that domain.
   - So the sentence is false today.
   - Two ways out, and both touch privacy and stored data:
     - include `app_flutter/` in device transfer, excluding
       `app_lock.json` (recommended);
     - or correct the sentence.
2. **Delete everything behind the phone's lock.** When app lock is on,
   should Delete everything ask for the phone's lock first?
   - It is the one action that cannot be undone.
   - Somebody holding an unlocked phone would otherwise reach it.

## Deferred

- Advising someone to remove their phone's screen lock, as a last resort
  when nothing else works. This needs the founder's word: it is advice to
  weaken their phone's security.
