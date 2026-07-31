// One shape for a screen that cannot show its content because something is
// wrong, as opposed to EmptyState, which is a screen with nothing in it YET.
//
// The difference matters to the reader. "Nothing to read yet, and that is fine"
// is reassuring and correct on a brand new account; shown when the ledger
// failed to load it would be a lie, because there IS data, the app just could
// not read it. This says so plainly and points to the way out, without ever
// implying the data is gone (an unreadable load overwrites nothing).
//
// Same card-and-column shape as EmptyState so the two read as one app, with a
// problem-toned icon instead of a mascot. Not const, for the same palette
// reason spelled out in empty_state.dart.

import 'package:flutter/material.dart';

import '../theme.dart';
import 'salapify_icon.dart';

class ErrorState extends StatelessWidget {
  /// Semantic icon name, resolved by salapify_icon.dart. Drawn in the warning
  /// accent so the trouble is signalled by colour AND the words below, never
  /// colour alone.
  final String icon;

  /// Plain and calm. "Your saved data could not be read" beats "Error".
  final String title;

  /// What happened and, where possible, the reassuring part (nothing was lost).
  final String body;

  /// The way forward. Null means no button.
  final String? actionLabel;
  final VoidCallback? onAction;

  // ignore: prefer_const_constructors_in_immutables
  ErrorState({
    super.key,
    required this.title,
    required this.body,
    this.icon = 'inspect',
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
            SalapifyGlyph(icon, size: 24, color: Barako.warning),
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
