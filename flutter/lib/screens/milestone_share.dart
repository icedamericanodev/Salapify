// Share a win: milestone cards for the moments people already screenshot, a
// debt paid to zero, a goal fully funded, an utang settled either way. Same
// proven pipeline as the monthly recap card: a fixed 330-wide branded card
// captured via RepaintBoundary off-screen, share-as-text fallback that cannot
// fail, temp PNG deleted after the sheet closes. Every win and every amount
// comes from the tested milestone engine; the widget invents nothing.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/store.dart';
import '../money/debtmath.dart' show formatMoneyText;
import '../money/milestones.dart';
import '../money/pan_mood.dart';
import '../theme.dart';
import '../widgets/pan_mascot.dart' show PanCupPainter, PanPalette;

// The same baked Barako brand colors as the recap card: the image is brand
// marketing wherever it lands, whatever theme the sender runs.
const Color _bg = Color(0xFF1A130E);
const Color _border = Color(0xFF3A2A20);
const Color _orange = Color(0xFFFF8A3D);
const Color _cream = Color(0xFFFBF3E9);
const Color _muted = Color(0xFFA99182);

const double _cardW = 330;

const PanPalette _panBrand = PanPalette(
  cup: _orange,
  face: _bg,
  calm: _muted,
  nudge: _muted,
  worried: _cream,
  happy: _cream,
);

class MilestoneShareScreen extends StatefulWidget {
  final SalapifyStore store;
  const MilestoneShareScreen({super.key, required this.store});

  @override
  State<MilestoneShareScreen> createState() => _MilestoneShareScreenState();
}

class _MilestoneShareScreenState extends State<MilestoneShareScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _hideAmounts = false;
  bool _busy = false;
  int _selected = 0;

  // Computed once on open, like the recap: the list cannot shift under the
  // user mid-share.
  late final List<Milestone> _wins = milestones(widget.store.data);

  @override
  Widget build(BuildContext context) {
    final win = _wins.isEmpty
        ? null
        : _wins[_selected < _wins.length ? _selected : 0];
    final card = win == null
        ? null
        : _MilestoneCard(win: win, hideAmounts: _hideAmounts);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Share a win',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (win == null) ...[
                  Text(
                    'No wins to share yet, and that is okay. Pay a debt down '
                    'to zero, fund a savings goal, or settle an IOU either '
                    'way, and the card builds itself here.',
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Turn a real money win into a card you can post or send. '
                    'You choose if peso amounts show.',
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (_wins.length > 1) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _wins.length; i++)
                          ChoiceChip(
                            label: Text(
                              '${_wins[i].headline} · ${_wins[i].name}',
                              style: TextStyle(
                                color: i == _selected
                                    ? Barako.onPrimary
                                    : Barako.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selected: i == _selected,
                            onSelected: (_) => setState(() => _selected = i),
                            selectedColor: Barako.primary,
                            backgroundColor: Barako.card,
                            side: BorderSide(color: Barako.border),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: card),
                  ),
                  const SizedBox(height: 20),
                  _toggle(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : () => _shareImage(win),
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
                      onPressed: () => _shareText(win),
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
              ],
            ),
          ),
          // The off-screen fixed-size capture source, same trick as the recap.
          if (card != null)
            Positioned(
              left: -_cardW * 4,
              top: 0,
              child: RepaintBoundary(key: _cardKey, child: card),
            ),
        ],
      ),
    );
  }

  Future<Uint8List?> _capture() async {
    final ctx = _cardKey.currentContext;
    if (ctx == null) return null;
    final obj = ctx.findRenderObject();
    if (obj is! RenderRepaintBoundary) return null;
    final image = await obj.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  Future<void> _shareText(Milestone win) async {
    try {
      await Share.share(milestoneText(win, formatMoneyText, _hideAmounts));
    } catch (_) {
      // The user closing the sheet is not an error worth surfacing.
    }
  }

  Future<void> _shareImage(Milestone win) async {
    if (_busy) return;
    setState(() => _busy = true);
    File? file;
    try {
      final bytes = await _capture();
      if (bytes == null) throw StateError('no snapshot');
      final dir = await getTemporaryDirectory();
      file = File('${dir.path}/salapify-win-${win.kind}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'image/png'),
      ], text: 'A win worth sharing');
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
      await _shareText(win);
    } finally {
      try {
        if (file != null && await file.exists()) await file.delete();
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
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
                'Share the win, keep the numbers private.',
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

// The branded milestone card. Fixed 330 wide, baked Barako colors, Pan happy;
// a milestone card is by definition a good day.
class _MilestoneCard extends StatelessWidget {
  final Milestone win;
  final bool hideAmounts;
  const _MilestoneCard({required this.win, required this.hideAmounts});

  String get _closing => switch (win.kind) {
    'debt' => 'Every payment logged. That is how it gets done.',
    'goal' => 'Saved on purpose, not by luck.',
    'utangIn' => 'Tracked kindly, collected kindly.',
    _ => 'Paid back in full, friendship intact.',
  };

  @override
  Widget build(BuildContext context) {
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
              const Expanded(
                child: Text(
                  'MILESTONE',
                  style: TextStyle(
                    fontFamily: 'Jakarta',
                    color: _orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Semantics(
                label: 'Pan looking happy',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CustomPaint(
                    painter: PanCupPainter(
                      mood: PanMood.happy,
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
            win.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Fraunces',
              color: _cream,
              fontSize: win.headline.length > 13 ? 24 : 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            win.sub,
            style: const TextStyle(
              fontFamily: 'Jakarta',
              color: _muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (win.amount > 0 && !hideAmounts) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: _border),
            const SizedBox(height: 14),
            Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    win.amountLabel,
                    style: const TextStyle(
                      fontFamily: 'Jakarta',
                      color: _muted,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    formatMoneyText(win.amount),
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
          ],
          const SizedBox(height: 14),
          Text(
            _closing,
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
}
