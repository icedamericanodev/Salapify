import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/format.dart';
import '../../data/import.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Restoring a backup, which replaces everything.
///
/// This is the most destructive thing Salapify can do: no server, no account,
/// no second copy. So the whole sheet is built around one idea, that NOTHING
/// is written until the person has seen both ledgers side by side and
/// confirmed. Picking the wrong file costs nothing at all, because the file is
/// only ever decoded in memory until then.
///
/// The way back is a real file, written before the replacement and never
/// deleted, surfaced as a permanent row rather than a snackbar. A snackbar
/// undo would be a second write racing the first, and an app killed in the gap
/// would leave a half swapped ledger.
class ImportSheet extends StatefulWidget {
  const ImportSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => ImportSheet(state: state),
    );
  }

  @override
  State<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<ImportSheet> {
  FinancialState get state => widget.state;

  ImportCheck? _check;
  LedgerSummary? _previous;
  bool _busy = false;
  final TextEditingController _paste = TextEditingController();
  bool _showPaste = false;

  @override
  void initState() {
    super.initState();
    _loadPrevious();
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _loadPrevious() async {
    final LedgerSummary? p = await state.previousLedger();
    if (mounted) setState(() => _previous = p);
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(state.theme);
    final ImportCheck? check = _check;

    return SheetScaffold(
      palette: p,
      icon: Icons.settings_backup_restore_outlined,
      title: 'Restore from a backup',
      subtitle: 'Replaces everything on this phone',
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (check == null) ..._chooser(p),
            if (check is ImportRefused) ..._refused(p, check),
            if (check is ImportReady) ..._ready(p, check),
            if (_previous != null) ...<Widget>[
              const SizedBox(height: Spacing.lg),
              Divider(color: p.border),
              const SizedBox(height: Spacing.md),
              _undoRow(p, _previous!),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _chooser(Palette p) => <Widget>[
    Text(
      'A backup file replaces everything in Salapify on this phone. Salapify '
      'saves a copy of what is here now first, so you can put it back.',
      style: AppType.body(p),
    ),
    const SizedBox(height: Spacing.lg),
    _Action(
      palette: p,
      label: _busy ? 'Reading the file...' : 'Choose a backup file',
      onTap: _busy ? null : _pickFile,
    ),
    const SizedBox(height: Spacing.sm),
    _Action(
      palette: p,
      label: _showPaste ? 'Read what I pasted' : 'Paste a backup instead',
      emphasis: false,
      onTap: () {
        if (!_showPaste) {
          setState(() => _showPaste = true);
          return;
        }
        setState(() => _check = checkImportFile(_paste.text));
      },
    ),
    if (_showPaste) ...<Widget>[
      const SizedBox(height: Spacing.sm),
      TextField(
        controller: _paste,
        maxLines: 6,
        minLines: 4,
        style: AppType.caption(p),
        decoration: InputDecoration(
          hintText: 'Paste the contents of your backup file here',
          hintStyle: AppType.caption(p).copyWith(color: p.textMuted),
          filled: true,
          fillColor: p.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.control),
            borderSide: BorderSide(color: p.border),
          ),
        ),
      ),
      const SizedBox(height: Spacing.xs),
      Text(
        // Not a footnote. This is the route that works when the share sheet or
        // the file picker is missing, which on a development build is common.
        'Useful when the backup arrived in an email or a chat rather than as '
        'a file.',
        style: AppType.caption(p),
      ),
    ],
  ];

  List<Widget> _refused(Palette p, ImportRefused refused) => <Widget>[
    Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: p.negative.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: p.negative.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            refused.reason,
            style: AppType.body(p).copyWith(color: p.negative),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            // Always, on every refusal. The first question somebody has after
            // a red box in a money app is whether it broke something.
            'Nothing on this phone has changed.',
            style: AppType.rowMeta(p),
          ),
        ],
      ),
    ),
    const SizedBox(height: Spacing.md),
    _Action(
      palette: p,
      label: 'Choose another file',
      emphasis: false,
      onTap: () => setState(() => _check = null),
    ),
  ];

  List<Widget> _ready(Palette p, ImportReady ready) {
    final LedgerSummary now = summarizeSnapshot(state.snapshot());
    return <Widget>[
      _Compare(palette: p, label: 'On this phone now', summary: now),
      const SizedBox(height: Spacing.sm),
      _Compare(palette: p, label: 'In this file', summary: ready.summary),
      const SizedBox(height: Spacing.md),

      // The lines that stay however long they are, because silence would
      // mislead rather than merely omit.
      if (now.hasSampleData)
        _Note(
          palette: p,
          text:
              'Everything on this phone now is Salapify’s sample data. '
              'None of it is yours.',
        ),
      if (ready.missing.isNotEmpty)
        _Note(
          palette: p,
          text:
              'This file does not contain: ${ready.missing.join(', ')}. Those '
              'will be empty after you restore, even if you have them now.',
        ),
      if (ready.summary.isEmpty)
        _Note(
          palette: p,
          text:
              'This file contains no accounts and no entries. Restoring it '
              'leaves Salapify empty.',
        ),

      const SizedBox(height: Spacing.md),
      _Action(
        palette: p,
        label: 'Replace everything with this backup',
        onTap: _busy ? null : () => _confirm(p, ready, now),
      ),
    ];
  }

  Widget _undoRow(Palette p, LedgerSummary previous) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Put back what was here before', style: AppType.rowTitle(p)),
      const SizedBox(height: 2),
      Text(
        'The ledger from before you last restored a backup: '
        '${previous.accounts} accounts holding ${formatPeso(previous.assets)} '
        'and ${previous.entries} entries.',
        style: AppType.caption(p),
      ),
      const SizedBox(height: Spacing.sm),
      _Action(
        palette: p,
        label: 'Put the earlier ledger back',
        emphasis: false,
        onTap: _busy ? null : () => _confirmUndo(p, previous),
      ),
    ],
  );

  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      const XTypeGroup group = XTypeGroup(
        label: 'Salapify backup',
        extensions: <String>['json'],
      );
      final XFile? file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[group],
      );
      if (file == null) return;
      final String raw = await File(file.path).readAsString();
      if (mounted) setState(() => _check = checkImportFile(raw));
    } on MissingPluginException {
      // Built before file_selector was added. The paste route still works,
      // and saying so beats a dead button.
      if (mounted) {
        setState(() {
          _showPaste = true;
          _check = const ImportRefused(
            'This build cannot open the file picker yet. A full rebuild fixes '
            'it. You can paste the backup instead.',
          );
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _check = ImportRefused('Could not read that file. $e'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(Palette p, ImportReady ready, LedgerSummary now) async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text(
          'Replace everything with this backup?',
          style: AppType.title(p),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // BOTH ledgers, in pesos. "Are you sure?" over a destructive
              // action is a question nobody can answer.
              Text('Out: ${_describe(now)}', style: AppType.body(p)),
              const SizedBox(height: Spacing.sm),
              Text('In: ${_describe(ready.summary)}', style: AppType.body(p)),
              const SizedBox(height: Spacing.sm),
              Text(
                'This is not a merge. Nothing on this phone is kept.',
                style: AppType.body(p).copyWith(color: p.negative),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Salapify saves a copy of what is here now first, so you can '
                'put it back from this same screen.',
                style: AppType.caption(p),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep what I have',
              style: TextStyle(color: p.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Replace it', style: TextStyle(color: p.negative)),
          ),
        ],
      ),
    );

    if (go != true) return;
    setState(() => _busy = true);
    final bool ok = await state.importSnapshot(ready.incoming);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _check = null;
    });
    await _loadPrevious();
    if (mounted) {
      _say(
        ok
            ? 'Restored. You can put the earlier ledger back from Settings.'
            : 'Nothing was restored, and nothing has changed.',
      );
    }
  }

  Future<void> _confirmUndo(Palette p, LedgerSummary previous) async {
    final LedgerSummary now = summarizeSnapshot(state.snapshot());
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Put the earlier ledger back?', style: AppType.title(p)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Out: ${_describe(now)}', style: AppType.body(p)),
            const SizedBox(height: Spacing.sm),
            Text('In: ${_describe(previous)}', style: AppType.body(p)),
            const SizedBox(height: Spacing.sm),
            Text(
              'Salapify keeps a copy of what is here now, so you can swap '
              'back again.',
              style: AppType.caption(p),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Leave it', style: TextStyle(color: p.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Put it back', style: TextStyle(color: p.accent)),
          ),
        ],
      ),
    );

    if (go != true) return;
    setState(() => _busy = true);
    final bool ok = await state.undoLastImport();
    if (!mounted) return;
    setState(() => _busy = false);
    await _loadPrevious();
    if (mounted) {
      _say(ok ? 'Put back.' : 'Nothing changed.');
    }
  }

  static String _describe(LedgerSummary s) {
    if (s.isEmpty) {
      return 'nothing. This holds no accounts and no entries, so Salapify '
          'will be empty afterwards.';
    }
    final StringBuffer b = StringBuffer()
      ..write('${s.accounts} accounts holding ')
      ..write('${formatPeso(s.assets)} of savings and ')
      ..write('${formatPeso(s.liabilities)} of debts, ')
      ..write('${s.entries} entries');
    if (s.debts > 0) b.write(' and ${s.debts} debts');
    b.write('.');
    return b.toString();
  }

  void _say(String message) {
    final Palette p = Palette.of(state.theme);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: p.onAccent)),
          backgroundColor: p.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }
}

