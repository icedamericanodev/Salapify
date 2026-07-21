// Overview: the first real screen of the Flutter rebuild. Net worth from the
// same golden-verified netWorthParts the Reports use, the accounts list, and
// this month's income statement. Empty state offers the backup import (paste
// the text the RN Backup screen shows), so the founder's data carries over
// with zero extra plugins.

import 'dart:convert' show jsonDecode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../data/backup.dart';
import '../data/store.dart';
import '../money/coach.dart' as coach;
import '../money/statements.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';
import 'debts.dart';
import 'insights.dart';
import 'log_sheet.dart';
import 'search.dart';

String formatMoney(num value) {
  // A backup can smuggle near-max doubles whose SUMS overflow to Infinity.
  // round() throws on non-finite, which would take down the whole screen,
  // so render the raw word instead (the RN app shows the same garbage but
  // stays alive, and staying alive is the contract here).
  if (!value.isFinite) return '₱$value';
  final negative = value < 0;
  // A FINITE value near max double still overflows when scaled by 100 for
  // centavo rounding, and round() throws on the resulting Infinity. Same
  // contract: render the raw number, stay alive.
  final scaled = value.abs() * 100;
  if (!scaled.isFinite) return '₱$value';
  final rounded = scaled.round() / 100;
  var whole = rounded.floor();
  final cents = ((rounded - whole) * 100).round();
  final digits = whole.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  final centsPart = cents > 0 ? '.${cents.toString().padLeft(2, '0')}' : '';
  return '${negative ? '-' : ''}₱$buf$centsPart';
}

