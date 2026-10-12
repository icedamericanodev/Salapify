import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/money.dart';
import '../../core/money/payday_schedule.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../models/models.dart';
import '../../state/financial_state.dart';
import '../shared/sheet_scaffold.dart';

/// Where somebody tells Salapify when they get paid.
///
/// This sheet exists because three screens asked for a payday and nothing in
/// the app could set one. The hero card said "Set your payday to see a daily
/// figure", Health Check offered "Tell Salapify when you get paid", and the
/// Safe to Spend sheet said "Payday not set", and every one of them was a
/// dead end. The per-day figure they all gate could not be earned by anybody
/// who cleared the sample data.
///
/// What is recorded here is a RULE, never a countdown. Founder direction,
/// 2026-09-20, on why the days are a choice rather than a constant: "give
/// them options since it differs per company. Sometime 15th and 30th,
/// sometimes 10th and 25th."
class PaydaySheet extends StatefulWidget {
  const PaydaySheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => PaydaySheet(state: state),
    );
  }

  @override
  State<PaydaySheet> createState() => _PaydaySheetState();
}

/// The five choices on the sheet (D37). Twice and once a month are one
/// stored kind, days of the month, told apart by how many days there are.
enum _Choice { twice, once, weekly, twoWeeks, none }

class _PaydaySheetState extends State<PaydaySheet> {
  late _Choice _choice;
  late int _first;
  late int _second;
  late int _weekday;
  late DateTime _anchor;
  late DateTime _until;
  late final TextEditingController _pay;

  DateTime get _today {
    final DateTime n = widget.state.now;
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();

    // Opens on what is already recorded, so editing a cycle is editing and
    // not retyping. A cycle with no rule yet opens on the common Philippine
    // sweldo, which is a starting point rather than an answer: nothing is
    // stored until Save is tapped. Every other choice starts somewhere
    // sensible too, so switching between them never shows an empty picker.
    final PaydayCycle c = widget.state.payday;
    final PaydaySchedule? s = widget.state.paydaySchedule;
    final List<int> days = c.paydayDays;

    _choice = switch (s?.kind) {
      PaydayKind.weekly => _Choice.weekly,
      PaydayKind.everyTwoWeeks => _Choice.twoWeeks,
      PaydayKind.lastUntil => _Choice.none,
      _ => days.length == 1 ? _Choice.once : _Choice.twice,
    };
    _first = days.isNotEmpty ? days.first : 15;
    _second = days.length > 1 ? days[1] : 30;
    _weekday = s?.weekday ?? DateTime.friday;
    // The LAST payday, not the stored anchor: an anchor saved in August is
    // still a valid rule in October but is not "your last payday", and the
    // picker only reaches back a month (qa-tester, 2026-10-12).
    _anchor = s?.kind == PaydayKind.everyTwoWeeks
        ? s!.pointsFrom(widget.state.now)?.last ?? s.date!
        : _today;
    // A week from today, so nobody faces a blank picker (financial-coach,
    // 2026-10-12). A date that has passed is replaced, never shown again.
    final DateTime? until = s?.kind == PaydayKind.lastUntil ? s!.date : null;
    _until = until != null && until.isAfter(_today) ? until : _plus(_today, 7);

    _pay = TextEditingController(
      // Whole pesos with no ".00", centavos with two places. The rule used to
      // be spelled out here; it lives on Money as `plain` now, because the
      // one sheet that spelled it out WRONG lost centavos.
      text: c.expectedIncome.isPositive ? c.expectedIncome.plain : '',
    );
  }

  @override
  void dispose() {
    _pay.dispose();
    super.dispose();
  }

  List<int> get _days =>
      _choice == _Choice.twice ? <int>[_first, _second] : <int>[_first];

  PaydaySchedule get _schedule => switch (_choice) {
    _Choice.twice || _Choice.once => PaydaySchedule(_days),
    _Choice.weekly => PaydaySchedule.weekly(_weekday),
    _Choice.twoWeeks => PaydaySchedule.everyTwoWeeks(_anchor),
    _Choice.none => PaydaySchedule.lastUntil(_until),
  };

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final PaydaySchedule schedule = _schedule;
    final PaydayPoints? points = schedule.pointsFrom(widget.state.now);
    final bool none = _choice == _Choice.none;

