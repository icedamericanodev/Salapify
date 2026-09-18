import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// A tab that has not been migrated yet. It says so plainly rather than
/// showing an empty screen that could be mistaken for a bug.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.palette,
    required this.title,
    required this.note,
  });

  final Palette palette;
  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.construction_outlined, size: 34, color: palette.textMuted),
            const SizedBox(height: Spacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              note,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: palette.textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
