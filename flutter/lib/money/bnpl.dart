// The true cost of an installment or "0% interest" plan (GGives, BillEase,
// Home Credit, Shopee and Lazada installment, card installment), ported 1:1
// from mobile/lib/bnpl.js. Backs out the real effective rate hidden inside
// a monthly quote and any upfront fee, so a "0%" plan with a processing fee
// is unmasked. Reuses the golden-locked loan engine. An estimate from the
// numbers entered, not a loan offer. Golden-verified against the real RN
// module.

import 'ledger.dart' show amountOf;
import 'loan.dart' show effectiveAnnualRate, effectiveMonthlyRate;

double _jsRound(num x) => (x + 0.5).floorToDouble();

/// fields: cashPrice, downpayment, months, monthlyPayment, upfrontFee.
/// Returns the totals, how much more than paying cash it costs, and the
/// real effective monthly and annual rate on the credit actually received.
Map<String, dynamic> bnplCost([Map<String, dynamic>? fields]) {
  final f = fields ?? const {};
  final cash = amountOf(f['cashPrice']) > 0 ? amountOf(f['cashPrice']) : 0.0;
  final downRaw =
      amountOf(f['downpayment']) > 0 ? amountOf(f['downpayment']) : 0.0;
  final down = downRaw < cash ? downRaw : cash;
  final fee = amountOf(f['upfrontFee']) > 0 ? amountOf(f['upfrontFee']) : 0.0;
  final monthsRounded = _jsRound(amountOf(f['months']));
  final monthsFloor = monthsRounded > 1 ? monthsRounded : 1.0;
  final months = (monthsFloor < 60 ? monthsFloor : 60.0).toInt();
  final monthly =
      amountOf(f['monthlyPayment']) > 0 ? amountOf(f['monthlyPayment']) : 0.0;

  // What you finance is the price left after any downpayment. What you pay
  // is the downpayment now, the fee now, and the installments over time.
  final financedRaw = cash - down;
  final financed = financedRaw > 0 ? financedRaw : 0.0;
  final totalPaid = down + fee + monthly * months;
  final extraRaw = totalPaid - cash;
  final extraCost = extraRaw > 0 ? extraRaw : 0.0;

  // The numbers do not add up when the payments do not even cover the item;
  // a true cost tool must never reassure someone on impossible numbers.
  final underpays = totalPaid < cash - 0.005;

  // The honest effective rate is measured on the credit actually received:
  // financed minus any fee taken upfront, so a fee shows as real cost even
  // when the quoted rate is "0%".
  final netRaw = financed - fee;
  final netCredit = netRaw > 0 ? netRaw : 0.0;
  final monthlyRate = effectiveMonthlyRate(netCredit, monthly, months);
  final annualRate = effectiveAnnualRate(monthlyRate);
  final rateReliable = netCredit > 0.005 && monthlyRate > 0;

  // Genuinely free only when it fully covers the price, costs nothing over
  // cash, and carries no fee.
  final trulyFree = !underpays && extraCost <= 0.005 && fee <= 0.005;

  return {
    'cash': cash,
    'down': down,
    'fee': fee,
    'months': months,
    'monthly': monthly,
    'financed': financed,
    'netCredit': netCredit,
    'totalPaid': totalPaid,
    'extraCost': extraCost,
    'monthlyRate': monthlyRate,
    'annualRate': annualRate,
    'rateReliable': rateReliable,
    'underpays': underpays,
    'trulyFree': trulyFree,
  };
}
