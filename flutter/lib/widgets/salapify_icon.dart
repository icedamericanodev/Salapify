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
  'calendarDay': Icons.calendar_today_outlined,
  'work': Icons.work_outline,
  'receipt': Icons.receipt_long_outlined,
  'foundation': Icons.foundation_outlined,
  'target': Icons.my_location_outlined,
  'cash': Icons.payments_outlined,
  'growth': Icons.trending_up_outlined,
  // The mirror of 'growth', for money going the other way. Added for the
  // Loans category in the add-account flow; the content test is what stops a
  // name like this being used before it exists and reaching the fallback.
  'decline': Icons.trending_down_outlined,
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
  'categories': Icons.sell_outlined,
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

  // Affordances: the small chrome every screen shares. These existed as two
  // hundred raw Icons.* constants across fifty files; now the meaning lives
  // here and a screen says what it wants, not which glyph draws it.
  'forward': Icons.chevron_right,
  // 'previous' is forward's mirror for steppers; 'back' is the app-bar
  // arrow. Different meanings, deliberately different pictures.
  'previous': Icons.chevron_left,
  'back': Icons.arrow_back,
  'up': Icons.arrow_upward,
  'expand': Icons.expand_more,
  'collapse': Icons.expand_less,
  'add': Icons.add,
  'subtract': Icons.remove,
  'close': Icons.close,
  'check': Icons.check,
  // The theme tile's picked badge. Distinct from 'check' on purpose: the
  // appearance screen shows both at once, and a test proves exactly one
  // picked badge exists, which two meanings sharing one picture would break.
  'chosen': Icons.check_rounded,
  'refresh': Icons.refresh,
  'startOver': Icons.restart_alt,
  'swap': Icons.swap_vert,
  'split': Icons.call_split,
  'copy': Icons.copy,
  'download': Icons.download,
  'import': Icons.upload_file,
  'install': Icons.system_update_alt,
  'edit': Icons.edit_outlined,
  'editDate': Icons.edit_calendar_outlined,
  'save': Icons.save_outlined,
  'delete': Icons.delete_outline,
  'deleteForever': Icons.delete_forever_outlined,
  'moveUp': Icons.arrow_upward,
  'moveDown': Icons.arrow_downward,

  // Selection and state. ONE canonical pair on purpose: the app had grown
  // four different "checked" glyphs (check, check_rounded, check_circle,
  // check_box) and three different "unchecked" ones for the same meaning,
  // which is exactly the drift a meaning map exists to stop. The selected
  // form is FILLED, the resting form is outlined; that asymmetry is the
  // house rule for active states, same as the bottom bar.
  'selected': Icons.check_circle,
  'unselected': Icons.circle_outlined,
  // Multi-select boxes, distinct from the choose-one circles above: a
  // check-all list drawn with radio circles tells the user to pick one.
  'checked': Icons.check_box,
  'unchecked': Icons.check_box_outline_blank,
  // A finished STEP in a list (outlined, calm), distinct from 'selected'
  // (filled, active): a done lesson is not a chosen option.
  'done': Icons.check_circle_outline,
  'cut': Icons.content_cut,
  // The display fallback for a treat whose emoji field is empty. The emoji
  // a user typed stays theirs; this is only what WE draw when there is none.
  'treat': Icons.local_cafe_outlined,
  'paused': Icons.pause_circle_outline,
  // A paused decision sitting in the Money Mindset Waiting list, counting
  // down to its Do you still want this? check-in.
  'waiting': Icons.hourglass_top_outlined,
  'play': Icons.play_circle_outline,
  'locked': Icons.lock_outline,
  'unlocked': Icons.lock_open_outlined,
  'autoLock': Icons.lock_clock_outlined,
  'blocked': Icons.block,
  'error': Icons.error_outline,
  'warning': Icons.warning_amber_rounded,
  'help': Icons.help_outline,
  'hidden': Icons.visibility_off,
  'protected': Icons.verified_user_outlined,
  'biometric': Icons.fingerprint,
  'star': Icons.star_rounded,
  'sparkle': Icons.auto_awesome,
  'greeting': Icons.waving_hand_outlined,

  // Feature domains that had no name yet.
  'note': Icons.sticky_note_2_outlined,
  'document': Icons.description_outlined,
  'pdf': Icons.picture_as_pdf_outlined,
  'folder': Icons.folder_open,
  'table': Icons.table_view_outlined,
  'grid': Icons.grid_on,
  'shopping': Icons.shopping_bag_outlined,
  'outgoing': Icons.north_east,
  'incoming': Icons.south_west,
  'event': Icons.event,
  'scheduled': Icons.event_available_outlined,
  'recurringDate': Icons.event_repeat_outlined,
  'exchange': Icons.currency_exchange,
  'percent': Icons.percent,
  'stats': Icons.query_stats,
  'offline': Icons.cloud_off_outlined,
  'backedUp': Icons.cloud_done_outlined,
  'network': Icons.wifi,
  // The contactless-payment arcs on a bank card. A meaning of its own, not
  // 'network': the two happen to share Material's wifi-ish family but mean
  // different things and are free to diverge.
  'contactless': Icons.contactless_outlined,
  'notifications': Icons.notifications_none,
  'notificationsOff': Icons.notifications_off_outlined,
  'phoneRing': Icons.phonelink_ring_outlined,
  'vibration': Icons.vibration,
  'appearance': Icons.palette_outlined,
  'mindset': Icons.self_improvement_outlined,
  'learning': Icons.school_outlined,
  'plan': Icons.flag_outlined,
  'diagnostics': Icons.bug_report_outlined,
  'screen': Icons.screenshot_monitor_outlined,
  'widgets': Icons.widgets_outlined,
  'billing': Icons.request_quote_outlined,
  'checklist': Icons.fact_check_outlined,
  'setup': Icons.build_outlined,
  'bank': Icons.account_balance_outlined,
  'send': Icons.send_outlined,
  'quick': Icons.bolt_outlined,

  // Goal templates. Content declares which fund a template is; the pictures
  // stay swappable here. The old goal template emoji (a lifebuoy, a tree, a
  // plane, a stethoscope) were the last authored emoji on a screen; a goal
  // the USER already saved keeps whatever emoji they picked, because that is
  // their data, not ours.
  'goal': Icons.my_location_outlined,
  'emergency': Icons.support_outlined,
  'pasko': Icons.park_outlined,
  'travel': Icons.flight_takeoff,
  'education': Icons.school_outlined,
  'familySupport': Icons.volunteer_activism_outlined,
  'gadget': Icons.devices_outlined,
  'wedding': Icons.favorite_outline,
  'house': Icons.cottage_outlined,
  'debtPayoff': Icons.trending_down_outlined,
};

/// Icon size tokens. Passive detail 16, inline with text 20, action 24,
/// feature or template card 32, empty-state composition 48. A size outside
/// this scale is a design decision to defend in review, not a default.
abstract final class SalapifyIconSize {
  static const double detail = 16;
  static const double inline = 20;
  static const double action = 24;
  static const double feature = 32;
  static const double hero = 48;
}

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

/// Every name the map knows, so the guard test can prove each one resolves
/// and the goal template registry can assert its keys are real.
Iterable<String> get salapifyIconNames => _icons.keys;

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
IconData salapifyIconSelected(String name) =>
    _filled[name] ?? salapifyIcon(name);

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
