// Settings, which today is Backup, because Backup is the only thing here that
// somebody would miss.
//
// Pushed over the shell like every other detail screen (04-screens.md), so it
// carries a BackBar.
//
// THE SHAPE OF THIS SCREEN IS THE SAFETY. Export sits above Restore because
// making a copy is what you do BEFORE replacing anything, and a person reading
// top to bottom meets them in that order. The Undo card, when there is one, sits
// above both, because after a restore it is the most urgent thing on the page.
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/clock.dart';
import '../../app/ledger_scope.dart';
import '../../core/money/format.dart';
import '../../design/kit.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import 'backup_files.dart';
import 'backup_service.dart';
import 'save_to_device.dart';
import 'spreadsheet_export.dart';

/// The route this screen lives at.
const String settingsRoutePath = '/settings';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _canUndo = false;

  bool _askedForUndo = false;

  // NOT initState. `context.ledger` reads an inherited widget, and Flutter
  // forbids that before initState has completed: it throws
  // "dependOnInheritedWidgetOfExactType<LedgerScope>() was called before
  // _SettingsScreenState.initState() completed", which on a phone means the
  // screen throws while building and draws nothing at all.
  //
  // That is precisely what happened. This screen shipped without being
  // rendered once, and the founder opened Settings and reported "I do not see
  // a Save button" and "no Restore button either". Both were true and neither
  // was a sync problem: the whole screen was failing to build. 524 tests were
  // green, because not one of them had built THIS widget.
  //
  // didChangeDependencies is the documented home for setup that reads
  // inherited widgets. It can run more than once, so the flag keeps the undo
  // check to the first pass.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_askedForUndo) return;
    _askedForUndo = true;
    _refreshUndo();
  }

  Future<void> _refreshUndo() async {
    final can = await context.ledger.hasUndoSnapshot;
    if (mounted) setState(() => _canUndo = can);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.ledger;
    final summary = LedgerSummary.of(store.data);

    return Scaffold(
      backgroundColor: context.skin.bg,
      body: Screen(
        children: [
          const BackBar(),
          const SizedBox(height: 14),
          const ScreenTitle(
            title: 'Settings',
            sub: 'Your money lives on this phone. Keep a copy somewhere else.',
          ),
          const SizedBox(height: 20),

          // A restore that can still be undone is the most urgent thing on the
          // page, so it goes first, and it is a CARD rather than a snackbar. A
          // snackbar that vanishes after four seconds is not an undo for an
          // action this size: the moment somebody realises they restored the
          // wrong file is not within four seconds of doing it.
          if (_canUndo) ...[
            _UndoCard(onUndo: _busy ? null : _undo),
            const SizedBox(height: 22),
          ],

          const Head(title: 'Backup'),
          const SizedBox(height: 10),
          _Card(
            title: 'Save a copy',
            body:
                'Everything on this phone in one file that can be restored '
                'later. ${summary.entries} entries, ${summary.accounts} '
                'accounts, ${formatMoney(summary.netWorth)}.',
            // TWO ways out, because saving and sharing are different acts and
            // the founder asked for exactly this: "what if i do not like to
            // share it but just want to save in my device?". Offering only the
            // share sheet asks somebody to send their whole ledger through
            // Gmail in order to keep a copy of it.
            //
            // Save is the PRIMARY. Keeping a copy is the common case; sending
            // one somewhere is the occasional one.
            action: 'Save to this phone',
            onAction: _busy ? null : _saveBackup,
            secondAction: 'Share instead',
            onSecondAction: _busy ? null : _shareBackup,
          ),
          const SizedBox(height: 12),
          _Card(
            title: 'Restore from a file',
            body:
                'Brings back a backup you saved before. This REPLACES '
                'everything currently on this phone. You will see what is in '
                'the file before anything changes.',
            action: 'Choose a file',
            onAction: _busy ? null : _restore,
          ),

          const SizedBox(height: 26),
          // A SEPARATE SECTION, deliberately, and the word "backup" never
          // appears in it. A spreadsheet cannot be restored: it is a flat grid,
          // and a ledger is accounts, debts, people and the links between them.
          // The dangerous version of this feature is a "CSV backup" button, and
          // somebody discovering at the worst possible moment that it was never
          // one.
          const Head(title: 'For a spreadsheet'),
          const SizedBox(height: 10),
          _Card(
            title: 'Your entries as a spreadsheet',
            body:
                'A CSV of every entry with its date, amount and account, for '
                'Excel, Google Sheets, or your accountant. This is for '
                'READING. It cannot be restored, so keep the backup above as '
                'well.',
            action: 'Save to this phone',
            onAction: _busy ? null : _saveCsv,
            secondAction: 'Share instead',
            onSecondAction: _busy ? null : _shareCsv,
          ),

          const SizedBox(height: 22),
          // Said plainly, on the screen that makes the file, not buried in a
          // policy nobody opens. The founder was told this before approving it
          // and users deserve the same sentence.
          _Note(
            'The file is plain readable text. It contains your accounts, '
            'balances and every entry, including any accounts you have hidden. '
            'Anyone who opens it can read all of it, so keep it somewhere you '
            'trust.',
          ),
        ],
      ),
    );
  }

  Future<void> _saveBackup() => _backup(share: false);
  Future<void> _shareBackup() => _backup(share: true);

  /// Both backup paths, because only the last step differs and two copies of
  /// the verification would be two things to keep true.
  Future<void> _backup({required bool share}) async {
    final store = context.ledger;
    final now = context.now;
    setState(() => _busy = true);
    try {
      // Verified BEFORE anything leaves. An export the app cannot read back is
      // not a backup, and finding that out after somebody has filed it away is
      // finding out too late.
      final built = buildVerifiedBackup(store.data, now: now);
      final name = backupFileName(now);
      final done = share
          ? await shareBackupText(built.text, name)
          : await saveBytesToDevice(utf8.encode(built.text), name);
      if (!mounted) return;
      _say(
        done
            ? 'Saved $name. ${built.summary.entries} entries, '
                  '${built.summary.accounts} accounts, '
                  '${formatMoney(built.summary.netWorth)}. Keep a copy '
                  'somewhere that is not this phone.'
            // Never report success from a dialog merely closing: they may have
            // backed out on purpose, and telling them it saved would leave
            // them believing in a backup that does not exist.
            : 'Nothing was saved.',
      );
    } on BackupFileProblem catch (e) {
      if (mounted) _say(e.message);
    } catch (e) {
      if (mounted) _say('Could not save a copy. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCsv() => _csv(share: false);
  Future<void> _shareCsv() => _csv(share: true);

  /// The spreadsheet path. No verification step, and that is not an oversight:
  /// there is nothing to verify against, because a CSV is not restorable and
  /// never claims to be.
  Future<void> _csv({required bool share}) async {
    final store = context.ledger;
    final now = context.now;
    setState(() => _busy = true);
    try {
      final text = transactionsCsv(store.data);
      final name = csvFileName(now);
      final done = share
          ? await shareBackupText(text, name)
          : await saveBytesToDevice(utf8.encode(text), name);
      if (!mounted) return;
      _say(
        done
            ? 'Saved $name. Remember this one cannot be restored, so keep a '
                  'backup too.'
            : 'Nothing was saved.',
      );
    } catch (e) {
      if (mounted) _say('Could not save that. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final store = context.ledger;
    setState(() => _busy = true);
    try {
      final text = await pickBackupText();
      if (text == null || !mounted) return;

      // PARSED IN MEMORY FIRST, always. Nothing has been written at this point
      // and nothing can be: a bad file fails here with the stored ledger
      // untouched, which is what makes a half-applied restore impossible
      // rather than merely unlikely.
      final incoming = parseBackupText(text);
      final fileSummary = LedgerSummary.of(incoming);

      if (fileSummary.isEmpty) {
        // Valid, and the most dangerous file the app can be handed. It parses
        // perfectly, and restoring it over a real ledger is the most complete
        // data loss available through a path where nothing went wrong. There
        // is no Replace button for this one.
        _say(
          'That backup has nothing in it, so there is nothing to bring back. '
          'Nothing on your phone was changed.',
        );
        return;
      }

      final here = LedgerSummary.of(store.data);
      final ok = await _confirm(here: here, file: fileSummary);
      if (ok != true || !mounted) return;

      await store.restoreFrom(incoming);
      if (!mounted) return;
      await _refreshUndo();
      if (!mounted) return;
      _say(
        'Brought in ${fileSummary.entries} entries, '
        '${fileSummary.accounts} accounts, '
        '${formatMoney(fileSummary.netWorth)}.',
      );
    } on BackupFileProblem catch (e) {
      if (mounted) _say(e.message);
    } catch (e) {
      if (mounted) _say('Could not read that file. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The confirmation, which names BOTH sides in pesos.
  ///
  /// "Are you sure?" is not a question anybody can answer. "This replaces 128
  /// entries and PHP171,825.75 with 96 entries and PHP150,300.00" is, and it is
  /// the only point in the flow where a wrong file is still cheap to catch.
  Future<bool?> _confirm({
    required LedgerSummary here,
    required LedgerSummary file,
  }) {
    final skin = context.skin;
    final fresh = here.isEmpty;
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: skin.card,
        title: Text(
          fresh ? 'Bring in this backup?' : 'Replace everything with this file?',
          style: TypeScale.sheetTitle(skin.text),
        ),
        content: Text(
          fresh
              ? 'The file has ${file.entries} entries and '
                    '${formatMoney(file.netWorth)} across ${file.accounts} '
                    'accounts. This phone has nothing yet, so nothing is '
                    'replaced.'
              : 'This phone has ${here.entries} entries and '
                    '${formatMoney(here.netWorth)} across ${here.accounts} '
                    'accounts.\n\n'
                    'The file has ${file.entries} entries and '
                    '${formatMoney(file.netWorth)} across ${file.accounts} '
                    'accounts.\n\n'
                    'Restoring replaces what is here now. You can undo this '
                    'once, until you restore again.',
          style: TypeScale.subtitle(skin.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(fresh ? 'Not now' : 'Keep what I have'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(fresh ? 'Bring it in' : 'Replace'),
          ),
        ],
      ),
    );
  }

  Future<void> _undo() async {
    setState(() => _busy = true);
    try {
      final done = await context.ledger.undoRestore();
      if (!mounted) return;
      await _refreshUndo();
      if (!mounted) return;
      _say(
        done
            ? 'Put back what was here before the restore.'
            // Never claim it worked when there was nothing to put back.
            : 'There was nothing to undo.',
      );
    } catch (e) {
      if (mounted) _say('Could not undo that. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// One thing you can do, with the sentence that explains it.
class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.secondAction,
    this.onSecondAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback? onAction;

  /// The quieter alternative, drawn secondary so the primary stays obvious.
  final String? secondAction;
  final VoidCallback? onSecondAction;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TypeScale.sectionHead(skin.text)),
          const SizedBox(height: 6),
          Text(body, style: TypeScale.caption(skin.text2)),
          const SizedBox(height: 14),
          if (secondAction == null)
            PillButton(label: action, onTap: onAction)
          else
            // Stacked, not side by side. "Save to this phone" and "Share
            // instead" both need their words, and two pill buttons sharing a
            // 320dp row would truncate one of them.
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: PillButton(label: action, onTap: onAction),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: PillButton(
                    label: secondAction!,
                    secondary: true,
                    onTap: onSecondAction,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The one undo, offered until it is used or spent.
class _UndoCard extends StatelessWidget {
  const _UndoCard({required this.onUndo});
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Undo the last restore', style: TypeScale.sectionHead(skin.text)),
          const SizedBox(height: 6),
          Text(
            'This puts back exactly what was on this phone before you '
            'restored. What you restored will be replaced.',
            style: TypeScale.caption(skin.text2),
          ),
          const SizedBox(height: 14),
          PillButton(label: 'Undo the restore', secondary: true, onTap: onUndo),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(text, style: TypeScale.caption(context.skin.text3)),
  );
}
