// The Windfall Split Planner card. A lump landed (13th month, bonus, tax refund,
// paluwagan payout), and this shows a sound way to split it: set aside what you
// need soon, then pour the rest through cushion, costliest debt, fuller fund, and
// goals, with the remainder honestly marked as yours. The math is the pure
// windfall.dart engine; this file is only the inputs and phrasing. It only reads:
// nothing is posted, no balance moves, and a windfall never feeds a monthly
// figure. A guide the user acts on by hand.

import 'package:flutter/material.dart';

import '../money/windfall.dart';
import '../theme.dart';

class WindfallCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final DateTime ref;
  const WindfallCard({super.key, required this.data, required this.ref});

  @override
  State<WindfallCard> createState() => _WindfallCardState();
}

class _WindfallCardState extends State<WindfallCard> {
  final _amount = TextEditingController();
  final _setAside = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _setAside.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) {
    var cleaned = c.text.replaceAll(RegExp(r'[^0-9.]'), '');
    if ('.'.allMatches(cleaned).length > 1) cleaned = cleaned.replaceAll('.', '');
    return double.tryParse(cleaned) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final r = splitWindfall(widget.data, widget.ref,
        amount: _parse(_amount), setAside: _parse(_setAside));
    final applicable = r['applicable'] == true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAY NATANGGAP NA MALAKI?', style: Barako.kickerStyle),
            const SizedBox(height: 6),
            Text(
                'A 13th month, bonus, tax refund, or paluwagan payout? See a sound way to split it before it disappears.',
                style: TextStyle(
                    color: Barako.textSecondary, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            _field(_amount, 'How much landed'),
            const SizedBox(height: 10),
            Text('Set aside first, optional', style: Barako.kickerStyle),
            const SizedBox(height: 4),
            Text(
                'Money you already need soon: gifts, tuition, premiums, a paluwagan turn, or ongoing hulog.',
                style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.3)),
            const SizedBox(height: 6),
            _field(_setAside, 'Amount to keep aside'),
            const SizedBox(height: 16),
            if (!applicable)
              Text('Enter what you received to see a plan.',
                  style: TextStyle(color: Barako.muted, fontSize: 13))
            else
              _plan(r),
            const SizedBox(height: 14),
            Text(
                'A suggested split from your own cushion, debts, and goals. Nothing is moved for you. Ikaw pa rin ang bahala.',
                style:
                    TextStyle(color: Barako.faint, fontSize: 11, height: 1.35)),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint) => TextField(
        controller: c,
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
          hintText: hint,
          hintStyle: TextStyle(color: Barako.faint, fontSize: 16),
          filled: true,
          fillColor: Barako.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  Widget _plan(Map<String, dynamic> r) {
    final slices = (r['slices'] as List).cast<Map<String, dynamic>>();
    final leftover = (r['leftover'] as num).toDouble();
    final setAside = (r['setAside'] as num?)?.toDouble() ?? 0;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (setAside > 0) ...[
            _row('Set aside for what you need soon', setAside,
                color: Barako.textSecondary),
            const SizedBox(height: 6),
          ],
          for (final s in slices) ...[
            _row(s['label'] as String, (s['amount'] as num).toDouble(),
                color: Barako.primary),
            const SizedBox(height: 2),
            Text(s['detail'] as String,
                style: TextStyle(
                    color: Barako.muted, fontSize: 12, height: 1.35)),
            const SizedBox(height: 8),
          ],
          Divider(color: Barako.border, height: 16),
          _row(
              leftover > 0
                  ? 'Keep for long-term goals or investing'
                  : 'Nothing left over',
              leftover,
              color: leftover > 0 ? Barako.primaryText : Barako.muted,
              bold: true),
          if (r['usedFloor'] == true) ...[
            const SizedBox(height: 10),
            Text(
                'Based on a starter cushion of ₱10,000 for now. Log a few months and this uses your real monthly spending.',
                style:
                    TextStyle(color: Barako.textSecondary, fontSize: 12, height: 1.35)),
          ],
          if (r['rateUnfilled'] == true) ...[
            const SizedBox(height: 10),
            Text(
                'One debt has no monthly interest rate saved, so it could not be ranked. Add its rate in Utang so a real windfall knows to hit it first.',
                style: TextStyle(
                    color: Barako.warning, fontSize: 12, height: 1.35)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {required Color color, bool bold = false}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: bold ? color : Barako.text,
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text(_peso(amount),
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ],
      );

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
}
