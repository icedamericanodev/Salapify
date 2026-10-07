// How the expansion paths and courses are PRESENTED, kept entirely separate
// from how they are STORED.
//
// Phase 6B Batch C1B re-shelved the expansion library (Protect first, then
// Grow, then Business under Advanced; and inside Grow, the technical courses
// tucked behind a "Go deeper" section). Every one of those decisions is about
// display order and labels, never about identity: pathId, groupId, lessonId,
// and the settings.expansionProgress[pathId][lessonId] keys are untouched, so
// a learner's completion and percentage cannot move when a course changes
// which header it sits under. This file is the one place that presentation
// metadata lives, so the regrouping is data a screen reads, not a rewrite of
// the content.
//
// Nothing here gates opening anything. The categories order and label the
// catalog; the readers still return every lesson regardless.

/// The display order of the three published paths, most-relevant-to-everyday
/// life first. Protect leads because everyone with a payslip already pays SSS,
/// PhilHealth and Pag-IBIG; Grow is mainstream money growth; Business is
/// advanced and optional, so it sits last and never competes with the two
/// paths a typical working adult needs.
const List<String> expansionPathDisplayOrder = [
  'protect_your_future',
  'grow_your_money',
  'build_your_business',
];

/// Sort rank for a path id, for [expansionPathDisplayOrder]. An unknown id
/// sorts last rather than crashing, the same fails-safe convention the rest of
/// the expansion code follows.
int expansionPathRank(String pathId) {
  final i = expansionPathDisplayOrder.indexOf(pathId);
  return i < 0 ? expansionPathDisplayOrder.length : i;
}

/// A path shown under the "Advanced" tier: useful, but not part of the
/// everyday financial-literacy journey. Only Business is advanced as a whole
/// path; Grow is mainstream with a couple of advanced courses inside it (see
/// [advancedGrowGroupIds]), and Protect is squarely everyday.
bool isAdvancedPath(String pathId) => pathId == 'build_your_business';

/// The two courses inside Grow that sit behind a "Go deeper" disclosure rather
/// than beside the mainstream three. Government securities is advanced for its
/// technical complexity; crypto is advanced and optional and higher risk. Both
/// are kept INSIDE Grow (never moved to a separate top-level category), which
/// is the whole point of the disclosure: the hierarchy carries the difficulty,
/// no new bucket does.
const Set<String> advancedGrowGroupIds = {
  'ph_government_securities',
  'crypto_without_hype',
};

/// True when a Grow course belongs under the "Go deeper" section.
bool isAdvancedGrowGroup(String groupId) =>
    advancedGrowGroupIds.contains(groupId);

/// The one-line note shown beside an advanced Grow course, deliberately
/// DIFFERENT per course so the UI never implies the two share a risk profile.
/// Government securities is advanced because it is technical, not because it
/// is dangerous; crypto is advanced because it is optional and can lose value.
/// Neutral wording, no fear copy, per the C1B brief.
String? advancedGrowNote(String groupId) => switch (groupId) {
  'ph_government_securities' => 'More technical. Not higher risk.',
  'crypto_without_hype' => 'Optional. Higher risk, can lose value.',
  _ => null,
};
