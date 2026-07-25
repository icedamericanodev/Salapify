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
import 'salapify_icon.dart';

class EmptyState extends StatelessWidget {
  /// Semantic icon name, resolved by salapify_icon.dart.
  final String icon;

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

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SalapifyGlyph(icon, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Barako.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(
                color: Barako.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
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
