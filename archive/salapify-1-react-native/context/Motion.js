// Motion context. Reads the phone's "reduce motion" accessibility setting once,
// here, and shares it with the whole app. Every animation we add is a
// progressive enhancement: when the user has asked their phone to reduce
// motion, we still show the exact same final state, number, and layout, just
// without the tween. This is where that decision is made, in one place, so no
// screen has to remember to check.

import { createContext, useContext, useEffect, useState } from 'react';
import { AccessibilityInfo } from 'react-native';

const MotionContext = createContext(false);

export function MotionProvider({ children }) {
  const [reduceMotion, setReduceMotion] = useState(false);

  useEffect(() => {
    let mounted = true;
    // Read the current setting on mount. Wrapped defensively: on web or an old
    // platform this can reject, and a missing answer should just mean "motion
    // is fine", never a crash.
    AccessibilityInfo.isReduceMotionEnabled?.()
      .then((v) => {
        if (mounted) setReduceMotion(!!v);
      })
      .catch(() => {});
    // Keep in sync if the user flips the setting while the app is open.
    const sub = AccessibilityInfo.addEventListener?.(
      'reduceMotionChanged',
      (v) => {
        if (mounted) setReduceMotion(!!v);
      }
    );
    return () => {
      mounted = false;
      // RN returns a subscription with .remove(); guard for older shapes.
      if (sub && typeof sub.remove === 'function') sub.remove();
    };
  }, []);

  return (
    <MotionContext.Provider value={reduceMotion}>
      {children}
    </MotionContext.Provider>
  );
}

// True when the user has asked their phone to reduce motion. Animations should
// early return to their final state when this is true.
export function useReduceMotion() {
  return useContext(MotionContext);
}