/// One side of the before-and-after, with the same rows on both so the eye can
/// compare them straight down.
class _Compare extends StatelessWidget {
  const _Compare({
    required this.palette,
    required this.label,
    required this.summary,
  });

  final Palette palette;
  final String label;
  final LedgerSummary summary;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> rows = <(String, String)>[
      (
        'Accounts',
        '${summary.accounts}, holding ${formatPeso(summary.assets)} of '
            'savings and ${formatPeso(summary.liabilities)} of debts',
      ),
      ('Entries', '${summary.entries}'),
      if (summary.debts > 0)
        (
          'Debts',
          'You owe ${formatPeso(summary.owed)}. You are owed '
              '${formatPeso(summary.owedToYou)}.',
        ),
      if (summary.goals > 0) ('Goals', '${summary.goals}'),
      if (summary.budgets > 0) ('Budget limits', '${summary.budgets}'),
      if (summary.bills > 0) ('Bills', '${summary.bills}'),
      if (summary.installments > 0)
        ('Payment plans', '${summary.installments}'),
      if (summary.savedAt != null) ('Saved', summary.savedAt!.split('T').first),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label.toUpperCase(), style: AppType.kicker(palette)),
          const SizedBox(height: Spacing.sm),
          for (final (String k, String v) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 96,
                    child: Text(k, style: AppType.caption(palette)),
                  ),
                  Expanded(child: Text(v, style: AppType.rowMeta(palette))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.palette, required this.text});

  final Palette palette;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 16, color: palette.accent),
        const SizedBox(width: Spacing.sm),
        Expanded(child: Text(text, style: AppType.caption(palette))),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({
    required this.palette,
    required this.label,
    required this.onTap,
    this.emphasis = true,
  });

  final Palette palette;
  final String label;
  final VoidCallback? onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final bool off = onTap == null;
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: off
            ? palette.surfaceAlt
            : emphasis
            ? palette.negative
            : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.rowTitle(palette).copyWith(
                color: off
                    ? palette.textMuted
                    : emphasis
                    ? Colors.white
                    : palette.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
