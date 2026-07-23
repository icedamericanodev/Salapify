// Menu: the hub that keeps the dashboard clean. Everything that is not
// glance-level status lives here, grouped: the money screens (Accounts, Debts,
// Goals, the deeper Insights), the helpers (Ask Pan, Tools), personalize
// (mood), and your data (backup, build stamp). Reached as the last bottom tab.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/export_files.dart';
import '../data/store.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/lock_gate.dart' show BiometricAuthenticator;
import '../widgets/screen_header.dart';
import '../widgets/pressable_scale.dart';
import 'accounts.dart';
import 'cashflow.dart';
import 'csv_import.dart';
import 'debts.dart';
import 'goals.dart';
import 'overview.dart' show ExportScreen, ImportScreen;
import 'paluwagan.dart';
import 'pan.dart';
import 'search.dart';
import 'recap_share.dart';
import 'recurring.dart';
import 'reports.dart';
import 'tools.dart';
import 'treats.dart';
import 'update_card.dart';

class MenuScreen extends StatelessWidget {
  final SalapifyStore store;

  /// Switch a bottom tab. A pushed screen that wants to jump to a tab (Insights
  /// to Utang, a search result to Utang) pops back to Menu first, then switches.
  final void Function(int)? onSwitchTab;
  const MenuScreen({super.key, required this.store, this.onSwitchTab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              ScreenHeader('MENU'),
              _navRow(
                icon: Icons.search,
                title: 'Search',
                blurb: 'Find any entry, account, or utang by name or amount.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SearchScreen(store: store, onSwitchTab: onSwitchTab),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _kicker('MONEY'),
              const SizedBox(height: 8),
              _navRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Accounts',
                blurb: 'Your wallets, banks, and assets, all in one place.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AccountsScreen(store: store),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.calendar_month_outlined,
                title: 'Cash flow',
                blurb:
                    'Your month ahead day by day: sweldo in, bills out, and the days your cash runs tight.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CashFlowScreen(store: store),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.credit_card_outlined,
                title: 'Debts',
                blurb:
                    'Cards and loans, payments split into interest and principal.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => DebtsScreen(store: store)),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.savings_outlined,
                title: 'Goals',
                blurb:
                    'Savings goals with progress bars and an honest monthly pace.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => GoalsScreen(store: store)),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.groups_outlined,
                title: 'Paluwagan',
                blurb:
                    'Your rotating savings groups, with your payout date and an honest read on your turn.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PaluwaganScreen(store: store),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.event_repeat_outlined,
                title: 'Recurring',
                blurb:
                    'Bills and income that log themselves every month, on their day.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecurringScreen(store: store),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.bar_chart_outlined,
                title: 'Reports',
                blurb:
                    'Your net worth, monthly income, and cash flow as three plain statements.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ReportsScreen(store: store, onSwitchTab: onSwitchTab),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _kicker('HELPERS'),
              const SizedBox(height: 8),
              _navRow(
                icon: Icons.chat_bubble_outline,
                title: 'Ask Pan',
                blurb:
                    'Your money questions, answered from your own data. Walang halong AI sa cloud.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PanScreen(store: store, onSwitchTab: onSwitchTab),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.handyman_outlined,
                title: 'Tools',
                blurb:
                    'Loan, tax, and take-home calculators, currency converter, notes, and lessons.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ToolsScreen(store: store)),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.emoji_events_outlined,
                title: 'Earn your treats',
                blurb:
                    'Pair a treat with a healthy habit and earn it guilt free. No pesos counted.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TreatsScreen(store: store)),
                ),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.ios_share_outlined,
                title: 'Share your month',
                blurb:
                    'Turn this month into a card you can post or send. You choose if amounts show.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecapShareScreen(store: store),
                  ),
                ),
              ),
              if (store.canWrite) ...[
                const SizedBox(height: 20),
                _kicker('PERSONALIZE'),
                const SizedBox(height: 8),
                _appearanceCard(context),
                const SizedBox(height: 20),
                _kicker('REMINDERS'),
                const SizedBox(height: 8),
                _remindersCard(context),
                const SizedBox(height: 20),
                _kicker('SECURITY'),
                const SizedBox(height: 8),
                _appLockCard(context),
              ],
              const SizedBox(height: 20),
              _kicker('YOUR DATA'),
              const SizedBox(height: 8),
              _backupCard(context),
              // The save dialog and share sheet are native-only; on the web
              // preview both would fail, so the export card hides there.
              if (store.hasData && !kIsWeb) ...[
                const SizedBox(height: 12),
                _exportCard(context),
              ],
              const SizedBox(height: 12),
              _startFreshCard(context),
              const SizedBox(height: 16),
              const UpdateCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kicker(String text) => Text(
    text,
    style: TextStyle(
      color: Barako.muted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    ),
  );

