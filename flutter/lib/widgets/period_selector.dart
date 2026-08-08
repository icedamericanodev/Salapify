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
import '../typography.dart';
import '../widgets/choice_chip.dart';
import '../widgets/salapify_icon.dart';

class PeriodSelector extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChange;

  /// Whether to offer All time. Opt in, because a screen that only makes sense
  /// per month (a monthly budget) should not offer a slice it cannot draw.
  final bool allowAll;

  /// Injected so a test can pin what "this month" and "no stepping into the
  /// future" mean without waiting for the calendar to roll over.
  final DateTime Function() clock;

  /// The latest date the caller's data actually contains, when it knows.
  /// Stepping normally stops at today, which is right for browsing, but it
  /// stranded rows dated ahead: a CSV imported with the day and month the
  /// wrong way round puts entries in the future, and the arrow refused to
  /// walk to them.
  final String? lastEntryDate;

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
    this.lastEntryDate,
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
    // Generous bounds for a restored backup's oldest entry and a bill dated
    // ahead. The first version made firstDate a constant and lastDate depend
    // on the clock, which INVERTS the range on a device whose clock is before
    // 1995: an Android with a dead RTC boots at 1970 and the picker asserted
    // "lastDate must be on or after firstDate". The comment here used to say
    // the bounds were generous BECAUSE showDatePicker asserts, so the hazard
    // was known and only half handled. Both ends now move together and the
    // initial date is clamped inside them, the pattern paluwagan.dart and
    // edit_sheet.dart already use.
    final first = DateTime(now.year - 30 < 2000 ? now.year - 30 : 2000);
    final last = DateTime(now.year + 5, 12, 31);
    var initial = parsed ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    final iso =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    var from = isFrom ? iso : period.from;
    var to = isFrom ? period.to : iso;
    // Picking the To end first and then a later From is a natural order, and
    // it produced a range that matches nothing at all with no hint on screen
    // that the ends were inverted. Swapping is what the person meant: they
    // picked two dates, and there is only one range those two dates describe.
    if (from != null && to != null && from.compareTo(to) > 0) {
      final swap = from;
      from = to;
      to = swap;
    }
    onChange(Period(mode: PeriodMode.custom, from: from, to: to));
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
    // Never step into a month or year that cannot contain anything, which
    // normally means past today. When the data itself reaches further, the
    // stop moves out to it rather than hiding rows the person really has.
    final next = shiftPeriod(period, 1);
    final canForward =
        stepping &&
        (!periodIsFuture(next, clock()) || _hasDataIn(next, lastEntryDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: [
            // The shared chip. Adopting it turns the checkmark cue ON here,
            // deliberately: selection was carried by color alone before,
            // and the check is the shape cue the chip contract requires.
            for (final (key, label) in modes)
              SalapifyChoiceChip(
                label: label,
                selected: period.mode == key,
                onSelected: (_) => _setMode(key),
              ),
          ],
        ),
        if (stepping) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                // A period step is a selection change and clicks like one.
                // The disabled forward arrow can never buzz a blocked step.
                onPressed: () {
                  Haptics.select();
                  onChange(shiftPeriod(period, -1)!);
                },
                icon: Icon(salapifyIcon('previous')),
                color: Barako.text,
                tooltip: 'Previous period',
              ),
              Expanded(
                child: Text(
                  periodLabel(period),
                  textAlign: TextAlign.center,
                  style: AppText.bodyStrong,
                ),
              ),
              IconButton(
                // Disabled rather than hidden: a control that vanishes at the
                // edge of its range reads as a bug, and its neighbour then
                // jumps sideways under the thumb that was reaching for it.
                onPressed: canForward
                    ? () {
                        Haptics.select();
                        onChange(shiftPeriod(period, 1)!);
                      }
                    : null,
                icon: Icon(salapifyIcon('forward')),
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

  /// Whether [last] falls on or after the start of [p]. Same lexical text
  /// comparison the engine uses, so the two can never disagree about which
  /// month a date belongs to.
  static bool _hasDataIn(Period? p, String? last) {
    if (p == null || last == null) return false;
    if (p.mode == PeriodMode.year) {
      return p.y != null &&
          last.length >= 4 &&
          last.substring(0, 4).compareTo(p.y!) >= 0;
    }
    if (p.mode == PeriodMode.month) {
      return p.ym != null &&
          last.length >= 7 &&
          last.substring(0, 7).compareTo(p.ym!) >= 0;
    }
    return false;
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
              // A real 48dp box around a deliberately small glyph. At 16dp a
              // miss of a few pixels hit the button behind it and opened a
              // full screen calendar, so the cost of missing was far worse
              // than the cost of the tap.
              child: Semantics(
                button: true,
                label: 'Clear $label date',
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    salapifyIcon('close'),
                    size: 16,
                    color: Barako.faint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
