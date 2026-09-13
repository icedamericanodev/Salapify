// The component kit. Every screen is built from these and nothing else.
//
// This file exists so a screen CANNOT quietly invent a second card shape or a
// second way to draw a row. D12 locks the look; this is where that lock is
// enforced in code rather than in a document.
//
// Ported from docs/revamp/mockups/hapon/source/kit.dart, which produced the 24
// renders the founder approved on 2026-09-13. Three changes and no others:
// the preview's mutable `skin` global became `context.skin` so the palette can
// follow the phone; every inline `ts(15, w500, ...)` became its named role on
// the ladder in type.dart; and `Row_` and `Chip_` became `ItemRow` and
// `PickChip`, because the preview's underscore dodge around Flutter's own Row
// and Chip is a name analyze rejects. NO NUMBER MOVED. Every size, weight,
// padding, radius and inset below is the one in the approved pictures.
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'type.dart';

// ---------------------------------------------------------------- scaffold

/// The scrolling body of a tab screen.
///
/// Deliberately does NOT draw the nav bar, which the preview's version did.
/// The preview had no shell, so every screen carried its own copy. In the real
/// app the shell owns ONE bar and keeps it alive across all four tabs, so it
/// never rebuilds or re-animates when a tab changes. The bottom padding here
/// is what leaves room for it, and the rendered result is identical.
class Screen extends StatelessWidget {
  const Screen({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(gutter, 6, gutter, 130),
        physics: const BouncingScrollPhysics(),
        children: children,
      ),
    );
  }
}

/// The date line and the bell. Home only, but it lives here because any screen
/// that grows one must grow the same one.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      children: [
        Expanded(child: Text(date, style: TypeScale.quiet(skin.text2))),
        Icon(Icons.notifications_none_rounded, size: 23, color: skin.text2),
      ],
    );
  }
}

/// A screen title with an optional trailing action. Not the same thing as
/// [Head], which titles a section INSIDE a screen.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle({super.key, required this.title, this.action, this.sub});
  final String title;
  final String? action;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(title, style: TypeScale.screenTitle(skin.text)),
            ),
            if (action != null)
              Text(action!, style: TypeScale.control(skin.accent)),
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub!, style: TypeScale.subtitle(skin.text3)),
        ],
      ],
    );
  }
}

/// A section heading inside a screen, with an optional trailing action.
class Head extends StatelessWidget {
  const Head({super.key, required this.title, this.action});
  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: TypeScale.sectionHead(skin.text)),
        if (action != null) Text(action!, style: TypeScale.action(skin.accent)),
      ],
    );
  }
}

// ---------------------------------------------------------------- surfaces

/// A card holding rows, with a hairline between rows and none after the last.
/// Without the hairline a fourteen row list is one white slab.
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.inset = 52});
  final List<Widget> children;

  /// Where the hairline starts. 52 clears the icon disc; 0 for rows with no
  /// disc, so the rule runs the full width instead of starting nowhere.
  final double inset;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final laid = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      laid.add(children[i]);
      if (i != children.length - 1) {
        laid.add(
          Padding(
            padding: EdgeInsets.only(left: inset),
            child: Container(height: 1, color: skin.line),
          ),
        );
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: BorderRadius.circular(skin.radius),
      ),
      child: Column(children: laid),
    );
  }
}

/// A plain card for anything that is not a list of rows.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.pad = 18});
  final Widget child;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: BorderRadius.circular(skin.radius),
      ),
      child: child,
    );
  }
}

/// Colour on a row means DIRECTION, never emphasis. If every amount is
/// coloured then colour means nothing.
enum Tone { plain, good, owe }

/// The one list row in the app.
class ItemRow extends StatelessWidget {
  const ItemRow({
    super.key,
    this.icon,
    required this.title,
    this.sub,
    required this.amount,
    this.amountSub,
    this.tone = Tone.plain,
    this.strike = false,
  });

