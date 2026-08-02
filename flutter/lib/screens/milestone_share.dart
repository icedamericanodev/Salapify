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
import '../typography.dart';
import '../widgets/celebration.dart' show showCelebration;
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

// Capture a RepaintBoundary to PNG bytes, or null if it is not ready. Shared by
// the share screen and the celebration sheet so the capture recipe lives once.
Future<Uint8List?> _captureCard(GlobalKey key) async {
  final ctx = key.currentContext;
  if (ctx == null) return null;
  final obj = ctx.findRenderObject();
  if (obj is! RenderRepaintBoundary) return null;
  final image = await obj.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

// The text fallback that cannot fail; used by both surfaces.
Future<void> _shareCardText(Milestone win, bool hideAmounts) async {
  try {
    await Share.share(milestoneText(win, formatMoneyText, hideAmounts));
  } catch (_) {
    // The user closing the sheet is not an error worth surfacing.
  }
}

/// Capture the branded card at [key] and hand it to the OS share sheet, writing
/// a temp PNG that is deleted after. On any failure it falls back to sharing the
/// text, so a win is never un-shareable. Shared by the picker screen and the
/// live celebration sheet so the temp-file discipline lives in one place.
Future<void> _shareCardImage(
  BuildContext context,
  GlobalKey key,
  Milestone win,
  bool hideAmounts,
) async {
  File? file;
  try {
    final bytes = await _captureCard(key);
    if (bytes == null) throw StateError('no snapshot');
    final dir = await getTemporaryDirectory();
    file = File('${dir.path}/salapify-win-${win.kind}.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'image/png'),
    ], text: 'A win worth sharing');
  } catch (_) {
    if (context.mounted) {
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
    await _shareCardText(win, hideAmounts);
  } finally {
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// The live celebration moment: fire the confetti the app already shows for a
/// win, then offer the branded card to share right there, instead of leaving it
/// buried in the menu. [win] comes from the tested milestone engine
/// (milestoneFor), so this invents nothing. Non-blocking: dismissing shares
/// nothing, and a caller with no milestone for the id should just show its own
/// confetti instead of calling this.
Future<void> showMilestoneCelebration(
  BuildContext context,
  Milestone win,
) async {
  // The sheet is the moment: "You just made it" plus the card to keep and
  // share. The confetti fires AFTER it closes, over the screen the user returns
  // to, not at the same instant, where the modal's scrim would bury the burst
  // and its pill would just repeat the card headline. The sheet announces the
  // win to a screen reader on open, so accessibility does not wait for the
  // confetti.
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Barako.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CelebrationSheet(win: win),
  );
  if (context.mounted) showCelebration(context, win.headline);
}

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
  // Capped. milestones() returns EVERY settled utang, funded goal and cleared
  // debt with no limit, a realistic few hundred for a heavy utang user, and
  // the picker became a wall of chips to scroll past before reaching the card.
  //
  // Order is left exactly as milestones() returns it (debts, goals, then
  // utang). Sorting by recency would be better, but Milestone carries no date,
  // so that needs a change in the money layer and its goldens rather than a
  // reverse() here, which would only shuffle the categories.
  static const int _maxWins = 12;
  late final List<Milestone> _wins = milestones(
    widget.store.data,
  ).take(_maxWins).toList();

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
                    style: AppText.label.w4
                        .tint(Barako.textSecondary)
                        .copyWith(height: 1.45),
                  ),
                ] else ...[
                  Text(
                    'Turn a real money win into a card you can post or send. '
                    'You choose if peso amounts show.',
                    style: AppText.label.w4
                        .tint(Barako.textSecondary)
                        .copyWith(height: 1.45),
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
                              style: AppText.caption.w6.tint(
                                i == _selected ? Barako.onPrimary : Barako.text,
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

  // Both share actions delegate to the file-level helpers, so the capture and
  // temp-file recipe genuinely lives once (see _shareCardImage / _shareCardText
  // at the top of this file). The screen only adds its own busy state.
  Future<void> _shareText(Milestone win) => _shareCardText(win, _hideAmounts);

  Future<void> _shareImage(Milestone win) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _shareCardImage(context, _cardKey, win, _hideAmounts);
    } finally {
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
                style: AppText.body.w6,
              ),
              const SizedBox(height: 2),
              Text(
                'Share the win, keep the numbers private.',
                style: AppText.caption.tint(Barako.faint),
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

// The live celebration sheet: the branded card for the win the user just
// finished, with one tap to share it. Reuses the same card and share pipeline
// as the picker screen; it just shows ONE win, the one that just happened,
// with no chooser.
class _CelebrationSheet extends StatefulWidget {
  final Milestone win;
  const _CelebrationSheet({required this.win});

  @override
  State<_CelebrationSheet> createState() => _CelebrationSheetState();
}

class _CelebrationSheetState extends State<_CelebrationSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _hideAmounts = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Speak the win as the sheet opens, so a screen-reader user hears it now
    // rather than waiting for the confetti that fires after dismiss.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          '${widget.win.headline}. ${widget.win.sub}',
          TextDirection.ltr,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = _MilestoneCard(win: widget.win, hideAmounts: _hideAmounts);
    return SafeArea(
      child: Stack(
        children: [
          _body(card),
          // The capture source is a FULL-SIZE card off-screen, the picker's
          // trick, so the shared PNG is the same crisp 330-wide image on every
          // phone. Capturing the visible FittedBox instead would export a
          // smaller, lower-res card on a narrow phone.
          Positioned(
            left: -_cardW * 4,
            top: 0,
            child: RepaintBoundary(
              key: _cardKey,
              child: _MilestoneCard(win: widget.win, hideAmounts: _hideAmounts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Widget card) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'You just made it',
              textAlign: TextAlign.center,
              style: AppText.title.copyWith(fontSize: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Turn this into a card you can post or send. You choose if peso '
            'amounts show.',
            textAlign: TextAlign.center,
            style: AppText.small.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          // Shown scaled to fit the sheet width; the crisp full-size copy that
          // actually shares is the off-screen RepaintBoundary in build().
          Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: card),
          ),
          const SizedBox(height: 16),
          _HideAmountsToggle(
            value: _hideAmounts,
            onChanged: (v) => setState(() => _hideAmounts = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _share,
            style: FilledButton.styleFrom(
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
              disabledBackgroundColor: Barako.primary.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: Text(
              _busy ? 'Preparing...' : 'Share the card',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _shareCardText(widget.win, _hideAmounts),
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
          const SizedBox(height: 4),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
            child: Text('Maybe later', style: TextStyle(color: Barako.muted)),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _shareCardImage(context, _cardKey, widget.win, _hideAmounts);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// The hide-amounts toggle, shared shape as the picker screen's.
class _HideAmountsToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _HideAmountsToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Barako.background,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Barako.border),
    ),
    clipBehavior: Clip.antiAlias,
    // The whole row toggles, not just the 48dp switch, and it reads as one
    // control to a screen reader.
    child: MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hide peso amounts',
                      style: AppText.body.w6,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Share the win, keep the numbers private.',
                      style: AppText.caption.tint(Barako.faint),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Barako.onPrimary,
                activeTrackColor: Barako.primary,
                inactiveThumbColor: Barako.faint,
                inactiveTrackColor: Barako.border,
              ),
            ],
          ),
        ),
      ),
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
                    fontFamily: Barako.bodyFont,
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
              fontFamily: Barako.displayFont,
              color: _cream,
              fontSize: win.headline.length > 13 ? 24 : 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            win.sub,
            style: const TextStyle(
              fontFamily: Barako.bodyFont,
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
                      fontFamily: Barako.bodyFont,
                      color: _muted,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    formatMoneyText(win.amount),
                    style: const TextStyle(
                      fontFamily: Barako.bodyFont,
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
              fontFamily: Barako.bodyFont,
              color: _cream,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Salapify, on your money's side",
            style: TextStyle(
              fontFamily: Barako.bodyFont,
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
