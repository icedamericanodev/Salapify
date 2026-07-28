// The first run, ported from the RN Onboarding: what Salapify is, the
// basics (currency and a starting monthly budget), the nightly nudge ask,
// and how to start. No back button, no skip, every field carrying a default
// so there is nothing to get wrong, ending in the one settings patch that
// marks onboarding done and queues the first log.
//
// One deliberate difference from RN, and it is safety: Flutter starts EMPTY
// and seeds the sample set only when asked, so there is no destructive
// "start empty" wipe and no confirm dialog for a brand new user to misread.
// Nothing real can be lost here.
//
// The step COUNT is not fixed, the same as RN: a device that cannot show
// reminders at all (the web preview) never sees the nudge step, and the
// kickers read 2 instead of 3 rather than announcing a step that does not
// exist.
//
// The gate lives in main.dart on store.needsOnboarding, whose derivation is
// the load-bearing part: any successfully loaded blob counts as onboarded
// unless the flag is literally false, so an existing user upgrading into
// this build is never greeted like a stranger.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../money/pan_mood.dart';
import '../services/notifications.dart';
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

  /// Whether to show the nightly nudge step. Defaults to whether this device
  /// can show reminders at all.
  ///
  /// A test seam, like OverviewScreen's clock: the widget suite runs on a
  /// desktop VM where reminders are unsupported, so without this the step
  /// could never be reached by a test at all, and the one part of the flow
  /// that touches the OS would ship unguarded.
  final bool? showNudge;

  /// Asks the OS for notification permission. Injectable for the same
  /// reason: the real call can only ever answer "no" in a test.
  final Future<bool> Function() askPermission;

  // ignore: prefer_const_constructors_in_immutables
  OnboardingScreen({
    super.key,
    required this.store,
    this.showNudge,
    this.askPermission = Reminders.requestPermission,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// The steps, by name. They are compared and jumped between in four places,
/// and a bare 2 meant "the nudge" in one of them and "how to start" in
/// another the moment the nudge became optional.
enum _Step { welcome, basics, nudge, start }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Step step = _Step.welcome;

  /// Set only when the phone actually granted permission, so a refused
  /// dialog can never leave reminders switched on in settings that the OS
  /// will silently swallow.
  bool nightlyNudge = false;

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

  /// Whether this run of the flow includes the nudge step, and therefore
  /// how many steps the kickers should claim.
  bool get _nudgeStep => widget.showNudge ?? Reminders.supported;
  int get _stepCount => _nudgeStep ? 3 : 2;

  /// The nightly nudge choice. Yes asks the phone first and only remembers
  /// the answer when it is granted; either way the flow moves on, because
  /// this step must never be able to trap anyone behind a permission dialog
  /// they cannot get back to.
  Future<void> _askNudge() async {
    var granted = false;
    try {
      granted = await widget.askPermission();
    } catch (_) {
      // Permission plumbing must never block onboarding.
    }
    if (!mounted) return;
    setState(() {
      nightlyNudge = granted;
      step = _Step.start;
    });
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
        nightlyNudge: nightlyNudge,
      );
      // Lay tonight's reminder now rather than at the next launch. The app
      // only reschedules on load and on resume, and someone who just said
      // yes to an 8pm nudge should get it tonight, not tomorrow. A no-op on
      // any device that cannot show reminders.
      if (nightlyNudge) {
        await Reminders.reschedule(widget.store.data, DateTime.now());
      }
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
                _Step.welcome => _welcome(),
                _Step.basics => _basics(),
                _Step.nudge => _nudge(),
                _Step.start => _howToStart(),
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
      _primary('Get started', () => setState(() => step = _Step.basics)),
    ],
  );

  Widget _basics() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('STEP 1 OF $_stepCount', style: Barako.kickerStyle),
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
      _primary(
        'Next',
        () => setState(() => step = _nudgeStep ? _Step.nudge : _Step.start),
      ),
    ],
  );

  /// The nightly nudge ask. Both answers carry the SAME visual weight, the
  /// RN decision kept on purpose: a "no" that looks like the lesser button
  /// is a no the design is arguing with, and a yes collected that way is
  /// worth nothing to a person who then mutes the app a week later.
  Widget _nudge() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('STEP 2 OF $_stepCount', style: Barako.kickerStyle),
      const SizedBox(height: 6),
      Text(
        'A 30 second nudge at night?',
        style: TextStyle(
          color: Barako.text,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: Gap.md),
      Text(
        'People who log daily actually change how they spend. One quiet '
        'reminder at 8pm, plus a heads up on payday. No sounds, no spam, '
        'and you can switch it off any time in Menu.',
        style: TextStyle(
          color: Barako.textSecondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      const SizedBox(height: Gap.xl),
      _choice('Yes, remind me at night', _askNudge),
      const SizedBox(height: Gap.sm),
      _choice('No thanks', () => setState(() => step = _Step.start)),
    ],
  );

  /// One of a pair of equally weighted answers. Outlined rather than filled,
  /// because two filled accent buttons stacked read as one button and one
  /// mistake, and the point here is that neither answer is the mistake.
  Widget _choice(String label, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Barako.primaryText,
        side: BorderSide(color: Barako.primary),
        minimumSize: const Size(0, 52),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
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
        Text('STEP $_stepCount OF $_stepCount', style: Barako.kickerStyle),
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
