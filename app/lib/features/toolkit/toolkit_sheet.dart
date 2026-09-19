import 'package:flutter/material.dart';

import '../../core/money/format.dart';
import '../../core/money/impulse_check.dart';
import '../../core/money/notes_calculator.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../../state/financial_state.dart';
import '../fx/fx_sheet.dart';
import '../shared/sheet_scaffold.dart';

/// The Philippine Financial Toolkit, the header's sparkle button.
///
/// FOUR TABS, matching the prototype's own overhaul
/// (`src/components/PhilippineFeaturesModal.tsx`, the newest commit on main):
/// Notes Calc, Mindset, Treats and FX Rates.
///
/// It used to be a list of tiles, two of which opened the tax calculator and
/// the business tax simulator. Founder direction, 2026-09-19: "Remove the tax
/// calculator, business tax simulator in the current build. Its already a
/// duplicate of those calculator in the Plan tab." Both are still reachable
/// from Plan, which is where the prototype keeps them too.
class ToolkitSheet extends StatefulWidget {
  const ToolkitSheet({super.key, required this.state});

  final FinancialState state;

  static Future<void> show(BuildContext context, FinancialState state) {
    return SheetScaffold.show<void>(
      context: context,
      palette: Palette.of(state.theme),
      builder: (BuildContext context) => ToolkitSheet(state: state),
    );
  }

  @override
  State<ToolkitSheet> createState() => _ToolkitSheetState();
}

