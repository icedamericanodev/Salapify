// The quick add editor: the sheet that lets someone make the one tap buttons
// their own.
//
// It opens from the QUICK ADD card on Budget rather than from a settings
// screen, which is where the RN app keeps it. The reason is where the thought
// happens: nobody decides "my presets are wrong" while browsing Preferences,
// they decide it while looking at a chip that says Coffee ₱120 when their
// coffee is ₱65.
//
// Opening it SEEDS the current defaults into storage. That is what makes
// deleting the last button work: before this existed, an empty stored list
// could only mean "never set", so the card fell back to the four defaults.
// Without the seed, deleting all four would make four different ones reappear,
// which reads as the app refusing to be changed.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/quick_adds.dart';
import '../theme.dart';
import 'overview.dart' show formatMoney;
import '../money/currencies.dart' show baseCurrencySymbol;

Future<void> showQuickAddEditor(BuildContext context, SalapifyStore store) async {
  // Seeded BEFORE the sheet builds, so the list it shows is the list that is
  // stored and a delete cannot be undone by a fallback.
  await store.seedQuickAdds();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Barako.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: QuickAddEditor(store: store),
    ),
  );
}

class QuickAddEditor extends StatefulWidget {
  final SalapifyStore store;
  const QuickAddEditor({super.key, required this.store});

  @override
  State<QuickAddEditor> createState() => _QuickAddEditorState();
}

class _QuickAddEditorState extends State<QuickAddEditor> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    final refusal = await widget.store.addQuickAddPreset(
      _label.text,
      _amount.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = refusal;
      if (refusal == null) {
        _label.clear();
        _amount.clear();
      }
    });
  }

  Future<void> _remove(int index) async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.store.removeQuickAddPreset(index);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final adds = widget.store.quickAdds;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Barako.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quick add buttons',
                  style: TextStyle(
                    color: Barako.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'One tap logs the amount. Make them the things you actually '
                  'buy, at the prices you actually pay.',
                  style: TextStyle(color: Barako.muted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (adds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No buttons right now. Add one below, or leave it empty '
                      'and just use Log.',
                      style: TextStyle(color: Barako.faint, fontSize: 13),
                    ),
                  )
                else
                  for (var i = 0; i < adds.length; i++) _row(adds[i], i),
                const SizedBox(height: 16),
                Text('ADD A BUTTON', style: Barako.kickerStyle),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _label,
                        style: TextStyle(color: Barako.text),
                        decoration: _field('Name, like Jeep'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(color: Barako.text),
                        decoration: _field('0').copyWith(
                          prefixText: '$baseCurrencySymbol ',
                          prefixStyle: TextStyle(color: Barako.muted),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  // A live region, so a screen reader announces the refusal
                  // instead of leaving the person tapping Add again.
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(color: Barako.warning, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Barako.primary,
                          foregroundColor: Barako.onPrimary,
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: _busy ? null : _add,
                        child: Text(
                          _busy ? 'Saving...' : 'Add button',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text('Done', style: TextStyle(color: Barako.muted)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _field(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Barako.faint, fontSize: 14),
    filled: true,
    fillColor: Barako.card,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Barako.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Barako.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Barako.primary),
    ),
  );

  Widget _row(QuickAdd q, int index) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            q.label,
            style: TextStyle(color: Barako.text, fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          formatMoney(q.amount),
          style: TextStyle(
            color: Barako.textSecondary,
            fontSize: 15,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        IconButton(
          onPressed: _busy ? null : () => _remove(index),
          icon: const Icon(Icons.close, size: 18),
          color: Barako.faint,
          // Named for the button it removes, so a screen reader user is never
          // choosing between four identical "Remove" controls.
          tooltip: 'Remove ${q.label}',
        ),
      ],
    ),
  );
}
