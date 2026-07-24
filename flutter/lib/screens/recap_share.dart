// The monthly recap share card. Turns the month into a branded card the user
// can post or send, with a privacy toggle that hides peso amounts. The card is
// a normal widget tree captured to a PNG via RepaintBoundary (no Skia needed),
// so the whole feature ships over the air. The numbers come from the
// golden-locked monthRecap/recapText engine, so the card can never disagree
// with the app.
//
// The capture source is a fixed 330-wide card rendered off-screen, NOT the
// scaled on-screen preview, so the exported image is the same size and
// proportion on every phone (a narrow phone would otherwise clamp the card
// below 330 and shrink the PNG). Defensive by design: if the image capture
// ever fails, the user still has Share as text, which cannot fail. The cached
// PNG is deleted after the share sheet closes, the same hygiene as backups.
// Ported from the RN RecapShare.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../money/cycle.dart' show cycleRecap, cycleRecapText;
import '../money/debtmath.dart' show formatMoneyText;
import '../money/pan_mood.dart';
import '../money/recap.dart';
import '../theme.dart';
import '../widgets/pan_mascot.dart' show PanCupPainter, PanPalette;

// Barako, baked into the shared image on purpose: the card is brand marketing
// wherever it lands, whatever theme the sender uses in the app.
const Color _bg = Color(0xFF1A130E);
const Color _border = Color(0xFF3A2A20);
const Color _orange = Color(0xFFFF8A3D);
const Color _cream = Color(0xFFFBF3E9);
const Color _muted = Color(0xFFA99182);

// Card size in logical units; the snapshot comes out at device pixels.
const double _cardW = 330;

// Pan on the card, in the same baked brand colors as the card itself, never
// the live theme (the painter would otherwise inherit whatever palette the
// sender runs, breaking the card's one-brand rule).
const PanPalette _panBrand = PanPalette(
  cup: _orange,
  face: _bg,
  calm: _muted,
  nudge: _muted,
  worried: _cream,
  happy: _cream,
);

class RecapShareScreen extends StatefulWidget {
  final SalapifyStore store;
  const RecapShareScreen({super.key, required this.store});

  @override
  State<RecapShareScreen> createState() => _RecapShareScreenState();
}

