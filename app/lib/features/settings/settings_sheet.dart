import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../lock/app_lock.dart';
import '../../data/store.dart';
import '../../main.dart' show updateStamp;
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../categories/category_manager_sheet.dart';
import '../shared/sheet_scaffold.dart';
import '../tax/tax_calculator_sheet.dart';
import 'export_backup.dart';
import 'import_sheet.dart';
import 'privacy_sheet.dart';
import 'sample_data_sheet.dart';
import 'wipe_sheet.dart';

/// Settings, from `archive/prototype-google-ai-studio/src/components/SettingsModal.tsx`.
///
/// The gear in the header opened a "coming soon" toast until now. It holds the
/// things the prototype's own Settings holds and that this build actually has:
/// appearance, where the data lives, a backup, the categories, the tax
/// calculator, and the sample data control.
///
/// ## Why the storage detail moved in here
///
/// Founder direction, 2026-09-19, looking at a screenshot of Home: "can you
/// remove/hide that warning box on the simulator screen or put them in the
/// settings?"
///
/// It is now one line on Home and the whole explanation is here. What did NOT
/// happen is the first half of that sentence, and the reason is worth stating
/// rather than quietly ignoring: a silent save failure is the one defect that
/// costs somebody everything they typed, with no server holding a copy. So the
/// line stays on Home, it just stops being six lines of it.
///
/// On the founder's own emulator the whole thing disappears after a rebuild,
/// because the cause is an app built before path_provider was added.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => SettingsSheet(state: state),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  FinancialState get state => widget.state;
  bool _busy = false;

  /// On or off, each behind the phone's own lock (see AppLockController).
  /// Anything that stopped it is said in a short note, never in silence.
  Future<void> _toggleLock(AppLockController lock) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool turningOn = !lock.enabled;
    final String? problem = turningOn
        ? await lock.enable()
        : await lock.disable();
    if (!mounted) return;
    setState(() {});
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            problem ??
                (turningOn
                    ? 'App lock is on. Salapify asks for your phone\'s lock '
                          'when it opens, and after a minute away.'
                    : 'App lock is off.'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(state.theme);
    final AppLockController? lock = AppLockScope.maybeOf(context);
    final String? problem = state.saveProblem ?? state.loadProblem;
    final bool cannotExport = state.loadStatus == LoadStatus.unreadable;

    return SheetScaffold(
      palette: p,
      icon: Icons.settings_outlined,
      title: 'Settings',
      subtitle: 'Your app, your data, and how it is kept',
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Section(palette: p, title: 'Appearance'),
            _Row(
              palette: p,
              icon: state.theme == ThemeMode2.gabi
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              title: state.theme == ThemeMode2.gabi
                  ? 'Gabi, the warm evening dark'
                  : 'Hapon, the late afternoon light',
              subtitle: 'Tap to switch',
              onTap: () {
                state.toggleTheme();
                setState(() {});
              },
            ),

            _Section(palette: p, title: 'Your data'),
            _StorageStatus(palette: p, state: state, problem: problem),
            // EXPORT SENDS THE RAW BYTES WHEN THE FILE COULD NOT BE READ,
            // and never a snapshot.
            //
            // On an unreadable file, restore() never runs _apply, so the state
            // still holds SeedData. state.snapshot() would encode ELEVEN DEMO
            // ACCOUNTS under a row promising "everything on this phone". The
            // person standing in front of the red "not being saved" panel is
            // exactly the person who taps Export to rescue their data, and
            // they would receive a file of Salapify's samples and keep it as
            // their backup.
            //
            // This row was simply DISABLED here for a while, which was right
            // about the danger and wrong about the remedy: the one state that
            // most needs an export then had no route out, on a phone where the
            // data file sits in app-private storage a stock file manager
            // cannot open.
            _Row(
              palette: p,
              icon: Icons.ios_share_outlined,
              title: _busy
                  ? 'Preparing your backup...'
                  : cannotExport
                  ? 'Export the file Salapify cannot read'
                  : 'Export a backup',
              // Says what it IS, because a person about to hand a file to
              // Google Drive deserves to know it holds their salary.
              //
              // IN THE UNREADABLE STATE IT SENDS THE RAW BYTES, not a
              // snapshot. Disabling it entirely was right about the danger and
              // wrong about the remedy: it left the one state with no route
              // out at all, on a phone where the file sits in app-private
              // storage a file manager cannot reach. The bytes are still the
              // person's records, and they are plain text.
              subtitle: cannotExport
                  ? 'Salapify cannot make sense of your data file, so it '
                        'cannot build a normal backup. This sends the file '
                        'exactly as it is. Keep it. It still holds your '
                        'records, and it is plain text.'
                  : 'One file holding everything on this phone. Keep it '
                        'somewhere you trust.',
              onTap: _busy ? null : (cannotExport ? _exportRaw : _export),
            ),
            _Row(
              palette: p,
              icon: Icons.settings_backup_restore_outlined,
              title: 'Restore from a backup',
              // OFFERED EVEN WHEN THE FILE IS UNREADABLE. Refusing it was
              // the worse answer: somebody with an unreadable file and a good
              // backup in their email had no move except to uninstall, which
              // destroys the very file they might still have rescued. The
              // copy promise stays literally true because the import keeps
              // the RAW BYTES rather than a snapshot of the seed.
              subtitle: cannotExport
                  ? 'Replaces what is on this phone with a backup file. '
                        'Salapify keeps the file it cannot read, so nothing '
                        'is thrown away. Export it first.'
                  : 'Replaces everything on this phone with a backup file. '
                        'Salapify keeps a copy of what is here now.',
              onTap: () async {
                await ImportSheet.show(context, state);
                if (mounted) setState(() {});
              },
            ),
            _Row(
              palette: p,
              icon: Icons.folder_open_outlined,
              title: 'Categories',
              subtitle: 'The categories and sub-categories your entries use',
              onTap: () => CategoryManagerSheet.show(context, state),
            ),
            _Row(
              palette: p,
              icon: Icons.science_outlined,
              title: 'Sample data',
              subtitle: state.hasSampleData
                  ? 'Salapify added some example entries. Remove them here.'
                  : 'Nothing of Salapify’s own is on this phone.',
              onTap: () async {
                await SampleDataSheet.show(context, state);
                if (mounted) setState(() {});
              },
            ),

            _Section(palette: p, title: 'Philippine tax and take-home'),
            _Row(
              palette: p,
              icon: Icons.calculate_outlined,
              title: 'Tax and 13th month calculator',
              subtitle: 'Take-home pay, and the freelancer 8% choice',
              onTap: () => TaxCalculatorSheet.show(context, p),
            ),

            _Section(palette: p, title: 'Privacy'),
            if (lock != null)
              _Row(
                key: const Key('settings-app-lock'),
                palette: p,
                icon: lock.enabled
                    ? Icons.lock_outline
                    : Icons.lock_open_outlined,
                title: lock.enabled ? 'App lock is on' : 'App lock',
                // The second sentence is on the screen, not behind a dot,
                // under the house rule's one exception: without it the
                // natural conclusion is that a locked app also means locked
                // backups, and it does not.
                subtitle: lock.enabled
                    ? 'Salapify opens with your phone\'s fingerprint, face or '
                          'PIN, and hides from screenshots and recent apps. It '
                          'does not encrypt your data or your backups.'
                    : 'Open Salapify with your phone\'s own lock. It stops '
                          'someone opening Salapify on this phone; it does not '
                          'encrypt your data or your backups.',
                onTap: () => _toggleLock(lock),
              ),
            _Row(
              palette: p,
              icon: Icons.verified_user_outlined,
              title: 'What stays on this phone',
              subtitle:
                  'Every line, including the two things that leave and the '
                  'fact that a backup is readable text',
              onTap: () => PrivacySheet.show(context, p),
            ),
            // DELETE IS IN THE PRIVACY SECTION, not under "Your data" beside
            // Export and Restore. Somebody looking for a way to get their
            // records off a phone is thinking about privacy, and putting the
            // one irreversible control next to the two routine ones is how a
            // wrong tap happens.
            _Row(
              palette: p,
              icon: Icons.delete_forever_outlined,
              title: 'Delete everything on this phone',
              subtitle:
                  'Your ledger, both spare copies and the saved exchange '
                  'rates. There is no undo.',
              onTap: () async {
                await WipeSheet.show(context, state);
                if (mounted) setState(() {});
              },
            ),
            _Row(
              palette: p,
              icon: Icons.gavel_outlined,
              title: 'Not financial, tax or legal advice',
              subtitle: 'What Salapify\'s figures are, and what they are not',
              onTap: () => _DisclaimerSheet.show(context, p),
            ),

            _Section(palette: p, title: 'About'),
            _Row(
              palette: p,
              icon: Icons.info_outline,
              title: 'Salapify $appVersion',
              subtitle:
                  'Built in the Philippines. Offline by default, and yours.',
              onTap: null,
            ),
            // THE UPDATE STAMP ROW, and it is here so the founder can answer
            // one question: which build am I running.
            //
            // They read it against the last row of docs/delivery-log.md. That
            // comparison is the only real proof a build reached the phone, and
            // it is the one check nobody but the founder can perform: every
            // other signal in the pipeline can be green while the phone runs
            // last week's build.
            //
            // maxLines is the SECOND of two guards, and both are needed. The
            // test caps what can be written; this caps what can be rendered.
            // On Salapify 2 the stamp grew into forty lines filling the whole
            // screen, and the row it lived in was a Text with no limit, so
            // nothing pushed back until somebody looked at their phone.
            _Row(
              palette: p,
              icon: Icons.sync,
              title: 'Update stamp',
              subtitle: updateStamp,
              subtitleMaxLines: 3,
              onTap: null,
            ),
          ],
        ),
      ),
    );
  }

  /// Writes the whole ledger to a file and hands it to the phone's share
  /// sheet, the same route the amortisation statement takes.
  ///
  /// This is not a nicety. Android's automatic cloud backup is switched OFF
  /// for Salapify on purpose (see the manifest), which is the right call for a
  /// file holding somebody's salary and the names of people who owe them
  /// money, and it has a consequence: without this, a lost phone loses
  /// everything. The export is what makes that decision honest.
  /// Shares the data file EXACTLY as it is, for the state where Salapify
  /// cannot read it.
  ///
  /// Deliberately a different filename and a different sentence from a normal
  /// backup, because it is a different thing: it may not import anywhere, and
  /// somebody filing it beside their good backups should be able to tell them
  /// apart six months later.
  Future<void> _exportRaw() async {
    setState(() => _busy = true);
    try {
      final String? raw = await state.rawStoredFile();
      if (raw == null || raw.trim().isEmpty) {
        _say(
          'There is no data file on this phone to send. Nothing has been '
          'deleted.',
        );
        return;
      }
      final String stamp = state.now.toIso8601String().split('T').first;
      try {
        final Directory dir = await getTemporaryDirectory();
        final File file = File('${dir.path}/salapify-unreadable-$stamp.json');
        await file.writeAsString(raw, flush: true);
        await Share.shareXFiles(<XFile>[
          XFile(file.path, mimeType: 'application/json'),
        ], subject: 'Salapify data file, unreadable, $stamp');
      } on Object {
        // Same fallback as the normal export, and for the same reason: a
        // missing plugin or a refused share must not be the thing that loses
        // the only copy worth having.
        await Clipboard.setData(ClipboardData(text: raw));
        _say(
          'Could not open the share sheet, so the file is on your clipboard '
          'instead. Paste it somewhere safe before doing anything else.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      // The body moved to export_backup.dart so the wipe sheet can offer the
      // same export at the moment it matters most, without a second copy of
      // the share plumbing drifting away from this one.
      await exportBackup(state: state, say: _say);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    final Palette p = Palette.of(state.theme);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: p.onAccent)),
          backgroundColor: p.accent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
  }
}

