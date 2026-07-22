// "Kaya mo ba ito?" the Afford-This card. The user names something they are
// eyeing, a one-time price or a monthly installment, and the card mirrors what
// it does to their real money: the spendable cash it takes before the next
// sweldo, the share of a typical month it spokes-for, whether it still fits a
// lean month, and how much emergency cushion a lump buy burns. It only reads;
// nothing is saved and no balance moves. The math is the golden-composed
// afford.dart engine; this file is purely the input and the honest phrasing.
//
// It is a mirror, not a salesman. The framing defaults to caution, every
// verdict carries its lean-month assumption, and there is no loan or lending
// vocabulary anywhere. The final call is always the user's.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../money/afford.dart';
import '../theme.dart';

class AffordCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final DateTime ref;
  const AffordCard({super.key, required this.data, required this.ref});

  @override
  State<AffordCard> createState() => _AffordCardState();
}

class _AffordCardState extends State<AffordCard> {
  final _controller = TextEditingController();
  AffordMode _mode = AffordMode.oneTime;
  int _term = 6;
  static const List<int> _terms = [3, 6, 12, 24];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _amount {
    // Strip anything that is not a digit or a dot, so "1,200" or "₱1200" still
    // read. The engine guards junk anyway; this just keeps typing forgiving.
    final cleaned =
        _controller.text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final r = affordCheck(widget.data, widget.ref,
        mode: _mode, amount: _amount, termMonths: _term);
    final applicable = r['applicable'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('KAYA MO BA ITO?', style: Barako.kickerStyle),
            const SizedBox(height: 6),
            Text(
                'Eyeing something? See what it does to your money before you commit.',
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            _modeChips(),
            const SizedBox(height: 12),
            _amountField(),
            if (_mode == AffordMode.installment) ...[
              const SizedBox(height: 12),
              Text('For how many months', style: Barako.kickerStyle),
              const SizedBox(height: 8),
              _termChips(),
            ],
            const SizedBox(height: 16),
            if (!applicable)
              Text(
                  _mode == AffordMode.installment
                      ? 'Enter the monthly amount to see if it fits your month.'
                      : 'Enter a price to see if it fits your spendable cash.',
                  style: TextStyle(color: Barako.muted, fontSize: 13))
            else
              _verdict(r),
            const SizedBox(height: 14),
            Text(
                'This mirrors your own numbers against a typical and a lean month. It is not advice to buy. Ang huling desisyon ay sa iyo.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.35)),
          ],
        ),
      ),
    );
  }

  Widget _modeChips() => Wrap(
        spacing: 8,
        children: [
          _choice('Pay in full', _mode == AffordMode.oneTime,
              () => setState(() => _mode = AffordMode.oneTime)),
          _choice('Pay monthly', _mode == AffordMode.installment,
              () => setState(() => _mode = AffordMode.installment)),
        ],
      );

  Widget _termChips() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in _terms)
            _choice('$t months', _term == t, () => setState(() => _term = t)),
        ],
      );

  Widget _choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onTap();
        },
        selectedColor: Barako.primary,
        backgroundColor: Barako.background,
        labelStyle: TextStyle(
            color: selected ? Barako.onPrimary : Barako.textSecondary,
            fontWeight: FontWeight.w600),
      );

  Widget _amountField() => TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        style: TextStyle(
            color: Barako.text, fontSize: 18, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          prefixText: '₱ ',
          prefixStyle: TextStyle(
              color: Barako.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
          hintText: _mode == AffordMode.installment ? 'Monthly amount' : 'Price',
          hintStyle: TextStyle(color: Barako.muted, fontSize: 16),
          filled: true,
          fillColor: Barako.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Barako.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Barako.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Barako.primary, width: 2),
          ),
        ),
      );

  // The verdict word, its color, and the honest lines behind it.
  Widget _verdict(Map<String, dynamic> r) {
    final verdict = r['verdict'] as String;
    final (word, color) = _verdictHead(verdict);
    final lines = _mode == AffordMode.installment
        ? _installmentLines(r)
        : _oneTimeLines(r);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(word,
              maxLines: 1,
              style: TextStyle(
                  fontFamily: Barako.displayFont,
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        for (final line in lines) ...[
          Text(line.$1,
              style: TextStyle(
                  color: line.$2 ? color : Barako.text,
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: line.$2 ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  (String, Color) _verdictHead(String verdict) => switch (verdict) {
        'comfortable' => ('Kaya mo ito', Barako.primary),
        'tight' => ('Kaya, pero masikip', Barako.warning),
        'heavy' => ('Mabigat sa budget', Barako.warningStrong),
        'no-fit' => ('Hindi pa kaya', Barako.warningStrong),
        _ => ('Kulang pa ang datos', Barako.muted),
      };

  // Each line: (text, isEmphasised). Emphasised lines take the verdict color.
  List<(String, bool)> _oneTimeLines(Map<String, dynamic> r) {
    final lines = <(String, bool)>[];
    final available = (r['availableNow'] as num).toDouble();
    final after = (r['availableAfter'] as num).toDouble();
    final eatsCushion = r['eatsCushion'] == true;
    if (!eatsCushion) {
      lines.add((
        'Leaves ${_peso(after)} of your ${_peso(available)} spendable cash until sweldo.',
        false
      ));
    } else {
      final overflow = (r['overflow'] as num).toDouble();
      final cushionAfter = (r['cushionAfter'] as num).toDouble();
      final wipes = r['wipesCushion'] == true;
      lines.add((
        wipes
            ? 'This is more than your spendable cash and would wipe out your ${_peso((r['buffer'] as num).toDouble())} emergency cushion.'
            : 'This goes past your spendable cash and dips ${_peso(overflow)} into your emergency cushion, leaving ${_peso(cushionAfter)}.',
        true
      ));
    }
    final monthsLost = r['cushionMonthsLost'];
    if (monthsLost is num && monthsLost.isFinite && monthsLost > 0) {
      lines.add((
        'That is about ${_months(monthsLost.toDouble())} of your usual spending.',
        false
      ));
    }
    return lines;
  }

  List<(String, bool)> _installmentLines(Map<String, dynamic> r) {
    final lines = <(String, bool)>[];
    final hasIncome = r['hasIncomeBase'] == true;
    final total = r['totalCost'];
    final term = r['termMonths'] as int;
    if (!hasIncome) {
      lines.add((
        'I cannot tell yet how this fits your month. Log a few more sweldo so a typical month is known, and check back.',
        true
      ));
      if (total is num && total > 0) {
        lines.add(
            ('That is ${_peso(total.toDouble())} in total over $term months.', false));
      }
      return lines;
    }
    final cur = r['currentShare'];
    final next = r['newShare'];
    if (cur is num && next is num && cur.isFinite && next.isFinite) {
      lines.add((
        'Your spoken-for money would go from ${_pct(cur.toDouble())} to ${_pct(next.toDouble())} of a typical month.',
        next >= 0.5
      ));
    }
    final leanShare = r['newLeanShare'];
    if (leanShare is num && leanShare.isFinite) {
      final fitsLean = r['fitsLean'] == true;
      lines.add((
        leanShare > 1
            ? 'On a lean month it would not even fit, taking ${_pct(leanShare.toDouble())} of what came in.'
            : fitsLean
                ? 'Even on a lean month it stays manageable at ${_pct(leanShare.toDouble())}.'
                : 'On a lean month it gets tight, taking ${_pct(leanShare.toDouble())} of what came in.',
        !fitsLean
      ));
    }
    if ((r['shortNow'] as num) > 0) {
      lines.add((
        'The first payment does not fit your spendable cash right now, so it would come out of savings or bills.',
        true
      ));
    }
    if (total is num && total > 0) {
      lines.add(
          ('All in, that is ${_peso(total.toDouble())} over $term months.', false));
    }
    return lines;
  }

  String _peso(double v) {
    if (!v.isFinite) return '₱$v';
    final n = v.round();
    final neg = n < 0;
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '${neg ? '-' : ''}₱$buf';
  }

  String _pct(double share) {
    if (!share.isFinite) return '--';
    final p = (share * 100).round();
    return '$p%';
  }

  String _months(double m) {
    if (!m.isFinite) return '--';
    // One decimal unless it is whole, so "0.5 months" and "2 months" both read.
    final rounded = (m * 10).round() / 10;
    final text = rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toString();
    return '$text ${rounded == 1 ? 'month' : 'months'}';
  }
}
