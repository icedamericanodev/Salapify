import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../theme.dart';
import '../typography.dart';
import 'salapify_icon.dart';

/// Compact progress feedback for work that lasts long enough to acknowledge.
/// Prefer keeping existing financial content visible during refreshes.
class SalapifyUpdatingIndicator extends StatelessWidget {
  final String label;
  const SalapifyUpdatingIndicator({
    super.key,
    this.label = 'Updating insights…',
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!reduceMotion)
              SpinKitThreeBounce(color: Barako.primary, size: 18)
            else
              SalapifyGlyph(
                'refresh',
                size: 18,
                boxed: false,
                color: Barako.primary,
              ),
            const SizedBox(width: 8),
            Text(label, style: AppText.small),
          ],
        ),
      ),
    );
  }
}
