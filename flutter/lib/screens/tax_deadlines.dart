// BIR filing dates for freelancers and the self-employed: what is next, how
// far away it is, and what each filing covers.
//
// State derived, deliberately. It reads the device date every time it opens,
// so it never depends on a notification having fired. Many Android phones kill
// background alarms silently, and "I missed my filing because the reminder did
// not arrive" is the worst possible way to learn an app is unreliable. Open
// the screen, see the truth.
//
// All the date logic is in money/taxdeadlines.dart, golden locked to the RN
// engine. Awareness only, never a filing service, and the screen says so
// rather than leaving it implied.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/taxdeadlines.dart';
import '../theme.dart';
import '../widgets/section.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

class TaxDeadlinesScreen extends StatefulWidget {
  final SalapifyStore store;

  /// Injectable clock, so a test can stand on a specific day. The app never
  /// passes it.
  final DateTime Function() clock;
  const TaxDeadlinesScreen({
    super.key,
    required this.store,
    this.clock = DateTime.now,
  });

  @override
  State<TaxDeadlinesScreen> createState() => _TaxDeadlinesScreenState();
}

class _TaxDeadlinesScreenState extends State<TaxDeadlinesScreen> {
  late bool _onEight = _storedEightPercent();

  /// Remembered from the tax calculator when the user has already told us
  /// they are on the 8% option, so the same person is not asked twice.
  bool _storedEightPercent() {
    final s = widget.store.data['settings'];
    return s is Map && s['taxOnEightPercent'] == true;
  }

  Future<void> _setEight(bool value) async {
    setState(() => _onEight = value);
    // Remembered, but never blocking: if the write fails the screen still
    // shows the right list for this visit.
    try {
      await widget.store.setSetting('taxOnEightPercent', value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final rows = taxDeadlines(
      widget.clock(),
      onEightPercent: _onEight,
      count: 6,
    );
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text(
          'BIR dates',
          style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'The filing dates a freelancer or self-employed taxpayer works '
              'to, counted from today. Salapify does not file anything for '
              'you and never sees your BIR account; this is here so a '
              'deadline never arrives as a surprise.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Gap.lg),
            Text('ARE YOU ON THE 8% OPTION?', style: Barako.kickerStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _choice('No, regular rates', !_onEight, () {
                    _setEight(false);
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _choice('Yes, 8%', _onEight, () => _setEight(true)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _onEight
                  ? 'The 8% replaces the percentage tax, so the 2551Q rows '
                        'are not yours to file.'
                  : 'Percentage tax (2551Q) is included. Pick the 8% option '
                        'if that is what you elected, and those rows drop.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: Gap.xl),
            Kicker('WHAT IS NEXT'),
            const SizedBox(height: 8),
            for (final d in rows) _deadlineCard(d),
            const SizedBox(height: Gap.lg),
            Text(
              'A deadline that lands on a weekend or a holiday usually moves '
              'to the next working day. Salapify shows the statutory date, so '
              'treat it as the earliest it could be due and check the BIR '
              'advisory for that filing.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choice(String label, bool selected, VoidCallback onTap) => Material(
    color: selected ? Barako.primary : Barako.card,
    borderRadius: BorderRadius.circular(Radii.md),
    child: InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: Barako.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Barako.onPrimary : Barako.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );

  Widget _deadlineCard(TaxDeadline d) {
    final soon = d.daysLeft <= 14;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: soon ? Barako.primary : Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  d.title,
                  style: TextStyle(
                    color: Barako.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                deadlineDaysLabel(d.daysLeft),
                style: TextStyle(
                  color: soon ? Barako.primaryText : Barako.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${d.form}  ${_fmtDate(d.date)}',
            style: TextStyle(color: Barako.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            d.what,
            style: TextStyle(color: Barako.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
