// The Card Skin Studio: pick a finish for one account's card and see it live.
//
// It is a thin, safe surface. It renders the card the CALLER already draws
// (handed in as [previewBuilder]) so it never re-derives an account's brand,
// type or number, and swapping a skin just re-seeds that same card. The choice
// is stored per account in CardSkinStore, which is a local device preference and
// NOT part of the backup (see services/card_skins.dart), so nothing here touches
// money, storage or the golden locked engine. Every colour is a Barako getter,
// so the sheet follows all sixteen palettes and both brightnesses.

import 'package:flutter/material.dart';

import '../services/card_skins.dart';
import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

/// Open the studio for [accountId]. [previewBuilder] returns the card to show,
/// re-seeded with the skin colour passed to it (null means the card's own brand
/// colour). Applies each pick immediately and persists it.
Future<void> showCardSkinStudio(
  BuildContext context, {
  required String accountId,
  required Widget Function(Color? skinSeed) previewBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _CardSkinStudio(accountId: accountId, previewBuilder: previewBuilder),
  );
}

class _CardSkinStudio extends StatefulWidget {
  final String accountId;
  final Widget Function(Color? skinSeed) previewBuilder;

  const _CardSkinStudio({
    required this.accountId,
    required this.previewBuilder,
  });

  @override
  State<_CardSkinStudio> createState() => _CardSkinStudioState();
}

class _CardSkinStudioState extends State<_CardSkinStudio> {
  late String? _selectedId = CardSkinStore.instance.skinIdFor(widget.accountId);

  Future<void> _apply(String? id) async {
    setState(() => _selectedId = id);
    Haptics.select();
    await CardSkinStore.instance.setSkin(widget.accountId, id);
  }

  @override
  Widget build(BuildContext context) {
    final seed = skinById(_selectedId)?.seed;
    return SafeArea(
      // Scrolls so a large system font or a short viewport cannot overflow the
      // fixed sheet height, the same guard the account action sheet uses.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Barako.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SalapifyGlyph('appearance', size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Card skin studio', style: AppText.subtitle),
                ),
                IconButton(
                  icon: Icon(salapifyIcon('close'), color: Barako.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'A finish is only how the card looks on this phone. It does not '
              'change your balance or your card.',
              style: AppText.caption,
            ),
            const SizedBox(height: 16),
            // The live preview: the caller's own card, re-seeded.
            widget.previewBuilder(seed),
            const SizedBox(height: 20),
            Text('FINISH', style: Barako.kickerStyle),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _swatch(
                  id: null,
                  label: 'Default',
                  color: Barako.surfaceRaised,
                  showBorder: true,
                ),
                for (final skin in cardSkins)
                  _swatch(id: skin.id, label: skin.label, color: skin.seed),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch({
    required String? id,
    required String label,
    required Color color,
    bool showBorder = false,
  }) {
    final selected = _selectedId == id;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label card finish',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _apply(id),
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Barako.primary : Barako.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: showBorder ? Border.all(color: Barako.border) : null,
                ),
                child: selected
                    ? Icon(
                        salapifyIcon('check'),
                        size: 18,
                        // White reads on the dark metal seeds and on the raised
                        // default swatch alike; the tick is a selection cue, not
                        // body text held to AA.
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.tint(
                  selected ? Barako.text : Barako.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
