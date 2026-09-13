// Salapify 3 design preview, real Flutter.
// One theme: Hapon in light, Gabi in dark. The layout is identical in both,
// so the dark shot is proof that dark is derived and not redrawn.
import 'package:flutter/material.dart';
import 'skin.dart';

export 'skin.dart';

void main() => runApp(const PreviewApp());

// ---------------------------------------------------------------- type

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

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});
  @override
  Widget build(BuildContext context) =>
      const MaterialApp(debugShowCheckedModeBanner: false, home: HomeScreen());
}

// ---------------------------------------------------------------- home

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: skin.bg,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 130),
              physics: const BouncingScrollPhysics(),
              children: [
                const _TopBar(),
                const SizedBox(height: 22),
                const Hero_(),
                const SizedBox(height: 30),
                const _QuickActions(),
                const SizedBox(height: 34),
                const _Head(title: 'Debt, both ways', action: 'See all'),
                const SizedBox(height: 14),
                const _DebtBlock(),
                const SizedBox(height: 34),
                const _Head(title: 'Coming up', action: 'See all'),
                const SizedBox(height: 6),
                const _Group(
                  children: [
                    _Row(
                      icon: Icons.bolt_outlined,
                      title: 'Meralco',
                      sub: 'Today',
                      amount: '₱2,340',
                    ),
                    _Row(
                      icon: Icons.music_note_outlined,
                      title: 'Spotify',
                      sub: 'Sun, Sep 14',
                      amount: '₱149',
                    ),
                    _Row(
                      icon: Icons.savings_outlined,
                      title: 'Payday',
                      sub: 'Mon, Sep 15',
                      amount: '+₱21,000',
                      positive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                const _Head(title: 'Latest', action: 'See all'),
                const SizedBox(height: 6),
                _Group(children: _latest()),
              ],
            ),
          ),
          const Positioned(left: 0, right: 0, bottom: 0, child: _NavBar()),
        ],
      ),
    );
  }
}

/// Three rows is a brochure. [dense] is the real daily state.
List<Widget> _latest() {
  const short = <_Row>[
    _Row(
      icon: Icons.lunch_dining_outlined,
      title: 'Jollibee',
      sub: 'Food · GCash',
      amount: '₱250',
    ),
    _Row(
      icon: Icons.directions_bus_outlined,
      title: 'Grab',
      sub: 'Transport · Maya',
      amount: '₱180',
    ),
    _Row(
      icon: Icons.south_west_rounded,
      title: 'Kuya Jun paid back',
      sub: 'Debt · Cash',
      amount: '+₱1,000',
      positive: true,
    ),
  ];
  if (!dense) return short;
  const more = <_Row>[
    _Row(
      icon: Icons.local_cafe_outlined,
      title: 'Kopiko Blanca',
      sub: 'Food · Cash',
      amount: '₱75',
    ),
    _Row(
      icon: Icons.shopping_bag_outlined,
      title: 'Puregold',
      sub: 'Groceries · BPI',
      amount: '₱2,847',
    ),
    _Row(
      icon: Icons.local_gas_station_outlined,
      title: 'Shell Katipunan',
      sub: 'Transport · GCash',
      amount: '₱1,200',
    ),
    _Row(
      icon: Icons.wifi_outlined,
      title: 'Converge',
      sub: 'Bills · Maya',
      amount: '₱1,699',
    ),
    _Row(
      icon: Icons.north_east_rounded,
      title: 'Lent to Ate Bing',
      sub: 'Debt · Cash',
      amount: '₱1,500',
    ),
    _Row(
      icon: Icons.medication_outlined,
      title: 'Mercury Drug',
      sub: 'Health · Cash',
      amount: '₱430',
    ),
    _Row(
      icon: Icons.directions_bus_outlined,
      title: 'Angkas',
      sub: 'Transport · GCash',
      amount: '₱165',
    ),
    _Row(
      icon: Icons.lunch_dining_outlined,
      title: 'Mang Inasal',
      sub: 'Food · Cash',
      amount: '₱219',
    ),
    _Row(
      icon: Icons.swap_horiz_rounded,
      title: 'GCash to BPI',
      sub: 'Move · not a spend',
      amount: '₱5,000',
    ),
    _Row(
      icon: Icons.school_outlined,
      title: 'Tuition, 3 of 10',
      sub: 'Bills · BPI',
      amount: '₱6,250',
    ),
    _Row(
      icon: Icons.south_west_rounded,
      title: 'Refund, Lazada',
      sub: 'Shopping · GCash',
      amount: '+₱899',
      positive: true,
    ),
  ];
  return [...short, ...more];
}

// ---------------------------------------------------------------- pieces

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Saturday, Sep 13',
            style: ts(14, FontWeight.w500, skin.text2),
          ),
        ),
        Icon(Icons.notifications_none_rounded, size: 23, color: skin.text2),
      ],
    );
  }
}

/// Signature device one. A LIGHT panel carrying DARK ink. Every fintech hero
/// on the reference board is the other way round, a dark panel with white ink,
/// so this is the thing that makes a cropped screenshot ours.
class Hero_ extends StatelessWidget {
  const Hero_({super.key});

