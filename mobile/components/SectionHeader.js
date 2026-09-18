// SectionHeader. One shared treatment for the little "overline" labels that sit
// above cards and lists (QUICK ADD, RECENT, BILLS BEFORE SWELDO, and so on).
// Before this, each screen redefined its own sectionTitle: index and budget used
// letterSpacing 1.5, insights used 1.2, person used the softGreen kicker color.
// That drift meant the same label looked slightly different on every tab. Now one
// component owns the look, so one edit here restyles every section label at once.
//
// The chosen look: colors.muted (the calm, secondary label color the majority of
// screens already used, and distinct from the in-card softGreen kicker so a
// section label never blurs with a card's own kicker), the caption size, medium
// weight, and letterSpacing 1.2 (the cleaner of the two spacings, a touch tighter
// than the old 1.5 so wide labels do not sprawl). Callers still pass the text
// already uppercased, exactly as the old <Text> labels did, so nothing about the
// wording changes.
//
// Reads live theme colors through useTheme(), so all 8 palettes and both light and
// dark just work with no per-screen code.
//
// Props:
//  - title: the label string (pass it uppercased, as the old labels were).
//  - trailing: an optional node shown at the end of the row, right aligned, for a
//    Pro badge, a count, or a "See all" link. When omitted the header is a plain
//    single line of text.
//  - style: extra styles, applied last so a screen can still nudge spacing.
// Accessibility: the label carries accessibilityRole="header" so screen readers
// announce it as a heading and users can jump between sections, matching how a
// section title should behave.

import { useMemo } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { spacing, fontSize, fontWeight } from '../theme';
import { useTheme } from '../context/Theme';

export default function SectionHeader({ title, trailing, style }) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  if (trailing) {
    return (
      <View style={[styles.row, style]}>
        <Text style={styles.title} accessibilityRole="header">
          {title}
        </Text>
        {trailing}
      </View>
    );
  }

  return (
    <Text style={[styles.title, styles.block, style]} accessibilityRole="header">
      {title}
    </Text>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    title: {
      color: colors.muted,
      fontSize: fontSize.caption,
      fontWeight: fontWeight.medium,
      letterSpacing: 1.2,
    },
    // Spacing for the standalone (no trailing) case, so a bare header keeps the
    // same gap below it and slight inset the old sectionTitle had.
    block: {
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
    // The row case owns the spacing itself so the title stays margin free and both
    // sides center on one line.
    row: {
      flexDirection: 'row',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: spacing.sm,
      paddingHorizontal: spacing.xs,
    },
  });
}