class OverviewScreen extends StatelessWidget {
  final SalapifyStore store;
  final void Function(int)? onSwitchTab;
  const OverviewScreen({super.key, required this.store, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    final data = store.data;
    final parts = netWorthParts(data);
    final istmt = incomeStatement(data, DateTime.now());
    final accounts =
        (data['accounts'] as List).cast<Map<String, dynamic>>();
    // The one thing to do about money right now, seen the moment Home opens.
    // Reuses the same coach decision layer Insights renders, so the two can
    // never disagree. Only once there is real data to reason about.
    final transactions = data['transactions'];
    final hasStarted = accounts.isNotEmpty ||
        (transactions is List && transactions.isNotEmpty);
    final checkIn =
        hasStarted ? coach.weeklyCheckIn(data, DateTime.now()) : null;

    return Scaffold(
      // No Log button until the store loaded cleanly: after a failed read,
      // saving would overwrite data we could not read, so the write path
      // stays closed (the store enforces it too; this hides the door).
      floatingActionButton: store.canWrite
          ? FloatingActionButton.extended(
              backgroundColor: Barako.primary,
              foregroundColor: Barako.onPrimary,
              onPressed: () => showLogSheet(context, store),
              icon: const Icon(Icons.add),
              label: Text('Log',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20),
          children: [
            SizedBox(height: 8),
            Row(
              children: [
                Text('₱',
                    style: TextStyle(
                        color: Barako.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
                SizedBox(width: 10),
                Text('SALAPIFY',
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.search, color: Barako.text),
                  tooltip: 'Search',
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SearchScreen(
                          store: store, onSwitchTab: onSwitchTab))),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (store.loadError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Your saved data could not be read, so nothing was overwritten. ${store.loadError}',
                    style: TextStyle(color: Barako.warning),
                  ),
                ),
              ),
            if (checkIn != null) ...[
              _checkInCard(context, checkIn),
              const SizedBox(height: 12),
            ],
            _netWorthHero(parts),
            const SizedBox(height: 16),
            if (!hasStarted)
              _welcomeCard(context)
            else ...[
              if (accounts.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kicker('MY MONEY'),
                        const SizedBox(height: 6),
                        for (final a in accounts)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                      a['name'] as String? ?? 'Account',
                                      style: TextStyle(
                                          color: Barako.text, fontSize: 16)),
                                ),
                                Text(formatMoney(amount(a['balance'])),
                                    style: TextStyle(
                                        color: Barako.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ])),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kicker('THIS MONTH'),
                      const SizedBox(height: 6),
                      _line('Income earned',
                          formatMoney(istmt['income'] as double)),
                      _line('Spending',
                          formatMoney(istmt['expenses'] as double)),
                      const Divider(),
                      _line('Net income',
                          formatMoney(istmt['netIncome'] as double),
                          strong: true,
                          color: (istmt['netIncome'] as double) >= 0
                              ? Barako.primary
                              : Barako.warning),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double amount(dynamic v) => v is num ? v.toDouble() : 0;

  Widget _kicker(String text) => Text(text,
      style: TextStyle(
          color: Barako.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2));

  // The bottom tabs a check-in action can jump straight to. Insights is no
  // longer a tab (it lives under Menu), so its route is handled by a push in
  // _checkInCard instead. Routes that are neither a tab nor handled there
  // (/goals, /learn) simply are not tappable from here.
  static const Map<String, int> _routeTabs = {
    '/': 0,
    '/budget': 1,
    '/receivables': 3,
  };

  /// The single most important money decision right now, or a calm all-clear,
  /// rendered at the top of Home. Mirrors the Insights decision card so the two
  /// read the same; tapping goes where the action points, a bottom tab or the
  /// Debts screen.
  Widget _checkInCard(BuildContext context, Map<String, dynamic> c) {
    final tone = c['tone'] as String;
    final action = c['action'];
    final route = action is Map ? action['route'] as String? : null;
    final tab = route != null ? _routeTabs[route] : null;
    VoidCallback? onTap;
    if (tab != null && onSwitchTab != null) {
      onTap = () => onSwitchTab!(tab);
    } else if (route == '/debts') {
      // Debts is not a bottom tab; a due-soon decision is prio 92, so it must
      // not be a dead end. Push the screen Home already imports.
      onTap = () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DebtsScreen(store: store)));
    } else if (route == '/insights') {
      // Insights moved off the bottom bar into Menu, so a forecast/overspend
      // decision pushes it as a route. It jumps to Utang from inside, so pop
      // this route first before switching the tab.
      onTap = () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InsightsScreen(
              store: store,
              onSwitchTab: onSwitchTab == null
                  ? null
                  : (i) {
                      Navigator.of(context).pop();
                      onSwitchTab!(i);
                    })));
    }
    final good = tone == 'good';
    // Same mapping as the Insights decision card: urgent and watch read as
    // "act", a nudge reads dimmer as "FYI".
    final titleColor = tone == 'urgent'
        ? Barako.warning
        : good
            ? Barako.primaryText
            : tone == 'watch'
                ? Barako.text
                : Barako.textSecondary;
    final dotColor = tone == 'urgent'
        ? Barako.warning
        : tone == 'nudge'
            ? Barako.muted
            : Barako.primary;
    final Widget card = Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kicker('MONEY CHECK-IN'),
              const SizedBox(height: 8),
              Row(
                children: [
                  // The all-clear wears a quiet check, not the attention dot,
                  // so calm reads softer than a real decision.
                  if (good)
                    Icon(Icons.check_circle_outline,
                        color: Barako.primary, size: 16)
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: dotColor, shape: BoxShape.circle),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(c['title'] as String,
                        style: TextStyle(
                            color: titleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: Barako.faint, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(c['message'] as String,
                  style: TextStyle(
                      color: Barako.textSecondary, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ),
    );
    // Only the tappable states get the press feel; the calm all-clear (no
    // action) stays still, so press feedback never lies about interactivity.
    return onTap == null ? card : PressableScale(child: card);
  }

  /// The dashboard hero. Now that the clutter moved to Menu, net worth is the
  /// headline: raised surface, bigger figure, and a negative total reads in the
  /// warning color so the sign lands instantly. Numbers come straight from the
  /// golden-locked netWorthParts, this only restyles them.
  Widget _netWorthHero(Map<String, dynamic> parts) {
    final nw = parts['netWorth'] as double;
    return Card(
      color: Barako.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('NET WORTH'),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(formatMoney(nw),
                  maxLines: 1,
                  style: TextStyle(
                      fontFamily: Barako.displayFont,
                      color: nw < 0 ? Barako.warning : Barako.primary,
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()])),
            ),
            const SizedBox(height: 4),
            Text(
                'Assets ${formatMoney(parts['assets'] as double)}  ·  Owed ${formatMoney(parts['liabilities'] as double)}',
                style: TextStyle(color: Barako.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// First-run card, shown in place of MY MONEY and THIS MONTH when there is no
  /// data yet. Keeps the "bring your data over" path one tap from Home now that
  /// the backup card lives under Menu.
  Widget _welcomeCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kicker('WELCOME'),
              const SizedBox(height: 8),
              Text('Wala pang laman, and that is okay.',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  'Tap Log below to add your first entry, or bring everything from your current Salapify app: Menu, then Backup.',
                  style: TextStyle(
                      color: Barako.textSecondary, fontSize: 14, height: 1.4)),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary),
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ImportScreen(store: store))),
                child: const Text('Import my backup'),
              ),
            ],
          ),
        ),
      );

  Widget _line(String label, String value,
          {bool strong = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: strong ? Barako.text : Barako.muted,
                    fontSize: 15,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
            Text(value,
                style: TextStyle(
                    color: color ?? Barako.textSecondary,
                    fontSize: 15,
                    fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );
}

class ExportScreen extends StatefulWidget {
  final SalapifyStore store;
  const ExportScreen({super.key, required this.store});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  // Built ONCE when the screen opens (a big store makes a big string, and
  // re-encoding it on every rebuild would jank). The store is never written
  // to from this screen.
  late final String text = widget.store.exportBackupText();

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final txns = (store.data['transactions'] as List).length;
    final accounts = (store.data['accounts'] as List).length;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: const Text('Export backup'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Everything in this app, as one block of text: $accounts ${accounts == 1 ? 'account' : 'accounts'}, $txns ${txns == 1 ? 'entry' : 'entries'}, utang, goals, settings. Copy it and keep it somewhere safe (notes, email to yourself). The current Salapify app imports it unchanged.',
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Barako.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Barako.border),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: TextStyle(
                          color: Barako.textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(text: text));
                    messenger.showSnackBar(const SnackBar(
                        content: Text(
                            'Copied. Paste it somewhere safe, like a note or an email to yourself.')));
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy backup text',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImportScreen extends StatefulWidget {
  final SalapifyStore store;
  const ImportScreen({super.key, required this.store});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final controller = TextEditingController();
  String? error;
  bool busy = false;

  Future<void> _import() async {
    // Validate BEFORE the scary dialog, like the RN app: garbage should get
    // the JSON error, never a replace-everything confirm.
    try {
      parseBackupObject(jsonDecode(controller.text.trim()));
    } on NewerBackupException catch (e) {
      setState(() => error = e.message);
      return;
    } on NotABackupException catch (e) {
      setState(() => error = e.message);
      return;
    } on FormatException {
      setState(() => error =
          'That text is not valid JSON. Copy the whole backup from the Backup screen and paste it unchanged.');
      return;
    }
    // Importing over existing data replaces EVERYTHING in one tap, the most
    // destructive action in the app, so it confirms first, the same standard
    // the RN app holds for replaceAll. A snapshot of the outgoing data is
    // kept on disk by the store, but a stray tap should never need it.
    if (widget.store.hasData) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Barako.card,
          title: Text('Replace everything?',
              style: TextStyle(color: Barako.text)),
          content: Text(
            'Everything currently in this preview app will be replaced by '
            'what you pasted. The replaced data is kept on this phone until '
            'your next import, but there is no undo button.',
            style: TextStyle(color: Barako.textSecondary),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Cancel',
                    style: TextStyle(color: Barako.muted))),
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Replace',
                    style: TextStyle(color: Barako.warning))),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.importBackupText(controller.text.trim());
      if (mounted) Navigator.of(context).pop();
    } on NewerBackupException catch (e) {
      setState(() => error = e.message);
    } on NotABackupException catch (e) {
      setState(() => error = e.message);
    } on FormatException {
      setState(() => error =
          'That text is not valid JSON. Copy the whole backup from the Backup screen and paste it unchanged.');
    } catch (e) {
      // The snapshot or save failed; the store aborted or rolled back, so
      // nothing was replaced. Say so instead of failing silently.
      setState(() =>
          error = 'Could not import, so nothing was changed. $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: const Text('Import backup'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the backup text from the current Salapify app (Backup screen, copy button). Importing replaces what is in this preview app only; your current app is untouched.',
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                      color: Barako.text, fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: '{"app":"salapify", ...}',
                    hintStyle: TextStyle(color: Barako.faint),
                    filled: true,
                    fillColor: Barako.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Barako.border),
                    ),
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style:
                        TextStyle(color: Barako.warning, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary),
                  onPressed: busy ? null : _import,
                  child: Text(busy ? 'Importing...' : 'Import'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
