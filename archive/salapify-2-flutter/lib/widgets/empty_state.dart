// One shape for every empty screen.
//
// They had drifted into three different shapes. Insights got an icon, a
// heading, an explanation, and a button that took you somewhere. Utang got a
// card with a heading and a sentence, no icon and no way forward. History got
// bare centred text with no card at all, floating at an odd height down an
// otherwise blank screen. None of them was broken; side by side they read as
// three different apps.
//
// An empty screen is also the FIRST thing a new user sees on most tabs, so it
// carries more weight than its size suggests. The shape below is the Insights
// one, which was the best of the three, made shared so the three cannot drift
// apart again.
//
// The action is optional but strongly encouraged: an empty screen that only
// says "nothing here" leaves the reader to work out what to do next, and the
// whole reason they are looking at it is that they have not done that thing
// yet.

import 'package:flutter/material.dart';

import '../theme.dart';
import '../typography.dart';
import 'pan_mascot.dart';
import 'salapify_icon.dart';

class EmptyState extends StatelessWidget {
  /// Semantic icon name, resolved by salapify_icon.dart.
  final String icon;

  /// Show Pan instead of the icon.
  ///
  /// The rule, narrow on purpose: Pan appears on the empty state of a TAB,
  /// which is where a brand new user meets the app before they have any data.
  /// That is the moment a character earns its keep, because there is nothing
  /// else on screen to build any warmth.
  ///
  /// He does NOT appear on a filtered empty state ("no entries match"), which
  /// is a search result rather than a first meeting, and not on pushed
  /// screens. A character who turns up on every blank surface is wallpaper,
  /// and wallpaper is invisible within a day.
  final bool showPan;

  /// Reassuring, never scolding. "Nothing here yet, and that is okay" beats
  /// "No data".
  final String title;

  /// What this screen becomes once there is something in it, and what to do
  /// to get there.
  final String body;

  /// Label for the way forward. Null means no button, which should be rare
  /// and deliberate.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Which feeling Pan shows when [showPan] is set. Defaults to content, the
  /// at-ease look an empty screen deserves.
  final PanEmotion panEmotion;

  // NOT const on purpose. Every colour below is a mutable Barako getter
  // read in build(). Dart canonicalizes const instances, so a const call
  // site makes two builds compare equal and Element.updateChild skips
  // build() entirely, freezing this widget in the previous palette after
  // a theme switch or a night-mode flip. Removing const from the
  // CONSTRUCTOR is what makes the mistake impossible at every call site,
  // rather than something each caller has to remember.
  // ignore: prefer_const_constructors_in_immutables
  EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.showPan = false,
    this.panEmotion = PanEmotion.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showPan)
              // Calm, deliberately. An empty screen is not a problem to be
              // worried about, and it is the first thing a new user sees, so
              // the app's own character should look at ease with it.
              ExcludeSemantics(
                child: PanMascot.emotion(emotion: panEmotion, size: 76),
              )
            else
              SalapifyGlyph(icon, size: 24),
            const SizedBox(height: 8),
            Text(title, style: AppText.heading.w8),
            const SizedBox(height: 6),
            Text(
              body,
              style: AppText.label.w4
                  .tint(Barako.textSecondary)
                  .copyWith(height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Barako.primary,
                  foregroundColor: Barako.onPrimary,
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
