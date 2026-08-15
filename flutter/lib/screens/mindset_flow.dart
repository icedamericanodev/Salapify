// The Money Mindset flow: a four-step wizard (Context, Impact, Decision,
// Reflection) that replaces the single long screen. This file holds the
// scaffold (step header + paged body + Back/Continue) and Step 1, Context.
// Steps 2 to 4 are placeholders here and grow in following changes. All the
// money still comes from the read-only Decision Score engine; nothing here
// writes.
import 'package:flutter/material.dart';

import '../content/lesson_model.dart' show lessonFromMap;
import '../content/lessons.dart' show lessonOfTheDay;
import '../data/store.dart';
import '../money/currencies.dart' show baseCurrencySymbol;
import '../money/format.dart' show formatMoney, prettyDay;
import '../money/ledger.dart' show amountOf;
import '../money/bnpl.dart' show bnplCost;
import '../money/mindset_credit.dart' show BnplFlatPlan, bnplFlatPlan;
import '../money/mindset_purchase.dart' show goalTradeoff;
import '../money/mindset_subscriptions.dart'
    show parseSubscriptions, subscriptionsOverview;
import '../money/mindset_decisions.dart'
    show mindsetOutcomeFromFlow, mindsetWeekDots;
import '../money/mindset_wins.dart'
    show MindsetSnapshot, mindsetAllTimeAvoided, mindsetSnapshot;
import '../services/notifications.dart' show Reminders;
import '../money/mindset_decision.dart'
    show
        MindsetMode,
        applyReflection,
        mindsetBandLabel,
        mindsetCoolOff,
        mindsetComfortRange,
        mindsetDecision;
