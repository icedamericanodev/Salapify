import 'package:flutter/material.dart';

import 'tokens.dart';

/// Salapify's own icons: Material glyphs in the theme accent, resolved by NAME.
///
/// Content declares the MEANING ('shield', 'mind', 'card') and this one file
/// decides how it is drawn, so restyling every icon in the app is a single
/// edit. Emoji cannot do this: they are OS-drawn multicolour stickers, the
/// palette cannot reach them, and they change shape between phones.
///
/// The line that decides what belongs here: it covers icons SALAPIFY authors,
/// such as course tracks and empty states. It must NEVER be extended to emoji
/// the USER picked. Category icons, goal icons and account icons are user data
/// and live in their backup file; replacing those would overwrite a choice
/// that was never ours.
class SalapifyIcon extends StatelessWidget {
  const SalapifyIcon({
    super.key,
    required this.name,
    required this.palette,
    this.size = 16,
    this.color,
  });

  final String name;
  final Palette palette;
  final double size;
  final Color? color;

  /// The map. A name missing from here falls back to a neutral marker rather
  /// than taking a screen down, and the content test is what stops that
  /// fallback being reached silently.
  static const Map<String, IconData> glyphs = <String, IconData>{
    'mind': Icons.psychology_outlined,
    'target': Icons.adjust,
    'transfer': Icons.swap_horiz,
    'bank': Icons.account_balance_outlined,
    'shieldAlert': Icons.gpp_maybe_outlined,
    'shield': Icons.verified_user_outlined,
    'trendingDown': Icons.trending_down,
    'card': Icons.credit_card_outlined,
    'calendar': Icons.event_outlined,
    'savings': Icons.savings_outlined,
    'award': Icons.workspace_premium_outlined,
    'chart': Icons.show_chart,
    'sliders': Icons.tune,
    'shopping': Icons.shopping_bag_outlined,
    'palm': Icons.beach_access_outlined,
    'document': Icons.description_outlined,
    'warning': Icons.warning_amber_outlined,
    'sparkle': Icons.auto_awesome_outlined,
    'health': Icons.monitor_heart_outlined,
    'people': Icons.people_outline,
    'handshake': Icons.volunteer_activism_outlined,
    'send': Icons.send_outlined,
    'laptop': Icons.laptop_mac_outlined,
    'bolt': Icons.bolt_outlined,
    'package': Icons.inventory_2_outlined,
    'share': Icons.share_outlined,
    'building': Icons.apartment_outlined,
    'briefcase': Icons.work_outline,
    'scale': Icons.balance,
    'globe': Icons.public_outlined,
    'phone': Icons.smartphone_outlined,
    'mountain': Icons.landscape_outlined,
  };

  /// The marker a typo lands on. Never a crash, and deliberately a QUESTION
  /// MARK rather than a neutral circle: 'target' resolves to Icons.adjust,
  /// which is a circle, so a circular fallback would be indistinguishable
  /// from a legitimate icon and the mistake would look intentional.
  static const IconData fallback = Icons.help_outline;

  static IconData resolve(String name) => glyphs[name] ?? fallback;

  @override
  Widget build(BuildContext context) {
    return Icon(resolve(name), size: size, color: color ?? palette.accent);
  }
}
