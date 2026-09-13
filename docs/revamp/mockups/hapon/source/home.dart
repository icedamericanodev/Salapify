// Home. APPROVED AND LOCKED by the founder on 2026-09-13 ("i think thats good
// to go"), so the three devices on this screen are D12 material now: the light
// hero panel with dark ink, the sweldo rail inside it, and the debt beam.
// Changing any of them takes a founder decision, not a good argument.
import 'package:flutter/material.dart';
import 'kit.dart';
import 'skin.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Screen(
      tab: 0,
      children: [
        const TopBar(),
        const SizedBox(height: 22),
        const Hero_(),
        const SizedBox(height: 30),
        const QuickActions(),
        const SizedBox(height: 34),
        const Head(title: 'Debt, both ways', action: 'See all'),
        const SizedBox(height: 14),
        const DebtBeam(),
        const SizedBox(height: 34),
        const Head(title: 'Coming up', action: 'See all'),
        const SizedBox(height: 6),
        const Group(
          children: [
            Row_(
              icon: Icons.bolt_outlined,
              title: 'Meralco',
              sub: 'Today',
              amount: '₱2,340',
            ),
            Row_(
              icon: Icons.music_note_outlined,
              title: 'Spotify',
              sub: 'Sun, Sep 14',
              amount: '₱149',
            ),
            Row_(
              icon: Icons.savings_outlined,
              title: 'Payday',
              sub: 'Mon, Sep 15',
              amount: '+₱21,000',
              tone: Tone.good,
            ),
          ],
        ),
        const SizedBox(height: 34),
        const Head(title: 'Latest', action: 'See all'),
        const SizedBox(height: 6),
        Group(children: latest()),
      ],
    );
  }
}

/// Three rows is a brochure. [dense] is the real daily state.
List<Widget> latest() {
  const short = <Row_>[
    Row_(
      icon: Icons.lunch_dining_outlined,
      title: 'Jollibee',
      sub: 'Food · GCash',
      amount: '₱250',
    ),
    Row_(
      icon: Icons.directions_bus_outlined,
      title: 'Grab',
      sub: 'Transport · Maya',
      amount: '₱180',
    ),
    Row_(
      icon: Icons.south_west_rounded,
      title: 'Kuya Jun paid back',
      sub: 'Debt · Cash',
      amount: '+₱1,000',
      tone: Tone.good,
    ),
  ];
  if (!dense) return short;
  const more = <Row_>[
    Row_(
      icon: Icons.local_cafe_outlined,
      title: 'Kopiko Blanca',
      sub: 'Food · Cash',
      amount: '₱75',
    ),
    Row_(
      icon: Icons.shopping_bag_outlined,
      title: 'Puregold',
      sub: 'Groceries · BPI',
      amount: '₱2,847',
    ),
    Row_(
      icon: Icons.local_gas_station_outlined,
      title: 'Shell Katipunan',
      sub: 'Transport · GCash',
      amount: '₱1,200',
    ),
    Row_(
      icon: Icons.wifi_outlined,
      title: 'Converge',
      sub: 'Bills · Maya',
      amount: '₱1,699',
    ),
    Row_(
      icon: Icons.north_east_rounded,
      title: 'Lent to Ate Bing',
      sub: 'Debt · Cash',
      amount: '₱1,500',
    ),
    Row_(
      icon: Icons.medication_outlined,
      title: 'Mercury Drug',
      sub: 'Health · Cash',
      amount: '₱430',
    ),
    Row_(
      icon: Icons.directions_bus_outlined,
      title: 'Angkas',
      sub: 'Transport · GCash',
      amount: '₱165',
    ),
    Row_(
      icon: Icons.lunch_dining_outlined,
      title: 'Mang Inasal',
      sub: 'Food · Cash',
      amount: '₱219',
    ),
    Row_(
      icon: Icons.swap_horiz_rounded,
      title: 'GCash to BPI',
      sub: 'Move · not a spend',
      amount: '₱5,000',
    ),
    Row_(
      icon: Icons.school_outlined,
      title: 'Tuition, 3 of 10',
      sub: 'Bills · BPI',
      amount: '₱6,250',
    ),
    Row_(
      icon: Icons.south_west_rounded,
      title: 'Refund, Lazada',
      sub: 'Shopping · GCash',
      amount: '+₱899',
      tone: Tone.good,
    ),
  ];
  return [...short, ...more];
}

/// Signature device one. A LIGHT panel carrying DARK ink. Every fintech hero
/// on the reference board is the other way round, a dark panel with white ink,
/// so this is the thing that makes a cropped screenshot ours.
class Hero_ extends StatelessWidget {
  const Hero_({
    super.key,
    this.kicker = 'SAFE TO SPEND',
    this.whole = '6,240',
    this.cents = '.00',
    this.sentence = '₱1,560 a day until payday on Monday.',
    this.rail = true,
  });
  final String kicker, whole, cents, sentence;
  final bool rail;

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
          Text(kicker, style: ts(11.5, FontWeight.w700, quiet, ls: 1.4)),
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
              // is 8.6 percent of a 412 pt screen. The money apps on the
              // reference board sit at 7.6 to 8.8 percent. The old 54 pt came
              // out at 9.83 percent and read as a poster.
              Text(
                whole,
                style: ts(47, FontWeight.w700, ink, h: 1.0, ls: -1.7),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(cents, style: ts(20, FontWeight.w500, quiet)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(sentence, style: ts(14.5, FontWeight.w400, quiet)),
          if (rail) ...[
            const SizedBox(height: 20),
            // Signature device two, the sweldo rail. The filled part is the
            // quiet ink, not solid onHero: 5.42 to 1 at the panel's darkest,
            // past the 3.0 a meaningful non text element needs, and 3.74
            // against its own track.
            ThinBar(
              fraction: 0.786,
              fill: quiet,
              track: skin.onHero.withValues(alpha: 0.20),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '4 days to payday',
                  style: ts(12.5, FontWeight.w500, quiet),
                ),
                Text('Sep 1 to 15', style: ts(12.5, FontWeight.w500, quiet)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Four things a person actually does. Four is the ceiling, one row, never a
/// grid. That is the GCash convention with the GCash mistake removed.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});
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

/// Signature device three, the debt beam. Both directions in one object: the
/// two amounts sit above their own ends of a single split bar.
///
/// The owe half used to be solid [Skin.text], a pure black slab 78 percent of
/// the card wide, and it was the loudest thing on a page that is supposed to
/// feel energising. It is the accent now, so the beam reads as money in versus
/// money out and the app contains no black graphics at all.
class DebtBeam extends StatelessWidget {
  const DebtBeam({super.key, this.footer = true});
  final bool footer;

  @override
  Widget build(BuildContext context) {
    return Panel(
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
          if (footer) ...[
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
        ],
      ),
    );
  }
}