  Widget _navRow({
    required IconData icon,
    required String title,
    required String blurb,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Barako.primary, size: 20),
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
                      Text(
                        blurb,
                        style: TextStyle(color: Barako.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Barako.faint, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _modeLabels = {
    'system': 'System',
    'light': 'Light',
    'dark': 'Dark',
  };

  Widget _appearanceCard(BuildContext context) {
    final (rawKey, currentMode) = resolveThemeChoice(store.data['settings']);
    // Highlight the theme actually in effect: an unknown or future key renders
    // as Barako (themeForKey falls back), so the chip should show Barako too.
    final currentKey = themeForKey(rawKey).key;
    Future<void> save(Future<void> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Could not save that, nothing was changed. $e'),
          ),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('COLOR THEME'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in barakoThemes)
                  ChoiceChip(
                    // A two-tone swatch previews each theme: its own background
                    // field with its brand color inside. This separates the
                    // warm trio (Barako brown, Ember charcoal, Forest green
                    // fields) that all shared a near-identical orange dot.
                    avatar: _ThemeSwatch(t.resolve(Barako.current.brightness)),
                    label: Text(t.label),
                    selected: currentKey == t.key,
                    onSelected: (_) => save(() => store.setThemeKey(t.key)),
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.background,
                    labelStyle: TextStyle(
                      color: currentKey == t.key
                          ? Barako.onPrimary
                          : Barako.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: Barako.border),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              themeForKey(currentKey).hint,
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 16),
            _kicker('APPEARANCE'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in appearanceModes)
                  ChoiceChip(
                    label: Text(_modeLabels[m] ?? m),
                    selected: currentMode == m,
                    onSelected: (_) => save(() => store.setThemeMode(m)),
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.background,
                    labelStyle: TextStyle(
                      color: currentMode == m
                          ? Barako.onPrimary
                          : Barako.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: Barako.border),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'System follows your phone, going dark at night on its own.',
              style: TextStyle(color: Barako.faint, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _remindersCard(BuildContext context) {
    Future<void> toggle(String key, bool value) async {
      final messenger = ScaffoldMessenger.of(context);
      // Turning a reminder on needs the phone's notification permission. If it
      // is refused, leave the switch off and point at settings.
      if (value && !await Reminders.requestPermission()) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Allow notifications for Salapify in your phone settings, then try again.',
            ),
          ),
        );
        return;
      }
      try {
        await store.setNotifPref(key, value);
        await Reminders.reschedule(store.data, DateTime.now());
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save that, nothing changed. $e')),
        );
      }
    }

    Widget row(String key, IconData icon, String title, String subtitle) => Row(
      children: [
        Icon(icon, color: Barako.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Barako.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: store.notifOn(key),
          onChanged: (v) => toggle(key, v),
          activeThumbColor: Barako.onPrimary,
          activeTrackColor: Barako.primary,
          inactiveThumbColor: Barako.faint,
          inactiveTrackColor: Barako.border,
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gentle nudges on your phone, nothing sent anywhere. Pick the ones that help.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 14),
            row(
              'daily',
              Icons.edit_calendar_outlined,
              'Log reminder',
              'An evening nudge to log, skipped once you already did.',
            ),
            const Divider(height: 24),
            row(
              'payday',
              Icons.payments_outlined,
              'Sweldo day',
              'A morning ping on payday to plan the money before it goes.',
            ),
            const Divider(height: 24),
            row(
              'bills',
              Icons.credit_card_outlined,
              'Bills due',
              'A heads up before a card or loan is due, so no late fees.',
            ),
            const Divider(height: 24),
            row(
              'collect',
              Icons.handshake_outlined,
              'Utang to collect',
              'A reminder when someone owes you and it is due.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _appLockCard(BuildContext context) {
    final on = (store.data['settings'] as Map?)?['appLock'] == true;
    Future<void> toggle(bool value) async {
      final messenger = ScaffoldMessenger.of(context);
      if (value) {
        final auth = BiometricAuthenticator();
        // Only turn it on when the phone can actually unlock it, so App lock
        // never strands the owner behind a lock they cannot pass.
        if (!await auth.canLock()) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Set up a fingerprint or face unlock on your phone first, then turn this on.',
              ),
            ),
          );
          return;
        }
        // Confirm the unlock works right now, so nobody enables a lock they
        // cannot pass. A cancel leaves it off.
        if (!await auth.authenticate()) return;
      }
      try {
        await store.setAppLock(value);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save that, nothing changed. $e')),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.fingerprint, color: Barako.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App lock',
                    style: TextStyle(
                      color: Barako.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ask for your fingerprint or face to open Salapify. Your '
                    'money stays private if someone else picks up your phone.',
                    style: TextStyle(
                      color: Barako.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch(
              value: on,
              onChanged: toggle,
              activeThumbColor: Barako.onPrimary,
              activeTrackColor: Barako.primary,
              inactiveThumbColor: Barako.faint,
              inactiveTrackColor: Barako.border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportCard(BuildContext context) {
    // Each export offers the two honest destinations: straight to the phone
    // (the system save dialog, Downloads or any folder) or the share sheet.
    Future<void> run(
      BuildContext context,
      String label,
      Future<bool> Function() saveTask,
      Future<void> Function() shareTask,
    ) async {
      final messenger = ScaffoldMessenger.of(context);
      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          backgroundColor: Barako.background,
          title: Text(
            'Export $label',
            style: TextStyle(
              color: Barako.text,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('save'),
              child: Row(
                children: [
                  Icon(Icons.download, size: 20, color: Barako.primaryText),
                  const SizedBox(width: 12),
                  Text(
                    'Save to this phone',
                    style: TextStyle(color: Barako.text, fontSize: 15),
                  ),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop('share'),
              child: Row(
                children: [
                  Icon(Icons.ios_share, size: 20, color: Barako.primaryText),
                  const SizedBox(width: 12),
                  Text(
                    'Share (Drive, email, chat)',
                    style: TextStyle(color: Barako.text, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (choice == null) return;
      try {
        if (choice == 'save') {
          final saved = await saveTask();
          if (saved) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'Saved. Check your Downloads or the folder you picked.',
                ),
              ),
            );
          }
        } else {
          await shareTask();
        }
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not export $label. $e')),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('EXPORT'),
            const SizedBox(height: 8),
            Text(
              'Save your entries as a spreadsheet, or this month as a PDF report. '
              'Save straight to this phone, or share it to Files, Drive, or email.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Barako.border),
                    foregroundColor: Barako.text,
                  ),
                  icon: const Icon(Icons.grid_on, size: 18),
                  onPressed: () => run(
                    context,
                    'the CSV',
                    () =>
                        saveTransactionsCsvToDevice(store.data, DateTime.now()),
                    () => shareTransactionsCsv(store.data, DateTime.now()),
                  ),
                  label: const Text('CSV'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Barako.border),
                    foregroundColor: Barako.text,
                  ),
                  icon: const Icon(Icons.table_chart_outlined, size: 18),
                  onPressed: () => run(
                    context,
                    'the Excel file',
                    () => saveTransactionsXlsxToDevice(
                      store.data,
                      DateTime.now(),
                    ),
                    () => shareTransactionsXlsx(store.data, DateTime.now()),
                  ),
                  label: const Text('Excel'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Barako.border),
                    foregroundColor: Barako.text,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  onPressed: () => run(
                    context,
                    'the PDF',
                    () => saveReportPdfToDevice(store.data, DateTime.now()),
                    () => shareReportPdf(store.data, DateTime.now()),
                  ),
                  label: const Text('PDF report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // The most destructive action in the app, founder approved before it was
  // built. Two explicit confirmations, an offered backup first, and honest
  // copy about the safety net going too. Also the documented recovery path
  // when the stored data cannot be read.
  Widget _startFreshCard(BuildContext context) {
    Future<void> onStartFresh() async {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final first = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Barako.background,
          title: Text(
            'Erase everything?',
            style: TextStyle(
              color: Barako.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Start fresh deletes every account, entry, utang, goal, debt, and '
            'setting Salapify keeps on this phone, including the safety copy '
            'kept from your last import. There is no undo. If you might ever '
            'want this data back, save a backup first.',
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Barako.textSecondary),
              ),
            ),
            if (store.hasData)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('backup'),
                child: Text(
                  'Save a backup first',
                  style: TextStyle(
                    color: Barako.primaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop('erase'),
              child: Text(
                'Continue',
                style: TextStyle(
                  color: Barako.warningStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
      if (first == 'backup') {
        navigator.push(
          MaterialPageRoute(builder: (_) => ExportScreen(store: store)),
        );
        return;
      }
      if (first != 'erase') return;
      if (!context.mounted) return;
      final sure = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Barako.background,
          title: Text(
            'Last check',
            style: TextStyle(
              color: Barako.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This permanently erases all Salapify data on this phone and '
            'cancels your reminders. Are you sure?',
            style: TextStyle(
              color: Barako.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: Barako.textSecondary),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Barako.warningStrong,
                foregroundColor: Barako.onPrimary,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                'Yes, erase it all',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
      if (sure != true) return;
      try {
        await store.startFresh();
        await Reminders.cancelAll();
        messenger.showSnackBar(
          const SnackBar(content: Text('Everything erased. Fresh start.')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not erase everything. $e')),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('START FRESH'),
            const SizedBox(height: 8),
            Text(
              'Erase everything Salapify keeps on this phone and begin again '
              'from zero. This is also the way out if your stored data can no '
              'longer be read.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Barako.warningStrong),
                foregroundColor: Barako.warningStrong,
              ),
              onPressed: onStartFresh,
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: const Text(
                'Start fresh (erase everything)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupCard(BuildContext context) {
    void openImport() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ImportScreen(store: store)));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker(store.hasData ? 'BACKUP' : 'BRING YOUR DATA OVER'),
            const SizedBox(height: 8),
            Text(
              store.hasData
                  ? 'Your data lives only on this phone. Save a backup file to Google Drive or Files, or copy the text, any time. Salapify imports it unchanged, so you always have a way back.'
                  : 'Bring your data over: choose a backup file, or paste the backup text from the current Salapify app. Everything comes over: accounts, entries, utang, goals, settings.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            // Wrap, not Row: on a narrow phone or with a large system font, the
            // second button drops to its own line instead of overflowing the
            // edge (the striped overflow bug on ~360px budget phones).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (store.hasData) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ExportScreen(store: store),
                      ),
                    ),
                    child: const Text('Export backup'),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Barako.border),
                      foregroundColor: Barako.textSecondary,
                    ),
                    onPressed: openImport,
                    child: const Text('Import backup'),
                  ),
                ] else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                    ),
                    onPressed: openImport,
                    child: const Text('Import backup'),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: Barako.textSecondary,
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.table_view_outlined, size: 18),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CsvImportScreen(store: store),
                  ),
                ),
                label: const Text('Import from a bank or GCash CSV'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The theme picker swatch: the theme's own background field with its brand
// color inside, so each of the 8 chips reads as its own little app. Takes a
// resolved palette (passed in, not a live getter), so a const swatch is safe.
class _ThemeSwatch extends StatelessWidget {
  final BarakoPalette palette;
  const _ThemeSwatch(this.palette);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.border),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: palette.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
