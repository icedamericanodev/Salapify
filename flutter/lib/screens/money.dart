// The Utang tab, holding both directions of owing.
//
// The founder's call, and the numbers backed it: what you OWE is the richer,
// more pressing screen (strategy switch, debt-free projection, interest cost),
// and it was buried behind Menu while the smaller who-owes-you list owned a
// bottom tab. One tab now, two segments, "I owe" first.
//
// The label stays Utang, and the merge makes it MORE correct, not less: utang
// in Tagalog is primarily what you owe. A tab named Utang that showed only
// receivables was the odd one out. The English glosses sit right beside it in
// the segments, which is what the identity-noun rule asks for.
//
// The two segments live in an inner IndexedStack, so the strategy switch in
// the debts view survives a segment flip. It no longer survives being CLOSED:
// Utang left the bottom bar (founder direction, matching the mockup) and is a
// pushed screen now, so popping it disposes this State and the transient
// strategy resets to its default on the next open, the same as every other
// pushed screen. Neither list uses the ambient PrimaryScrollController: with
// both mounted at once they would fight over it and throw, so this screen owns
// one controller per segment.

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/screen_header.dart';
import '../widgets/segmented.dart';
import 'debts.dart';
import 'utang.dart';
import '../widgets/salapify_icon.dart';

/// The two directions of owing.
enum MoneySegment { owe, owed }

class MoneyScreen extends StatefulWidget {
  final SalapifyStore store;
  final VoidCallback? onMenu;

  /// Pops this screen. Utang is a pushed screen now (it left the bar), so it
  /// carries a back arrow rather than a Menu key. Null when hosted some other
  /// way.
  final VoidCallback? onBack;

  /// Which side to open on. Utang is no longer a bottom tab (it is pushed from
  /// Home and the Menu now), so a caller that means one side specifically, a
  /// "follow up Migs" check-in or a debt-due tap, passes it here at construction
  /// instead of flipping a persistent tab's segment after the fact.
  final MoneySegment initialSegment;

  // ignore: prefer_const_constructors_in_immutables
  MoneyScreen({
    super.key,
    required this.store,
    this.onMenu,
    this.onBack,
    this.initialSegment = MoneySegment.owe,
  });

  @override
  State<MoneyScreen> createState() => MoneyScreenState();
}

class MoneyScreenState extends State<MoneyScreen> {
  late MoneySegment segment = widget.initialSegment;

  /// One controller per segment, owned here. See the header comment: two
  /// mounted scrollables cannot share the primary controller.
  final _oweController = ScrollController();
  final _owedController = ScrollController();

  @override
  void dispose() {
    _oweController.dispose();
    _owedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owe = segment == MoneySegment.owe;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Gap.gutter,
              Gap.sm,
              Gap.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(
                  'Utang',
                  subtitle: owe
                      ? 'What you owe, and the plan to zero'
                      : 'Money owed to you, oldest first',
                  onMenu: widget.onMenu,
                  onBack: widget.onBack,
                  // The create action follows the segment, so each half keeps
                  // the one it had when it was its own screen.
                  trailing: !widget.store.canWrite
                      ? null
                      : owe
                      ? FilledButton.icon(
                          onPressed: () =>
                              showDebtFormSheet(context, widget.store),
                          icon: Icon(salapifyIcon('add'), size: 18),
                          label: const Text('New'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Barako.primary,
                            foregroundColor: Barako.onPrimary,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md,
                            ),
                          ),
                        )
                      : newUtangButton(context, widget.store),
                ),
                Segmented<MoneySegment>(
                  current: segment,
                  onPick: (s) => setState(() => segment = s),
                  options: const [
                    SegmentOption(
                      value: MoneySegment.owe,
                      label: 'I owe',
                      semanticLabel: 'What I owe',
                    ),
                    SegmentOption(
                      value: MoneySegment.owed,
                      label: 'Owed to me',
                      semanticLabel: 'Money owed to me',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.xs),
          Expanded(
            child: IndexedStack(
              index: segment.index,
              children: [
                DebtsView(
                  store: widget.store,
                  controller: _oweController,
                  padding: Insets.tabScreen.copyWith(top: Gap.md),
                ),
                UtangBody(
                  store: widget.store,
                  controller: _owedController,
                  padding: Insets.tabScreen.copyWith(top: Gap.md),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
