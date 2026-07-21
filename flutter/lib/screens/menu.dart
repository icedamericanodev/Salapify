// Menu: the hub that keeps the dashboard clean. Everything that is not
// glance-level status lives here, grouped: the money screens (Accounts, Debts,
// Goals, the deeper Insights), the helpers (Ask Pan, Tools), personalize
// (mood), and your data (backup, build stamp). Reached as the last bottom tab.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/pressable_scale.dart';
import 'accounts.dart';
import 'debts.dart';
import 'goals.dart';
import 'overview.dart' show ExportScreen, ImportScreen;
import 'pan.dart';
import 'search.dart';
import 'tools.dart';
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
              Text('MENU',
                  style: TextStyle(
                      color: Barako.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3)),
              const SizedBox(height: 16),
              _navRow(
                icon: Icons.search,
                title: 'Search',
                blurb: 'Find any entry, account, or utang by name or amount.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        SearchScreen(store: store, onSwitchTab: onSwitchTab))),
              ),
              const SizedBox(height: 20),
              _kicker('MONEY'),
              const SizedBox(height: 8),
              _navRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Accounts',
                blurb: 'Your wallets, banks, and assets, all in one place.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => AccountsScreen(store: store))),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.credit_card_outlined,
                title: 'Debts',
                blurb:
                    'Cards and loans, payments split into interest and principal.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => DebtsScreen(store: store))),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.savings_outlined,
                title: 'Goals',
                blurb:
                    'Savings goals with progress bars and an honest monthly pace.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GoalsScreen(store: store))),
              ),
              const SizedBox(height: 20),
              _kicker('HELPERS'),
              const SizedBox(height: 8),
              _navRow(
                icon: Icons.chat_bubble_outline,
                title: 'Ask Pan',
                blurb:
                    'Your money questions, answered from your own data. Walang halong AI sa cloud.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        PanScreen(store: store, onSwitchTab: onSwitchTab))),
              ),
              const SizedBox(height: 10),
              _navRow(
                icon: Icons.handyman_outlined,
                title: 'Tools',
                blurb:
                    'Loan, tax, and take-home calculators, currency converter, notes, and lessons.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ToolsScreen(store: store))),
              ),
              if (store.canWrite) ...[
                const SizedBox(height: 20),
                _kicker('PERSONALIZE'),
                const SizedBox(height: 8),
                _appearanceCard(context),
              ],
              const SizedBox(height: 20),
              _kicker('YOUR DATA'),
              const SizedBox(height: 8),
              _backupCard(context),
              const SizedBox(height: 16),
              const UpdateCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kicker(String text) => Text(text,
      style: TextStyle(
          color: Barako.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2));

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
                      Text(title,
                          style: TextStyle(
                              color: Barako.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                      Text(blurb,
                          style: TextStyle(color: Barako.muted, fontSize: 12)),
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
    final (currentKey, currentMode) = resolveThemeChoice(store.data['settings']);
    Future<void> save(Future<void> Function() action) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await action();
      } catch (e) {
        messenger.showSnackBar(SnackBar(
            content: Text('Could not save that, nothing was changed. $e')));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kicker('THEME'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in barakoThemes)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: currentKey == t.key,
                    onSelected: (_) => save(() => store.setThemeKey(t.key)),
                    selectedColor: Barako.primary,
                    backgroundColor: Barako.background,
                    labelStyle: TextStyle(
                        color: currentKey == t.key
                            ? Barako.onPrimary
                            : Barako.textSecondary,
                        fontWeight: FontWeight.w600),
                    side: BorderSide(color: Barako.border),
                  ),
              ],
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
                        fontWeight: FontWeight.w600),
                    side: BorderSide(color: Barako.border),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('System follows your phone, going dark at night on its own.',
                style: TextStyle(color: Barako.faint, fontSize: 11, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _backupCard(BuildContext context) {
    void openImport() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ImportScreen(store: store)),
        );
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
                  color: Barako.textSecondary, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (store.hasData) ...[
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ExportScreen(store: store)),
                    ),
                    child: const Text('Export backup'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Barako.border),
                        foregroundColor: Barako.textSecondary),
                    onPressed: openImport,
                    child: const Text('Import backup'),
                  ),
                ] else
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Barako.primary,
                        foregroundColor: Barako.onPrimary),
                    onPressed: openImport,
                    child: const Text('Import backup'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
