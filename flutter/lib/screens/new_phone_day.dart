// New phone day: the guided two-minute handoff to a new device, composing the
// existing backup primitives (save to device, share sheet, file-pick import).
// This closes the one honest argument cloud apps have against an offline app,
// "what if I lose my phone", without adding any cloud: the file moves however
// the user likes (Quick Share, email to self, a drive) and the golden-locked
// importer does the safety work on the other end. Works from either side: the
// old phone saves and sends, the new phone brings the file in.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/backup_file.dart';
import '../data/store.dart';
import '../theme.dart';
import 'overview.dart' show ImportScreen;

class NewPhoneDayScreen extends StatefulWidget {
  final SalapifyStore store;
  const NewPhoneDayScreen({super.key, required this.store});

  @override
  State<NewPhoneDayScreen> createState() => _NewPhoneDayScreenState();
}

class _NewPhoneDayScreenState extends State<NewPhoneDayScreen> {
  bool _busy = false;

  // Runs a backup task and toasts only on a real outcome: a task returning
  // false means the user deliberately backed out (cancelled the save dialog,
  // dismissed the share sheet), which deserves silence, not an error.
  Future<void> _run(Future<bool> Function() task, String doneMessage) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final done = await task();
      if (done) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(doneMessage)));
      }
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('That did not go through, nothing lost. $e')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The save dialog and share sheet need a native platform, matching the
    // export screen's web gating; on the web preview the steps still read as
    // instructions and the import path still works.
    final canAct = !kIsWeb && widget.store.hasData;
    // On a brand new phone there is nothing to back up yet, which is the whole
    // point of arriving here. Say so, rather than rendering steps 1 and 2 with
    // their buttons silently missing.
    final nothingToSendYet = !kIsWeb && !widget.store.hasData;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'New phone day',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Moving phones takes about two minutes, and your data never '
              'touches a cloud you did not choose. One small file carries '
              'everything: accounts, entries, IOUs, goals, settings.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Text('ON THIS PHONE', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            if (nothingToSendYet) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'This phone has nothing saved yet, so there is nothing to '
                    'send from here. These two steps are for your OLD phone. '
                    'If this is the new one, skip to step 3.',
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _stepCard(
              '1',
              'Save your backup file',
              'One file, everything in it. Save it to this phone or straight '
                  'into a drive folder.',
              button: canAct ? 'Save backup file' : null,
              onPressed: canAct
                  ? () => _run(
                      () =>
                          saveBackupFileToDevice(widget.store, DateTime.now()),
                      'Backup saved. Now get it to the new phone.',
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            _stepCard(
              '2',
              'Send it to the new phone',
              'Any way you like: Quick Share to the new phone, email it to '
                  'yourself, or drop it in a drive. The share button sends '
                  'the same file directly.',
              button: canAct ? 'Share the backup' : null,
              onPressed: canAct
                  ? () => _run(
                      () => shareBackupFile(widget.store, DateTime.now()),
                      'Sent. Open Salapify on the new phone next.',
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text('ON THE NEW PHONE', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            _stepCard(
              '3',
              'Bring the file in',
              'Install Salapify, open this same screen, and choose the file. '
                  'Every number arrives exactly as you left it, checked by '
                  'the same importer your backups have always used.',
              button: 'I am the new phone: bring data over',
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ImportScreen(store: widget.store),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      color: Barako.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'A monthly backup reminder lives in Menu under '
                        'Reminders, so the file on your drive stays fresh '
                        'and a lost phone is an errand, not a disaster.',
                        style: TextStyle(
                          color: Barako.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard(
    String number,
    String title,
    String body, {
    String? button,
    VoidCallback? onPressed,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Barako.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: TextStyle(
                      color: Barako.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          color: Barako.muted,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (button != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _busy ? null : onPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Barako.primaryText,
                    side: BorderSide(color: Barako.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _busy ? 'Working...' : button,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
