import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../features/settings/export_backup.dart';
import '../../features/shared/sheet_scaffold.dart';
import '../../state/financial_state.dart';
import 'home_kit.dart';

/// The Home card that asks for a backup (D38.3).
///
/// Salapify keeps every record on this phone and nowhere else. The card only
/// exists while [FinancialState.backupNudge] says so: thirty or more of the
/// person's own entries the last backup lacks AND fourteen days since it, and
/// no "Not now" still running. It is never a phone notification, because a
/// backup is something to do with the app open, not something to be woken for.
///
/// The figure is the reason, so it leads: "42 entries live only on this
/// phone" is a fact about their records, where "remember to back up" is a
/// lecture.
class BackupCard extends StatefulWidget {
  const BackupCard({super.key, required this.state, required this.count});

  final FinancialState state;

  /// Entries the last backup lacks, from [FinancialState.backupNudge].
  final int count;

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool _busy = false;

  Future<void> _backUp() async {
    setState(() => _busy = true);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    void say(String message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    try {
      final bool done = await exportBackup(state: widget.state, say: say);
      // The card leaves the moment the store records the backup, so the
      // confirmation is the snackbar: the file is wherever they sent it, and
      // the one thing left worth saying is that the phone is not that place.
      if (done) {
        say(
          'Backed up. Keep the file somewhere off this phone, like Drive or '
          'email.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final int n = widget.count;

    return SectionCard(
      key: const Key('backup-card'),
      palette: p,
      padding: const EdgeInsets.all(Spacing.md),
      radius: Radii.control,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconTile(palette: p, icon: Icons.cloud_upload_outlined),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Text('Back up your records', style: AppType.rowTitle(p)),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '$n entries live only on this phone. A backup file keeps them '
            'safe if the phone is lost.',
            style: AppType.body(p),
          ),
          const SizedBox(height: Spacing.md),
          PrimaryButton(
            palette: p,
            icon: Icons.ios_share_outlined,
            label: _busy ? 'Preparing your backup...' : 'Back up now',
            onTap: _busy ? null : _backUp,
          ),
          const SizedBox(height: Spacing.xs),
          Center(
            child: TextButton(
              onPressed: _busy ? null : widget.state.snoozeBackupNudge,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                child: Text(
                  'Not now',
                  style: AppType.body(p).copyWith(color: p.textMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
