const fs = require('fs');

const filesToUpdate = [
  'src/components/OnboardingFlow.tsx',
  'src/components/YourSetupModal.tsx',
  'src/components/SavingsInvestmentModal.tsx',
  'src/components/AccountsScreen.tsx',
  'src/components/InvestmentsView.tsx',
  'src/utils/healthCheckEngine.ts',
  'src/utils/philippineFinances.ts',
  'src/utils/financialTruthEngine.ts',
  'src/data/initialData.ts',
  'src/data/academyData.ts',
  'src/types.ts'
];

filesToUpdate.forEach(file => {
  if (fs.existsSync(file)) {
    let code = fs.readFileSync(file, 'utf8');
    code = code.replace(/SeaBank/g, 'MariBank');
    
    // In AccountsScreen, the monogram block: "if (inst === 'SeaBank') return 'SB';"
    code = code.replace(/if \(inst === 'MariBank'\) return 'SB';/g, "if (inst === 'MariBank') return 'MB';");
    
    fs.writeFileSync(file, code, 'utf8');
  }
});
console.log('MariBank patched across codebase.');
