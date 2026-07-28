// Menu: the hub that keeps the dashboard clean. Everything that is not
// glance-level status lives here, grouped: the money screens (Accounts,
// Goals, the deeper Insights), the helpers (Ask Pan, Tools), personalize
// (mood), and your data (backup, build stamp). Reached from the header key
// on every tab. Debts has no tile here: it lives on the Utang tab.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/export_files.dart';
import '../data/store.dart';
import '../money/currencies.dart' show currencies;
import '../money/greeting.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/lock_gate.dart' show BiometricAuthenticator;
import '../widgets/section.dart';
import '../widgets/pan_mascot.dart';
import '../money/pan_mood.dart';
import '../widgets/nav_tile.dart';
import '../widgets/pressable_scale.dart';
import 'accounts.dart';
import 'categories.dart';
import 'appearance.dart';
import 'cashflow.dart';
import 'csv_import.dart';
import 'goals.dart';
import 'milestone_share.dart';
import 'new_phone_day.dart';
import 'overview.dart' show ExportScreen, ImportScreen;
import 'paluwagan.dart';
import 'pan.dart';
import 'privacy_receipt.dart';
import 'search.dart';
import 'payday.dart';
import 'recap_share.dart';
import 'recurring.dart';
import 'reports.dart';
import 'tools.dart';
import 'treats.dart';
import 'update_card.dart';
import 'shell.dart';

class MenuScreen extends StatelessWidget {
  final SalapifyStore store;

  /// Switch a bottom tab. A pushed screen that wants to jump to a tab (Insights
  /// to Utang, a search result to Utang) pops back to Menu first, then switches.
  final void Function(Destination)? onSwitchTab;

  /// Jumps to the Utang tab showing "Owed to me". Receivables taps land
  /// there specifically; plain onSwitchTab would open the "I owe" segment.
  final VoidCallback? onOpenReceivables;
  final VoidCallback? onOpenPayables;
  const MenuScreen({
    super.key,
    required this.store,
    this.onSwitchTab,
    this.onOpenReceivables,
    this.onOpenPayables,
  });

