const fs = require('fs');
let accCode = fs.readFileSync('src/components/AccountsScreen.tsx', 'utf8');

const newMonograms = `
    if (inst === 'BPI') return 'BPI';
    if (inst === 'BDO') return 'BDO';
    if (inst === 'Metrobank') return 'MBTC';
    if (inst === 'RCBC') return 'RC';
    if (inst === 'UnionBank') return 'UB';
    if (inst === 'Security Bank') return 'SB';
    if (inst === 'PNB') return 'PNB';
    if (inst === 'EastWest') return 'EW';
    if (inst === 'AUB') return 'AUB';
    if (inst === 'LandBank') return 'LB';
    if (inst === 'PSBank') return 'PS';
    if (inst === 'China Bank') return 'CB';
    if (inst === 'MariBank') return 'MB';
    if (inst === 'GoTyme') return 'GT';
    if (inst === 'Tonik') return 'TK';
    if (inst === 'CIMB') return 'CIMB';
    if (inst === 'Komo') return 'KM';
    if (inst === 'DiskarTech') return 'DT';
    if (inst === 'Netbank') return 'NB';
    if (inst === 'UNO Digital Bank') return 'UNO';
    if (inst === 'OwnBank') return 'OB';
    if (inst === 'TikTok') return 'TK';
    if (inst === 'Atome') return 'AT';
    if (inst === 'Pag-IBIG') return 'HDMF';
    if (inst === 'SSS') return 'SSS';
    if (inst === 'Cash') return '₱';
`;

accCode = accCode.replace(
  /if \(inst === 'BPI'\) return 'BPI';[\s\S]*?if \(inst === 'Cash'\) return '₱';/,
  newMonograms.trim()
);
fs.writeFileSync('src/components/AccountsScreen.tsx', accCode, 'utf8');
console.log('Monogram patched');
