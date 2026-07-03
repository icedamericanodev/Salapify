// BankBadge: a small rounded square that looks like a bank or e-wallet app
// icon, drawn from brand colors and a short mark (see lib/banks.js). When
// the brand is not recognized, it falls back to the account's emoji icon
// so every account still has a face.

import { StyleSheet, Text, View } from 'react-native';
import { findBrand } from '../lib/banks';

export default function BankBadge({ brand, fallback = '💵', size = 34 }) {
  const b = findBrand(brand);
  if (!b) {
    return (
      <Text style={{ fontSize: size * 0.65, width: size, textAlign: 'center' }}>{fallback}</Text>
    );
  }
  // Long marks like "CIMB" shrink so they always fit the square.
  const fontSize = b.short.length <= 1 ? size * 0.5 : b.short.length <= 2 ? size * 0.4 : size * 0.26;
  return (
    <View
      style={[
        styles.badge,
        { width: size, height: size, borderRadius: size * 0.26, backgroundColor: b.bg },
      ]}
    >
      <Text style={{ color: b.fg, fontSize, fontWeight: '800' }} numberOfLines={1}>
        {b.short}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  badge: { alignItems: 'center', justifyContent: 'center', overflow: 'hidden' },
});
