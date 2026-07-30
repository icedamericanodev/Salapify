// What kind of build is this, decided at compile time.
//
// One file, one constant, so "remove that before we launch" stops being a
// sentence somebody has to remember on the busiest day of the project.
//
// The founder asked for sample data to poke at while they were at work, and in
// the same breath asked for it to be gone before the app reaches the store. Both
// are right, and the gap between them is months. A note in a chat log would not
// survive that gap; a launch checklist would survive it and still rely on
// somebody reading the checklist. A compile-time flag survives it without
// anybody doing anything, because the Play build simply does not contain the
// code.

/// True for the founder's over-the-air preview, false for a store build.
///
/// Defaults to TRUE deliberately, and that direction is a judgement worth
/// stating. Defaulting to false would mean a forgotten `--dart-define` silently
/// STRIPS a feature from the preview, which reads to the founder as the app
/// losing something and takes a round to diagnose. Defaulting to true means a
/// forgotten flag ships a preview-only feature to the store, which is caught by
/// `test/preview_only_test.dart` and by the launch audit, both of which run
/// before a store build exists.
///
/// Set it at build time:
///
///     flutter build appbundle --dart-define=SALAPIFY_PREVIEW=false
///
/// Nothing needs editing at launch, which is the entire point: an edit is a
/// thing that can be forgotten, and a build command is a thing that is written
/// down once in the release workflow.
const bool kPreviewBuild = bool.fromEnvironment(
  'SALAPIFY_PREVIEW',
  defaultValue: true,
);

/// Features that exist only for testing the app, and must never reach a user
/// who paid attention to the store listing.
///
/// Separate from [kPreviewBuild] rather than an alias for it, because they will
/// diverge: a preview build is also where a half-finished real feature lives,
/// and that is a different question from "this is scaffolding". Anything behind
/// this name is a thing the founder wants for testing and nobody else should
/// ever see.
const bool kTestingAids = kPreviewBuild;
