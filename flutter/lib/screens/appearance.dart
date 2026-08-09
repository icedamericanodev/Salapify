// Appearance: the light/dark MODE and the eight color themes, on their own
// screen instead of squeezed into a card at the bottom of Menu.
//
// It moved for width, not tidiness. Inside a Menu card the content is 20 + 20
// of page padding plus 16 + 16 of card padding, so on a 320dp phone a tile gets
// 118dp and "Ultraviolet" at 14/w700 already touches the edge. A pushed screen
// gives 280dp and a 134dp tile, which is exactly enough for a preview, a name
// and a two line hint. The old card could not hold an honest preview, so it did
// not have one.
//
// Three other things fell out of the move, all of them free. The Menu row now
// shows which theme you are on, which the app could not tell you anywhere
// before. The screen fits in a single golden shot, so the "look at the screen
// before shipping it" rule can finally be followed here. And Menu loses a card
// that sat a full screen below the fold.
//
// Nothing on this screen is an asset. Every visual is a colored box or a glyph
// already compiled in, so it patches over the air.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/section.dart';
import '../widgets/segmented.dart';
import '../widgets/salapify_icon.dart';

const Map<String, String> appearanceModeLabels = {
  'system': 'System',
  'light': 'Light',
  'dark': 'Dark',
};

class AppearanceScreen extends StatelessWidget {
  final SalapifyStore store;

  // NOT const. build() reads Barako getters, and this is the one screen in the
  // app where the palette changes while you are looking at it, so a frozen
  // const subtree would be visible immediately.
  // ignore: prefer_const_constructors_in_immutables
  AppearanceScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final (rawKey, currentMode) = resolveThemeChoice(
          store.data['settings'],
        );
        // Highlight the theme actually in effect. An unknown or future key
        // renders as Barako (themeForKey falls back), so Barako is what should
        // show as selected.
        final currentKey = themeForKey(rawKey).key;

