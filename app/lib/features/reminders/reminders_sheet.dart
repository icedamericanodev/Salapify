import 'package:flutter/material.dart';

import '../../core/money/reminders.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../info/info_dot.dart';
import '../info/info_sheet.dart';
import '../shared/sheet_scaffold.dart';

/// The bell, ported from `src/components/RemindersModal.tsx`.
///
/// Three tabs, the prototype's own: the tray of what has been raised, the
/// rules that decide what gets raised, and a test that puts one message in the
/// tray so a person can see the thing working.
///
/// ## The one sentence that stays on the screen
///
/// "These appear here when you open Salapify. Your phone does not buzz."
///
/// Everything else that TEACHES is behind the dot, per the screen rule. That
/// line is not teaching, it is the exception the rule names: somebody who
/// opens a screen headed Reminders will conclude their phone is going to
/// remind them, and silence would let them rely on it and miss a payment.
/// Sending a real Android notification needs a notification permission and a
/// native build, which is a founder decision rather than an afternoon.
///
/// ## What the prototype had that is deliberately NOT here
///
/// Its Rules tab ends with three delivery channels: browser notifications, an
/// in-app toast, and a synthesised audio chime. All three are web APIs. A
/// switch that says "Browser Web Notifications" on a phone is not a migration,
/// it is a dead control, and the prototype's own permission states
/// (GRANTED, DENIED) have no meaning in an app that has never asked for one.
class RemindersSheet extends StatefulWidget {
  const RemindersSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    // The sweep runs on the way IN, so opening the bell always shows what is
    // due right now rather than what was due when the app was last started.
    state.refreshReminders();
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => RemindersSheet(state: state),
    );
  }

  @override
  State<RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends State<RemindersSheet> {
  int _tab = 0;

  /// null means every kind.
  ReminderKind? _filter;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);

    return ListenableBuilder(
      listenable: widget.state,
      builder: (BuildContext context, _) => SheetScaffold(
        palette: p,
        icon: Icons.notifications_none,
        title: 'Reminders',
        subtitle: 'Daily logging, payments, bills and renewals',
        tabs: const <String>['Alerts', 'Rules', 'Test'],
        selectedTab: _tab,
        onSelectTab: (int i) => setState(() => _tab = i),
        child: switch (_tab) {
          0 => _AlertsTab(
            palette: p,
            state: widget.state,
            filter: _filter,
            onFilter: (ReminderKind? k) => setState(() => _filter = k),
          ),
          1 => _RulesTab(palette: p, state: widget.state),
          _ => _TestTab(palette: p, state: widget.state),
        },
      ),
    );
  }
}

/// One rule card's key, so a test can reach the switch that belongs to a rule
/// rather than the first switch it happens to find on the tab.
Key ruleKey(ReminderKind kind) => ValueKey<String>('rule-${kind.name}');

/// Every kind's icon, label and colour in one place, so a new kind cannot be
/// half added.
class _KindStyle {
  const _KindStyle(this.icon, this.label);
  final IconData icon;
  final String label;

  static const Map<ReminderKind, _KindStyle> of = <ReminderKind, _KindStyle>{
    ReminderKind.dailyExpense: _KindStyle(
      Icons.edit_calendar_outlined,
      'Daily log',
    ),
    ReminderKind.paymentDue: _KindStyle(
      Icons.credit_card_outlined,
      'Payment due',
    ),
    ReminderKind.billDue: _KindStyle(Icons.bolt_outlined, 'Bill'),
    ReminderKind.subscription: _KindStyle(Icons.autorenew, 'Renewal'),
  };
}

// ---------------------------------------------------------------------------
// 1. The tray
// ---------------------------------------------------------------------------

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({
    required this.palette,
    required this.state,
    required this.filter,
    required this.onFilter,
  });

  final Palette palette;
  final FinancialState state;
  final ReminderKind? filter;
  final ValueChanged<ReminderKind?> onFilter;

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> all = state.notifications;
    final List<AppNotification> shown = filter == null
        ? all
        : all.where((AppNotification n) => n.kind == filter).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HowTheyReachYou(palette: palette),
        const SizedBox(height: Spacing.md),
        _Filters(
          palette: palette,
          all: all,
          selected: filter,
          onSelect: onFilter,
        ),
        if (all.isNotEmpty) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          Row(
            children: <Widget>[
              if (state.unreadNotificationsCount > 0)
                _TextAction(
                  palette: palette,
                  icon: Icons.done_all,
                  label: 'Mark all read',
                  onTap: state.markAllNotificationsRead,
                ),
              const Spacer(),
              _TextAction(
                palette: palette,
                icon: Icons.delete_outline,
                label: 'Clear all',
                onTap: state.clearAllNotifications,
              ),
            ],
          ),
        ],
        const SizedBox(height: Spacing.md),
        if (shown.isEmpty)
          _Empty(palette: palette, filtered: filter != null)
        else
          for (final AppNotification n in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _NotificationCard(
                palette: palette,
                notification: n,
                onRead: () => state.markNotificationRead(n.id),
                onClear: () => state.clearNotification(n.id),
              ),
            ),
      ],
    );
  }
}

