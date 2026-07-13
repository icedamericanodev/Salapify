// 13th month pay math (PD 851), ported 1:1 from mobile/lib/thirteenth.js and
// held to the same golden vectors as the rest of the money engine. The
// 90,000 TRAIN ceiling shelters other benefits first, then the 13th month;
// only the excess is taxed, marginally, on top of the year's regular
// taxable pay scaled by months actually worked.

import 'phtax.dart';

/// Re-export of the shared ceiling under the name the 13th month screens use,
/// mirroring the RN single-source-of-truth arrangement.
const double thirteenthTaxFreeCeiling = bonusTaxFreeCeiling;

double _num(num? x) => (x == null || !x.isFinite) ? 0 : x.toDouble();

double _jsRound(double v) {
  final f = v.floorToDouble();
  return (v - f >= 0.5) ? f + 1 : f;
}

double _round2(num x) => _jsRound(_num(x) * 100) / 100;

/// The 13th month pay and its tax treatment. monthsWorked null means a full
/// year; a real value clamps to 1..12 so it never silently becomes 12.
Map<String, dynamic> thirteenthMonth(num monthlyBasic,
    {num? monthsWorked, num otherBenefits = 0}) {
  final basic = _num(monthlyBasic) < 0 ? 0.0 : _num(monthlyBasic);
  final months = monthsWorked == null
      ? 12
      : _jsRound(_num(monthsWorked)).clamp(1, 12).toInt();
  final other = _num(otherBenefits) < 0 ? 0.0 : _num(otherBenefits);

  final amount = _round2((basic * months) / 12);

  var remainingExemption = thirteenthTaxFreeCeiling - other;
  if (remainingExemption < 0) remainingExemption = 0;
  final taxFreePortion = _round2(amount < remainingExemption ? amount : remainingExemption);
  var taxable = _round2(amount - remainingExemption);
  if (taxable < 0) taxable = 0;

  final regularAnnualTaxable =
      _round2((takeHomePay(basic)['monthlyTaxable'] as double) * months);
  final taxOnExcess = taxable > 0
      ? _round2(annualIncomeTax(regularAnnualTaxable + taxable) -
          annualIncomeTax(regularAnnualTaxable))
      : 0.0;

  final net = _round2(amount - taxOnExcess);

  return {
    'amount': amount,
    'monthsWorked': months,
    'otherBenefits': other,
    'ceiling': thirteenthTaxFreeCeiling,
    'taxFreePortion': taxFreePortion,
    'taxable': taxable,
    'taxOnExcess': taxOnExcess,
    'net': net,
    'ratesYear': ratesYear,
  };
}