class _RecapShareScreenState extends State<RecapShareScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _hideAmounts = false;
  bool _busy = false;

  // Computed once, so the clock is read a single time: the captured image, the
  // filename, and the text fallback can never describe two different windows
  // if the user crosses midnight with the screen open. Both windows come from
  // that same instant; the toggle only picks which one renders.
  late final DateTime _openedAt = DateTime.now();
  late final Map<String, dynamic> _month = monthRecap(
    widget.store.data,
    _openedAt,
  );
  late final Map<String, dynamic> _cycle = cycleRecap(
    widget.store.data,
    _openedAt,
  );
  bool _isCycle = false;
  Map<String, dynamic> get _recap => _isCycle ? _cycle : _month;

  String _money(num n) => _hideAmounts ? '***' : formatMoneyText(n);

  Future<Uint8List?> _capture() async {
    final ctx = _cardKey.currentContext;
    if (ctx == null) return null;
    final obj = ctx.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    // A higher pixel ratio makes the shared PNG crisp on any feed.
    final image = await obj.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _shareText() async {
    try {
      // Each window has its own text builder so a cycle share never says
      // "this month" about a cycle percentage.
      await Share.share(
        _isCycle
            ? cycleRecapText(_recap, formatMoneyText, _hideAmounts)
            : recapText(_recap, formatMoneyText, _hideAmounts),
      );
    } catch (_) {
      // The user closing the sheet is not an error worth surfacing.
    }
  }

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Snapshot the window at press time (the chips are also disabled while
    // busy): the filename, sheet text, and fallback must describe the same
    // card the capture caught, not whatever the toggle says later.
    final recap = _recap;
    final isCycle = _isCycle;
    File? file;
    try {
      final bytes = await _capture();
      if (bytes == null) throw StateError('no snapshot');
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/salapify-recap-${recap['monthKey']}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: isCycle
            ? 'My payday cycle with Salapify'
            : 'My month with Salapify',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Could not build the image. Sharing as text instead.',
              ),
            ),
          );
      }
      await _shareText();
    } finally {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _RecapCard(
      recap: _recap,
      hideAmounts: _hideAmounts,
      money: _money,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          _isCycle ? 'Payday cycle recap' : '${_recap['label']} recap',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Turn ${_isCycle ? 'this payday cycle' : _recap['label']} '
                  'into a card you can post or send. You choose if peso '
                  'amounts show.',
                  style: TextStyle(
                    color: Barako.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                // The window toggle: the calendar month, or your own sweldo
                // cycle (payday to payday), because the month is not the unit
                // your money actually lives in.
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(
                        'This month',
                        style: TextStyle(
                          color: _isCycle ? Barako.text : Barako.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: !_isCycle,
                      // Disabled mid-capture so the PNG, filename, and text
                      // can never describe different windows.
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _isCycle = false),
                      selectedColor: Barako.primary,
                      backgroundColor: Barako.card,
                      side: BorderSide(color: Barako.border),
                      showCheckmark: false,
                    ),
                    ChoiceChip(
                      label: Text(
                        'Payday cycle',
                        style: TextStyle(
                          color: _isCycle ? Barako.onPrimary : Barako.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: _isCycle,
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _isCycle = true),
                      selectedColor: Barako.primary,
                      backgroundColor: Barako.card,
                      side: BorderSide(color: Barako.border),
                      showCheckmark: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Preview scales down to fit a narrow phone without distorting;
                // the capture happens off-screen at the true 330 (below).
                Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: card),
                ),
                const SizedBox(height: 20),
                _toggle(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _shareImage,
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      disabledBackgroundColor: Barako.primary.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text(
                      _busy ? 'Preparing...' : 'Share the card',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _shareText,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Barako.textSecondary,
                      side: BorderSide(color: Barako.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Share as text',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // The capture source: a genuinely fixed 330-wide card, always laid
          // out (never culled by the scroll) and off-screen so it is invisible.
          // toImage still snapshots it. This keeps every exported PNG identical
          // in size and proportion across devices.
          Positioned(
            left: -_cardW * 4,
            top: 0,
            child: RepaintBoundary(key: _cardKey, child: card),
          ),
        ],
      ),
    );
  }

  Widget _toggle() => Container(
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Barako.border),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hide peso amounts',
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Show percentages only, keep numbers private.',
                style: TextStyle(color: Barako.faint, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: _hideAmounts,
          onChanged: (v) => setState(() => _hideAmounts = v),
          activeThumbColor: Barako.onPrimary,
          activeTrackColor: Barako.primary,
          inactiveThumbColor: Barako.faint,
          inactiveTrackColor: Barako.border,
        ),
      ],
    ),
  );
}

