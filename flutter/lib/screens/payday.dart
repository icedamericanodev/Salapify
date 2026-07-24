// Payday: where the user tells Salapify when they actually get paid.
//
// This screen exists because the app was asserting a payday it had only
// guessed. normalizeSchedule falls back to semimonthly 15/31, which is the
// common Philippine pattern and a perfectly fine assumption for a FORECAST
// ("your next payday is probably around then"). It is not fine for a CLAIM.
// The Home ritual card and the 9am push both said "It is payday" on the 15th
// and the month end to every user, including monthly earners paid on the 30th
// and the swing-income people Steady Pay is built for, who have no payday at
// all. Nothing in the app could correct it, because nothing ever wrote the
// setting.
//
// So: the guess stays for forecasts, the claim now requires this screen, and
// "my pay has no fixed date" is a first-class answer rather than a gap.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/schedule.dart' show hasExplicitPaydaySchedule;
import '../theme.dart';

const List<String> _weekdayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

class PaydayScreen extends StatefulWidget {
  final SalapifyStore store;
  const PaydayScreen({super.key, required this.store});

  @override
  State<PaydayScreen> createState() => _PaydayScreenState();
}

class _PaydayScreenState extends State<PaydayScreen> {
  // 'none' is a real answer, not an empty state.
  late String _mode;
  late int _dayA;
  late int _dayB;
  late int _monthlyDay;
  late int _weekday;
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final settings = widget.store.data['settings'];
    final s = settings is Map ? settings['paydaySchedule'] : null;
    final explicit = hasExplicitPaydaySchedule(widget.store.data);
    _mode = explicit ? (s as Map)['mode'] as String : 'none';
    final days = explicit && s is Map && s['days'] is List
        ? (s['days'] as List)
        : const [];
    _dayA = _clampDay(days.isNotEmpty ? days[0] : null, 15);
    _dayB = _clampDay(days.length > 1 ? days[1] : null, 31);
    _monthlyDay = _clampDay(explicit && s is Map ? s['day'] : null, 30);
    final w = explicit && s is Map ? s['weekday'] : null;
    _weekday = (w is int && w >= 0 && w <= 6) ? w : 5;
  }

  static int _clampDay(dynamic raw, int fallback) {
    final n = raw is int ? raw : int.tryParse('$raw');
    return (n != null && n >= 1 && n <= 31) ? n : fallback;
  }

  Map<String, dynamic>? _buildSchedule() {
    switch (_mode) {
      case 'semimonthly':
        return {
          'mode': 'semimonthly',
          'days': [_dayA, _dayB],
        };
      case 'monthly':
        return {'mode': 'monthly', 'day': _monthlyDay};
      case 'weekly':
        return {'mode': 'weekly', 'weekday': _weekday};
    }
    return null; // 'none'
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!widget.store.canWrite) {
      setState(
        () => _err =
            'Your saved data could not be read, so settings '
            'cannot be changed right now.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _err = null;
    });
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final schedule = _buildSchedule();
      if (schedule == null) {
        await widget.store.clearPaydaySchedule();
      } else {
        await widget.store.setPaydaySchedule(schedule);
      }
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              schedule == null
                  ? 'Saved. Salapify will not assume a payday.'
                  : 'Saved. Your payday plan will use this from now on.',
            ),
          ),
        );
      nav.pop();
    } catch (e) {
      // Never close the sheet on a failed write, and never leave the button
      // stuck: say what happened and let the user try again.
      if (!mounted) return;
      setState(() {
        _saving = false;
        _err = 'That did not save. Please try again.';
      });
      return;
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'Payday',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'When do you get paid?',
              style: TextStyle(
                fontFamily: Barako.displayFont,
                color: Barako.text,
                fontSize: 24,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Salapify uses this for the payday plan on Home, the payday '
              'reminder, and the cycle recap. Until you set it, none of those '
              'will claim it is payday, because a guess about your pay day is '
              'not worth much.',
              style: TextStyle(color: Barako.muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 20),
            _option(
              value: 'semimonthly',
              title: 'Twice a month',
              blurb: 'The usual 15th and end of month, or your own two dates.',
              detail: _mode == 'semimonthly'
                  ? Row(
                      children: [
                        Expanded(
                          child: _dayPicker(
                            label: 'First',
                            value: _dayA,
                            onChanged: (v) => setState(() => _dayA = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _dayPicker(
                            label: 'Second',
                            value: _dayB,
                            onChanged: (v) => setState(() => _dayB = v),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            _option(
              value: 'monthly',
              title: 'Once a month',
              blurb: 'One payday every month.',
              detail: _mode == 'monthly'
                  ? _dayPicker(
                      label: 'Day',
                      value: _monthlyDay,
                      onChanged: (v) => setState(() => _monthlyDay = v),
                    )
                  : null,
            ),
            _option(
              value: 'weekly',
              title: 'Every week',
              blurb: 'The same day each week.',
              detail: _mode == 'weekly'
                  ? DropdownButtonFormField<int>(
                      initialValue: _weekday,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Day'),
                      items: [
                        for (var i = 0; i < 7; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(_weekdayNames[i]),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _weekday = v ?? _weekday),
                    )
                  : null,
            ),
            _option(
              value: 'none',
              title: 'My pay has no fixed date',
              blurb:
                  'Freelance, gig work, selling, commissions. Salapify will '
                  'stop guessing, and Steady Pay in Insights is built for '
                  'exactly this.',
            ),
            if (_err != null) ...[
              const SizedBox(height: 12),
              Text(
                _err!,
                style: TextStyle(color: Barako.warningStrong, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Barako.primary,
                foregroundColor: Barako.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _saving ? 'Saving...' : 'Save',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayPicker({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (var d = 1; d <= 31; d++)
          DropdownMenuItem(
            value: d,
            // Day 31 means "the real last day", which is what the schedule
            // math already does when a month is shorter.
            child: Text(d == 31 ? 'End of month' : '$d'),
          ),
      ],
      onChanged: (v) => onChanged(v ?? value),
    );
  }

  Widget _option({
    required String value,
    required String title,
    required String blurb,
    Widget? detail,
  }) {
    final selected = _mode == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        color: selected ? Barako.surfaceRaised : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: selected ? Barako.primary : Barako.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _mode = value),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? Barako.primary : Barako.faint,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Barako.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Text(
                    blurb,
                    style: TextStyle(
                      color: Barako.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: detail,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
