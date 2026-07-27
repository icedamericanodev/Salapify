// One place that decides what Salapify's own icons look like.
//
// The app used to draw its chrome with emoji: a lifebuoy on the emergency
// fund lesson, a mountain on the debt track, a party popper on a win. Emoji
// are multicolour stickers drawn by the operating system, so a red lifebuoy
// and a blue wave sat inside an orange-on-dark screen looking like they came
// from a different app, and they changed shape between Android versions and
// between phones. Nothing in the palette could reach them.
//
// So content now names the MEANING ('shield', 'mountain', 'gift') and this
// file decides how that meaning is drawn. Restyling every icon in the app is
// one edit here, not a hunt through 26 content entries and a dozen screens.
//
// IMPORTANT, and the line that decides whether something belongs here: this
// covers icons SALAPIFY authors. It does NOT cover emoji the USER picked, and
// it must never be extended to them. Category icons, treat icons, account
// icons, and goal icons are user data: they live in the backup file, the user
// chose them, and replacing them with our icons would overwrite a choice that
// was never ours to make. Those stay emoji on purpose.

import 'package:flutter/material.dart';

import '../theme.dart';

/// Meaning to glyph. Names are what the thing IS, never what it looks like,
/// so a later restyle cannot make a name a lie.
const Map<String, IconData> _icons = {
  // Course tracks
  'cushion': Icons.shield_outlined,
  'mountain': Icons.terrain_outlined,
  'waves': Icons.waves_outlined,
  'gift': Icons.card_giftcard_outlined,

  // Lessons
  'spotlight': Icons.flashlight_on_outlined,
  'mind': Icons.psychology_outlined,
  'essentials': Icons.rice_bowl_outlined,
  'savings': Icons.savings_outlined,
  'health': Icons.medical_services_outlined,
  'card': Icons.credit_card_outlined,
  'cart': Icons.shopping_cart_outlined,
  'balance': Icons.balance_outlined,
  'inspect': Icons.travel_explore_outlined,
  'handshake': Icons.handshake_outlined,
  'calendar': Icons.calendar_month_outlined,
  'work': Icons.work_outline,
  'receipt': Icons.receipt_long_outlined,
  'foundation': Icons.foundation_outlined,
  'target': Icons.my_location_outlined,
  'cash': Icons.payments_outlined,
  'growth': Icons.trending_up_outlined,
  'repeat': Icons.autorenew_outlined,

  // Empty states and moments
  'search': Icons.search_outlined,
  'chart': Icons.bar_chart_outlined,
  'celebrate': Icons.celebration_outlined,

  // Navigation destinations. Added when Menu became a tile grid, where the
  // icon does more work than it does in a row: with the explanatory blurbs
  // gone, the glyph and the label are the only things telling you where a
  // tile goes.
  'wallet': Icons.account_balance_wallet_outlined,
  'flow': Icons.waterfall_chart_outlined,
  'group': Icons.groups_outlined,
  'tools': Icons.handyman_outlined,
  'share': Icons.ios_share_outlined,
  'phone': Icons.phone_iphone_outlined,

  // The bottom bar. These were raw Icons.* constants sitting in main.dart,
  // which is the one place in the app that never went through this file, on
  // the one row of icons every user sees on every screen.
  //
  // Some of these glyphs are already in the map above under a different name:
  // 'handshake' and 'utang' are both the handshake, 'savings' and 'budget' are
  // both the piggy bank. That is not a mistake to clean up. Names here are
  // MEANINGS, and two meanings are allowed to share a picture; collapsing them
  // would mean the Utang tab and a lesson about lending had to keep the same
  // glyph forever, which is exactly the coupling this file exists to prevent.
  'home': Icons.home_outlined,
  'budget': Icons.savings_outlined,
  'activity': Icons.receipt_long_outlined,
  'utang': Icons.handshake_outlined,
  'insights': Icons.insights_outlined,
  'menu': Icons.grid_view_outlined,
};

/// The filled twin of a destination icon, for the selected tab.
///
/// A separate map rather than a naming convention like 'home-filled', because
/// only the bottom bar has a selected state and inventing a suffix would imply
/// every icon has one. A name with no filled twin falls back to its outlined
/// form, which is the honest answer for the other thirty.
const Map<String, IconData> _filled = {
  'home': Icons.home,
  'budget': Icons.savings,
  'activity': Icons.receipt_long,
  'utang': Icons.handshake,
  'insights': Icons.insights,
  'menu': Icons.grid_view,
};

/// The glyph for a name. An unknown name draws a neutral marker rather than
/// throwing or drawing nothing: a missing icon must never take a screen down,
/// and a blank space would hide the mistake instead of showing it.
IconData salapifyIcon(String name) =>
    _icons[name] ?? Icons.label_important_outline;

/// The glyph for a name in its selected state, for a navigation destination.
///
/// Falls back to the outlined form rather than to the neutral marker, so a name
/// with no filled twin simply does not change when selected. That is a
/// deliberate difference from [salapifyIcon]: an unknown NAME is a typo worth
/// showing, but a missing filled variant is a normal, correct state.
IconData salapifyIconSelected(String name) => _filled[name] ?? salapifyIcon(name);

/// A Salapify icon, in the theme's accent, optionally inside a soft tinted
/// disc. The disc is what makes a row of these read as one family: it gives
/// every icon the same silhouette no matter how wide or tall the glyph is,
/// which is exactly what a set of emoji could never do.
class SalapifyGlyph extends StatelessWidget {
  final String name;
  final double size;

  /// Draw the tinted disc behind the glyph. Off for inline use inside a line
  /// of text, where a disc would look like a button.
  final bool boxed;

  /// Override the accent. Defaults to the theme's primary, which is the whole
  /// point: these follow the palette, and the old emoji could not.
  final Color? color;

  // NOT const on purpose. Every colour below is a mutable Barako getter
  // read in build(). Dart canonicalizes const instances, so a const call
  // site makes two builds compare equal and Element.updateChild skips
  // build() entirely, freezing this widget in the previous palette after
  // a theme switch or a night-mode flip. Removing const from the
  // CONSTRUCTOR is what makes the mistake impossible at every call site,
  // rather than something each caller has to remember.
  // ignore: prefer_const_constructors_in_immutables
  SalapifyGlyph(
    this.name, {
    super.key,
    this.size = 24,
    this.boxed = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Barako.primary;
    final icon = Icon(
      salapifyIcon(name),
      size: size,
      color: tint,
      // The name is the meaning, so it is also the accessible label. Without
      // this a screen reader announces nothing at all here, and the emoji it
      // replaced at least had a spoken name.
      semanticLabel: name,
    );
    if (!boxed) return icon;
    final pad = size * 0.5;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        // Low-opacity accent rather than a card colour, so the disc sits on
        // any surface (card, sheet, or page) without drawing a hard edge.
        color: tint.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: icon,
    );
  }
}
