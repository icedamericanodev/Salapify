// The time slice control: All, Month, Year, or a Custom range.
//
// It holds no state. The parent owns a Period and gets a new one back through
// onChange, so every screen that adopts it shares one rule for what "this
// month" means. All the logic lives in money/period.dart and is golden locked
// against the live app.
//
// One deliberate difference from the RN original: the custom range is picked
// from a calendar, not typed as YYYY-MM-DD. Phase 2 batch 3 already removed
// typed ISO dates from the log sheet on the grounds that nobody should have to
// know what ISO means, and reintroducing them here would undo that for the one
// control most likely to be used by someone chasing a specific receipt.

import 'package:flutter/material.dart';

import '../money/period.dart';
import '../theme.dart';

class PeriodSelector extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChange;

  /// Whether to offer All time. Opt in, because a screen that only makes sense
  /// per month (a monthly budget) should not offer a slice it cannot draw.
  final bool allowAll;

  /// Injected so a test can pin what "this month" and "no stepping into the
  /// future" mean without waiting for the calendar to roll over.
  final DateTime Function() clock;

  // NOT const, the documented rule on every widget here that reads a Barako
  // getter during build. Dart canonicalizes const instances, so a const call
  // site lets Element.updateChild skip build() and freezes this control in the
  // previous theme's colours after a switch.
  // ignore: prefer_const_constructors_in_immutables
  PeriodSelector({
    super.key,
    required this.period,
    required this.onChange,
    this.allowAll = false,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  void _setMode(String next) {
    if (next == period.mode) return;
    final now = clock();
    onChange(switch (next) {
      PeriodMode.all => const Period.all(),
      PeriodMode.month => Period.monthOf(now),
      PeriodMode.year => Period.year(now.year.toString().padLeft(4, '0')),
      // Custom opens with both ends OPEN, which reads as All dates. Starting
      // it at today would silently hide everything the moment it is tapped.
      _ => const Period.custom(),
    });
  }

  Future<void> _pick(BuildContext context, {required bool isFrom}) async {
    final now = clock();
    final current = isFrom ? period.from : period.to;
    final parsed = current == null ? null : DateTime.tryParse(current);
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed ?? now,
      // Wide enough for a restored backup's oldest entry and for a bill dated
      // ahead. showDatePicker asserts in debug when initialDate falls outside
      // the range, which is why the bounds are generous rather than tidy.
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    onChange(
      Period(
        mode: PeriodMode.custom,
        from: isFrom ? iso : period.from,
        to: isFrom ? period.to : iso,
      ),
    );
  }

  void _clear(bool isFrom) => onChange(
    Period(
      mode: PeriodMode.custom,
      from: isFrom ? null : period.from,
      to: isFrom ? period.to : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final modes = <(String, String)>[
      // 'All time', not 'All'. On Activity this row sits directly above the
      // type filter row, whose first chip is also called All and is also
      // highlighted, so two orange chips called All stacked on top of each
      // other and neither said which was which. The render showed it; no test
      // did, and the test that DID trip over the ambiguity was rewritten to
      // scope past it, which silenced the only warning there was.
      if (allowAll) (PeriodMode.all, 'All time'),
      (PeriodMode.month, 'Month'),
      (PeriodMode.year, 'Year'),
      (PeriodMode.custom, 'Custom'),
    ];
    final stepping =
        period.mode == PeriodMode.month || period.mode == PeriodMode.year;
    // Never step into a month or year that cannot contain anything yet.
    final canForward =
        stepping && !periodIsFuture(shiftPeriod(period, 1), clock());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (key, label) in modes)
              ChoiceChip(
                label: Text(label),
                selected: period.mode == key,
                onSelected: (_) => _setMode(key),
                showCheckmark: false,
                backgroundColor: Barako.card,
                selectedColor: Barako.primary,
                side: BorderSide(color: Barako.border),
                labelStyle: TextStyle(
                  color: period.mode == key ? Barako.onPrimary : Barako.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
          ],
        ),
        if (stepping) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () => onChange(shiftPeriod(period, -1)!),
                icon: const Icon(Icons.chevron_left),
                color: Barako.text,
                tooltip: 'Previous period',
              ),
              Expanded(
                child: Text(
                  periodLabel(period),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Barako.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                // Disabled rather than hidden: a control that vanishes at the
                // edge of its range reads as a bug, and its neighbour then
                // jumps sideways under the thumb that was reaching for it.
                onPressed: canForward
                    ? () => onChange(shiftPeriod(period, 1)!)
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: Barako.text,
                disabledColor: Barako.faint,
                tooltip: 'Next period',
              ),
            ],
          ),
        ],
        if (period.mode == PeriodMode.custom) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _dateField(context, isFrom: true, label: 'From')),
              const SizedBox(width: 8),
              Expanded(child: _dateField(context, isFrom: false, label: 'To')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dateField(
    BuildContext context, {
    required bool isFrom,
    required String label,
  }) {
    final value = isFrom ? period.from : period.to;
    final set = value != null && value.isNotEmpty;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: Barako.border),
        foregroundColor: set ? Barako.text : Barako.muted,
        minimumSize: const Size(0, 48),
        alignment: Alignment.centerLeft,
      ),
      onPressed: () => _pick(context, isFrom: isFrom),
      child: Row(
        children: [
          Expanded(
            child: Text(
              // An unset end says what it MEANS rather than sitting blank:
              // leaving From empty is not an incomplete form, it is a choice
              // to include everything up to the other end.
              set ? value : (isFrom ? '$label: the start' : '$label: the end'),
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (set)
            GestureDetector(
              onTap: () => _clear(isFrom),
              child: Semantics(
                button: true,
                label: 'Clear $label date',
                child: Icon(Icons.close, size: 16, color: Barako.faint),
              ),
            ),
        ],
      ),
    );
  }
}
