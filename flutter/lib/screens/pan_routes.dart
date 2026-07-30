// The one destination registry for Pan's CTAs.
//
// Pan's brain (money/pan/) is a golden-ported module: it emits RN-style route
// strings on its cta objects and must keep emitting exactly those, or the
// golden vectors break. The screen is where those strings become navigation,
// and that mapping used to be a bare `switch (route)` in pan.dart whose default
// arm returned null. Four routes the brain genuinely emits, /accounts,
// /reports, /goals, and /(tabs)/more, fell into that default and rendered a
// reply whose button simply was not there: "See accounts" with nothing to tap.
//
// This enum is that registry, named once. Two things now keep it honest:
//
//   1. The switch in pan.dart is over this enum, so it is exhaustive. Add a
//      value here without a destination and the analyzer fails the build.
//   2. test/pan_route_contract_test.dart reads the brain's own source, pulls
//      every 'route' literal out of it, and asserts each resolves through
//      forPath. A new responder route with no home fails that test instead of
//      shipping as a dead button.
//
// The strings are the RN routes verbatim (including the legacy '/(tabs)/more'
// that the Set payday CTA carries); this file only decides where each one goes
// in the Flutter app, it never changes what the brain says.
enum PanRoute {
  insights('/insights'),
  receivables('/receivables'),
  debts('/debts'),
  reports('/reports'),
  goals('/goals'),
  accounts('/accounts'),
  setPayday('/(tabs)/more'),
  loanCalculator('/loan-calculator'),
  taxCalculator('/tax-calculator'),
  salaryCalculator('/salary-calculator'),
  thirteenthCalculator('/thirteenth-calculator'),
  contributionCalculator('/contribution-calculator');

  const PanRoute(this.path);

  /// The RN-style route string the brain emits for this destination.
  final String path;

  /// Resolve a raw route string to its typed destination, or null when the
  /// brain emitted a route with no home here. Null renders no button, and the
  /// contract test forbids the brain from ever reaching that state.
  static PanRoute? forPath(String path) {
    for (final r in values) {
      if (r.path == path) return r;
    }
    return null;
  }
}
