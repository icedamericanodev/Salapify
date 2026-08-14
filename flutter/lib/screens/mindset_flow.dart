// The Money Mindset flow: a four-step wizard (Context, Impact, Decision,
// Reflection) that replaces the single long screen. This file holds the
// scaffold (step header + paged body + Back/Continue) and Step 1, Context.
// Steps 2 to 4 are placeholders here and grow in following changes. All the
// money still comes from the read-only Decision Score engine; nothing here
// writes.
import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/currencies.dart' show baseCurrencySymbol;
import '../money/format.dart' show formatMoney;
import '../money/ledger.dart' show amountOf;
import '../money/mindset_decision.dart'
    show MindsetMode, mindsetBandLabel, mindsetComfortRange, mindsetDecision;
import '../theme.dart';
import '../typography.dart';
import '../widgets/mindset_score_gauge.dart';
import '../widgets/mindset_spectrum_bar.dart';
import '../widgets/mindset_step_indicator.dart';
import '../widgets/pan_mascot.dart';
import '../widgets/salapify_icon.dart';
import 'log_sheet.dart' show parseAmount;

class MindsetFlowScreen extends StatefulWidget {
  const MindsetFlowScreen({super.key, required this.store});

  final SalapifyStore store;

  @override
  State<MindsetFlowScreen> createState() => _MindsetFlowScreenState();
}

class _MindsetFlowScreenState extends State<MindsetFlowScreen> {
  // Two leading-square sizes: the larger for the tall selection cards, the
  // smaller for single-line input fields, so the two input rows (item, amount)
  // come out the same height.
  static const double _iconBox = 44;
  static const double _fieldIconBox = 32;

  final _page = PageController();
  int _step = 1;

  String _purchaseType = 'oneTime';
  final _itemName = TextEditingController();
  final _amount = TextEditingController();
  String? _categoryId;

  // Step 2 what-if exploration (one-time only), memoised so a drag never
  // re-runs the search over the ledger.
  double? _whatIf;
  double? _whatIfBase;
  Map<String, double>? _spectrum;
  String? _spectrumKey;
  double? _spectrumSearchMax;

  MindsetMode get _mindsetMode => switch (_purchaseType) {
    'subscription' => MindsetMode.subscription,
    'credit' => MindsetMode.credit,
    _ => MindsetMode.oneTime,
  };

  double get _enteredAmount => parseAmount(_amount.text) ?? 0;

  static Color _bandColor(int band) => switch (band) {
    1 => Barako.primary,
    2 => Barako.warning,
    _ => Barako.warningStrong,
  };

  static Color _scoreColor(double score) {
    if (score.isNaN) return Barako.muted;
    if (score >= 70) return Barako.primary;
    if (score >= 45) return Barako.warning;
    return Barako.warningStrong;
  }

  /// The read-only Decision Score for the current entry. Goal is left out here
  /// (no goal picker yet), so the score and the what-if spectrum stay
  /// consistent and the spectrum's monotonic search stays valid.
  Map<String, dynamic> _decision(DateTime now) {
    final amt = _enteredAmount;
    final mode = _mindsetMode;
    return mindsetDecision(
      widget.store.data,
      now,
      mode: mode,
      cashNow: amt,
      monthlyLoad: mode == MindsetMode.oneTime ? 0.0 : amt,
      goalAmount: amt,
    );
  }