// The branded card, fixed at 330 wide so the captured PNG is consistent. Uses
// hardcoded Barako-dark brand colors, never live theme getters: the image is
// the same marketing whatever theme the sender runs.
class _RecapCard extends StatelessWidget {
  final Map<String, dynamic> recap;
  final bool hideAmounts;
  final String Function(num) money;
  const _RecapCard({
    required this.recap,
    required this.hideAmounts,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final keptRate = recap['keptRate'];
    final kept = (recap['kept'] as num?)?.toDouble() ?? 0;
    final daysLogged = recap['daysLogged'] as int? ?? 0;
    final pct = keptRate is num ? ((keptRate * 100) + 0.5).floor() : null;

    // Pan wears the month's honest mood: happy on a kept month, worried on an
    // over month, calm when there is no verdict yet (days-logged only). The
    // over month stays sympathetic, never shameful; worried is Pan's ceiling.
    final mood = pct == null
        ? PanMood.calm
        : kept >= 0
        ? PanMood.happy
        : PanMood.worried;

    // Which window the percent belongs to: the cycle map names its noun, the
    // month map has none and falls back, so a cycle card can never claim
    // "this month" about a cycle figure in the shared image.
    final noun = (recap['windowNoun'] as String?) ?? 'month';
    final big = pct == null
        ? '$daysLogged ${daysLogged == 1 ? 'day' : 'days'} logged'
        : kept >= 0
        ? (hideAmounts ? 'Kept ${pct < 0 ? 0 : pct}%' : '${money(kept)} kept')
        : (hideAmounts ? 'Over this $noun' : '${money(-kept)} over');
    final sub = pct == null
        ? 'Every logged day builds the habit.'
        : kept >= 0
        ? (hideAmounts
              ? 'of my income this $noun'
              : '${pct < 0 ? 0 : pct}% of income kept')
        : 'spending passed income';

    final moneyIn = (recap['moneyIn'] as num?)?.toDouble() ?? 0;
    final moneyOut = (recap['moneyOut'] as num?)?.toDouble() ?? 0;
    final utangCollected = (recap['utangCollected'] as num?)?.toDouble() ?? 0;
    final debtPaid = (recap['debtPaid'] as num?)?.toDouble() ?? 0;
    final topCats = recap['topCats'] as List? ?? const [];

    final rows = <List<String>>[];
    if (moneyIn > 0) rows.add(['Money in', money(moneyIn)]);
    if (moneyOut > 0) rows.add(['Money out', money(moneyOut)]);
    if (topCats.isNotEmpty) {
      final t = topCats.first as Map;
      rows.add([
        'Top spending',
        '${_fit(t['label'], 13)} ${(t['pct'] as num).toInt()}%',
      ]);
    }
    if (utangCollected > 0) {
      rows.add(['Utang collected', money(utangCollected)]);
    }
    if (debtPaid > 0) rows.add(['Debt paid down', money(debtPaid)]);
    rows.add(['Days logged', '$daysLogged']);

    return Container(
      width: _cardW,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // The cycle recap supplies its own kicker ('MY CYCLE SINCE
                // JUL 5'); the month falls back to the derived form.
                child: Text(
                  (recap['kicker'] as String?) ??
                      'MY ${recap['label'].toString().toUpperCase()}',
                  style: const TextStyle(
                    fontFamily: 'Jakarta',
                    color: _orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              // Pan wearing the month's mood, painted in pure Dart so the mark
              // is identical on every device (a system emoji would render
              // differently per phone). Static (wisp settled), brand palette.
              Semantics(
                label:
                    'Pan looking ${mood == PanMood.happy
                        ? 'happy'
                        : mood == PanMood.worried
                        ? 'worried'
                        : 'calm'}',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(
                    painter: PanCupPainter(
                      mood: mood,
                      wisp: 1,
                      palette: _panBrand,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            big,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Fraunces',
              color: _cream,
              fontSize: big.length > 13 ? 24 : 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(
              fontFamily: 'Jakarta',
              color: _muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _border),
          const SizedBox(height: 14),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      r[0],
                      style: const TextStyle(
                        fontFamily: 'Jakarta',
                        color: _muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      r[1],
                      style: const TextStyle(
                        fontFamily: 'Jakarta',
                        color: _cream,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            recap['verdict'].toString(),
            style: const TextStyle(
              fontFamily: 'Jakarta',
              color: _cream,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Salapify, on your money's side",
            style: TextStyle(
              fontFamily: 'Jakarta',
              color: _orange,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // Truncate free user text (category labels) so a long name cannot run past
  // the card edge in the shared image.
  static String _fit(dynamic text, int max) {
    final s = text?.toString() ?? '';
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1).trimRight()}…';
  }
}