import '../theme.dart';
import '../typography.dart';
import '../widgets/mindset_score_gauge.dart';
import '../widgets/mindset_spectrum_bar.dart';
import '../widgets/mindset_step_indicator.dart';
import '../widgets/pan_mascot.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/segmented.dart';
import 'log_sheet.dart' show parseAmount;
import 'mindset_subscriptions_screen.dart';

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
  final _note = TextEditingController();

  // Credit / BNPL path: the installment term and the one-time add-on fee the
  // person's plan charges. The fee is left blank on purpose (a prefilled small
  // rate makes credit feel harmless); the cost card appears once it is entered.
  int _creditMonths = 6;
  final _creditFee = TextEditingController();

  // Subscription path: whether the price the person entered is billed monthly
  // or yearly, so the comparison can annualize or normalize it.
  String _subCycle = 'monthly';
  String? _categoryId;

  // Step 2 goal-impact: which saved goal the buy is weighed against. This is
  // INFORMATIONAL only and never feeds the Decision Score (the score already
  // carries your cash cushion; a wants goal is your own tradeoff to weigh).
  // Founder-directed, finance-expert reviewed (2026-08-15).
  String? _goalId;

  // Step 2 what-if exploration (one-time only), memoised so a drag never
  // re-runs the search over the ledger.
  double? _whatIf;
  double? _whatIfBase;
  Map<String, double>? _spectrum;
  String? _spectrumKey;
  double? _spectrumSearchMax;

  // Step 3 reflection. Private, never leaves the phone.
  static const List<String> _questions = [
    'Is this essential right now?',
    'Can I afford this without using money reserved for bills, debt, or goals?',
    'Have I wanted it for at least 24 hours?',
  ];
  final List<bool?> _answers = List<bool?>.filled(3, null);
  int _expandedQ = 0;
  String? _outcome; // 'bought' | 'skipped' | 'waiting', set by the actions

  bool get _allAnswered => _answers.every((a) => a != null);

  MindsetMode get _mindsetMode => switch (_purchaseType) {
    'subscription' => MindsetMode.subscription,
    'credit' => MindsetMode.credit,
    _ => MindsetMode.oneTime,
  };

  double get _enteredAmount => parseAmount(_amount.text) ?? 0;

  /// A borderless input decoration. InputDecoration.collapsed only nulls the
  /// base border, so the app's inputDecorationTheme still draws its enabled and
  /// focused OutlineInputBorders inside the field, a second rounded outline that
  /// cramps the text. Nulling every state, plus filled:false, leaves only the
  /// field container's own border.
  InputDecoration _bareInput(String hint, TextStyle hintStyle) =>
      InputDecoration(
        isCollapsed: true,
        filled: false,
        contentPadding: EdgeInsets.zero,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: hint,
        hintStyle: hintStyle,
      );

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
    _note.dispose();
    _creditFee.dispose();
    super.dispose();
  }

  bool get _step1Valid => parseAmount(_amount.text) != null;

  // The friendly date the "Remind me" nudge will actually arrive: one day out,
  // mirroring addMindsetWaitingItem's revisitAt (now + 24h). Kept in step with
  // that constant so the button never promises a date the reminder will not
  // honor. The band cool-off length (mindsetCoolOff) gates whether this button
  // shows at all; it does not drive the reminder timing today, which is a
  // discrepancy flagged to the founder rather than changed here.
  String _revisitDate() => prettyDay(
    DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
  );

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

  // Goals with something still left to save, the only ones a tradeoff can speak
  // to (goalTradeoff returns null for a fully funded goal anyway).
  List<Map<String, dynamic>> _openGoals() => [
    for (final g in (widget.store.data['goals'] as List? ?? const []))
      if (g is Map<String, dynamic> &&
          amountOf(g['target']) - amountOf(g['saved']) > 0)
        g,
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
        actions: [
          // A jump straight to the 30-day overview, so history is one tap away
          // without walking the decision steps.
          if (_step != 4)
            TextButton(
              onPressed: () => _goTo(4),
              child: Text(
                'My 30 days',
                style: AppText.small.w7.tint(Barako.primary),
              ),
            ),
        ],
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
                _decisionStep(),
                _reflectionStep(),
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
          Text(
            _purchaseType == 'credit'
                ? 'Purchase price'
                : _purchaseType == 'subscription'
                ? 'Monthly price'
                : 'Estimated amount',
            style: AppText.small.w7,
          ),
          const SizedBox(height: 8),
          _amountField(),
          if (_purchaseType == 'credit') _creditDetail(),
          if (_purchaseType == 'subscription') _subscriptionDetail(),
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
              decoration: _bareInput(
                'e.g. new headphones',
                AppText.body.tint(Barako.muted),
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
              decoration: _bareInput('0', AppText.title.w7.tint(Barako.muted)),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  // Credit / BNPL Step 1 detail: the installment term, a one-time fee percent,
  // and a live cost breakdown. The fee is labelled a one-time fee on the price,
  // never a monthly rate (a flat 3% and 3% per month differ by the term), and
  // the real cost per year is shown from the golden bnplCost engine so the
  // annualized cost lands, not just a small peso fee. Bank-officer verified.
  Widget _creditDetail() {
    final price = _enteredAmount;
    final feeText = _creditFee.text.trim();
    final fee = double.tryParse(feeText);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Gap.lg),
        Text('Installment plan', style: AppText.small.w7),
        const SizedBox(height: Gap.sm),
        Segmented<int>(
          options: const [
            SegmentOption(value: 3, label: '3 mo'),
            SegmentOption(value: 6, label: '6 mo'),
            SegmentOption(value: 12, label: '12 mo'),
          ],
          current: _creditMonths,
          onPick: (v) => setState(() => _creditMonths = v),
        ),
        const SizedBox(height: Gap.lg),
        Text('One-time fee (% of price)', style: AppText.small.w7),
        const SizedBox(height: Gap.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.lg,
            vertical: Gap.md,
          ),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(Radii.field),
            border: Border.all(color: Barako.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _creditFee,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppText.title.w7,
                  decoration: _bareInput(
                    'e.g. 3',
                    AppText.title.w7.tint(Barako.muted),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text('%', style: AppText.title.w7.tint(Barako.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text(
          'A single fee on the price, not a rate per month. If your plan charges '
          'a rate every month, this estimate will be too low.',
          style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
        ),
        if (price > 0 && feeText.isNotEmpty && fee != null) ...[
          const SizedBox(height: Gap.lg),
          _creditCostCard(
            bnplFlatPlan(price: price, months: _creditMonths, feePercent: fee),
          ),
        ],
      ],
    );
  }

  // Subscription Step 1 detail: a peek at what all the person's subscriptions
  // already cost per month, and a way in to manage them. The full monthly vs
  // yearly comparison for the item being considered is a follow-up.
  Widget _subscriptionDetail() {
    final subs = parseSubscriptions(widget.store.mindsetSubscriptions);
    final o = subscriptionsOverview(subs);
    final price = _enteredAmount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Gap.lg),
        Text('Billed', style: AppText.small.w7),
        const SizedBox(height: Gap.sm),
        Segmented<String>(
          options: const [
            SegmentOption(value: 'monthly', label: 'Monthly'),
            SegmentOption(value: 'annual', label: 'Yearly'),
          ],
          current: _subCycle,
          onPick: (v) => setState(() => _subCycle = v),
        ),
        if (price > 0) ...[
          const SizedBox(height: Gap.lg),
          _subscriptionCompareCard(price, o.monthlyTotal),
        ],
        const SizedBox(height: Gap.lg),
        _subscriptionManagePeek(subs, o),
      ],
    );
  }

  Widget _subscriptionCompareCard(double price, double currentMonthly) {
    // Normalize the entered price to per-month and per-year the same way the
    // overview engine does, so the two figures always reconcile.
    final perMonth = _subCycle == 'annual' ? price / 12 : price;
    final perYear = _subCycle == 'annual' ? price : price * 12;
    final newMonthly = currentMonthly + perMonth;
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
          _resultRow('Per month', formatMoney(perMonth)),
          _resultRow('Per year', formatMoney(perYear)),
          if (currentMonthly > 0) ...[
            const Divider(height: Gap.lg),
            _resultRow(
              'Your subscriptions would go to',
              '${formatMoney(newMonthly)} a month',
            ),
          ],
          const SizedBox(height: Gap.sm),
          Text(
            'A subscription is small each month and large across a year. This '
            'is what it adds, not a bill you owe.',
            style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionManagePeek(List<dynamic> subs, dynamic o) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MindsetSubscriptionsScreen(store: widget.store),
            ),
          );
          if (mounted) setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: Barako.border),
          ),
          child: Row(
            children: [
              Icon(salapifyIcon('repeat'), size: 20, color: Barako.primary),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subs.isEmpty
                          ? 'Track your subscriptions'
                          : '${o.count} subscription${o.count == 1 ? '' : 's'}, ${formatMoney(o.monthlyTotal)} a month',
                      style: AppText.small.w7,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subs.isEmpty
                          ? 'See what your monthly and yearly plans cost together.'
                          : 'Tap to manage, or add this one to the list.',
                      style: AppText.caption.tint(Barako.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(salapifyIcon('forward'), size: 18, color: Barako.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _creditCostCard(BnplFlatPlan plan) {
    // Real cost per year, from the golden engine. The fee rides in the monthly
    // (upfrontFee 0), so netCredit is the full price and the rate is honest.
    final cost = bnplCost({
      'cashPrice': plan.price,
      'downpayment': 0,
      'months': plan.months,
      'monthlyPayment': plan.monthly,
      'upfrontFee': 0,
    });
    final rateReliable = cost['rateReliable'] == true;
    final annual = (cost['annualRate'] as num).toDouble();
    final rateText = annual > 10
        ? 'over 1,000% a year'
        : '${(annual * 100).toStringAsFixed(1)}% a year';
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
          _resultRow('Monthly payment (approx.)', formatMoney(plan.monthly)),
          _resultRow('Total paid', formatMoney(plan.totalPaid)),
          _resultRow('Extra cost', formatMoney(plan.extraCost)),
          if (rateReliable) _resultRow('Real cost per year', rateText),
          const SizedBox(height: Gap.sm),
          Text(
            'An estimate from the numbers you enter, not a loan offer. Fee only, '
            'before any late fees or penalties. The last payment covers any '
            'centavo remainder.',
            style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
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
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: _showScoreExplainer,
            child: Text(
              'How we score this',
              style: AppText.small.w7.tint(Barako.primary),
            ),
          ),
          const SizedBox(height: Gap.md),
          _impactCard(decision),
          const SizedBox(height: Gap.lg),
          _openGoals().isNotEmpty
              ? _goalImpactCard(amt, now)
              : _goalImpactEmpty(),
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

  // Plain-words definition of the Decision Score, so the number never feels like
  // a mystery. Founder direction 2026-08-15: define it simply, no jargon.
  void _showScoreExplainer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Barako.background,
          border: Border.all(color: Barako.border),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Barako.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                Text('How we score this', style: AppText.title.w7),
                const SizedBox(height: Gap.sm),
                Text(
                  'The Decision Score is a quick read, from 0 to 100, of how '
                  'well this purchase fits your money right now. Higher is safer '
                  'to buy. Lower means it is worth a pause.',
                  style: AppText.small
                      .tint(Barako.textSecondary)
                      .copyWith(height: 1.5),
                ),
                const SizedBox(height: Gap.lg),
                _explainRow(
                  'wallet',
                  'Cash left after',
                  'How much cash you would have left once you buy. More left, '
                      'higher score.',
                ),
                _explainRow(
                  'shield',
                  'Bills and debt',
                  'Whether it dips into money set aside for what you owe. '
                      'Dipping pulls the score down the most.',
                ),
                _explainRow(
                  'chart',
                  'Size vs income',
                  'How big it is next to a month of your income. Smaller is '
                      'safer.',
                ),
                const SizedBox(height: Gap.md),
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: Barako.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(Radii.card),
                  ),
                  child: Text(
                    'It is a guide, not a rule. You always make the final call.',
                    style: AppText.small.w6
                        .tint(Barako.primary)
                        .copyWith(height: 1.4),
                  ),
                ),
                const SizedBox(height: Gap.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Barako.primary,
                      foregroundColor: Barako.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _explainRow(String icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Barako.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Icon(salapifyIcon(icon), size: 18, color: Barako.primary),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.small.w7),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: AppText.caption
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
        ? 'Add income to see'
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
          Text('WHAT THIS LOOKS AT', style: Barako.cardKickerStyle),
          const SizedBox(height: Gap.md),
          _metricRow('Cash left after', cushion, axisScore('buffer')),
          _metricRow('Size vs income', income, axisScore('income')),
          _metricRow(
            'Bills and debt',
            dips ? 'Dips ${formatMoney(shortfall)}' : 'No dip',
            dips ? -1 : 100,
          ),
        ],
      ),
    );
  }

  String _goalKey(Map<String, dynamic> g) {
    final id = g['id'];
    if (id is String && id.trim().isNotEmpty) return id;
    final name = g['name'];
    return name is String ? name : '';
  }

  String? _delayText(dynamic delay) {
    if (delay is! Map) return null;
    final periods = delay['periods'];
    if (periods is! int || periods <= 0) return null;
    final freq = delay['frequency'];
    final unit = switch (freq) {
      'weekly' => periods == 1 ? 'week' : 'weeks',
      'kinsenas' => periods == 1 ? 'payday' : 'paydays',
      _ => periods == 1 ? 'month' : 'months',
    };
    return 'about $periods $unit later';
  }

  // Shown when there is no savings goal yet, so the goal lens is always visible
  // on Impact (a first-run phone has no goals, and a hidden card can never be
  // discovered). It explains what the section would do and points to Goals.
  Widget _goalImpactEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHAT THIS COSTS YOUR GOAL', style: Barako.cardKickerStyle),
          const SizedBox(height: Gap.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(salapifyIcon('goal'), size: 18, color: Barako.textSecondary),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  'Set a savings goal and this will show how much a buy sets it '
                  'back, and about how much later it would land.',
                  style: AppText.small
                      .tint(Barako.textSecondary)
                      .copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // What a buy costs a savings goal. INFORMATIONAL, separate from the score: the
  // heading and copy never imply the score dropped because of the goal (the
  // score does not use it). Bars and any delay come from the tested goalTradeoff
  // engine, and the delay is shown ONLY when that engine gives a real number.
  Widget _goalImpactCard(double amt, DateTime now) {
    final goals = _openGoals();
    final selected = goals.firstWhere(
      (g) => _goalKey(g) == _goalId,
      orElse: () => goals.first,
    );
    final target = amountOf(selected['target']);
    final saved = amountOf(selected['saved']);
    final name = (selected['name'] is String)
        ? (selected['name'] as String).trim()
        : 'this goal';
    final beforePct = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;
    // If you buy this AND still want the goal, you need [amt] more, so you are
    // this far along a bigger total. Honest opportunity-cost framing that lines
    // up with the delay math (which adds the amount to the target).
    final afterPct = (target + amt) > 0
        ? (saved / (target + amt)).clamp(0.0, 1.0)
        : 0.0;
    final tradeoff = goalTradeoff(
      goal: selected,
      purchaseAmount: amt,
      now: now,
    );
    final delayText = _delayText(tradeoff?['delay']);
    final pctOfRemaining = tradeoff?['percentOfRemaining'];
    final isEmergency = name.toLowerCase().contains('emergency');

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
          Row(
            children: [
              Expanded(
                child: Text(
                  'WHAT THIS COSTS YOUR GOAL',
                  style: Barako.cardKickerStyle,
                ),
              ),
              if (goals.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _goalKey(selected),
                    isDense: true,
                    dropdownColor: Barako.card,
                    style: AppText.small.w7.tint(Barako.primary),
                    icon: Icon(
                      salapifyIcon('expand'),
                      size: 18,
                      color: Barako.primary,
                    ),
                    items: [
                      for (final g in goals)
                        DropdownMenuItem(
                          value: _goalKey(g),
                          child: Text(
                            (g['name'] is String)
                                ? g['name'] as String
                                : 'Goal',
                            style: AppText.small.w7,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _goalId = v),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          if (goals.length == 1)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(name, style: AppText.body.w7),
            ),
          _goalBar('Now', beforePct, saved, target, Barako.primary),
          const SizedBox(height: Gap.md),
          _goalBar(
            'If you buy this',
            afterPct,
            saved,
            target + amt,
            Barako.warning,
          ),
          const SizedBox(height: Gap.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                salapifyIcon(isEmergency ? 'shield' : 'goal'),
                size: 16,
                color: isEmergency
                    ? Barako.warningStrong
                    : Barako.textSecondary,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  _goalImpactLine(name, delayText, pctOfRemaining, isEmergency),
                  style: AppText.small
                      .tint(Barako.textSecondary)
                      .copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _goalImpactLine(
    String name,
    String? delayText,
    dynamic pctOfRemaining,
    bool isEmergency,
  ) {
    final pct = pctOfRemaining is num ? pctOfRemaining.round() : null;
    final pctPart = (pct != null && pct > 0)
        ? 'This buy is about $pct% of what you still need for $name. '
        : '';
    final timePart = delayText != null
        ? 'At your pace, $name lands $delayText.'
        : 'It slows $name down.';
    final lead = isEmergency ? 'Careful, this is your emergency fund. ' : '';
    return '$lead$pctPart$timePart';
  }

  Widget _goalBar(
    String label,
    double pct,
    double saved,
    double total,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: AppText.small.tint(Barako.muted)),
            ),
            Text('${(pct * 100).round()}%', style: AppText.small.w7),
          ],
        ),
        const SizedBox(height: Gap.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Barako.surfaceRaised,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: Gap.xxs),
        Text(
          '${formatMoney(saved)} of ${formatMoney(total)}',
          style: AppText.caption.tint(Barako.muted),
        ),
      ],
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

  // ------------------------------------------------------------- Step 3

  int _nextUnanswered() => _answers.indexWhere((a) => a == null);

  Widget _decisionStep() {
    final amt = _enteredAmount;
    if (!(amt > 0)) {
      return _placeholder('Decision', 'Add an amount in step 1 first.');
    }
    final decision = _decision(DateTime.now());
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Gap.gutter,
        Gap.xs,
        Gap.gutter,
        Gap.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('A few honest questions', style: AppText.title.w7),
          const SizedBox(height: Gap.xs),
          Text(
            'Only you see these. They can nudge you toward waiting, never '
            'toward buying.',
            style: AppText.small
                .tint(Barako.textSecondary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: Gap.lg),
          for (var i = 0; i < _questions.length; i++) _questionTile(i),
          const SizedBox(height: Gap.sm),
          Row(
            children: [
              Icon(salapifyIcon('lock'), size: 15, color: Barako.muted),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  'Private and stored only on your phone.',
                  style: AppText.small.tint(Barako.muted),
                ),
              ),
            ],
          ),
          if (_allAnswered) ...[
            const SizedBox(height: Gap.lg),
            _resultCard(decision),
          ],
        ],
      ),
    );
  }

  Widget _questionTile(int i) {
    final expanded = _expandedQ == i;
    final answer = _answers[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Barako.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(
            color: expanded ? Barako.primary : Barako.border,
            width: expanded ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () => setState(() => _expandedQ = expanded ? -1 : i),
              child: Padding(
                padding: const EdgeInsets.all(Gap.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${i + 1} of ${_questions.length}',
                            style: AppText.caption.tint(Barako.muted),
                          ),
                          const SizedBox(height: Gap.xxs),
                          Text(
                            _questions[i],
                            style: AppText.body.w6.copyWith(height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    if (answer != null && !expanded)
                      Text(
                        answer ? 'Yes' : 'No',
                        style: AppText.small.w7.tint(Barako.primary),
                      )
                    else
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          salapifyIcon('expand'),
                          size: 20,
                          color: Barako.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
                child: Row(
                  children: [
                    Expanded(child: _answerButton('Yes', true, i)),
                    const SizedBox(width: Gap.sm),
                    Expanded(child: _answerButton('No', false, i)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _answerButton(String label, bool value, int i) {
    final selected = _answers[i] == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('mindsetAnswer_${i}_$value'),
        borderRadius: BorderRadius.circular(Radii.field),
        onTap: () => setState(() {
          _answers[i] = value;
          _expandedQ = _nextUnanswered();
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Barako.primary.withValues(alpha: 0.12)
                : Barako.surfaceRaised,
            borderRadius: BorderRadius.circular(Radii.field),
            border: Border.all(
              color: selected ? Barako.primary : Barako.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: AppText.body.w6.tint(
              selected ? Barako.primary : Barako.text,
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultCard(Map<String, dynamic> decision) {
    final financial = decision['financialScore'] as int;
    final reflection = applyReflection(
      financial,
      essential: _answers[0]!,
      affordWithoutReserved: _answers[1]!,
      wanted24h: _answers[2]!,
    );
    final band = reflection['finalBand'] as int;
    final label = mindsetBandLabel(band);
    final color = _bandColor(band);
    final icon = switch (band) {
      1 => 'done',
      2 => 'paused',
      _ => 'warning',
    };
    final bufferAfter = amountOf(decision['bufferAfter']);
    final incomeShare = decision['incomeShare'] as double?;
    final coolOff = mindsetCoolOff(band);

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(salapifyIcon(icon), color: color, size: 22),
              const SizedBox(width: Gap.sm),
              Text(label, style: AppText.title.w7.tint(color)),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            _bandLine(band),
            style: AppText.small
                .tint(Barako.textSecondary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: Gap.md),
          Divider(height: 1, color: Barako.border),
          const SizedBox(height: Gap.md),
          _resultRow('Cash buffer after', formatMoney(bufferAfter)),
          if (incomeShare != null)
            _resultRow(
              'Share of income',
              '${(incomeShare * 100).round()}% of a month',
            ),
          const SizedBox(height: Gap.md),
          Text(
            'Add a note (optional)',
            style: AppText.caption.w6.tint(Barako.muted),
          ),
          const SizedBox(height: Gap.xs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.md,
              vertical: Gap.sm,
            ),
            decoration: BoxDecoration(
              color: Barako.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.field),
              border: Border.all(color: Barako.border),
            ),
            child: TextField(
              controller: _note,
              style: AppText.small,
              minLines: 1,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              decoration: _bareInput(
                'e.g. I cooked at home instead',
                AppText.small.tint(Barako.muted),
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),
          if (coolOff != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _finish('waiting'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color),
                  padding: const EdgeInsets.symmetric(vertical: Gap.md),
                ),
                child: Text('Remind me on ${_revisitDate()}'),
              ),
            ),
          if (coolOff != null) const SizedBox(height: Gap.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _finish('skipped'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Barako.textSecondary,
                    side: BorderSide(color: Barako.border),
                    padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  ),
                  child: const Text('Skip for now'),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: FilledButton(
                  onPressed: () => _finish('bought'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Barako.primary,
                    foregroundColor: Barako.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: Gap.md),
                  ),
                  child: const Text('Buy anyway'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Gap.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: AppText.small.tint(Barako.muted))),
        const SizedBox(width: Gap.sm),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(value, style: AppText.small.w7),
          ),
        ),
      ],
    ),
  );

  String _resultKey(int band) => switch (band) {
    1 => 'fitsPlan',
    2 => 'pause24h',
    _ => 'notInPlan',
  };

  /// Records the chosen outcome through the existing, tested store write paths
  /// (no new schema): every completed check is logged; a skip becomes a small
  /// win; a "remind me" becomes a waiting item and reschedules its nudge. Then
  /// it moves to Reflection. A write failure never traps the user mid-flow.
  Future<void> _finish(String outcome) async {
    final store = widget.store;
    if (store.canWrite && _allAnswered) {
      final name = _itemName.text.trim().isNotEmpty
          ? _itemName.text.trim()
          : 'a purchase';
      final amt = _enteredAmount;
      final band =
          applyReflection(
                _decision(DateTime.now())['financialScore'] as int,
                essential: _answers[0]!,
                affordWithoutReserved: _answers[1]!,
                wanted24h: _answers[2]!,
              )['finalBand']
              as int;
      final result = _resultKey(band);
      try {
        await store.logMindsetCheck(verdict: result);
        // The unified decision record that powers the Mindset Today dashboard
        // (summary counts and Recent Decisions). Additive and read-only: the
        // amount is the Step 1 estimate, never a transaction.
        await store.addMindsetDecision(
          itemName: name,
          amount: amt > 0 ? amt : null,
          categoryId: _categoryId,
          outcome: mindsetOutcomeFromFlow(outcome),
          note: _note.text,
          verdict: result,
        );
        if (outcome == 'skipped') {
          await store.addWin('Skipped $name', amount: amt > 0 ? amt : null);
        } else if (outcome == 'waiting') {
          await store.addMindsetWaitingItem(
            itemName: name,
            amount: amt > 0 ? amt : null,
            categoryId: _categoryId,
            essential: _answers[0]!,
            affordableWithoutReserved: _answers[1]!,
            waited24h: _answers[2]!,
            result: result,
          );
          await Reminders.reschedule(store.data, DateTime.now());
        }
      } catch (_) {
        // The reflection still shows, just without the recorded row.
      }
    }
    if (!mounted) return;
    setState(() => _outcome = outcome);
    _goTo(4);
  }

  // ------------------------------------------------------------- Step 4

  static const List<String> _months = [
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

  String _fmtDate(dynamic iso) {
    final d = iso is String ? DateTime.tryParse(iso) : null;
    if (d == null) return '';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  List<Map<String, dynamic>> _wins() => [
    for (final w in (widget.store.data['wins'] as List? ?? const []))
      if (w is Map<String, dynamic>) w,
  ];

  Widget _reflectionStep() {
    final now = DateTime.now();
    final snap = mindsetSnapshot(
      wins: widget.store.data['wins'],
      mindsetChecks: widget.store.mindsetChecks,
      mindsetWaiting: widget.store.mindsetWaiting,
      now: now,
    );
    final wins = _wins().reversed.take(4).toList();
    final allTime = mindsetAllTimeAvoided(widget.store.data['wins']);
    final lesson = lessonFromMap(lessonOfTheDay(now));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        Gap.gutter,
        Gap.xs,
        Gap.gutter,
        Gap.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_outcome != null) ...[
            _outcomeBanner(),
            const SizedBox(height: Gap.lg),
          ],
          if (allTime.count > 0) ...[
            _allTimeHero(allTime.total, allTime.count),
            const SizedBox(height: Gap.lg),
          ],
          Text('Your last 30 days', style: AppText.title.w7),
          const SizedBox(height: Gap.md),
          _snapshotGrid(snap),
          const SizedBox(height: Gap.lg),
          _streakCard(snap, now),
          const SizedBox(height: Gap.lg),
          _lessonCard(lesson.title, lesson.summary),
          const SizedBox(height: Gap.lg),
          _winsCard(wins),
          const SizedBox(height: Gap.md),
          Text(
            "This doesn't add to your balance. It reflects what you chose not "
            'to spend.',
            style: AppText.caption.tint(Barako.muted).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  // All-time money kept: the running total of confirmed spending avoided across
  // every choice, not just the last 30 days. Read-only, the same win-amount sum
  // the 30-day snapshot uses; it never adds to a balance.
  Widget _allTimeHero(double total, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: Barako.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Money kept, all time',
            style: AppText.small.w7.tint(Barako.primary),
          ),
          const SizedBox(height: Gap.xs),
          Text(formatMoney(total), style: AppText.amountLg.tabular),
          const SizedBox(height: 2),
          Text(
            count == 1
                ? 'From 1 choice you made on purpose.'
                : 'From $count choices you made on purpose.',
            style: AppText.small.tint(Barako.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _outcomeBanner() {
    final (icon, text, color) = switch (_outcome) {
      'bought' => (
        'cart',
        'You decided to buy it. Logged with care.',
        Barako.primary,
      ),
      'skipped' => (
        'done',
        'You skipped it. That is money kept.',
        Barako.primary,
      ),
      'waiting' => (
        'paused',
        "Saved to wait on. We'll nudge you when it's time.",
        Barako.warning,
      ),
      _ => ('sparkle', '', Barako.muted),
    };
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(salapifyIcon(icon), color: color, size: 20),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: AppText.small.w6.tint(color))),
        ],
      ),
    );
  }

  Widget _snapshotGrid(MindsetSnapshot snap) {
    Widget tile(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(Gap.lg),
        decoration: BoxDecoration(
          color: Barako.card,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: Barako.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppText.titleLg.w8.tabular),
            const SizedBox(height: Gap.xxs),
            Text(
              label,
              style: AppText.small.tint(Barako.textSecondary),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            tile('Decision checks', '${snap.decisionChecksCompleted}'),
            const SizedBox(width: Gap.md),
            tile('Purchases paused', '${snap.purchasesPaused}'),
          ],
        ),
        const SizedBox(height: Gap.md),
        Row(
          children: [
            tile('Purchases skipped', '${snap.purchasesSkipped}'),
            const SizedBox(width: Gap.md),
            tile(
              'Spending avoided',
              formatMoney(snap.confirmedSpendingAvoided),
            ),
          ],
        ),
      ],
    );
  }

  Widget _streakCard(MindsetSnapshot snap, DateTime now) {
    final dots = _weekDots(now);
    final active = dots.where((d) => d).length;
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
          Text('MINDFUL STREAK', style: Barako.cardKickerStyle),
          const SizedBox(height: Gap.xs),
          Text(
            active >= 1
                ? '$active of the last 4 weeks, you checked before buying.'
                : 'Check before a buy to start your streak.',
            style: AppText.body.w6.copyWith(height: 1.3),
          ),
          const SizedBox(height: Gap.md),
          Row(
            children: [
              for (var i = 0; i < dots.length; i++) ...[
                _weekDot(dots[i], i + 1),
                if (i < dots.length - 1) const SizedBox(width: Gap.md),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _weekDot(bool active, int week) => Expanded(
    child: Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? Barako.primary : Colors.transparent,
            border: Border.all(
              color: active ? Barako.primary : Barako.border,
              width: 1.5,
            ),
          ),
        ),
        const SizedBox(height: Gap.xs),
        Text('W$week', style: AppText.caption.tint(Barako.muted)),
      ],
    ),
  );

  /// One dot per week over the last four, active when a check or a win landed
  /// in that week. Oldest week first. Delegates to the shared pure helper so the
  /// standalone insights screen and this step never drift.
  List<bool> _weekDots(DateTime now) =>
      mindsetWeekDots(widget.store.mindsetChecks, _wins(), now);

  Widget _lessonCard(String title, String summary) => Container(
    padding: const EdgeInsets.all(Gap.lg),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(salapifyIcon('learning'), size: 16, color: Barako.primary),
            const SizedBox(width: Gap.xs),
            Text("TODAY'S LESSON", style: Barako.cardKickerStyle),
          ],
        ),
        const SizedBox(height: Gap.sm),
        Text(title, style: AppText.body.w7.copyWith(height: 1.3)),
        const SizedBox(height: Gap.xs),
        Text(
          summary,
          style: AppText.small.tint(Barako.textSecondary).copyWith(height: 1.4),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );

  Widget _winsCard(List<Map<String, dynamic>> wins) => Container(
    padding: const EdgeInsets.all(Gap.lg),
    decoration: BoxDecoration(
      color: Barako.card,
      borderRadius: BorderRadius.circular(Radii.card),
      border: Border.all(color: Barako.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SMALL WINS', style: Barako.cardKickerStyle),
        const SizedBox(height: Gap.sm),
        if (wins.isEmpty)
          Text(
            'Each purchase you skip can be a small win. They show up here.',
            style: AppText.small
                .tint(Barako.textSecondary)
                .copyWith(height: 1.4),
          )
        else
          for (var i = 0; i < wins.length; i++) ...[
            if (i > 0) Divider(height: Gap.lg, color: Barako.border),
            _winRow(wins[i]),
          ],
      ],
    ),
  );

  Widget _winRow(Map<String, dynamic> w) {
    final note = (w['note'] ?? w['itemName'] ?? 'Skipped a buy').toString();
    final amount = amountOf(w['amount']);
    final date = _fmtDate(w['date']);
    return Row(
      children: [
        Icon(salapifyIcon('done'), size: 18, color: Barako.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note,
                style: AppText.small.w6,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (date.isNotEmpty)
                Text(date, style: AppText.caption.tint(Barako.muted)),
            ],
          ),
        ),
        if (amount > 0) ...[
          const SizedBox(width: Gap.sm),
          Text(
            formatMoney(amount),
            style: AppText.small.w7.tint(Barako.primary),
          ),
        ],
      ],
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
    final canContinue = switch (_step) {
      1 => _step1Valid,
      3 => _allAnswered,
      _ => true,
    };
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
              onPressed: canContinue
                  ? (_step < 4 ? _next : () => Navigator.of(context).maybePop())
                  : null,
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
