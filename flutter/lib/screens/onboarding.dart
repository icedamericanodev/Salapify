// The first run, ported from the RN Onboarding: what Salapify is, the
// basics (currency and a starting monthly budget), and how to start. Three
// steps, no back button, no skip, every field carrying a default so there
// is nothing to get wrong, ending in the one settings patch that marks
// onboarding done and queues the first log.
//
// Two deliberate differences from RN, both safety:
// - Flutter starts EMPTY and seeds the sample set only when asked, so there
//   is no destructive "start empty" wipe and no confirm dialog for a brand
//   new user to misread. Nothing real can be lost here.
// - The notification ask is not in this flow yet; it arrives as its own
//   batch, so the step count reads 2 like the RN web variant.
//
// The gate lives in main.dart on store.needsOnboarding, whose derivation is
// the load-bearing part: any successfully loaded blob counts as onboarded
// unless the flag is literally false, so an existing user upgrading into
// this build is never greeted like a stranger.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/pan_mood.dart';
import '../theme.dart';
import '../widgets/pan_mascot.dart';

/// The four quick picks, the RN set; the full list lives in Menu.
const _quickCurrencies = [
  ('PHP', '₱'),
  ('USD', r'$'),
  ('EUR', '€'),
  ('SGD', r'S$'),
];

class OnboardingScreen extends StatefulWidget {
  final SalapifyStore store;

  // ignore: prefer_const_constructors_in_immutables
  OnboardingScreen({super.key, required this.store});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int step = 0;

  /// Seeded from existing settings so a restored user who somehow lands
  /// here (explicit onboarded false in a backup) is not reset, the RN rule.
  late String code = _initialCode();
  late String symbol = _initialSymbol();
  late final budgetController = TextEditingController(text: _initialLimit());
  bool saving = false;

  Map _settings() => (widget.store.data['settings'] as Map?) ?? const {};

  String _initialCode() => (_settings()['currencyCode'] as String?) ?? 'PHP';
  String _initialSymbol() => (_settings()['currency'] as String?) ?? '₱';
  String _initialLimit() {
    // 0 seeds as 0: it is a real stored answer ("do not budget me"), and a
    // restored onboarded-false backup whose owner chose it must not have
    // 20000 written back by a tap-through.
    final v = _settings()['monthlyLimit'];
    return v is num && v.isFinite && v >= 0 ? _plain(v) : '20000';
  }

  static String _plain(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    budgetController.dispose();
    super.dispose();
  }

  /// The RN budget parse exactly: commas and spaces stripped, a typed 0
  /// honored as a real answer, junk and empty falling back to 20000, capped
  /// at one hundred million.
  num _parsedLimit() {
    final raw = budgetController.text.replaceAll(RegExp(r'[, ]'), '').trim();
    if (raw.isEmpty) return 20000;
    final n = num.tryParse(raw);
    if (n == null || !n.isFinite || n < 0) return 20000;
    return n > 100000000 ? 100000000 : n;
  }

