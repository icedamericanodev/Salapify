// The update card: the stamp row plus a one-tap update check, the same
// habit the RN app taught the founder. Shorebird patches normally download
// quietly on open and apply on the NEXT start; this button removes the
// waiting: check, download now, then close the app in one tap so the next
// open is the new build. All Dart, no new native code, so this card itself
// arrives as a patch.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

import '../main.dart' show updateStamp;
import '../theme.dart';
import 'app_exit_stub.dart' if (dart.library.io) 'app_exit_io.dart';

class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key});

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
      setState(() => status =
          'The web preview updates by itself: just refresh the page.');
      return;
    }
    if (!_updater.isAvailable) {
      setState(() => status =
          'Automatic updates are not active in this build.');
      return;
    }
    setState(() {
      busy = true;
      status = 'Checking...';
    });
    try {
      final result = await _updater.checkForUpdate();
      switch (result) {
        case UpdateStatus.upToDate:
          setState(() => status = 'You are on the newest build already.');
        case UpdateStatus.restartRequired:
          setState(() => status = 'Update ready.');
          await _offerRestart('The new build is already downloaded.');
        case UpdateStatus.outdated:
          setState(() => status = 'Downloading the update...');
          await _updater.update();
          setState(() => status = 'Update ready.');
          await _offerRestart('The new build finished downloading.');
        case UpdateStatus.unavailable:
          setState(() =>
              status = 'Automatic updates are not active in this build.');
      }
    } on UpdateException catch (e) {
      setState(() => status = 'Update failed, nothing changed: ${e.message}');
    } catch (e) {
      setState(() =>
          status = 'Could not check right now. Are you online? $e');
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
        title: const Text('Switch to the new build?',
            style: TextStyle(color: Barako.text)),
        content: Text(
          '$detail The app switches to it the next time it starts. '
          'Close the app now and reopen it to finish.',
          style: const TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Later',
                  style: TextStyle(color: Barako.muted))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Close app now',
                  style: TextStyle(color: Barako.primary))),
        ],
      ),
    );
    if (close == true) {
      // A full process exit is what lets the Shorebird engine boot into the
      // downloaded patch; reopening the app lands on the new build.
      closeApp();
    }
    if (mounted) {
      setState(() =>
          status = 'Update is ready. It applies the next time the app starts.');
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
                const Text('Update stamp',
                    style: TextStyle(color: Barako.text, fontSize: 14)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                      patchNumber != null
                          ? '$updateStamp (patch $patchNumber)'
                          : updateStamp,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Barako.muted, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Barako.border),
                      foregroundColor: Barako.textSecondary),
                  onPressed: busy ? null : _check,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Barako.muted))
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(busy ? 'Working...' : 'Check for update'),
                ),
              ],
            ),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(status!,
                  style:
                      const TextStyle(color: Barako.muted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
