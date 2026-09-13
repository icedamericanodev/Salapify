// The type ladder. Every piece of text in the app comes from here.
//
// The sizes are NOT new. Every one is lifted from the 24 renders the founder
// approved on 2026-09-13, so naming them moves no pixels. What naming buys is
// the rule underneath: test/design/type_discipline_test.dart forbids a raw
// TextStyle anywhere outside lib/design, and that rule is unenforceable while
// the design folder itself hands out arbitrary numbers. A ladder you can name
// is a ladder you can check.
//
// Roles, not sizes. A screen asks for `TypeScale.rowTitle`, never for "15 point
// medium", so the day a row title changes it changes in one place.
import 'package:flutter/material.dart';

/// The one type helper. Tabular figures always, so a column of amounts never
/// jiggles as the digits change: in a proportional face a 1 is narrower than a
/// 7, and a list of pesos visibly shivers as it updates.
TextStyle ts(double size, FontWeight w, Color c, {double? h, double? ls}) =>
    TextStyle(
      fontFamily: 'Jakarta',
      fontSize: size,
      fontWeight: w,
      color: c,
      height: h,
      letterSpacing: ls,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

/// The ladder.
///
/// Not `Type`, because that is a real class in dart:core. The preview called
/// it `Type_`, and the kit called its row and chip `Row_` and `Chip_` for the
/// same reason, all three colliding with something Flutter or Dart already
/// owns. Analyze rejects the underscore, correctly, so they are named properly
/// here: `TypeScale`, `ItemRow`, `PickChip`. Nothing about them changed but
/// the name.
abstract final class TypeScale {
  /// The one big number on Home. Tightened hard, because a 47 point figure at
  /// default tracking reads as a logo rather than a total.
  static TextStyle hero(Color c) => ts(47, FontWeight.w700, c, ls: -1.6);

  /// The name of a screen.
  static TextStyle screenTitle(Color c) => ts(27, FontWeight.w700, c, ls: -0.8);

  /// The name of a sheet that slid up over one.
  static TextStyle sheetTitle(Color c) => ts(22, FontWeight.w700, c, ls: -0.5);

  /// A section heading inside a screen.
  static TextStyle sectionHead(Color c) => ts(16, FontWeight.w600, c, ls: -0.2);

  /// What the person is typing. One step up from body, because it is the only
  /// text on the screen they are actually looking at.
  static TextStyle input(Color c) => ts(16, FontWeight.w500, c);

  /// The peso figure at the right end of a row. Slightly larger and heavier
  /// than the label beside it, which is what makes a list scannable by amount.
  static TextStyle rowAmount(Color c) => ts(15.5, FontWeight.w600, c, ls: -0.3);

  /// The label at the left end of a row.
  static TextStyle rowTitle(Color c) => ts(15, FontWeight.w500, c);

  /// The label on the one primary button.
  static TextStyle button(Color c) => ts(15, FontWeight.w600, c);

  /// The Log pill in the tab bar. Half a point up from [button] because it
  /// sits on the accent and small text on a saturated fill reads lighter.
  static TextStyle navPill(Color c) => ts(14.5, FontWeight.w600, c);

  /// A date line, a Cancel. Present, not shouting.
  static TextStyle quiet(Color c) => ts(14, FontWeight.w500, c);

  /// The sentence under a screen title.
  static TextStyle subtitle(Color c) => ts(14, FontWeight.w400, c);

  /// A chip or a segment at rest.
  static TextStyle control(Color c) => ts(13.5, FontWeight.w500, c);

  /// A chip or a segment that is on. Weight carries the state, so the control
  /// does not have to change size and shove its neighbours.
  static TextStyle controlOn(Color c) => ts(13.5, FontWeight.w600, c);

  /// The tappable word at the end of a section heading.
  static TextStyle action(Color c) => ts(13, FontWeight.w500, c);

  /// The app explaining itself in a small voice.
  static TextStyle hint(Color c) => ts(13, FontWeight.w400, c);

  /// The part of that explanation that is the answer.
  static TextStyle hintStrong(Color c) => ts(13, FontWeight.w600, c);

  /// The word above a group of inputs.
  static TextStyle fieldLabel(Color c) => ts(12.5, FontWeight.w500, c);

  /// The second line under a row label.
  static TextStyle caption(Color c) => ts(12.5, FontWeight.w400, c);

  /// The second line under a row amount. The smallest thing that is still a
  /// sentence.
  static TextStyle captionSm(Color c) => ts(12, FontWeight.w400, c);

  /// A tab bar label. The smallest type in the app, and the only place this
  /// size is allowed, because a tab label is read once and then recognised by
  /// its icon.
  static TextStyle tab(Color c) => ts(10.5, FontWeight.w500, c);
}
