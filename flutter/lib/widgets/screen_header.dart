// The one header every tab uses, so the screens read as one app: a big Jakarta
// wordmark title, an optional muted subtitle, an optional trailing action, and
// fixed spacing above and below. Home keeps its own branded wordmark plus
// search; this is for the other tabs. Titles stay Jakarta (Fraunces is reserved
// for peso amounts).

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

/// The named header faces, so a screen picks a TIER and never a size.
///
/// [tab] is the per-tab title this widget renders. [cover] is the big opener
/// a content screen composes itself (a lesson's title page); it lives here so
/// the face has ONE definition on the ladder. Before this enum, the Learn
/// cover set its own 27, one off-ladder point under [TypeScale.big], purely
/// because no name existed for what it was trying to be.
enum HeaderTier { tab, cover }

TextStyle headerStyle(HeaderTier tier) => switch (tier) {
  HeaderTier.tab => AppText.title,
  HeaderTier.cover => AppText.title.w7.copyWith(
    fontSize: TypeScale.big,
    height: 1.1,
  ),
};

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Opens the Menu. Present on every primary destination, because Menu left
  /// the bottom bar and this is now the only way in.
  final VoidCallback? onMenu;

  /// The gap above the title. Defaults to 12; the whole header carries a fixed
  /// 20 gap below so content starts at the same place on every tab.
  final double topGap;

  // NOT const on purpose: the header reads mutable Barako palette getters in
  // build(), so a const call site would be canonicalized and freeze its colors
  // on a theme or light/dark switch. A non-const constructor makes that
  // mistake impossible. The analyzer wants const on an all-final widget, but
  // that is exactly the footgun we are avoiding, so we opt out here.
  // ignore: prefer_const_constructors_in_immutables
  ScreenHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.onMenu,
    this.topGap = 12,
  });

  @override
  Widget build(BuildContext context) {
    // Sentence case at 22/w800/0, matching this app's OWN AppBar titles.
    //
    // The old 26/w800/ls3 uppercase was the outlier, not the standard: 28
    // pushed screens already set a sentence-case AppBar title, and all six
    // bottom tab labels are sentence case too. So "Budget" sat in the nav bar
    // while "BUDGET" sat 40dp above it, in two different cases, on the same
    // screen. That is the busy feeling, and it was self inflicted.
    //
    // It also leaves exactly ONE uppercase treatment in the app, the 12px
    // kicker. Two all-caps sizes competing is solved by deleting one of them,
    // not by tuning both.
    final titleText = Text(title, style: headerStyle(HeaderTier.tab));
    // One Row whenever there is anything beside the title, rather than a
    // trailing-only special case. Menu now sits here on every primary screen,
    // and Utang carries a create button as well, so "title alone" stopped
    // being the common shape.
    //
    // Expanded on the title, never on the actions, and no Spacer. The first
    // version used Flexible plus Spacer, which is TWO flex children: the row
    // split its free space between them, and on a short title ("Budget") the
    // title's unused share became dead space at the END of the row, parking
    // the Menu key 19dp off the content edge on some tabs and flush on
    // others. A single tight Expanded title owns all the free space, so the
    // actions land on the edge on every tab. When the text is long or the
    // system font is large, the TITLE is still the thing that wraps; letting
    // an action shrink instead would give a user a button too small to hit at
    // exactly the font size they chose because things were hard to see.
    final hasActions = trailing != null || onMenu != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: topGap),
        if (hasActions)
          Row(
            children: [
              Expanded(child: titleText),
              ?trailing,
              if (trailing != null && onMenu != null)
                const SizedBox(width: Gap.sm),
              if (onMenu != null) MenuAction(onTap: onMenu!),
            ],
          )
        else
          titleText,
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppText.small.tint(Barako.muted)),
        ],
        // Gap.md, not 20: the title shrank from 26 to 22, so it needs less
        // air under it to keep the same optical relationship.
        const SizedBox(height: Gap.md),
      ],
    );
  }
}

/// A header action drawn as a raised key: a 48 square on Barako.surfaceRaised
/// with a hairline Barako.border edge, the same physical language as the
/// app's cards.
///
/// The container is the point, not decoration. As a bare glyph this control
/// floated in empty space and read as ink, not as a button, and the founder
/// called it out; beside the orange New pill on Utang it disappeared
/// entirely. The edge and the surface are what "pressable" already means in
/// this app, so the fix borrows that instead of borrowing orange. Neutral ink
/// on a raised neutral surface keeps the action color (Log, New) as the only
/// orange in the row: same height as the pill says peer control, different
/// fill says different job.
///
/// The border is load bearing, not optional: in the palest light palettes
/// surfaceRaised sits on a near white background and the 1dp edge is the only
/// thing that makes the button exist, exactly like every card there.
///
/// The visual square IS the tap target, 48, the Android floor. The tooltip is
/// not decoration either: it is the only text a screen reader has to work
/// with, and labeledTapTargetGuideline fails without it.
class HeaderAction extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onTap;

  // ignore: prefer_const_constructors_in_immutables
  HeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    // 22, the size the bottom bar icons use, so chrome icons stay one
    // size app wide.
    icon: Icon(salapifyIcon(icon), size: 22, color: Barako.text),
    style: IconButton.styleFrom(
      backgroundColor: Barako.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: Barako.border),
      ),
      // fixedSize pins the drawn square to the tap target, so the shape
      // users see is exactly the thing they can hit.
      fixedSize: const Size(48, 48),
      minimumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
    ),
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
  );
}

/// The way into Menu, in one place.
///
/// A named wrapper rather than five call sites spelling HeaderAction out, so
/// the icon, the tooltip and the tap target cannot drift apart across the
/// five screens that carry it. The tooltip doubles as the seam the test
/// suite navigates through (find.byTooltip in app_harness.dart).
class MenuAction extends StatelessWidget {
  final VoidCallback onTap;

  // ignore: prefer_const_constructors_in_immutables
  MenuAction({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      HeaderAction(icon: 'menu', tooltip: 'Menu', onTap: onTap);
}