  @override
  void dispose() {
    _page.dispose();
    _itemName.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _step1Valid => parseAmount(_amount.text) != null;

  void _goTo(int step) {
    setState(() => _step = step);
    _page.animateToPage(
      step - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  void _next() {
    if (_step < 4) _goTo(_step + 1);
  }

  void _back() {
    if (_step > 1) {
      _goTo(_step - 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  List<Map<String, dynamic>> _categories() => [
    for (final c in (widget.store.data['categories'] as List? ?? const []))
      if (c is Map<String, dynamic>) c,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Barako.background,
      appBar: AppBar(
        title: const Text('Money mindset'),
        leading: IconButton(
          icon: Icon(salapifyIcon('close'), color: Barako.text),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Close',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: MindsetStepIndicator(current: _step),
          ),
          Expanded(
            child: PageView(
              controller: _page,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _contextStep(),
                _impactStep(),
                _placeholder('Decision', 'The three questions and your call.'),
                _placeholder(
                  'Reflection',
                  'Your streak, wins, and today\'s lesson.',
                ),
              ],
            ),
          ),
          _navBar(),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Step 1

  Widget _contextStep() {
    final cats = _categories();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are you considering?', style: AppText.title.w7),
          const SizedBox(height: 4),
          Text(
            "Let's start with what you're thinking of buying.",
            style: AppText.small
                .tint(Barako.textSecondary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          _typeCard(
            'oneTime',
            'shopping',
            'One-time purchase',
            'Something you plan to buy once.',
          ),
          _typeCard(
            'subscription',
            'repeat',
            'Subscription',
            'A recurring monthly or yearly payment.',
          ),
          _typeCard(
            'credit',
            'card',
            'Credit or BNPL',
            'Buy now, pay later or installment.',
          ),
          const SizedBox(height: 20),
          Text('What is it?', style: AppText.small.w7),
          const SizedBox(height: 8),
          _itemField(),
          const SizedBox(height: 16),
          Text('Estimated amount', style: AppText.small.w7),
          const SizedBox(height: 8),
          _amountField(),
          if (cats.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Category (optional)', style: AppText.small.w7),
            const SizedBox(height: 10),
            _categoryChips(cats),
          ],
          const SizedBox(height: 20),
          _panTip('Taking a moment now can save you more later.'),
        ],
      ),
    );
  }

  Widget _typeCard(String value, String icon, String title, String subtitle) {
    final selected = _purchaseType == value;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: () => setState(() => _purchaseType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(Gap.lg),
            decoration: BoxDecoration(
              color: selected
                  ? Barako.primary.withValues(alpha: 0.08)
                  : Barako.card,
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(
                color: selected ? Barako.primary : Barako.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: _iconBox,
                  height: _iconBox,
                  decoration: BoxDecoration(
                    color: selected
                        ? Barako.primary.withValues(alpha: 0.15)
                        : Barako.surfaceRaised,
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(
                    salapifyIcon(icon),
                    size: 22,
                    color: selected ? Barako.primary : Barako.textSecondary,
                  ),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.body.w7),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppText.small.tint(Barako.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _radio(selected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _radio(bool on) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: on ? Barako.primary : Barako.border, width: 2),
    ),
    child: on
        ? Center(
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Barako.primary,
              ),
            ),
          )
        : null,
  );

  Widget _itemField() {
    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        children: [
          Container(
            width: _fieldIconBox,
            height: _fieldIconBox,
            decoration: BoxDecoration(
              color: Barako.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Icon(salapifyIcon('cart'), size: 18, color: Barako.muted),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: TextField(
              controller: _itemName,
              style: AppText.body,
              decoration: InputDecoration.collapsed(
                hintText: 'e.g. new headphones',
                hintStyle: AppText.body.tint(Barako.muted),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(
          color: _amount.text.isNotEmpty && !_step1Valid
              ? Barako.warningStrong
              : Barako.border,
        ),
      ),
      child: Row(
        children: [
          Text(
            baseCurrencySymbol,
            style: AppText.title.w7.tint(Barako.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppText.title.w7,
              decoration: InputDecoration.collapsed(
                hintText: '0',
                hintStyle: AppText.title.w7.tint(Barako.muted),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChips(List<Map<String, dynamic>> cats) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in cats.take(10))
          _CategoryChip(
            label: '${c['icon'] ?? ''} ${c['name'] ?? ''}'.trim(),
            selected: _categoryId == '${c['id']}',
            onTap: () => setState(
              () => _categoryId = _categoryId == '${c['id']}'
                  ? null
                  : '${c['id']}',
            ),
          ),
      ],
    );
  }

  Widget _panTip(String tip) {
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanMascot.emotion(emotion: PanEmotion.content, size: _iconBox),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Pan's tip", style: AppText.small.w7.tint(Barako.primary)),
                const SizedBox(height: 2),
                Text(
                  tip,
                  style: AppText.small
                      .tint(Barako.textSecondary)
                      .copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Step 2

  Widget _impactStep() {
    final amt = _enteredAmount;
    if (!(amt > 0)) {
      return _placeholder(
        'Impact',
        'Add an amount in step 1 to see the impact.',
      );
    }
    final now = DateTime.now();
    final decision = _decision(now);
    final score = decision['financialScore'] as int;
    final band = decision['band'] as int;
    final color = _bandColor(band);
    final spectrum = _mindsetMode == MindsetMode.oneTime
        ? _spectrumFor(now, decision, amt)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Gap.gutter,
        Gap.sm,
        Gap.gutter,
        Gap.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: Gap.sm),
          MindsetScoreGauge(score: score, band: band, size: 180),
          const SizedBox(height: Gap.md),
          Text(mindsetBandLabel(band), style: AppText.title.w7.tint(color)),
          const SizedBox(height: Gap.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            child: Text(
              _bandLine(band),
              textAlign: TextAlign.center,
              style: AppText.small
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: Gap.xl),
          _impactCard(decision),
          if (spectrum != null) ...[
            const SizedBox(height: Gap.lg),
            _whatIfCard(spectrum, amt),
          ],
        ],
      ),
    );
  }

  String _bandLine(int band) => switch (band) {
    1 => 'This fits comfortably against your money right now.',
    2 => 'Not a bad buy, but the timing is worth a pause.',
    _ => 'This would make a big dent in your money right now.',
  };

  Widget _impactCard(Map<String, dynamic> decision) {
    final runwayAfter = decision['runwayAfter'] as double?;
    final bufferAfter = amountOf(decision['bufferAfter']);
    final incomeShare = decision['incomeShare'] as double?;
    final dips = decision['dipsReserved'] as bool;
    final shortfall = amountOf(decision['reservedShortfall']);
    final axes = (decision['axes'] as List).cast<Map<String, dynamic>>();
    double axisScore(String name) {
      final a = axes.firstWhere(
        (e) => e['name'] == name,
        orElse: () => const {'score': double.nan},
      );
      return (a['score'] as num).toDouble();
    }

    final String cushion;
    if (runwayAfter == null) {
      cushion = bufferAfter > 0
          ? '${formatMoney(bufferAfter)} left'
          : 'Empties it';
    } else if (runwayAfter <= 0) {
      cushion = 'Empties it';
    } else if (runwayAfter < 0.05) {
      cushion = 'Under 0.1 months left';
    } else {
      cushion = '${runwayAfter.toStringAsFixed(1)} months left';
    }
    final income = incomeShare == null
        ? 'Income unknown'
        : '${(incomeShare * 100).round()}% of a month';

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHAT IT DOES', style: Barako.cardKickerStyle),
          const SizedBox(height: Gap.md),
          _metricRow('Cushion after', cushion, axisScore('buffer')),
          _metricRow('Share of income', income, axisScore('income')),
          _metricRow(
            'Bills & debt money',
            dips ? 'Dips ${formatMoney(shortfall)}' : 'No dip',
            dips ? -1 : 100,
          ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, double score) {
    final c = score < 0 ? Barako.warningStrong : _scoreColor(score);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              label,
              style: AppText.small.tint(Barako.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Gap.sm),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value, maxLines: 1, style: AppText.small.w6.tint(c)),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double>? _spectrumFor(
    DateTime now,
    Map<String, dynamic> decision,
    double entered,
  ) {
    final buffer = amountOf(decision['bufferAfter']) + entered;
    final available = amountOf(decision['availableAfter']) + entered;
    final daysLeft = decision['daysLeft'];
    final key =
        '${buffer.round()}_${available.round()}_'
        '${daysLeft}_${decision['incomeKnown']}';
    if (key != _spectrumKey) {
      final searchMax = [
        buffer * 2,
        entered * 5,
        300000.0,
      ].reduce((a, b) => a > b ? a : b);
      _spectrum = mindsetComfortRange(
        widget.store.data,
        now,
        goal: null,
        maxAmount: searchMax,
      );
      _spectrumKey = key;
      _spectrumSearchMax = searchMax;
    }
    return _spectrum;
  }

  static double _niceCeil(double x) {
    if (x <= 0) return 1000;
    final step = x < 5000
        ? 500.0
        : x < 20000
        ? 1000.0
        : x < 100000
        ? 5000.0
        : 10000.0;
    return (x / step).ceil() * step;
  }

  Widget _whatIfCard(Map<String, double> spectrum, double entered) {
    final comfortCeiling = spectrum['comfortCeiling'] ?? 0;
    final cautionCeiling = spectrum['cautionCeiling'] ?? 0;
    final maxSlider = _niceCeil(
      [
        entered * 1.4,
        cautionCeiling * 1.25,
        comfortCeiling * 1.5,
        1000.0,
      ].reduce((a, b) => a > b ? a : b),
    );
    final synced = _whatIfBase == entered;
    final sliderValue = ((synced ? (_whatIf ?? entered) : entered)).clamp(
      0.0,
      maxSlider,
    );
    final band = MindsetSpectrumBar.bandForAmount(
      sliderValue,
      comfortCeiling,
      cautionCeiling,
    );
    final displayCeiling = (comfortCeiling / 50).floorToDouble() * 50;
    final searchMax = _spectrumSearchMax ?? double.infinity;
    final saturated = comfortCeiling >= searchMax * 0.999;
    final String line;
    if (saturated) {
      line = 'Comfortable well past anything you would buy right now.';
    } else if (displayCeiling > 0) {
      line =
          'Up to ${formatMoney(displayCeiling)} still fits comfortably '
          'right now.';
    } else {
      line = 'Right now, even a small buy is worth a pause.';
    }

    String readout(double v) {
      final b = MindsetSpectrumBar.bandForAmount(
        v,
        comfortCeiling,
        cautionCeiling,
      );
      return '${formatMoney(v.roundToDouble())}, ${mindsetBandLabel(b)}';
    }

    final step = MindsetSpectrumBar.stepFor(maxSlider);

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHAT IF YOU SPEND', style: Barako.cardKickerStyle),
          const SizedBox(height: Gap.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(salapifyIcon('insights'), size: 16, color: Barako.primary),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  line,
                  style: AppText.small
                      .tint(Barako.textSecondary)
                      .copyWith(height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),
          MindsetSpectrumBar(
            value: sliderValue,
            maxAmount: maxSlider,
            comfortCeiling: comfortCeiling,
            cautionCeiling: cautionCeiling,
            semanticLabel: 'What if amount',
            semanticValue: readout(sliderValue),
            semanticIncreasedValue: readout(
              (sliderValue + step).clamp(0.0, maxSlider),
            ),
            semanticDecreasedValue: readout(
              (sliderValue - step).clamp(0.0, maxSlider),
            ),
            onChanged: (v) => setState(() {
              _whatIf = v;
              _whatIfBase = entered;
            }),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Drag to explore',
                  style: AppText.small.tint(Barako.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${formatMoney(sliderValue.roundToDouble())} · '
                    '${mindsetBandLabel(band)}',
                    maxLines: 1,
                    style: AppText.small.w6.tint(_bandColor(band)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- placeholder steps

  Widget _placeholder(String title, String note) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(salapifyIcon('sparkle'), size: 32, color: Barako.muted),
            const SizedBox(height: 12),
            Text(title, style: AppText.title.w7),
            const SizedBox(height: 6),
            Text(
              note,
              textAlign: TextAlign.center,
              style: AppText.small.tint(Barako.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- nav

  Widget _navBar() {
    final canContinue = _step > 1 || _step1Valid;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Barako.background,
        border: Border(top: BorderSide(color: Barako.border)),
      ),
      child: Row(
        children: [
          if (_step > 1) ...[
            OutlinedButton(
              onPressed: _back,
              style: OutlinedButton.styleFrom(
                foregroundColor: Barako.textSecondary,
                side: BorderSide(color: Barako.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton(
              onPressed: canContinue ? _next : null,
              style: FilledButton.styleFrom(
                backgroundColor: Barako.primary,
                foregroundColor: Barako.onPrimary,
                disabledBackgroundColor: Barako.border,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_step < 4 ? 'Continue' : 'Done'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A selectable category pill matching the flow's card language.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.control),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Barako.primary.withValues(alpha: 0.12)
                : Barako.card,
            borderRadius: BorderRadius.circular(Radii.control),
            border: Border.all(
              color: selected ? Barako.primary : Barako.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppText.small.w6.tint(
              selected ? Barako.primary : Barako.text,
            ),
          ),
        ),
      ),
    );
  }
}