/// The honest line about delivery, and the only thing on this screen that is
/// not a figure or a message.
class _HowTheyReachYou extends StatelessWidget {
  const _HowTheyReachYou({required this.palette});

  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.phone_iphone, size: 18, color: palette.accent),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              'These appear here when you open Salapify. Your phone does not '
              'buzz.',
              style: AppType.body(palette).copyWith(color: palette.textPrimary),
            ),
          ),
          InfoDot(
            color: palette.accent,
            semanticLabel: 'How reminders work',
            onTap: () => InfoSheet.show(context, palette, InfoTopic.reminders),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.palette,
    required this.all,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final List<AppNotification> all;
  final ReminderKind? selected;
  final ValueChanged<ReminderKind?> onSelect;

  @override
  Widget build(BuildContext context) {
    // A Wrap, not a Row. Five pills at 1.5x system text do not fit a 320dp
    // phone in one line, and in a Row the last one would be clipped rather
    // than moved.
    return Wrap(
      spacing: Spacing.xs,
      runSpacing: Spacing.xs,
      children: <Widget>[
        _pill('All', all.length, selected == null, () => onSelect(null)),
        for (final MapEntry<ReminderKind, _KindStyle> e
            in _KindStyle.of.entries)
          _pill(
            e.value.label,
            all.where((AppNotification n) => n.kind == e.key).length,
            selected == e.key,
            () => onSelect(e.key),
          ),
      ],
    );
  }

  Widget _pill(String label, int count, bool on, VoidCallback onTap) {
    return Material(
      color: on ? palette.accent : palette.surfaceAlt,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          // 44 is the tap-target floor, enforced here rather than hoped for.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          // A Row with mainAxisSize.min, NOT `alignment: Alignment.center`.
          //
          // A Container with an alignment and no width fills everything it is
          // offered, and a Wrap offers its children the whole line. That made
          // five pills into five full width bars stacked down the screen. This
          // is the fourth time that exact shape has shipped in this
          // repository, which is why the comment is here and not in a commit
          // message. The Row centres vertically for free.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '$label ($count)',
                style: AppType.button(
                  palette,
                  color: on ? palette.onAccent : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.palette,
    required this.notification,
    required this.onRead,
    required this.onClear,
  });

  final Palette palette;
  final AppNotification notification;
  final VoidCallback onRead;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final _KindStyle style = _KindStyle.of[notification.kind]!;
    final bool unread = !notification.isRead;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: unread ? palette.surface : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(
          color: unread ? palette.accent : palette.border,
          width: unread ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(style.icon, size: 18, color: palette.accent),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      style.label.toUpperCase(),
                      style: AppType.kicker(palette),
                    ),
                    const SizedBox(height: 2),
                    Text(notification.title, style: AppType.rowTitle(palette)),
                  ],
                ),
              ),
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: Spacing.sm),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(notification.body, style: AppType.body(palette)),
          const SizedBox(height: Spacing.sm),
          Row(
            children: <Widget>[
              if (unread)
                _TextAction(
                  palette: palette,
                  icon: Icons.check,
                  label: 'Mark read',
                  onTap: onRead,
                ),
              const Spacer(),
              _TextAction(
                palette: palette,
                icon: Icons.close,
                label: 'Remove',
                onTap: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.palette, required this.filtered});

  final Palette palette;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: Column(
        children: <Widget>[
          Icon(Icons.notifications_none, size: 32, color: palette.textMuted),
          const SizedBox(height: Spacing.sm),
          Text(
            filtered ? 'Nothing of this kind' : 'Nothing to tell you',
            style: AppType.section(palette),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            filtered
                ? 'Tap All to see the rest.'
                : 'Nothing is due in the next few days, and today is logged. '
                      'Reminders land here as they come up.',
            style: AppType.caption(palette),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. The rules
// ---------------------------------------------------------------------------

class _RulesTab extends StatelessWidget {
  const _RulesTab({required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    final ReminderSettings s = state.reminderSettings;
    final String todayIso = _isoToday(state.now);
    final int loggedToday = state.transactions
        .where(
          (Transaction t) =>
              t.type == TransactionType.expense &&
              t.date.split('T').first == todayIso,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _RuleCard(
          palette: palette,
          icon: Icons.edit_calendar_outlined,
          key: ruleKey(ReminderKind.dailyExpense),
          title: 'Daily logging nudge',
          subtitle: 'If nothing has been entered by a time you choose',
          on: s.dailyExpenseEnabled,
          onChanged: (bool v) =>
              state.updateReminderSettings(s.copyWith(dailyExpenseEnabled: v)),
          detail: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _HourPicker(
                palette: palette,
                hour: s.dailyExpenseHour,
                onChanged: (int h) => state.updateReminderSettings(
                  s.copyWith(dailyExpenseHour: h, dailyExpenseMinute: 0),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                loggedToday > 0
                    ? 'Today: $loggedToday logged.'
                    : 'Today: nothing logged yet.',
                style: AppType.caption(palette),
              ),
            ],
          ),
        ),
        _RuleCard(
          palette: palette,
          icon: Icons.credit_card_outlined,
          key: ruleKey(ReminderKind.paymentDue),
          title: 'Payments you owe',
          subtitle: 'Debts, credit card cutoffs and payment plans',
          on: s.paymentDueEnabled,
          onChanged: (bool v) =>
              state.updateReminderSettings(s.copyWith(paymentDueEnabled: v)),
          detail: _DaysPicker(
            palette: palette,
            days: s.paymentDueDaysBefore,
            onChanged: (int d) => state.updateReminderSettings(
              s.copyWith(paymentDueDaysBefore: d),
            ),
          ),
        ),
        _RuleCard(
          palette: palette,
          icon: Icons.bolt_outlined,
          key: ruleKey(ReminderKind.billDue),
          title: 'Bills',
          subtitle: 'Electricity, water, internet, rent and dues',
          on: s.billEnabled,
          onChanged: (bool v) =>
              state.updateReminderSettings(s.copyWith(billEnabled: v)),
          detail: _DaysPicker(
            palette: palette,
            days: s.billDaysBefore,
            onChanged: (int d) =>
                state.updateReminderSettings(s.copyWith(billDaysBefore: d)),
          ),
        ),
        _RuleCard(
          palette: palette,
          icon: Icons.autorenew,
          key: ruleKey(ReminderKind.subscription),
          title: 'Subscription renewals',
          subtitle: 'Anything on Coming up that renews itself',
          on: s.subscriptionEnabled,
          onChanged: (bool v) =>
              state.updateReminderSettings(s.copyWith(subscriptionEnabled: v)),
          detail: _DaysPicker(
            palette: palette,
            days: s.subscriptionDaysBefore,
            onChanged: (int d) => state.updateReminderSettings(
              s.copyWith(subscriptionDaysBefore: d),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          'An overdue item keeps reminding you until it is paid or removed.',
          style: AppType.caption(palette),
        ),
      ],
    );
  }

  static String _isoToday(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    super.key,
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onChanged,
    required this.detail,
  });

  final Palette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool on;
  final ValueChanged<bool> onChanged;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: palette.accent),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppType.rowTitle(palette)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppType.caption(palette)),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Switch(
                value: on,
                onChanged: onChanged,
                activeThumbColor: palette.onAccent,
                activeTrackColor: palette.accent,
              ),
            ],
          ),
          if (on) ...<Widget>[const SizedBox(height: Spacing.md), detail],
        ],
      ),
    );
  }
}