    return SheetScaffold(
      palette: p,
      icon: Icons.event_available_outlined,
      title: 'When do you get paid',
      subtitle: 'Salapify works the countdown out from this, every day.',
      footer: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: PrimaryButton(
          palette: p,
          label: 'Save',
          // A "last until" date must still be ahead; anything else is a
          // countdown of zero, which no screen should be handed.
          onTap: schedule.isUsable && points != null ? _save : null,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // FIVE CHOICES, so a Wrap of chips rather than a segmented row,
          // which at 320dp has no room for five labels.
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: <Widget>[
              for (final (_Choice c, String label) in const <(_Choice, String)>[
                (_Choice.twice, 'Twice a month'),
                (_Choice.once, 'Once a month'),
                (_Choice.weekly, 'Every week'),
                (_Choice.twoWeeks, 'Every two weeks'),
                (_Choice.none, 'No fixed payday'),
              ])
                _ChoiceChip(
                  key: Key('payday-choice-${c.name}'),
                  palette: p,
                  label: label,
                  selected: _choice == c,
                  onTap: () => setState(() => _choice = c),
                ),
            ],
          ),
          const SizedBox(height: Spacing.lg),

          ...switch (_choice) {
            _Choice.twice => <Widget>[
              // Wrapped rather than a Row, because at 320dp two labelled
              // pickers beside each other do not fit and a Row would overflow
              // instead of giving way.
              Wrap(
                spacing: Spacing.md,
                runSpacing: Spacing.md,
                children: <Widget>[
                  _DayPicker(
                    palette: p,
                    label: 'First payday',
                    value: _first,
                    onChanged: (int v) => setState(() => _first = v),
                  ),
                  _DayPicker(
                    palette: p,
                    label: 'Second payday',
                    value: _second,
                    onChanged: (int v) => setState(() => _second = v),
                  ),
                ],
              ),
            ],
            _Choice.once => <Widget>[
              _DayPicker(
                palette: p,
                label: 'Day of the month',
                value: _first,
                onChanged: (int v) => setState(() => _first = v),
              ),
            ],
            _Choice.weekly => <Widget>[
              Text('Which day', style: AppType.label(p)),
              const SizedBox(height: Spacing.xs),
              Wrap(
                spacing: Spacing.sm,
                runSpacing: Spacing.sm,
                children: <Widget>[
                  for (int d = 1; d <= 7; d++)
                    _ChoiceChip(
                      palette: p,
                      label: _weekdayNames[d - 1],
                      selected: _weekday == d,
                      onTap: () => setState(() => _weekday = d),
                    ),
                ],
              ),
            ],
            _Choice.twoWeeks => <Widget>[
              _DateButton(
                key: const Key('payday-anchor'),
                palette: p,
                label: 'Your last payday',
                date: _anchor,
                now: _today,
                onTap: () => _pick(
                  initial: _anchor,
                  first: _plus(_today, -31),
                  last: _today,
                  help: 'Your last payday',
                  onPicked: (DateTime d) => _anchor = d,
                ),
              ),
            ],
            _Choice.none => <Widget>[
              _DateButton(
                key: const Key('payday-until'),
                palette: p,
                label: 'Make my money last until',
                date: _until,
                now: _today,
                onTap: () => _pick(
                  initial: _until,
                  first: _plus(_today, 1),
                  last: _plus(_today, 90),
                  help: 'Make my money last until',
                  onPicked: (DateTime d) => _until = d,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                // The one line needed to read the choice: what the date is.
                'The day money next comes in: a payout, a client payment, a '
                'padala.',
                style: AppType.caption(p),
              ),
            ],
          },

          // ONLY when it applies. A standing note about short months under a
          // cycle of the 10th and the 25th is noise that teaches people to
          // stop reading the notes.
          if ((_choice == _Choice.twice || _choice == _Choice.once) &&
              _days.any((int d) => d > 28)) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              'February and the 30 day months pay on their last day instead.',
              style: AppType.caption(p),
            ),
          ],