  final IconData? icon;
  final String title;
  final String? sub;
  final String? amountSub;
  final String amount;
  final Tone tone;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final c = switch (tone) {
      Tone.plain => skin.text,
      Tone.good => skin.good,
      Tone.owe => skin.accent,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          if (icon != null) ...[
            // One disc, one tint, one size, so a long row of icons reads as
            // one texture instead of fourteen separate stickers.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: skin.discOnCard,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 19, color: skin.text2),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.rowTitle(skin.text).copyWith(
                    decoration: strike ? TextDecoration.lineThrough : null,
                    decorationColor: skin.text3,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub!, style: TypeScale.caption(skin.text3)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: TypeScale.rowAmount(c)),
              if (amountSub != null) ...[
                const SizedBox(height: 3),
                Text(amountSub!, style: TypeScale.captionSm(skin.text3)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- controls

/// The 5 dp bar. Budgets, credit limits, debt progress, the sweldo rail.
class ThinBar extends StatelessWidget {
  const ThinBar({
    super.key,
    required this.fraction,
    this.fill,
    this.track,
    this.height = 5,
  });

  final double fraction;
  final Color? fill;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Container(color: track ?? skin.line),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: fill ?? skin.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class PickChip extends StatelessWidget {
  const PickChip({super.key, required this.label, this.on = false, this.onTap});
  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? skin.accent : skin.card,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TypeScale.control(on ? skin.onAccent : skin.text2),
        ),
      ),
    );
  }
}

class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.index,
    this.onPick,
  });

  final List<String> options;
  final int index;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: onPick == null ? null : () => onPick!(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index ? skin.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: i == index
                        ? TypeScale.controlOn(skin.onAccent)
                        : TypeScale.controlOn(skin.text3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The accent pill. The only primary button, and the only place the accent
/// becomes a fill rather than ink.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.secondary = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool secondary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final fg = secondary ? skin.accent : skin.onAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: secondary ? skin.card : skin.accent,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 7),
            ],
            Text(label, style: TypeScale.button(fg)),
          ],
        ),
      ),
    );
  }
}

class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.value,
    this.hint = false,
    this.leading,
  });
  final String value;
  final bool hint;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(leading, size: 19, color: skin.text3),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              value,
              style: TypeScale.rowTitle(hint ? skin.text3 : skin.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a screen says when it has nothing to show yet.
///
/// New in v3 and not a port: the preview had fixture data on every screen, so
/// it never had to answer this. An empty screen with nothing on it is the
/// first thing the founder will see on a fresh install, and "blank" is not a
/// design. It is built from the kit like everything else.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Panel(
      pad: 26,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: skin.discOnCard,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: skin.text2),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TypeScale.sectionHead(skin.text),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TypeScale.hint(skin.text3),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- nav

/// The four tabs and the Log pill. The shell owns which tab is active and what
/// tapping one does; this only draws it.
class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.active, this.onTab, this.onLog});

  final int active;
  final ValueChanged<int>? onTab;
  final VoidCallback? onLog;

  /// The tab set, in order. Accounts, not Wallets. Wallet is Tarsi's word and
  /// this rebuild exists because of the sentence "it looks like we copy the
  /// Tarsi". See D3.
  static const tabs = <(String, IconData)>[
    ('Home', Icons.home_outlined),
    ('Ledger', Icons.article_outlined),
    ('Plan', Icons.donut_small_outlined),
    ('Accounts', Icons.account_balance_wallet_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // The fade strip has to finish BEFORE the icon row starts, or the last
    // list row shows through the tabs. It did, in the first render.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [skin.bg.withValues(alpha: 0.0), skin.bg],
            ),
          ),
        ),
        Container(
          color: skin.bg,
          padding: const EdgeInsets.fromLTRB(gutter, 4, gutter, 26),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTab == null ? null : () => onTab!(i),
                    child: Column(
                      children: [
                        Icon(
                          tabs[i].$2,
                          size: 23,
                          color: i == active ? skin.text : skin.text3,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          tabs[i].$1,
                          style: TypeScale.tab(
                            i == active ? skin.text : skin.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              // A labelled pill, not a round FAB. The round accent circle in a
              // tab bar is a named signature of the apps this must not read as.
              GestureDetector(
                onTap: onLog,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                  decoration: BoxDecoration(
                    color: skin.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: skin.onAccent, size: 22),
                      const SizedBox(width: 4),
                      Text('Log', style: TypeScale.navPill(skin.onAccent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