/// How many days of warning. The prototype's own set, minus nothing.
class _DaysPicker extends StatelessWidget {
  const _DaysPicker({
    required this.palette,
    required this.days,
    required this.onChanged,
  });

  final Palette palette;
  final int days;
  final ValueChanged<int> onChanged;

  static const List<int> _choices = <int>[0, 1, 2, 3, 5];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Warn me', style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: <Widget>[
            for (final int d in _choices)
              _Chip(
                palette: palette,
                label: d == 0
                    ? 'On the day'
                    : d == 1
                    ? '1 day before'
                    : '$d days before',
                on: d == days,
                onTap: () => onChanged(d),
              ),
          ],
        ),
      ],
    );
  }
}

/// The hour of the daily nudge. Hours only, because a minute picker on a
/// nudge is precision nobody needs and one more thing to get wrong.
class _HourPicker extends StatelessWidget {
  const _HourPicker({
    required this.palette,
    required this.hour,
    required this.onChanged,
  });

  final Palette palette;
  final int hour;
  final ValueChanged<int> onChanged;

  static const List<int> _choices = <int>[18, 19, 20, 21, 22];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Nudge me after', style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.xs,
          runSpacing: Spacing.xs,
          children: <Widget>[
            for (final int h in _choices)
              _Chip(
                palette: palette,
                label: '${h - 12} PM',
                on: h == hour,
                onTap: () => onChanged(h),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.palette,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? palette.accent : palette.surface,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          // See _Filters._pill: no `alignment`, or the chip fills the line.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: AppType.button(
                  palette,
                  color: on ? palette.onAccent : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. The test
// ---------------------------------------------------------------------------

class _TestTab extends StatelessWidget {
  const _TestTab({required this.palette, required this.state});

  final Palette palette;
  final FinancialState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Put one message in the tray so you can see where reminders appear. '
          'It is marked as a test and nothing is actually due.',
          style: AppType.body(palette),
        ),
        const SizedBox(height: Spacing.md),
        for (final MapEntry<ReminderKind, _KindStyle> e
            in _KindStyle.of.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Material(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.tile),
              child: InkWell(
                onTap: () {
                  state.sendTestReminder(e.key);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Test added to the Alerts tab'),
                      backgroundColor: palette.accent,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(Radii.tile),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.all(Spacing.md),
                  child: Row(
                    children: <Widget>[
                      Icon(e.value.icon, size: 20, color: palette.accent),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Text(
                          'Test a ${e.value.label.toLowerCase()} reminder',
                          style: AppType.rowTitle(palette),
                        ),
                      ),
                      Icon(
                        Icons.play_arrow,
                        size: 18,
                        color: palette.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Palette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.tile),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 15, color: palette.accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppType.button(palette, color: palette.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
