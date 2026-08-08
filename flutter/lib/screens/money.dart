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
// the debts view survives a segment flip, and the whole thing sits inside the
// shell's outer IndexedStack, so it survives a tab flip too. Neither list uses
// the ambient PrimaryScrollController: with both mounted at once they would
// fight over it and throw, so this screen owns one controller per segment and
// hands the shell whichever is active for its scroll-to-top.

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

  // ignore: prefer_const_constructors_in_immutables
  MoneyScreen({super.key, required this.store, this.onMenu});

  @override
  State<MoneyScreen> createState() => MoneyScreenState();
}

class MoneyScreenState extends State<MoneyScreen> {
  MoneySegment segment = MoneySegment.owe;

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

  /// The shell calls this when the Utang tab is re-tapped while active.
  ScrollController get activeController =>
      segment == MoneySegment.owe ? _oweController : _owedController;

  /// Jump straight to a segment, for taps that mean one side specifically:
  /// a "follow up Migs" check-in means the money owed TO you, and landing it
  /// on "I owe" would show a screen with no Migs anywhere on it.
  void showSegment(MoneySegment s) {
    if (s != segment) setState(() => segment = s);
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
