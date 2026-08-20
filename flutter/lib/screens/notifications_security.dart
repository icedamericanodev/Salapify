// Notifications and security: reminders and the two lock/privacy switches,
// reached from Menu's SETTINGS card as one row. Adapted from the RN app's
// own app/notifications.js, which already learned this lesson once: these
// settings used to sit inline on the settings tab and made it "a very long
// scroll" (that file's own words). The fix there, and here, is not to
// collapse the content in place; it is to give it a real destination and
// leave one short, unmistakably tappable row behind on Menu, reusing the
// exact same "boxed row with a chevron" language every other Menu
// destination already uses (Privacy receipt, Diagnostics, New phone day),
// rather than a bespoke collapsed-section treatment nobody read as tappable.
//
// Nothing about how these settings are stored or applied changed: this file
// is the same _remindersCard/_appLockCard/_widgetPrivacyCard bodies (and the
// _ReminderRow they share) moved out of menu.dart, unmodified in substance.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/commitments.dart' show debtsWithSchedule;
import '../services/notifications.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/lock_gate.dart' show BiometricAuthenticator;
import '../widgets/salapify_icon.dart';
import '../widgets/section.dart';

class NotificationsSecurityScreen extends StatelessWidget {
  final SalapifyStore store;

  /// Test seam for the existing-debts reminder nudge below, null in real
  /// use where Reminders.supported decides (same pattern as onboarding's
  /// showNudge, for the same reason: the widget test platform is never
  /// Android or iOS, so Reminders.supported is always false there and the
  /// nudge could never be proven to render without a way to force it).
  final bool? showBillsNudge;

