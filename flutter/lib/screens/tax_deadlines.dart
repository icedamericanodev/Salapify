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
  /// The tap made in THIS visit, if any. Null means "read it from settings",
  /// which is what makes the yearly expiry work: a stored answer from last
  /// year stops being honoured the moment the year turns, without needing
  /// the screen to be disposed and rebuilt first.
  FilingBasis? _tapped;
  FilingBasis get _basis => _tapped ?? _stored();

  /// The remembered basis, but ONLY if it was recorded for the year we are
  /// in now.
  ///
  /// The 8% election is per taxable year and has to be re-signified every
  /// year. A bare remembered boolean meant someone who tapped "Yes, 8%" once
  /// would never be shown a percentage tax row again, silently, forever. The
  /// year is stored with the answer so the question comes back when the
  /// answer expires.
  FilingBasis _stored() {
    final s = widget.store.data['settings'];
    if (s is! Map) return FilingBasis.regular;
    if (s['taxBasisYear'] != widget.clock().year) return FilingBasis.regular;
    return switch (s['taxBasis']) {
      'eight' => FilingBasis.eightPercent,
      'vat' => FilingBasis.vatRegistered,
      _ => FilingBasis.regular,
    };
  }

  bool get _expired {
    final s = widget.store.data['settings'];
    if (s is! Map || s['taxBasis'] == null) return false;
    return s['taxBasisYear'] != widget.clock().year;
  }

  Future<void> _setBasis(FilingBasis value) async {
    setState(() => _tapped = value);
    // Remembered, but never blocking: if the write fails the screen still
    // shows the right list for this visit.
    try {
      await widget.store.setSetting('taxBasis', switch (value) {
        FilingBasis.regular => 'regular',
        FilingBasis.eightPercent => 'eight',
        FilingBasis.vatRegistered => 'vat',
      });
      await widget.store.setSetting('taxBasisYear', widget.clock().year);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final rows = taxDeadlines(widget.clock(), basis: _basis, count: 6);
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
            Text(
              'HOW ARE YOU FILING IN ${widget.clock().year}?',
              style: Barako.kickerStyle,
            ),
            const SizedBox(height: 8),
            if (_expired)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'You told us how you file in a previous year. That choice '
                  'covers one year at a time, so please set it again for '
                  '${widget.clock().year}.',
                  style: TextStyle(
                    color: Barako.primaryText,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (basis, label) in [
                  (FilingBasis.regular, 'Regular rates'),
                  (FilingBasis.eightPercent, '8% option'),
                  (FilingBasis.vatRegistered, 'VAT registered'),
                ])
                  _choice(label, _basis == basis, () => _setBasis(basis)),
              ],
            ),
            const SizedBox(height: 6),
            // liveRegion: tapping a basis silently swaps the whole list, so
            // a screen reader user otherwise gets no signal that anything
            // happened at all.
            Semantics(
              liveRegion: true,
              child: Text(
                _basisNote(),
                style: TextStyle(
                  color: Barako.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: Gap.xl),
            Kicker('WHAT IS NEXT'),
            const SizedBox(height: 8),
            for (final d in rows) _deadlineCard(d),
            const SizedBox(height: Gap.lg),
            Text(
              'File even if you earned nothing that quarter. A missed return '
              'is penalised on its own, separately from any tax due.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'If your annual tax came to more than ₱2,000 and you chose to '
              'pay it in two parts, the second part is due 15 October. That '
              'is a choice you make at filing time, so it is not in the list '
              'above.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'A deadline that lands on a weekend or a holiday usually moves '
              'to the next working day. Salapify shows the statutory date, so '
              'treat it as the earliest it could be due and check the BIR '
              'advisory for that filing.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: Gap.md),
            Text(
              'Dates as of 2026. This is not tax advice or a filing service, '
              'and it does not cover returns for staff you employ, taxes you '
              'withhold on rent or contractors, or VAT amounts. Confirm with '
              'the BIR or a licensed accountant before you file.',
              style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// The honest version of what each basis means, and what it does NOT mean.
  ///
  /// The first draft said the 8% "replaces the percentage tax, so the 2551Q
  /// rows are not yours to file", stated as fact. A tax professional listed
  /// three ways that is untrue for a real person, and every one of them ends
  /// in a surcharge. A screen may not make a categorical claim about someone's
  /// filing obligations on the strength of one tap.
  String _basisNote() => switch (_basis) {
    FilingBasis.regular =>
      'Percentage tax (2551Q) is included. Pick the 8% option if that is '
          'what you elected for this year, or VAT registered if your gross '
          'sales passed ₱3,000,000.',
    FilingBasis.eightPercent =>
      'The 8% takes the place of the 3% percentage tax for the year you '
          'elected it, so those quarters have no 2551Q. Three things still '
          'put one back on your list: a quarter from before you elected, a '
          'year you did not elect 8%, and going over ₱3,000,000, which moves '
          'you to VAT and makes the percentage tax due on the part before '
          'you crossed.',
    FilingBasis.vatRegistered =>
      'VAT filers file 2550Q and not 2551Q. Salapify does not compute the '
          '12% VAT itself, so work the amounts out with your accountant and '
          'use these dates for the timing.',
  };

  Widget _choice(String label, bool selected, VoidCallback onTap) => Material(
    color: selected ? Barako.primary : Barako.card,
    borderRadius: BorderRadius.circular(Radii.md),
    child: InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
          if (d.note != null) ...[
            const SizedBox(height: 6),
            Text(
              d.note!,
              style: TextStyle(
                color: Barako.primaryText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