  Future<void> _finish(bool withSample) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await widget.store.completeOnboarding(
        currencyCode: code,
        currencySymbol: symbol,
        monthlyLimit: _parsedLimit(),
        withSampleData: withSample,
      );
      // No navigation: the gate in main.dart flips to the shell on the
      // store notify, and the shell acts on firstLogPrompt.
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save, nothing was changed. $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Barako.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: switch (step) {
                0 => _welcome(),
                1 => _basics(),
                _ => _howToStart(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcome() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Center(child: PanMascot(mood: PanMood.happy, size: 132)),
      const SizedBox(height: Gap.lg),
      Center(
        child: Text(
          'Salapify',
          style: TextStyle(
            color: Barako.text,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          "On your money's side.",
          style: TextStyle(color: Barako.textSecondary, fontSize: 15),
        ),
      ),
      const SizedBox(height: Gap.lg),
      Center(
        child: Wrap(
          spacing: 8,
          children: [
            for (final pill in const ['Free', 'Offline', 'No ads'])
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Barako.card,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: Barako.border),
                ),
                child: Text(
                  pill,
                  style: TextStyle(
                    color: Barako.primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: Gap.lg),
      Text(
        'Budget, debts, savings, utang, and bills. Everything stays on '
        'your phone. No account needed, ever.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Barako.textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      const SizedBox(height: Gap.xl),
      _primary('Get started', () => setState(() => step = 1)),
    ],
  );

  Widget _basics() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('STEP 1 OF 2', style: Barako.kickerStyle),
      const SizedBox(height: 6),
      Text(
        'The basics',
        style: TextStyle(
          color: Barako.text,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: Gap.lg),
      Text('Your currency', style: Barako.cardKickerStyle),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (c, s) in _quickCurrencies)
            ChoiceChip(
              label: Text('$s $c'),
              selected: code == c,
              onSelected: (_) => setState(() {
                code = c;
                symbol = s;
              }),
              selectedColor: Barako.primary,
              backgroundColor: Barako.card,
              labelStyle: TextStyle(
                color: code == c ? Barako.onPrimary : Barako.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: Barako.border),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'More currencies live in Menu.',
        style: TextStyle(color: Barako.muted, fontSize: 12),
      ),
      const SizedBox(height: Gap.lg),
      Text('Monthly spending budget', style: Barako.cardKickerStyle),
      const SizedBox(height: 8),
      TextField(
        controller: budgetController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          color: Barako.text,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: '20000',
          hintStyle: TextStyle(color: Barako.faint),
          prefixText: '$symbol ',
          prefixStyle: TextStyle(color: Barako.muted, fontSize: 20),
          filled: true,
          fillColor: Barako.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: BorderSide(color: Barako.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            borderSide: BorderSide(color: Barako.border),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'A starting line, not a cage. Change it anytime in Menu.',
        style: TextStyle(color: Barako.muted, fontSize: 12),
      ),
      const SizedBox(height: Gap.xl),
      _primary('Next', () => setState(() => step = 2)),
    ],
  );

  Widget _howToStart() {
    // If anything already exists (a fresh user who quit mid-welcome after
    // seeding the sample), never offer seeding again and never offer a
    // wipe: one honest button forward.
    final d = widget.store.data;
    final hasAnything = [
      'accounts',
      'transactions',
      'debts',
      'receivables',
    ].any((k) => (d[k] as List? ?? const []).isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STEP 2 OF 2', style: Barako.kickerStyle),
        const SizedBox(height: 6),
        Text(
          hasAnything ? 'You are all set.' : 'How do you want to start?',
          style: TextStyle(
            color: Barako.text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: Gap.md),
        Text(
          hasAnything
              ? 'Add your accounts, log your first entry, and your chain '
                    'starts today.'
              : 'Most people start clean and log their own money. The app '
                    'also has a little sample data if you would rather look '
                    'around first; it is clearly marked and removable in '
                    'one tap.',
          style: TextStyle(
            color: Barako.textSecondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: Gap.xl),
        if (hasAnything)
          _primary('Start tracking', saving ? null : () => _finish(false))
        else ...[
          _primary(
            'Start with a clean slate',
            saving ? null : () => _finish(false),
          ),
          const SizedBox(height: Gap.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: saving ? null : () => _finish(true),
              style: OutlinedButton.styleFrom(
                foregroundColor: Barako.primaryText,
                side: BorderSide(color: Barako.primary),
                minimumSize: const Size(0, 48),
              ),
              child: const Text(
                'Explore the sample data first',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
        const SizedBox(height: Gap.lg),
        Text(
          'Tip: after this, the Budget tab is where daily life happens. '
          'Log anything today and your chain starts.',
          style: TextStyle(color: Barako.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Widget _primary(String label, VoidCallback? onTap) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: Barako.primary,
        foregroundColor: Barako.onPrimary,
        minimumSize: const Size(0, 48),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
