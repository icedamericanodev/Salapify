# Salapify

Salapify is an offline first budget, debt, and utang tracker for Filipino Gen Z,
millennials, and working adults. It runs entirely on your phone: no account, no
server, and your money data never leaves the device unless you export or share a
backup yourself.

This directory is the Flutter rebuild. The shipping React Native app lives in
`../mobile` and stays the tester build until this app reaches parity.

## Privacy in one line

No account, no cloud sync, no analytics, no trackers, no ads. The in-app Privacy
receipt lists every network connection the app can make, there are two (currency
rates and app-code updates, neither carrying your money data), lists every
Android permission and why it exists, and invites you to verify the whole thing
in airplane mode. On-device your data is protected too: Android cloud and
device-to-device backup are turned off for this app, the screen is marked secure
when App lock is on, and lock-screen reminders stay generic unless you opt into
detailed ones.

## Development

The working rules live in `../CLAUDE.md`. In short:

- Money math is ported from the RN app with the same test vectors, matching to
  the centavo.
- Every screen is rendered to an image and actually looked at before it ships.
- `flutter analyze` must be clean and `flutter test` green before any merge.
- Delivery is over the air via Shorebird; a base APK is rebuilt only for
  native-level changes.

The local Flutter SDK a session uses is `3.44.6` stable.
