// The Philippine banks and e-wallets people actually use, with their brand
// colors. We render each as a colored badge (brand colors plus a short
// mark), not the trademarked logo image, so the app feels real without
// shipping other companies' protected artwork.

export const BANK_BRANDS = [
  // E-wallets first, they are the most common for our users.
  { key: 'gcash', name: 'GCash', short: 'G', bg: '#007DFE', fg: '#FFFFFF', kind: 'ewallet' },
  { key: 'maya', name: 'Maya', short: 'maya', bg: '#0C0C0C', fg: '#29E3A4', kind: 'ewallet' },
  { key: 'seabank', name: 'SeaBank', short: 'Sea', bg: '#EE4D2D', fg: '#FFFFFF', kind: 'savings' },
  { key: 'gotyme', name: 'GoTyme', short: 'Go', bg: '#001E28', fg: '#2CE6C9', kind: 'savings' },
  { key: 'cimb', name: 'CIMB', short: 'CIMB', bg: '#ED1C24', fg: '#FFFFFF', kind: 'savings' },
  { key: 'tonik', name: 'Tonik', short: 'tonik', bg: '#3D2B96', fg: '#FFE14D', kind: 'savings' },
  // The big banks.
  { key: 'bpi', name: 'BPI', short: 'BPI', bg: '#B11116', fg: '#FFFFFF', kind: 'savings' },
  { key: 'bdo', name: 'BDO', short: 'BDO', bg: '#00308F', fg: '#FFD200', kind: 'savings' },
  { key: 'metrobank', name: 'Metrobank', short: 'M', bg: '#00529C', fg: '#FFFFFF', kind: 'savings' },
  { key: 'landbank', name: 'Landbank', short: 'LBP', bg: '#00A651', fg: '#FFFFFF', kind: 'savings' },
  { key: 'unionbank', name: 'UnionBank', short: 'UB', bg: '#FF7A00', fg: '#FFFFFF', kind: 'savings' },
  { key: 'securitybank', name: 'Security Bank', short: 'SB', bg: '#00703C', fg: '#FFFFFF', kind: 'savings' },
  { key: 'pnb', name: 'PNB', short: 'PNB', bg: '#005BAA', fg: '#FFFFFF', kind: 'savings' },
  { key: 'rcbc', name: 'RCBC', short: 'RCBC', bg: '#003DA5', fg: '#FFFFFF', kind: 'savings' },
  { key: 'chinabank', name: 'China Bank', short: 'CBC', bg: '#C8102E', fg: '#FFFFFF', kind: 'savings' },
  { key: 'eastwest', name: 'EastWest', short: 'EW', bg: '#5C2D91', fg: '#FFFFFF', kind: 'savings' },
];

// Find a brand from whatever is stored in account.brand: the key, the exact
// name, or a name typed by hand in any casing. Returns null when unknown,
// and the caller falls back to the emoji icon.
export function findBrand(brand) {
  if (!brand || typeof brand !== 'string') return null;
  const needle = brand.trim().toLowerCase();
  if (!needle) return null;
  return (
    BANK_BRANDS.find((b) => b.key === needle || b.name.toLowerCase() === needle) || null
  );
}