  @override
  Widget build(BuildContext context) {
    final ink = skin.onHero;
    // A real second colour, not the ink dimmed with opacity. Dimming is what
    // breaks readability on a coloured field, so the quiet tone is measured
    // separately in the skin, against the panel's darkest stop.
    final quiet = skin.onHeroQuiet;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: skin.heroGradient,
        ),
        borderRadius: BorderRadius.circular(skin.radius + 6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SAFE TO SPEND',
            style: ts(11.5, FontWeight.w700, quiet, ls: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5, right: 2),
                child: Text('₱', style: ts(23, FontWeight.w500, quiet)),
              ),
              // Measured, not guessed. Plus Jakarta Sans draws a lining figure
              // at 0.750 of its font size, so 47 pt gives a 35.3 pt cap, which
              // is 8.6 percent of a 412 pt screen. Re-measured off the
              // finished PNG the drawn cap is 35.5 pt, 8.62 percent. The
              // money apps on the
              // reference board sit at 7.6 to 8.8 percent. The old 54 pt came
              // out at 9.83 percent and read as a poster.
              Text(
                '6,240',
                style: ts(47, FontWeight.w700, ink, h: 1.0, ls: -1.7),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('.00', style: ts(20, FontWeight.w500, quiet)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '₱1,560 a day until payday on Monday.',
            style: ts(14.5, FontWeight.w400, quiet),
          ),
          const SizedBox(height: 20),
          // Signature device two, the sweldo rail. The filled part used to be
          // solid onHero, a hard black rule across a warm panel and the second
          // heaviest object on the screen. It is the quiet ink now: still
          // 5.42 to 1 at the panel's darkest, well past the 3.0 a meaningful
          // non text element needs, and 3.74 against its own track.
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: skin.onHero.withValues(alpha: 0.20)),
                  FractionallySizedBox(
                    widthFactor: 0.786,
                    child: Container(color: quiet),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('4 days to payday', style: ts(12.5, FontWeight.w500, quiet)),
              Text('Sep 1 to 15', style: ts(12.5, FontWeight.w500, quiet)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Four things a person actually does. Four is the ceiling, one row, never a
/// grid. That is the GCash convention with the GCash mistake removed.
class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    const items = [
      ('Log', Icons.add_rounded),
      ('Debt', Icons.swap_vert_rounded),
      ('Bills', Icons.event_outlined),
      ('Move', Icons.arrow_forward_rounded),
    ];
    return Row(
      children: [
        for (final (label, icon) in items)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: skin.discOnPage,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 21, color: skin.text),
                ),
                const SizedBox(height: 8),
                Text(label, style: ts(12.5, FontWeight.w500, skin.text2)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.title, required this.action});
  final String title, action;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(title, style: ts(16, FontWeight.w600, skin.text, ls: -0.2)),
        Text(action, style: ts(13, FontWeight.w500, skin.accent)),
      ],
    );
  }
}

/// A group of rows on one card, with a hairline between rows and none after
/// the last. Without the hairline a fourteen row list is a single white slab,
/// which is what three tidy demo rows hid.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final laid = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      laid.add(children[i]);
      if (i != children.length - 1) {
        laid.add(
          Padding(
            padding: const EdgeInsets.only(left: 52),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.sub,
    required this.amount,
    this.positive = false,
  });
  final IconData icon;
  final String title, sub, amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          // One disc, one tint, one size, so a long row of icons reads as one
          // texture instead of fourteen separate stickers.
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ts(15, FontWeight.w500, skin.text),
                ),
                const SizedBox(height: 3),
                Text(sub, style: ts(12.5, FontWeight.w400, skin.text3)),
              ],
            ),
          ),
          // Ordinary amounts are never coloured. Colour on this screen means
          // direction, and if every amount is coloured then colour means
          // nothing.
          Text(
            amount,
            style: ts(
              15.5,
              FontWeight.w600,
              positive ? skin.good : skin.text,
              ls: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Signature device three, the debt beam. Both directions in one object: the
/// two amounts sit above their own ends of a single split bar.
///
/// The owe half used to be solid [Skin.text], a pure black slab 78 percent of
/// the card wide, and it was the loudest thing on a page that is supposed to
/// feel energising. It is the accent now, so the beam reads as money in versus
/// money out and the app contains no black graphics at all.
class _DebtBlock extends StatelessWidget {
  const _DebtBlock();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: skin.card,
        borderRadius: BorderRadius.circular(skin.radius),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Owed to you',
                      style: ts(12.5, FontWeight.w400, skin.text3),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '₱3,500',
                      style: ts(21, FontWeight.w600, skin.good, ls: -0.5),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('You owe', style: ts(12.5, FontWeight.w400, skin.text3)),
                  const SizedBox(height: 5),
                  Text(
                    '₱12,000',
                    style: ts(21, FontWeight.w600, skin.text, ls: -0.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 5,
              child: Row(
                children: [
                  Expanded(flex: 22, child: Container(color: skin.good)),
                  const SizedBox(width: 3),
                  Expanded(flex: 78, child: Container(color: skin.accent)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Home Credit, next Sep 18',
                  style: ts(13, FontWeight.w400, skin.text3),
                ),
              ),
              Text('₱2,000', style: ts(14, FontWeight.w600, skin.text)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar();
  @override
  Widget build(BuildContext context) {
    const tabs = [
      ('Home', Icons.home_outlined, true),
      ('Ledger', Icons.article_outlined, false),
      ('Plan', Icons.donut_small_outlined, false),
      ('Accounts', Icons.account_balance_wallet_outlined, false),
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
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
          child: Row(
            children: [
              for (final (label, icon, on) in tabs)
                Expanded(
                  child: Column(
                    children: [
                      Icon(icon, size: 23, color: on ? skin.text : skin.text3),
                      const SizedBox(height: 5),
                      Text(
                        label,
                        style: ts(
                          10.5,
                          FontWeight.w500,
                          on ? skin.text : skin.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 10),
              // A labelled pill, not a round FAB. The round accent circle in
              // a tab bar is a named signature of the apps this must not read
              // as, and it was the one borrowed shape left on the screen.
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
