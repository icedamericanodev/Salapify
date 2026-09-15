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

          // ONE HERO, THEN ROWS. The founder said this screen was too wordy
          // and asked whether the budget sheet's "i" icon belonged here.
          //
          // It does not, and the reason is worth keeping. That "i" hides copy
          // teaching what a category cap IS, and skipping it costs only
          // understanding. Every paragraph on THIS screen describes a
          // consequence: what gets replaced, what cannot be restored, what
          // anybody who opens the file can read. An "i" on a destructive screen
          // is a consent box nobody ticks.
          //
          // The rule applied here: A SENTENCE STAYS VISIBLE IF NOT READING IT
          // CAN COST MONEY OR DATA. It may hide if not reading it only costs
          // understanding.
          //
          // So nothing was hidden. What changed is that the consequences moved
          // to the DECISION instead of stacking above it, and the screen gained
          // a hierarchy it never had: three identical cards at identical weight
          // never answered "what do I do here", which is what actually made it
          // read as a wall. Backing up is the answer, so it is the only card
          // left.
          const Head(title: 'Backup'),
          const SizedBox(height: 10),
          _Card(
            title: 'Save a copy',
            body:
                '${summary.entries} entries, ${summary.accounts} accounts, '
                '${formatMoney(summary.netWorth)}.\n\n'
                // The sentence somebody who has never backed anything up
                // actually needs. "Restore" means nothing until you know what
                // it buys you.
                'If this phone is lost or wiped, this file is how you get your '
                'money back.',
            // TWO ways out, because saving and sharing are different acts and
            // the founder asked for exactly this: "what if i do not like to
            // share it but just want to save in my device?". Offering only the
            // share sheet asks somebody to send their whole ledger through
            // Gmail in order to keep a copy of it.
            action: 'Save to this phone',
            onAction: _busy ? null : _saveBackup,
            secondAction: 'Send it somewhere',
            onSecondAction: _busy ? null : _shareBackup,
          ),

          const SizedBox(height: 24),
          const Head(title: 'More'),
          const SizedBox(height: 8),
          Group(
            children: [
              // ROWS, not cards. `ItemRow` brings the tap target, the chevron
              // and the press feedback the paragraphs never had, and the one
              // clause under each title is the consequence in the fewest words
              // that still carry it. The full sentence is not lost: it is in
              // the confirmation, where it is read at the moment it matters
              // rather than two scrolls above it.
              ItemRow(
                icon: Icons.restore_rounded,
                title: 'Restore from a file',
                sub: 'Replaces everything on this phone',
                amount: '',
                onTap: _busy ? null : _restore,
              ),
              ItemRow(
                icon: Icons.table_chart_outlined,
                title: 'Entries as a spreadsheet',
                // "Cannot be restored" is the hardest working clause on this
                // screen, so nothing follows it. A wrong restore is
                // recoverable, thanks to the Undo card above. Trusting a CSV
                // as a backup is not.
                sub: 'For reading only, cannot be restored',
                amount: '',
                onTap: _busy ? null : _csvSheet,
              ),
            ],
          ),

          const SizedBox(height: 22),
          // Said plainly, on the screen that makes the file, not buried in a
          // policy nobody opens. The founder was told this before approving
          // plaintext and users deserve the same sentence.
          //
          // text2, not text3. It was the faintest ink on the screen, which is
          // the wrong weight for the only sentence here about who else can
          // read your finances.
          _Note(
            'This file is plain text. Anyone who opens it can read your '
            'accounts, balances and every entry, including hidden accounts. '
            'Keep it somewhere private.',
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

  /// The spreadsheet's own sheet, so its one warning is read at the moment of
  /// the decision rather than in a paragraph two scrolls above it.
  Future<void> _csvSheet() async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // The shell draws the nav bar over the tab, so a sheet without this lands
      // underneath it with its buttons unreachable.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CsvSheet(),
    );
    if (choice == null || !mounted) return;
    await _csv(share: choice);
  }

  Future<void> _csv({required bool share}) => _csvRun(share: share);

  /// The spreadsheet path. No verification step, and that is not an oversight:
  /// there is nothing to verify against, because a CSV is not restorable and
  /// never claims to be.
  Future<void> _csvRun({required bool share}) async {
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
    // text2, not text3. This was the faintest ink on the screen and it is the
    // only sentence here about who else can read your finances.
    child: Text(text, style: TypeScale.caption(context.skin.text2)),
  );
}

/// What a spreadsheet is and is not, at the moment somebody asks for one.
///
/// The warning lives here rather than in a paragraph on the screen because
/// this is where the decision happens. Somebody who taps this row is about to
/// make a file, and the one thing they must not walk away believing is that it
/// is a backup.
class _CsvSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return Container(
      decoration: BoxDecoration(
        color: skin.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(gutter, 18, gutter, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entries as a spreadsheet',
            style: TypeScale.sheetTitle(skin.text),
          ),
          const SizedBox(height: 8),
          Text(
            'Every entry as a CSV for Excel or Google Sheets.',
            style: TypeScale.caption(skin.text2),
          ),
          const SizedBox(height: 10),
          Text(
            'This cannot be restored. Keep a backup as well.',
            // Accent, not red. It is not an error, it is the one fact that
            // decides whether this file is enough on its own.
            style: TypeScale.hintStrong(skin.accent),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: 'Save to this phone',
              onTap: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: PillButton(
              label: 'Send it somewhere',
              secondary: true,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}