        Future<void> save(Future<void> Function() action) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await action();
          } catch (_) {
            // Deliberately no "$e". The old message pasted the raw exception
            // into a settings screen, so a real failure showed the founder a
            // FileSystemException. The tiles read from store.data, so a failed
            // write leaves the previous theme selected with no rollback code,
            // which is what makes this short sentence true.
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Could not save that. Your look did not change.'),
              ),
            );
          }
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Barako.background,
            foregroundColor: Barako.text,
            title: Text(
              'Appearance',
              style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, Gap.xxl),
              children: [
                Kicker('MODE'),
                const SizedBox(height: Gap.md),
                Segmented<String>(
                  current: currentMode,
                  onPick: (m) => save(() => store.setThemeMode(m)),
                  options: [
                    for (final m in appearanceModes)
                      SegmentOption(
                        value: m,
                        label: appearanceModeLabels[m] ?? m,
                        semanticLabel:
                            '${appearanceModeLabels[m] ?? m} appearance',
                      ),
                  ],
                ),
                const SizedBox(height: Gap.sm),
                Text(
                  'System follows your phone, so the app goes dark at night on '
                  'its own.',
                  style: AppText.caption.copyWith(height: 1.3),
                ),
                const SizedBox(height: Gap.xl),
                Kicker('COLOR THEME'),
                const SizedBox(height: Gap.sm),
                Text(
                  'Barako is the Salapify look. Your money, entries and '
                  'settings never change.',
                  style: AppText.caption.copyWith(height: 1.3),
                ),
                const SizedBox(height: Gap.md),
                _ThemeGrid(
                  selectedKey: currentKey,
                  onPick: (key) => save(() => store.setThemeKey(key)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The eight themes, two to a row, with both tiles in a row the same height.
///
/// Deliberately paired Rows rather than a Wrap. A Wrap lets every tile take its
/// own height, which sounds harmless and renders as a ragged edge whenever two
/// neighbours have hints of different lengths: "Deep navy, vivid aqua." is one
/// line and "Coral on charcoal. Barako, hotter." is two, so that row came out
/// visibly lopsided. IntrinsicHeight with a stretched Row gives the pair the
/// taller of the two heights.
///
/// Still not a GridView. GridView wants a fixed childAspectRatio, which clips
/// the hint the moment someone turns the system font size up; this grows
/// instead, row by row.
class _ThemeGrid extends StatelessWidget {
  final String selectedKey;
  final void Function(String) onPick;

  // ignore: prefer_const_constructors_in_immutables
  _ThemeGrid({required this.selectedKey, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - Gap.md) / 2;
        Widget tile(BarakoTheme t) => SizedBox(
          width: width,
          child: ThemeTile(
            theme: t,
            selected: selectedKey == t.key,
            onTap: () => onPick(t.key),
          ),
        );
        final rows = <Widget>[];
        for (var i = 0; i < barakoThemes.length; i += 2) {
          if (i > 0) rows.add(const SizedBox(height: Gap.md));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tile(barakoThemes[i]),
                  // Guarded rather than assumed. An odd count is not possible
                  // today, but a ninth theme should widen the grid, not throw.
                  if (i + 1 < barakoThemes.length) ...[
                    const SizedBox(width: Gap.md),
                    tile(barakoThemes[i + 1]),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows,
        );
      },
    );
  }
}

/// One theme: a preview of the app in it, its name, and its hint.
class ThemeTile extends StatelessWidget {
  final BarakoTheme theme;
  final bool selected;
  final VoidCallback onTap;

  // ignore: prefer_const_constructors_in_immutables
  ThemeTile({
    super.key,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve at the brightness actually in effect, so the preview shows what
    // you will get right now rather than a marketing render.
    final p = theme.resolve(Barako.current.brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} theme. ${theme.hint}',
      child: ExcludeSemantics(
        child: PressableScale(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(Radii.card),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () {
                Haptics.select();
                onTap();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(Gap.md),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.card),
                  // The width is ALWAYS 2 and only the color changes. The RN
                  // screen swaps 1dp for 2dp and then shaves a pixel of padding
                  // to compensate, which is a hack around a reflow; holding the
                  // width fixed removes the reflow, and leaves AnimatedContainer
                  // a pure color tween with no layout pass.
                  border: Border.all(
                    width: 2,
                    color: selected ? Barako.primary : Barako.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PalettePreview(palette: p, selected: selected),
                    const SizedBox(height: Gap.sm),
                    Text(
                      theme.label,
                      // Two lines, not one. At 1.4x system font on a 320dp
                      // phone "Orchid Gold" truncated to "Orchid G...", and a
                      // theme whose NAME is unreadable is worse than a tall
                      // tile. Nothing wraps at normal size, so this costs
                      // nothing until it is needed.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.w7.copyWith(height: 1.2),
                    ),
                    const SizedBox(height: Gap.xxs),
                    // No maxLines. RN caps the hint at three lines, which clips
                    // at large system font sizes; the Wrap above lets each row
                    // take the height its tallest tile needs, so an uncapped
                    // hint can never clip and can never overflow.
                    //
                    // muted, not faint: faint on card bottoms out at 4.53 in
                    // four dark palettes, three hundredths above AA, and this
                    // is text the user is meant to read and compare.
                    Text(
                      theme.hint,
                      style: AppText.caption.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A miniature of the app, drawn in one theme's palette.
///
/// This replaces a single two tone dot, which could not tell Barako, Ember and
/// Forest apart because all three have a near identical orange accent. The
/// accent is about five percent of a real screen, so a preview dominated by the
/// accent asks the wrong question. What actually separates the themes is the
/// background, the card sitting on it, and the win color, so those get the
/// pixels here in roughly the proportions the app uses.
///
/// Eight tokens, each earning its place: [background] and [card] carry most of
/// the screen; [border] is what makes a card read as an object rather than a
/// smudge (without it Voltage would preview as a black square); [text] and
/// [muted] make this a live legibility demo that cannot flatter a palette it
/// does not deserve; [primary] with [onPrimary] INSIDE it shows whether buttons
/// carry white or dark labels, which changes how every action in the app feels
/// and which no dot preview can show; [celebrate] is deliberately the SAME
/// gold in every theme now (the win signature is brand, like Pan's orange), so
/// in the preview it reads as the one constant across all eight tiles.
///
/// Deliberately no peso amount. Money is golden locked, and a settings screen
/// is the last place a figure should appear where it could be mistaken for
/// yours.
class _PalettePreview extends StatelessWidget {
  final BarakoPalette palette;
  final bool selected;

  // ignore: prefer_const_constructors_in_immutables
  _PalettePreview({required this.palette, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(Radii.control),
              // The CURRENT theme's line, not the previewed one. Previewing
              // Barako dark while already on Barako dark puts #1A130E against
              // #251A13, a contrast of 1.08, so the preview would have no
              // visible edge at all. Every tile gets the same outline the rest
              // of the app uses.
              border: Border.all(color: Barako.border),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // The accent button, with its label color inside it.
                    Container(
                      width: 26,
                      height: 9,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                          color: palette.onPrimary,
                          borderRadius: BorderRadius.circular(Radii.pill),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    // The win color.
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: palette.celebrate,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // The hero amount, then the line under it.
                        _Bar(color: palette.text, height: 5, widthFactor: 0.62),
                        const SizedBox(height: 4),
                        _Bar(color: palette.muted, height: 3, widthFactor: 0.4),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selected) Positioned(right: -4, top: -4, child: _CheckBadge()),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final Color color;
  final double height;
  final double widthFactor;

  // ignore: prefer_const_constructors_in_immutables
  _Bar({required this.color, required this.height, required this.widthFactor});

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
    ),
  );
}

/// Selection, shown as a shape rather than only as a color.
///
/// A filled disc, not a tinted check glyph. The disc guarantees the onPrimary
/// on primary pair, which measures 5.23 at worst across all sixteen palettes; a
/// bare glyph would sit on whatever the previewed palette happens to be and
/// could land on its own hue.
class _CheckBadge extends StatelessWidget {
  // ignore: prefer_const_constructors_in_immutables
  _CheckBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    decoration: BoxDecoration(
      color: Barako.primary,
      shape: BoxShape.circle,
      border: Border.all(color: Barako.card, width: 2),
    ),
    child: Icon(salapifyIcon('chosen'), size: 12, color: Barako.onPrimary),
  );
}
