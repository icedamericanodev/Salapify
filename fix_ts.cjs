const fs = require('fs');

// 1. Fix Context
let contextCode = fs.readFileSync('src/context/FinancialContext.tsx', 'utf8');
contextCode = contextCode.replace(
  "Omit<Goal, 'id'> & { currentAmount?: number }",
  "Omit<Goal, 'id' | 'currentAmount'> & { currentAmount?: number }"
);
contextCode = contextCode.replace(
  "Omit<Goal, 'id'> & { currentAmount?: number }",
  "Omit<Goal, 'id' | 'currentAmount'> & { currentAmount?: number }"
);
fs.writeFileSync('src/context/FinancialContext.tsx', contextCode, 'utf8');

// 2. Fix Savings Modal
let modalCode = fs.readFileSync('src/components/SavingsInvestmentModal.tsx', 'utf8');
// Remove the useEffect from the top
modalCode = modalCode.replace(
  "  const [isSaved, setIsSaved] = useState(false);\n\n  // Reset saved state on changes\n  React.useEffect(() => { setIsSaved(false); }, [plannerType, monthlyExpenseStr, monthsTarget, goalAmountStr, currentSavedStr, monthlyContributionStr, isOpen]);",
  "  const [isSaved, setIsSaved] = useState(false);"
);
// Insert it after state declarations
modalCode = modalCode.replace(
  "const monthlyContribution = parseFloat(monthlyContributionStr.replace(/,/g, '')) || 0;",
  "const monthlyContribution = parseFloat(monthlyContributionStr.replace(/,/g, '')) || 0;\n\n  React.useEffect(() => { setIsSaved(false); }, [plannerType, monthlyExpenseStr, monthsTarget, goalAmountStr, currentSavedStr, monthlyContributionStr, isOpen]);"
);
fs.writeFileSync('src/components/SavingsInvestmentModal.tsx', modalCode, 'utf8');

console.log("Fixed TS errors!");
