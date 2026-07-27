// The bottom bar's icons must be Salapify's, and must actually exist.
//
// This row is the only part of the app visible on every screen, and until now
// it was the one part that never went through salapify_icon.dart: main.dart
// reached for raw Icons.* constants directly. So a restyle of Salapify's icon
// set would have changed every screen except the strip sitting on all of them.
//
// Names are resolved at runtime through a map, which means a typo does not
// fail to compile. It draws the neutral fallback marker, on the bottom bar,
// forever. That is what this file is for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/screens/shell.dart';
import 'package:salapify/widgets/salapify_icon.dart';

void main() {
  test('every destination icon name resolves to a real glyph', () {
    for (final d in Destination.values) {
      expect(
        salapifyIcon(d.icon),
        isNot(Icons.label_important_outline),
        reason:
            'Destination.${d.name} asks for the icon named "${d.icon}", which '
            'is not in the map, so the bottom bar would draw the fallback '
            'marker. Add it to salapify_icon.dart rather than renaming this.',
      );
    }
  });

  test('and so does every selected variant', () {
    for (final d in Destination.values) {
      expect(
        salapifyIconSelected(d.icon),
        isNot(Icons.label_important_outline),
        reason:
            'The selected state of Destination.${d.name} falls through to the '
            'fallback marker, which means the tab you are ON is the one drawn '
            'wrong.',
      );
    }
  });

  test('selected and unselected are actually different glyphs', () {
    // The half that keeps the two above honest. salapifyIconSelected falls
    // back to the outlined form on purpose for the thirty icons that have no
    // filled twin, so "it resolved" is not the same as "it resolved to the
    // filled one". Every bottom bar destination is meant to have both.
    for (final d in Destination.values) {
      expect(
        salapifyIconSelected(d.icon),
        isNot(salapifyIcon(d.icon)),
        reason:
            'Destination.${d.name} draws the same glyph selected and '
            'unselected, so the only cue for which tab you are on is colour. '
            'Add "${d.icon}" to the _filled map.',
      );
    }
  });

  test('no two destinations share a label or an icon name', () {
    // A duplicated label makes the bar ambiguous to a screen reader and to
    // every test finder; a duplicated icon name makes two tabs look identical.
    expect(
      Destination.values.map((d) => d.label).toSet().length,
      Destination.values.length,
    );
    expect(
      Destination.values.map((d) => d.icon).toSet().length,
      Destination.values.length,
    );
  });
}
