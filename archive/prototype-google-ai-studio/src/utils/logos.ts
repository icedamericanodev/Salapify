export const INSTITUTION_DOMAINS: Record<string, string> = {
  'GCash': 'gcash.com',
  'Maya': 'maya.ph',
  'BPI': 'bpi.com.ph',
  'BDO': 'bdo.com.ph',
  'UnionBank': 'unionbankph.com',
  'MariBank': 'maribank.ph', // changed from SeaBank
  'GoTyme': 'gotyme.com.ph',
  'Tonik': 'tonikbank.com',
  'CIMB': 'cimbbank.com.ph',
  'Metrobank': 'metrobank.com.ph',
  'Security Bank': 'securitybank.com',
  'RCBC': 'rcbc.com',
  'PNB': 'pnb.com.ph',
  'Atome': 'atome.ph',
  'EastWest': 'eastwestbanker.com',
  'AUB': 'aub.com.ph',
  'TikTok': 'tiktok.com',
  'LandBank': 'landbank.com',
  'PSBank': 'psbank.com.ph',
  'China Bank': 'chinabank.ph',
  'Komo': 'komo.ph',
  'DiskarTech': 'diskartech.ph',
  'Netbank': 'netbank.ph',
  'UNO Digital Bank': 'unobank.asia',
  'OwnBank': 'ownbank.com',
  'Pag-IBIG': 'pagibigfund.gov.ph',
  'SSS': 'sss.gov.ph',
};

export const getLogoUrl = (institution: string): string => {
  const domain = INSTITUTION_DOMAINS[institution];
  if (domain) {
    return `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;
  }
  // Fallback for unknown
  const cleanName = institution.toLowerCase().replace(/\s+/g, '');
  return `https://www.google.com/s2/favicons?domain=${cleanName}.com&sz=128`;
}
