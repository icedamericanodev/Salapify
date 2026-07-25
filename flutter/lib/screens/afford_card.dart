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
    // read (commas are thousands separators here). If more than one dot is left,
    // they are thousands separators too ("1.200.000"), so drop them; a single
    // dot stays a decimal point. The engine guards junk anyway.
    var cleaned = _controller.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if ('.'.allMatches(cleaned).length > 1) {
      cleaned = cleaned.replaceAll('.', '');
    }
    return double.tryParse(cleaned) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final r = affordCheck(
      widget.data,
      widget.ref,
      mode: _mode,
      amount: _amount,
      termMonths: _term,
    );
    final applicable = r['applicable'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CAN YOU AFFORD IT?', style: Barako.kickerStyle),
            const SizedBox(height: 6),
            Text(
              'Eyeing something? See what it does to your money before you commit.',
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
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
                style: TextStyle(color: Barako.muted, fontSize: 13),
              )
            else
              _verdict(r),
            const SizedBox(height: 14),
            Text(
              'This mirrors your own numbers against a typical and a lean month. It is not advice to buy. The final decision is yours.',
              style: TextStyle(color: Barako.faint, fontSize: 11, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  void _setMode(AffordMode m) {
    if (_mode == m) return;
    // Clear the amount: the same number means a one-time PRICE in one mode and a
    // MONTHLY payment in the other, so carrying it over would silently reinterpret
    // it and flash an alarming verdict. A fresh field makes the mode switch honest.
    setState(() {
      _mode = m;
      _controller.clear();
    });
  }

  Widget _modeChips() => Wrap(
    spacing: 8,
    children: [
      _choice(
        'Pay in full',
        _mode == AffordMode.oneTime,
        () => _setMode(AffordMode.oneTime),
      ),
      _choice(
        'Pay monthly',
        _mode == AffordMode.installment,
        () => _setMode(AffordMode.installment),
      ),
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
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _amountField() => TextField(
    controller: _controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    style: TextStyle(
      color: Barako.text,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
    decoration: InputDecoration(
      prefixText: '₱ ',
      prefixStyle: TextStyle(
        color: Barako.textSecondary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      hintText: _mode == AffordMode.installment ? 'Monthly amount' : 'Price',
      hintStyle: TextStyle(color: Barako.faint, fontSize: 16),
      filled: true,
      fillColor: Barako.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // Match the app's other input fields (14 radius, 1.4 focus ring).
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Barako.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Barako.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Barako.primary, width: 1.4),
      ),
    ),
  );

  // The verdict word, its color, and the honest lines behind it.
  Widget _verdict(Map<String, dynamic> r) {
    final verdict = r['verdict'] as String;
    final (word, color, icon) = _verdictHead(verdict);
    final lines = _mode == AffordMode.installment
        ? _installmentLines(r)
        : _oneTimeLines(r);

    // liveRegion so a screen reader announces the new verdict as the user types,
    // since it changes on keystroke, not on a self-announcing tap.
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The palette only offers three caution steps, so heavy and no-fit
          // share a red. A leading icon separates all four states without
          // relying on colour alone (accessibility, and clarity at a glance).
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    word,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: Barako.displayFont,
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final line in lines) ...[
            Text(
              line.$1,
              style: TextStyle(
                color: line.$2 ? color : Barako.text,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: line.$2 ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  // The verdict word, its colour, and a non-chromatic severity icon. The
  // 'comfortable' word depends on mode: for a one-time buy you literally hold
  // the cash, so "Kaya mo ito" is honest; for a plan it only means there is room
  // in the budget, never "go take on the debt", so it stays a room statement.
  (String, Color, IconData) _verdictHead(String verdict) => switch (verdict) {
    'comfortable' => (
      _mode == AffordMode.installment ? 'There is room' : 'You can afford this',
      Barako.primary,
      Icons.check_circle_outline,
    ),
    'tight' => ('Doable, but tight', Barako.warning, Icons.balance),
    'heavy' => (
      'Heavy on the budget',
      Barako.warningStrong,
      Icons.warning_amber_rounded,
    ),
    'no-fit' => ('Not yet affordable', Barako.warningStrong, Icons.block),
    _ => ('Not enough data yet', Barako.muted, Icons.help_outline),
  };

  // Each line: (text, isEmphasised). Emphasised lines take the verdict color.
  List<(String, bool)> _oneTimeLines(Map<String, dynamic> r) {
    final lines = <(String, bool)>[];
    final available = (r['availableNow'] as num).toDouble();
    final after = (r['availableAfter'] as num).toDouble();
    final eatsCushion = r['eatsCushion'] == true;
    if (!eatsCushion) {
      lines.add((
        'Leaves ${_peso(after)} of your ${_peso(available)} spendable cash until payday.',
        false,
      ));
    } else {
      final overflow = (r['overflow'] as num).toDouble();
      final cushionAfter = (r['cushionAfter'] as num).toDouble();
      final wipes = r['wipesCushion'] == true;
      lines.add((
        wipes
            ? 'This is more than all the money in your accounts (${_peso((r['buffer'] as num).toDouble())}), so it does not fit right now.'
            : 'This is past your ${_peso(available)} spendable cash until payday. ${_peso(overflow)} would come from savings or money set aside for bills, leaving ${_peso(cushionAfter)} across your accounts.',
        true,
      ));
    }
    final monthsLost = r['cushionMonthsLost'];
    if (monthsLost is num && monthsLost.isFinite && monthsLost > 0) {
      lines.add((
        'That is about ${_months(monthsLost.toDouble())} of your usual spending.',
        false,
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
        'I cannot tell yet how this fits your month. Log a few more paydays so a typical month is known, and check back.',
        true,
      ));
      if (total is num && total > 0) {
        lines.add((
          'That is ${_peso(total.toDouble())} in total over $term months.',
          false,
        ));
      }
      return lines;
    }
    final cur = r['currentShare'];
    final next = r['newShare'];
    if (cur is num && next is num && cur.isFinite && next.isFinite) {
      lines.add((
        'Your spoken-for money would go from ${_pct(cur.toDouble())} to ${_pct(next.toDouble())} of a typical month.',
        next >= 0.5,
      ));
    }
    final leanShare = r['newLeanShare'];
    final leanIsDistinct = r['leanIsDistinct'] == true;
    if (leanIsDistinct && leanShare is num && leanShare.isFinite) {
      // Only speak of a lean month when the user has actually HAD one leaner
      // than usual, so we never manufacture a downturn stress test the data
      // cannot support.
      final fitsLean = r['fitsLean'] == true;
      lines.add((
        leanShare > 1
            ? 'On your leaner months it would not even fit, taking ${_pct(leanShare.toDouble())} of what came in.'
            : fitsLean
            ? 'Even on your leaner months it stays manageable at ${_pct(leanShare.toDouble())}.'
            : 'On your leaner months it gets tight, taking ${_pct(leanShare.toDouble())} of what came in.',
        !fitsLean,
      ));
    } else {
      // Flat or too-little income history: say so plainly instead of implying a
      // resilience we have not seen.
      lines.add((
        'This assumes every payday is like your usual. You have not logged a leaner month yet.',
        false,
      ));
    }
    if ((r['shortNow'] as num) > 0) {
      lines.add((
        'The first payment does not fit your spendable cash right now, so it would come out of savings or bills.',
        true,
      ));
    }
    if (total is num && total > 0) {
      lines.add((
        'All in, that is ${_peso(total.toDouble())} over $term months.',
        false,
      ));
    }
    return lines;
  }

  // A peso ceiling past which real amounts stop meaning anything (a trillion).
  // Above it we say "more than your money can cover" rather than let an absurd
  // pasted amount saturate int64 into garbage like -₱9,223,372,036,854,775,808.
  static const double _pesoCeiling = 1e12;

  String _peso(double v) {
    if (!v.isFinite) return '₱--';
    if (v.abs() > _pesoCeiling) {
      return v < 0 ? '-₱1,000,000,000,000+' : '₱1,000,000,000,000+';
    }
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
    // Guard the PRODUCT, not just the input: a finite share can still overflow
    // to Infinity when multiplied, and round() on Infinity throws and would take
    // down the whole Insights tab.
    final p = share * 100;
    if (!p.isFinite) return '--';
    if (p > 100000) return '999%+';
    return '${p.round()}%';
  }

  String _months(double m) {
    // Same product guard as _pct: m is finite but m*10 can overflow.
    final scaled = m * 10;
    if (!scaled.isFinite) return 'many months';
    if (m > 1200) return 'over 1,000 months';
    // One decimal unless it is whole, so "0.5 months" and "2 months" both read.
    final rounded = scaled.round() / 10;
    final text = rounded % 1 == 0
        ? rounded.toInt().toString()
        : rounded.toString();
    return '$text ${rounded == 1 ? 'month' : 'months'}';
  }
}
