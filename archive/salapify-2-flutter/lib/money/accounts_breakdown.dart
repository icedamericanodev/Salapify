// The assets-vs-liabilities breakdown behind the donut screen (mockup screen 8).
//
// The ONE rule this file exists to keep: the slices must sum to exactly what
// netWorthParts calls assets and liabilities, so the donut and its legend can
// never show a total that disagrees with the hero. netWorthParts defines:
//
//   assets      = accounts + holdings + receivables + fxAssets.converted
//   liabilities = debts + payables + fxDebts.converted
//
// So the breakdown groups accounts and assets (holdings) by taxonomy category
// using the SAME counted-amount rule netWorthParts uses per row (base as-is,
// foreign converted, unpriceable foreign as zero), which reproduces
// accounts + holdings + fxAssets.converted; then it adds receivables as its own
// asset slice and payables as its own liability slice. The debt categories do
// the same on the liability side. accounts_breakdown_test asserts the sums
// reconcile with netWorthParts to the centavo, so a future change cannot let
// the two drift.
//
// No new money methodology: every peso here is a value netWorthParts already
// counts, only regrouped by category for display.

import 'account_taxonomy.dart';
import 'base_currency_scope.dart' show baseCurrencyOf;
import 'fx_totals.dart' show FxTable, resolveRate;
import 'ledger.dart' show amountOf;
import 'statements.dart' show trackedRemaining;

/// One slice of the assets-or-liabilities breakdown: a taxonomy category (or
/// the receivables / payables pseudo-category), its counted total, and how many
/// entries rolled into it.
class BreakdownSlice {
  final String id;
  final String label;
  final AccountClass cls;
  final double total;
  final int count;
  const BreakdownSlice({
    required this.id,
    required this.label,
    required this.cls,
    required this.total,
    required this.count,
  });
}

List<Map<String, dynamic>> _rows(dynamic v) => [
  for (final r in (v is List ? v : const []))
    if (r is Map) r.cast<String, dynamic>(),
];

/// A row's contribution to a base-currency total: base rows as themselves,
/// foreign rows converted, unpriceable foreign as zero. Identical to the
/// accounts screen's _countedAmount and to netWorthParts' per-row handling.
double _counted(Map<String, dynamic> r, double amount, String base, FxTable? fx) {
  final c = r['currencyCode'];
  if (c is! String || c.isEmpty || c.toUpperCase() == base) return amount;
  if (fx == null) return 0;
  final rate = resolveRate(fx, c.toUpperCase());
  return rate.basePerUnit == null ? 0 : amount * rate.basePerUnit!;
}

/// The asset slices and the liability slices, each summing to the matching
/// netWorthParts total. Slices with a zero total are dropped, so an empty
/// category never draws a legend row or a donut sliver. Ordered by the taxonomy
/// registry (assets then liabilities), with receivables appended to the asset
/// side and payables to the liability side.
List<BreakdownSlice> assetLiabilityBreakdown(
  Map<String, dynamic>? data, {
  FxTable? fx,
}) {
  final d = data ?? const {};
  final base = baseCurrencyOf(d);
  final totals = <String, double>{};
  final counts = <String, int>{};

  void add(Map<String, dynamic> row, AccountStore which, double amount) {
    final id = resolveKind(row, which).category.id;
    totals[id] = (totals[id] ?? 0) + _counted(row, amount, base, fx);
    counts[id] = (counts[id] ?? 0) + 1;
  }

  for (final r in _rows(d['accounts'])) {
    add(r, AccountStore.accounts, amountOf(r['balance']));
  }
  for (final r in _rows(d['assets'])) {
    add(r, AccountStore.assets, amountOf(r['value']));
  }
  for (final r in _rows(d['debts'])) {
    add(r, AccountStore.debts, amountOf(r['remaining']));
  }

  final out = <BreakdownSlice>[];
  for (final c in accountCategories) {
    final total = totals[c.id] ?? 0;
    if (total.abs() < 0.005) continue;
    out.add(
      BreakdownSlice(
        id: c.id,
        label: c.label,
        cls: c.cls,
        total: total,
        count: counts[c.id] ?? 0,
      ),
    );
  }

  // Receivables and payables are net worth components too, and dropping them
  // would make the slices sum to LESS than the hero's totals. They are not
  // taxonomy categories (they live on the Utang tab), so they come in as their
  // own clearly named slices. Counts are the number of tracked people.
  final receivables = trackedRemaining(d['receivables']);
  if (receivables.abs() >= 0.005) {
    out.add(
      BreakdownSlice(
        id: 'receivables',
        label: 'Owed to you',
        cls: AccountClass.asset,
        total: receivables,
        count: _rows(d['receivables']).length,
      ),
    );
  }
  final payables = trackedRemaining(d['payables']);
  if (payables.abs() >= 0.005) {
    out.add(
      BreakdownSlice(
        id: 'payables',
        label: 'You owe',
        cls: AccountClass.liability,
        total: payables,
        count: _rows(d['payables']).length,
      ),
    );
  }
  return out;
}

/// The glyph name for a breakdown slice, so the donut legend uses the same
/// icons as the account groups. Kept beside the breakdown so a new category
/// updates one file.
String breakdownGlyph(String id) => switch (id) {
  'cash_equivalents' => 'wallet',
  'investments' => 'growth',
  'property' => 'house',
  'credit' => 'card',
  'loans' => 'document',
  'installments' => 'calendar',
  'receivables' => 'incoming',
  'payables' => 'outgoing',
  _ => 'wallet',
};
