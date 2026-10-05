#!/bin/bash
sed -i 's/<CalculatorLibrary onOpenCalculator={(id) => console.log(id)} \/>/<CalculatorLibrary onOpenCalculator={(id) => {\
            if (id === '\''tax_comprehensive'\'') {\
              onOpenTaxCalculator && onOpenTaxCalculator();\
            } else if (id === '\''debt_loan'\'') {\
              onOpenDebt && onOpenDebt();\
            } else {\
              alert('\''Calculator coming soon!'\'');\
            }\
          }} \/>/g' src/components/PlanScreen.tsx
