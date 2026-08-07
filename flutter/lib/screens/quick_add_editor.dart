// The quick add editor: the sheet that lets someone make the one tap buttons
// their own.
//
// It opens from the QUICK ADD card on Budget rather than from a settings
// screen, which is where the RN app keeps it. The reason is where the thought
// happens: nobody decides "my presets are wrong" while browsing Preferences,
// they decide it while looking at a chip that says Coffee ₱120 when their
// coffee is ₱65.
//
// Opening it writes NOTHING. The two WRITE paths record that the presets have
// been edited, which is what makes deleting the last button work: before this
// existed, an empty stored list could only mean "never set", so the card fell
// back to the four defaults, and deleting all four would make four different
// ones reappear.
//
// This paragraph said the opposite one commit ago, and it was true then. The
// seed moved because doing it on OPEN flipped hasData true on an empty app and
// deleted Menu's import prompt. A comment describing what the code does is a
// claim with an expiry date; this one is dated on purpose.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/quick_adds.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/entry_form.dart' show AmountField;
import '../widgets/salapify_icon.dart';
import 'overview.dart' show formatMoney;

Future<void> showQuickAddEditor(BuildContext context, SalapifyStore store) {
  // Opening writes NOTHING. The first version seeded the defaults here so a
  // later delete could not be undone by the card's fallback, and that turned
  // out to flip hasData true on an empty app: Menu's BRING YOUR DATA OVER
  // card, the only in-app route to import from the old app, was replaced by a
  // backup card just for looking at this sheet. The write paths carry the flag
  // instead, which cannot do that because by then there really is data.
  final media = MediaQuery.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // Safe area and a height cap, the categories.dart pattern. Without them a
    // person with a dozen presets got a sheet running the full screen: the
    // grab handle sat under the status bar and the Add and Done buttons were
    // below the fold with no visible way out.
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: (media.size.height - media.viewInsets.bottom) * 0.9,
    ),
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

  // Both writes are wrapped, the categories.dart pattern. Without the catch a
  // store that refuses to write (disk full, canWrite false) never reached the
  // line that clears _busy: the Add button stuck on "Saving...", every remove
  // went dead, no message appeared anywhere, and the exception escaped
  // unhandled because nothing awaits an onPressed future. The sheet was dead
  // until it was closed and reopened, and the person was told nothing.
  Future<void> _add() async {
    if (_busy) return;
    setState(() => _busy = true);
    String? refusal;
    try {
      refusal = await widget.store.addQuickAddPreset(_label.text, _amount.text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save, nothing was changed. $e';
        });
      }
      return;
    }
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
    try {
      await widget.store.removeQuickAddPreset(index);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save, nothing was changed. $e';
        });
      }
      return;
    }
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
                Text('Quick add buttons', style: AppText.title),
                const SizedBox(height: 4),
                Text(
                  'One tap logs the amount. Make them the things you actually '
                  'buy, at the prices you actually pay.',
                  style: AppText.small.tint(Barako.muted),
                ),
                const SizedBox(height: 16),
                if (adds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No buttons right now. Add one below, or leave it empty '
                      'and just use Log.',
                      style: AppText.small.tint(Barako.faint),
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
                        decoration: const InputDecoration(
                          hintText: 'Name, like Jeep',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      // The shared money entry field, so typing a preset's
                      // amount looks like typing any other amount in the app.
                      child: AmountField(controller: _amount),
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
                      style: AppText.small.tint(Barako.warning),
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
                      child: Text(
                        'Done',
                        style: TextStyle(color: Barako.muted),
                      ),
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

  Widget _row(QuickAdd q, int index) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            q.label,
            style: AppText.body,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          formatMoney(q.amount),
          style: AppText.amountRow.w4.tint(Barako.textSecondary),
        ),
        IconButton(
          onPressed: _busy ? null : () => _remove(index),
          icon: Icon(salapifyIcon('close'), size: 18),
          color: Barako.faint,
          // Named for the button it removes, so a screen reader user is never
          // choosing between four identical "Remove" controls.
          tooltip: 'Remove ${q.label}',
        ),
      ],
    ),
  );
}