/// Where the ledger lives, and whether it is actually being written.
///
/// The full text of a failure lives HERE rather than on Home, which is the
/// founder's request. It is not hidden: Home still carries one line.
class _StorageStatus extends StatelessWidget {
  const _StorageStatus({
    required this.palette,
    required this.state,
    required this.problem,
  });

  final Palette palette;
  final FinancialState state;
  final String? problem;

  @override
  Widget build(BuildContext context) {
    // THREE states, not two. The first render of this panel showed "Your
    // entries are NOT being saved" over an empty body, because a store that
    // has not been restored yet has no problem AND is not saving, and the
    // two-way test read that as failure. An alarm with nothing under it is
    // worse than no alarm: it is frightening and it says nothing.
    // RECOVERY IS NOT FAILURE, and conflating them is a specific mistake the
    // old banner was careful not to make. When the last save was interrupted
    // the previous copy opens, everything is here except the final change,
    // and saving carries on working. Reporting that in the words used for
    // losing everything is how a beginner stops trusting the app over
    // something it handled correctly.
    final bool recovered = state.loadStatus == LoadStatus.recovered;
    final bool failed = problem != null && !recovered;
    final bool ok = problem == null && state.isSaving;
    final Color tint = failed
        ? palette.negative
        : recovered
        ? palette.accent
        : ok
        ? palette.positive
        : palette.textMuted;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                failed
                    ? Icons.warning_amber_rounded
                    : recovered
                    ? Icons.history
                    : ok
                    ? Icons.check_circle_outline
                    : Icons.hourglass_empty,
                size: 18,
                color: tint,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  failed
                      ? 'Your entries are NOT being saved'
                      : recovered
                      ? 'We opened your last saved copy'
                      : ok
                      ? 'Your entries are being saved to this phone'
                      : 'Still opening your data file',
                  style: AppType.rowTitle(palette).copyWith(color: tint),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            failed || recovered
                ? plainStorageProblem(problem!)
                : ok
                ? 'Everything stays in one file in Salapify’s own private '
                      'storage. No other app can read it, and it is not copied '
                      'to any cloud.'
                : 'Nothing has been written yet.',
            style: AppType.caption(palette),
          ),
          if (failed || recovered) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            // The raw text, kept because it is what makes a screenshot
            // diagnosable, and moved off Home because it is unreadable there.
            Text(
              problem!,
              style: AppType.caption(
                palette,
              ).copyWith(color: palette.textSecondary.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.palette, required this.title});