class _ToolkitSheetState extends State<ToolkitSheet> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final Palette p = Palette.of(widget.state.theme);

    return SheetScaffold(
      palette: p,
      icon: Icons.auto_awesome_outlined,
      title: 'Philippine Toolkit',
      subtitle: 'Mindful spending, smart text calculations, and habit rewards',
      tabs: const <String>['Notes Calc', 'Mindset', 'Treats', 'FX Rates'],
      selectedTab: _tab,
      onSelectTab: (int i) => setState(() => _tab = i),
      child: switch (_tab) {
        0 => _NotesTab(palette: p),
        1 => _MindsetTab(palette: p, state: widget.state),
        2 => _TreatsTab(palette: p),
        _ => _FxTab(palette: p),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Notes Calc
// ---------------------------------------------------------------------------

class _NotesTab extends StatefulWidget {
  const _NotesTab({required this.palette});
  final Palette palette;

  @override
  State<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<_NotesTab> {
  /// The prototype's own starting text, kept so the feature explains itself
  /// without a tutorial: somebody sees `6*8` become 48 and understands the
  /// whole idea in one glance.
  final TextEditingController _c = TextEditingController(
    text:
        'ate 50\n'
        'kuya 600\n'
        'mama 6*8\n'
        'electricity 1250\n'
        'groceries 1850 + 450',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final NotesResult r = parseNotes(_c.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Type your notes one line at a time, with a label and an amount. '
          'Maths works too: 6*8, or 1850 + 450.',
          style: AppType.body(p),
        ),
        const SizedBox(height: Spacing.md),
        TextField(
          controller: _c,
          // BIGGER. Founder direction, 2026-09-19: "Expand the notepad in the
          // notes calc". It opened five lines tall on a screen with room for
          // far more, so a real day's worth of notes scrolled inside a box
          // while the space below it sat empty.
          //
          // No maxLines, so it grows with what is typed rather than stopping
          // at an arbitrary line and scrolling within itself. The sheet
          // already scrolls, which is the right place for it to happen.
          maxLines: null,
          minLines: 12,
          onChanged: (_) => setState(() {}),
          // The APP's own face, not 'monospace'. Salapify bundles Plus
          // Jakarta Sans and nothing else, so a declared monospace family is
          // whatever the device happens to have, which is a font nobody here
          // can look at. It rendered as empty boxes in the very first shot.
          style: AppType.body(p),
          decoration: InputDecoration(
            filled: true,
            fillColor: p.card,
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
        const SizedBox(height: Spacing.md),
        for (final NoteLine line in r.items)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    line.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.rowMeta(p).copyWith(
                      color: line.isValid ? p.textSecondary : p.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  // A line with no number says so, rather than showing ₱0.00
                  // as though it had been counted.
                  line.isValid ? formatPeso(line.value) : 'no amount',
                  style: AppType.rowMeta(p).copyWith(
                    color: line.isValid ? p.textPrimary : p.textMuted,
                    fontWeight: line.isValid ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: Spacing.sm),
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: p.accentSoft,
            borderRadius: BorderRadius.circular(Radii.tile),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Grand total',
                  style: AppType.rowTitle(p).copyWith(color: p.accent),
                ),
              ),
              Text(
                formatPeso(r.grandTotal),
                style: AppType.amountSmall(p).copyWith(color: p.accent),
              ),
            ],
          ),
        ),
        if (r.countedLines != r.items.length) ...<Widget>[
          const SizedBox(height: Spacing.xs),
          Text(
            // Said out loud, because a total that quietly skipped a line is
            // the one thing this tool must never do.
            '${r.countedLines} of ${r.items.length} lines had an amount.',
            style: AppType.caption(p),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Mindset
// ---------------------------------------------------------------------------

class _MindsetTab extends StatefulWidget {
  const _MindsetTab({required this.palette, required this.state});
  final Palette palette;
  final FinancialState state;

  @override
  State<_MindsetTab> createState() => _MindsetTabState();
}

class _MindsetTabState extends State<_MindsetTab> {
  final TextEditingController _name = TextEditingController(
    text: 'Wireless earbuds',
  );
  final TextEditingController _price = TextEditingController(text: '4500');
  final TextEditingController _income = TextEditingController(text: '35000');

  NeedOrWant _need = NeedOrWant.want;
  UseFrequency _use = UseFrequency.weekly;
  CheaperAlternative _cheaper = CheaperAlternative.yes;
  ImpulseResult? _result;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _income.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Three questions before you buy. The pause is the point.',
          style: AppType.body(p),
        ),
        const SizedBox(height: Spacing.md),
        SheetField(
          palette: p,
          label: 'What is it',
          controller: _name,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: Spacing.md),
        SheetField(
          palette: p,
          label: 'How much',
          controller: _price,
          prefix: '₱ ',
        ),
        const SizedBox(height: Spacing.md),
        SheetField(
          palette: p,
          label: 'Your monthly take-home',
          controller: _income,
          prefix: '₱ ',
        ),
        const SizedBox(height: Spacing.lg),
        _Choice<NeedOrWant>(
          palette: p,
          label: 'Do you need it, or want it?',
          value: _need,
          options: const <(NeedOrWant, String)>[
            (NeedOrWant.need, 'Need'),
            (NeedOrWant.want, 'Want'),
          ],
          onChanged: (NeedOrWant v) => setState(() => _need = v),
        ),
        _Choice<UseFrequency>(
          palette: p,
          label: 'How often would you use it?',
          value: _use,
          options: const <(UseFrequency, String)>[
            (UseFrequency.daily, 'Daily'),
            (UseFrequency.weekly, 'Weekly'),
            (UseFrequency.rarely, 'Rarely'),
          ],
          onChanged: (UseFrequency v) => setState(() => _use = v),
        ),
        _Choice<CheaperAlternative>(
          palette: p,
          label: 'Is there a cheaper version?',
          value: _cheaper,
          options: const <(CheaperAlternative, String)>[
            (CheaperAlternative.yes, 'Yes'),
            (CheaperAlternative.no, 'No'),
          ],
          onChanged: (CheaperAlternative v) => setState(() => _cheaper = v),
        ),
        const SizedBox(height: Spacing.md),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: p.accent,
            borderRadius: BorderRadius.circular(Radii.control),
            child: InkWell(
              onTap: () => setState(() {
                _result = checkImpulse(
                  price: double.tryParse(_price.text.trim()) ?? 0,
                  monthlyIncome: double.tryParse(_income.text.trim()) ?? 0,
                  needOrWant: _need,
                  useFrequency: _use,
                  cheaperAlternative: _cheaper,
                );
              }),
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                child: Text(
                  'Should I buy it?',
                  style: AppType.button(p, color: p.onAccent),
                ),
              ),
            ),
          ),
        ),
        if (_result != null) ...<Widget>[
          const SizedBox(height: Spacing.md),
          _Verdict(palette: p, result: _result!, item: _name.text.trim()),
        ],
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.palette,
    required this.result,
    required this.item,
  });

  final Palette palette;
  final ImpulseResult result;
  final String item;

  @override
  Widget build(BuildContext context) {
    // Colour AND the word, never colour alone: roughly one man in twelve
    // cannot separate this red from this green.
    final Color tint = switch (result.verdict) {
      ImpulseVerdict.green => palette.positive,
      ImpulseVerdict.yellow => palette.accent,
      ImpulseVerdict.red => palette.negative,
    };

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.tile),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  result.headline,
                  style: AppType.rowTitle(palette).copyWith(color: tint),
                ),
              ),
              Text(
                '${result.score} / 100',
                style: AppType.rowMeta(palette).copyWith(color: tint),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(result.advice, style: AppType.caption(palette)),
          if (result.hoursOfWork != null) ...<Widget>[
            const SizedBox(height: Spacing.sm),
            Text(
              // The line that actually changes minds. A price is abstract;
              // hours of your own life are not.
              'That is ${result.hoursOfWork!.toStringAsFixed(1)} hours of '
              'work${item.isEmpty ? '' : ' for $item'}.',
              style: AppType.rowMeta(palette),
            ),
          ],
        ],
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.palette,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final Palette palette;
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: AppType.label(palette)),
          const SizedBox(height: Spacing.xs),
          // Wrap rather than Row: three labels at a large system font size
          // overflow a 320dp phone, and a control that runs off the screen
          // cannot be tapped at all.
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.xs,
            children: <Widget>[
              for (final (T v, String text) o in options)
                Material(
                  color: o.$1 == value ? palette.accent : palette.card,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  child: InkWell(
                    onTap: () => onChanged(o.$1),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    // NO 'alignment' on this Container, and that is the
                    // whole reason these are pills and not full width bars.
                    // A Container given an alignment and no width expands to
                    // every pixel it is offered, so inside a Wrap each pill
                    // took the whole row and the group stacked vertically.
                    // This repository has now made that exact mistake three
                    // times; segmented_pills_test.dart is the guard.
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.pill),
                        border: Border.all(
                          color: o.$1 == value
                              ? palette.accent
                              : palette.border,
                        ),
                      ),
                      child: Center(
                        // widthFactor 1 so the Center hugs its child instead
                        // of filling the row, which is the same trap as the
                        // alignment above wearing a different hat.
                        widthFactor: 1,
                        child: Text(
                          o.$2,
                          style: AppType.rowMeta(palette).copyWith(
                            color: o.$1 == value
                                ? palette.onAccent
                                : palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Treats
// ---------------------------------------------------------------------------

/// A treat somebody has to earn.
class _Treat {
  _Treat({
    required this.name,
    required this.cost,
    required this.task,
    this.done = false,
  });

  final String name;
  final double cost;
  final String task;
  bool done;
  bool claimed = false;
}

class _TreatsTab extends StatefulWidget {
  const _TreatsTab({required this.palette});
  final Palette palette;

  @override
  State<_TreatsTab> createState() => _TreatsTabState();
}

class _TreatsTabState extends State<_TreatsTab> {
  /// The prototype's own three, and like the prototype these live only while
  /// the sheet is open. NOT persisted, deliberately: a treat list is stored
  /// data, and adding a new collection to the file is a data decision rather
  /// than a UI one. Written down here rather than done quietly.
  final List<_Treat> _treats = <_Treat>[
    _Treat(
      name: 'Iced caramel macchiato',
      cost: 180,
      task: 'Walk 5,000 steps and drink 2L of water',
      done: true,
    ),
    _Treat(
      name: 'Samgyupsal with friends',
      cost: 799,
      task: 'Review the week’s budget and categorise every entry',
    ),
    _Treat(
      name: 'New running shoes',
      cost: 2800,
      task: 'Five workouts this week without skipping',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final Palette p = widget.palette;
    final double earned = _treats
        .where((_Treat t) => t.done && !t.claimed)
        .fold<double>(0, (double s, _Treat t) => s + t.cost);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Pair a treat with something worth doing. Finish the task, then the '
          'treat is yours without the guilt.',
          style: AppType.body(p),
        ),
        const SizedBox(height: Spacing.md),
        for (final _Treat t in _treats)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Container(
              padding: const EdgeInsets.all(Spacing.md),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(Radii.tile),
                border: Border.all(
                  color: t.done ? p.positive.withValues(alpha: 0.5) : p.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: Text(t.name, style: AppType.rowTitle(p))),
                      Text(
                        formatPeso(t.cost),
                        style: AppType.rowMeta(
                          p,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(t.task, style: AppType.caption(p)),
                  const SizedBox(height: Spacing.sm),
                  Row(
                    children: <Widget>[
                      _Pill(
                        palette: p,
                        label: t.done ? 'Task done' : 'Mark task done',
                        filled: t.done,
                        onTap: () => setState(() => t.done = !t.done),
                      ),
                      const SizedBox(width: Spacing.sm),
                      if (t.done)
                        _Pill(
                          palette: p,
                          label: t.claimed ? 'Claimed' : 'Claim the treat',
                          filled: t.claimed,
                          onTap: () => setState(() => t.claimed = !t.claimed),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: Spacing.sm),
        Text(
          earned > 0
              ? '${formatPeso(earned)} of treats earned and not yet claimed.'
              : 'Nothing earned yet. Finish a task first.',
          style: AppType.rowMeta(p),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          // Said plainly, because a list that looks saved and is not is worse
          // than one that never pretended.
          'This list is not saved yet, so it starts fresh each time.',
          style: AppType.caption(p),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.palette,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final Palette palette;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? palette.positive : palette.surfaceAlt,
      borderRadius: BorderRadius.circular(Radii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          child: Text(
            label,
            style: AppType.rowMeta(palette).copyWith(
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : palette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. FX Rates
// ---------------------------------------------------------------------------

class _FxTab extends StatelessWidget {
  const _FxTab({required this.palette});
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    // The converter is its own sheet, already built and already fetching live
    // rates. Embedding a second copy here would be two things to keep in step.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Live rates between the peso and four major currencies, with the '
          'last good set kept for when there is no signal.',
          style: AppType.body(palette),
        ),
        const SizedBox(height: Spacing.md),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: palette.accent,
            borderRadius: BorderRadius.circular(Radii.control),
            child: InkWell(
              onTap: () {
                Navigator.of(context).pop();
                FxSheet.show(context, palette);
              },
              borderRadius: BorderRadius.circular(Radii.control),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                child: Text(
                  'Open the converter',
                  style: AppType.button(palette, color: palette.onAccent),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
