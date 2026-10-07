import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../info/info_dot.dart';
import '../info/info_sheet.dart';

/// The only thing onboarding asks somebody to type.
///
/// NOT WIRED INTO THE APP YET, for the reasons in [WelcomeScreen]'s doc.
///
/// ## Why one account, and why only one
///
/// It is the single irreducible datum. Without an account, net worth is zero,
/// Safe to Spend cannot compute, Reconcile has no account to select, and a
/// first logged entry has nowhere to land. It is also the cheapest number in
/// the person's life to produce, because they read it off their GCash home
/// screen, and it pays back immediately with a figure on Home that is theirs.
///
/// Everything else a first run is tempted to ask was cut and the reasons are
/// in docs/reviews/onboarding-design.md. The payday is the one worth naming
/// here: it is NOT asked, because a form on screen one spends the moment
/// money is salient weeks before it pays off. It is asked at the first income
/// entry instead, as a yes or no rather than a form. Budget limits are cut
/// too: a limit set before any spending is logged is a number pulled from the
/// air, and the first week of data contradicts it, which teaches somebody
/// that the app's figures are soft.
///
/// ## The i dot is doing real work here
///
/// Typing the balance your bank actually shows IS the Reconcile gesture, the
/// app's own differentiator, performed once against an empty ledger. That is
/// worth knowing and it is not worth saying on screen, which is exactly what
/// the dot is for: teaching that is pulled by somebody looking at the field,
/// not pushed at somebody who has not got there yet.
class FirstAccountScreen extends StatefulWidget {
  const FirstAccountScreen({super.key, required this.palette, this.onDone});

  final Palette palette;

  /// Takes the name and the opening balance as typed. Deliberately not a
  /// store write from in here: this screen collects, the caller decides.
  final void Function(String name, String balance)? onDone;

  @override
  State<FirstAccountScreen> createState() => _FirstAccountScreenState();
}

class _FirstAccountScreenState extends State<FirstAccountScreen> {
  /// GCash first, and that order is not alphabetical. It is the wallet most
  /// of this app's audience opens every day, so the common case is one tap
  /// away from done and the other two are still one tap each.
  static const List<({String label, IconData icon})> _kinds =
      <({String label, IconData icon})>[
        (label: 'GCash', icon: Icons.account_balance_wallet_outlined),
        (label: 'Bank', icon: Icons.account_balance_outlined),
        (label: 'Cash', icon: Icons.payments_outlined),
      ];

  int _kind = 0;
  final TextEditingController _name = TextEditingController(text: 'GCash');
  final TextEditingController _balance = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  void _pick(int i) {
    setState(() {
      _kind = i;
      // Overwrites only while the name is still one Salapify suggested. A
      // person who typed "Payroll BPI" and then taps a different chip keeps
      // what they wrote, because the chip is about the KIND and the field is
      // about the name.
      final bool untouched = _kinds.any(
        (({String label, IconData icon}) k) => k.label == _name.text,
      );
      if (untouched) _name.text = _kinds[i].label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final bool ready = _balance.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Spacing.xxl),

              Text('Where is your money?', style: AppType.hero(p)),
              const SizedBox(height: Spacing.sm),
              Text(
                'One place is enough to start. You can add the rest whenever '
                'you like.',
                style: AppType.body(p).copyWith(color: p.textSecondary),
              ),

              const SizedBox(height: Spacing.xxl),

              Row(
                children: <Widget>[
                  for (int i = 0; i < _kinds.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: _KindChip(
                        palette: p,
                        label: _kinds[i].label,
                        icon: _kinds[i].icon,
                        selected: i == _kind,
                        onTap: () => _pick(i),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: Spacing.xl),

              Text('What do you call it', style: AppType.label(p)),
              const SizedBox(height: Spacing.sm),
              _Field(palette: p, controller: _name, numeric: false),

              const SizedBox(height: Spacing.xl),

              Row(
                children: <Widget>[
                  Text('What it shows right now', style: AppType.label(p)),
                  const SizedBox(width: Spacing.sm),
                  InfoDot(
                    color: p.textMuted,
                    semanticLabel: 'Why Salapify asks for this balance',
                    onTap: () =>
                        InfoSheet.show(context, p, InfoTopic.openingBalance),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              _Field(
                palette: p,
                controller: _balance,
                numeric: true,
                hint: '0.00',
                big: true,
                onChanged: (_) => setState(() {}),
              ),

              const Spacer(),

              _Done(
                palette: p,
                enabled: ready,
                onTap: ready
                    ? () => widget.onDone?.call(
                        _name.text.trim(),
                        _balance.text.trim(),
                      )
                    : null,
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                // Says what the number is FOR, which is the only thing
                // somebody hesitating over this field is actually asking.
                'Salapify starts counting from here. Nothing is sent anywhere.',
                style: AppType.caption(p),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the three account kinds.
class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.palette,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.accentSoft : p.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.control),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(vertical: Spacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.control),
              border: Border.all(
                color: selected ? p.accent : p.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: selected ? p.accent : p.textSecondary,
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  label,
                  style: AppType.caption(p).copyWith(
                    color: selected ? p.textPrimary : p.textSecondary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A field, sized to its job.
class _Field extends StatelessWidget {
  const _Field({
    required this.palette,
    required this.controller,
    required this.numeric,
    this.hint,
    this.big = false,
    this.onChanged,
  });

  final Palette palette;
  final TextEditingController controller;
  final bool numeric;
  final String? hint;
  final bool big;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final Palette p = palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: <Widget>[
          if (big) ...<Widget>[
            Text('₱', style: AppType.hero(p).copyWith(color: p.textMuted)),
            const SizedBox(width: Spacing.sm),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              // WITH a decimal point, the same keyboard every money field in
              // the app asks for. Plain number maps to a keypad with no dot.
              keyboardType: numeric
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              style: big ? AppType.hero(p) : AppType.body(p),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: (big ? AppType.hero(p) : AppType.body(p)).copyWith(
                  color: p.textMuted,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: Spacing.md,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one action, with the press scale the house uses.
class _Done extends StatefulWidget {
  const _Done({
    required this.palette,
    required this.enabled,
    required this.onTap,
  });

  final Palette palette;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  State<_Done> createState() => _DoneState();
}

class _DoneState extends State<_Done> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final bool on = widget.enabled;

    return Semantics(
      button: true,
      enabled: on,
      child: GestureDetector(
        onTapDown: on ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        child: AnimatedScale(
          // Still when the phone asks for less motion.
          scale: _down && !reduceMotion(context) ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Material(
            color: on ? p.accent : p.border,
            borderRadius: BorderRadius.circular(Radii.control),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 52),
                alignment: Alignment.center,
                child: Text(
                  'Done',
                  style: AppType.button(
                    p,
                    color: on ? p.onAccent : p.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
