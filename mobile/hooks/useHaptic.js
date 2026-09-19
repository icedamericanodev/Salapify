// useHaptic. One wrapper around expo-haptics so every screen buzzes the same
// way, instead of the same try/catch being copy pasted in a handful of files.
//
// Usage:
//   const haptic = useHaptic();
//   haptic('light');   // a tap landed
//   haptic('success'); // an utang got paid off
//
// Kinds: 'light' | 'medium' | 'heavy' | 'success' | 'warning' | 'error' |
//        'selection'. Anything else falls back to a light tap.
//
// Haptics are silenced when the user has reduce motion on (a motion sensitive
// user does not want buzz spam either), and every call is wrapped so web, where
// haptics do not exist, is a quiet no op rather than a crash.

import { useCallback } from 'react';
import * as Haptics from 'expo-haptics';
import { useReduceMotion } from '../context/Motion';

export function useHaptic() {
  const reduce = useReduceMotion();
  return useCallback(
    (kind = 'light') => {
      if (reduce) return;
      try {
        switch (kind) {
          case 'success':
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
            break;
          case 'warning':
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning).catch(() => {});
            break;
          case 'error':
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error).catch(() => {});
            break;
          case 'selection':
            Haptics.selectionAsync().catch(() => {});
            break;
          case 'medium':
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium).catch(() => {});
            break;
          case 'heavy':
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy).catch(() => {});
            break;
          case 'light':
          default:
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light).catch(() => {});
            break;
        }
      } catch (e) {
        // Haptics are not available (for example on web). That is fine.
      }
    },
    [reduce]
  );
}
