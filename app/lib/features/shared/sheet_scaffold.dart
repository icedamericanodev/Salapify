import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/type.dart';

/// The shell every Salapify sheet is built in.
///
/// The prototype draws each modal by hand, and they drift: different header
/// paddings, different close buttons, tabs that are underlined in one and
/// pilled in another. One scaffold means a new sheet cannot invent its own
/// chrome, and it means the 44dp tap-target floor is enforced once rather than
/// remembered five times.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.banner,
    this.tabs,
    this.selectedTab = 0,
    this.onSelectTab,
    this.footer,
  });

  final Palette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  /// An optional strip under the header, for a mode switch that applies to
  /// every tab.
  final Widget? banner;

  final List<String>? tabs;
  final int selectedTab;
  final ValueChanged<int>? onSelectTab;

  /// A pinned action row. Kept OUT of the scroll so the primary action cannot
  /// be scrolled away on a short phone.
  final Widget? footer;

  /// Opens a sheet as a bottom sheet, which is the right shape on a phone: a
  /// centred dialog wastes the width and puts the close button where a thumb
  /// cannot reach.
  static Future<T?> show<T>({
    required BuildContext context,
    required Palette palette,
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // A sheet that only opens to half the screen forces a drag before
      // anything can be read, so these open tall.
      constraints: const BoxConstraints(maxWidth: 640),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);

    return Container(
      // 92% of the height, matching the prototype, so the sheet reads as a
      // layer over the app rather than a new screen.
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Radii.card),
        ),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _grabHandle(),
          _header(context),
          ?banner,
          if (tabs != null && tabs!.isNotEmpty) _tabBar(),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.lg,
                Spacing.lg,
                // Clears the keyboard when a field in the sheet has focus,
                // plus the home indicator.
                Spacing.lg + mq.viewInsets.bottom + mq.padding.bottom,
              ),
              child: child,
            ),
          ),
          if (footer != null)
            Container(
              padding: EdgeInsets.fromLTRB(
                Spacing.lg,
                Spacing.md,
                Spacing.lg,
                Spacing.md + mq.padding.bottom,
              ),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: footer,
            ),
        ],
      ),
    );
  }

  Widget _grabHandle() {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.xs),
      color: palette.surface,
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: palette.border,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.sm,
        Spacing.sm,
        Spacing.md,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(Radii.tile),
            ),
            child: Icon(icon, size: 18, color: palette.accent),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.title(palette),
                ),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption(palette),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Close',
            child: InkWell(
              onTap: () => Navigator.of(context).maybePop(),
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.close, size: 20, color: palette.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        child: Row(
          children: <Widget>[
            for (int i = 0; i < tabs!.length; i++)
              _Tab(
                palette: palette,
                label: tabs![i],
                selected: i == selectedTab,
                onTap: () => onSelectTab?.call(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? palette.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? palette.accent : palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled figure in a grid. The four-up block the prototype opens most of
/// its calculators with.
/// Two cards side by side, drawn to the SAME height.
///
/// Written as one widget because the obvious way to do this is wrong in a
/// sheet, and it was wrong in four places before a test caught it. A Row with
/// CrossAxisAlignment.stretch tells its children to fill the row's height, and
/// inside a vertical scroll view the row has no height to fill, so Flutter
/// hands the children an infinite constraint and the sheet throws instead of
/// rendering. IntrinsicHeight measures the taller child first and gives the
/// row a real height to stretch into, which is what "same height" actually
/// needs.
class StatPair extends StatelessWidget {
  const StatPair({super.key, required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: Spacing.md),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    this.caption,
    this.valueColor,
  });

  final Palette palette;
  final String label;
  final String value;
  final String? caption;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppType.kicker(palette).copyWith(fontSize: 10),
          ),
          const SizedBox(height: Spacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppType.amount(palette).copyWith(
                fontSize: 20,
                color: valueColor ?? palette.textPrimary,
              ),
            ),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: Spacing.xs),
            Text(caption!, style: AppType.caption(palette)),
          ],
        ],
      ),
    );
  }
}

/// One line of a breakdown: a label on the left, a figure on the right.
class BreakdownRow extends StatelessWidget {
  const BreakdownRow({
    super.key,
    required this.palette,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasis = false,
  });

  final Palette palette;
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: emphasis
                  ? AppType.rowTitle(palette)
                  : AppType.body(palette).copyWith(fontSize: 12),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            value,
            style: AppType.amountSmall(palette).copyWith(
              color: valueColor ?? palette.textPrimary,
              fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A primary action, sized to the 44dp floor.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.palette,
    required this.label,
    this.icon,
    this.onTap,
  });

  final Palette palette;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Material(
        color: enabled ? palette.accent : palette.border,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Icon(
                    icon,
                    size: 16,
                    color: enabled ? palette.onAccent : palette.textMuted,
                  ),
                  const SizedBox(width: Spacing.sm),
                ],
                Text(
                  label,
                  style: AppType.button(
                    palette,
                    color: enabled ? palette.onAccent : palette.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled text field. Numeric by default, because almost every field in
/// these sheets is money.
class SheetField extends StatelessWidget {
  const SheetField({
    super.key,
    required this.palette,
    required this.label,
    required this.controller,
    this.hint,
    // WITH a decimal point. Plain TextInputType.number maps to Android's
    // TYPE_CLASS_NUMBER without the decimal flag, so the numeric pad has no
    // "." key at all and a centavo amount simply cannot be typed. Every field
    // in these sheets that defaults to numeric is a money field.
    this.keyboardType = const TextInputType.numberWithOptions(decimal: true),
    this.prefix,
    this.onChanged,
  });

  final Palette palette;
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboardType;
  final String? prefix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: AppType.rowTitle(palette).copyWith(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppType.body(palette).copyWith(color: palette.textMuted),
            prefixText: prefix,
            prefixStyle: AppType.rowTitle(palette).copyWith(fontSize: 15),
            filled: true,
            fillColor: palette.card,
            // 48 tall, comfortably past the 44 floor.
            contentPadding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              borderSide: BorderSide(color: palette.accent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// A segmented choice. Used for scenario, entity type, regime and rate type.
///
/// Needs a BOUNDED width: the segments are equal shares of the row, so putting
/// one in a Row without an Expanded around it throws rather than guessing.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.palette,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.trackSoft,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: palette.border),
      ),
      // Equal segments on ONE line, which is what a segmented control is. It
      // was a Wrap, to stop a four-way control overflowing at 320dp, and the
      // render showed what that actually produced: four full-width buttons
      // stacked down the sheet, 330px tall, looking like a menu. Nothing
      // overflows here because the labels WRAP inside their own segment
      // instead, so a narrow phone makes the bar taller rather than broken.
      child: Row(
        children: <Widget>[
          for (final (T value, String label) in options) ...<Widget>[
            if (value != options.first.$1) const SizedBox(width: 3),
            Expanded(
              child: _Segment(
                palette: palette,
                label: label,
                selected: value == selected,
                onTap: () => onSelect(value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            // Tighter than the usual gutter, so a four-way control still has
            // room for its words at 320dp.
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              // Two lines rather than a cut-off word. "Every 2 weeks" does not
              // fit on one line in a quarter of a 320dp phone, and a label the
              // user cannot finish reading is worse than a taller bar.
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? palette.onAccent : palette.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
