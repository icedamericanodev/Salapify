import 'package:flutter/material.dart';

import '../../core/money/currencies.dart';
import '../../core/money/fx_rates.dart';
import '../../data/fx_service.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../shared/sheet_scaffold.dart';

/// The foreign exchange converter, from the prototype's FX Rates tab.
///
/// It opens on whatever rates the device already has, cached or built in, and
/// asks the server in the background. That order matters: the alternative is a
/// spinner where the answer should be, on a screen somebody opened to convert
/// two numbers, and an OFW checking a remittance on the MRT has no signal
/// anyway.
///
/// Rates are MID-MARKET and the screen says so permanently rather than behind
/// the info dot. This is the exception the info-dot rule names: silence would
/// let somebody plan around a number no bank will give them.
class FxSheet extends StatefulWidget {
  const FxSheet({super.key, required this.palette, this.service});

  final Palette palette;

  /// Injectable so a test can drive it without a network or a plugin.
  final FxService? service;

  static Future<void> show(
    BuildContext context,
    Palette palette, {
    FxService? service,
  }) {
    return SheetScaffold.show<void>(
      context: context,
      palette: palette,
      builder: (BuildContext context) =>
          FxSheet(palette: palette, service: service),
    );
  }

  @override
  State<FxSheet> createState() => _FxSheetState();
}

class _FxSheetState extends State<FxSheet> {
  late final FxService _service = widget.service ?? FxService();
  final TextEditingController _amount = TextEditingController(text: '1000');

  FxRates _rates = FxRates.builtIn();
  CurrencyCode _from = CurrencyCode.php;
  CurrencyCode _to = CurrencyCode.usd;
  bool _busy = false;
  String? _lastAttemptFailed;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final FxRates cached = await _service.loadCached();
    if (!mounted) return;
    setState(() => _rates = cached);
    await _refresh(silent: true);
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _lastAttemptFailed = null;
    });
    final FxRates? live = await _service.fetch();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (live != null) {
        _rates = live;
      } else if (!silent) {
        // Only on a tap. A background attempt that quietly failed must not
        // put an error on a screen somebody has not interacted with.
        _lastAttemptFailed =
            'Could not reach the rate service. Showing the last rates this '
            'phone has.';
      }
    });
  }

  double get _value =>
      double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final double? converted = _rates.convert(_value, _from, _to);

    return SheetScaffold(
      palette: p,
      icon: Icons.public_outlined,
      title: 'Foreign exchange',
      subtitle: 'Convert between the peso and four major currencies',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Status(palette: p, rates: _rates, busy: _busy, onRefresh: _refresh),
          if (_lastAttemptFailed != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              _lastAttemptFailed!,
              style: AppType.caption(p).copyWith(color: p.negative),
            ),
          ],
          const SizedBox(height: Spacing.lg),
          Text('Amount', style: AppType.label(p)),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: AppType.body(p),
            decoration: InputDecoration(
              prefixText: '${currencySymbols[_from]} ',
              prefixStyle: AppType.body(p),
              filled: true,
              fillColor: p.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.control),
                borderSide: BorderSide(color: p.border),
              ),
            ),
          ),
          const SizedBox(height: Spacing.lg),
          _Picker(
            palette: p,
            label: 'From',
            selected: _from,
            onSelect: (CurrencyCode c) => setState(() => _from = c),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _Picker(
                  palette: p,
                  label: 'To',
                  selected: _to,
                  onSelect: (CurrencyCode c) => setState(() => _to = c),
                ),
              ),
              Semantics(
                button: true,
                label: 'Swap the two currencies',
                child: InkWell(
                  onTap: () => setState(() {
                    final CurrencyCode was = _from;
                    _from = _to;
                    _to = was;
                  }),
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.swap_horiz, color: p.accent),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.lg),
          Container(
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('THEY ARE WORTH', style: AppType.kicker(p)),
                const SizedBox(height: Spacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    converted == null
                        ? 'No rate for that pair'
                        : formatCurrency(converted, _to),
                    maxLines: 1,
                    style: AppType.hero(p),
                  ),
                ),
                if (converted != null) ...<Widget>[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    // The unit rate, because it is the number people actually
                    // compare against a money changer's board.
                    '1 ${_from.wire} = '
                    '${_rates.convert(1, _from, _to)!.toStringAsFixed(4)} '
                    '${_to.wire}',
                    style: AppType.caption(p),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          // On the screen, not behind the dot. Somebody planning a remittance
          // around a mid-market rate will be short when they get to the
          // counter, and silence here is what lets that happen.
          Text(FxRates.disclaimer, style: AppType.caption(p)),
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({
    required this.palette,
    required this.rates,
    required this.busy,
    required this.onRefresh,
  });

  final Palette palette;
  final FxRates rates;
  final bool busy;
  final VoidCallback onRefresh;

  String _describe() {
    switch (rates.source) {
      case FxSource.live:
        return 'Updated just now.';
      case FxSource.cached:
        final DateTime? at = rates.fetchedAt;
        if (at == null) return 'Saved on this phone.';
        final int days = DateTime.now().difference(at).inDays;
        if (days <= 0) return 'Updated today.';
        if (days == 1) return 'Updated yesterday.';
        return 'Updated $days days ago.';
      case FxSource.builtIn:
        // Never pretends. Built-in rates are months old by construction and
        // saying "updated" of them would be a lie told by a rounding rule.
        return 'Built-in rates. This phone has not fetched any yet.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool stale = rates.staleAt(DateTime.now());
    return Row(
      children: <Widget>[
        Icon(
          stale ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
          size: 16,
          color: stale ? palette.textMuted : palette.positive,
        ),
        const SizedBox(width: Spacing.sm),
        Expanded(child: Text(_describe(), style: AppType.caption(palette))),
        Semantics(
          button: true,
          child: InkWell(
            onTap: busy ? null : onRefresh,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.refresh, size: 16, color: palette.accent),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    busy ? 'Checking…' : 'Refresh',
                    style: AppType.button(palette, color: palette.accent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  final Palette palette;
  final String label;
  final CurrencyCode selected;
  final ValueChanged<CurrencyCode> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: AppType.label(palette)),
        const SizedBox(height: Spacing.xs),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: <Widget>[
            for (final CurrencyCode c in CurrencyCode.values)
              Semantics(
                button: true,
                selected: selected == c,
                child: InkWell(
                  onTap: () => onSelect(c),
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                      vertical: Spacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: selected == c
                          ? palette.accent
                          : palette.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                        color: selected == c ? palette.accent : palette.border,
                      ),
                    ),
                    child: Text(
                      c.wire,
                      style: AppType.button(
                        palette,
                        color: selected == c
                            ? palette.onAccent
                            : palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