  @override
  Widget build(BuildContext context) {
    // A pushed route needs its own Scaffold. When Menu left the bottom bar it
    // was stripped of its Scaffold along with the other destinations, but the
    // destinations render inside the SHELL's Scaffold and a pushed route does
    // not: it rendered with no background surface at all. In dark mode that
    // happened to look almost right, which is why no eye caught it; the
    // contrast guideline did, sampling the title at 1.21 to 1. The AppBar also
    // carries the back button, and replaces the in-list ScreenHeader so the
    // word Menu is not on screen twice.
    //
    // Bottom padding drops to 32: a pushed route has no Log FAB to clear.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Menu',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _askPanBanner(context),
              const SizedBox(height: 20),
              Kicker('MONEY'),
              const SizedBox(height: Gap.md),
              // A grid, not sixteen stacked rows. The old shape reached the
              // eighth destination before running off the screen, so half the
              // app sat behind a scroll with nothing hinting it was there.
              NavTileGrid(
                tiles: [
                  NavTile(
                    icon: 'search',
                    label: 'Search',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(
                          store: store,
                          onSwitchTab: onSwitchTab,
                        ),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'wallet',
                    label: 'Accounts',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AccountsScreen(store: store),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'flow',
                    label: 'Cash flow',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CashFlowScreen(store: store),
                      ),
                    ),
                  ),
                  // No Debts tile: the Utang tab's "I owe" segment is the one
                  // home of that content since the Phase 1 merge, and a
                  // second door from Menu opened a pushed copy with no bottom
                  // bar. Founder approved the removal. Bonus: the MONEY grid
                  // is 8 tiles again, four clean rows.
                  NavTile(
                    icon: 'savings',
                    label: 'Goals',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GoalsScreen(store: store),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'group',
                    label: 'Paluwagan',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PaluwaganScreen(store: store),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'categories',
                    label: 'Categories',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CategoriesScreen(store: store),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'repeat',
                    label: 'Recurring',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecurringScreen(store: store),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'chart',
                    label: 'Reports',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReportsScreen(
                          store: store,
                          onSwitchTab: onSwitchTab,
                        ),
                      ),
                    ),
                  ),
                  // Payday joins MONEY rather than keeping a section of its
                  // own: a lone half-width tile under its own heading reads as
                  // a layout mistake. Still gated on canWrite, as before.
                  if (store.canWrite)
                    NavTile(
                      icon: 'calendar',
                      label: 'Payday',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PaydayScreen(store: store),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Kicker('HELPERS'),
              const SizedBox(height: Gap.md),
              NavTileGrid(
                tiles: [
                  NavTile(
                    icon: 'tools',
                    label: 'Tools',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ToolsScreen(store: store, onSwitchTab: onSwitchTab),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'gift',
                    label: 'Earn your treats',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TreatsScreen(store: store),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'share',
                    label: 'Share your month',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecapShareScreen(store: store),
                      ),
                    ),
                  ),
                  NavTile(
                    icon: 'celebrate',
                    label: 'Share a win',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MilestoneShareScreen(store: store),
                      ),
                    ),
                  ),
                ],
              ),
              if (store.canWrite) ...[
                const SizedBox(height: 20),
                Kicker('PERSONALIZE'),
                const SizedBox(height: 8),
                _appearanceRow(context),
                const SizedBox(height: 8),
                _currencyRow(context),
                const SizedBox(height: 20),
                Kicker('YOUR NAME'),
                const SizedBox(height: 8),
                _nameCard(context),
                const SizedBox(height: 20),
                Kicker('REMINDERS'),
                const SizedBox(height: 8),
                _remindersCard(context),
                const SizedBox(height: 20),
                Kicker('SECURITY'),
                const SizedBox(height: 8),
                _appLockCard(context),
                const SizedBox(height: 12),
                _widgetPrivacyCard(context),
              ],
              // Deliberately OUTSIDE the canWrite block. This screen is read
              // only and touches no user data, and a user whose stored data
              // failed to load is exactly the user most likely to want to
              // check what the app can reach on the network.
              const SizedBox(height: 20),
              Kicker('PRIVACY'),
              const SizedBox(height: 8),
              _navRow(
                icon: Icons.verified_user_outlined,
                title: 'Privacy receipt',
                blurb:
                    'Every connection this app can make, in plain words. Check it yourself with airplane mode.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PrivacyReceiptScreen()),
                ),
              ),
              const SizedBox(height: 20),
              Kicker('YOUR DATA'),
              const SizedBox(height: 8),
              _backupCard(context),
              _undoImportCard(context),
              // The save dialog and share sheet are native-only; on the web
              // preview both would fail, so the export card hides there.
              if (store.hasData && !kIsWeb) ...[
                const SizedBox(height: 12),
                _exportCard(context),
              ],
              const SizedBox(height: 12),
              _navRow(
                icon: Icons.phonelink_ring_outlined,
                title: 'New phone day',
                blurb:
                    'Moving phones? A two minute guided handoff, no cloud in the middle.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NewPhoneDayScreen(store: store),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _startFreshCard(context),
              const SizedBox(height: 16),
              UpdateCard(store: store),
            ],
          ),
        ),
      ),
    );
  }

  /// Ask Pan, promoted out of the list into a filled banner at the top.
  ///
  /// It used to be the ninth of sixteen identical rows, which put the one
  /// place you can ASK the app something below the fold and made it look like
  /// a screen rather than a conversation. Filled rather than outlined because
  /// it is the only thing on Menu that is an invitation instead of a
  /// destination, and it keeps its subtitle for the same reason: every other
  /// label says where you land, this one has to say what it is FOR.
  Widget _askPanBanner(BuildContext context) => PressableScale(
    child: Card(
      color: Barako.primary,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PanScreen(
              store: store,
              onSwitchTab: onSwitchTab,
              onOpenReceivables: onOpenReceivables,
              onOpenPayables: onOpenPayables,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Row(
            children: [
              // The disc is not decoration. Pan is a fixed orange and this
              // banner is filled with the accent, which on Barako is the SAME
              // orange, so without something behind him he dissolves into his
              // own background. A dark disc is what gives him an edge, and it
              // works on every theme because the fill is always the accent and
              // the disc is always darker than it.
              //
              // Excluded from semantics: the whole banner is already one
              // button announcing Ask Pan, so letting the mascot announce his
              // mood here would add a second, competing label to the same
              // target.
              ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Barako.background.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: PanMascot(mood: PanMood.calm, size: 56),
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Pan',
                      style: TextStyle(
                        color: Barako.onPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // Short on purpose. The title already says this is where
                      // you ask, so the subtitle only has to carry the thing
                      // the title cannot: that the answers never leave here.
                      'Answered from your own data, right on this phone.',
                      style: TextStyle(
                        color: Barako.onPrimary.withValues(alpha: 0.82),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(Icons.chevron_right, color: Barako.onPrimary, size: 20),
            ],
          ),
        ),
      ),
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

  /// Appearance lives on its own screen now, and this row is what is left.
  ///
  /// The blurb slot carries STATE, not a description: "Barako, System". Before
  /// this, nothing anywhere in the app could tell you which theme you were on
  /// without counting highlighted chips.
  Widget _appearanceRow(BuildContext context) {
    final (rawKey, currentMode) = resolveThemeChoice(store.data['settings']);
    final label = themeForKey(rawKey).label;
    final mode = appearanceModeLabels[currentMode] ?? currentMode;
    return _navRow(
      icon: Icons.palette_outlined,
      title: 'Appearance',
      blurb: '$label, $mode',
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => AppearanceScreen(store: store))),
    );
  }

  /// The display currency, PHP by default. Purely how amounts are DRAWN:
  /// nothing is ever converted, the offline-first currency design, and the
  /// picker sheet says so out loud before anyone taps.
  Widget _currencyRow(BuildContext context) {
    final settings = (store.data['settings'] as Map?) ?? const {};
    final code = (settings['currencyCode'] as String?) ?? 'PHP';
    final symbol = (settings['currency'] as String?) ?? '₱';
    return _navRow(
      icon: Icons.payments_outlined,
      title: 'Currency',
      blurb: '$code $symbol',
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: Barako.card,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                Text('CURRENCY', style: Barako.cardKickerStyle),
                const SizedBox(height: 6),
                Text(
                  'This only changes the sign in front of amounts. Nothing '
                  'is converted; your numbers stay exactly as you logged '
                  'them.',
                  style: TextStyle(
                    color: Barako.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                for (final c in currencies)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: 48,
                    title: Text(
                      '${c['code']}  ${c['symbol']}',
                      style: TextStyle(
                        color: Barako.text,
                        fontWeight: c['code'] == code
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: c['code'] == code
                        ? Icon(Icons.check, size: 18, color: Barako.primary)
                        : null,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(sheetContext).pop();
                      try {
                        await store.setCurrency(c['code']!, c['symbol']!);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not save that, nothing changed. $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
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

    // MergeSemantics, so the switch and its words are ONE thing to a screen
    // reader. A bare Switch announces "switch, on" with no hint of WHICH
    // reminder it controls; merged, it reads the title and subtitle too. The
    // a11y sweep caught this as an unlabeled tappable in Menu's middle band.
    Widget row(String key, IconData icon, String title, String subtitle) =>
        MergeSemantics(
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
          ),
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
              'Payday',
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
              'Money to collect',
              'A reminder when someone owes you and it is due.',
            ),
            const Divider(height: 24),
            row(
              'backup',
              Icons.save_outlined,
              'Monthly backup',
              'A nudge on the 1st to save a fresh backup file, so a lost '
                  'phone is an errand, not a disaster.',
            ),
          ],
        ),
      ),
    );
  }

  /// Set, change, or remove the greeting name.
  ///
  /// This row is what makes the Home ask genuinely skippable. Without it the
  /// only chance to give a name would be the welcome card, which disappears
  /// the moment there is any data, so skipping once would mean never being
  /// able to change your mind. Removing has to be as easy as setting: it is
  /// the one field here that is purely about how the app addresses a person.
  Widget _nameCard(BuildContext context) {
    final current = store.displayName;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        // The text gets the full width and the actions sit beneath it. Side by
        // side, two buttons squeezed the blurb into a narrow column that wrapped
        // across three ragged lines, which was obvious the moment it was
        // rendered and invisible in the code.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              current ?? 'Not set',
              style: TextStyle(
                color: current == null ? Barako.muted : Barako.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'How Pan greets you on Home. It never leaves this phone.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                if (current != null) ...[
                  TextButton(
                    onPressed: () => store.setDisplayName(null),
                    child: const Text('Remove'),
                  ),
                  const SizedBox(width: Gap.sm),
                ],
                TextButton(
                  onPressed: () => _editName(context, current),
                  child: Text(current == null ? 'Set' : 'Change'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context, String? current) async {
    // TextFormField rather than a TextField with a controller of our own, and
    // the reason is a real crash rather than a preference. Disposing a
    // controller as soon as showDialog returns looks correct and is not: the
    // dialog's exit ANIMATION is still running, the field still rebuilds
    // during it, and Flutter throws "A TextEditingController was used after
    // being disposed" every single time someone sets a name. TextFormField
    // owns its controller and tears it down on the right frame, which removes
    // the whole class of mistake instead of timing it correctly by hand.
    var typed = current ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextFormField(
          initialValue: current ?? '',
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: displayNameMaxLength,
          decoration: const InputDecoration(
            hintText: 'Your name',
            counterText: '',
          ),
          onChanged: (v) => typed = v,
          onFieldSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(typed),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // A cancel returns null and must change nothing. Clearing is done with
    // Remove, deliberately, so an accidental Save on an emptied field cannot
    // silently wipe a name the user meant to keep.
    if (result == null) return;
    if (normalizeDisplayName(result) == null) return;
    await store.setDisplayName(result);
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
        // Same MergeSemantics rule as the reminder rows: the switch and its
        // explanation are one control to a screen reader, not a mystery
        // toggle next to some text.
        child: MergeSemantics(
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
      ),
    );
  }

  /// The home screen tile's own privacy switch.
  ///
  /// It ships in the SAME release as the tile, never later, and that is a
  /// deliberate ordering rather than a nicety. The founder installs the APK,
  /// drags the tile onto the home screen, and their daily number is sitting
  /// there in public BEFORE any follow up patch could offer an off switch.
  /// That is not recoverable by shipping quickly afterwards.
  Widget _widgetPrivacyCard(BuildContext context) {
    final on = (store.data['settings'] as Map?)?['widgetHideAmount'] == true;
    Future<void> toggle(bool value) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await store.setWidgetHideAmount(value);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save that, nothing changed. $e')),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: MergeSemantics(
          child: Row(
            children: [
              Icon(Icons.visibility_off, color: Barako.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hide the amount on the home screen',
                      style: TextStyle(
                        color: Barako.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The Salapify tile shows days to payday instead of pesos, '
                      'so nobody reads your money over your shoulder. The Log '
                      'button still works. App lock already does this on its '
                      'own.',
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
            Kicker('EXPORT'),
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
            'Start fresh deletes every account, entry, IOU, goal, debt, and '
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
            Kicker('START FRESH'),
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

  /// The way back from a mistaken import. The store has always snapshotted the
  /// data an import replaced, but nothing could read that copy, so the dialog
  /// had to admit there was no undo. This row appears only when a copy really
  /// exists, so it is never a button that does nothing.
  Widget _undoImportCard(BuildContext context) {
    return FutureBuilder<bool>(
      future: store.hasPreviousImportCopy(),
      builder: (context, snap) {
        if (snap.data != true || !store.canWrite) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Kicker('AFTER AN IMPORT'),
                  const SizedBox(height: 8),
                  Text(
                    'Salapify kept a copy of the data your last import '
                    'replaced. You can put it back. What is on the phone now '
                    'becomes the kept copy instead, so you can switch back '
                    'again and nothing is thrown away.',
                    style: TextStyle(
                      color: Barako.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _confirmUndoImport(context),
                    child: const Text('Put back what the import replaced'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmUndoImport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text(
          'Put back the earlier data?',
          style: TextStyle(color: Barako.text),
        ),
        content: Text(
          'Everything on this phone right now will be swapped for the data '
          'your last import replaced. The current data is kept as the copy, '
          'so you can swap back if this was not what you wanted.',
          style: TextStyle(color: Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Put it back'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final done = await store.undoLastImport();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              done
                  ? 'Done. The earlier data is back, and the imported data is '
                        'now the kept copy.'
                  : 'There was nothing to put back.',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'That copy could not be read, so nothing was changed.',
            ),
          ),
        );
    }
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
            Kicker(store.hasData ? 'BACKUP' : 'BRING YOUR DATA OVER'),
            const SizedBox(height: 8),
            Text(
              store.hasData
                  ? 'Your data lives only on this phone. Save a backup file to Google Drive or Files, or copy the text, any time. Salapify imports it unchanged, so you always have a way back.'
                  : 'Bring your data over: choose a backup file, or paste the backup text from the current Salapify app. Everything comes over: accounts, entries, IOUs, goals, settings.',
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
                  // 48, the Android floor. Was 40 and shrinkwrapped, which no
                  // test had ever measured because it sits below the fold of a
                  // lazy list; the a11y suite now scrolls before it certifies.
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  foregroundColor: Barako.textSecondary,
                  minimumSize: const Size(0, 48),
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
