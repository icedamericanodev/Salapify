// Currency converter: type an amount, pick From and To, see what it is worth.
// A reference tool only, it shows values and never moves, trades, or sends
// money. Rates come from the internet when online and are cached for offline;
// only the base currency code is ever sent. All the money math is the
// golden-locked crossRate/roundRate/formatConverted from the pure core.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../data/fx_service.dart';
import '../data/store.dart';
import '../money/currencies.dart';
import '../money/fxrates.dart';
import '../theme.dart';

const List<String> _mos = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _asOf(int? ms) {
  if (ms == null || ms <= 0) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_mos[d.month - 1]} ${d.day}, ${d.year}';
}

class CurrencyConverterScreen extends StatefulWidget {
  final SalapifyStore store;
  const CurrencyConverterScreen({super.key, required this.store});

  @override
  State<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  late final String _base;
  final _amount = TextEditingController();
  late String _from;
  late String _to;
  FxRates? _fx;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _base = _baseCode(widget.store.data['settings']);
    _from = _base;
    _to = _base == 'USD' ? 'PHP' : 'USD';
    _amount.addListener(() => setState(() {}));
    _load();
  }

  String _baseCode(dynamic settings) {
    if (settings is Map) {
      for (final key in ['currencyCode', 'currency']) {
        final v = settings[key];
        if (v is String && currencies.any((c) => c['code'] == v)) return v;
      }
    }
    return 'PHP';
  }

  Future<void> _load() async {
    final fx = await FxService().load(_base);
    if (!mounted) return;
    setState(() {
      _fx = fx;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _swap() => setState(() {
        final t = _from;
        _from = _to;
        _to = t;
      });

  void _retry() {
    setState(() => _loading = true);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final amountNum =
        double.tryParse(_amount.text.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
    final haveRates = _fx != null && _fx!.base == _base;
    final rate = haveRates ? crossRate(_fx!.rates, _from, _to) : null;
    final converted = convertAmount(amountNum, rate);
    final asOf = haveRates ? _asOf(_fx!.fetchedAt) : '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Barako.background,
        foregroundColor: Barako.text,
        title: Text('Currency converter',
            style: TextStyle(color: Barako.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
                'See what your money is worth in another currency. Rates come from the internet when you are online and are saved for offline use. This shows values only, it does not exchange or move money.',
                style:
                    TextStyle(color: Barako.muted, fontSize: 13, height: 1.5)),
            const SizedBox(height: 18),
            Text('AMOUNT IN $_from', style: Barako.kickerStyle),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(currencySymbol(_from),
                    style:
                        TextStyle(color: Barako.textSecondary, fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
                    ],
                    autofocus: true,
                    style: TextStyle(
                        color: Barako.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(color: Barako.faint),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _currencyRow('FROM', _from, (c) => setState(() => _from = c)),
            Center(
              child: TextButton.icon(
                onPressed: _swap,
                icon: Icon(Icons.swap_vert, color: Barako.primary, size: 18),
                label: Text('Swap',
                    style: TextStyle(
                        color: Barako.primary, fontWeight: FontWeight.w700)),
              ),
            ),
            _currencyRow('TO', _to, (c) => setState(() => _to = c)),
            const SizedBox(height: 18),
            _resultCard(amountNum, converted, rate, asOf),
            const SizedBox(height: 18),
            Center(
              child: Text('Rates by Exchange Rate API',
                  style: TextStyle(color: Barako.faint, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _currencyRow(String label, String value, void Function(String) onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Barako.kickerStyle),
        const SizedBox(height: 8),
        SizedBox(
          // At least a 44dp tap target, and it grows with the system text
          // scale so the pills never clip for large-font users.
          height:
              48 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: currencies.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final c = currencies[i];
              final code = c['code']!;
              final on = value == code;
              return ChoiceChip(
                label: Text('${c['symbol']} $code'),
                selected: on,
                onSelected: (_) => onPick(code),
                selectedColor: Barako.primary,
                backgroundColor: Barako.background,
                labelStyle: TextStyle(
                    color: on ? Barako.onPrimary : Barako.textSecondary,
                    fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _resultCard(
      double amountNum, double? converted, double? rate, String asOf) {
    Widget body;
    if (_from == _to) {
      body = Column(
        children: [
          _big(formatConverted(amountNum, _to)),
          const SizedBox(height: 8),
          Text('Same currency, nothing to convert.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Barako.muted, fontSize: 12)),
        ],
      );
    } else if (converted != null && rate != null) {
      body = Column(
        children: [
          _big(formatConverted(converted, _to)),
          const SizedBox(height: 8),
          Text(
              '1 $_from = ${roundRate(rate)} $_to${asOf.isNotEmpty ? ' · rates as of $asOf' : ''}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Barako.muted, fontSize: 12)),
        ],
      );
    } else if (_loading) {
      body = Text("Getting today's rates...",
          style: TextStyle(color: Barako.textSecondary, fontSize: 13));
    } else if (_fx != null) {
      // Rates are loaded, this pair just is not covered by the table. Do not
      // tell an online user to connect.
      body = Text(
          'No rate for $_from to $_to right now. Try another currency.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Barako.textSecondary, fontSize: 13, height: 1.4));
    } else {
      body = Column(
        children: [
          Text(
              "No rates yet. Connect to the internet once to download today's rates, then it works offline too.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Barako.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _retry,
            child: Text('Try again',
                style: TextStyle(
                    color: Barako.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: body),
      ),
    );
  }

  Widget _big(String text) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(text,
            maxLines: 1,
            style: TextStyle(
                fontFamily: Barako.displayFont,
                color: Barako.primary,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()])),
      );
}