  final Palette palette;
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.sm),
    child: Text(title.toUpperCase(), style: AppType.kicker(palette)),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleMaxLines,
  });

  final Palette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  /// Cap the subtitle's height, for a row whose text is not written by hand.
  ///
  /// Null, the default, keeps every existing row exactly as it was: these
  /// subtitles are fixed copy somebody chose, and clipping them would hide
  /// words on a large font setting for no reason.
  ///
  /// The Update stamp row sets it, because its text changes every build and
  /// is written under time pressure. On Salapify 2 the stamp reached roughly
  /// forty lines and filled the founder's whole screen, and the row rendering
  /// it had no limit, so nothing pushed back until they looked at the phone.
  /// A test caps what can be WRITTEN and this caps what can be RENDERED;
  /// either one alone would have let that through.
  final int? subtitleMaxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Material(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.tile),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 20, color: palette.accent),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: AppType.rowTitle(palette)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppType.caption(palette),
                        maxLines: subtitleMaxLines,
                        overflow: subtitleMaxLines == null
                            ? null
                            : TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, size: 18, color: palette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The version, in ONE place, so a bug report has something to name.
///
/// There was no version anywhere in the app before this, which made every
/// future "it did this on mine" unanswerable. It is read from here rather
/// than from pubspec at runtime deliberately: package_info_plus is another
/// plugin and another native rebuild for a string that changes when somebody
/// decides it does.
const String appVersion = '3.0.0 early access';

