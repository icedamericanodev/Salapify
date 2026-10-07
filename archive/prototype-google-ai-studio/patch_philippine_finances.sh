#!/bin/bash
sed -i 's/export interface EmployeeTaxCalculation {/export interface EmployeeTaxCalculation {\n  inputFrequency: "semi-monthly" | "bi-weekly" | "monthly" | "annually";\n  inputSalary: number;\n  taxableAllowance: number;\n  nonTaxableAllowance: number;\n  overtime: number;\n  nightDifferential: number;\n  grossMonthlyIncome: number;\n/' src/utils/philippineFinances.ts
