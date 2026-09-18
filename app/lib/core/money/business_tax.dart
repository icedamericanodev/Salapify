import 'dart:math' as math;

import 'ph_tax.dart' show annualGraduatedTax;

/// Business tax for a sole proprietorship or a partnership, ported from
/// src/utils/businessTaxes.ts.
///
/// The prototype's simplifications are kept, not improved on. The two that
/// matter most, both stated in its own comments:
///
///   VAT is treated as PASS THROUGH and contributes nothing, because output
///   VAT is billed to the customer and input VAT is credited back. So a VAT
///   registered business shows businessTax 0 here. That is a cash-flow view,
///   not a filing figure.
///
///   A partnership is taxed at the flat CREATE-law MSME rate of 20%, on the
///   assumption that taxable income is under 5M and assets under 100M. The
///   engine does not check either.

enum EntityType { soleProp, partnership }

enum TaxRegime { eightPercent, graduatedOsd, graduatedItemized, corporateRcit }

enum VatStatus { nonVat, vat }

class BusinessFinancials {
  const BusinessFinancials({
    required this.revenue,
    required this.cogs,
    required this.opex,
  });

  final double revenue;
  final double cogs;
  final double opex;
}

class ComplianceForm {
  const ComplianceForm({
    required this.form,
    required this.name,
    required this.deadline,
    required this.frequency,
    required this.description,
  });

  final String form;
  final String name;
  final String deadline;
  final String frequency;
  final String description;
}

class BusinessTaxResult {
  const BusinessTaxResult({
    required this.grossProfit,
    required this.netTaxableIncome,
    required this.incomeTax,
    required this.businessTax,
    required this.totalTax,
    required this.netIncome,
    required this.effectiveTaxRate,
    required this.complianceForms,
  });

  final double grossProfit;
  final double netTaxableIncome;
  final double incomeTax;

  /// Percentage tax, or zero under VAT and under the 8% regime.
  final double businessTax;
  final double totalTax;
  final double netIncome;

  /// A percentage, 0 to 100.
  final double effectiveTaxRate;
  final List<ComplianceForm> complianceForms;
}

BusinessTaxResult calculateBusinessTax({
  required EntityType entity,
  required BusinessFinancials financials,
  required VatStatus vatStatus,
  required TaxRegime regime,
}) {
  final double revenue = financials.revenue;
  final double cogs = financials.cogs;
  final double opex = financials.opex;

  final double grossProfit = math.max(0, revenue - cogs);

  // 1. Percentage tax, 3% of gross sales, for a non-VAT business that is not
  //    on the 8% regime. The 8% rate already replaces it.
  double businessTax = 0;
  if (vatStatus == VatStatus.nonVat && regime != TaxRegime.eightPercent) {
    businessTax = revenue * 0.03;
  }

  double netTaxableIncome = 0;
  double incomeTax = 0;

  if (entity == EntityType.soleProp) {
    if (regime == TaxRegime.eightPercent) {
      // 8% on gross sales above 250,000, replacing income AND percentage tax.
      netTaxableIncome = math.max(0, revenue - 250000);
      incomeTax = netTaxableIncome * 0.08;
    } else {
      if (regime == TaxRegime.graduatedOsd) {
        // Optional standard deduction, 40% of GROSS SALES for an individual.
        netTaxableIncome = revenue - (revenue * 0.40);
      } else {
        // Itemized. Percentage tax is itself a deductible expense.
        netTaxableIncome = math.max(0, grossProfit - opex - businessTax);
      }
      incomeTax = annualGraduatedTax(netTaxableIncome);
    }
  } else {
    if (regime == TaxRegime.graduatedOsd) {
      // OSD for a partnership is 40% of GROSS INCOME, which is gross profit,
      // not of gross sales. The base differs from the sole prop case above and
      // that is deliberate in the prototype.
      netTaxableIncome = grossProfit - (grossProfit * 0.40);
    } else {
      netTaxableIncome = math.max(0, grossProfit - opex - businessTax);
    }
    incomeTax = netTaxableIncome * 0.20;
  }

  final double totalTax = incomeTax + businessTax;

  return BusinessTaxResult(
    grossProfit: grossProfit,
    netTaxableIncome: netTaxableIncome,
    incomeTax: incomeTax,
    businessTax: businessTax,
    totalTax: totalTax,
    netIncome: revenue - cogs - opex - totalTax,
    effectiveTaxRate: revenue > 0 ? (totalTax / revenue) * 100 : 0,
    complianceForms: _forms(entity, vatStatus, regime),
  );
}

List<ComplianceForm> _forms(
  EntityType entity,
  VatStatus vatStatus,
  TaxRegime regime,
) {
  final List<ComplianceForm> forms = <ComplianceForm>[];

  if (entity == EntityType.soleProp) {
    forms.add(
      const ComplianceForm(
        form: 'BIR Form 1701Q',
        name: 'Quarterly Income Tax Return',
        deadline: 'May 15, Aug 15, Nov 15',
        frequency: 'Quarterly',
        description: 'Declaration of quarterly income and tax dues.',
      ),
    );
    forms.add(
      const ComplianceForm(
        form: 'BIR Form 1701/1701A',
        name: 'Annual Income Tax Return',
        deadline: 'April 15 of next year',
        frequency: 'Annually',
        description: 'Final annual consolidation of income.',
      ),
    );
  } else {
    forms.add(
      const ComplianceForm(
        form: 'BIR Form 1702Q',
        name: 'Quarterly Corporate Income Tax',
        deadline: '60 days after the end of quarter',
        frequency: 'Quarterly',
        description: 'Declaration of partnership/corporate quarterly income.',
      ),
    );
    forms.add(
      const ComplianceForm(
        form: 'BIR Form 1702-RT/EX',
        name: 'Annual Corporate Income Tax',
        deadline: '105 days after the fiscal year end',
        frequency: 'Annually',
        description: 'Final annual consolidation for the partnership.',
      ),
    );
  }

  if (vatStatus == VatStatus.vat) {
    forms.add(
      const ComplianceForm(
        form: 'BIR Form 2550Q',
        name: 'Quarterly Value-Added Tax Return',
        deadline: '25th day of the month following the quarter',
        frequency: 'Quarterly',
        description: 'Summary of Output VAT vs Input VAT.',
      ),
    );
  } else if (regime != TaxRegime.eightPercent) {
    forms.add(
      const ComplianceForm(
        form: 'BIR Form 2551Q',
        name: 'Quarterly Percentage Tax',
        deadline: '25th day of the month following the quarter',
        frequency: 'Quarterly',
        description: '3% tax on gross sales/receipts.',
      ),
    );
  }

  // The annual registration fee (BIR Form 0605) was repealed by the EOPT law,
  // RA 11976, so it is deliberately absent.
  return forms;
}
