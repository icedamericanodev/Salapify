import 'package:flutter/material.dart';

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

class _PaydaySheetState extends State<PaydaySheet> {
  late bool _twice;
  late int _first;
  late int _second;
  late final TextEditingController _pay;

  @override
  void initState() {
    super.initState();

    // Opens on what is already recorded, so editing a cycle is editing and
    // not retyping. A cycle with no rule yet opens on the common Philippine
    // sweldo, which is a starting point rather than an answer: nothing is
    // stored until Save is tapped.
    final PaydayCycle c = widget.state.payday;
    final List<int> days = c.paydayDays;

    _twice = days.length != 1;
    _first = days.isNotEmpty ? days.first : 15;
    _second = days.length > 1 ? days[1] : 30;

    _pay = TextEditingController(
      text: c.expectedIncome > 0
          ? c.expectedIncome.toStringAsFixed(
              c.expectedIncome == c.expectedIncome.roundToDouble() ? 0 : 2,
            )
          : '',
    );
  }

  @override
  void dispose() {
    _pay.dispose();
    super.dispose();
  }

  List<int> get _days => _twice ? <int>[_first, _second] : <int>[_first];

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);
    final PaydaySchedule schedule = PaydaySchedule(_days);
    final PaydayPoints? points = schedule.pointsFrom(widget.state.now);

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
          onTap: schedule.isUsable ? _save : null,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SegmentedChoice<bool>(
            palette: p,
            selected: _twice,
            options: const <(bool, String)>[
              (true, 'Twice a month'),
              (false, 'Once a month'),
            ],
            onSelect: (bool v) => setState(() => _twice = v),
          ),
          const SizedBox(height: Spacing.lg),

          // Two pickers side by side when paid twice, one when paid once.
          // Wrapped rather than a Row, because at 320dp two labelled pickers
          // beside each other do not fit and a Row would overflow instead of
          // giving way.
          if (_twice)
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
            )
          else
            _DayPicker(
              palette: p,
              label: 'Day of the month',
              value: _first,
              onChanged: (int v) => setState(() => _first = v),
            ),

          // ONLY when it applies. A standing note about short months under a
          // cycle of the 10th and the 25th is noise that teaches people to
          // stop reading the notes.
          if (_days.any((int d) => d > 28)) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              'February and the 30 day months pay on their last day instead.',
              style: AppType.caption(p),
            ),
          ],

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

          if (points != null) ...<Widget>[
            const SizedBox(height: Spacing.lg),
            _Preview(palette: p, points: points),
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

  void _save() {
    final double? pay = double.tryParse(_pay.text.replaceAll(',', '').trim());

    widget.state.setPaydayRule(
      daysOfMonth: _days,
      // A blank field is not zero income, it is no answer, and the engine
      // treats both the same way: it only counts expected income above zero.
      expectedIncome: pay != null && pay > 0 ? pay : null,
    );
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.state.setPaydayRule(daysOfMonth: const <int>[]);
    Navigator.of(context).pop();
  }
}

/// What the rule means, in the two figures a person came here to see.
///
/// A figure and the short line needed to read it, which is what belongs on a
/// screen. The reason a 31st becomes a 28th is a lesson and lives in the
/// caution line above, and only when it is true of the chosen days.
class _Preview extends StatelessWidget {
  const _Preview({required this.palette, required this.points});

  final Palette palette;
  final PaydayPoints points;

  @override
  Widget build(BuildContext context) {
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
          Text('NEXT PAYDAY', style: AppType.label(palette)),
          const SizedBox(height: Spacing.xs),
          Text(
            formatPaydayLabel(points.next),
            style: AppType.amount(palette).copyWith(color: palette.textPrimary),
          ),
          Text(
            points.daysToNext == 1
                ? 'Tomorrow. Last one was ${formatPaydayLabel(points.last)}.'
                : 'In ${points.daysToNext} days. Last one was '
                      '${formatPaydayLabel(points.last)}.',
            style: AppType.body(palette),
          ),
        ],
      ),
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
