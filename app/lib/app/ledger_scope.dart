// How a screen reaches the ledger.
//
// Fifteen lines rather than a state-management package, and that is
// 02-architecture.md's decision, not a shortcut: plain ChangeNotifier, one
// app-level store, a view model per feature. The founder is a beginner and
// will read this code, the shipped app already proved ChangeNotifier is
// enough, and every extra framework is one more thing Context7 has to verify
// against a pinned version.
//
// InheritedNotifier is the piece Flutter already provides for exactly this: it
// hands the store down the tree AND rebuilds the widgets that read it when the
// store notifies. Nothing else is needed.
import 'package:flutter/widgets.dart';

import '../core/data/ledger_store.dart';

class LedgerScope extends InheritedNotifier<LedgerStore> {
  const LedgerScope({
    super.key,
    required LedgerStore store,
    required super.child,
  }) : super(notifier: store);

  /// The store, and a subscription to it. A widget calling this rebuilds when
  /// the money changes, which is what every screen wants.
  static LedgerStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LedgerScope>();
    assert(scope != null, 'No LedgerScope above this widget.');
    return scope!.notifier!;
  }

  /// The store WITHOUT subscribing. For a callback that only writes.
  ///
  /// Reading inside a button's onTap through [of] would make that widget
  /// rebuild on every change it causes and every change it does not, which is
  /// the quiet way a list starts rebuilding on every keystroke somewhere else.
  static LedgerStore read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<LedgerScope>();
    assert(scope != null, 'No LedgerScope above this widget.');
    return scope!.notifier!;
  }
}

/// `context.ledger` at a read site, matching `context.skin` in the design
/// layer so the two feel like one codebase.
extension LedgerX on BuildContext {
  LedgerStore get ledger => LedgerScope.of(this);
}
