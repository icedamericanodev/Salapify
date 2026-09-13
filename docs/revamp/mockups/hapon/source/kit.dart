// The component kit. Every screen is built from these and nothing else.
//
// This file exists so a screen CANNOT quietly invent a second card shape or a
// second way to draw a row. D12 locks the look; this is where that lock is
// enforced in code rather than in a document.
import 'package:flutter/material.dart';
import 'skin.dart';

/// The one type helper. Tabular figures always, so a column of amounts never
/// jiggles as the digits change.
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

/// Screen gutter. One number, used everywhere.
const double gutter = 22;

// ---------------------------------------------------------------- scaffold

/// Every tab screen. Takes the whole scrolling body and puts the nav bar over
/// it, with the fade strip that stops the last row showing through the tabs.
class Screen extends StatelessWidget {
  const Screen({super.key, required this.children, required this.tab});
  final List<Widget> children;
  final int tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: skin.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(gutter, 6, gutter, 130),
              physics: const BouncingScrollPhysics(),
              children: children,
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: NavBar(active: tab)),
        ],
      ),
    );
  }
}

/// The date line and the bell. Home only, but it lives here because any screen
/// that grows one must grow the same one.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.date = 'Saturday, Sep 13'});
  final String date;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(date, style: ts(14, FontWeight.w500, skin.text2))),
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
  final String? action, sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                title,
                style: ts(27, FontWeight.w700, skin.text, ls: -0.8),
              ),
            ),
            if (action != null)
              Text(action!, style: ts(13.5, FontWeight.w500, skin.accent)),
          ],
        ),
        if (sub != null) ...[
          const SizedBox(height: 6),
          Text(sub!, style: ts(14, FontWeight.w400, skin.text3)),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: ts(16, FontWeight.w600, skin.text, ls: -0.2)),
        if (action != null)
          Text(action!, style: ts(13, FontWeight.w500, skin.accent)),
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(pad),
    decoration: BoxDecoration(
      color: skin.card,
      borderRadius: BorderRadius.circular(skin.radius),
    ),
    child: child,
  );
}

/// The one list row in the app.
class Row_ extends StatelessWidget {
  const Row_({
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
  final String? sub, amountSub;
  final String amount;
  final Tone tone;
  final bool strike;

  @override
  Widget build(BuildContext context) {
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
                  style: ts(15, FontWeight.w500, skin.text).copyWith(
                    decoration: strike ? TextDecoration.lineThrough : null,
                    decorationColor: skin.text3,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 3),
                  Text(sub!, style: ts(12.5, FontWeight.w400, skin.text3)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount, style: ts(15.5, FontWeight.w600, c, ls: -0.3)),
              if (amountSub != null) ...[
                const SizedBox(height: 3),
                Text(amountSub!, style: ts(12, FontWeight.w400, skin.text3)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Colour on a row means DIRECTION, never emphasis. If every amount is
/// coloured then colour means nothing.
enum Tone { plain, good, owe }

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
  final Color? fill, track;
  final double height;

  @override
  Widget build(BuildContext context) {
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

class Chip_ extends StatelessWidget {
  const Chip_({super.key, required this.label, this.on = false});
  final String label;
  final bool on;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: on ? skin.accent : skin.card,
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: ts(13.5, FontWeight.w500, on ? skin.onAccent : skin.text2),
    ),
  );
}

class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.index});
  final List<String> options;
  final int index;
  @override
  Widget build(BuildContext context) {
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: i == index ? skin.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: ts(
                    13.5,
                    FontWeight.w600,
                    i == index ? skin.onAccent : skin.text3,
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
  });
  final String label;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final fg = secondary ? skin.accent : skin.onAccent;
    return Container(
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
          Text(label, style: ts(15, FontWeight.w600, fg)),
        ],
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
  Widget build(BuildContext context) => Container(
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
            style: ts(15, FontWeight.w500, hint ? skin.text3 : skin.text),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- nav

class NavBar extends StatelessWidget {
  const NavBar({super.key, required this.active});
  final int active;

  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('Home', Icons.home_outlined),
      ('Ledger', Icons.article_outlined),
      ('Plan', Icons.donut_small_outlined),
      // Accounts, not Wallets. Wallet is Tarsi's word and this rebuild exists
      // because of the sentence "it looks like we copy the Tarsi". See D3.
      ('Accounts', Icons.account_balance_wallet_outlined),
    ];
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
                        style: ts(
                          10.5,
                          FontWeight.w500,
                          i == active ? skin.text : skin.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              // A labelled pill, not a round FAB. The round accent circle in a
              // tab bar is a named signature of the apps this must not read as.
              Container(
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
                    Text(
                      'Log',
                      style: ts(14.5, FontWeight.w600, skin.onAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