/// What the figures are, and what they are not.
///
/// Salapify computes take-home pay, tax estimates, payoff dates and
/// forecasts, all from numbers a person typed in. None of those are official
/// determinations and none of them are regulated advice, and the app has to
/// say so somewhere a person can find rather than only in a store listing.
///
/// The "does not lend" sentence is doing specific work: the Philippines
/// removed dozens of lending apps from Google Play, and the route is
/// classification first and questions later. Salapify has a debt register and
/// loan calculators, which is exactly the shape a reviewer skims and
/// mis-files.
class _DisclaimerSheet extends StatelessWidget {
  const _DisclaimerSheet({required this.palette});

  final Palette palette;

  static Future<void> show(BuildContext context, Palette palette) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) => _DisclaimerSheet(palette: palette),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      palette: palette,
      icon: Icons.gavel_outlined,
      title: 'Not financial, tax or legal advice',
      subtitle: 'What Salapify can and cannot tell you',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Salapify works out its figures from the numbers you type in. '
            'Take-home pay, tax estimates, payoff dates, forecasts and the '
            'lessons are general information and arithmetic, not regulated '
            'financial, tax, investment or legal advice, and none of them is '
            'tailored to your situation.',
            style: AppType.body(palette),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'No figure in this app is an official assessment. The BIR, SSS, '
            'Pag-IBIG, PhilHealth, your employer and your bank each produce '
            'their own, and theirs is the one that counts. Check anything '
            'that matters with them.',
            style: AppType.body(palette),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Salapify does not lend money. It does not arrange, broker or '
            'refer loans, it does not handle investments, and it never moves, '
            'holds or transfers funds. The debt register and the loan '
            'calculators work on figures you entered about arrangements you '
            'already have, and no lender or institution ever sees them.',
            style: AppType.body(palette),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Where a lesson mentions a government programme or a kind of '
            'account, it is explaining how the thing works. It is not a '
            'recommendation to use it, and nobody pays Salapify to mention '
            'anything.',
            style: AppType.body(palette),
          ),
        ],
      ),
    );
  }
}