          // NO TAKE-HOME FIELD WITHOUT A PAYDAY (D37.2). There is no amount
          // "each payday" to give, and expected income must never become
          // spending money for somebody whose income may not come.
          if (!none) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            SheetField(
              palette: p,
              label: 'Take-home pay each payday (optional)',
              controller: _pay,
              hint: '0.00',
              prefix: '₱ ',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              // The warning, not the lesson. Somebody typing a number into an
              // optional field deserves to know it moves the biggest figure in
              // the app before they type it, not after they notice.
              'Leave this blank and Salapify assumes nothing is coming in, '
              'which keeps Safe to Spend cautious. Filling it in raises that '
              'figure.',
              style: AppType.caption(p),
            ),
          ],

          if (points != null) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            _Preview(palette: p, points: points, kind: schedule.kind),
          ],

          // The way back out, and only once there is something to undo.
          if (widget.state.payday.hasRule) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            Center(
              child: TextButton(
                onPressed: _clear,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  child: Text(
                    'Remove my payday',
                    style: AppType.body(p).copyWith(color: p.textMuted),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pick({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required String help,
    required void Function(DateTime) onPicked,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      // Clamped into the range, because the picker asserts rather than
      // opening on a date outside it.
      initialDate: initial.isBefore(first)
          ? first
          : initial.isAfter(last)
          ? last
          : initial,
      firstDate: first,
      lastDate: last,
      helpText: help,
    );
    if (picked != null && mounted) setState(() => onPicked(picked));
  }

  void _save() {
    final double? typed = double.tryParse(_pay.text.replaceAll(',', '').trim());
    // tryFromDouble turns away a NaN, an Infinity and a figure too large to
    // be a peso amount, so only a real number reaches the positive test.
    final Money? pay = typed == null ? null : Money.tryFromDouble(typed);
    // A blank field is not zero income, it is no answer, and the engine
    // treats both the same way: it only counts expected income above zero.
    final Money? expected = pay != null && pay.isPositive ? pay : null;

    switch (_choice) {
      case _Choice.twice:
      case _Choice.once:
        widget.state.setPaydayRule(
          daysOfMonth: _days,
          expectedIncome: expected,
        );
      case _Choice.weekly:
        widget.state.setPaydayRule(weekday: _weekday, expectedIncome: expected);
      case _Choice.twoWeeks:
        widget.state.setPaydayRule(
          everyTwoWeeksFrom: _anchor,
          expectedIncome: expected,
        );
      case _Choice.none:
        widget.state.setPaydayRule(lastUntil: _until);
    }
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.state.setPaydayRule(daysOfMonth: const <int>[]);
    Navigator.of(context).pop();
  }
}

/// Calendar days, by the date's own fields: `add(Duration(days: n))` is a
/// day short where a clock goes back an hour (qa-tester, 2026-10-12).
DateTime _plus(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

const List<String> _weekdayNames = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// What the rule means, in the figures a person came here to see.
///
/// A figure and the short line needed to read it, which is what belongs on a
/// screen. The reason a 31st becomes a 28th is a lesson and lives in the
/// caution line above, and only when it is true of the chosen days.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.palette,
    required this.points,
    required this.kind,
  });

  final Palette palette;
  final PaydayPoints points;
  final PaydayKind kind;

  String get _days =>
      points.daysToNext == 1 ? 'Tomorrow' : 'In ${points.daysToNext} days';

  @override
  Widget build(BuildContext context) {
    final bool none = kind == PaydayKind.lastUntil;
    final String line = switch (kind) {
      // Not "last one was": for somebody with no payday there was no last
      // one, only today.
      PaydayKind.lastUntil =>
        'What you have now is spread over ${points.daysToNext} '
            '${points.daysToNext == 1 ? 'day' : 'days'}.',
      // The one after too, so somebody who meant "twice a month" sees two
      // dates fourteen days apart and notices (financial-coach, 2026-10-12).
      PaydayKind.everyTwoWeeks =>
        '$_days, then '
            '${formatPaydayLabel(_plus(points.next, 14))}. '
            'Last one was ${formatPaydayLabel(points.last)}.',
      _ => '$_days. Last one was ${formatPaydayLabel(points.last)}.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            none ? 'MONEY LASTS UNTIL' : 'NEXT PAYDAY',
            style: AppType.label(palette),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            formatPaydayLabel(points.next),
            style: AppType.amount(palette).copyWith(color: palette.textPrimary),
          ),
          Text(line, style: AppType.body(palette)),
        ],
      ),
    );
  }
}

/// A selectable pill, the look the Bills sheet's kind chips already use.
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    super.key,
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.control),
        child: Container(
          // No `alignment`: a Container given one and no width fills all it
          // is offered, which turns a Wrap of chips into full-width bars.
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? palette.accent : palette.surface,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? Colors.transparent : palette.border,
            ),
          ),
          child: Text(
            label,
            style: AppType.body(palette).copyWith(
              fontSize: 13,
              color: selected ? palette.onAccent : palette.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// A date, shown as a tappable field that opens the date picker.
class _DateButton extends StatelessWidget {
  const _DateButton({
    super.key,
    required this.palette,
    required this.label,
    required this.date,
    required this.now,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final DateTime date;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String iso = isoDateOf(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Semantics(
          button: true,
          label: '$label, ${formatDateLabel(iso, now: now)}. Change the date',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Radii.control),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.event_outlined, size: 18, color: palette.accent),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      formatDateLabel(iso, now: now),
                      style: AppType.rowTitle(palette),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A day of the month, 1 to 31.
///
/// A picker rather than a text field, so 45 and 0 cannot be typed at all.
/// `PaydaySchedule` drops both anyway, because it also reads stored files,
/// but a control that silently discards what somebody typed is its own
/// defect.
class _DayPicker extends StatelessWidget {
  const _DayPicker({
    required this.palette,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Palette palette;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppType.label(palette)),
          const SizedBox(height: Spacing.xs),
          DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            dropdownColor: palette.card,
            style: AppType.rowTitle(palette).copyWith(fontSize: 15),
            items: <DropdownMenuItem<int>>[
              for (int d = 1; d <= 31; d++)
                DropdownMenuItem<int>(value: d, child: Text(ordinalDay(d))),
            ],
            onChanged: (int? v) {
              if (v != null) onChanged(v);
            },
            decoration: InputDecoration(
              filled: true,
              fillColor: palette.card,
              // Matches SheetField, which lands at 48 and clears the 44 floor.
              contentPadding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: palette.accent, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "1st", "2nd", "3rd", "21st", "30th".
///
/// The teens are the trap: 11, 12 and 13 take "th" despite ending in 1, 2
/// and 3, so a naive last-digit rule produces "11st".
String ordinalDay(int d) {
  if (d >= 11 && d <= 13) return '${d}th';
  return switch (d % 10) {
    1 => '${d}st',
    2 => '${d}nd',
    3 => '${d}rd',
    _ => '${d}th',
  };
}
