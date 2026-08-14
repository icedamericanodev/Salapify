// The Money Mindset flow: a four-step wizard (Context, Impact, Decision,
// Reflection) that replaces the single long screen. This file holds the
// scaffold (step header + paged body + Back/Continue) and Step 1, Context.
// Steps 2 to 4 are placeholders here and grow in following changes. All the
// money still comes from the read-only Decision Score engine; nothing here
// writes.
import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/currencies.dart' show baseCurrencySymbol;
import '../theme.dart';
import '../typography.dart';
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
  final _page = PageController();
  int _step = 1;

  String _purchaseType = 'oneTime';
  final _itemName = TextEditingController();
  final _amount = TextEditingController();
  String? _categoryId;

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
                _placeholder(
                  'Impact',
                  'The Decision Score and what-if lives here.',
                ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _purchaseType = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? Barako.primary.withValues(alpha: 0.08)
                  : Barako.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Barako.primary : Barako.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: selected
                        ? Barako.primary.withValues(alpha: 0.15)
                        : Barako.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    salapifyIcon(icon),
                    size: 22,
                    color: selected ? Barako.primary : Barako.textSecondary,
                  ),
                ),
                const SizedBox(width: 14),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Barako.surfaceRaised,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(salapifyIcon('cart'), size: 20, color: Barako.muted),
          ),
          const SizedBox(width: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanMascot.emotion(emotion: PanEmotion.content, size: 44),
          const SizedBox(width: 12),
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
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? Barako.primary.withValues(alpha: 0.12)
                : Barako.card,
            borderRadius: BorderRadius.circular(10),
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
