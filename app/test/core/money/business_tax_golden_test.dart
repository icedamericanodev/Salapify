import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/business_tax.dart';
import 'package:salapify/core/money/ph_tax.dart' show annualGraduatedTax;

/// Golden vectors for the business tax port, produced by running
/// src/utils/businessTaxes.ts under bun over the full 2 x 2 x 4 matrix of
/// entity, VAT status and regime. Revenue 3,000,000, COGS 1,200,000,
/// OPEX 600,000 throughout, so gross profit is 1,800,000 everywhere and only
/// the regime moves the numbers.
void main() {
  const BusinessFinancials fin = BusinessFinancials(
    revenue: 3000000,
    cogs: 1200000,
    opex: 600000,
  );

  BusinessTaxResult run(EntityType e, VatStatus v, TaxRegime r) =>
      calculateBusinessTax(entity: e, financials: fin, vatStatus: v, regime: r);

  void vector(
    String label,
    EntityType e,
    VatStatus v,
    TaxRegime r, {
    required double nti,
    required double incomeTax,
    required double businessTax,
    required double netIncome,
    required List<String> forms,
  }) {
    test(label, () {
      final BusinessTaxResult res = run(e, v, r);
      expect(res.grossProfit, 1800000);
      expect(res.netTaxableIncome, closeTo(nti, 1e-6));
      expect(res.incomeTax, closeTo(incomeTax, 1e-6));
      expect(res.businessTax, closeTo(businessTax, 1e-6));
      expect(res.totalTax, closeTo(incomeTax + businessTax, 1e-6));
      expect(res.netIncome, closeTo(netIncome, 1e-6));
      expect(
        res.complianceForms.map((ComplianceForm f) => f.form).toList(),
        forms,
      );
    });
  }

  group('sole proprietorship, non VAT', () {
    vector(
      '8 percent replaces both income and percentage tax',
      EntityType.soleProp,
      VatStatus.nonVat,
      TaxRegime.eightPercent,
      nti: 2750000,
      incomeTax: 220000,
      businessTax: 0,
      netIncome: 980000,
      forms: <String>['BIR Form 1701Q', 'BIR Form 1701/1701A'],
    );
    vector(
      'OSD deducts 40 percent of GROSS SALES',
      EntityType.soleProp,
      VatStatus.nonVat,
      TaxRegime.graduatedOsd,
      nti: 1800000,
      incomeTax: 352500,
      businessTax: 90000,
      netIncome: 757500,
      forms: <String>[
        'BIR Form 1701Q',
        'BIR Form 1701/1701A',
        'BIR Form 2551Q',
      ],
    );
    vector(
      'itemized deducts opex AND the percentage tax itself',
      EntityType.soleProp,
      VatStatus.nonVat,
      TaxRegime.graduatedItemized,
      nti: 1110000,
      incomeTax: 180000,
      businessTax: 90000,
      netIncome: 930000,
      forms: <String>[
        'BIR Form 1701Q',
        'BIR Form 1701/1701A',
        'BIR Form 2551Q',
      ],
    );
  });

  group('sole proprietorship, VAT registered', () {
    vector(
      'VAT is pass through, so percentage tax disappears',
      EntityType.soleProp,
      VatStatus.vat,
      TaxRegime.graduatedItemized,
      nti: 1200000,
      incomeTax: 202500,
      businessTax: 0,
      netIncome: 997500,
      forms: <String>[
        'BIR Form 1701Q',
        'BIR Form 1701/1701A',
        'BIR Form 2550Q',
      ],
    );
    vector(
      'OSD under VAT',
      EntityType.soleProp,
      VatStatus.vat,
      TaxRegime.graduatedOsd,
      nti: 1800000,
      incomeTax: 352500,
      businessTax: 0,
      netIncome: 847500,
      forms: <String>[
        'BIR Form 1701Q',
        'BIR Form 1701/1701A',
        'BIR Form 2550Q',
      ],
    );
  });

  group('partnership, taxed at the flat 20 percent CREATE rate', () {
    vector(
      'OSD for a partnership is 40 percent of GROSS PROFIT, not gross sales',
      EntityType.partnership,
      VatStatus.nonVat,
      TaxRegime.graduatedOsd,
      nti: 1080000,
      incomeTax: 216000,
      businessTax: 90000,
      netIncome: 894000,
      forms: <String>[
        'BIR Form 1702Q',
        'BIR Form 1702-RT/EX',
        'BIR Form 2551Q',
      ],
    );
    vector(
      'itemized',
      EntityType.partnership,
      VatStatus.nonVat,
      TaxRegime.graduatedItemized,
      nti: 1110000,
      incomeTax: 222000,
      businessTax: 90000,
      netIncome: 888000,
      forms: <String>[
        'BIR Form 1702Q',
        'BIR Form 1702-RT/EX',
        'BIR Form 2551Q',
      ],
    );
    vector(
      'the 8 percent regime does NOT apply to a partnership, only its form list changes',
      EntityType.partnership,
      VatStatus.nonVat,
      TaxRegime.eightPercent,
      nti: 1200000,
      incomeTax: 240000,
      businessTax: 0,
      netIncome: 960000,
      forms: <String>['BIR Form 1702Q', 'BIR Form 1702-RT/EX'],
    );
  });

  group('the rules behind the numbers', () {
    test('a VAT registered business never carries percentage tax', () {
      for (final TaxRegime r in TaxRegime.values) {
        for (final EntityType e in EntityType.values) {
          expect(
            run(e, VatStatus.vat, r).businessTax,
            0,
            reason: 'VAT is pass through in this engine',
          );
        }
      }
    });

    test('the 8 percent regime never carries percentage tax either', () {
      for (final EntityType e in EntityType.values) {
        expect(run(e, VatStatus.nonVat, TaxRegime.eightPercent).businessTax, 0);
      }
    });

    test(
      'every other non-VAT combination charges 3 percent of gross sales',
      () {
        for (final TaxRegime r in <TaxRegime>[
          TaxRegime.graduatedOsd,
          TaxRegime.graduatedItemized,
          TaxRegime.corporateRcit,
        ]) {
          for (final EntityType e in EntityType.values) {
            expect(run(e, VatStatus.nonVat, r).businessTax, 90000);
          }
        }
      },
    );

    test('a 2551Q is filed exactly when percentage tax is owed', () {
      for (final TaxRegime r in TaxRegime.values) {
        for (final EntityType e in EntityType.values) {
          for (final VatStatus v in VatStatus.values) {
            final BusinessTaxResult res = run(e, v, r);
            final bool filesPercentageTax = res.complianceForms.any(
              (ComplianceForm f) => f.form == 'BIR Form 2551Q',
            );
            expect(
              filesPercentageTax,
              res.businessTax > 0,
              reason: 'the form list and the tax owed must agree',
            );
          }
        }
      }
    });

    test('net income is revenue less costs less every tax', () {
      for (final TaxRegime r in TaxRegime.values) {
        for (final EntityType e in EntityType.values) {
          for (final VatStatus v in VatStatus.values) {
            final BusinessTaxResult res = run(e, v, r);
            expect(
              res.netIncome,
              closeTo(3000000 - 1200000 - 600000 - res.totalTax, 1e-6),
            );
          }
        }
      }
    });

    test('zero revenue divides by nothing and owes nothing', () {
      final BusinessTaxResult res = calculateBusinessTax(
        entity: EntityType.soleProp,
        financials: const BusinessFinancials(revenue: 0, cogs: 0, opex: 0),
        vatStatus: VatStatus.nonVat,
        regime: TaxRegime.eightPercent,
      );
      expect(res.totalTax, 0);
      expect(res.effectiveTaxRate, 0);
    });
  });

  group('the 8 percent election is gated, not just offered', () {
    BusinessTaxResult run(double revenue, VatStatus vat) =>
        calculateBusinessTax(
          entity: EntityType.soleProp,
          financials: BusinessFinancials(revenue: revenue, cogs: 0, opex: 0),
          vatStatus: vat,
          regime: TaxRegime.eightPercent,
        );

    test('a VAT registered sole prop cannot be on the 8 percent regime', () {
      // The sharpest defect in this file. The old code took the request at
      // face value, so percentage tax came out zero BECAUSE the 8% replaces
      // it, and income tax came out at 8%, which this taxpayer may not
      // elect at all. Wrong twice, in the same result.
      final BusinessTaxResult r = run(1000000, VatStatus.vat);
      expect(
        r.incomeTax,
        isNot(48000),
        reason: 'it still applied 8% of (1,000,000 - 250,000)',
      );
      // Falls back to graduated on the 40% OSD: 600,000 taxable.
      expect(r.netTaxableIncome, 600000);
      expect(r.incomeTax, annualGraduatedTax(600000));
    });

    test('above the VAT threshold the 8 percent is not applied', () {
      final BusinessTaxResult r = run(4000000, VatStatus.nonVat);
      expect(
        r.incomeTax,
        isNot(300000),
        reason: 'it still applied 8% of (4,000,000 - 250,000)',
      );
      expect(r.netTaxableIncome, 2400000);
      expect(r.incomeTax, annualGraduatedTax(2400000));
    });

    test('the percentage tax comes BACK when the 8 percent is refused', () {
      // The half that is easy to miss. Falling back to graduated without
      // restoring the 3% would leave the taxpayer owing a tax the result
      // does not show, because the regime that replaced it is gone.
      final BusinessTaxResult r = run(4000000, VatStatus.nonVat);
      expect(r.businessTax, 120000, reason: '3% of 4,000,000');
    });

    test('at EXACTLY the threshold the election still stands', () {
      // Strict greater-than. At 3,000,000 the taxpayer is eligible, and this
      // vector is the one that catches a >= typo.
      final BusinessTaxResult r = run(3000000, VatStatus.nonVat);
      expect(r.netTaxableIncome, 2750000);
      expect(r.incomeTax, 220000);
      expect(r.businessTax, 0);
    });

    test('a refused election files a 2551Q, because it owes one', () {
      final BusinessTaxResult r = run(4000000, VatStatus.nonVat);
      expect(
        r.complianceForms.map((ComplianceForm f) => f.form),
        contains('BIR Form 2551Q'),
        reason:
            'the form list still read the REQUESTED regime, so it told '
            'somebody they had no percentage tax return to file while the '
            'same result charged them percentage tax',
      );
    });
  });
}
