const fs = require('fs');

// 1. PATCH src/utils/logos.ts
let logosCode = fs.readFileSync('src/utils/logos.ts', 'utf8');

const newDomains = `
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
`;

logosCode = logosCode.replace(
  /export const INSTITUTION_DOMAINS: Record<string, string> = \{[\s\S]*?\};/,
  'export const INSTITUTION_DOMAINS: Record<string, string> = {' + newDomains + '};'
);
fs.writeFileSync('src/utils/logos.ts', logosCode, 'utf8');


// 2. PATCH src/components/BankCard.tsx
let bankCardCode = fs.readFileSync('src/components/BankCard.tsx', 'utf8');

const newBankThemes = `
  const bankThemes: Record<string, string> = {
    'BPI': 'bg-gradient-to-br from-red-700 to-red-900 text-white border-red-800',
    'BDO': 'bg-gradient-to-br from-blue-700 to-blue-900 text-white border-blue-800',
    'UnionBank': 'bg-gradient-to-br from-orange-500 to-orange-700 text-white border-orange-600',
    'GCash': 'bg-gradient-to-br from-blue-500 to-blue-700 text-white border-blue-600',
    'Maya': 'bg-gradient-to-br from-emerald-600 to-emerald-900 text-white border-emerald-700',
    'Metrobank': 'bg-gradient-to-br from-blue-800 to-blue-950 text-white border-blue-900',
    'MariBank': 'bg-gradient-to-br from-orange-500 to-red-500 text-white border-orange-600',
    'GoTyme': 'bg-gradient-to-br from-cyan-600 to-blue-700 text-white border-cyan-700',
    'RCBC': 'bg-gradient-to-br from-blue-700 to-blue-900 text-white border-blue-800',
    'Security Bank': 'bg-gradient-to-br from-blue-600 to-blue-800 text-white border-blue-700',
    'EastWest': 'bg-gradient-to-br from-purple-700 to-purple-900 text-white border-purple-800',
    'PNB': 'bg-gradient-to-br from-red-800 to-red-950 text-white border-red-900',
    'Atome': 'bg-gradient-to-br from-yellow-400 to-yellow-500 text-slate-900 border-yellow-400',
    'AUB': 'bg-gradient-to-br from-blue-400 to-blue-600 text-white border-blue-500',
    'TikTok': 'bg-gradient-to-br from-black to-zinc-900 text-white border-zinc-800',
    'LandBank': 'bg-gradient-to-br from-green-600 to-green-800 text-white border-green-700',
    'PSBank': 'bg-gradient-to-br from-blue-600 to-blue-800 text-white border-blue-700',
    'China Bank': 'bg-gradient-to-br from-red-600 to-red-800 text-white border-red-700',
    'UNO Digital Bank': 'bg-gradient-to-br from-fuchsia-600 to-pink-600 text-white border-fuchsia-700',
    'OwnBank': 'bg-gradient-to-br from-indigo-800 to-purple-900 text-white border-indigo-700',
  };
`;

bankCardCode = bankCardCode.replace(
  /const bankThemes: Record<string, string> = \{[\s\S]*?\};/,
  newBankThemes.trim()
);
fs.writeFileSync('src/components/BankCard.tsx', bankCardCode, 'utf8');


// 3. PATCH src/components/AccountsScreen.tsx
let accCode = fs.readFileSync('src/components/AccountsScreen.tsx', 'utf8');

const newOptions = `
                  <option value="BPI">BPI</option>
                  <option value="BDO">BDO</option>
                  <option value="Metrobank">Metrobank</option>
                  <option value="RCBC">RCBC</option>
                  <option value="UnionBank">UnionBank</option>
                  <option value="Security Bank">Security Bank</option>
                  <option value="PNB">PNB</option>
                  <option value="EastWest">EastWest</option>
                  <option value="AUB">AUB</option>
                  <option value="LandBank">LandBank</option>
                  <option value="PSBank">PSBank</option>
                  <option value="China Bank">China Bank</option>
                  <option value="GCash">GCash</option>
                  <option value="Maya">Maya</option>
                  <option value="MariBank">MariBank</option>
                  <option value="GoTyme">GoTyme</option>
                  <option value="Tonik">Tonik</option>
                  <option value="CIMB">CIMB</option>
                  <option value="Komo">Komo</option>
                  <option value="DiskarTech">DiskarTech</option>
                  <option value="Netbank">Netbank</option>
                  <option value="UNO Digital Bank">UNO Digital Bank</option>
                  <option value="OwnBank">OwnBank</option>
                  <option value="TikTok">TikTok (PayLater)</option>
                  <option value="Atome">Atome</option>
                  <option value="Pag-IBIG">Pag-IBIG Fund (MP2)</option>
                  <option value="SSS">SSS (WISP Plus)</option>
                  <option value="Cash">Cash (Physical)</option>
                  <option value="Other">Other Financial Institution</option>
`;

accCode = accCode.replace(
  /<option value="BPI">BPI<\/option>[\s\S]*?<option value="Other">Other Financial Institution<\/option>/,
  newOptions.trim()
);

// We should also replace SeaBank strings with MariBank if they are present in Context
fs.writeFileSync('src/components/AccountsScreen.tsx', accCode, 'utf8');


// 4. PATCH src/context/FinancialContext.tsx for SeaBank->MariBank Transfer rule
let finCode = fs.readFileSync('src/context/FinancialContext.tsx', 'utf8');
finCode = finCode.replace(/SeaBank/g, 'MariBank');
fs.writeFileSync('src/context/FinancialContext.tsx', finCode, 'utf8');

console.log('Providers patched successfully.');
