// The Subscription path's home: every subscription the person tracks, with a
// running monthly and annual total, and add / edit / delete. Read-only money in
// the Salapify sense (it records what the person pays elsewhere and never moves
// a Salapify balance); the totals come from the tested overview engine.
import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/currencies.dart' show baseCurrencySymbol;
import '../money/format.dart' show formatMoney;
import '../money/mindset_subscriptions.dart';
import '../theme.dart';
import '../typography.dart';
import '../widgets/salapify_icon.dart';
import '../widgets/segmented.dart';
import 'log_sheet.dart' show parseAmount;

class MindsetSubscriptionsScreen extends StatefulWidget {
  const MindsetSubscriptionsScreen({super.key, required this.store});

  final SalapifyStore store;

  @override
  State<MindsetSubscriptionsScreen> createState() =>
      _MindsetSubscriptionsScreenState();
}

class _MindsetSubscriptionsScreenState
    extends State<MindsetSubscriptionsScreen> {
  List<Subscription> get _subs =>
      parseSubscriptions(widget.store.mindsetSubscriptions);

  Future<void> _openEditor([Subscription? existing]) async {
    final result = await showModalBottomSheet<_SubDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SubscriptionEditor(existing: existing),
    );
    if (result == null) return;
    if (existing == null) {
      await widget.store.addMindsetSubscription(
        name: result.name,
        amount: result.amount,
        cycle: result.cycle,
        emoji: result.emoji,
      );
    } else {
      await widget.store.patchMindsetSubscription(existing.id, {
        'name': result.name,
        'amount': result.amount,
        'cycle': result.cycle,
        if (result.emoji.isNotEmpty) 'emoji': result.emoji,
      });
    }
    if (mounted) setState(() {});
  }

  Future<void> _confirmDelete(Subscription sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Barako.card,
        title: Text('Remove ${sub.name}?', style: AppText.body.w7),
        content: Text(
          'This only removes it from your subscriptions list. It does not '
          'cancel the service or move any money.',
          style: AppText.small.tint(Barako.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep', style: AppText.small.w7.tint(Barako.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: AppText.small.w7.tint(Barako.warningStrong),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.store.removeMindsetSubscription(sub.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final subs = _subs;
    final overview = subscriptionsOverview(subs);
    return Scaffold(
      backgroundColor: Barako.background,
      appBar: AppBar(
        title: const Text('My subscriptions'),
        leading: IconButton(
          icon: Icon(salapifyIcon('close'), color: Barako.text),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Close',
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: Barako.primary,
        icon: Icon(salapifyIcon('add'), color: Barako.onPrimary),
        label: Text('Add', style: AppText.small.w7.tint(Barako.onPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        children: [
          _overviewCard(overview),
          const SizedBox(height: Gap.lg),
          if (subs.isEmpty)
            _empty()
          else
            for (final sub in subs) ...[
              _row(sub),
              const SizedBox(height: Gap.sm),
            ],
        ],
      ),
    );
  }

  Widget _overviewCard(SubscriptionsOverview o) {
    return Container(
      padding: Insets.hero,
      decoration: BoxDecoration(
        color: Barako.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.hero),
        border: Border.all(color: Barako.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            o.count == 1 ? '1 subscription' : '${o.count} subscriptions',
            style: AppText.small.w7.tint(Barako.primary),
          ),
          const SizedBox(height: Gap.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  formatMoney(o.monthlyTotal),
                  style: AppText.amountLg.tabular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'a month',
                  style: AppText.small.tint(Barako.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'That is ${formatMoney(o.annualTotal)} a year.',
            style: AppText.small.tint(Barako.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(Gap.xl),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: Barako.border),
      ),
      child: Column(
        children: [
          Icon(salapifyIcon('repeat'), size: 36, color: Barako.muted),
          const SizedBox(height: Gap.md),
          Text(
            'No subscriptions yet',
            style: AppText.body.w7,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Add the services you pay for monthly or yearly to see what they '
            'cost you together.',
            style: AppText.small.tint(Barako.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _row(Subscription sub) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => _openEditor(sub),
        child: Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(
            color: Barako.card,
            borderRadius: BorderRadius.circular(Radii.card),
            border: Border.all(color: Barako.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Barako.surfaceRaised,
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: sub.emoji.isNotEmpty
                    ? Text(sub.emoji, style: AppText.title)
                    : Icon(
                        salapifyIcon('repeat'),
                        size: 20,
                        color: Barako.textSecondary,
                      ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.name, style: AppText.body.w7),
                    const SizedBox(height: 2),
                    Text(
                      sub.isAnnual
                          ? '${formatMoney(sub.amount)} a year'
                          : '${formatMoney(sub.amount)} a month',
                      style: AppText.small.tint(Barako.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              if (sub.isAnnual)
                Text(
                  '${formatMoney(sub.monthlyEquivalent)}/mo',
                  style: AppText.small.w7.tint(Barako.primary),
                ),
              IconButton(
                icon: Icon(
                  salapifyIcon('delete'),
                  size: 18,
                  color: Barako.muted,
                ),
                onPressed: () => _confirmDelete(sub),
                tooltip: 'Remove',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubDraft {
  final String name;
  final double amount;
  final String cycle;
  final String emoji;
  const _SubDraft(this.name, this.amount, this.cycle, this.emoji);
}

class _SubscriptionEditor extends StatefulWidget {
  const _SubscriptionEditor({this.existing});
  final Subscription? existing;

  @override
  State<_SubscriptionEditor> createState() => _SubscriptionEditorState();
}

class _SubscriptionEditorState extends State<_SubscriptionEditor> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _emoji;
  late String _cycle;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(
      text: e != null && e.amount > 0
          ? (e.amount % 1 == 0
                ? e.amount.toStringAsFixed(0)
                : e.amount.toStringAsFixed(2))
          : '',
    );
    _emoji = TextEditingController(text: e?.emoji ?? '');
    _cycle = e?.cycle ?? 'monthly';
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _emoji.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && (parseAmount(_amount.text) ?? 0) > 0;

  void _save() {
    final amt = parseAmount(_amount.text) ?? 0;
    Navigator.pop(
      context,
      _SubDraft(_name.text.trim(), amt, _cycle, _emoji.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Container(
        decoration: BoxDecoration(
          color: Barako.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            Text(
              widget.existing == null
                  ? 'Add subscription'
                  : 'Edit subscription',
              style: AppText.title.w7,
            ),
            const SizedBox(height: Gap.lg),
            Text('Name', style: AppText.small.w7),
            const SizedBox(height: Gap.sm),
            _field(_name, 'e.g. Streaming', autofocus: true),
            const SizedBox(height: Gap.lg),
            Text('Price', style: AppText.small.w7),
            const SizedBox(height: Gap.sm),
            _field(_amount, '0', prefix: baseCurrencySymbol, number: true),
            const SizedBox(height: Gap.lg),
            Text('Billing', style: AppText.small.w7),
            const SizedBox(height: Gap.sm),
            Segmented<String>(
              options: const [
                SegmentOption(value: 'monthly', label: 'Monthly'),
                SegmentOption(value: 'annual', label: 'Yearly'),
              ],
              current: _cycle,
              onPick: (v) => setState(() => _cycle = v),
            ),
            const SizedBox(height: Gap.lg),
            Text('Emoji (optional)', style: AppText.small.w7),
            const SizedBox(height: Gap.sm),
            _field(_emoji, 'Add one if you like'),
            const SizedBox(height: Gap.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _valid ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  disabledBackgroundColor: Barako.border,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Save',
                  style: AppText.body.w7.tint(Barako.onPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    String? prefix,
    bool number = false,
    bool autofocus = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
      decoration: BoxDecoration(
        color: Barako.card,
        borderRadius: BorderRadius.circular(Radii.field),
        border: Border.all(color: Barako.border),
      ),
      child: Row(
        children: [
          if (prefix != null) ...[
            Text(prefix, style: AppText.body.w7.tint(Barako.textSecondary)),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: c,
              autofocus: autofocus,
              keyboardType: number
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: AppText.body.w7,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: hint,
                hintStyle: AppText.body.tint(Barako.muted),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }
}
