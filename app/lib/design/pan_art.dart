import 'package:flutter/material.dart';

/// Pan, Salapify's character (D30, founder direction 2026-10-08).
///
/// Every screen draws him through [PanArt], so new art is a folder swap: when
/// hi-res files arrive they replace `assets/pan/` under the SAME names and no
/// code changes. Brief: docs/revamp/pan-handoff.md.
///
/// Pick the mood by what the screen SAYS, not by what looks cute. If none
/// fits, keep the icon.
enum PanMood {
  /// A hello. Home on a first run.
  wave,

  /// Nothing due, nothing owed. An "all clear".
  calm,

  /// An empty list with nothing logged yet.
  sleep,

  /// A Plan empty state that suggests a first step.
  idea,

  /// Reports before there is enough to show.
  thinking,

  /// Accounts, money coming in.
  coin,

  /// Asking permission. Later phases.
  shy,

  /// A quick confirmation. Later phases.
  wink,

  /// Big moments, later phases, after hi-res art.
  celebrate,
  stars,
  savings,
  love,

  /// Heads-ups and failures, later phases.
  surprised,
  nervous,
  confused,
  sad,

  /// NOT USED. Pan never judges spending. These three exist only because the
  /// art does, and `pan_art_test.dart` fails if anything in lib/ reaches
  /// them. Tear may return for the wipe-all-data confirmation, and only by a
  /// founder decision.
  annoyed,
  tear,
  crying,
}

/// The asset each mood is drawn from. One rule, so a test can check every
/// mood has a file.
String panAsset(PanMood mood) => 'assets/pan/pan_${mood.name}.png';

/// The largest Pan the current 256 x 256 art stays sharp at on a 3x phone.
/// Above it he goes soft, so callers are clamped to it until hi-res art lands.
const double panMaxSize = 96;

/// The gap under Pan on an empty state, in place of the icon's own gap. Ten
/// rather than the usual sixteen, because the art carries its own air.
const double panGap = 10;

/// Pan in one [mood], [size] logical pixels square.
///
/// Decorative to a screen reader: wherever he appears, the text beside him
/// already says what matters, and "image, Pan waving" would only be noise
/// read before it.
class PanArt extends StatelessWidget {
  const PanArt({super.key, required this.mood, this.size = panMaxSize});

  final PanMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double side = size.clamp(0, panMaxSize).toDouble();
    return Image.asset(
      panAsset(mood),
      width: side,
      height: side,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}