  const NotificationsSecurityScreen({
    super.key,
    required this.store,
    this.showBillsNudge,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Notifications and security')),
    body: SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
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
        ),
      ),
    ),
  );

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

    // Detailed reminders are a separate, opt-in choice: whether a reminder may
    // name the debt or person and the amount. Off by default. On reveals detail
    // only in the unlocked shade, never on the lock screen. Reschedule after so
    // already-queued reminders are rebuilt at the new detail level.
    Future<void> toggleDetail(bool value) async {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await store.setNotifDetailed(value);
        await Reminders.reschedule(store.data, DateTime.now());
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not save that, nothing changed. $e')),
        );
      }
    }

    // Collapsible per _ReminderRow below; the MergeSemantics/screen-reader
    // contract described there is unchanged.
    Widget row(String key, IconData icon, String title, String subtitle) =>
        _ReminderRow(
          icon: icon,
          title: title,
          subtitle: subtitle,
          value: store.notifOn(key),
          onChanged: (v) => toggle(key, v),
        );

    // f4.55 only offers the reminder at the moment a debt is saved, so a
    // debt that already existed before that shipped, or one somebody saved
    // and then declined the ask on, never gets asked again. This is the
    // same offer surfaced where it never expires: as long as Bills due is
    // off and at least one debt still has a resolvable due date, the
    // callout says so. It needs no settings flag of its own, unlike the
    // wizard's one-time ask; it is not an interruption someone can be
    // nagged by, only a fact shown on a screen they navigated to, and it
    // disappears the moment the reminder is on or every such debt is paid
    // off, self-healing exactly like the wizard preview and the Accounts
    // due line already do. Gated on Reminders.supported for the same reason
    // the wizard and onboarding gate it: asking a device that cannot show a
    // reminder is a question with no honest answer.
    final billsNudgeSupported = showBillsNudge ?? Reminders.supported;
    final needsReminder = billsNudgeSupported && !store.notifOn('bills')
        ? debtsWithSchedule(store.data['debts'], DateTime.now()).length
        : 0;

    Widget billsNudge() {
      final label = needsReminder == 1
          ? 'One of your debts has a due date but no reminder set yet.'
          : '$needsReminder of your debts have a due date but no reminder '
                'set yet.';
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Barako.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Barako.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(salapifyIcon('card'), color: Barako.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.caption.w6),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => toggle('bills', true),
                    style: TextButton.styleFrom(
                      foregroundColor: Barako.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text('Turn on Bills due'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gentle nudges on your phone, nothing sent anywhere. Pick the ones that help.',
              style: AppText.caption,
            ),
            const SizedBox(height: 14),
            row(
              'daily',
              salapifyIcon('editDate'),
              'Log reminder',
              'An evening nudge to log, skipped once you already did.',
            ),
            const Divider(height: 24),
            row(
              'payday',
              salapifyIcon('cash'),
              'Payday',
              'A morning ping on payday to plan the money before it goes.',
            ),
            const Divider(height: 24),
            if (needsReminder > 0) billsNudge(),
            row(
              'bills',
              salapifyIcon('card'),
              'Bills due',
              'A heads up before a card or loan is due, so no late fees.',
            ),
            const Divider(height: 24),
            row(
              'lookahead',
              salapifyIcon('stats'),
              'Cash flow heads up',
              'One evening warning when the plan ahead looks tight, so a '
                  'squeeze is never a surprise.',
            ),
            const Divider(height: 24),
            row(
              'collect',
              salapifyIcon('handshake'),
              'Money to collect',
              'A reminder when someone owes you and it is due.',
            ),
            const Divider(height: 24),
            row(
              'backup',
              salapifyIcon('save'),
              'Monthly backup',
              'A nudge on the 1st to save a fresh backup file, so a lost '
                  'phone is an errand, not a disaster.',
            ),
            const Divider(height: 24),
            row(
              'goals',
              salapifyIcon('goal'),
              'Goal check-in',
              'A gentle monthly nudge for the goals you are saving toward. '
                  'Whatever fits is enough.',
            ),
            const Divider(height: 24),
            row(
              'waiting',
              salapifyIcon('waiting'),
              'Paused purchase check-ins',
              'A ping when the 24 hours are up on something you paused in '
                  'Money mindset, so a paused decision is never forgotten.',
            ),
            const Divider(height: 24),
            row(
              'comeback',
              salapifyIcon('greeting'),
              'Come back',
              'A gentle nudge to return if you have been away a while. Never '
                  'fires while you are still opening the app.',
            ),
            const Divider(height: 24),
            _ReminderRow(
              icon: salapifyIcon('locked'),
              title: 'Show names and amounts',
              subtitle:
                  'Off by default. Reminders stay generic on your lock '
                  'screen. Turn on to include the name and amount, kept '
                  'off your lock screen and shown in the shade after you '
                  'unlock.',
              value: store.notifDetailed,
              onChanged: toggleDetail,
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
        // Same MergeSemantics rule as the reminder rows: the switch and its
        // explanation are one control to a screen reader, not a mystery
        // toggle next to some text.
        child: MergeSemantics(
          child: Row(
            children: [
              Icon(salapifyIcon('biometric'), color: Barako.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App lock', style: AppText.body.w7),
                    const SizedBox(height: 2),
                    Text(
                      'Ask for your fingerprint or face to open Salapify. Your '
                      'money stays private if someone else picks up your phone.',
                      style: AppText.caption,
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
              Icon(salapifyIcon('hidden'), color: Barako.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hide the amount on the home screen',
                      style: AppText.body.w7,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'The Salapify tile shows days to payday instead of pesos, '
                      'so nobody reads your money over your shoulder. The Log '
                      'button still works. App lock already does this on its '
                      'own.',
                      style: AppText.caption,
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
}

/// One reminder toggle: icon, title, switch, and an explanation that starts
/// collapsed unless the reminder is already on. Tapping the title area, not
/// the switch, expands or collapses the explanation; the switch is a
/// separate hit target outside that tap area, so turning a reminder on or
/// off never needs an extra tap first. Founder request, 2026-08-04: nine
/// reminders each carrying a two-to-three line explanation made Reminders
/// the longest scroll on the Menu screen; this is why the whole card moved
/// to its own screen (see the file header), but the per-row collapse still
/// pulls its weight here too since nine rows is still a lot in one place.
///
/// `_expanded` seeds from the CURRENT switch value, not always false: a
/// reminder someone already turned on is one they read and cared about
/// once, and collapsing it by default on the exact screen where they would
/// come back to reconsider it would be a small trust regression, even
/// though the switch itself never moves out of reach either way.
///
/// Unlike `_CollapsibleTool`/`CollapsibleCard` in insights.dart, the
/// subtitle here is never conditionally built or removed with
/// `if (_expanded)`. It stays mounted at all times and only animates to
/// zero height (AnimatedSize around an Align with heightFactor). Building it
/// conditionally would drop it from the widget tree, and the MergeSemantics
/// below merges only what is currently in the tree into one announcement
/// (title, subtitle, and switch state together): a screen-reader user would
/// then hear the subtitle only while it happened to be visually expanded,
/// silently reopening the exact unlabeled-switch gap the a11y sweep already
/// fixed once for this row.
class _ReminderRow extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ReminderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_ReminderRow> createState() => _ReminderRowState();
}

class _ReminderRowState extends State<_ReminderRow> {
  late bool _expanded = widget.value;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(widget.icon, color: Barako.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: AppText.label.w7,
                              ),
                            ),
                            ExcludeSemantics(
                              child: Icon(
                                _expanded
                                    ? salapifyIcon('collapse')
                                    : salapifyIcon('expand'),
                                size: 18,
                                color: Barako.muted,
                              ),
                            ),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topLeft,
                          // ClipRect is load-bearing, not decoration: Align
                          // shrinks its own layout box to heightFactor 0
                          // but never clips its child, so without this the
                          // subtitle keeps PAINTING at full size while
                          // laying out as if it took no space, overlapping
                          // the divider and the next row underneath it.
                          // Caught by actually rendering a collapsed row,
                          // not by reading the code.
                          child: ClipRect(
                            child: Align(
                              alignment: Alignment.topLeft,
                              heightFactor: _expanded ? 1 : 0,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  widget.subtitle,
                                  style: AppText.caption,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: widget.value,
            onChanged: widget.onChanged,
            activeThumbColor: Barako.onPrimary,
            activeTrackColor: Barako.primary,
            inactiveThumbColor: Barako.faint,
            inactiveTrackColor: Barako.border,
          ),
        ],
      ),
    );
  }
}
