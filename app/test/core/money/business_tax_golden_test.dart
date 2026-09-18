import 'package:flutter_test/flutter_test.dart';
import 'package:salapify/core/money/business_tax.dart';

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
}
