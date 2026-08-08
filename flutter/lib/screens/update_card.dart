// The update card: the stamp row plus a one-tap update check, the same
// habit the RN app taught the founder. Shorebird patches normally download
// quietly on open and apply on the NEXT start; this button removes the
// waiting: check, download now, then close the app in one tap so the next
// open is the new build. All Dart, no new native code, so this card itself
// arrives as a patch.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../data/store.dart';
import '../main.dart' show updateStamp;
import '../services/diagnostics.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';
import 'app_exit_stub.dart' if (dart.library.io) 'app_exit_io.dart';

class UpdateCard extends StatefulWidget {
  /// Optional so existing uses keep working. When present, the diagnostics
  /// report can include COUNTS of stored items, never their contents.
  final SalapifyStore? store;
  const UpdateCard({super.key, this.store});

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
  final ShorebirdUpdater _updater = ShorebirdUpdater();
  bool busy = false;
  String? status;
  int? patchNumber;

  @override
  void initState() {
    super.initState();
    _readPatch();
  }

  Future<void> _readPatch() async {
    if (kIsWeb || !_updater.isAvailable) return;
    try {
      final patch = await _updater.readCurrentPatch();
      if (mounted && patch != null) setState(() => patchNumber = patch.number);
    } catch (_) {
      // Purely informational; a read failure changes nothing.
    }
  }

  Future<void> _check() async {
    if (busy) return;
    if (kIsWeb) {
      setState(
        () => status =
            'The web preview updates by itself: just refresh the page.',
      );
      return;
    }
    if (!_updater.isAvailable) {
      setState(
        () => status = 'Automatic updates are not active in this build.',
      );
      return;
    }
    setState(() {
      busy = true;
      status = 'Checking...';
    });
    // The card can be disposed mid-await (switching tabs swaps the body),
    // so every state touch after an await goes through this guard.
    void safeSet(VoidCallback fn) {
      if (mounted) setState(fn);
    }

    try {
      final result = await _updater.checkForUpdate();
      switch (result) {
        case UpdateStatus.upToDate:
          safeSet(() => status = 'You are on the newest build already.');
        case UpdateStatus.restartRequired:
          safeSet(() => status = 'Update ready.');
          await _offerRestart('The new build is already downloaded.');
        case UpdateStatus.outdated:
          safeSet(() => status = 'Downloading the update...');
          await _updater.update();
          safeSet(() => status = 'Update ready.');
          await _offerRestart('The new build finished downloading.');
        case UpdateStatus.unavailable:
          safeSet(
            () => status = 'Automatic updates are not active in this build.',
          );
      }
    } on UpdateException catch (e) {
      safeSet(() => status = 'Update failed, nothing changed: ${e.message}');
    } catch (e) {
      safeSet(() => status = 'Could not check right now. Are you online? $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _offerRestart(String detail) async {
    if (!mounted) return;
    final close = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text(
          'Switch to the new build?',
          style: TextStyle(color: Barako.text),
        ),
        content: Text(
          '$detail The app switches to it the next time it starts. '
          'Close the app now and reopen it to finish.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Later', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Close app now',
              style: TextStyle(color: Barako.primary),
            ),
          ),
        ],
      ),
    );
    if (close == true) {
      // A full process exit is what lets the Shorebird engine boot into the
      // downloaded patch; reopening the app lands on the new build.
      closeApp();
    }
    if (mounted) {
      setState(
        () => status =
            'Update is ready. It applies the next time the app starts.',
      );
    }
  }

  // Show it, THEN copy it. A money app asking to put anything on the
  // clipboard has to let the person read it first, and this is the only
  // feature that deliberately moves data off the phone.
  Future<void> _copyDiagnostics() async {
    final text = Diagnostics.report(
      stamp: updateStamp,
      patch: patchNumber,
      data: widget.store?.data,
    );
    if (!mounted) return;
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Diagnostics', style: TextStyle(color: Barako.text)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This is everything that gets copied. It has counts and '
                  'error messages only, never your amounts, names, or notes.',
                  style: AppText.small,
                ),
                const SizedBox(height: 12),
                // Deliberately NOT a monospace family. The report is a list
                // of lines, not aligned columns, so monospace bought almost
                // nothing, and it cost the ability to check this screen: the
                // render harness has no monospace font, so every character
                // drew as a box and the one screen that shows data leaving
                // the phone became the one screen nobody could read.
                SelectableText(
                  text,
                  style: AppText.caption
                      .tint(Barako.text)
                      .copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Barako.muted)),
          ),
          TextButton(
            onPressed: () async {
              await Diagnostics.clear();
              if (context.mounted) Navigator.pop(context, false);
            },
            child: Text('Clear', style: TextStyle(color: Barako.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Copy'),
          ),
        ],
      ),
    );
    if (send != true) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      setState(() => status = 'Diagnostics copied. Paste it in a message.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Update stamp', style: AppText.label.w4),
                const SizedBox(width: 16),
                Expanded(
                  // Capped on purpose. A stamp is meant to answer one
                  // question, which build am I running, and this row once
                  // filled the entire screen with forty lines of release
                  // notes because nothing here pushed back on a long string.
                  // A test keeps the stamp short; this keeps the SCREEN safe
                  // even when something gets past it.
                  child: Text(
                    patchNumber != null
                        ? '$updateStamp (patch $patchNumber)'
                        : updateStamp,
                    textAlign: TextAlign.right,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption,
                  ),
                ),
              ],
            ),
            if (widget.store != null) ...[
              const SizedBox(height: 10),
              _StorageRow(store: widget.store!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Barako.border),
                    foregroundColor: Barako.textSecondary,
                  ),
                  onPressed: busy ? null : _check,
                  icon: busy
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Barako.muted,
                          ),
                        )
                      : Icon(salapifyIcon('refresh'), size: 16),
                  label: Text(busy ? 'Working...' : 'Check for update'),
                ),
                // The one thing that could not be got off the phone before.
                // Everything it copies is on screen first, so nothing leaves
                // the device without being seen.
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Barako.border),
                    foregroundColor: Barako.textSecondary,
                  ),
                  onPressed: _copyDiagnostics,
                  icon: Icon(salapifyIcon('diagnostics'), size: 16),
                  label: const Text('Copy diagnostics'),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(status!, style: AppText.caption),
            ],
          ],
        ),
      ),
    );
  }
}

/// The one-line "where your data lives" readout, so the founder can SEE that the
/// encrypted store engaged rather than silently falling back to plaintext. An
/// untestable native encryption is exactly the kind of thing that must be
/// visible, not trusted.
class _StorageRow extends StatelessWidget {
  final SalapifyStore store;
  const _StorageRow({required this.store});

  @override
  Widget build(BuildContext context) {
    final health = store.storageHealth();
    final encrypted = health.encrypted;
    return Row(
      children: [
        Text('Storage', style: AppText.label.w4),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Icon(
                encrypted ? salapifyIcon('locked') : salapifyIcon('unlocked'),
                size: 14,
                color: encrypted ? Barako.primary : Barako.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  encrypted
                      ? (health.migratedThisRun
                            ? 'Encrypted (moved this run)'
                            : 'Encrypted')
                      : health.engineLabel,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
