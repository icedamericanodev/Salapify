// Card. One shared surface so cards, hero money panels, and sheets all speak
// the same visual language: consistent radius, padding, border, and depth.
// Before this, every screen hand-rolled its own card styles, so changing the
// look meant editing a dozen files. Now one edit here updates everywhere.
// Reads live theme colors through useTheme(), so all 8 palettes and both light
// and dark just work with no per-screen code.
//
// Props:
//  - variant: 'flat' (border only, default), 'raised' (soft shadow plus a
//    lighter surface so dark themes still read as lifted), or 'hero' (raised
//    plus the extra-round radius and roomy padding for headline money panels).
//  - padding: 'lg' (default) or 'xl'. hero always uses 'xl'.
//  - onPress: when set, the card becomes a pressable that springs down a touch
//    on press with a light haptic (via PressableScale), so tapping a card feels
//    physical. Reduce motion falls back to a gentle opacity dip, no buzz.
//  - haptic: which buzz a pressable card fires on press ('light' by default,
//    pass null to silence). Ignored when onPress is not set.
//  - warning: draws a red border, reserved for debt and over-limit states.
//  - style: extra styles, applied last so a screen can still override.
//  - accessibilityRole / accessibilityLabel: passed through to the pressable
//    so screen readers keep announcing what they announced before.

import { useMemo } from 'react';
import { StyleSheet, View } from 'react-native';
import { spacing, radius, elevation } from '../theme';
import { useTheme } from '../context/Theme';
import PressableScale from './motion/PressableScale';

export default function Card({
  variant = 'flat',
  padding = 'lg',
  onPress,
  warning = false,
  haptic = 'light',
  style,
  children,
  accessibilityRole,
  accessibilityLabel,
  ...rest
}) {
  const { colors } = useTheme();
  const styles = useMemo(() => makeStyles(colors), [colors]);

  const isHero = variant === 'hero';
  const isRaised = isHero || variant === 'raised';
  // hero always gets the roomy padding; otherwise honor the prop.
  const padKey = isHero ? 'xl' : padding;

  // Order matters: warning after raised so a red border wins over the raised
  // border, and style last so a screen can still override anything.
  const base = [
    styles.card,
    styles[`pad_${padKey}`],
    isHero && styles.hero,
    isRaised && styles.raised,
    warning && styles.warning,
    style,
  ];

  if (onPress) {
    return (
      <PressableScale
        onPress={onPress}
        haptic={haptic}
        accessibilityRole={accessibilityRole || 'button'}
        accessibilityLabel={accessibilityLabel}
        style={base}
        {...rest}
      >
        {children}
      </PressableScale>
    );
  }

  return (
    <View
      style={base}
      accessibilityRole={accessibilityRole}
      accessibilityLabel={accessibilityLabel}
      {...rest}
    >
      {children}
    </View>
  );
}

function makeStyles(colors) {
  return StyleSheet.create({
    card: {
      backgroundColor: colors.card,
      borderColor: colors.border,
      borderWidth: 1,
      borderRadius: radius.lg,
    },
    pad_lg: { padding: spacing.lg },
    pad_xl: { padding: spacing.xl },
    hero: { borderRadius: radius.xl },
    // raised uses the soft shadow AND a lighter surface, so on dark espresso
    // themes where shadows barely show the card still reads as lifted.
    raised: {
      backgroundColor: colors.surfaceRaised,
      ...elevation.raised,
    },
    warning: { borderColor: colors.warning },
  });
}
